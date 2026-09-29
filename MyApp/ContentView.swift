import SwiftUI

struct GuitarString: Identifiable {
    let id: Int
    let number: Int
    let note: String
    let octave: Int
    let frequency: Double
}

struct ContentView: View {
    
    // Standart tuning from sixth string to first.
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
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(guitarStrings) { guitarString in
                VStack(spacing: 4) {
                    Text("\(guitarString.note)\(guitarString.octave)")
                    Text("String \(guitarString.number)")
                    Text("\(String(guitarString.frequency)) Hz")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
