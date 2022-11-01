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
@testable import NameResolverMDNS
import NIOCore
import NIOPosix
import XCTest

final class NameResolverMDNSTests: XCTestCase {
    var elg: MultiThreadedEventLoopGroup!
    var eventLoop: EventLoop!
    var threadPool: NIOThreadPool!
    var resolver: NameResolver!
    
    override func setUp() {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.eventLoop = self.elg.next()
        self.threadPool = NIOThreadPool(numberOfThreads: 1)
        self.threadPool.start()
        self.resolver = .dnssd
    }
    
    override func tearDown() {
        self.resolver = nil
        XCTAssertNoThrow(try self.threadPool.syncShutdownGracefully())
        XCTAssertNoThrow(try self.elg.syncShutdownGracefully())
    }
    
    func testLocalhostSuccess() {
        let e = expectation(description: "")
        self.resolver.lookup(address: "localhost") {
            switch $0 {
            case .success([.v4(.loopback)]),
                 .success([.v6(.loopback)]),
                 .success([.v4(.loopback), .v6(.loopback)]),
                 .success([.v6(.loopback), .v4(.loopback)]):
                break
            default:
                XCTFail()
            }
            e.fulfill()
        }
        wait(for: [e], timeout: 2.0)
    }
    
    func testLocalhostSuccessNIO() {
        guard var versions = try? self.resolver.lookup(address: "localhost",
                                                       eventLoop: self.eventLoop)
            .wait()
        else {
            XCTFail()
            return
        }
        
        XCTAssert(!versions.isEmpty)

        while let last = versions.popLast() {
            guard last == .v4(.loopback) || last == .v6(.loopback)
            else {
                XCTFail()
                return
            }
        }
    }
    
    func testNotFound() {
        let e = expectation(description: "")
        self.resolver.lookup(address: "something that would never resolve 🤢") {
            switch $0 {
            case .failure(let error) where error is NameResolver.NameNotFound:
                break
            default:
                XCTFail()
            }
            e.fulfill()
        }
        wait(for: [e], timeout: 2.0)
    }

    func testNotFoundNIO() {
        XCTAssertThrowsError(
            try self.resolver.lookup(address: "something that would never resolve 🤢",
                                     eventLoop: self.eventLoop).wait()
        ) {
            switch $0 {
            case let error where error is NameResolver.NameNotFound:
                break
            default:
                XCTFail()
            }
        }
    }
}
