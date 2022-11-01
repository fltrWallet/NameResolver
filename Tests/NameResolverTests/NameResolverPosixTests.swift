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
import NameResolverPosix
import NIOCore
import NIOPosix
import XCTest

final class NameResolverPosixTests: XCTestCase {
    var elg: MultiThreadedEventLoopGroup!
    var eventLoop: EventLoop!
    var threadPool: NIOThreadPool!
    var resolver: NameResolver!
    
    override func setUp() {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.eventLoop = self.elg.next()
        self.threadPool = NIOThreadPool(numberOfThreads: 1)
        self.threadPool.start()
        self.resolver = .posix(threadPool: self.threadPool)
    }
    
    override func tearDown() {
        self.resolver = nil
        XCTAssertNoThrow(try self.threadPool.syncShutdownGracefully())
        XCTAssertNoThrow(try self.elg.syncShutdownGracefully())
    }
    
    func testLoopbackSuccess() {
        guard var result = try? self.resolver.lookup(address: "localhost",
                                                eventLoop: self.eventLoop).wait()
        else {
            XCTFail()
            return
        }
        
        XCTAssert(!result.isEmpty)
        
        while let last = result.popLast() {
            guard last == .v4(.loopback) || last == .v6(.loopback)
            else {
                XCTFail()
                return
            }
        }
    }
    
    func testNotFound() {
        XCTAssertThrowsError(try self.resolver.lookup(address: "something that would never resolve 🤢",
                                                      eventLoop: self.eventLoop).wait()) {
            switch $0 {
            case let error where error is NameResolver.NameNotFound:
                break
            default:
                XCTFail()
                return
            }
        }
    }
}
