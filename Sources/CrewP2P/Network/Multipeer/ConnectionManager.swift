//
//  ConnectionManager.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 09/02/23.
//

import Foundation
import MultipeerConnectivity
import Combine
import DirectedGraph
import CoreBluetooth

/// Main Class for MultiPeer
public class ConnectionManager: NSObject, Connection, ObservableObject {
    
    /// Singleton instance - call via MultiPeer.instance
    public static let instance: ConnectionManager = ConnectionManager()
    
    // MARK: Properties
    
    /** Conforms to MultiPeerDelegate: Handles receiving data and changes in connections */
    public weak var delegate: ConnectionDelegate?
    
    /** Name of MultiPeer session: Up to one hyphen (-) and 15 characters */
    // internal var serviceType: String!
    
    /** Device's name */
    public var devicePeerID: MCPeerID!
    
    /** Name of MultiPeer session*/
    @Published internal var sessionName: String!
    var deviceName: String = ""
    
    /** UserDefaults key for defaultSession data
     provided by the client app at the time of initlisation
     **/
    var userDefaultsKeyForDefaultSession: String?
    
    /** Advertises session */
    public var serviceAdvertiser: MCNearbyServiceAdvertiser!
    
    /** Browses for sessions */
    public var serviceBrowser: MCNearbyServiceBrowser!
    
    /** Advertises  for default Session*/
    public var serviceAdvertiserForDefaultSession: MCNearbyServiceAdvertiser!
    
    /** Browses for default Session*/
    public var serviceBrowserForDefaultSession: MCNearbyServiceBrowser!
    
    /// Amount of time to spend connecting before timeout
    public var connectionTimeout = 10.0
    
    /// Peers available to connect to
    @Published public var availablePeers: [Peer] = []
    
    /// All Peers connected in custom session.
    @Published public var connectedPeers: [Peer] = []
    
    /// All Peers connected in default session.
    @Published public var defaultConnectedPeers: [Peer] = []
    
    /// Peers recently connected to
    @Published public var otherPeers: [Peer] = []
    /// Prints out all errors and status updates
    public var debugMode = false
    
    /// Time in days after which a transaction deleted from all databases
    var timeToLive = 15
    
    var completion: (([DataObject]) -> ())?
    
    /** Dictionary of all devices (where key are device and value their direct connection)*/
    var devicesInNetwork: [String: [String]] = [String: [String]]()
    
    /** Dictionary of all devices in default Session (where key are device and value their direct connection)*/
    var devicesInDefaultSessionNetwork: [String: [String]] = [String: [String]]()
    
    /**Invoked this work item when all devices sent their broadcast operation when method called to get all devices in network in custom session.
     **/
    var devicesInNetworkTask: DispatchWorkItem?
    
    /**Invoked this work item when all devices sent their broadcast operation when method called to get all devices in network in default session.
     **/
    var devicesInNetworkForDefaultSessionTask: DispatchWorkItem?
    
    /**Timer for broadcast alive signal every n seconds */
    var timerForAlive: Timer?
    
    /**Timer for checking if deive sending its alive signal or not (if device is not sending it alive signal for certain time period (lets say 15 seconds) we consider that perticular device as offline **/
    var timerForCheckAlive: Timer?
    
    /**Timer for checking if deive sending its alive signal or not (if device is not sending it alive signal for certain time period (lets say 15 seconds) we consider that perticular device as offline **/
    var timerForCheckAliveDefaultSession: Timer?
    
    /**Holds all the alive nodes(whos is sending alive signal regularly)**/
    var aliveNodes: [DataObject] = []
    /**Holds all the alive nodes(whos is sending alive signal regularly)**/
    var aliveNodesForDefaultSession: [DataObject] = []
    // MARK: - Initializers
    
    // deinit: stop advertising and browsing services
    deinit {
        disconnect()
    }
    
    ///  Dictionary for created custom session , Here key is the PeerId's hash Value.
    var dicSessions: [Int:MCSession] = [:]
    
    ///  Dictionary for created session for defaultSession , Here key is the PeerId's hash Value.
    var dicDefaultSessions: [Int:MCSession] = [:]
    
