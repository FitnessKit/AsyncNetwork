//
//  AsyncUDP+Receive.swift
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

public extension AsyncUDP {

    /// Continous Receive of the UDP Packets
    ///
    /// - Throws: Throws SocketError if error condition
    public func beginReceiving() throws {
        var errorCode: SocketError?

        let block: as_dispatch_block_t = {

            if self.flags.contains(.receiveContinous) == false {

                if self.flags.contains(.didBind) == false {
                    errorCode = SocketError(.notBound(msg: "Must bind a socket prior to receiving."))
                    return
                }

                //Remove Receive once if set
                self.flags.remove(.receiveOnce)
                _ = self.flags.insert(.receiveContinous)

                self.socketQueue.async {
                    self.doReceive()
                }

            }

        }

        if isCurrentQueue == true {
            block()
        } else {
            socketQueue.sync(execute: block)
        }

        if let errors = errorCode {
            throw errors
        }
    }


    /// Receives One UDP Message at a time
    ///
    /// - Throws: Throws SocketError if error condition
    public func receiveOnce() throws {
        var errorCode: SocketError?

        let block: as_dispatch_block_t = {

            if self.flags.contains(.receiveContinous) == true {
                errorCode = SocketError(.alreadyReceiving(msg: "Already Receiving Data.  Must pause prior to calling receiveOnce"))
                return
            }

            if self.flags.contains(.receiveOnce) == false {

                if self.flags.contains(.didCreateSockets) == false {
                    errorCode = SocketError(.notBound(msg: "You must bind the Socket prior to Receiving"))
                    return

                }

                self.flags.remove(.receiveContinous)

                _ = self.flags.insert(.receiveOnce)

                //Continue to Receive
                self.socketQueue.async {
                    self.doReceive()
                }
            }
        }

        if isCurrentQueue == true {
            block()
        } else {
            socketQueue.sync(execute: block)
        }

        if let errors = errorCode {
            throw errors
        }

    }
}


//MARK: - Suspend/Receive
internal extension AsyncUDP {

    internal func suspendReceive() {

        if flags.contains(.recvSourceSuspend) == false {

            if let source = receiveSource {

                source.suspend()

                _ = flags.insert(.recvSourceSuspend)

            }
        }
    }

    internal func resumeReceive() {

        if flags.contains(.recvSourceSuspend) == true {

            if let source = receiveSource {

                source.resume()
                
                flags.remove(.recvSourceSuspend)
            }
        }
    }

    internal func doReceive() {

        if (flags.contains(.receiveContinous) || flags.contains(.receiveOnce)) == false {

            if socketBytesAvailable > 0  {
                suspendReceive()
            }

            return
        }

        //No Data
        if socketBytesAvailable == 0 {
            resumeReceive()
            return
        }

        assert(socketBytesAvailable > 0, "Invalid Logic")

        var readData:(data: [UInt8], sender: InternetAddress)

        do {
            readData = try self.socket!.receivefrom(maxBytes: maxReceiveSize)
        } catch  {
            //print("Receive \(error)")
            return
        }

        var waitingForSocket: Bool = false
        var notifyDelegate: Bool = false

        if readData.data.count == 0 {
            waitingForSocket = true
        } else if (readData.data.count < 0) {
            if errno == EAGAIN {
                waitingForSocket = true
            } else {
                closeSocketFinal()
                return
            }

        } else {

            if UInt(readData.data.count) > socketBytesAvailable {
                socketBytesAvailable = 0
            } else {
                socketBytesAvailable -= UInt(readData.data.count)
            }

            let responseDgram = Data(bytes: readData.data)

            //no errors go ahead and notify
            notifyRecieveDelegate(data: responseDgram, fromAddress: readData.sender)

            notifyDelegate = true

        }

        if waitingForSocket == true {
            resumeReceive()
        } else {

            if notifyDelegate == true {
                flags.remove(UdpSocketFlags.receiveOnce)
            }

            if flags.contains(UdpSocketFlags.receiveContinous) == true {
                doReceive()
            }
        }

    }

    internal func doReceiveEOF() {
        closeSocketFinal()
    }

    internal func notifyRecieveDelegate(data: Data, fromAddress address: InternetAddress) {

        for observer in observers {
            //Observer decides which queue it will send back on
            observer.socketDidReceive(self, data: data, fromAddress: address)
        }
    }


}
