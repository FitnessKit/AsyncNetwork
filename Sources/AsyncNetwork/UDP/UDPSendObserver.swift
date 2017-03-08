//
//  UDPSendObserver.swift
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
import Dispatch
import Foundation


public struct UDPSendObserver: SocketObserver {

    private let didSendHandler: ((_ socket: AsyncUDP, _ tag: Int) -> Void)?
    private let didNotSendHandler: ((_ socket: AsyncUDP, _ tag: Int, _ error: SocketError) -> Void)?
    private let dispatchQueue: DispatchQueue

    private(set) public var uuid: UUID

    public init(
        didSend: ((_ socket: AsyncUDP, _ tag: Int) -> Void)? = nil,
        didNotSend: ((_ socket: AsyncUDP, _ tag: Int, _ error: SocketError) -> Void)? = nil,
        onQueue: DispatchQueue = DispatchQueue.main
        ) {

        self.didSendHandler = didSend
        self.didNotSendHandler = didNotSend
        self.dispatchQueue = onQueue

        self.uuid = UUID()
    }


    //MARK: - Observers

    public func sockDidClose(_ socket: AsyncUDP, error: SocketError?) {
        //no Op
    }

    public func socketDidReceive(_ socket: AsyncUDP, data: Data, fromAddress: InternetAddress) {
        //no Op
    }

    public func socketDidNotSend(_ socket: AsyncUDP, tag: Int, error: SocketError) {
        dispatchQueue.async { () -> Void in
            self.didNotSendHandler?(socket, tag, error)
        }
    }

    public func socketDidSend(_ socket: AsyncUDP, tag: Int) {
        dispatchQueue.async { () -> Void in
            self.didSendHandler?(socket, tag)
        }
    }

}

