import SwiftUI

struct ProgressBar: View {
    @State private var progress: Double = 0.1
    @State private var startTime: Date?
    private let startingProgress: Double = 0.1
    private let updateInterval: Double = 0.4
    private let totalDuration: Double = 30.0  // 30 seconds to complete

    var body: some View {
        ProgressView(value: progress)
            .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#05B959")))
            .frame(maxWidth: 280)
            .padding(.vertical, 24).onAppear {
                startTime = Date()
                progress = startingProgress
            }
            .onReceive(Timer.publish(every: updateInterval, on: .main, in: .common).autoconnect()) { currentTime in
                guard let startTime = startTime else { return }

                let elapsedTime = currentTime.timeIntervalSince(startTime)
                let calculatedProgress = min(elapsedTime / totalDuration, 1.0)

                withAnimation {
                    progress = calculatedProgress
                }
            }
    }
}
