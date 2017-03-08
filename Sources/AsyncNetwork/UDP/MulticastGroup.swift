//
//  MulticastGroup.swift
//  AsyncNetwork
//
//  Created by Kevin Hoogheem on 3/5/17.
//
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif


public struct MulticastGroup {

    public let group: String
    public let family: AddressFamily

    public init(group: String, family: AddressFamily = .inet) {
        self.group = group

        //TODO: think about checking that it is not unspec
        self.family = family
    }


    /// All Hosts on the same Network Segment
    ///
    /// - Parameter family: Address Family
    /// - Returns: An Instance of Multicast Group
    static public func allHosts(family: AddressFamily = .inet) -> MulticastGroup {
        let group: String
        let proto: AddressFamily

        switch family {
        case .inet6:
            group = "ff02::1"
            proto = .inet
        default:
            //Otherwise use IPV4
            group = "224.0.0.1"
            proto = .inet
        }

        return MulticastGroup(group: group, family: proto)
    }

    /// Multicast DNS (mDNS)
    ///
    /// Bind to Port: 5353
    ///
    /// - Parameter family: Address Family
    /// - Returns: An Instance of Multicast Group
    static public func mDNS(family: AddressFamily = .inet) -> MulticastGroup {
        let group: String
        let proto: AddressFamily

        switch family {
        case .inet6:
            group = "FF02::FB"
            proto = .inet
        default:
            //Otherwise use IPV4
            group = "224.0.0.251"
            proto = .inet
        }

        return MulticastGroup(group: group, family: proto)
    }

    /// Network Time Protocol (NTP)
    ///
    /// Bind to Port: 123
    ///
    /// - Parameter family: Address Family
    /// - Returns: An Instance of Multicast Group
    static public func networkTimeProtocol(family: AddressFamily = .inet) -> MulticastGroup {
        let group: String
        let proto: AddressFamily

        switch family {
        case .inet6:
            group = "FF0X::101"
            proto = .inet
        default:
            //Otherwise use IPV4
            group = "224.0.1.1"
            proto = .inet
        }

        return MulticastGroup(group: group, family: proto)
    }
}

internal extension MulticastGroup {

    func resolveGroup() throws -> SockAddressStorage {
        var hints = socket_addrinfo.init()
       // hints.ai_flags = AI_NUMERICHOST         //no name resolution
        hints.ai_family = self.family.value
        hints.ai_flags = AI_PASSIVE
        hints.ai_socktype = SocketType.dataGram.value
        hints.ai_protocol = Protocol.UDP.value

        var addressInfo: UnsafeMutablePointer<socket_addrinfo>?

        let getReturn = getaddrinfo(self.group, UnsafePointer<Int8>(bitPattern: 0), &hints, &addressInfo)

        guard getReturn == 0 else {
            let reason = String(validatingUTF8: gai_strerror(getReturn)) ?? "unknown"
            throw SocketError(.addressValidationFail(msg: reason))
        }

        guard let addrList = addressInfo else { throw SocketError(.addressResolutionFail) }
        defer {
            freeaddrinfo(addrList)
        }

        guard let addrInfo = addrList.pointee.ai_addr else { throw SocketError(.addressResolutionFail) }

        let family = try AddressFamily(Int32(addrInfo.pointee.sa_family))

        let ptr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
        ptr.initialize(to: sockaddr_storage())

        switch family {
        case .inet:
            let addr = UnsafeMutablePointer<sockaddr_in>.init(OpaquePointer(addrInfo))!
            let specPtr = UnsafeMutablePointer<sockaddr_in>(OpaquePointer(ptr))
            specPtr.assign(from: addr, count: 1)

        case .inet6:
            let addr = UnsafeMutablePointer<sockaddr_in6>(OpaquePointer(addrInfo))!
            let specPtr = UnsafeMutablePointer<sockaddr_in6>(OpaquePointer(ptr))
            specPtr.assign(from: addr, count: 1)

        default:
            throw SocketError(.invalidAddressFamilyType)
        }

        let address = SockAddressStorage(storage: ptr)

        return address
    }
}
