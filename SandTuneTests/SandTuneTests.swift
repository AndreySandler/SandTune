//
//  SandTuneTests.swift
//  SandTuneTests
//
//  Created by Andrey Sandler on 04.10.2026.
//

import Foundation
import Testing
@testable import SandTune

struct SandTuneTests {
    private let analyzer = PitchAnalyzer()
    private let sampleRate = 44_100.0
    private let sampleCount = 4_096

    @Test(
        "Detects every open guitar string",
        arguments: [82.41, 110.00, 146.83, 196.00, 246.94, 329.63]
    )
    func detectsOpenString(frequency: Double) throws {
        let samples = makeSineWave(frequency: frequency, amplitude: 0.5)
        let detectedFrequency = try #require(
            analyzer.estimateFrequency(
                from: samples,
                sampleRate: sampleRate
            )
        )

        #expect(centsBetween(detectedFrequency, frequency) < 3)
    }

    @Test("Returns no pitch for silence")
    func rejectsSilence() {
        let samples = Array(repeating: Float.zero, count: sampleCount)

        #expect(
            analyzer.estimateFrequency(
                from: samples,
                sampleRate: sampleRate
            ) == nil
        )
    }

    @Test("Detects a quiet guitar signal")
    func detectsQuietSignal() throws {
        let frequency = 82.41
        let samples = makeSineWave(frequency: frequency, amplitude: 0.001)
        let detectedFrequency = try #require(
            analyzer.estimateFrequency(
                from: samples,
                sampleRate: sampleRate
            )
        )

        #expect(centsBetween(detectedFrequency, frequency) < 3)
    }

    @Test("Finds the fundamental when harmonics are present")
    func detectsFundamentalWithHarmonics() throws {
        let frequency = 82.41
        let samples = (0..<sampleCount).map { index in
            let time = Double(index) / sampleRate
            let fundamental = 0.5 * sin(2 * .pi * frequency * time)
            let secondHarmonic = 0.25 * sin(2 * .pi * frequency * 2 * time)
            let thirdHarmonic = 0.15 * sin(2 * .pi * frequency * 3 * time)
            return Float(fundamental + secondHarmonic + thirdHarmonic)
        }
        let detectedFrequency = try #require(
            analyzer.estimateFrequency(
                from: samples,
                sampleRate: sampleRate
            )
        )

        #expect(centsBetween(detectedFrequency, frequency) < 3)
    }

    @Test("Corrects a subharmonic for the selected string")
    func correctsSubharmonicForSelectedString() throws {
        let detectedSubharmonic = 97.7
        let samples = makeSineWave(
            frequency: detectedSubharmonic,
            amplitude: 0.2
        )
        let detectedFrequency = try #require(
            analyzer.estimateFrequency(
                from: samples,
                sampleRate: sampleRate,
                expectedFrequency: 196
            )
        )

        #expect(centsBetween(detectedFrequency, 195.4) < 3)
    }

    private func makeSineWave(
        frequency: Double,
        amplitude: Double
    ) -> [Float] {
        (0..<sampleCount).map { index in
            let time = Double(index) / sampleRate
            return Float(amplitude * sin(2 * .pi * frequency * time))
        }
    }

    private func centsBetween(_ first: Double, _ second: Double) -> Double {
        abs(1200 * log2(first / second))
    }
}
