
import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                SearchView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))

            withAnimation(.easeInOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }
}

struct SplashView: View {
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(.primary)
                .scaleEffect(isVisible ? 1.0 : 0.7)
                .opacity(isVisible ? 1.0 : 0.0)

            Text("GitHub Followers")
                .font(.title2)
                .fontWeight(.semibold)
                .opacity(isVisible ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .task {
            withAnimation(.easeOut(duration: 0.8)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    ContentView()
}
