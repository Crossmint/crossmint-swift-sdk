import Foundation

public enum CrossmintWebViewContent: Equatable {
    case url(URL)

    public static func == (lhs: CrossmintWebViewContent, rhs: CrossmintWebViewContent) -> Bool {
        switch (lhs, rhs) {
        case (.url(let lhsURL), .url(let rhsURL)):
            return lhsURL == rhsURL
        }
    }
}