    // Mark: Bluetooth
    let peripheralManagerQueue = DispatchQueue(label: "com.p2p.bluetooth")
    var transmissionMode: DataTransmissionMode?
    var arrData: [Data] = []
    let semaphore = DispatchSemaphore(value: 1)
    var maximumWriteValueLength = 0
    @Published var centralDevices: Set<String> = Set()
    
    var centralManager: CBCentralManager?
    // A strong reference to a detected matching peripheral from the central manager
    @Published var sessionPeers: Set<BLPeer> = Set()
    // Per, name, state
    var dicPeripherals:[CBPeripheral: CBCharacteristic] = [:]
    // The peripheral advertising ourselves
    var peripheralManager: CBPeripheralManager?
    
    // If we join the connection as a peripheral, we maintain a reference to our central
    @Published var centrals: Set<CBCentral> = Set()
    // The characteristic of the service that carries out chat data (when we are a central)
    var centralCharacteristic: CBCharacteristic?
    
    // The characteristic of the service that carries out chat data (when we are a peripheral)
    // Create the characteristic which will be the conduit for our chat data.
    // Make sure the properties are set to writeable so we can send data upstream
    // to the central, and notifiable, so we'll receive callbacks when data comes downstream
    var peripheralCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: BluetoothConstants.chatCharacteristicID, properties: [.write, .notify], value: nil, permissions: .writeable)
    
    var receivedChunks: [DataPacket] = []
    // MARK: - Methods
    
    /// HOST: Automatically browses and invites all found devices
    func startInviting() {
        if self.serviceBrowser != nil {
            self.serviceBrowser.startBrowsingForPeers()
        }
        if self.serviceBrowserForDefaultSession != nil {
            self.serviceBrowserForDefaultSession.startBrowsingForPeers()
        }
    }
    
    /// JOIN: Automatically advertises and accepts all invites
    func startAccepting() {
        if self.serviceAdvertiser != nil {
            self.serviceAdvertiser.startAdvertisingPeer()
        }
        if self.serviceAdvertiserForDefaultSession != nil {
            self.serviceAdvertiserForDefaultSession.startAdvertisingPeer()
        }
    }
    
    /// Stops the invitation process
    private func stopInviting() {
        if self.serviceBrowser != nil {
            self.serviceBrowser.stopBrowsingForPeers()
        }
    }
    
    /// Stops accepting invites and becomes invisible on the network
    private func stopAccepting() {
        if self.serviceAdvertiser != nil {
            self.serviceAdvertiser.stopAdvertisingPeer()
        }
    }
    
    /// Stops all invite/accept services
    public func stopSearching() {
        stopAccepting()
        stopInviting()
    }
    
    /// Disconnects from the current session(custom session) and stops all searching activity
    public func disconnect() {
        if isConnected {
            for (_, session) in dicSessions {
                session.disconnect()
            }
            // update(empty) connected, available, other and alive nodes.
            connectedPeers.removeAll()
            availablePeers.removeAll()
            otherPeers.removeAll()
            dicSessions.removeAll()
            aliveNodes.removeAll()
            self.sessionName = ""
        }
        // invalidate timer for keep alive signal for custom session.
        timerForCheckAlive?.invalidate()
    }
    
    /// Stops all invite/accept services, disconnects from the current session, and stops all searching activity
    public func end() {
        stopCustomSession()
        stopDefaultSession()
    }
    
    
    /// Stop all invite/accept services of default session
    /// Disconnect all default sessions.
    /// Update(empty) alive nodes.
    func stopDefaultSession() {
        if self.serviceAdvertiserForDefaultSession != nil {
            self.serviceAdvertiserForDefaultSession.stopAdvertisingPeer()
        }
        if self.serviceBrowserForDefaultSession != nil {
            self.serviceBrowserForDefaultSession.stopBrowsingForPeers()
        }
        
        if isDefaultConnected {
            for (_, session) in dicDefaultSessions {
                session.disconnect()
            }
            defaultConnectedPeers.removeAll()
            dicDefaultSessions.removeAll()
            aliveNodesForDefaultSession.removeAll()
        }
        timerForCheckAliveDefaultSession?.invalidate()
    }
    
    /// Stop custom session.
    func stopCustomSession() {
        stopSearching()
        disconnect()
        otherPeers.removeAll()
    }
    
    /// Returns true if there are any connected peers
    public var isConnected: Bool {
        return connectedPeers.count > 0
    }
    
    /// Returns true if there are any connected peers
    public var isDefaultConnected: Bool {
        return defaultConnectedPeers.count > 0
    }
    
    /// This function creates a MCPeerId object once with the passed diplayName and then archives it for future use.
    func createPeerID(displayName: String) {
        let oldDisplayName = UserDefaults.standard.string(forKey: "kDisplayNameKey")
        
        do {
            if oldDisplayName == displayName {
                if let peerIDData = UserDefaults.standard.data(forKey: "kPeerIDKey") {
                    self.devicePeerID = try NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: peerIDData)
                }
            } else {
                self.devicePeerID = MCPeerID(displayName: displayName)
                let peerIDData = try NSKeyedArchiver.archivedData(withRootObject: self.devicePeerID as Any, requiringSecureCoding: false)
                UserDefaults.standard.set(displayName, forKey: "kDisplayNameKey")
                UserDefaults.standard.set(peerIDData, forKey: "kPeerIDKey")
                UserDefaults.standard.synchronize()
            }
            debugPrint("generated peer id \(String(describing: self.devicePeerID))")
        } catch {
            debugPrint("Could not generate peer id \(error)")
        }
        
    }
    
    /// This variable holds the reference to the SecIdentity object which is extracted from the p12 file . This identity is then passed along as a parameter when creating a MCSEssion object
    lazy var identity: SecIdentity? = {
       // guard let pspBundle = Bundle(identifier: "com.app.CrewP2PFramework") else { return nil }
        guard let url = Bundle.module.url(forResource: "Certificates", withExtension: "p12") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            var importResult: CFArray? = nil
            let err = SecPKCS12Import( data as NSData, [kSecImportExportPassphrase as String: "ThisCertificateIsForCrew@pps"] as NSDictionary, &importResult)
            guard err == errSecSuccess else { debugPrint("error \(err) "); return nil }
            let identityDictionaries = importResult as! [[String:Any]]
            return (identityDictionaries[0][kSecImportItemIdentity as String] as! SecIdentity)
        } catch {
            debugPrint("error \(error) ")
            return nil
        }
    }()
}

