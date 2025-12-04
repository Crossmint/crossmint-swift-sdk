//
//  CrossmintAuthManager.swift
//  SmartWalletsDemo
//
//  Created by Austin Feight on 11/24/25.
//

import Auth
import CrossmintClient

let crossmintApiKey = "ck_staging_9tb52Q6BLj8aeLEynQcpyrpGZ5kBbTVjLN1aH5tiyx9D6YWyS76bPm1cPQWnchVNGfwQjZsF92GE5gGUGPQjtpDVDwAaz9PXPw74Udo6WjeRjpiXJ24TDV29DCYDmAoTkbNN865KEDZKHrqUHEBh8dBvcYLes2HCjx5fiCysFS1MUU4mjYUk6taftpSLHMHVvGAbbXSAqCRnuvxda1sUMEqg"
// swiftlint:disable:next force_try
let crossmintAuthManager = try! CrossmintAuthManager(apiKey: crossmintApiKey)
