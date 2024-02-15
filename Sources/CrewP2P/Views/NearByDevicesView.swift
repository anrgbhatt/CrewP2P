//
//  NearByDevicesView.swift
//  CrewP2PFramework
//
//  Created by Anurag bhatt on 05/10/23.
//

import SwiftUI

public struct NearByDevicesView: View {
    @StateObject var manager = ConnectionManager.instance
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) var dismiss
    public init() {}
    public var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(manager.defaultConnectedPeers, id: \.peerID) { peer in
                        Text(peer.peerID.displayName)
                        Button {
                            manager.disConnectDefaultDevice(peer: peer.peerID)
                        } label: {
                            Text("Disconnect")
                                .underline()
                        }
                    }
                }
            }
            .navigationBarTitle("Nearby Devices", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                    self.dismiss()
                }) {
                    Text("Done")
                        .foregroundStyle(Color.blue)
                }
                )
            
        }
    }
}

#Preview {
    NearByDevicesView()
}
