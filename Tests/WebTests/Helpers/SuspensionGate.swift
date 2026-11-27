//
//  SuspensionGate.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/11/26.
//

import Foundation

final class SuspensionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var isReleased = false
    private var hasArrived = false

    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let (resumeNow, arrival) = lock.withLock {
                hasArrived = true
                if !isReleased { self.continuation = continuation }
                defer { arrivalContinuation = nil }
                return (isReleased, arrivalContinuation)
            }
            arrival?.resume()
            if resumeNow { continuation.resume() }
        }
    }

    func waitUntilArrived() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let arrived = lock.withLock {
                if !hasArrived { arrivalContinuation = continuation }
                return hasArrived
            }
            if arrived { continuation.resume() }
        }
    }

    func release() {
        let pending = lock.withLock {
            isReleased = true
            defer { continuation = nil }
            return continuation
        }
        pending?.resume()
    }
}
