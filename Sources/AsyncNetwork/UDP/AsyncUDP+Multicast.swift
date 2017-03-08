//
//  AsyncUDP+Multicast.swift
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

//MARK: - Multicast
public extension AsyncUDP {

    /// Join Multicast Group
    ///
    /// - Parameter group: Multicast Group
    /// - Throws: Throws SocketError if error condition
    public func join(group: MulticastGroup) throws {

        var errorCode: SocketError?

        let block: as_dispatch_block_t = {

            do {
                //Do the Pre Multicast Checks
                try self.preMulticastCheck()

            } catch {
                errorCode = (error as? SocketError)!
                return
            }

            //Must be same Address Family as the Socket
            if self.socket?.config.addressFamily != group.family {
                errorCode = SocketError(.multicastJoinFail(msg: "Address Family of Multicast Group is not same as Sockets"))
                return
            }

            let groupStorage: SockAddressStorage

            do {
                groupStorage = try group.resolveGroup()
            } catch  {
                errorCode = (error as? SocketError)!
                return
            }

            //Preform the Join Request
            do {
                try self.doJoinLeave(group.family.mcastJoinValue, groupStorage: groupStorage)

            } catch  {
                errorCode = (error as? SocketError)!
                return
            }

            self.flags.insert(.multiCastJoined)

        }

        if isCurrentQueue == true {
            block()
        } else {
            socketQueue.sync(execute: block)
        }

        if let errors = errorCode {
            throw errors
        }

        //print("Joined Multicast Group \(group)")

    }

    /// Leaves the Multicast Group
    ///
    /// - Parameter group: Multicast Group
    /// - Throws: Throws SocketError if error condition
    public func leave(group: MulticastGroup) throws {
        var errorCode: SocketError?

        let block: as_dispatch_block_t = {

            //Cant Leave if never joined
            guard self.flags.contains(.multiCastJoined) != false else {
                errorCode = SocketError(.multicastLeaveFail(msg: "Not part of a Multicast Group."))
                return
            }

            let groupStorage: SockAddressStorage

            do {
                groupStorage = try group.resolveGroup()
            } catch  {
                errorCode = (error as? SocketError)!
                return
            }

            //Preform the Join Request

            do {
                try self.doJoinLeave(group.family.mcastLeaveValue, groupStorage: groupStorage)

            } catch  {
                errorCode = (error as? SocketError)!
                return
            }
            
            self.flags.remove(.multiCastJoined)

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


fileprivate extension AsyncUDP {

    fileprivate func preMulticastCheck() throws {
        //Pre-check if we can Bind
        guard flags.contains(.didBind) != false else {
            throw SocketError(.notBound(msg: "Must bind a socket before joining a multicast group."))
        }

        guard flags.contains(.multiCastJoined) == false else {
            throw SocketError(.multicastJoinFail(msg: "Already Joined a Multicast Group."))
        }
        
    }

    func doJoinLeave(_ request: Int32, groupStorage: SockAddressStorage) throws   {

        var status: Int32 = 0

        let groupFamily = try groupStorage.addressFamily()

        if groupFamily == .inet {

            var imReq: ip_mreq = ip_mreq()

            imReq.imr_multiaddr = groupStorage.sockaddr_in.pointee.sin_addr
            imReq.imr_interface = self.socket!.address.sockaddr_in.pointee.sin_addr

            status = setsockopt((self.socket?.fd)!, Protocol.TCP.ipProto(family: .inet), request, &imReq, UInt32(MemoryLayout<ip_mreq>.size))

            guard status != -1 else { throw SocketError(.setSocketOptionFail(msg: "Couldn't perform multicast socket option")) }

        } else if groupFamily == .inet6 {

            var imReq: ipv6_mreq = ipv6_mreq()

            imReq.ipv6mr_multiaddr = groupStorage.sockaddr_in6.pointee.sin6_addr
            imReq.ipv6mr_interface = (self.socket?.address.sockaddr_in.pointee.sin_addr.s_addr)!

            status = setsockopt((self.socket?.fd)!, Protocol.TCP.ipProto(family: .inet6), request, &imReq, UInt32(MemoryLayout<ipv6_mreq>.size))

            guard status != -1 else { throw SocketError(.setSocketOptionFail(msg: "Couldn't perform multicast socket option")) }

        }


    }
}
