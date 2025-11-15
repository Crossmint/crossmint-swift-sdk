public func isEmpty(_ str: String?) -> Bool {
    guard let str = str else { return true }
    return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

public func cutMiddleAndAddEllipsis(_ str: String, beginLength: Int = 4, endLength: Int = 4)
    -> String {
    guard str.count > beginLength + endLength else {
        return str
    }

    let start = str.prefix(beginLength)
    let end = str.suffix(endLength)
    return "\(start)…\(end)"
}
