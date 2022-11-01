//===----------------------------------------------------------------------===//
//
// This source file is part of the NameResolver open source project
//
// Copyright (c) 2022 fltrWallet AG and the NameResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import NIOCore

public extension NameResolver {
    @inlinable
    func lookup(address: String,
                eventLoop: EventLoop) -> EventLoopFuture<[IP]> {
        if let nioLookup = self._nioLookup {
            return nioLookup(address, eventLoop)
        } else {
            let promise = eventLoop.makePromise(of: [IP].self)
            self.lookup(address: address) { result in
                promise.completeWith(result)
            }
            return promise.futureResult
        }
    }
}
