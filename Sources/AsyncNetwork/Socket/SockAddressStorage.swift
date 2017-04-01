//
//  SockAddressStorage.swift
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


internal class SockAddressStorage {

    let _rawStorage: UnsafeMutablePointer<sockaddr_storage>

    var sockaddr: UnsafeMutablePointer<sockaddr> {
        return UnsafeMutablePointer<sockaddr>(OpaquePointer(_rawStorage))
    }

    var sockaddr_in: UnsafeMutablePointer<sockaddr_in> {
        return UnsafeMutablePointer<sockaddr_in>(OpaquePointer(_rawStorage))
    }

    var sockaddr_in6: UnsafeMutablePointer<sockaddr_in6> {
        return UnsafeMutablePointer<sockaddr_in6>(OpaquePointer(_rawStorage))
    }


    init(storage rawStorage: UnsafeMutablePointer<sockaddr_storage>) {
        self._rawStorage = rawStorage
        precondition((try! addressFamily()).isValid(), "Cannot create SockAddressStorage with invalid address family")
    }

    internal func addressFamily() throws -> AddressFamily {
        return try AddressFamily(Int32(_rawStorage.pointee.ss_family))
    }

    public var port: UInt16 {
        let val: UInt16
        switch try! addressFamily() {
        case .inet:
            val = UnsafePointer<sockaddr_in>(OpaquePointer(_rawStorage)).pointee.sin_port
        case .inet6:
            val = UnsafePointer<sockaddr_in6>(OpaquePointer(_rawStorage)).pointee.sin6_port
        default:
            fatalError()
        }
        return (val << 8) + (val >> 8)

    }

    var length: socklen_t {
        switch try! addressFamily() {
        case .inet:
            return socklen_t(MemoryLayout<sockaddr_in>.size)
        case .inet6:
            return socklen_t(MemoryLayout<sockaddr_in6>.size)
        default:
            return 0
        }
    }

    public var ipString: String {

        guard let family = try? addressFamily() else { return "Invalid family" }

        let cfamily = family.value
        let strData: UnsafeMutablePointer<Int8>
        let maxLen: socklen_t

        switch family {
        case .inet:
            maxLen = socklen_t(INET_ADDRSTRLEN)
            strData = UnsafeMutablePointer<Int8>.allocate(capacity: Int(maxLen))
            var ptr = UnsafeMutablePointer<sockaddr_in>(OpaquePointer(_rawStorage)).pointee.sin_addr
            inet_ntop(cfamily, &ptr, strData, maxLen)

        case .inet6:
            maxLen = socklen_t(INET6_ADDRSTRLEN)
            strData = UnsafeMutablePointer<Int8>.allocate(capacity: Int(maxLen))
            var ptr = UnsafeMutablePointer<sockaddr_in6>(OpaquePointer(_rawStorage)).pointee.sin6_addr
            inet_ntop(cfamily, &ptr, strData, maxLen)

        case .unspecified:
            fatalError("Can't create IP From Unspecified Family")
        }

        let testString = String(validatingUTF8: strData)
        strData.deallocate(capacity: Int(maxLen))

        guard let str = testString else {
            return "Invalid IP"
        }

        return str
    }

}
