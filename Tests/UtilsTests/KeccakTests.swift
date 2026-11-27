//
//  KeccakTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 11/27/26.
//

import Foundation
import Testing
@testable import Utils

@Suite("Keccak-256", .tags(.unit))
struct KeccakTests {
    @Test(arguments: [
        ("", "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"),
        ("abc", "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"),
        (String(repeating: "a", count: 136), "a6c4d403279fe3e0af03729caada8374b5ca54d8065329a3ebcaeb4b60aa386e"),
        (String(repeating: "a", count: 200), "96ea54061def936c4be90b518992fdc6f12f535068a256229aca54267b4d084d")
    ])
    func hashesKnownVectors(input: String, expectedHex: String) {
        #expect(keccak256(Data(input.utf8)).toHexString(withPrefix: false) == expectedHex)
    }
}
