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

#if canImport(Foundation)
#if canImport(dnssd)
import Foundation
import dnssd

public extension NameResolver {
    static var dnssd: Self {
        var sdRef = DNSServiceRef?.none
        
        return .init { address, callback in
            Self.getAddrInfo(sdRef: &sdRef,
                             host: address,
                             queue: .global(),
                             cb: callback)
        }
    }
}

extension NameResolver {
    static func getAddrInfo(sdRef: inout DNSServiceRef?,
                            host: String,
                            queue: DispatchQueue,
                            cb: @escaping (Result<[NameResolver.IP], Swift.Error>) -> Void) {
        class CallBackData {
            struct Proto: OptionSet, Hashable {
                let rawValue: UInt8
                
                static var v4: Self = .init(rawValue: 1)
                static var v6: Self = .init(rawValue: 1 << 1)
                
                static func from(_ sa: sockaddr) -> Self {
                    switch Int32(sa.sa_family) {
                    case AF_INET:
                        return .v4
                    case AF_INET6:
                        return .v6
                    default:
                        preconditionFailure()
                    }
                }
                
                var other: Self {
                    switch self.rawValue {
                    case Self.v4.rawValue:
                        return .v6
                    case Self.v6.rawValue:
                        return .v4
                    default:
                        preconditionFailure()
                    }
                }
            }
            var set: Proto = []
            let cb: (Result<[NameResolver.IP], Swift.Error>) -> Void
            var value: [NameResolver.IP] = []
            
            init(cb: @escaping (Result<[NameResolver.IP], Swift.Error>) -> Void) {
                self.cb = cb
            }
        }
        
        let callbackData = CallBackData(cb: cb)
        let u = Unmanaged.passRetained(callbackData)
        
        let callback: DNSServiceGetAddrInfoReply = { service, flags, _, error, _, sa, _, unmanaged in
            let result = Unmanaged<CallBackData>
                .fromOpaque(unmanaged!)
                .takeUnretainedValue()
            let proto = CallBackData.Proto.from(sa!.pointee)
            result.set.insert(proto)
            let hasMore = flags & kDNSServiceFlagsMoreComing > 0
            
            guard error == kDNSServiceErr_NoError
            else {
                guard result.set.contains(proto.other)
                else {
                    // ignore if first protocol (v4/v6)
                    return
                }

                DNSServiceRefDeallocate(service)
                defer { Unmanaged<CallBackData>.fromOpaque(unmanaged!).release() }
                return result.value.isEmpty
                    ? result.cb(.failure(NameResolver.NameNotFound()))
                    : result.cb(.success(result.value))
            }
            
            switch Int32(sa!.pointee.sa_family) {
            case AF_INET:
                sa!.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    result.value.append(NameResolver.IP.v4($0.pointee))
                }
            case AF_INET6:
                sa!.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    result.value.append(NameResolver.IP.v6($0.pointee))
                }
            default:
                preconditionFailure()
            }
            
            guard !hasMore, result.set.contains(proto.other)
            else { return }

            DNSServiceRefDeallocate(service)
            defer { Unmanaged<CallBackData>.fromOpaque(unmanaged!).release() }
            return result.cb(.success(result.value))
        }
        
        let both = DNSServiceProtocol(kDNSServiceProtocol_IPv4 | kDNSServiceProtocol_IPv6)
        guard kDNSServiceErr_NoError == DNSServiceGetAddrInfo(&sdRef,
                                                              kDNSServiceFlagsTimeout
                                                                + kDNSServiceFlagsReturnIntermediates,
                                                              UInt32(kDNSServiceInterfaceIndexAny),
                                                              both,
                                                              host,
                                                              callback,
                                                              u.toOpaque())
        else {
            preconditionFailure()
        }
        DNSServiceSetDispatchQueue(sdRef!, queue)
    }

}
#endif
#endif
