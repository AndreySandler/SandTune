import SwiftUI
import UIKit

struct GuitarString: Identifiable {
    let id: Int
    let number: Int
    let note: String
    let octave: Int
    let frequency: Double
}

private enum TuningFeedback: Equatable {
    case playString
    case tuneUp
    case tuneDown
    case holdSteady
    case tuned

    var title: LocalizedStringResource {
        switch self {
        case .playString:
            "Play a String"
        case .tuneUp:
            "Tune Up"
        case .tuneDown:
            "Tune Down"
        case .holdSteady:
            "Hold Steady"
        case .tuned:
            "String Tuned"
        }
    }

    var color: Color {
        switch self {
        case .playString:
            .white.opacity(0.45)
        case .tuneUp, .tuneDown:
            .orange
        case .holdSteady, .tuned:
            .green
        }
    }
}

private struct TuningScale: View {
    let centsOffset: Double
    let color: Color
    let showsMarker: Bool

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

                if showsMarker {
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
    @State private var tunedStringIDs: Set<Int> = []
    @State private var selectedStringID = 6
    @State private var audioStartFailed = false
    @State private var isShowingTipJar = false
#if DEBUG
    @State private var isShowingDiagnosticRecorder = false
#endif
    @State private var tuningConfirmationTask: Task<Void, Never>?
    @State private var lastCentsOffset = 0.0
    @State private var isVisuallyInTune = false
    @State private var lastTuningFeedback = TuningFeedback.playString
    
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
    
    // The string chosen by the user in the bottom selector.
    private var selectedString: GuitarString {
        guitarStrings.first {
            $0.id == selectedStringID
        } ?? guitarStrings[0]
    }
    
    // Convertation frequency into music cents.
    private var centsOffset: Double {
        let frequencyRatio = detectedFrequency / selectedString.frequency
        return log2(frequencyRatio) * 1200
    }
    
    private var tuningFeedback: TuningFeedback {
        if tunedStringIDs.contains(selectedStringID),
           isVisuallyInTune {
            return .tuned
        }

        if isVisuallyInTune {
            return .holdSteady
        }
        if centsOffset < 0 {
            return .tuneUp
        }
        return .tuneDown
    }

    private var tuningColor: Color {
        tuningFeedback.color
    }

    private func stringColor(for guitarString: GuitarString) -> Color {
        if tunedStringIDs.contains(guitarString.id) {
            return .green
        }

        if selectedStringID == guitarString.id {
            return pitchDetector.isDetectingSound
                ? tuningColor
                : .white.opacity(0.55)
        }

        return .secondary
    }

    private func startPitchDetector() {
        do {
            pitchDetector.selectExpectedFrequency(selectedString.frequency)
            try pitchDetector.start()
            audioStartFailed = false
        } catch {
            audioStartFailed = true
            print("Failed to start pitch detector: \(error)")
        }
    }

    private func cancelTuningConfirmation() {
        tuningConfirmationTask?.cancel()
        tuningConfirmationTask = nil
    }

    private func updateTuningConfirmation() {
        guard pitchDetector.isDetectingSound,
              !tunedStringIDs.contains(selectedStringID) else {
            cancelTuningConfirmation()
            return
        }

        let absoluteOffset = abs(centsOffset)

        if tuningConfirmationTask != nil {
            // A small amount of movement is expected while a string rings out.
            if absoluteOffset > 8 {
                cancelTuningConfirmation()
            }

            return
        }

        guard absoluteOffset <= 5 else {
            return
        }

        let candidateStringID = selectedStringID

        tuningConfirmationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch {
                return
            }

            defer {
                tuningConfirmationTask = nil
            }

            guard selectedStringID == candidateStringID,
                  pitchDetector.isDetectingSound,
                  abs(centsOffset) <= 8 else {
                return
            }

            tunedStringIDs.insert(candidateStringID)
            lastTuningFeedback = .tuned
        }
    }

    private func updateTunerDisplay() {
        guard pitchDetector.isDetectingSound else {
            isVisuallyInTune = false
            cancelTuningConfirmation()
            return
        }

        lastCentsOffset = centsOffset
        let absoluteOffset = abs(centsOffset)

        if isVisuallyInTune {
            // Keep the green state through tiny pitch fluctuations.
            isVisuallyInTune = absoluteOffset <= 10
        } else {
            isVisuallyInTune = absoluteOffset <= 7
        }

        lastTuningFeedback = tuningFeedback
        updateTuningConfirmation()
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

#if DEBUG
                    Button {
                        isShowingDiagnosticRecorder = true
                    } label: {
                        Image(systemName: "waveform.badge.mic")
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Record diagnostic audio samples")
#endif

                    Button {
                        isShowingTipJar = true
                    } label: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Leave a tip")

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
                    Text("\(selectedString.note)\(selectedString.octave)")
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

                    TuningScale(
                        centsOffset: centsOffset,
                        color: tuningColor,
                        showsMarker: true
                    )

                    Text(tuningFeedback.title)
                        .font(.headline)
                        .foregroundStyle(tuningColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            tuningColor.opacity(0.12),
                            in: Capsule()
                        )
                } else {
                    Text("\(selectedString.note)\(selectedString.octave)")
                        .font(
                            .system(
                                size: 112,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white.opacity(0.65))

                    TuningScale(
                        centsOffset: lastCentsOffset,
                        color: .white.opacity(0.55),
                        showsMarker: true
                    )

                    Text(lastTuningFeedback.title)
                        .font(.headline)
                        .foregroundStyle(lastTuningFeedback.color)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            lastTuningFeedback.color.opacity(0.12),
                            in: Capsule()
                        )

                }

                Spacer()

                if microphonePermissionGranted != false {
                    HStack(spacing: 8) {
                        ForEach(guitarStrings) { guitarString in
                            Button {
                                cancelTuningConfirmation()
                                selectedStringID = guitarString.id
                                pitchDetector.selectExpectedFrequency(
                                    guitarString.frequency
                                )
                                lastCentsOffset = 0
                                isVisuallyInTune = false
                                lastTuningFeedback = .playString
                            } label: {
                                VStack(spacing: 2) {
                                    Text(guitarString.note)
                                        .font(.title3.bold())

                                    if tunedStringIDs.contains(guitarString.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                    }
                                }
                                    .foregroundStyle(stringColor(for: guitarString))
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
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "String \(guitarString.number), \(guitarString.note)"
                            )
                            .accessibilityValue(
                                tunedStringIDs.contains(guitarString.id)
                                    ? "Tuned"
                                    : "Not tuned"
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
        .sheet(isPresented: $isShowingTipJar) {
            TipJarView()
        }
#if DEBUG
        .sheet(isPresented: $isShowingDiagnosticRecorder) {
            DiagnosticRecorderView(
                pitchDetector: pitchDetector,
                guitarStrings: guitarStrings,
                selectedStringID: selectedStringID
            )
        }
#endif
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
            updateTunerDisplay()
        }
        .onDisappear {
            cancelTuningConfirmation()
            pitchDetector.stop()
        }
    }
}

#Preview {
    ContentView()
}
