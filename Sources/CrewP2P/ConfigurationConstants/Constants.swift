//
//  Constants.swift
//  CrewP2PFramework
//
//  Created by Anurag bhatt on 27/09/23.
//

import Foundation
import CoreBluetooth

enum Constant {
    enum P2PConstant {
        static let P2PServiceType = "com-lh-p2p"
        static let P2PDefaultServiceType = "com-lh-default"
        static let P2PDefaultSession = "default"
        static let discoveryInfoKey = "sessionName"
    }
    
    enum AppcenterKey {
        
    #if DEV
        static let appCenterSecretKey = "af1719b0-a108-41ee-8ee9-c2f682fe115a"
    #else
        static let appCenterSecretKey = "af1719b0-a108-41ee-8ee9-c2f682fe115a"
    #endif
    }
}

enum NetworkGraphSegment {
    static let Default = "Default"
    static let Custom = "Custom"
}

public enum DataTransmissionMode {
    case Wifi
    case Bluetooth
}

struct BluetoothConstants {

    /// Once two devices have decided they will initiate a chat session, this service is used
    /// in place of the discovery service, so these two devices can identify each other
    static let chatServiceID = CBUUID(string: "43eb0d29-4188-4c84-b1e8-73231e02af98")

    /// Bluetooth services contain a number of characteristics, that represent a number
    /// of specific functions of a service.
    /// a characteristic that is used to move data between devices.
    static let chatCharacteristicID = CBUUID(string: "f0ab5a15-b003-4653-a248-73fd504c1288")
}