// MARK: - Certificate handling
extension ConnectionManager {
    
    /// validates the passed certificate and matches its public key with the certificate that is stored locally in the framework
    /// - Parameters:
    ///     - externalCertificate: Provide a SecCertificate which you would like to validate and match with stored certificate
    func shouldTrust(externalCertificate: SecCertificate?) -> Bool {
        guard let externalCertificate = externalCertificate else { return false }
        
        // 1. create a trust object from certificate and evaluate, if trusted, get public key, if not trusted, return
        guard let externalKey = getPublicKeyFromCertificate(certificate: externalCertificate, validateTrust: true) else { return false }
        
        // 2. get public key from internal certificate
        guard let identity = identity else { return false }
        guard let internalCertificate = getCertificateFromIdentity(identity: identity) else { return false }
        guard let internalKey = getPublicKeyFromCertificate(certificate: internalCertificate, validateTrust: false) else { return false }
        
        // match both keys and return result
        return externalKey == internalKey
    }
    
    /// extracts the public key from the SecCertificate.
    /// - Parameters:
    ///     - certificate: Provide a SecCertificate from which you want to extract the public key
    ///     - validateTrust: if this is set to true, passed certificate is first validated, and if validation is passed then only public key is extracted
    func getPublicKeyFromCertificate(certificate: SecCertificate, validateTrust: Bool) -> SecKey? {
        var key: SecKey?
        guard let identity = identity else { return nil }
        let policy = SecPolicyCreateBasicX509()
        var expTrust: SecTrust?
        let status = SecTrustCreateWithCertificates([certificate] as CFArray, policy, &expTrust)
        if let expTrust = expTrust, status == errSecSuccess {
            if validateTrust {
                let statusForAnchor = SecTrustSetAnchorCertificates(expTrust, [getCertificateFromIdentity(identity: identity)] as CFArray)
                if statusForAnchor == errSecSuccess {
                    let isServerTrusted = SecTrustEvaluateWithError(expTrust, nil)
                    if isServerTrusted {
                        key = SecTrustCopyKey(expTrust)
                    }
                }
            } else {
                key = SecTrustCopyKey(expTrust)
            }
        }
        return key
    }
    
