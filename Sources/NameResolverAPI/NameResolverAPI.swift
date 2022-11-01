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
import NIOPosix

public extension NameResolver {
    enum IP {
        case v4(sockaddr_in)
        case v6(sockaddr_in6)
    }
}

public struct NameResolver {
    @inlinable
    public init(lookup: @escaping (String, @escaping (Result<[IP], Error>) -> Void) -> Void,
                nioLookup: ((String, EventLoop) -> EventLoopFuture<[IP]>)? = nil) {
        self._lookup = lookup
        self._nioLookup = nioLookup
    }
    
    @usableFromInline
    let _lookup: (String, @escaping (Result<[IP], Error>) -> Void) -> Void
    
    @usableFromInline
    let _nioLookup: ((String, EventLoop) -> EventLoopFuture<[IP]>)?
    
    @inlinable
    public func lookup(address: String,
                       callback: @escaping (Result<[IP], Error>) -> Void) -> Void {
        self._lookup(address, callback)
    }
}

public extension NameResolver {
    struct NameNotFound: Error, Hashable {
        @inlinable
        public init() {}
    }
}

extension NameResolver.IP: Equatable {
    @inlinable
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.v4(let lhs), .v4(let rhs)):
            return lhs.sin_addr.s_addr == rhs.sin_addr.s_addr
        case (.v6(let lhsSock), .v6(let rhsSock)):
            var lhs = lhsSock.sin6_addr
            var rhs = rhsSock.sin6_addr
            return withUnsafeBytes(of: &lhs) { lhs in
                withUnsafeBytes(of: &rhs) { rhs in
                    lhs.elementsEqual(rhs)
                }
            }
        case (.v4, .v6),
             (.v6, .v4):
            return false
        }
    }
}
