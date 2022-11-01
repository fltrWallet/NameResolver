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
@_exported import NameResolverAPI
import Foundation

public extension NameResolver {
    static var live: Self {
        .init { address, callback in
            NameResolver.lookup(address, outerCB: { cbHandler in
                guard let result = cbHandler.result
                else { preconditionFailure() }

                switch result {
                case .success(let cfArray):
                    callback(.success(NameResolver.parse(cfArray)))
                case .failure(DNSError.noResult):
                    callback(.failure(NameResolver.NameNotFound()))
                case .failure(let error):
                    callback(.failure(error))
                }
            })
        }
    }
}

extension NameResolver {
    @usableFromInline
    static func parse(_ array: CFArray) -> [NameResolver.IP] {
        let nsArray = array as NSArray
        return nsArray
        .map({ $0 as! NSData })
        .map { data in
            var storage = sockaddr_storage()
            data.getBytes(&storage, length: data.length)

            switch Int32(storage.ss_family) {
            case AF_INET:
                return withUnsafePointer(to: &storage) {
                    $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                        .v4($0.pointee)
                    }
                }
            case AF_INET6:
                return withUnsafePointer(to: &storage) {
                    $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                        .v6($0.pointee)
                    }
                }
            default:
                preconditionFailure()
            }
        }
    }
}

extension NameResolver {
    enum DNSError: Swift.Error {
        case error(CFStreamError)
        case noResult
    }
    
    @usableFromInline
    class CallBackHandler {
        let callback: (CallBackHandler) -> Void
        var result: Result<CFArray, NameResolver.DNSError>?
        
        init(callback: @escaping (CallBackHandler) -> Void) {
            self.callback = callback
            self.result = nil
        }
    }
    
    @usableFromInline
    static func lookup(_ address: String, outerCB: @escaping (CallBackHandler) -> Void) -> Void {
        let cbResult = CallBackHandler(callback: outerCB)
        let pointer = Unmanaged.passRetained(cbResult).toOpaque()
        var context = CFHostClientContext(version: 0,
                                          info: pointer,
                                          retain: nil,
                                          release: nil,
                                          copyDescription: nil)
        
        let callBack: CFHostClientCallBack = { host, _, errorOptional, contextOptional in
            guard let context = contextOptional
            else { preconditionFailure() }
            
            let cbResult = Unmanaged<CallBackHandler>
                .fromOpaque(context)
                .takeRetainedValue()
            
            if let error = errorOptional,
               error.pointee.error > 0 {
                switch (Int32(error.pointee.domain), error.pointee.error) {
                case (kCFStreamErrorDomainNetDB, 8):
                    cbResult.result = .failure(.noResult)
                default:
                    cbResult.result = .failure(.error(error.pointee))
                    return cbResult.callback(cbResult)
                }
                
            }
            
            var resolved: DarwinBoolean = false
            guard let raw = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue(),
                  resolved.boolValue
            else {
                cbResult.result = .failure(DNSError.noResult)
                return cbResult.callback(cbResult)
            }
            
            cbResult.result = .success(raw)
            return cbResult.callback(cbResult)
        }
        let hostReference = CFHostCreateWithName(nil, address as CFString).takeRetainedValue()
        CFHostSetClient(hostReference, callBack, &context)
        
        Thread {
            CFHostScheduleWithRunLoop(hostReference,
                                      CFRunLoopGetCurrent(),
                                      CFRunLoopMode.defaultMode.rawValue)
            RunLoop.current.run(mode: .default, before: .distantFuture)
            Thread.exit()
        }
        .start()
        
        var error = CFStreamError()
        CFHostStartInfoResolution(hostReference, .addresses, &error)
    }
}
#endif
