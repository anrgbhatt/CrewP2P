//
//  ConnectionManagerExtension.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 27/02/23.
//

import Foundation
import MultipeerConnectivity

// MARK: - Advertiser Delegate
extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    
    /// Received invitation
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("didReceiveInvitationFromPeer: \(peerID) with context: \(String(describing: String(data: context ?? Data(), encoding: .utf8)))")
        
        guard let context = context else {
            printDebug("Did receive invite without any additional context, hence discarding the invite ")
            return
        }
        
        guard  let sessionName = String(data: context, encoding: .utf8) else { return  }
        
        /// check Received invitation is from Default Session or Custom session.
        /// invoke invitationHandler accordingly
        
        if sessionName == Constant.P2PConstant.P2PDefaultSession {
            /// get the default session object from 'dicDefaultSessions' and call the invitationHandler
            if let session = self.dicDefaultSessions[peerID.hashValue] {
                invitationHandler(true, session)
            }
        }
        if sessionName == self.sessionName {
            /// get the custom session object from 'dicSessions' and call the invitationHandler
            if let session = self.dicSessions[peerID.hashValue] {
                invitationHandler(true, session)
            }
        }
    }
    
    /// Error, could not start advertising
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        printDebug("Could not start advertising due to error: \(error)")
    }
    
}

