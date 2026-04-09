//
//  CrossmintAuthManager.swift
//  SmartWalletsDemo
//
//  Created by Austin Feight on 11/24/25.
//

import CrossmintAuth
import CrossmintClient

let crossmintApiKey = "ck_staging_31oLQLjeg8y9eaLTewmB8PCk5EPfpw7Z4fbVZbzTYKBNEUnpVARMNiLCVw8sNzbRw8Z7ZXxwTFjcS1im3kMCEKxHHEkthcefrGHqV3j7KtuSDLWybtCaDiCCuJvsbvNNk2RChYciJVaRGtVprroEYvp1TW8xWUMTkaBo5CMC7FV1X1P3FbKGFjhL29PwF2GJUw3BeNKZg2tDHBBD8Phn12Z"
// swiftlint:disable:next force_try
let crossmintAuthManager = try! CrossmintAuthManager(apiKey: crossmintApiKey)