    /// extracts the SecCertificate from SecIdentity
    /// - Parameters:
    ///     - identity: Provide a SecIdentity from which you want to extract the SecCertificate
    func getCertificateFromIdentity(identity: SecIdentity) -> SecCertificate?{
        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        guard status == errSecSuccess else { return nil }
        return certificate
    }
    
    // Create separate session for each Peer id.
    /// - Parameters:
    ///     - MCPeerID:  Peer id
    ///     - info: Discovery info
    func createSessionObject(peerID: MCPeerID,info: [String: String])-> MCSession {
        
        if let identity = identity {
            return getMCSessionObject(peerID: peerID, info: info, securityIdentity: [identity])
        } else {
            return getMCSessionObject(peerID: peerID, info: info, securityIdentity: nil)
        }
    }
    
    // Get MCsession object for each Peer id and Add created session in to the dictionary(dicDefaultSessions/dicSessions variable.
    /// Variable dicDefaultSessions/dicSessions is used to get all the directly connected peers in Default session and custom session respectively.
    /// - Parameters:
    ///     - MCPeerID:  Peer id
    ///     - info: Discovery info
    ///     - securityIdentity: securityIdentity
    func getMCSessionObject(peerID: MCPeerID,info: [String: String], securityIdentity identity: [SecIdentity]?) -> MCSession {
        
        let sessionObject = MCSession(peer: self.devicePeerID, securityIdentity: identity, encryptionPreference: .required)
        sessionObject.delegate = self
        if info[Constant.P2PConstant.discoveryInfoKey] == Constant.P2PConstant.P2PDefaultSession {
            dicDefaultSessions[peerID.hashValue] = sessionObject
        } else {
            dicSessions[peerID.hashValue] = sessionObject
        }
        return sessionObject
    }
    
    /// Publish all custom sessions connected Peers
    func getAllConnectedPeers() {
        var peers: [Peer] = []
        for session in dicSessions {
            if session.value.connectedPeers.count > 0 {
                peers.append(contentsOf: session.value.connectedPeers.map { Peer(peerID: $0, state: .connected)})
            }
        }
        connectedPeers = peers
    }
    
    /// Publish all default connected Peers
    func getAllDefaultConnectedPeers() {
        var peers: [Peer] = []
        for session in dicDefaultSessions {
            if session.value.connectedPeers.count > 0 {
                peers.append(contentsOf: session.value.connectedPeers.map { Peer(peerID: $0, state: .connected)})
            }
        }
        defaultConnectedPeers = peers
    }
    
    /// Return array of all connected Peers from all session
    func connectedPeersInAllSession() -> [MCPeerID] {
        var peers: [MCPeerID] = []
        for session in dicSessions {
            if session.value.connectedPeers.count > 0 {
                peers.append(contentsOf: session.value.connectedPeers)
            }
        }
        return peers
    }
    
