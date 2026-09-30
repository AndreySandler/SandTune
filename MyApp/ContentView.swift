import SwiftUI

struct GuitarString: Identifiable {
    let id: Int
    let number: Int
    let note: String
    let octave: Int
    let frequency: Double
}

struct ContentView: View {
    @State private var detectedFrequency = 82.41
    
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
    
    var body: some View {
        VStack(spacing: 12) {
            Text(
                "Detected frequency"
            )
            
            Text(
                "\(String(detectedFrequency)) Hz"
            )
            
            Text(
                "\(centsOffset.formatted(.number.precision(.fractionLength(1)))) cents"
            )
            
            Text(
                "Closest string is: \(closestString.note)\(closestString.octave)"
            )
            
            Text(tuningInstruction)
            
            HStack(spacing: 24) {
                Button("-1 Hz") {
                    detectedFrequency -= 1
                }
                Button("+1 Hz") {
                    detectedFrequency += 1
                }
            }
            
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
