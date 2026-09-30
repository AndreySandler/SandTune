//
//  Untitled.swift
//  MyApp
//
//  Created by Andrey Sandler on 30.09.2026.
//

import AVFoundation
import Observation

@Observable
final class PitchDetector {
    private let audioEngine = AVAudioEngine()
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
            
            guard rootMeanSquare > 0.01 else {
                return
            }
            
            guard let frequency = self?.estimateFrequency(
                from: samples,
                sampleRate: sampleRate
            ) else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                isDetectingSound = true
                silenceTask?.cancel()
                silenceTask = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        return
                    }

                    self?.isDetectingSound = false
                }

                if detectedFrequency == 0 {
                    detectedFrequency = frequency
                    return
                }

                let centsDifference = abs(
                    1200 * log2(frequency / detectedFrequency)
                )

                if centsDifference > 50 {
                    detectedFrequency = frequency
                    return
                }

                let smoothingFactor = 0.35

                detectedFrequency =
                    detectedFrequency * (1 - smoothingFactor)
                    + frequency * smoothingFactor
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stop() {
        silenceTask?.cancel()
        silenceTask = nil
        isDetectingSound = false

        guard audioEngine.isRunning else {
            return
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private nonisolated func estimateFrequency(
        from samples: [Float],
        sampleRate: Double
    ) -> Double? {
        let minimumFrequency = 70.0
        let maximumFrequency = 400.0
        
        let minimumLag = Int(sampleRate / maximumFrequency)
        
        let maximumLag = min(
            Int(sampleRate / minimumFrequency),
            samples.count - 1
        )
        
        guard minimumLag < maximumLag else {
            return nil
        }
        
        var bestLag = 0
        var bestCorrelation: Float = 0
        
        for lag in minimumLag...maximumLag {
            var correlation: Float = 0
            var firstEnergy: Float = 0
            var secondEnergy: Float = 0
            
            for index in 0..<(samples.count - lag) {
                let firstSample = samples[index]
                let secondSample = samples[index + lag]
                
                correlation += firstSample * secondSample
                firstEnergy += firstSample * firstSample
                secondEnergy += secondSample * secondSample
            }
            
            let normalization = sqrt(firstEnergy * secondEnergy)
            
            guard normalization > 0 else {
                continue
            }
            
            let normalizedCorrelation = correlation / normalization
            
            if normalizedCorrelation > bestCorrelation {
                bestCorrelation = normalizedCorrelation
                bestLag = lag
            }
        }

        guard bestLag > 0, bestCorrelation > 0.6 else {
            return nil
        }

        return sampleRate / Double(bestLag)
    }
}

