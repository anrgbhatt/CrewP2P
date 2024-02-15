//
//  ConnectionProtocol.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 09/02/23.
//

import Foundation

protocol Connection {
    
    /// initialize  Coredata , Introspection and other dependent objects
    ///- Parameters:
    /// - device Name:  to identifie the peer.
    /// - userDefaultsKeyForDefaultSession: userDefaults key against the saved default session data.
    ///  The persistence of default session's(Universal Session) data is not handled by framework,If Application(Client App) required to persist the Default Session's data Application can use the userDefaults as storage.
    func initialization(deviceName: String,userDefaultsKeyForDefaultSession: String?)
    
    /// starts the MultiPeer service with a serviceType and the default deviceName
    /// - Parameters:
    ///     - sessionName: Provide a string to uniquely identify a session. Use same sessionName for all devices that should be part of that session
    ///     - deviceName: Provide a string to uniquely identify a device in a session
    ///     - retentionPeriod: Time in days until the data lives in the database. Default value is 15 days
    func start(dataTransmissionMode: DataTransmissionMode,sessionName: String, deviceName: String, retentionPeriod: Int?)
    
    /// stops the connection
    func stop()
    
    /// Sends an object to all peers in network.
    /// - Parameters:
    ///     - object: Object (DataObject) to send to all connected peers.
    func sendData(data: DataObject)
    
    /// Fetch the data/updates after a particular date according to specified sort order
    /// - Parameters:
    ///     - for: session identifier for fetching data objects for a particular session. If not provided all data will be fetched
    ///     - since: the date after which you want to recieve the data. If not provided all data will be fetched
    ///     - sortOrder: the sort ordering for data objects
    func fetchData(for: String?, since: Date?, sortOrder: SortOrder, completion: @escaping (([DataObject]) -> ()))
    
    /// Fetch the data/updates after a particular date from peers
    /// - Parameters:
    ///     - since: the date after which you want to recieve the data. If not provided all data will be fetched
    func syncDatabase(since: Date?)

}


public protocol ConnectionDelegate: AnyObject {
 
    /// didReceiveData: delegate runs on receiving data from another peer
    func peerDidReceiveData(data: DataObject)

    /// connectedDevicesChanged: delegate runs on connection/disconnection event in session
    func peerListChanged(devices: [Peer])
    
    /// databaseSynced: delegate is called when the database is updated on account og: func syncDatabase(since: Date?)
    func databaseSynced()
    
    ///  didReceiveDeviceListInNetwork: delegate runs on connection/disconnection event in session, which provide the list of devices in network graph.
    func didReceiveDeviceListInNetwork(devices:[String: [String]])
    
    // didReceiveDefaultSessionData: When default session data exchange this delegate called with Data object.
    func didReceiveDefaultSessionData(data: DataObject)
}
