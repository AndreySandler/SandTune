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
    private(set) var detectedFrequency = 0.0
    
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
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: outputFormat
        ) { buffer, _ in
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

            print("Sound level: \(rootMeanSquare)")
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
}
