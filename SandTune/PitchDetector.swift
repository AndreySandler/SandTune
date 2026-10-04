//
//  Untitled.swift
//  MyApp
//
//  Created by Andrey Sandler on 30.09.2026.
//

import AVFoundation
import Observation

private final class AudioSampleWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var audioFile: AVAudioFile?

    func startWriting(to url: URL, settings: [String: Any]) throws {
        let file = try AVAudioFile(
            forWriting: url,
            settings: settings
        )

        lock.lock()
        audioFile = file
        lock.unlock()
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        do {
            try audioFile?.write(from: buffer)
        } catch {
            // A failed diagnostic write must not interrupt pitch detection.
            audioFile = nil
        }
    }

    func stopWriting() {
        lock.lock()
        audioFile = nil
        lock.unlock()
    }
}

private final class NoiseFloorTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var estimatedNoiseFloor: Float = 0.00003

    func reset() {
        lock.lock()
        estimatedNoiseFloor = 0.00003
        lock.unlock()
    }

    func currentThreshold() -> Float {
        lock.lock()
        defer { lock.unlock() }

        // Stay sensitive in quiet rooms, but rise above steady background
        // noise. The upper limit prevents a noisy moment from deafening the
        // tuner for subsequent quiet notes.
        return min(max(estimatedNoiseFloor * 2, 0.00005), 0.0003)
    }

    func observeNoise(rootMeanSquare: Float) {
        lock.lock()
        defer { lock.unlock() }

        let sample = min(rootMeanSquare, 0.005)
        let smoothingFactor: Float = sample > estimatedNoiseFloor
            ? 0.02
            : 0.15

        estimatedNoiseFloor +=
            (sample - estimatedNoiseFloor) * smoothingFactor
    }
}

private final class ExpectedFrequencyStore: @unchecked Sendable {
    private let lock = NSLock()
    private var frequency = 82.41

    func update(_ newFrequency: Double) {
        lock.lock()
        frequency = newFrequency
        lock.unlock()
    }

    func current() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return frequency
    }
}

@Observable
final class PitchDetector {
    private let audioEngine = AVAudioEngine()
    private let noiseFloorTracker = NoiseFloorTracker()
    private let pitchAnalyzer = PitchAnalyzer()
    private let sampleWriter = AudioSampleWriter()
    private let expectedFrequencyStore = ExpectedFrequencyStore()
    private var silenceTask: Task<Void, Never>?
    private var recordingSettings: [String: Any]?
    private(set) var detectedFrequency = 0.0
    private(set) var isDetectingSound = false
    private(set) var isRecordingSample = false
    private(set) var latestSampleURL: URL?
    
    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
    
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        try audioSession.setCategory(
            .record,
            mode: .measurement
        )
        
        try audioSession.setActive(true)
    }
    
    func start() throws {
        guard !audioEngine.isRunning else {
            return
        }
        
        try configureAudioSession()
        noiseFloorTracker.reset()
        
        let inputNode = audioEngine.inputNode
        let outputFormat = inputNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        recordingSettings = outputFormat.settings
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: outputFormat
        ) { [weak self] buffer, _ in
            self?.sampleWriter.write(buffer)

            guard let channelData = buffer.floatChannelData?[0] else {
                return
            }
            
            let frameCount = Int(buffer.frameLength)
            
            let samples = Array(
                UnsafeBufferPointer(
                    start: channelData,
                    count: frameCount
                )
            )
            
            guard !samples.isEmpty else {
                return
            }
            
            let sumOfSquares = samples.reduce(0) { partialResult, sample in
                partialResult + sample * sample
            }
            
            let rootMeanSquare = sqrt(
                sumOfSquares / Float(samples.count)
            )
            
            let signalThreshold = self?.noiseFloorTracker.currentThreshold()
                ?? 0.0002

            guard rootMeanSquare > signalThreshold else {
                self?.noiseFloorTracker.observeNoise(
                    rootMeanSquare: rootMeanSquare
                )
                return
            }
            
            guard let frequency = self?.pitchAnalyzer.estimateFrequency(
                from: samples,
                sampleRate: sampleRate,
                expectedFrequency: self?.expectedFrequencyStore.current()
            ) else {
                self?.noiseFloorTracker.observeNoise(
                    rootMeanSquare: rootMeanSquare
                )
                return
            }

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                detectedFrequency = frequency
                isDetectingSound = true
                silenceTask?.cancel()
                silenceTask = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .milliseconds(1_200))
                    } catch {
                        return
                    }

                    self?.isDetectingSound = false
                    self?.detectedFrequency = 0
                }

            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stop() {
        stopSampleRecording()
        resetTracking()

        guard audioEngine.isRunning else {
            return
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    func startSampleRecording(label: String) throws {
        guard audioEngine.isRunning,
              let recordingSettings else {
            throw CocoaError(.fileWriteUnknown)
        }

        let documentsDirectory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let timestamp = Date.now.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .time(includingFractionalSeconds: false)
                .timeZone(separator: .omitted)
        )
        .replacingOccurrences(of: ":", with: "-")
        let fileURL = documentsDirectory
            .appendingPathComponent("SandTune_\(label)_\(timestamp)")
            .appendingPathExtension("caf")

        try sampleWriter.startWriting(
            to: fileURL,
            settings: recordingSettings
        )
        latestSampleURL = fileURL
        isRecordingSample = true
    }

    func stopSampleRecording() {
        sampleWriter.stopWriting()
        isRecordingSample = false
    }

    func resetTracking() {
        silenceTask?.cancel()
        silenceTask = nil
        isDetectingSound = false
        detectedFrequency = 0
    }

    func selectExpectedFrequency(_ frequency: Double) {
        expectedFrequencyStore.update(frequency)
        resetTracking()
    }
    
}
