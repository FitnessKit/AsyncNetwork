//
//  UDPReceiveObserver.swift
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
import Dispatch
import Foundation


public struct UDPReceiveObserver: SocketObserver {

    private let receiveHandler: ((AsyncUDP, Data, InternetAddress) -> Void)?
    private let closeHandler: ((_ socket: AsyncUDP, _ error: SocketError?) -> Void)?
    private let dispatchQueue: DispatchQueue

    private(set) public var uuid: UUID

    public init(
        closeHandler: ((_ socket: AsyncUDP, _ error: SocketError?) -> Void)? = nil,
        receiveHandler: ((_ socket: AsyncUDP, _ data: Data, _ fromAddress: InternetAddress) -> Void)? = nil,
        onQueue: DispatchQueue = DispatchQueue(label: UUID().uuidString)
        ){
        self.closeHandler = closeHandler
        self.receiveHandler = receiveHandler
        self.dispatchQueue = onQueue
        self.uuid = UUID()
    }

    //MARK: - Observers

    public func sockDidClose(_ socket: AsyncUDP, error: SocketError?) {
        dispatchQueue.async { () -> Void in
            self.closeHandler?(socket, error)
        }
    }

    public func socketDidReceive(_ socket: AsyncUDP, data: Data, fromAddress: InternetAddress) {
        dispatchQueue.async {
            self.receiveHandler?(socket, data, fromAddress)
        }
    }

    public func socketDidNotSend(_ socket: AsyncUDP, tag: Int, error: SocketError) {
        //No Op
    }

    public func socketDidSend(_ socket: AsyncUDP, tag: Int) {
        //no Op
    }

}

