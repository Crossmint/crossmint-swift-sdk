import Lottie
import SwiftUI

struct CrossmintLottieView: View {
    let animationName: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat

    init(
        animationName: String,
        loopMode: LottieLoopMode = .loop,
        animationSpeed: CGFloat = 1.0
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
    }

    var body: some View {
        LottieView(animation: .named(animationName, bundle: .module) ?? .named(animationName))
            .playing(.fromProgress(0, toProgress: 1, loopMode: loopMode))
            .animationSpeed(animationSpeed)
    }
}

#Preview {
    CrossmintLottieView(animationName: "paperPlane", loopMode: .loop, animationSpeed: 1.0)
}
