import SwiftUI
import UIKit

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
                    .fill(.white.opacity(0.18))
                    .frame(height: 3)

                HStack {
                    ForEach(0..<11, id: \.self) { tick in
                        Rectangle()
                            .fill(.white.opacity(tick == 5 ? 0.8 : 0.3))
                            .frame(
                                width: tick == 5 ? 2 : 1,
                                height: tick == 5 ? 24 : 10
                            )

                        if tick < 10 {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, horizontalInset)

                Circle()
                    .fill(color)
                    .stroke(.white.opacity(0.9), lineWidth: 2)
                    .shadow(color: color.opacity(0.55), radius: 8)
                    .frame(width: 22, height: 22)
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
    @Environment(\.openURL) private var openURL
    
    // @State private var's
    @State private var pitchDetector = PitchDetector()
    @State private var microphonePermissionGranted: Bool?
    @State private var confirmedTunedStringID: Int?
    @State private var audioStartFailed = false
    
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

    private func startPitchDetector() {
        do {
            try pitchDetector.start()
            audioStartFailed = false
        } catch {
            audioStartFailed = true
            print("Failed to start pitch detector: \(error)")
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.10),
                    Color(red: 0.10, green: 0.08, blue: 0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Label("SandTune", systemImage: "waveform")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("STANDARD")
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                if microphonePermissionGranted == false {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)

                    Text("Microphone access is required")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text("Enable access in Settings to use the tuner.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.6))

                    Button("Open Settings") {
                        guard let settingsURL = URL(
                            string: UIApplication.openSettingsURLString
                        ) else {
                            return
                        }

                        openURL(settingsURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else if audioStartFailed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)

                    Text("Unable to start the microphone")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text("Check the audio input and try again.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.6))

                    Button("Try Again") {
                        startPitchDetector()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else if pitchDetector.isDetectingSound {
                    Text("\(closestString.note)\(closestString.octave)")
                        .font(
                            .system(
                                size: 112,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(tuningColor)
                        .shadow(
                            color: tuningColor.opacity(0.25),
                            radius: 24
                        )

                    Text(
                        "\(detectedFrequency.formatted(.number.precision(.fractionLength(1)))) Hz"
                    )
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))

                    TuningScale(
                        centsOffset: centsOffset,
                        color: tuningColor
                    )

                    HStack {
                        Text("−50")
                        Spacer()
                        Text(
                            "\(centsOffset.formatted(.number.precision(.fractionLength(1)))) cents"
                        )
                        Spacer()
                        Text("+50")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))

                    Text(
                        isCurrentStringConfirmed
                            ? "String tuned — move on"
                            : tuningInstruction
                    )
                    .font(.headline)
                    .foregroundStyle(tuningColor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        tuningColor.opacity(0.12),
                        in: Capsule()
                    )
                } else if let confirmedTunedString {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.green)

                    Text(
                        "\(confirmedTunedString.note)\(confirmedTunedString.octave)"
                    )
                    .font(
                        .system(
                            size: 112,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.green)

                    Text("String tuned — move on")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.35))

                    Text("Play a string")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                Spacer()

                if microphonePermissionGranted != false {
                    HStack(spacing: 8) {
                        ForEach(guitarStrings) { guitarString in
                            Text(guitarString.note)
                                .font(.title3.bold())
                                .foregroundStyle(
                                    stringColor(for: guitarString)
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    stringColor(for: guitarString)
                                        .opacity(0.12),
                                    in: RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                )
                        }
                    }
                    .padding(8)
                    .background(
                        .white.opacity(0.06),
                        in: RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
                }
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .task {
            let permissionGranted =
                await pitchDetector.requestMicrophonePermission()

            microphonePermissionGranted = permissionGranted

            guard permissionGranted else {
                return
            }

            startPitchDetector()
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
