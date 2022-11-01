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
#if canImport(Foundation)
#if canImport(Network)
@_exported import NameResolverAPI
import Foundation
import Network

public extension NameResolver {
    @inlinable
    static var localhost: Self {
        .init { _, callback in
            callback(
                .success(
                    [
                        .v4(
                            IPv4Address.loopback
                        ),
                    ]
                )
            )
        }
    }
    
    struct AlwaysFail: Swift.Error, CustomStringConvertible {
        @usableFromInline
        init() {}
        
        public var description: String {
            "AlwaysFail[test implementation in NameResolverTest package]"
        }
    }
    
    @inlinable
    static var fail: Self {
        .init { _, callback in
            callback(.failure(AlwaysFail()))
        }
    }
}
#endif
#endif
