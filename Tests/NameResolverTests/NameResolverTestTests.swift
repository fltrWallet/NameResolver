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
import NameResolverTest
import Network
import NIOCore
import NIOPosix
import XCTest

final class NameResolverTestTests: XCTestCase {
    var elg: MultiThreadedEventLoopGroup!
    var eventLoop: EventLoop!

    override func setUp() {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.eventLoop = self.elg.next()
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try self.elg.syncShutdownGracefully())
    }
    
    func testLocalhost() {
        let resolver = NameResolver.localhost
        let e = expectation(description: "")
        resolver.lookup(address: "something that would never resolve 🤢") {
            switch $0 {
            case .success(let versions):
                XCTAssertEqual(versions, [.v4(.loopback)])
            case .failure(let error):
                XCTFail("\(error)")
            }
            e.fulfill()
        }
        wait(for: [e], timeout: 2.0)
    }
    
    func testLocalhostNIO() {
        XCTAssertNoThrow(
            XCTAssertEqual(
                try NameResolver.localhost.lookup(address: "something else 🙊",
                                                  eventLoop: self.eventLoop)
                    .wait(),
                [.v4(.loopback)]
            )
        )
    }
    
    func testAlwaysFail() {
        let resolver = NameResolver.fail
        let e = expectation(description: "")
        resolver.lookup(address: "localhost") {
            switch $0 {
            case .failure(let error) where error is NameResolver.AlwaysFail:
                break
            default:
                XCTFail()
            }
            e.fulfill()
        }
        wait(for: [e], timeout: 2.0)
    }
    
    func testAlwaysFailNIO() {
        XCTAssertThrowsError(
            try NameResolver.fail.lookup(address: "localhost",
                                         eventLoop: self.eventLoop)
                .wait()
        ) {
            switch $0 {
            case let error where error is NameResolver.AlwaysFail:
                break
            default:
                XCTFail()
            }
        }
    }
    
    func testAsIPv4() {
        let ip = NameResolver.IP.v4(IPv4Address.allReportsGroup)
        XCTAssertEqual(ip.asIPv4, IPv4Address.allReportsGroup)
        XCTAssertNotEqual(ip.asIPv4, IPv4Address.allHostsGroup)
        XCTAssertNotEqual(ip.asIPv6, IPv6Address.linkLocalNodes)
    }

    func testAsIPv6() {
        let ip = NameResolver.IP.v6(IPv6Address.linkLocalNodes)
        XCTAssertEqual(ip.asIPv6, IPv6Address.linkLocalNodes)
    }

    func testMappedv6() {
        let ip = NameResolver.IP.v4(IPv4Address.allRoutersGroup).asIPv6
        XCTAssertEqual(ip.asIPv4, IPv4Address.allRoutersGroup)
    }
    
    func testIsv6Loopback() {
        let ip = NameResolver.IP.v4(IPv4Address.loopback).asIPv6
        XCTAssert(ip.isLoopback)
        XCTAssertEqual(ip, IPv6Address.loopback)
    }
    
    func testEquatable() {
        XCTAssertEqual(
            NameResolver.IP.v4(IPv4Address("127.0.0.1")!),
            NameResolver.IP.v4(IPv4Address("127.0.0.1")!)
        )
        XCTAssertNotEqual(
            NameResolver.IP.v4(IPv4Address("127.0.0.1")!),
            NameResolver.IP.v4(IPv4Address("127.0.0.2")!)
        )
        XCTAssertEqual(
            NameResolver.IP.v6(IPv6Address("::abcd:abcd:abcd:1")!),
            NameResolver.IP.v6(IPv6Address("::abcd:abcd:abcd:1")!)
        )
        XCTAssertNotEqual(
            NameResolver.IP.v6(IPv6Address("::abcd:abcd:abcd:1")!),
            NameResolver.IP.v6(IPv6Address("::abcd:abcd:abcd:2")!)
        )
    }
}
