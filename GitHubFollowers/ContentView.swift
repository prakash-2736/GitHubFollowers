
import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                MainScreenPlaceholder()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(nil)
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

struct MainScreenPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)

            Text("Search GitHub Users")
                .font(.title2.bold())

            Text("Your main search screen will be built next.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    ContentView()
}
