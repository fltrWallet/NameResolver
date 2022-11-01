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
@_exported import NameResolverAPI
import NIOCore
import NIOPosix

public extension NameResolver {
    @inlinable
    static func posix(threadPool: NIOThreadPool) -> Self {
        Self.init(
            lookup: { address, callback in
                fatalError()
            },
            nioLookup: { address, eventLoop in
                threadPool.runIfActive(eventLoop: eventLoop) {
                    try NameResolver.blockingLookup(address)
                }
                .flatMapError {
                    switch $0 {
                    case SocketAddressError.unknown:
                        return eventLoop.makeFailedFuture(NameResolver.NameNotFound())
                    default:
                        return eventLoop.makeFailedFuture($0)
                    }
                }
            }
        )
    }
}

extension NameResolver {
    typealias CAddrInfo = addrinfo
    
    @usableFromInline
    enum SocketAddressError: Swift.Error {
        case unsupported
        case unknown
    }
    
    @usableFromInline
    internal static func blockingLookup(_ address: String) throws -> [NameResolver.IP] {
        func parseResults(_ info: UnsafeMutablePointer<CAddrInfo>) throws -> [NameResolver.IP] {
            defer { freeaddrinfo(info) }
            var results: [NameResolver.IP] = []

            var info: UnsafeMutablePointer<CAddrInfo> = info
            while true {
                switch NIOBSDSocket.AddressFamily(rawValue: info.pointee.ai_family) {
                case .inet:
                    info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ptr in
                        results.append(.v4(ptr.pointee))
                    }
                case .inet6:
                    info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr in
                        results.append(.v6(ptr.pointee))
                    }
                default:
                    preconditionFailure()
                }

                guard let nextInfo = info.pointee.ai_next else {
                    break
                }

                info = nextInfo
            }
            
            return results
        }
        
        func resolve(host: String) throws -> UnsafeMutablePointer<CAddrInfo> {
            var info: UnsafeMutablePointer<addrinfo>?

            var hint = addrinfo()
            hint.ai_socktype = SOCK_STREAM
            hint.ai_protocol = CInt(IPPROTO_TCP)
            guard getaddrinfo(host, "0", &hint, &info) == 0 else {
                throw SocketAddressError.unknown
            }

            if let info = info {
                return info
            } else {
                throw SocketAddressError.unsupported
            }
        }
        
        let info = try resolve(host: address)
        return try parseResults(info)
    }
}
