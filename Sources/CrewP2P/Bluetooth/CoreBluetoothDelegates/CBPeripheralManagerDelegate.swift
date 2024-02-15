//
//  CBPeripheralManagerDelegate.swift
//  CrewP2PFramework
//
//  Created by Anurag bhatt on 21/01/24.
//


import Foundation
import CoreBluetooth

extension ConnectionManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        // Once we're powered on, configure the peripheral with the services
        // and characteristics we intend to support
        switch peripheral.state {
        case .unknown:
            print("peripheral.state is .unknown")
        case .resetting:
            print("peripheral.state is .resetting")
        case .unsupported:
            print("peripheral.state is .unsupported")
        case .unauthorized:
            print("peripheral.state is .unauthorized")
        case .poweredOff:
            print("peripheral.state is .poweredOff, Turn on bluetooth")
        case .poweredOn:
            print("peripheral.state is .poweredOn")
            // Start startAdvertising
            self.startAdvertising()
        @unknown default:
            print("peripheral.state is .unknown")
            
        }
    }
    
    /// Called when someone else has subscribed to our characteristic, allowing us to send them data
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                                  central: CBCentral,
                                  didSubscribeTo characteristic: CBCharacteristic) {
        print("\(central) central has subscribed to the peripheral")
        self.centrals.insert(central)
    }
    
    /// This method is invoked after a failed call to  updateValue:forCharacteristic:onSubscribedCentrals
    /// (When we are operating as a peripheral, send a message to our connected central)
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if !arrData.isEmpty {
            semaphore.wait()
            print("peripheralManagerIsReady, Now  sending all stored data")
            for data in arrData {
                peripheralManager?.updateValue(data, for: peripheralCharacteristic,
                                                  onSubscribedCentrals: Array(centrals))
            }
            arrData.removeAll()
            semaphore.signal()
        }
    }
    
    /// Called when the subscribing central has unsubscribed from us
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                                  central: CBCentral,
                                  didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("The central has unsubscribed from the peripheral")
        self.centrals.remove(central)
    }
    
    func getSerializeDataFromChunks(receivedDataChunks: [DataPacket]) -> Data {
        let arrData  =  receivedDataChunks.map({$0.data})
        return arrData.reduce(Data()) { (result, chunk) in
            var mutableResult = result
            mutableResult.append(chunk)
            return mutableResult
        }
    }
    
    func didReceiveWriteFromCentral(data: Data,peripheral: CBPeripheralManager,requests: [CBATTRequest]) {
        do {
            let dataObj = try JSONDecoder().decode(DataObject.self, from: data)
            receivedChunks.removeAll()
            //  print("Decoding passed for DataObject : \(dataObj)")
            switch dataObj.dataOperation {
            case .Update:
                centralDevices.insert(dataObj.sender)
            default:
                OperationQueue.main.addOperation {
                    self.delegate?.peerDidReceiveData(data: dataObj)
                }
                peripheral.respond(to: requests[0], withResult: .success)
                
                // send data to isolatednode if any
                var peers = self.sessionPeers.map({$0.deviceName})
                peers.append(self.deviceName)
                if let nodes = dataObj.deliveredNodesBLE {
                    // let isolatedNodes = peers.filter { !nodes.contains($0) && $0 != self.deviceName}
                    let isolatedNodes = peers.filter { !nodes.contains($0) }
                    // send data to isolated node
                    self.sendDataToIsolatedNodeBLE(peers: isolatedNodes, data: dataObj)
                }
            }
        } catch {
            printDebug("Decoding failed for DataObject : \(error)")
        }
    }
    
    /// Receiving Data from a Central
    /// Called when the central has sent a message to this peripheral
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let request = requests.first, let data = request.value else { return }
        print("Received data: \(data.count) bytes")
        if let dataPacket = try? JSONDecoder().decode(DataPacket.self, from: data) {
            self.receivedChunks.append(dataPacket)
            peripheral.respond(to: requests[0], withResult: .success)
            if dataPacket.totalDataPacket == dataPacket.currentPacketNumber {
                let arrChunk = receivedChunks.filter({$0.timeStamp == dataPacket.timeStamp}).sorted(by: {$0.currentPacketNumber < $1.currentPacketNumber})
                self.didReceiveWriteFromCentral(data: getSerializeDataFromChunks(receivedDataChunks: arrChunk), peripheral: peripheral, requests: requests)
            }
        } else {
            self.didReceiveWriteFromCentral(data: data, peripheral: peripheral, requests: requests)
        }
    }
}
