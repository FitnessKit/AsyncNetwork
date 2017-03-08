//
//  Socket.swift
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
    private let sock_socket     = Glibc.socket
    private let sock_close      = Glibc.close
    private let socket_bind     = Glibc.bind
    private let socket_recvfrom = Glibc.recvfrom
    private let socket_sendto   = Glibc.sendto
#else
    import Darwin
    private let sock_socket     = Darwin.socket
    private let sock_close      = Darwin.close
    private let socket_bind     = Darwin.bind
    private let socket_recvfrom = Darwin.recvfrom
    private let socket_sendto   = Darwin.sendto
#endif


/// Invalid Socket
public let invalidSocket = Descriptor(-1)
public let kMaxBufferSize = 65_507


public struct SocketReceiveOptions: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// NO Flags should be set
    public static let none: SocketReceiveOptions        = SocketReceiveOptions(rawValue: 0)
    /// Receive Out of Band Data
    public static let outOfBand: SocketReceiveOptions   = SocketReceiveOptions(rawValue: MSG_OOB)
    /// Peek at the data.  Does not actually receive the data.. Just a preview
    public static let peek: SocketReceiveOptions        = SocketReceiveOptions(rawValue: MSG_PEEK)
    /// Wait until all of the data is present
    public static let waitAll: SocketReceiveOptions     = SocketReceiveOptions(rawValue: MSG_WAITALL)
}

public struct SocketSendOptions: OptionSet {
    public let rawValue: Int32
    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// NO Flags should be set
    public static let none: SocketSendOptions           = SocketSendOptions(rawValue: 0)
    /// Send Data as Out of Band
    public static let outOfBand: SocketSendOptions      = SocketSendOptions(rawValue: MSG_OOB)
    /// Don't Route Message Over Router.  Keep on Local Network
    public static let dontRoute: SocketSendOptions      = SocketSendOptions(rawValue: MSG_DONTROUTE)
}

public struct Socket {

    public let fd: Descriptor
    public let family: AddressFamily
    public let config: SocketConfig

    internal let address: SockAddressStorage

    public var isValid: Bool { return self.fd != invalidSocket }


    fileprivate init(fd: Descriptor, family: AddressFamily = .unspecified, sockStorage: SockAddressStorage, config: SocketConfig) {
        self.fd = fd
        self.family = family
        self.address = sockStorage
        self.config = config
    }

}

//MARK: - Creation of Socket
public extension Socket {

    static public func create(withAddress address: InternetAddress, withConfig config: SocketConfig, options: SocketOptions = [.reusePort]) throws -> Socket {

        var cfg = config

        //Resolve
        let address = try address.resolveAddress(with: &cfg)

        let protoFamily = cfg.addressFamily.value
        let sockType = cfg.socketType.value
        let proto = cfg.protocolType.value

        let descriptor = sock_socket(protoFamily, sockType, proto)
        guard descriptor >= 0 else { throw SocketError(.createSocketFail) }

        let socket = Socket(fd: descriptor, family: config.addressFamily, sockStorage: address, config: cfg)

        let reuseAddr = socket.setReuseAddr()
        guard reuseAddr != false else { throw SocketError(.setSocketOptionFail(msg: "Couldn't enable Reuse Address")) }

        if options.contains(.reusePort) {
            let reusePort = socket.setReusePort()
            guard reusePort != false else { throw SocketError(.setSocketOptionFail(msg: "Couldn't enable Reuse Port")) }
        }

        if options.contains(.enableBroadcast) {
            let broadcast = socket.setEnableBroadcast()
            guard broadcast != false else { throw SocketError(.setSocketOptionFail(msg: "Couldn't enable Broadcast")) }
        }

        let sigPipe = socket.disableSigPipe()
        guard sigPipe != false else { throw SocketError(.setSocketOptionFail(msg: "Couldn't disable SIGPipe")) }

        return socket
    }

}

//MARK: - Socket Control
public extension Socket {

    public func bind() throws {
        guard socket_bind(self.fd, address.sockaddr, address.length) > -1 else { throw SocketError(.socketBindFail) }
    }


    public func close() throws {
        if sock_close(self.fd) != 0 {
            throw SocketError(.closeSocketFail)
        }
    }

