# AsyncNetwork
Asynchronous Network support for Swift.  UDP, Multicast UDP


###Example Usage

```
    let sock = AsyncUDP()

    let observer = UDPReceiveObserver(closeHandler: { (sock: AsyncUDP, error: SocketError?) in

    print("Socket did Close: \(error)")

    }, receiveHandler: { (sock: AsyncUDP, data: Data, address: InternetAddress) in

        print("\n Data: \(data)  from: \(address.hostname) onPort:\(address.port)")

    })

    sock.addObserver(observer)


    do {
        let addr = InternetAddress.anyAddr(port: 51113, family: .inet)
        //let addr = InternetAddress.anyAddr(port: 5353, family: .inet)
        try sock.bind(address: addr)
    } catch  {
        print("error \(error)")
    }


    //Join Muliticast Group
    let mGroup = MulticastGroup(group: "239.78.80.1")
    //let mGroup = MulticastGroup.mDNS()

    do { 
        try sock.join(group: mGroup)

        //Start the Stream of Data
        try sock.beginReceiving()

    } catch  {
        print("error \(error)")
    }

    //Leave Group
    do {
        try sock.leave(group: mGroup)
    } catch {
        print("Error \(error)")
    }

```

