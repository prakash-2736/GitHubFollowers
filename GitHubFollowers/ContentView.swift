import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("GitHub Followers")
                .font(.title)
                .fontWeight(.bold)

            Text("Find GitHub users and explore their followers.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Get Started") {
                print("Get Started tapped")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
