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
        ) { _, _ in
            // Audio buffers will arrive here.
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
}
