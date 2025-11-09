import Foundation

public class ABI {
    protocol ABIType {
        var data: Data { get throws(Error) }
        var typeName: String { get }
    }

    public enum Error: Swift.Error {
        case invalidAddress(String)
    }

    public enum Argument: ABIType {
        case address(String)
        case uint64(UInt64)

        var data: Data {
            get throws (ABI.Error) {
                try arg.data
            }
        }

        var typeName: String {
            arg.typeName
        }

        private var arg: ABIType {
            switch self {
            case .address(let arg):
                return ABIAddress(address: arg)
            case .uint64(let arg):
                return ABIUInt64(uint: arg)
            }
        }
    }
}