    public func receivefrom(maxBytes: Int = kMaxBufferSize, options: SocketReceiveOptions = .none) throws -> (data: [UInt8], sender: InternetAddress) {
        if self.isValid == false { throw SocketError(.socketIsClosed) }

        let data = [UInt8](repeating: 0, count: maxBytes)

        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let addr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
        let addrSockAddr = UnsafeMutablePointer<sockaddr>(OpaquePointer(addr))

        let recvOps = options.rawValue

        let receivedBytes = socket_recvfrom(self.fd,
                                            UnsafeMutableRawPointer(mutating: data),
                                            data.capacity,
                                            recvOps,
                                            addrSockAddr,
                                            &length)
        
        guard receivedBytes > -1 else {
            addr.deallocate(capacity: 1)
            throw SocketError(.readFailed)
        }

        let clientAddress = SockAddressStorage(storage: addr)

        let finalBytes = data[0..<receivedBytes]
        let out = Array(finalBytes)

        let iNet = InternetAddress(hostname: clientAddress.ipString, port: clientAddress.port)
        return (data: out, sender: iNet)
    }


    /// Sends Data over the socket
    ///
    /// - Parameters:
    ///   - data: Data To Send
    ///   - host: Internet Host to send data to
    ///   - sendOptions: Send Options flags
    /// - Returns: Length of Sent Data
    /// - Throws: Throws SocketError if error in sending
    public func send(data: [UInt8], toHost host: InternetAddress?, sendOptions: SocketSendOptions = .none) throws -> Int{
        if self.isValid == false { throw SocketError(.socketIsClosed) }

        var destAddress = address

        if let rHost = host {
            var cfg = config
            destAddress = try rHost.resolveAddress(with: &cfg)
        }

        let len = try send(data: data, toResolvedHost: destAddress)

        return len
    }
}

//MARK - Internal Controls
internal extension Socket {

    internal func send(data: [UInt8], toResolvedHost dest: SockAddressStorage, sendOptions: SocketSendOptions = .none) throws -> Int {

        let sendOps = sendOptions.rawValue

        let sentLength = socket_sendto(self.fd,
                                       data,
                                       data.count,
                                       sendOps,
                                       dest.sockaddr,
                                       dest.length)

        guard sentLength == data.count else { throw SocketError(.sendFailed) }

        return sentLength
    }

}

//MARK: - Socket Options
internal extension Socket {


    /// Sets the Socket to Non Blocking mode
    ///
    /// - Returns: Bool Eval
    func setSocketNonBlocking() -> Bool {
        guard self.fd != invalidSocket else {
            return false
        }

        var currentFlags = fcntl(self.fd, F_GETFL)

        if currentFlags < 0 {
            return false
        }

        currentFlags |= O_NONBLOCK

        if fcntl(self.fd, currentFlags) < 0 {
            return false
        }

        return true
    }


    func setReuseAddr() -> Bool {
        var reuseAddr: UInt32 = 1

        let status = setsockopt(self.fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, UInt32(MemoryLayout<socklen_t>.size))

        if status == -1 {
            _ = sock_close(self.fd)
            return false
        }

        return true
    }


    func setReusePort() -> Bool {
        var reusePort: UInt32 = 1

        let status = setsockopt(self.fd, SOL_SOCKET, SO_REUSEPORT, &reusePort, UInt32(MemoryLayout<socklen_t>.size))

        if status == -1 {
            _ = sock_close(self.fd)
            return false
        }

        return true
    }


    func setEnableBroadcast() -> Bool {
        var enableBroadcast: UInt32 = 1

        let status = setsockopt(self.fd, SOL_SOCKET, SO_BROADCAST, &enableBroadcast, UInt32(MemoryLayout<socklen_t>.size))

        if status == -1 {
            _ = sock_close(self.fd)
            return false
        }

        return true
    }

    func disableSigPipe() -> Bool {

        #if os(OSX)
            var noSigPipe: UInt32 = 1

            let status = setsockopt(self.fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, UInt32(MemoryLayout<socklen_t>.size))

            if status == -1 {
                _ = sock_close(self.fd)
                return false
            }
        #endif

        return true
    }

}
