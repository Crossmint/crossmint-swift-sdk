import Foundation

public protocol SignatureApiModel: Decodable {
    var id: String { get }
    var type: String { get }
    var chainType: String? { get }
    var walletType: String? { get }
    var status: String { get }
    var approvals: Approvals { get }
    var createdAt: Date { get }
}
