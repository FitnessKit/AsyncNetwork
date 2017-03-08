//
//  InternetAddress.swift
//  AsyncNetwork
//
//  Created by Kevin Hoogheem on 3/4/17.
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
    typealias socket_addrinfo = Glibc.addrinfo
#else
    import Darwin
    typealias socket_addrinfo = Darwin.addrinfo
#endif


public struct InternetAddress {

    public let hostname: String
    public let port: Port
    public let addressFamily: AddressFamily

    public init(hostname: String, port: Port, family: AddressFamily = .unspecified) {
        self.hostname = hostname
        self.port = port
        addressFamily = family
    }

    /// Creates the Localhost Internet Address
    ///
    /// - Parameters:
    ///   - port: Port
    ///   - family: Address Faily
    /// - Returns: An Instance of Internet Address
    static public func localHost(port: Port, family: AddressFamily = .inet) -> InternetAddress {
        let hostname: String
        let proto: AddressFamily

        switch family {
        case .inet6:
            hostname = "::1"
            proto = .inet
        default:
            //Otherwise use IPV4
            hostname = "127.0.0.1"
            proto = .inet
        }

        return InternetAddress(hostname: hostname, port: port, family: proto)
    }

    /// Creates the AnyAddr Internet Address
    ///
    ///  This address will bind to all Interfaces on the device
    ///
    /// - Parameters:
    ///   - port: Port Number
    ///   - family: Address Family
    /// - Returns: An Instance of Internet Address
    static public func anyAddr(port: Port, family: AddressFamily) -> InternetAddress {
        let hostname: String
        let proto: AddressFamily

        switch family {
        case .inet6:
            hostname = "::"
            proto = .inet
        default:
            //Otherwise use IPV4
            hostname = "0.0.0.0"
            proto = .inet
        }

        return InternetAddress(hostname: hostname, port: port, family: proto)
    }
}

internal extension InternetAddress {

    func resolveAddress(with config: inout SocketConfig) throws -> SockAddressStorage {

        var hints = socket_addrinfo.init()
        hints.ai_family = config.addressFamily.value
        hints.ai_flags = AI_PASSIVE
        hints.ai_socktype = config.socketType.value
        hints.ai_protocol = config.protocolType.value

        var addressInfo: UnsafeMutablePointer<socket_addrinfo>? = nil

        let getReturn = getaddrinfo(self.hostname, String(self.port), &hints, &addressInfo)

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

        // Adjust SocketConfig with the resolved address family
        config.addressFamily = try address.addressFamily()

        return address
    }
}
