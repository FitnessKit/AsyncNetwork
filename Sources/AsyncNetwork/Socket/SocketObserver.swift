//
//  SocketObserver.swift
//  AsyncNetwork
//
//  Created by Kevin Hoogheem on 3/7/17.
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
import Foundation

public protocol SocketObserver {

    var uuid: UUID { get }

    func socketDidReceive(_ socket: AsyncUDP, data: Data, fromAddress: InternetAddress)

    func sockDidClose(_ socket: AsyncUDP, error: SocketError?)

    //Send Errors
    func socketDidNotSend(_ socket: AsyncUDP, tag: Int, error: SocketError)

    func socketDidSend(_ socket: AsyncUDP, tag: Int)

}

public func ==(lhs: SocketObserver, rhs: SocketObserver) -> Bool {
    return lhs.uuid.uuidString == rhs.uuid.uuidString
}


//public func ==<T :AsyncUDPSocketObserver> (lhs: T, rhs: T) -> Bool {
//    return lhs.uuid.UUIDString == rhs.uuid.UUIDString
//}

extension SocketObserver {

    public var hashValue: Int {
        get {
            return uuid.uuidString.hashValue
        }
    }
}
