//
//  ContentView.swift
//  Example
//
//  Created by Lufthansa on 27/02/23.
//

import SwiftUI
import CrewP2P
import PhotosUI

struct ContentView: View {
    @StateObject var connectionVM = ConnectionViewModel()
    @State var presentingModal = false
    @State var presentingDBViewer = false
    @State var presentingNetworkGraph = false
    @State var presentingNearByDevices = false
//    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        NavigationView {
            
            VStack {
                MessageView(connectionVM: connectionVM)
                Spacer()
                
                Divider()
                HStack {
                    TextField("Send message..", text: $connectionVM.message)
                    Spacer()
                    Button("Send") {
                        connectionVM.sendMessage(message: connectionVM.message)
                    }
                    .buttonStyle(.borderedProminent)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding()
            }
            .navigationTitle(connectionVM.sessionName.isEmpty ? "No active session": connectionVM.sessionName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button("Settings") {
                        self.presentingModal = true
                    }
                    
                    Button("DBViewer") {
                        self.presentingDBViewer = true
                    }
                    
                    Button("NetworkGraph") {
                        self.presentingNetworkGraph = true
                    }
                    
                    Button("Nearby Devices") {
                        self.presentingNearByDevices = true
                    }
                    if !connectionVM.sessionName.isEmpty {
                        Button("Clear Message") {
                            connectionVM.clearDataSource()
                        }
                    }
                    
                    if !connectionVM.sessionName.isEmpty {
                        Button(connectionVM.autoSendButtonText) {
                            connectionVM.autoSendButtonTapped()
                        }
                    }
                }
                .sheet(isPresented: $presentingModal, content: {
                    DeviceList(connectionVM: connectionVM, sessionName: $connectionVM.sessionName, deviceName: $connectionVM.deviceName)
                })
                .fullScreenCover(isPresented: $presentingDBViewer, content: {
                    DatabaseViewer()
                })
                .fullScreenCover(isPresented: $presentingNetworkGraph, content: {
                    NetworkGraphView()
                })
                .fullScreenCover(isPresented: $presentingNearByDevices, content: {
                    NearByDevicesView()
                })
        }
        .navigationViewStyle(.stack)
    }
    

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ConnectionViewModel()
        ContentView().environmentObject(viewModel)
    }
}
