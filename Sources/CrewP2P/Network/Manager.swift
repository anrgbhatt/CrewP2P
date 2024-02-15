//
//  Manager.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 15/03/23.
//

import Foundation
import MultipeerConnectivity
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes


extension ConnectionManager {
    
    public func initialization(deviceName: String, userDefaultsKeyForDefaultSession: String? = nil) {
        addAppCenterConfiguration()
        // loads core data stack
        DatabaseManager.sharedInstance.loadCoreDataStackOnce()
        
        // Broadcast message every n seconds to make aware of other devices its presence(Alive) in network
        timerForAlive?.invalidate()
        timerForAlive = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(broadcastAliveMessageToNetwork), userInfo: nil, repeats: true)
        
        self.userDefaultsKeyForDefaultSession = userDefaultsKeyForDefaultSession
        // Start default session
        startDefaultSession(deviceName: deviceName)
    }
    
    /// Method to Start the default Session
    /// - Parameter
    ///     - deviceName : device name received from client app.
    func startDefaultSession(deviceName: String) {
        stopDefaultSession()
        self.deviceName = deviceName
        createPeerID(displayName: deviceName)
        print("Default session started.")
        Analytics.trackEvent("Default session started.",
                             withProperties: ["Device Name": deviceName])
        DispatchQueue.main.async {
            self.serviceAdvertiserForDefaultSession = MCNearbyServiceAdvertiser(peer: self.devicePeerID,
                                                                                discoveryInfo: [Constant.P2PConstant.discoveryInfoKey:Constant.P2PConstant.P2PDefaultSession],
                                                                                serviceType: Constant.P2PConstant.P2PDefaultServiceType)
            self.serviceAdvertiserForDefaultSession.delegate = self
            
            self.serviceBrowserForDefaultSession = MCNearbyServiceBrowser(peer: self.devicePeerID,
                                                                          serviceType: Constant.P2PConstant.P2PDefaultServiceType)
            self.serviceBrowserForDefaultSession.delegate = self
            
            /// HOST: Automatically browses and invites all found devices
            if self.serviceBrowserForDefaultSession != nil {
                self.serviceBrowserForDefaultSession.startBrowsingForPeers()
            }
            
            /// JOIN: Automatically advertises and accepts all invites
            if self.serviceAdvertiserForDefaultSession != nil {
                self.serviceAdvertiserForDefaultSession.startAdvertisingPeer()
            }
        }
        
        // Start Timer for default session to check keep alive signal status.
        // Restart the session if device did not get keep alive signal.
        timerForCheckAliveDefaultSession = Timer.scheduledTimer(timeInterval:15, target: self, selector: #selector(notifieIfDeviceIsNotAliveForDefaultSession), userInfo: nil, repeats: true)
    }
    
    /// starts the MultiPeer service with a serviceType and the default deviceName
    /// - Parameters:
    ///     - sessionName: Provide a string to uniquely identify a session. Use same sessionName for all devices that should be part of that session
    ///     - deviceName: Provide a string to uniquely identify a device in a session
    ///     - retentionPeriod: Time in days until the data lives in the database. Default value is 15 days
    public func start(dataTransmissionMode: DataTransmissionMode,sessionName: String, deviceName: String, retentionPeriod: Int? = 15) {
        // Before start new custom session stop previously custom session if has
        stopCustomSession()
        self.transmissionMode = dataTransmissionMode
        if dataTransmissionMode == .Bluetooth {
            self.sessionName = sessionName
            self.deviceName = deviceName
            self.initBluetooth()
        } else {
            print("Custom session started.")
            Analytics.trackEvent("Custom session started.",
                                 withProperties: ["Session Name": sessionName])
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.sessionName = sessionName
                self.deviceName = deviceName
                if let retentionPeriod = retentionPeriod {
                    self.timeToLive = retentionPeriod
                }
                // Setup the service advertiser
                if self.serviceAdvertiser != nil {
                    self.serviceAdvertiser.stopAdvertisingPeer()
                }
                self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: self.devicePeerID,
                                                                   discoveryInfo: [Constant.P2PConstant.discoveryInfoKey:self.sessionName],
                                                                   serviceType: Constant.P2PConstant.P2PServiceType)
                self.serviceAdvertiser.delegate = self
                
                // Setup the service browser
                if self.serviceBrowser != nil {
                    self.serviceBrowser.stopBrowsingForPeers()
                }
                self.serviceBrowser = MCNearbyServiceBrowser(peer: self.devicePeerID,
                                                             serviceType: Constant.P2PConstant.P2PServiceType)
                self.serviceBrowser.delegate = self
                self.startInviting()
                self.startAccepting()
                
            }
            
            // Start Timer for custom session to check keep alive signal status.
            // Restart the session if device did not get keep alive signal for more than m seconds .
            self.timerForCheckAlive = Timer.scheduledTimer(timeInterval:15, target: self, selector: #selector(self.notifieIfDeviceIsNotAlive), userInfo: nil, repeats: true)
        }
    }
    
    /// stops the connection
    public func stop() {
        end()
    }
    
    // send data via bluetooth
    func sendDataThroughBluetooth(data: DataObject) {
        if let item = try? JSONEncoder().encode(data) {
            sendCentralData(item)
            sendPeripheralData(item)
        }
    }
    
    /// This method used to Sends an object to all  peers in network.
    /// this method is for both default session's peers & custom session's peers.
    /// - Parameters:
    ///     - data: Object (DataObject) to send to all connected peers.
    public func sendData(data: DataObject) {
        if self.transmissionMode == .Bluetooth  {
            var dataObject = data
            let arrConnectedPeers = self.sessionPeers.filter({$0.peripherial.state == .connected})
            dataObject.deliveredNodesBLE = arrConnectedPeers.map({$0.deviceName})
            dataObject.deliveredNodesBLE?.append(self.deviceName)
            self.sendDataThroughBluetooth(data: dataObject)
        } else {
            var dataObject: DataObject = data
            dataObject.deliveredNodes = data.isDataBelongsToDefaultSesssion ? connectedPeersInDefaultSession().map({$0.hashValue}) : connectedPeersInAllSession().map({$0.hashValue})
            
            if let selfPeerId = self.devicePeerID {
                dataObject.deliveredNodes?.append(selfPeerId.hashValue)
            }
            if data.isDataBelongsToDefaultSesssion ? isDefaultConnected : isConnected {
                do {
                    if let item = try? JSONEncoder().encode(dataObject) {
                        //Save data to db only if not belongs to alive signal and not to Default session
                        if dataObject.dataOperation != .alive && !data.isDataBelongsToDefaultSesssion {
                            DatabaseManager.sharedInstance.saveDataObject(obj: dataObject)
                        }
                        
                        // Send the data object to all peers.
                        for session in data.isDataBelongsToDefaultSesssion ? dicDefaultSessions : dicSessions {
                            if session.value.connectedPeers.count > 0 {
                                try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                            }
                        }
                    }
                } catch let error {
                    printDebug(error.localizedDescription)
                }
            } else {
                if dataObject.dataOperation != .alive && !data.isDataBelongsToDefaultSesssion {
                    DatabaseManager.sharedInstance.saveDataObject(obj: data)
                }
            }
        }
    }
    
    // Use for getting All devices in network.
    // Method request(using enum dataOperation as Network) all the peers to send its presence to the node.Once devices in network gets 'Network' dataOperation request, device broadcast its presence using dataOperation 'Broadast'.
    
    func getAllDevicesInNetwork() {
        devicesInNetwork.removeAll()
        devicesInNetwork[self.devicePeerID.displayName] = connectedPeersInAllSession().map({$0.displayName})
        if isConnected {
            
            var dataObject = DataObject(data: Data(), sender: self.devicePeerID.displayName, linkSession: false)
            dataObject.dataOperation = .Network
            dataObject.deliveredNodes = connectedPeersInAllSession().map({$0.hashValue})
            do {
                if let item = try? JSONEncoder().encode(dataObject) {
                    for session in dicSessions {
                        if session.value.connectedPeers.count > 0 {
                            try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                        }
                    }
                }
            } catch let error {
                printDebug(error.localizedDescription)
            }
        } else {
            NetworkGraphViewModel.instance.updateGraphViewModel(devicesInNetwork: self.devicesInNetwork)
            self.delegate?.didReceiveDeviceListInNetwork(devices: devicesInNetwork)
        }
    }
    
    // Use for getting All devices in Default Session network.
    // Method request(using enum dataOperation as Network) all the peers to send its presence to the node.Once devices in network gets 'Network' dataOperation request, device broadcast its presence using dataOperation 'Broadast'.
    func getAllDevicesInDefaultSessionNetwork() {
        devicesInDefaultSessionNetwork.removeAll()
        devicesInDefaultSessionNetwork[self.devicePeerID.displayName] = connectedPeersInDefaultSession().map({$0.displayName})
        if isDefaultConnected {
            
            var dataObject = DataObject(data: Data(), sender: self.devicePeerID.displayName, linkSession: false,isDataBelongsToDefaultSesssion: true)
            dataObject.dataOperation = .Network
            dataObject.deliveredNodes = connectedPeersInDefaultSession().map({$0.hashValue})
            do {
                if let item = try? JSONEncoder().encode(dataObject) {
                    for session in dicDefaultSessions {
                        if session.value.connectedPeers.count > 0 {
                            try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                        }
                    }
                }
            } catch let error {
                printDebug(error.localizedDescription)
            }
        } else {
            NetworkGraphViewModel.instance.updateDefaultGraphViewModel(devicesInNetwork: self.devicesInDefaultSessionNetwork)
        }
    }
    
    // Broadcast the data to all the devices when device gets the request for Network
    func broadcastDataForDeivceList() {
        var dataObject = DataObject(data: Data(), sender: self.devicePeerID.displayName, linkSession: false)
        dataObject.dataOperation = .Broadcast
        dataObject.recepients = connectedPeersInAllSession().map({$0.displayName})
        dataObject.deliveredNodes = connectedPeersInAllSession().map({$0.hashValue})
        if isConnected {
            do {
                if let item = try? JSONEncoder().encode(dataObject) {
                    for session in dicSessions {
                        if session.value.connectedPeers.count > 0 {
                            try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                        }
                    }
                }
            } catch let error {
                printDebug(error.localizedDescription)
            }
        }
    }
    
    // Broadcast the data to all the devices(Which is connected to default session) when device gets the request for Network
    func broadcastDataForDeivceListForDefaultSession() {
        var dataObject = DataObject(data: Data(), sender: self.devicePeerID.displayName, linkSession: false,isDataBelongsToDefaultSesssion: true)
        dataObject.dataOperation = .Broadcast
        dataObject.recepients = connectedPeersInDefaultSession().map({$0.displayName})
        dataObject.deliveredNodes = connectedPeersInDefaultSession().map({$0.hashValue})
        if isDefaultConnected {
            do {
                if let item = try? JSONEncoder().encode(dataObject) {
                    for session in dicDefaultSessions {
                        if session.value.connectedPeers.count > 0 {
                            try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                        }
                    }
                }
            } catch let error {
                printDebug(error.localizedDescription)
            }
        }
    }
    
    // delegate for getAllDeives in Network
    func didReceiveNetworkList() {
        devicesInNetworkTask?.cancel()
        let task = DispatchWorkItem {
            NetworkGraphViewModel.instance.updateGraphViewModel(devicesInNetwork: self.devicesInNetwork)
            self.delegate?.didReceiveDeviceListInNetwork(devices: self.devicesInNetwork)
        }
        self.devicesInNetworkTask = task
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: task)
    }
    
    // delegate for getAllDeives in Network for Default session
    func didReceiveNetworkListForDefaultSession() {
        devicesInNetworkForDefaultSessionTask?.cancel()
        let task = DispatchWorkItem {
            NetworkGraphViewModel.instance.updateDefaultGraphViewModel(devicesInNetwork: self.devicesInDefaultSessionNetwork)
        }
        self.devicesInNetworkForDefaultSessionTask = task
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: task)
    }
    
    public func fetchData(for sessionID: String? = nil,
                          since: Date?,
                          sortOrder: SortOrder = .forward,
                          completion: @escaping (([DataObject]) -> ())) {
        DispatchQueue.global().async {
            DatabaseManager.sharedInstance.fetchData(for: sessionID, from: since, intendedRecepient: nil, sortOrder: sortOrder) { result in
                completion(result)
            }
        }
    }
    
    public func syncDatabase(since: Date?) {
        if isConnected {
            var dataObj = DataObject(data: Data(), sender: self.devicePeerID.displayName, linkSession: true)
            dataObj.dataOperation = .Fetch
            dataObj.timeStamp = since ?? Date.init(timeIntervalSinceReferenceDate: 0)
            dataObj.deliveredNodes = connectedPeersInAllSession().map({$0.hashValue})
            if let selfPeerId = self.devicePeerID {
                dataObj.deliveredNodes?.append(selfPeerId.hashValue)
            }
            do {
                if let item = try? JSONEncoder().encode(dataObj) {
                    for session in dicSessions {
                        if session.value.connectedPeers.count > 0 {
                            try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                        }
                    }
                }
            } catch let error {
                printDebug(error.localizedDescription)
            }
        }
        syncDefaultSessionData()
    }
    
    func syncDefaultSessionData() {
        if isDefaultConnected {
            var dataObj = DataObject(data: Data(), sender: self.devicePeerID.displayName, linkSession: true,isDataBelongsToDefaultSesssion: true)
            dataObj.dataOperation = .Fetch
            dataObj.deliveredNodes = connectedPeersInDefaultSession().map({$0.hashValue})
            if let selfPeerId = self.devicePeerID {
                dataObj.deliveredNodes?.append(selfPeerId.hashValue)
            }
            do {
                if let item = try? JSONEncoder().encode(dataObj) {
                    for session in dicDefaultSessions {
                        if session.value.connectedPeers.count > 0 {
                            try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                        }
                    }
                }
            } catch let error {
                printDebug(error.localizedDescription)
            }
        }
        
    }
    
    func cleanUpDatabase() {
        // delete data from database that has expired
        let allowedDataDate = Date().addingTimeInterval(-Double(timeToLive*24*60*60))
        DatabaseManager.sharedInstance.deleteData(before: allowedDataDate, for: self.sessionName)
        // send request to all connected device to delete their data as well
        OperationQueue.main.addOperation {
            self.delegate?.databaseSynced()
        }
        if isConnected {
            var dataObj = DataObject(data: Data(), sender: self.devicePeerID.displayName, linkSession: true)
            dataObj.dataOperation = .Delete
            dataObj.timeStamp = allowedDataDate
            do {
                if let item = try? JSONEncoder().encode(dataObj) {
                    
                    for session in dicSessions {
                        if session.value.connectedPeers.count > 0 {
                            try session.value.send(item, toPeers: (session.value.connectedPeers), with: .reliable)
                        }
                    }
                }
            } catch let error {
                printDebug(error.localizedDescription)
            }
        }
    }
    /// Method to delete expired Records from coredata
    /// Parameter : None
    /// Return : None
    public func deleteExpiredDataFromDatabase() {
        DatabaseManager.sharedInstance.deleteExpiredData()
    }
    
    ///get stored default session data from UserDefault
    ///Return: Data (default session's data)
    func getDefaultSessionUserDefaultData() -> Data {
        guard let userDefaultKey = self.userDefaultsKeyForDefaultSession, let userDefaultsData = UserDefaults.standard.data(forKey: userDefaultKey) else {
            return Data()
        }
        return userDefaultsData
    }
    
    private func addAppCenterConfiguration() {
        AppCenter.start(withAppSecret: Constant.AppcenterKey.appCenterSecretKey, services: [
            Analytics.self,
            Crashes.self
        ])
    }
}
