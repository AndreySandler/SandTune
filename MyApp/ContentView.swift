import SwiftUI

struct GuitarString: Identifiable {
    let id: Int
    let number: Int
    let note: String
    let octave: Int
    let frequency: Double
}

struct ContentView: View {
    let lowEString = GuitarString(
        id: 6,
        number: 6,
        note: "E",
        octave: 2,
        frequency: 82.41
    )
    
    var body: some View {
        VStack(spacing: 12) {
            Text("\(lowEString.note)\(lowEString.octave)")
            Text("String \(lowEString.number)")
            Text("\(String(lowEString.frequency)) Hz")
        }
    }
}

#Preview {
    ContentView()
}
