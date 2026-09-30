import StoreKit
import SwiftUI

private enum TipProduct {
    static let identifiers = [
        "com.andreysandlerpersonalteam.SandTune.tip.small",
        "com.andreysandlerpersonalteam.SandTune.tip.medium",
        "com.andreysandlerpersonalteam.SandTune.tip.large"
    ]
}

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)

                Text("Support SandTune")
                    .font(.title2.bold())

                Text("If SandTune helped you tune your guitar, you can support its development with a small tip.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                StoreView(ids: TipProduct.identifiers)
                    .storeButton(.hidden, for: .restorePurchases)
            }
            .padding(24)
            .navigationTitle("Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    TipJarView()
}
