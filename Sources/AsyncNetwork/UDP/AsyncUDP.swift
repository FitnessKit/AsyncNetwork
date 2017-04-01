//
//  AsyncUDP.swift
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
import Dispatch
import Foundation

internal struct UdpSocketFlags: OptionSet {
    internal let rawValue: Int
    internal init(rawValue: Int) { self.rawValue = rawValue }

    /** If set, the sockets have been created. */
    internal static let didCreateSockets: UdpSocketFlags        = UdpSocketFlags(rawValue: 1 << 0)
    internal static let didBind: UdpSocketFlags                 = UdpSocketFlags(rawValue: 1 << 1)
    internal static let didConnect: UdpSocketFlags              = UdpSocketFlags(rawValue: 1 << 2)
    internal static let receiveOnce: UdpSocketFlags             = UdpSocketFlags(rawValue: 1 << 3)
    internal static let receiveContinous: UdpSocketFlags        = UdpSocketFlags(rawValue: 1 << 4)
    internal static let sendSourceSuspend: UdpSocketFlags       = UdpSocketFlags(rawValue: 1 << 5)
    internal static let recvSourceSuspend: UdpSocketFlags       = UdpSocketFlags(rawValue: 1 << 6)
    internal static let sockCanAccept: UdpSocketFlags           = UdpSocketFlags(rawValue: 1 << 7)
    internal static let closeAfterSend: UdpSocketFlags          = UdpSocketFlags(rawValue: 1 << 8)
    internal static let multiCastJoined: UdpSocketFlags         = UdpSocketFlags(rawValue: 1 << 9)

}

public let kAsyncUDPSocketSendNoTimeout: TimeInterval = -1.0
public let kAsyncUDPSocketSendNoTag: Int = 0

/// Async UDP
public class AsyncUDP {
    internal var socketQueue: DispatchQueue

    private static var udpQueueIDKey: DispatchSpecificKey<UnsafeMutableRawPointer> = DispatchSpecificKey()

    fileprivate lazy var udpQueueID: UnsafeMutableRawPointer = { [unowned self] in
        unsafeBitCast(self, to: UnsafeMutableRawPointer.self)   // pointer to self
        }()

    //Max Buffer size for Packets
    internal let maxReceiveSize: Int = kMaxBufferSize
    internal var currentSend: AsyncUDPSendPacket?
    internal var sendQueue: [AsyncUDPSendPacket] = []

    internal var socketBytesAvailable: UInt

    internal var sendSource: DispatchSourceWrite?
    internal var receiveSource: DispatchSourceRead?
    internal var sendTimer: DispatchSourceTimer?

    internal var flags: UdpSocketFlags

    fileprivate(set) public var socket: Socket?
    fileprivate(set) var observers = [SocketObserver]()

    public init() {

        self.flags = UdpSocketFlags()
        self.socket = nil

        self.socketBytesAvailable = 0

        //Setup Dispatch

        socketQueue = DispatchQueue(label: "async.upd.queue")
        socketQueue.setSpecific(key: AsyncUDP.udpQueueIDKey, value: udpQueueID)

    }

    deinit {

        socketQueue.sync { () -> Void in
           // self.closeSocketError()
        }
    }

    internal var isCurrentQueue: Bool {
        return DispatchQueue.getSpecific(key: AsyncUDP.udpQueueIDKey) == udpQueueID
    }

}

//MARK: - Observer
public extension AsyncUDP {

    /// Add Observer to the Async UDP
    ///
    /// - Parameter observer: AsyncUDPSocketObserver object
    public func addObserver(_ observer: SocketObserver) {

        self.observers.append(observer)

    }

    /// Remove Observer from Async UDP
    ///
    /// - Parameter observer: AsyncUDPSocketObserver Object
    public func removeObserver(_ observer: SocketObserver) {

        for (idx, obsvr) in observers.enumerated() {
            if obsvr == observer {
                observers.remove(at: idx)
            }
        }
        
    }
}


//MARK: - Close Connection
public extension AsyncUDP {

    /// Close the Async UDP Connection
    public func close() {

        let block = DispatchWorkItem {

            self.closeSocket()
        }

        socketQueue.sync(execute: block)

    }

    internal func closeSocket(withError error: SocketError? = nil) {
        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            return
        }

        let shouldCallDelegate: Bool = flags.contains(.didCreateSockets) ? true : false

