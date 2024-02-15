//
//  NetworkGraphViewModel.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 09/09/23.
//

import Foundation
import DirectedGraph

class NetworkGraphViewModel: ObservableObject {
    var tempDevicesInNetwork: [String: [String]] = [String: [String]]()
    let segmentOptions = [NetworkGraphSegment.Default, NetworkGraphSegment.Custom]
    var selectedSegment = 0 {
        didSet {
            if segmentOptions[selectedSegment] == NetworkGraphSegment.Custom {
                NetworkGraphViewModel.instance.updateGraphViewModel(devicesInNetwork: ConnectionManager.instance.devicesInNetwork)
            } else {
                NetworkGraphViewModel.instance.updateDefaultGraphViewModel(devicesInNetwork: ConnectionManager.instance.devicesInDefaultSessionNetwork)
            }
        }
    }
    static let instance = NetworkGraphViewModel()
    /**Holds Devices in network graph**/
    var node: [SimpleNode] = []
    /**Holds  direct connection edge**/
    var edge: [SimpleEdge] = []
    
    @Published var graphViewModel: GraphViewModel = GraphViewModel(SimpleGraph(nodes: [], edges: []))
    @Published var graphViewModelForDefaultSession: GraphViewModel = GraphViewModel(SimpleGraph(nodes: [], edges: []))
    
    /**Create GraphViewModel for Network Graph(Used in DirectedGraph Framework) **/
    func updateGraphViewModel(devicesInNetwork: [String: [String]]) {
        if segmentOptions[selectedSegment] == NetworkGraphSegment.Custom {
            graphViewModel = getGraphViewModel(devicesInNetwork: devicesInNetwork)
        }
    }
    
    /**update GraphViewModel for Network Graph(Used in DirectedGraph Framework) **/
    func updateDefaultGraphViewModel(devicesInNetwork: [String: [String]]) {
        if segmentOptions[selectedSegment] == NetworkGraphSegment.Default {
            graphViewModelForDefaultSession = getGraphViewModel(devicesInNetwork: devicesInNetwork)
        }
    }
    
    func isCustomSessionCreated() -> Bool {
        if let sessionName = ConnectionManager.instance.sessionName {
            return sessionName.isEmpty ? false : true
        }
        return false
    }
    
    func getGraphViewModel(devicesInNetwork: [String: [String]]) -> GraphViewModel<SimpleGraph> {
        tempDevicesInNetwork.removeAll()
        node.removeAll()
        edge.removeAll()
        for key in devicesInNetwork {
            if tempDevicesInNetwork.isEmpty {
                tempDevicesInNetwork[key.key] = key.value
            } else {
                let target = key.value
                var tempTarget: [String] = [String]()
                for item in target {
                    if let arr = tempDevicesInNetwork[item] {
                        if !arr.contains(where: {$0 == key.key}) {
                            tempTarget.append(item)
                        }
                    } else {
                        tempDevicesInNetwork[key.key]?.append(item)
                    }
                }
                tempDevicesInNetwork[key.key] = tempTarget
            }
        }
        
        for source in tempDevicesInNetwork {
            // Used group as flag for Node Color (Self Node should be in different color)
            var group = 0
            if source.key == ConnectionManager.instance.devicePeerID.displayName {
                group = 1
            }
            node.append(SimpleNode(id: source.key, group: group))
            for target in source.value {
                edge.append(SimpleEdge(source: source.key, target: target, value: 2))
            }
        }
        return GraphViewModel(SimpleGraph(nodes: node, edges: edge))
    }
}
