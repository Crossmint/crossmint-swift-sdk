//
//  SignerOrigin.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/11/26.
//

import Foundation

struct SignerOrigin: Equatable, Sendable {
    private static let SCHEME = "https"
    private static let DEFAULT_PORT = 443

    let host: String
    let port: Int

    init?(scheme: String?, host: String?, port: Int?) {
        guard scheme?.lowercased() == Self.SCHEME,
              let host = host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        self.host = host
        if let port, port != 0 {
            self.port = port
        } else {
            self.port = Self.DEFAULT_PORT
        }
    }

    init?(url: URL?) {
        guard let url, url.user == nil, url.password == nil else {
            return nil
        }
        self.init(scheme: url.scheme, host: url.host, port: url.port)
    }

    var webOrigin: String {
        port == Self.DEFAULT_PORT ? "\(Self.SCHEME)://\(host)" : "\(Self.SCHEME)://\(host):\(port)"
    }

    func contains(_ url: URL?) -> Bool {
        SignerOrigin(url: url) == self
    }
}
