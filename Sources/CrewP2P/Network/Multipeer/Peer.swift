//
//  Peer.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 27/02/23.
//

import Foundation
import MultipeerConnectivity

/// Class containing peerID and session state
public class Peer: Identifiable {
    
    public var peerID: MCPeerID
    public var state: MCSessionState
    public var lastSeen: Date?
    
    public var lastSeenTimestamp : String {
        
        if let date = lastSeen {
            let formatter = DateFormatter.current
            formatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
            return formatter.string(from: date)
        }
        return ""
    }
    
    public var connectionState : String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .notConnected: return "Not Connected"
        default: return "Unknown"
        }
    }

    public init(peerID: MCPeerID, state: MCSessionState, lastSeen: Date? = nil) {
        self.peerID = peerID
        self.state = state
        self.lastSeen = lastSeen
    }

}