    /// Return array of all connected Peers in default session
    func connectedPeersInDefaultSession() -> [MCPeerID] {
        var peers: [MCPeerID] = []
        for session in dicDefaultSessions {
            if session.value.connectedPeers.count > 0 {
                peers.append(contentsOf: session.value.connectedPeers)
            }
        }
        return peers
    }
    
    
    /// get all connected node and compare with recevied node(deliveredNodes)
    /// if current node has more connection, get that node and send the data
    /// with same dataobject appending its all connected node(include self as well to avaoid cycle)
    func sendDataToIsolatedNode(dataObj: DataObject) {
        
        //Get All Node from All Session
        
        var connnectedWithSelf = dataObj.isDataBelongsToDefaultSesssion ?  connectedPeersInDefaultSession().map({$0.hashValue}) : connectedPeersInAllSession().map({$0.hashValue})
        
        if let selfPeerId = self.devicePeerID {
            //Append devicePeerID
            connnectedWithSelf.append(selfPeerId.hashValue)
        }
        
        if let deliveredNodes =  dataObj.deliveredNodes {
            var isolatedNodes:[Int] = []
            // Here compare the current node's all connected node(in All session) and get extra node if current node has more node than deliveredNodes (from dataObj.deliveredNodes) save it in Array named as isolatedNodes
            for node in connnectedWithSelf {
                if !deliveredNodes.contains(where: {$0 == node}) {
                    isolatedNodes.append(node)
                }
            }
            
            // if there is/are extra node (isolatedNodes) get all connected Peers In AllSession and store append it in DataObject's deliveredNodes and send the the data to all isolatednodes.
            if isolatedNodes.count > 0 {
                var dataObject: DataObject = dataObj
                for id in dataObj.isDataBelongsToDefaultSesssion ? connectedPeersInDefaultSession() : connectedPeersInAllSession() {
                    if let deliveredNodes = dataObject.deliveredNodes,!deliveredNodes.contains(where: {$0 == id.hashValue})  {
                        dataObject.deliveredNodes?.append(id.hashValue)
                    }
                }
                // append self devicePeerID in DataObject's deliveredNodes
                if let selfPeerId = self.devicePeerID {
                    if let deliveredNodes = dataObject.deliveredNodes, !deliveredNodes.contains(where: {$0 == selfPeerId.hashValue}){
                        dataObject.deliveredNodes?.append(selfPeerId.hashValue)
                    }
                }
                // send data to all remaining nodes(Isolated nodes)
                if let item = try? JSONEncoder().encode(dataObject) {
                    for node in isolatedNodes {
                        if let session = dataObj.isDataBelongsToDefaultSesssion ? dicDefaultSessions[node] : dicSessions[node] {
                            try? session.send(item, toPeers: (session.connectedPeers), with: .reliable)
                        }
                    }
                }
            }
        }
    }
    
    /// get all connected node and compare with recevied node(deliveredNodes)
    /// if current node has more connection, get that node and send the data
    /// with same dataobject appending its all connected node (include self as well to avaoid cycle)
    func updateDataBaseToIsolatedNode(dataObj: [DataObject]) {
        guard dataObj.count > 0 else {
            return
        }
        var connnectedWithSelf = connectedPeersInAllSession().map({$0.hashValue})
        if let selfPeerId = self.devicePeerID {
            connnectedWithSelf.append(selfPeerId.hashValue)
        }
        
        if let deliveredNodes =  dataObj[0].deliveredNodes {
            var isolatedNodes:[Int] = []
            for node in connnectedWithSelf {
                if !deliveredNodes.contains(where: {$0 == node}) {
                    isolatedNodes.append(node)
                }
            }
            
            if isolatedNodes.count > 0 {
                var dataObject: [DataObject] = dataObj
                for id in connectedPeersInAllSession() {
                    if let deliveredNodes = dataObject[0].deliveredNodes,!deliveredNodes.contains(where: {$0 == id.hashValue})  {
                        dataObject[0].deliveredNodes?.append(id.hashValue)
                    }
                }
                
                if let selfPeerId = self.devicePeerID {
                    if let deliveredNodes = dataObject[0].deliveredNodes, !deliveredNodes.contains(where: {$0 == selfPeerId.hashValue}){
                        dataObject[0].deliveredNodes?.append(selfPeerId.hashValue)
                    }
                }
                
                if let item = try? JSONEncoder().encode(dataObject) {
                    for node in isolatedNodes {
                        if let session = dicSessions[node] {
                            try? session.send(item, toPeers: (session.connectedPeers), with: .reliable)
                        }
                    }
                }
            }
        }
        
    }
    
    /// Disconnect perticular session from custom session
    /// - Parameters:
    ///     - MCPeerID- Peer id to disconnect
    func disConnectDevice(peer:MCPeerID) {
        if let session = dicSessions[peer.hashValue] {
            session.disconnect()
        }
    }
    
    /// Disconnect perticular session from defaultSession session
    /// - Parameters:
    ///     - MCPeerID- Peer id to disconnect
    func disConnectDefaultDevice(peer:MCPeerID) {
        if let session = dicDefaultSessions[peer.hashValue] {
            session.disconnect()
        }
    }
    
