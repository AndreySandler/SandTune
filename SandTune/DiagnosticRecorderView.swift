#if DEBUG
import SwiftUI

struct DiagnosticRecorderView: View {
    @Environment(\.dismiss) private var dismiss

    let pitchDetector: PitchDetector
    let guitarStrings: [GuitarString]

    @State private var selectedStringID: Int
    @State private var errorMessage: String?

    init(
        pitchDetector: PitchDetector,
        guitarStrings: [GuitarString],
        selectedStringID: Int
    ) {
        self.pitchDetector = pitchDetector
        self.guitarStrings = guitarStrings
        _selectedStringID = State(initialValue: selectedStringID)
    }

    private var selectedString: GuitarString {
        guitarStrings.first { $0.id == selectedStringID }
            ?? guitarStrings[0]
    }

    private var sampleLabel: String {
        "String\(selectedString.number)_\(selectedString.note)\(selectedString.octave)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("String") {
                    Picker("String", selection: $selectedStringID) {
                        ForEach(guitarStrings) { guitarString in
                            Text(
                                "\(guitarString.number): "
                                    + "\(guitarString.note)\(guitarString.octave)"
                            )
                            .tag(guitarString.id)
                        }
                    }
                    .disabled(pitchDetector.isRecordingSample)
                }

                Section {
                    Button {
                        toggleRecording()
                    } label: {
                        Label(
                            pitchDetector.isRecordingSample
                                ? "Stop Recording"
                                : "Start Recording",
                            systemImage: pitchDetector.isRecordingSample
                                ? "stop.circle.fill"
                                : "record.circle"
                        )
                        .foregroundStyle(
                            pitchDetector.isRecordingSample ? .red : .primary
                        )
                    }

                    if pitchDetector.isRecordingSample {
                        LabeledContent("Status", value: "Recording…")
                    } else if let sampleURL = pitchDetector.latestSampleURL {
                        LabeledContent("Latest file", value: sampleURL.lastPathComponent)

                        ShareLink(item: sampleURL) {
                            Label("Share Recording", systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    Text("Recording")
                } footer: {
                    Text(
                        "Leave 2–3 seconds of silence, then make several soft, "
                            + "normal, and strong plucks with pauses between them."
                    )
                }

                Section("Why this exists") {
                    Text(
                        "This debug tool records the same uncompressed microphone "
                            + "signal used by the pitch detector. Recordings stay "
                            + "on this iPhone until you share them."
                    )
                }
            }
            .navigationTitle("Audio Samples")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(pitchDetector.isRecordingSample)
            .alert(
                "Recording Failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func toggleRecording() {
        if pitchDetector.isRecordingSample {
            pitchDetector.stopSampleRecording()
            return
        }

        do {
            try pitchDetector.startSampleRecording(label: sampleLabel)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
