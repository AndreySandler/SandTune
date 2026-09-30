import SwiftUI

struct GuitarString: Identifiable {
    let id: Int
    let number: Int
    let note: String
    let octave: Int
    let frequency: Double
}

private struct TuningScale: View {
    let centsOffset: Double
    let color: Color

    private var clampedOffset: Double {
        min(max(centsOffset, -50), 50)
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalInset = 12.0
            let centerX = geometry.size.width / 2
            let usableWidth = geometry.size.width - horizontalInset * 2
            let markerX = centerX + usableWidth * clampedOffset / 100

            ZStack {
                Capsule()
                    .fill(.secondary.opacity(0.25))
                    .frame(height: 4)

                Rectangle()
                    .fill(.secondary)
                    .frame(width: 2, height: 20)

                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .position(
                        x: markerX,
                        y: geometry.size.height / 2
                    )
            }
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tuning offset")
        .accessibilityValue(
            "\(centsOffset.formatted(.number.precision(.fractionLength(1)))) cents"
        )
    }
}

struct ContentView: View {
    
    // @State private var's
    @State private var pitchDetector = PitchDetector()
    @State private var microphonePermissionGranted: Bool?
    @State private var confirmedTunedStringID: Int?
    
    // Private var's
    private var detectedFrequency: Double {
        if pitchDetector.detectedFrequency > 0 {
            return pitchDetector.detectedFrequency
        }

        return 82.41
    }
    
    // Standard tuning from sixth string to first.
    let guitarStrings = [
        GuitarString(
            id: 6,
            number: 6,
            note: "E",
            octave: 2,
            frequency: 82.41
        ),
        GuitarString(
            id: 5,
            number: 5,
            note: "A",
            octave: 2,
            frequency: 110.00
        ),
        GuitarString(
            id: 4,
            number: 4,
            note: "D",
            octave: 3,
            frequency: 146.83
        ),
        GuitarString(
            id: 3,
            number: 3,
            note: "G",
            octave: 3,
            frequency: 196.00
        ),
        GuitarString(
            id: 2,
            number: 2,
            note: "B",
            octave: 3,
            frequency: 246.94
        ),
        GuitarString(
            id: 1,
            number: 1,
            note: "E",
            octave: 4,
            frequency: 329.63
        )
    ]
    
    // Finds the string closest to the detected frequency.
    private var closestString: GuitarString {
        var closestMatch = guitarStrings[0]
        for guitarString in guitarStrings {
            let currentDifference = abs(
                guitarString.frequency - detectedFrequency
            )
            
            let closestDifference = abs(
                closestMatch.frequency - detectedFrequency
            )
            
            if currentDifference < closestDifference {
                closestMatch = guitarString
            }
        }
        return closestMatch
    }
    
    // Convertation frequency into music cents.
    private var centsOffset: Double {
        let frequencyRatio = detectedFrequency / closestString.frequency
        return log2(frequencyRatio) * 1200
    }
    
    private var tuningInstruction: String {
        if abs(centsOffset) <= 5 {
            return "In Tune"
        }
        if centsOffset < 0 {
            return "Tune Up"
        }
        return "Tune Down"
    }

    private var confirmedTunedString: GuitarString? {
        guard let confirmedTunedStringID else {
            return nil
        }

        return guitarStrings.first {
            $0.id == confirmedTunedStringID
        }
    }

    private var isCurrentStringConfirmed: Bool {
        confirmedTunedStringID == closestString.id
    }

    private var tuningColor: Color {
        if isCurrentStringConfirmed || abs(centsOffset) <= 5 {
            return .green
        }

        return .orange
    }

    private func stringColor(for guitarString: GuitarString) -> Color {
        if confirmedTunedStringID == guitarString.id {
            return .green
        }

        if pitchDetector.isDetectingSound,
           closestString.id == guitarString.id {
            return tuningColor
        }

        return .secondary
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if microphonePermissionGranted == false {
                Text("Microphone access is required")
                Text("Enable access in Settings to use the tuner.")
            } else if pitchDetector.isDetectingSound {
                Text("Detected frequency")

                Text("\(closestString.note)\(closestString.octave)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(tuningColor)

                Text(
                    "\(String(detectedFrequency)) Hz"
                )

                Text(
                    "\(centsOffset.formatted(.number.precision(.fractionLength(1)))) cents"
                )
                .foregroundStyle(tuningColor)

                TuningScale(
                    centsOffset: centsOffset,
                    color: tuningColor
                )
                .padding(.horizontal, 32)

                Text(
                    isCurrentStringConfirmed
                        ? "String tuned — move on"
                        : tuningInstruction
                )
                .foregroundStyle(tuningColor)
            } else if let confirmedTunedString {
                Text("\(confirmedTunedString.note)\(confirmedTunedString.octave)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text("String tuned — move on")
                    .foregroundStyle(.green)
            } else {
                Text("Play a string")
            }
            
            if microphonePermissionGranted != false {
                HStack(spacing: 8) {
                    ForEach(guitarStrings) { guitarString in
                        Text(guitarString.note)
                            .font(.title2.bold())
                            .foregroundStyle(
                                stringColor(for: guitarString)
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
        }.task {
            let permissionGranted =
                await pitchDetector.requestMicrophonePermission()

            microphonePermissionGranted = permissionGranted

            guard permissionGranted else {
                return
            }

            do {
                try pitchDetector.start()
            } catch {
                print("Failed to start pitch detector: \(error)")
            }
        }
        .onChange(of: pitchDetector.detectedFrequency) { _, _ in
            guard pitchDetector.isDetectingSound else {
                return
            }

            if confirmedTunedStringID != closestString.id {
                confirmedTunedStringID = nil
            }

            if abs(centsOffset) <= 5 {
                confirmedTunedStringID = closestString.id
            }
        }
        .onDisappear {
            pitchDetector.stop()
        }
    }
}

#Preview {
    ContentView()
}
