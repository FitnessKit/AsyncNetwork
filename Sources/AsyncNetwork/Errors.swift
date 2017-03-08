//
//  Errors.swift
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


public enum ErrorReasons {

    case dispatchFail(msg: String)
    case createSocketFail
    case closeSocketFail
    case socketIsClosed
    case setSocketOptionFail(msg: String)

    //Read
    case alreadyReceiving(msg: String)
    case readFailed

    //Send
    case sendTimout(msg: String)
    case sendFailed

    //Bind
    case socketBindFail
    case alreadyBound(msg: String)
    case notBound(msg: String)

    //Connection
    case connectionFail(msg: String)
    case alreadyConnected(msg: String)

    //Address Family
    case unsupportedAddressFamily(Int32)
    case invalidAddressFamilyType

    //Internet Address Errors
    case addressValidationFail(msg: String)
    case addressResolutionFail

    //Multicast
    case multicastJoinFail(msg: String)
    case multicastLeaveFail(msg: String)

    //Generic
    case generic(String)
}

public struct SocketError: Error {

    public let type: ErrorReasons
    public let number: Int32

    init(_ type: ErrorReasons) {
        self.type = type
        self.number = errno
    }

    init(message: String) {
        self.type = .generic(message)
        self.number = -1
    }

}