// MARK: - Browser Delegate
extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    
    /// Found a peer, update the list of available peers
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("Found peer: \(peerID) with discovery info: \(String(describing: info))")
        guard let info = info else {
            printDebug("No discovery info found for the peer, hence discarding it")
            return
        }
        
        /// Check wheather the found peer is adverised for 'Default Session' or 'Custom session'
        /// Invite the peer to join and store the MCSession object in MCSession dictionary(dicDefaultSessions/dicSessions) variable.
        /// Variable dicDefaultSessions/dicSessions is used to get all the directly connected peers in Default session and custom session respectively.
        if info[Constant.P2PConstant.discoveryInfoKey] == Constant.P2PConstant.P2PDefaultSession {
            /// Invite the peer to join the default session.
            browser.invitePeer(peerID, to: createSessionObject(peerID: peerID, info: info), withContext: Constant.P2PConstant.P2PDefaultSession.data(using: .utf8), timeout: connectionTimeout)
        }
        
        if info[Constant.P2PConstant.discoveryInfoKey] == self.sessionName {
            /// Update the list of available peers
            if availablePeers.contains(where: {$0.peerID != peerID}) {
                availablePeers.append(Peer(peerID: peerID, state: .notConnected))
            }
            
            /// Invite the peer to join the custom session.
            browser.invitePeer(peerID, to: createSessionObject(peerID: peerID, info: info), withContext: self.sessionName.data(using: .utf8), timeout: connectionTimeout)
        }
    }
    
    /// Lost a peer, update the list of available peers
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID)")
        
        /// Update the lost peer
        availablePeers = availablePeers.filter { $0.peerID != peerID }
        otherPeers = otherPeers.filter { $0.peerID != peerID }
        otherPeers.append(Peer(peerID: peerID, state: .notConnected, lastSeen: Date.now))
        
        /// Remove the peer from dicSessions variable.
        dicSessions.removeValue(forKey: peerID.hashValue)
        
        /// Update all custom sessions connected Peers
        getAllConnectedPeers()
        
        /// Update all default connected Peers
        getAllDefaultConnectedPeers()
        
        /// Use for getting All devices in network for custom session.
        getAllDevicesInNetwork()
        
        /// Use for getting All devices in network for default session.
        getAllDevicesInDefaultSessionNetwork()
    }
    
    /// Error, could not start browsing
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        printDebug("Could not start browsing due to error: \(error)")
    }
    
    
    /// Perfom operation on data received for Custom session
    /// Action based on the dataOperations in DataObject.
    /// - Parameters:
    ///     - MCSession:  Session Object
    ///     - MCPeerID: Peer Id
    ///     - DataObject: DataObject
    func customSessionDidReceiveDataOperation(session: MCSession, peerID: MCPeerID, dataObj: DataObject) {
        switch dataObj.dataOperation {
        case .Fetch:
            OperationQueue.main.addOperation {
                /// fetch the record from coreData related to specified session only with time stamp
                DatabaseManager.sharedInstance.fetchData(for: self.sessionName,from: dataObj.timeStamp, intendedRecepient: dataObj.sender) { dataObject in
                    var data = dataObject
                    if data.count > 0 {
                        if let selfPeerId = self.devicePeerID {
                            data[0].deliveredNodes?.append(selfPeerId.hashValue)
                            data[0].deliveredNodes?.append(peerID.hashValue)
                        }
                    }
                    /// send the data to peer
                    do {
                        if let item = try? JSONEncoder().encode(data) {
                            try session.send(item, toPeers: session.connectedPeers.filter({$0.displayName == dataObj.sender}), with: MCSessionSendDataMode.reliable)
                        }
                    } catch {
                        printDebug("sending failed for DataObjects : \(error.localizedDescription)")
                    }
                }
            }
            
        case .FetchResponse:
            OperationQueue.main.addOperation {
                self.delegate?.databaseSynced()
            }
            
        case .Delete:
            DispatchQueue.main.async {
                /// Delete all data from coredata before the given timestamp.
                DatabaseManager.sharedInstance.deleteData(before: dataObj.timeStamp, for: self.sessionName)
            }
            OperationQueue.main.addOperation {
                /// databaseSynced: delegate is called as database updated(Performed Delete operation)
                self.delegate?.databaseSynced()
                self.sendDataToIsolatedNode(dataObj: dataObj)
            }
            /// Used to get the devices in network
        case .Network:
            OperationQueue.main.addOperation {
                self.broadcastDataForDeivceList()
                self.sendDataToIsolatedNode(dataObj: dataObj)
            }
            /// when ever peer received 'Network' DataOperation peers sends its presence in network
            /// using 'Broadcast' DataOperation
        case .Broadcast:
            OperationQueue.main.addOperation {
                self.devicesInNetwork[dataObj.sender] = dataObj.recepients
                self.sendDataToIsolatedNode(dataObj: dataObj)
                self.didReceiveNetworkList()
            }
            
            /// This is used for alive signal received every n(5) seconds.
            /// Update the aliveNode with dataObject when ever alive signal(dataOperation) received.
        case .alive:
            OperationQueue.main.addOperation {
                if let index = self.aliveNodes.firstIndex(where: {$0.sender == dataObj.sender}) {
                    self.aliveNodes[index] = dataObj
                } else {
                    self.aliveNodes.append(dataObj)
                }
                if self.connectedPeersInAllSession().contains(where: {$0.displayName == dataObj.sender}) && self.connectedPeers.contains(where: {$0.peerID.displayName != dataObj.sender}) {
                    
                    // Update all connectedpeers
                    self.getAllConnectedPeers()
                    // Update all otherPeers
                    self.otherPeers = self.otherPeers.filter({$0.peerID.displayName != dataObj.sender})
                    
                }
                self.sendDataToIsolatedNode(dataObj: dataObj)
            }
            
        default:
            DispatchQueue.main.async {
                DatabaseManager.sharedInstance.saveDataObject(obj: dataObj)
            }
            OperationQueue.main.addOperation {
                self.delegate?.peerDidReceiveData(data: dataObj)
                self.sendDataToIsolatedNode(dataObj: dataObj)
            }
        }
        
    }
    
    /// Perfom operation on data received for default session
    /// Action based on the dataOperations in DataObject.
    /// - Parameters:
    ///     - MCSession:  Session Object
    ///     - DataObject: DataObject
    func defaultSessionDidReceiveDataOperation(session: MCSession,dataObj: DataObject) {
        
        switch dataObj.dataOperation {
            /// Fetch the data from Storage here in default session the storage is user default
        case .Fetch:
            var data = dataObj
            data.dataOperation = .Add
            let defaultSessionData = getDefaultSessionUserDefaultData()
            data.data = defaultSessionData
            do {
                /// Send the data to peer.
                if let item = try? JSONEncoder().encode(data) {
                    try session.send(item, toPeers: session.connectedPeers.filter({$0.displayName == dataObj.sender}), with: MCSessionSendDataMode.reliable)
                }
            } catch {
                printDebug("sending failed for DefaultSessionObjects : \(error.localizedDescription)")
            }
            
            /// This is used for alive signal received every n(5) seconds.
            /// Update the aliveNode with dataObject when ever alive signal(dataOperation) received.
        case .alive:
            OperationQueue.main.addOperation {
                if let index = self.aliveNodesForDefaultSession.firstIndex(where: {$0.sender == dataObj.sender}) {
                    /// Save the peer data in alive nodes varaible if peer is new.
                    self.aliveNodesForDefaultSession[index] = dataObj
                } else {
                    /// update the peer info (DataObject) in keep alive variable.
                    self.aliveNodesForDefaultSession.append(dataObj)
                }
                /// pass the data to isolated node
                self.sendDataToIsolatedNode(dataObj: dataObj)
            }
            
            /// Used to get the devices in network
        case .Network:
            OperationQueue.main.addOperation {
                // Broadcast the data to all the devices(Which is connected to default session) when device gets the request for Network dataOperations
                self.broadcastDataForDeivceListForDefaultSession()
                
                /// pass the data to isolated node
                self.sendDataToIsolatedNode(dataObj: dataObj)
            }
            
            /// when ever peer received 'Network' DataOperation peers sends its presence in network
            /// using 'Broadcast' DataOperation
        case .Broadcast:
            OperationQueue.main.addOperation {
                self.devicesInDefaultSessionNetwork[dataObj.sender] = dataObj.recepients
                /// pass the data to isolated node
                self.sendDataToIsolatedNode(dataObj: dataObj)
                self.didReceiveNetworkListForDefaultSession()
            }
            
        default:
            OperationQueue.main.addOperation {
                self.sendDataToIsolatedNode(dataObj: dataObj)
                /// send the default session data to application
                self.delegate?.didReceiveDefaultSessionData(data: dataObj)
            }
        }
    }
}

