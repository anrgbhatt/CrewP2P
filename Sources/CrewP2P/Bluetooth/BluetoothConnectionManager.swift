//
//  BluetoothConnectionViewModel.swift
//  CrewP2PFramework
//
//  Created by Anurag bhatt on 21/01/24.
//

import Foundation
import CoreBluetooth

extension ConnectionManager {
    
    func initBluetooth() {
        /// Start the central, scanning immediately
        /// will call centralManagerDidUpdateState delegate
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        /// The central manager that will scan for any peripherals matching our device
        /// will call peripheralManagerDidUpdateState delegate
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func divideDataIntoChunks(data: Data, chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        
        var offset = 0
        while offset < data.count {
            let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
            chunks.append(chunk)
            offset += chunkSize
        }
        
        return chunks
    }
    
    /// When we are operating as a central, send a message to our connected peripheral
    func sendCentralData(_ data: Data) {
        for peripheral in dicPeripherals {
            if peripheral.key.state == .connected {
                maximumWriteValueLength = peripheral.key.maximumWriteValueLength(for: .withResponse)
                let chunks = divideDataIntoChunks(data: data, chunkSize: maximumWriteValueLength/2)
                
                let timeStamp =  Date()
                for (index, chunk) in chunks.enumerated() {
                    let packet = DataPacket(timeStamp:timeStamp,totalDataPacket: chunks.count, currentPacketNumber: index+1, data: chunk)
                    if let packetData = try? JSONEncoder().encode(packet) {
                        peripheral.key.writeValue(packetData, for: peripheral.value, type: .withResponse)
                    }
                }
            }
        }
    }
    
    /// When we are operating as a peripheral, send a message to our connected central
    /// when updateValue failed (due to underlying transmit queue is full)
    /// the delegate method peripheralManagerIsReadyToUpdateSubscribers: will be called once space has become available, and the update should be re-send if so desired.
    
    func sendPeripheralData(_ data: Data) {
        guard let peripheralManager = peripheralManager else {return}
        DispatchQueue.global().async {
            if !peripheralManager.updateValue(data, for: self.peripheralCharacteristic,
                                              onSubscribedCentrals: nil) {
                print("Data did not send to central, store it in array for resend.")
                self.semaphore.wait()
                self.arrData.append(data)
                self.semaphore.signal()
            }
        }
    }
    
    // Send data to IsolatedNode for BLE
    // Parameters -
    // peers: list of all peers name which is directly connnected this node.
    // data: Data object received from other node.
    func sendDataToIsolatedNodeBLE(peers:[String],data: DataObject) {
        
        for deviceName in peers {
            let peer = self.sessionPeers.filter({$0.deviceName == deviceName}).first
            let arrDicPeripheral = self.dicPeripherals.filter({$0.key.identifier == peer?.peripherial.identifier})
            for peripheral in arrDicPeripheral {
                var dataObject = data
                dataObject.deliveredNodesBLE?.append(contentsOf: self.sessionPeers.map({$0.deviceName}))
                dataObject.deliveredNodesBLE?.append(self.deviceName)
                if let message = try? JSONEncoder().encode(dataObject) {
                    if peripheral.key.state == .connected {
                        peripheral.key.writeValue(message, for: peripheral.value, type: .withResponse)
                    }
                }
            }
        }
        self.sendDataToIsolatedCentralNode(peers: peers, data: data)
    }
    
    
    // Send data to central when current device act as peripheral to other device 
    private func sendDataToIsolatedCentralNode(peers:[String],data: DataObject) {
        
        if let deliveredNodesBLE = data.deliveredNodesBLE {
            let allDeliveredNode = Set(deliveredNodesBLE + peers)
            var dataObject = data
            dataObject.deliveredNodesBLE?.append(contentsOf: Array(allDeliveredNode))
            dataObject.deliveredNodesBLE?.append(self.deviceName)
            if self.centralDevices.count > 0 && !(self.centralDevices.isSubset(of: allDeliveredNode)) {
                if let message = try? JSONEncoder().encode(dataObject) {
                    sendPeripheralData(message)
                }
            }
        }
    }
    
    /// Reset all of the state back to default
    private func resetCentral() {
        // Reset all state
        self.sessionPeers.removeAll()
    }
    
    /// Cancels an active or pending local connection to a peripheral.
    func cancelPeripheral(peripheralName:String) {
        let peer = self.sessionPeers.filter({$0.deviceName == peripheralName}).first
        let arrDicPeripheral = self.dicPeripherals.filter({$0.key.identifier == peer?.peripherial.identifier})
        for peripheral in arrDicPeripheral {
            if peripheral.key.state != .disconnected {
                // Cancel the connection
                centralManager?.cancelPeripheralConnection(peripheral.key)
            }
        }
    }
    
    func cancelAllPeripheralConnections() {
        guard  let centralManager = centralManager else {return}
        for peripheral in centralManager.retrieveConnectedPeripherals(withServices: [BluetoothConstants.chatServiceID]) {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    /// // Start advertising as a peripheral
    func startAdvertising() {
        // Create the service that will represent this characteristic
        let service = CBMutableService(type: BluetoothConstants.chatServiceID, primary: true)
        service.characteristics = [self.peripheralCharacteristic]
        
        // Register this service to the peripheral so it can now be advertised
        peripheralManager?.add(service)

       let  strDeviceAndSessionName = deviceName.replacingOccurrences(of: " ", with: "") + "," + sessionName.replacingOccurrences(of: " ", with: "")
        
        let advertisementData: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [BluetoothConstants.chatServiceID],CBAdvertisementDataLocalNameKey: strDeviceAndSessionName]
        peripheralManager?.startAdvertising(advertisementData)
    }
    
    // Start scanning for a peripheral that matches our saved device
    func startScan() {
        guard let centralManager = centralManager else { return }
        cleanup()
        centralManager.scanForPeripherals(withServices: [BluetoothConstants.chatServiceID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    func cleanup() {
        self.cancelAllPeripheralConnections()
        self.sessionPeers.removeAll()
        self.centrals.removeAll()
        self.dicPeripherals.removeAll()
        self.centralDevices.removeAll()
    }
    
}
