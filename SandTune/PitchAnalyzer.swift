import Foundation

struct PitchAnalyzer: Sendable {
    func estimateFrequency(
        from samples: [Float],
        sampleRate: Double,
        expectedFrequency: Double? = nil
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

        let detectedFrequency = sampleRate / refinedLag

        guard let expectedFrequency else {
            return detectedFrequency
        }

        // YIN can occasionally lock onto a subharmonic and report exactly
        // half of a guitar string's pitch. Prefer the octave candidate closest
        // to the string selected by the user, without rejecting other notes.
        let octaveCandidates = [
            detectedFrequency / 2,
            detectedFrequency,
            detectedFrequency * 2
        ]
        .filter { $0 >= minimumFrequency && $0 <= maximumFrequency }

        return octaveCandidates.min { first, second in
            abs(log2(first / expectedFrequency))
                < abs(log2(second / expectedFrequency))
        } ?? detectedFrequency
    }
}
