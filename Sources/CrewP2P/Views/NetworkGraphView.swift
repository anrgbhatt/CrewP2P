//
//  NetworkGraphView.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 08/09/23.
//

import SwiftUI
import DirectedGraph

public struct NetworkGraphView: View {
    @StateObject var graphVM = NetworkGraphViewModel.instance
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) var dismiss   

    public init() {
        UISegmentedControl.appearance().selectedSegmentTintColor = .systemBlue.withAlphaComponent(0.7)
           UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
           UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.blue], for: .normal)
    }
    public var body: some View {
        NavigationView {
            VStack {
                Picker("", selection: $graphVM.selectedSegment) {
                    ForEach(0..<graphVM.segmentOptions.count, id: \.self) { index in
                        Text(graphVM.segmentOptions[index])
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                if graphVM.segmentOptions[graphVM.selectedSegment] == "Custom" {
                    if graphVM.isCustomSessionCreated() {
                        GraphView(graphVM.graphViewModel)
                    } else {
                        Spacer()
                        Text("No active session.")
                            .bold()
                    }
                } else {
                    GraphView(graphVM.graphViewModelForDefaultSession)
                }
                Spacer()
            }
            .navigationBarTitle("Network Graph", displayMode: .inline)
            .onAppear {
                if graphVM.segmentOptions[graphVM.selectedSegment] == "Custom" {
                    if graphVM.isCustomSessionCreated() {
                        NetworkGraphViewModel.instance.updateGraphViewModel(devicesInNetwork: ConnectionManager.instance.devicesInNetwork)
                    }
                } else {
                    NetworkGraphViewModel.instance.updateDefaultGraphViewModel(devicesInNetwork: ConnectionManager.instance.devicesInDefaultSessionNetwork)
                }
            }
            .navigationBarItems(trailing:
             Button(action: {
                self.dismiss()
            }) {
                Text("Done")
                    .foregroundStyle(Color.blue)
            }
            )
        }
    }
}

struct NetworkGraphView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkGraphView()
    }
}

