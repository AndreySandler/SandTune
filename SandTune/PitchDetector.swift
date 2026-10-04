//
//  Untitled.swift
//  MyApp
//
//  Created by Andrey Sandler on 30.09.2026.
//

import AVFoundation
import Observation

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
        return min(max(estimatedNoiseFloor * 2, 0.00005), 0.001)
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

@Observable
final class PitchDetector {
    private let audioEngine = AVAudioEngine()
    private let noiseFloorTracker = NoiseFloorTracker()
    private let pitchAnalyzer = PitchAnalyzer()
    private var silenceTask: Task<Void, Never>?
    private(set) var detectedFrequency = 0.0
    private(set) var isDetectingSound = false
    
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
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: outputFormat
        ) { [weak self] buffer, _ in
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
                sampleRate: sampleRate
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
        resetTracking()

        guard audioEngine.isRunning else {
            return
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    func resetTracking() {
        silenceTask?.cancel()
        silenceTask = nil
        isDetectingSound = false
        detectedFrequency = 0
    }
    
}
