//
//  AsyncUDPSendPacket.swift
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
import Foundation


internal class AsyncUDPSendPacket {

    internal var resolveInProgress: Bool = false

    internal var resolvedAddress: SockAddressStorage?
    internal var resolvedError: SocketError?
    internal var resolvedFamily: AddressFamily = .inet

    internal let buffer: Data
    internal let timeout: TimeInterval
    internal let tag: Int

    internal init(data: Data, timeout: TimeInterval = kAsyncUDPSocketSendNoTimeout, tag: Int = kAsyncUDPSocketSendNoTag) {

        self.buffer = data
        self.timeout = timeout
        self.tag = tag

        self.resolveInProgress = false

    }
}

internal func ==(lhs: AsyncUDPSendPacket, rhs: AsyncUDPSendPacket) -> Bool {
    return lhs.buffer == rhs.buffer
}
