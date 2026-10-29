//
//  RecoveryGate.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 29/10/26.
//

actor RecoveryGate {
    private var running: Task<Result<Transaction?, WalletError>, Never>?

    func run(
        _ recovery: @escaping @Sendable () async -> Result<Transaction?, WalletError>
    ) async -> Result<Transaction?, WalletError> {
        if let running { return await running.value }
        let task = Task { await recovery() }
        running = task
        let outcome = await task.value
        running = nil
        return outcome
    }
}
