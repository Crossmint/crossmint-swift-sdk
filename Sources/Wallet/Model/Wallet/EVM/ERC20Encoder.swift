import Foundation
import SwiftKeccak

public struct ERC20Encoder {
    public enum Error: Swift.Error, Equatable {
        case invalidAddress(address: String)
        case invalidData
    }

    public static func encode(
        functionName: String,
        arguments: [ABI.Argument]
    ) throws(ERC20Encoder.Error) -> String {
        let functionSignature = "\(functionName)(\(arguments.map(\.typeName).joined(separator: ",")))"
        guard let functionSignatureData = functionSignature.data(using: .utf8) else {
            throw .invalidData
        }
        let selector = keccak256(functionSignatureData).prefix(4)
        let data: Data
        do {
            data = try arguments.reduce(into: Data(selector)) { result, arg in
                result.append(try arg.data)
            }
        } catch let abiError as ABI.Error {
            switch abiError {
            case .invalidAddress(let address):
                throw .invalidAddress(address: address)
            }
        } catch {
            throw .invalidData
        }

        return "0x" + data.map { String(format: "%02x", $0) }.joined()
    }
}
