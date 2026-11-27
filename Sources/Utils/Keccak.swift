//
//  Keccak.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 11/27/26.
//

import Foundation
import KeccakTiny

package func keccak256(_ data: Data) -> Data {
    var digest = [UInt8](repeating: 0, count: 32)
    data.withUnsafeBytes { input in
        _ = keccak_256(&digest, digest.count, input.bindMemory(to: UInt8.self).baseAddress, input.count)
    }
    return Data(digest)
}
