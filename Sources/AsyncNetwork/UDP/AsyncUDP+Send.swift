//
//  AsyncUDP+Send.swift
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

public extension AsyncUDP {

    /// Sends Data to a UDP end point
    ///
    /// - Parameters:
    ///   - data: Data to send
    ///   - host: Internet Address to send data to
    ///   - timeout: Timeout period to send data
    ///   - tag: Tags can be used to associate sends on the Observer
    public func send(data: Data, toHost host: InternetAddress, timeout: TimeInterval = kAsyncUDPSocketSendNoTimeout, tag: Int = kAsyncUDPSocketSendNoTag) {

        if data.count == 0 {
            return
        }

        let sendPacket = AsyncUDPSendPacket(data: data, timeout: timeout, tag: tag)
        sendPacket.resolveInProgress = true

        resolve(host: host) { (resolvedAddr: SockAddressStorage?, error: SocketError?) in

            sendPacket.resolveInProgress = false
            sendPacket.resolvedAddress = resolvedAddr
            sendPacket.resolvedError = error

            var family = host.addressFamily

            if resolvedAddr != nil {

                do {
                    family = try resolvedAddr!.addressFamily()
                } catch {
                    // no op..  Will handle later
                }
            }
            sendPacket.resolvedFamily = family

        }


        self.socketQueue.async { () -> Void in
            self.sendQueue.append(sendPacket)
            self.maybeDequeueSend()
        }


    }

}

//MARK: - Internal
internal extension AsyncUDP {


    func suspendSendSource() {

        if flags.contains(.sendSourceSuspend) == false {

            guard let source = self.sendSource else { return }

            source.suspend()

            _ = flags.insert(.sendSourceSuspend)
            
        }
    }

    internal func resumeSendSource() {

        if flags.contains(.sendSourceSuspend) == true {

            guard let source = self.sendSource else { return }

            source.resume()

            flags.remove(.sendSourceSuspend)
        }
    }

    internal func doSend() {

        assert(currentSend != nil, "Invalid Logic")

        if let curSend = currentSend {

            let buffer      = Array(curSend.buffer)
            let dest        = curSend.resolvedAddress!

            var result: Int = 0

            do {
                result = try self.socket?.send(data: buffer, toResolvedHost: dest, sendOptions: .none) ?? 0
            } catch  {
                //Result is still 0 so we are ok here.
            }

            //Check Results
            var waitingForSocket: Bool = false
            var socketError: SocketError?


            if result == 0 {
                waitingForSocket = true
            } else if result < 0 {

                if errno == EAGAIN {
                    waitingForSocket = true
                } else {
                    socketError = SocketError(.sendFailed)
                }
            }

            if waitingForSocket == true {

                if !flags.contains(.sockCanAccept) {
                    resumeSendSource()
                }

                if sendTimer == nil && (currentSend?.timeout)! >= TimeInterval(0.0) {
                    setupSendTimer((currentSend?.timeout)!)
                }

            } else if socketError != nil {

                closeSocket(withError: socketError)

            } else {
                let tag = (currentSend?.tag)!
                
                notifyDidSend(tag)
                
                endCurrentSend()
                maybeDequeueSend()
            }

        } else {

            if !flags.contains(.sockCanAccept) {
                resumeSendSource()
            }
        }

    }

}

//MARK: - Private
fileprivate extension AsyncUDP {


    fileprivate func resolve(host: InternetAddress, handler: @escaping (_ address: SockAddressStorage?, _ error: SocketError?) -> Void) {

        let globalConcurrentQ = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)

        globalConcurrentQ.async { () -> Void in

            var cfg = SocketConfig.UDP(family: host.addressFamily)

            do {
                //Resolve
                let address = try host.resolveAddress(with: &cfg)

                self.socketQueue.async {
                    handler(address, nil)
                }

            } catch {

                self.socketQueue.async {
                    handler(nil, error as? SocketError)
                }
            }
        }
    }

    fileprivate func endCurrentSend() {

        if sendTimer != nil {
            sendTimer!.cancel()
            sendTimer = nil
        }

        currentSend = nil
    }

    fileprivate func doPreSend() {

        //Check for any problems with Send Packet

        var waitingForResolve: Bool = false
        var error: SocketError?


        if currentSend?.resolveInProgress == true {
            waitingForResolve = true
        } else if currentSend?.resolvedError != nil {
            error = (currentSend?.resolvedError!)!
        } else if currentSend?.resolvedAddress == nil {
            waitingForResolve = true
        }

        if waitingForResolve == true {

            if flags.contains(.sockCanAccept) {
                suspendSendSource()
                return
            }
        }

        if let errors = error {
            notifyDidNotSend(errors, tag: (currentSend?.tag)!)

            endCurrentSend()
            maybeDequeueSend()
            return
        }
        
        doSend()
    }

    fileprivate func maybeDequeueSend() {

        guard isCurrentQueue == true else {
            assertionFailure("Must be dispatched on Socket Queue")
            return
        }

        if currentSend == nil {

            guard flags.contains(.didCreateSockets) == true else {
                //throw error here
                let err = SocketError(.notBound(msg: "Socket Must be bound and created prior to sending."))
                notifyDidNotSend(err, tag: kAsyncUDPSocketSendNoTag)

                return
            }

            while sendQueue.count > 0 {

                currentSend = sendQueue.first
                sendQueue.remove(at: 0)

                //Check for Errors in resolv
                if currentSend?.resolvedError != nil {
                    notifyDidNotSend((currentSend?.resolvedError)!, tag: kAsyncUDPSocketSendNoTag)

                    currentSend = nil
                    continue
                } else {
                    //do presend!
                    doPreSend()
                    break
                }

            }

            if currentSend == nil && flags.contains(.closeAfterSend) {
                closeSocket(withError: SocketError(message: "Nothing more to Send"))
            }
        }
    }



    //MARK: Send Timeout
    fileprivate func setupSendTimer(_ timeout: TimeInterval) {

        assert(sendTimer == nil, "Invalid Logic")
        assert(timeout >= 0.0, "Invalid Logic")

        let timerFlag = DispatchSource.TimerFlags(rawValue: 0)

        sendTimer = DispatchSource.makeTimerSource(flags: timerFlag, queue: socketQueue)

        sendTimer!.setEventHandler { () -> Void in
            self.doSendTimout()
        }

        let when = DispatchTime.now() + Double(Int64(timeout * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

        sendTimer?.scheduleOneshot(deadline: when)

        sendTimer!.resume();

    }

    fileprivate func doSendTimout() {
        let error = SocketError(.sendTimout(msg: "Send operation timed out"))

        notifyDidNotSend(error, tag: (currentSend?.tag)!)

        endCurrentSend()
        maybeDequeueSend()

    }

    fileprivate func notifyDidNotSend(_ error: SocketError, tag: Int) {

        for observer in observers {
            //Observer decides which queue it will send back on
            observer.socketDidNotSend(self, tag: tag, error: error)

        }
    }

    fileprivate func notifyDidSend(_ tag: Int) {

        for observer in observers {
            //Observer decides which queue it will send back on
            observer.socketDidSend(self, tag: tag)
        }
    }

}
