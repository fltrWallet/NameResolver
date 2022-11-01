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

@_implementationOnly import struct Foundation.Data
import Network

public extension NameResolver.IP {
    var asIPv6: IPv6Address {
        let bytes: [UInt8] = {
            switch self {
            case .v4(let saddr):
                var v4 = saddr.sin_addr
                return withUnsafeBytes(of: &v4) {
                    $0.elementsEqual([127, 0, 0, 1])
                    ? [ 0, 0, 0, 0,
                        0, 0, 0, 0,
                        0, 0, 0, 0,
                        0, 0, 0, 1 ]
                    : [ 0, 0, 0, 0,
                        0, 0, 0, 0,
                        0, 0, 255, 255 ]
                        + $0
                }
            case .v6(let saddr6):
                var v6 = saddr6.sin6_addr
                return withUnsafeBytes(of: &v6) {
                    return Array($0)
                }
            }
        }()
        assert(bytes.count == 16)

        return IPv6Address(Data(bytes))!
    }
    
    var asIPv4: IPv4Address? {
        switch self {
        case .v4(let saddr):
            var v4 = saddr.sin_addr
            return withUnsafeBytes(of: &v4) {
                IPv4Address(Data($0))
            }
        case .v6(let saddr6):
            var v6 = saddr6.sin6_addr
            return withUnsafeBytes(of: &v6) {
                IPv6Address(Data($0))?.asIPv4
            }
        }
    }
    
    static func v4(_ v4: IPv4Address) -> Self {
        let data = v4.rawValue
        var storage = sockaddr_storage()
        return withUnsafeMutablePointer(to: &storage) { ptr in
            ptr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                $0.pointee.sin_family = .init(AF_INET)
                withUnsafeMutableBytes(of: &$0.pointee.sin_addr) {
                    $0.copyBytes(from: data)
                }
                return NameResolver.IP.v4($0.pointee)
            }
        }
    }
    
    static func v6(_ v6: IPv6Address) -> Self {
        let data = v6.rawValue
        var storage = sockaddr_storage()
        return withUnsafeMutablePointer(to: &storage) { ptr in
            ptr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                $0.pointee.sin6_family = .init(AF_INET6)
                withUnsafeMutableBytes(of: &$0.pointee.sin6_addr) {
                    $0.copyBytes(from: data)
                }
                return NameResolver.IP.v6($0.pointee)
            }
        }
    }
}

extension NameResolver.IP: CustomStringConvertible {
    public var description: String {
        switch self {
        case .v4: return "NameResolver.IP.v4(\(self.asIPv4!))"
        case .v6: return "NameResolver.IP.v6(\(self.asIPv6))"
        }
    }
}
#endif
#endif
