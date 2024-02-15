//
//  BLPeer.swift
//  CrewP2PFramework
//
//  Created by Anurag bhatt on 21/01/24.
//

import Foundation
import CoreBluetooth

enum PeerConnectionStatus: Int {
    case disconnected = 0
    case connecting = 1
    case connected = 2
}
                                
struct BLPeer: Hashable {
    var deviceName: String
    var peripherial: CBPeripheral
    var state: PeerConnectionStatus
    
    init(deviceName: String, peripherial: CBPeripheral) {
        self.deviceName = deviceName
        self.peripherial = peripherial
        self.state = PeerConnectionStatus(rawValue: peripherial.state.rawValue) ?? .disconnected
    }
    
}

struct DataPacket: Codable, Equatable, Hashable {
    
      var timeStamp: Date
      var totalDataPacket: Int
      var currentPacketNumber: Int
      var data: Data
    
    init(timeStamp: Date, totalDataPacket: Int, currentPacketNumber: Int, data: Data) {
        self.timeStamp = timeStamp
        self.totalDataPacket = totalDataPacket
        self.currentPacketNumber = currentPacketNumber
        self.data = data
    }
  }
