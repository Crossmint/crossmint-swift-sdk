import SwiftUI
import CrossmintClient

@main
struct SolanaDemoApp: App {
    @State var flip = true
    
    var body: some Scene {
        WindowGroup {
            VStack {
                if flip {
                    SplashScreen()
                }
                Button(action: { Task { await flip() } }) {
                    Text("Flip")
                }
            }
        }
    }
    
    func flip() async {
        flip = false
        Task {
            try? await Task.sleep(for: .seconds(2))
            flip = true
        }
    }
}
