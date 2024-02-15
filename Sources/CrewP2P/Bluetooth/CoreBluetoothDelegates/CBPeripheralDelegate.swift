//
//  CBPeripheralDelegate.swift
//  CrewP2PFramework
//
//  Created by Anurag bhatt on 21/01/24.
//

import Foundation
import CoreBluetooth

extension ConnectionManager: CBPeripheralDelegate {
    
    /// Called when the peripheral has discovered all of the services we requested,
    /// so we can then check those services for the characteristics we need
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // If an error occurred, print it, and then reset all of the state
        if let error = error {
            print("Unable to discover service: \(error.localizedDescription)")
            return
        }
        
        // It's possible there may be more than one service, so loop through each one to discover
        // the characteristic that we want
        peripheral.services?.forEach{ service in
            guard service.uuid == BluetoothConstants.chatServiceID else { return }
            peripheral.discoverCharacteristics([BluetoothConstants.chatCharacteristicID], for: service)
        }
    }
    
    /// A characteristic matching the ID that we specifed was discovered in one of the services of the peripheral
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Handle if any errors occurred
        if let error = error {
            print("Unable to discover characteristics: \(error.localizedDescription)")
            return
        }
        
        // Perform a loop in case we received more than one
        service.characteristics?.forEach { characteristic in
            guard characteristic.uuid == BluetoothConstants.chatCharacteristicID else { return }
            
            // Subscribe to this characteristic, so we can be notified when data comes from it
            peripheral.setNotifyValue(true, for: characteristic)
            
            // Hold onto a reference for this characteristic for sending data
            self.centralCharacteristic = characteristic
            dicPeripherals[peripheral] = characteristic
        }
    }
    /// Receiving Data from a Peripheral
    /// Called when the peripheral has sent data to central.
    /// More data has arrived via a notification from the characteristic we subscribed to
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Perform any error handling if one occurred
        if let error = error {
            print("Characteristic value update failed: \(error.localizedDescription)")
            return
        }
        
        // Decode the message string and trigger the callback
        guard let data = characteristic.value else { return }
        do {
            let dataObj = try JSONDecoder().decode(DataObject.self, from: data)
            //print("Decoding passed for DataObject : \(dataObj)")
            OperationQueue.main.addOperation {
                self.delegate?.peerDidReceiveData(data: dataObj)
            }
            
            // send data to isolatednode if any
            var peers = self.sessionPeers.map({$0.deviceName})
            peers.append(self.deviceName)
            if let nodes = dataObj.deliveredNodesBLE {
               // let isolatedNodes = peers.filter { !nodes.contains($0) && $0 != self.deviceName}
                let isolatedNodes = peers.filter { !nodes.contains($0) }
                // send data to isolated node
                self.sendDataToIsolatedNodeBLE(peers: isolatedNodes, data: dataObj)
            }
            
        } catch {
            // printDebug("Decoding failed for DataObject : \(error)")
        }
    }
    
    /// Only called if write type was .withResponse
    /// When central Write value to its connected peripheral didWriteValueFor called having status of error if successfully data delivered error would be nil.
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            // Handle error
            print("didNotWriteValueFor\(error)")
            return
        }
        print("Successfully wrote value to characteristic")
        // Successfully wrote value to characteristic
    }
    
    /// The peripheral returned back whether our subscription to the characteristic was successful or not
    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateNotificationStateFor characteristic: CBCharacteristic,
                           error: Error?) {
        // Perform any error handling if one occurred
        if let error = error {
            print("Characteristic update notification failed: \(error.localizedDescription)")
            return
        }
        
        // Ensure this characteristic is the one we configured
        guard characteristic.uuid == BluetoothConstants.chatCharacteristicID else { return }
        
        // Check if it is successfully set as notifying
        if characteristic.isNotifying {
            print("Characteristic notifications have begun.")
            
            var data = DataObject(data: Data(), sender: self.deviceName, linkSession: false)
            data.dataOperation = .Update
            if let item = try? JSONEncoder().encode(data) {
                if let objPeripheral = dicPeripherals.filter({$0.key == peripheral}).first, objPeripheral.key.state == .connected {
                    objPeripheral.key.writeValue(item, for: objPeripheral.value, type: .withResponse)
                }
            }
        } else {
            print("Characteristic notifications have stopped. Disconnecting.")
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
}

