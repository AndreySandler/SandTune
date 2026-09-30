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
            
            // Ignore quiet room noise so the UI does not report a wrong string
            // when the instrument is not being played.
            guard rootMeanSquare > 0.001 else {
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
                        try await Task.sleep(for: .milliseconds(1_200))
                    } catch {
                        return
                    }

                    self?.isDetectingSound = false
                    self?.detectedFrequency = 0
                }

                if detectedFrequency == 0 {
                    detectedFrequency = frequency
                    return
                }

                // Smooth in the logarithmic pitch domain so movement in cents
                // stays even across the guitar's full frequency range.
                let smoothingFactor = 0.18
                let frequencyRatio = frequency / detectedFrequency

                detectedFrequency *= pow(
                    frequencyRatio,
                    smoothingFactor
                )
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
        let threshold: Float = 0.25

        let minimumLag = Int(sampleRate / maximumFrequency)
        let maximumLag = min(
            Int(sampleRate / minimumFrequency),
            samples.count / 2
        )

        guard minimumLag < maximumLag else {
            return nil
        }

        var difference = Array(
            repeating: Float.zero,
            count: maximumLag + 1
        )

        for lag in 1...maximumLag {
            var sum: Float = 0

            for index in 0..<(samples.count - lag) {
                let delta = samples[index] - samples[index + lag]
                sum += delta * delta
            }

            difference[lag] = sum
        }

        var normalizedDifference = Array(
            repeating: Float(1),
            count: maximumLag + 1
        )
        var runningSum: Float = 0

        for lag in 1...maximumLag {
            runningSum += difference[lag]

            guard runningSum > 0 else {
                continue
            }

            normalizedDifference[lag] =
                difference[lag] * Float(lag) / runningSum
        }

        var candidateLag: Int?
        var lag = minimumLag

        while lag <= maximumLag {
            if normalizedDifference[lag] < threshold {
                while lag < maximumLag,
                      normalizedDifference[lag + 1]
                        < normalizedDifference[lag] {
                    lag += 1
                }

                candidateLag = lag
                break
            }

            lag += 1
        }

        guard let candidateLag else {
            return nil
        }

        var refinedLag = Double(candidateLag)

        if candidateLag > minimumLag,
           candidateLag < maximumLag {
            let previous = Double(
                normalizedDifference[candidateLag - 1]
            )
            let current = Double(
                normalizedDifference[candidateLag]
            )
            let next = Double(
                normalizedDifference[candidateLag + 1]
            )
            let denominator = previous - 2 * current + next

            if abs(denominator) > .ulpOfOne {
                refinedLag += 0.5 * (previous - next) / denominator
            }
        }

        return sampleRate / refinedLag
    }
}
