//
//  PeerInformationView.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 27/06/23.
//

import SwiftUI

public struct PeerInformationView: View {
    
    @StateObject var manager = ConnectionManager.instance
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    public init() {}
    
    public var body: some View {
        
        List {
            
            if manager.transmissionMode == .Wifi {
                Section(header: Text("**CONNECTED**")) {
                    ForEach(manager.connectedPeers, id: \.peerID) { peer in
                        HStack {
                            Text(peer.peerID.displayName)
                            Spacer()
                            Button {
                                manager.disConnectDevice(peer: peer.peerID)
                            } label: {
                                Text("Disconnect")
                                    .underline()
                            }
                        }
                        
                    }
                }
                
                Section(header: Text("**AVAILABLE**")) {
                    ForEach(manager.availablePeers, id: \.peerID) { peer in
                        if horizontalSizeClass == .regular {
                            HStack {
                                Text(peer.peerID.displayName)
                                Spacer()
                                Text(peer.connectionState)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(peer.peerID.displayName)
                                Text(peer.connectionState)
                                    .modifier(TextModifier())
                            }
                        }
                    }
                }
                
                Section(header: Text("**OFFLINE**")) {
                    ForEach(manager.otherPeers, id: \.peerID) { peer in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(peer.peerID.displayName)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("last seen \(peer.lastSeenTimestamp)")
                                    .modifier(TextModifier())
                                Text(String(describing: peer.peerID))
                                    .modifier(TextModifier())
                            }
                        }
                    }
                }
            }
            
            if manager.transmissionMode == .Bluetooth {
                Section(header: Text("**CONNECTED Peripherals**")) {
                    ForEach(Array(manager.sessionPeers), id: \.self) { peer in
                        HStack {
                            Text(peer.deviceName)
                            Spacer()
//                            Button {
//                                manager.cancelPeripheral(peripheralName: peer.deviceName)
//                            } label: {
//                                Text("Disconnect")
//                                    .underline()
//                            }
                            
                            // Could be a better way of doing this.
                            Circle()
                                .fill(connectionStatusColor(PeerConnectionStatus(rawValue: peer.peripherial.state.rawValue) ?? .disconnected))
                                .frame(width: 10, height: 10)
                            
                        }
                    }
                }
                
                Section(header: Text("**CONNECTED Centrals**")) {
                    
                    ForEach(Array(manager.centralDevices), id: \.self) { central in
                        HStack {
                            Text(central)
                        }
                        
                    }
                }
            }
        }
    }
}
private func connectionStatusColor(_ state: PeerConnectionStatus) -> Color {
    var color = Color.white
    switch state {
    case .connected:
        color = .green
    case .disconnected:
        color = .red
    case .connecting:
        color = .yellow
    }
    return color
}

struct TextModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.gray)
            .font(.footnote)
    }
}
