//
//  DeviceList.swift
//  Example
//
//  Created by Lufthansa on 27/02/23.
//

import SwiftUI
import CrewP2P

struct DeviceList: View {
    @StateObject var connectionVM: ConnectionViewModel
    @Binding var sessionName: String
    @Binding var deviceName: String
    var body: some View {
        NavigationView {
            
            VStack(alignment: .leading, spacing: 10) {
                
                VStack {
                    HStack {
                        Text("Session name")
                        Spacer()
                        TextField("enter session name", text: $sessionName)
                            .frame(width: 180)
                    }
                    .padding()
                    .background(.white)
                    
                    HStack {
                        Text("Device name")
                        Spacer()
                        TextField("enter device name", text: $deviceName)
                            .frame(width: 180)
                    }
                    .padding()
                    .background(.white)
                    
                    HStack {
                        Text("Data Transmission Mode")
                        Spacer()
                        Picker("", selection: $connectionVM.selectedOption) {
                            ForEach(0..<connectionVM.dataTransmissionModes.count, id: \.self) { index in
                                Text(self.connectionVM.dataTransmissionModes[index])
                            }
                        }
                        .padding()
                    }
                    .padding()
        
                    HStack {

                        Button("Start") {
                            connectionVM.startSession()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background((sessionName.isEmpty || deviceName.isEmpty) ? Color.blue.opacity(0.3) : Color.blue.opacity(0.7))
                        .clipShape(Capsule())
                        .disabled((sessionName.isEmpty || deviceName.isEmpty))
                        
                        Spacer()
                            .frame(width: 15)
                        
                        Button("Stop") {
                            connectionVM.stopSession()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background((sessionName.isEmpty || deviceName.isEmpty) ? Color.teal.opacity(0.3) : Color.teal.opacity(0.7))
                        .clipShape(Capsule())
                        .disabled((sessionName.isEmpty || deviceName.isEmpty))
                    }
                    .padding(.horizontal)

                }
                .padding(.bottom, 10)
                .background(.white)
                .cornerRadius(10)

                
                Text("Peers:")
                    .padding(.horizontal)
                
                PeerInformationView()

//                List(connectionVM.deviceList) { peer in
//                    Text(peer.peerID.displayName)
//
//                }
//                .listStyle(.insetGrouped)
//                .background(Color.init(white: 0.95))
//                .cornerRadius(10)

            }
            .padding()
            .background(Color.init(white: 0.97))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        
    }
}

struct DeviceList_Previews: PreviewProvider {
    static var previews: some View {
        DeviceList(connectionVM: ConnectionViewModel(), sessionName: .constant(""), deviceName: .constant(""))
    }
}