    /// Method to BroadCast Alive signal in network for both Default session and Custom session.
    /// - Parameter type: None
    /// - Returns: None
    @objc func broadcastAliveMessageToNetwork() {
        if self.transmissionMode == .Wifi  {
            DispatchQueue.main.async { [weak self] in
                if let devicePeerID = self?.devicePeerID {
                    var dataObject = DataObject(data: Data(), sender: devicePeerID.displayName, linkSession:true)
                    // here change the dataOperation to Alive
                    dataObject.dataOperation = .alive
                    // Send the Alive signal to custom session
                    self?.sendData(data: dataObject)
                    
                    //Here for default session's Keep alive signal make the dataObject belongs to default session, use DataObject Property 'isDataBelongsToDefaultSesssion' True
                    dataObject.isDataBelongsToDefaultSesssion = true
                    
                    // Send the Alive signal to default session
                    self?.sendData(data: dataObject)
                }
            }
        }
    }
    
    /// Method to Check, device Alive or not, If its not alive make the changes(Connected / Offline ) in introsepection view, restart the session if device did not get any keep alive message from all connected devices.
    /// - Parameter type: None
    /// - Returns: None
    @objc func notifieIfDeviceIsNotAlive() {
        if isConnected {
            let devices = self.aliveNodes.filter({self.getNoOfSeconds(date: $0.timeStamp) > 15})
            var arrDeviceNotAlive:[DataObject] = []
            for device in devices {
                if devicesInNetwork.contains(where: {$0.key == device.sender}) {
                    arrDeviceNotAlive.append(device)
                }
            }
            if arrDeviceNotAlive.count > 0 {
                // Notifie these devices are no longer alive
                print("Device is no longer Alive: \(arrDeviceNotAlive)")
                for device in arrDeviceNotAlive {
                    // disconnect inactive sesssion
                    let notActive = self.connectedPeers.filter({$0.peerID.displayName == device.sender})
                    for peer in notActive {
                        self.disConnectDevice(peer: peer.peerID)
                    }
                    
                    // Update otherPeers
                    if self.otherPeers.filter({$0.peerID.displayName == device.sender}).count < 1 {
                        self.otherPeers.append(Peer(peerID: MCPeerID(displayName: device.sender), state: .notConnected, lastSeen: device.timeStamp))
                    }
                }
                
                //Here devicesInNetwork gives all devices in network(included self) that is why subtracted 1
                if arrDeviceNotAlive.count == devicesInNetwork.count-1 {
                    restartSession()
                }
            }
        } else {
            //Restart the session
            restartSession()
        }
        
    }
    
    ///  Restart the default session when there is no alive nodes.(Assuming device become zombie)
    @objc func notifieIfDeviceIsNotAliveForDefaultSession() {
        if isDefaultConnected {
            let devices = self.aliveNodesForDefaultSession.filter({self.getNoOfSeconds(date: $0.timeStamp) > 15})
            var arrDeviceNotAlive:[DataObject] = []
            for device in devices {
                if defaultConnectedPeers.contains(where: {$0.peerID.displayName == device.sender}) {
                    arrDeviceNotAlive.append(device)
                }
            }
            
            if arrDeviceNotAlive.count > 0 {
                print("default session Device is no longer Alive: \(arrDeviceNotAlive)")
            }
            /// Restart the default session if  number of not alive divices equal to currently default connected peers
            if arrDeviceNotAlive.count == defaultConnectedPeers.count {
                self.startDefaultSession(deviceName: self.deviceName)
            }
        } else {
            /// Restart the default session
            self.startDefaultSession(deviceName: self.deviceName )
        }
    }
    
    ///Restart the custom session
    func restartSession() {
        if let _ = self.sessionName {
            self.start(dataTransmissionMode: self.transmissionMode ?? .Wifi, sessionName: self.sessionName, deviceName: self.deviceName,retentionPeriod: self.timeToLive)
        }
    }
    /// Method to Get the no of seconds from current date
    /// - Parameter type: date
    /// - Returns: No of seconds
    func getNoOfSeconds(date: Date) -> Int {
        let calender = Calendar.current
        let components = calender.dateComponents([.second], from: date,to: Date())
        if let seconds = components.second {
            return seconds
        }
        return 0
    }
    
}
