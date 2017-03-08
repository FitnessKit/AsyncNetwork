//
//  Shims.swift
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
#else
    import Darwin
#endif

internal typealias as_dispatch_block_t = (Void)->Void


public typealias Descriptor = Int32
public typealias Port = UInt16


public enum SocketType {
    case stream
    case dataGram

    public var value: Int32  {

        switch self {
        case .stream:
            #if os(Linux)
                return Int32(SOCK_STREAM.rawValue)
            #else
                return SOCK_STREAM
            #endif

        case .dataGram:
            #if os(Linux)
                return Int32(SOCK_DGRAM.rawValue)
            #else
                return SOCK_DGRAM
            #endif

        }
    }
}

public enum Protocol {
    case TCP
    case UDP

    public var value: Int32 {
        switch self {
        case .TCP:
            return Int32(IPPROTO_TCP)
        case .UDP:
            return Int32(IPPROTO_UDP)
        }
    }

    public func ipProto(family: AddressFamily) -> Int32 {
        switch self {
        case .UDP:
            #if os(Linux)
                return Int32(IPPROTO_UDP)
            #else
                return IPPROTO_UDP
            #endif

        default:
            switch family {
            case .inet6:
                #if os(Linux)
                    return Int32(IPPROTO_IPV6)
                #else
                    return IPPROTO_IPV6
                #endif

            default:
                #if os(Linux)
                    return Int32(IPPROTO_IP)
                #else
                    return IPPROTO_IP
                #endif

            }
        }
    }
}


// Defining the space to which the address belongs
public enum AddressFamily {
    case inet           // IPv4
    case inet6          // IPv6
    case unspecified    // We will determine based on Resolution

    public var value: Int32 {
        switch self {
        case .inet:
            return Int32(AF_INET)
        case .inet6:
            return Int32(AF_INET6)
        case .unspecified :
            return Int32(AF_UNSPEC)
        }
    }

    init(_ family: Int32) throws {
        switch family {
        case Int32(AF_INET):
            self = .inet
        case Int32(AF_INET6):
            self = .inet6
        case Int32(AF_UNSPEC):
            self = .unspecified
        default:
            throw SocketError(.unsupportedAddressFamily(family))
        }
    }

    func isValid() -> Bool {
        switch self {
        case .inet,
             .inet6:
            return true
        case .unspecified:
            return false
        }
    }
}


public extension AddressFamily {

    public var mcastJoinValue: Int32 {
        switch self {
        case .inet6:
            return Int32(IPV6_JOIN_GROUP)
        default:
            return Int32(IP_ADD_MEMBERSHIP)

        }
    }

    public var mcastLeaveValue: Int32 {
        switch self {
        case .inet6:
            return Int32(IP_DROP_MEMBERSHIP)
        default:
            return Int32(IPV6_LEAVE_GROUP)

        }
    }

}