        if shouldCallDelegate {
            //notify close!
            for observer in observers {
                //Observer decides which queue it will send back on
                observer.sockDidClose(self, error: error)
            }
        }

        closeSocketFinal()

        flags.remove(.didCreateSockets)

        flags = UdpSocketFlags()
    }

    internal func closeSocketFinal() {

        if socket?.isValid == true {


            if let sSource = sendSource,
                let rSource = receiveSource {
                sSource.cancel()

                rSource.cancel()

                //Make sure they are not paused...
                //resumeSendSource()
                resumeReceive()

                //clear States
                socketBytesAvailable = 0
                flags.remove(.sockCanAccept)
                
            }

            //Try and Close the Socket
            do {
                try socket?.close()
            } catch  {
                //
            }

            socket = nil

        }
    }
}

//MARK: - Control
public extension AsyncUDP {

    /// Binds Socket to Address
    ///
    /// - Parameters:
    ///   - address: Address to Bind to.  Typically AnyAddr to allow receiving on all interfaces
    ///   - options: Binding Options
    /// - Throws: Throws Error if issue with binding
    public func bind(address: InternetAddress, options: SocketOptions = [.reusePort]) throws {
        
        var errorCode: SocketError?

        let block = DispatchWorkItem {

            do {
                //Do the Pre Bind Checks
                try self.preBindCheck()

            } catch {
                errorCode = (error as? SocketError)!
                return
            }

            let config = SocketConfig.UDP(family: address.addressFamily)

            do {
                //Try and Create the Socket
                try self.socket = Socket.create(withAddress: address, withConfig: config, options: options)
                _ = self.flags.insert(.didCreateSockets)

            } catch  {
                errorCode = (error as? SocketError)!
                return
            }

            do {

                try self.socket?.bind()
                _ = self.flags.insert(.didBind)

            } catch  {
                errorCode = (error as? SocketError)!
                return

            }

            self.setupSendReceiveSources()
        }


        if isCurrentQueue == true {
            block.perform()
        }else {
            socketQueue.sync(execute: block)
        }

        if let error = errorCode {
            throw error
        }

    }

    fileprivate func preBindCheck() throws {
        //Pre-check if we can Bind
        guard isCurrentQueue == true else {
            //assertionFailure("Must be dispatched on Socket Queue")
            throw SocketError(.dispatchFail(msg: "Must be dispatched on Socket Queue"))
        }

        guard flags.contains(.didBind) == false else {
            throw SocketError(.alreadyBound(msg: "Cannot bind a socket more than once."))
        }

        guard flags.contains([.didConnect]) == false else {
            throw SocketError(.alreadyConnected(msg: "Cannot bind after connect."))
        }
    }
}


fileprivate extension AsyncUDP {

    func setupSendReceiveSources()  {
        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            return
        }

        let newSendSource = DispatchSource.makeWriteSource(fileDescriptor: (self.socket?.fd)!, queue: socketQueue)
        let newReceiveSource = DispatchSource.makeReadSource(fileDescriptor: (self.socket?.fd)!, queue: socketQueue)

        //Setup event handlers
        //Send Handler
        newSendSource.setEventHandler { () -> Void in
            _ = self.flags.insert(.sockCanAccept)

            if self.currentSend == nil {

                self.suspendSendSource()

            } else if self.currentSend?.resolveInProgress == true {

                self.suspendSendSource()

            } else {
                self.doSend()
            }

        }

        //Receive Handler
        newReceiveSource.setEventHandler { () -> Void in

            self.socketBytesAvailable = newReceiveSource.data

            if self.socketBytesAvailable > 0 {
                self.doReceive()
            } else {
                self.doReceiveEOF()
            }
            
        }

        //Cancel Handlers
        var socketFDRefCount: Int = 2

        newSendSource.setCancelHandler { () -> Void in
            socketFDRefCount -= 1

            if socketFDRefCount == 0 {

                do {
                    try self.socket?.close()
                } catch {

                }
            }
        }

        newReceiveSource.setCancelHandler { () -> Void in
            socketFDRefCount -= 1

            if socketFDRefCount == 0 {
                do {
                    try self.socket?.close()
                } catch {

                }
            }
        }

        socketBytesAvailable = 0

        _ = flags.insert([.sockCanAccept, .sendSourceSuspend, .recvSourceSuspend])

        sendSource = newSendSource
        receiveSource = newReceiveSource

    }
}
