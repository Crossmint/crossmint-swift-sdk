import SwiftUI

struct MiddleEllipsisText: View {
    let text: String
    let maxLength: Int

    var truncatedText: String {
        guard text.count > maxLength else { return text }

        let prefixLength = maxLength / 2
        let suffixLength = maxLength - prefixLength - 3 // 3 for "..."

        let prefix = text.prefix(prefixLength)
        let suffix = text.suffix(suffixLength)

        return "\(prefix)...\(suffix)"
    }

    var body: some View {
        Text(truncatedText)
            .lineLimit(1)
    }
}
