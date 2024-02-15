//
//  CBCentralManagerDelegate.swift
//  CrewP2PFramework
//
//  Created by Anurag bhatt on 21/01/24.
//


import Foundation
import CoreBluetooth

extension ConnectionManager:CBCentralManagerDelegate {
    /// Called when the state of the device as a Bluetooth central changed
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff, Turn on bluetooth")
        case .poweredOn:
            print("central.state is .poweredOn")
            // Start scanning
            self.startScan()
        @unknown default:
            print("central.state is .unknown")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // If this is the device we're expecting, start connecting
        
        guard peripheral.state != .connected  else {
            return
        }
        guard let strAdvertisementData =  advertisementData[CBAdvertisementDataLocalNameKey] as? String else {return}
        
        if let index = strAdvertisementData.range(of: ",") {
            let strSessionName = strAdvertisementData.suffix(from: index.upperBound)
            if strSessionName == sessionName {
                // Connect peripheral
                centralManager?.connect(peripheral, options: nil)
                // get the peer name (combination of device name and session name, seprated by ',')
                if let index = strAdvertisementData.firstIndex(of: Character(",")) {
                    let strName = strAdvertisementData.prefix(upTo: index)
                    self.sessionPeers.insert(.init(deviceName: String(strName), peripherial: peripheral))
                }
            }
        }
    }
    
    /// Called when a peripheral has successfully connected to this device (which is acting as a central)
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Configure a delegate for the peripheral
        peripheral.delegate = self
        print("\(peripheral): peripheral has successfully connected")
        // Scan for the chat characteristic we'll use to communicate
        peripheral.discoverServices([BluetoothConstants.chatServiceID])
    }
    
    /// An error occurred when attempting to connect to the peripheral
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("didFailToConnectPeripheral: \(error.localizedDescription)")
        }
        self.sessionPeers = self.sessionPeers.filter({$0.peripherial.identifier != peripheral.identifier})
        self.dicPeripherals.removeValue(forKey: peripheral)
        centralManager?.connect(peripheral, options: nil)
       
    }
    
    /// The peripheral disconnected
    /// This method is invoked upon the disconnection of a peripheral that was connected by  connectPeripheral:options:. If the disconnection was not initiated by cancelPeripheralConnection}  the cause will be detailed in the error parameter
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.dicPeripherals.removeValue(forKey: peripheral)
        self.sessionPeers = self.sessionPeers.filter({$0.peripherial.identifier != peripheral.identifier})
        if let error = error {
            print("didDisconnectPeripheral: \(error.localizedDescription)")
          //  centralManager?.connect(peripheral, options: nil)
        }
    }
}