// MARK: - Session Delegate
extension ConnectionManager: MCSessionDelegate {
    
    /// Peer changed state, update all connected peers and send new connection list to delegate connectedDevicesChanged
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        /// If the new state is connected, then remove it from the available peers
        /// Otherwise, update the state
        switch state {
        case .connected:
            print("Connected: \(peerID.displayName)")
        case .connecting:
            print("Connecting: \(peerID.displayName)")
            
        case .notConnected:
            print("Not Connected: \(peerID.displayName)")
            
        @unknown default:
            printDebug("Unknown state received: \(peerID.displayName)")
        }
        
        /// Update all peers
        DispatchQueue.main.async {
            /// Update all connected peers
            self.getAllConnectedPeers()
            self.getAllDefaultConnectedPeers()
            
            /// Update all available peers
            if self.connectedPeersInAllSession().contains(where: { $0 == peerID}) {
                self.availablePeers = self.availablePeers.filter { $0.peerID != peerID }
            } else {
                self.availablePeers.filter { $0.peerID == peerID }.first?.state = state
            }
            
            // Update all other peers
            if self.connectedPeersInAllSession().contains(where: { $0 == peerID}) || self.availablePeers.contains(where: { $0.peerID == peerID}) {
                self.otherPeers = self.otherPeers.filter { $0.peerID != peerID }
            }
            if state == .connected || state == .notConnected {
                /// update All devices in network for custom session.
                /// Also it will invoke delegate having List of devices in Network
                self.getAllDevicesInNetwork()
                
                /// Invoke delegate 'didReceiveDeviceListInNetwork' having list of directly connected devices
                self.delegate?.didReceiveDeviceListInNetwork(devices: self.devicesInNetwork)
                
                /// update All devices in network for default session.
                self.getAllDevicesInDefaultSessionNetwork()
            }
        }
        
        // Send new connection list to delegate
        OperationQueue.main.addOperation {
            self.delegate?.peerListChanged(devices: self.connectedPeers)
        }
    }
    
    /// Received data, update delegate didRecieveData
    /// When ever Peer received data this delegate invoked
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("Received data: \(data.count) bytes")
        
        do {
            let dataObj = try JSONDecoder().decode(DataObject.self, from: data)
            print("Decoding passed for DataObject : \(dataObj)")
            
            /// check received data is for default session or custom session.
            /// Perform Operation on received data accordingly.
            if dataObj.isDataBelongsToDefaultSesssion {
                /// perfom operation on received data for default session.
                self.defaultSessionDidReceiveDataOperation(session: session, dataObj: dataObj)
            } else {
                /// perfom operation on received data for custom session.
                self.customSessionDidReceiveDataOperation(session: session, peerID: peerID, dataObj: dataObj)
            }
        } catch {
            // printDebug("Decoding failed for DataObject : \(error)")
        }
        
        do {
            let dataObjArray = try JSONDecoder().decode([DataObject].self, from: data)
            printDebug("Decoding passed for dataObjArray : \(dataObjArray)")
            
            DispatchQueue.main.async { [weak self] in
                Task {
                    await DatabaseManager.sharedInstance.saveDataObjects(objs: dataObjArray)
                    self?.delegate?.databaseSynced()
                }
                self?.updateDataBaseToIsolatedNode(dataObj: dataObjArray)
            }
        } catch {
            // printDebug("Decoding failed for DataObjectss : \(error)")
        }
        
    }
    
    /// Received stream
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        printDebug("Received stream")
    }
    
    /// Started receiving resource
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        printDebug("Started receiving resource with name: \(resourceName)")
    }
    
    /// Finished receiving resource
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        printDebug("Finished receiving resource with name: \(resourceName)")
    }
    
    public func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        if let certificates = certificate, let firstCert = certificates.first {
            if (shouldTrust(externalCertificate: (firstCert as! SecCertificate))) == true {
                certificateHandler(true)
            } else {
                printDebug("Found a device on network whose certificate evaluation failed")
                certificateHandler(false)
            }
        } else {
            printDebug("Found a device on network without a valid certificate")
            certificateHandler(true)
        }
    }
    
}
