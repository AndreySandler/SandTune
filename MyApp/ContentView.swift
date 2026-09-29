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
        Text("Hello, world!")
            .padding()
    }
}

#Preview {
    ContentView()
}
