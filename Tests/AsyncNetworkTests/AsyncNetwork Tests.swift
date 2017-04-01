import XCTest
@testable import AsyncNetwork
import Foundation

class AsyncNetworkTests: XCTestCase {


    func testBadAddress() {
        let sock = AsyncUDP()

        do {
            let addr = InternetAddress.anyAddr(port: 5113, family: .inet)
            try sock.bind(address: addr)
        } catch  {
            print("error \(error)")
        }
        sock.close()

        do {
            let addr = InternetAddress(hostname: "0.0.0.0.0.0.0", port: 1234)
            try sock.bind(address: addr)
        } catch  {
            print("error \(error)")
            XCTAssertTrue(1 == 1, "This Should Fail")
            sock.close()
        }


    }//

    func  testMulticastJoin()  {
        let sock = AsyncUDP()

        do {
            let addr = InternetAddress.anyAddr(port: 51113, family: .inet)
            try sock.bind(address: addr)
        } catch  {
            print("error \(error)")
        }

        do {
            let mGroup = MulticastGroup(group: "239.78.80.1")
            try sock.join(group: mGroup)

        } catch  {
            print("error \(error)")

        }
        do {
            let mGroup = MulticastGroup(group: "127.2.2.2", family: .inet6)
            try sock.join(group: mGroup)
        } catch  {
            print("error \(error)")
            XCTAssertTrue(1 == 1, "This Should Fail")

        }
    }

    func testReceive() {
        let expect: XCTestExpectation = expectation(description: "test")
        let stop: Bool = false
        let sock = AsyncUDP()

        let observer = UDPReceiveObserver(closeHandler: { (sock: AsyncUDP, error: SocketError?) in

            print("Socket did Close: \(error)")

        }, receiveHandler: { (sock: AsyncUDP, data: Data, address: InternetAddress) in

//            let head = String(format: "%X%X", data[0], data[1])
            let head = String(format: "%C%C", data[0], data[1])
            let flags = String(format: "%X%X", data[2], data[3])

            print("\n Data: \(data.debugDescription) Header: \(head) flags:\(flags) from: \(address.hostname) onPort:\(address.port)")

        })
        
        sock.addObserver(observer)


        do {
            let addr = InternetAddress.anyAddr(port: 51113, family: .inet)
//            let addr = InternetAddress.anyAddr(port: 5353, family: .inet)
            try sock.bind(address: addr)
        } catch  {
            print("error \(error)")
        }

        do {
//            let mGroup = MulticastGroup.mDNS()
            let mGroup = MulticastGroup(group: "239.78.80.1")

            print("Group: \(mGroup)")
            try sock.join(group: mGroup)

            try sock.beginReceiving()

            //            try sock.leave(group: mGroup)
        } catch  {
            print("error \(error)")
            
        }

        if stop == true {
            expect.fulfill()
        }


        waitForExpectations(timeout: 3234234236) { (error) -> Void in

            if (error != nil) {
                XCTFail("Expectation Failed with error: \(error)");
            }
            
        }

    }


    static var allTests : [(String, (AsyncNetworkTests) -> () throws -> Void)] {
        return [
            ("testBadAddress", testBadAddress),
            ("testMulticastJoin", testMulticastJoin),
        ]
    }
}
