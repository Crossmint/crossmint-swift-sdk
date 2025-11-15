public enum OrderPhase: String, Codable, Sendable {
    case quote
    case payment
    case delivery
    case completed
}
