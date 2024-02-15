//
//  DataObject.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 01/03/23.
//

import Foundation

public enum DataOperation: Int32 {
    /// Used to send the data to peers using delegate 'peerDidReceiveData'
    case Add = 1
    
    case Update = 2
    
    /// used delete operation on received DataObjects/Storage using timeStamp
    case Delete = 3
    
    /// used to fetch the records from storage.
    case Fetch = 4
    
    case FetchResponse = 5
    
    /// Used to get the devices in network
    case Network = 6
    
    /// when ever peer received 'Network' DataOperation peers sends its presence in network
    /// using 'Broadcast' DataOperation
    case Broadcast = 7
    
    /// used for sending keep alive signal every n seconds.
    case alive = 8
    
    var name: String {
        get { return String(describing: self) }
    }
}

public enum PayloadType: String {
    case String
    case Number
    case JSON
    case Image
    case blob
}

public struct DataObject: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var data: Data
    public var timeStamp = Date()
    public var dataOperation: DataOperation = DataOperation.Add
    public var sender: String
    public var linkSession: Bool
    public var intendedRecepient: String?
    public var payloadType: PayloadType?
    var sessionID: String?
    /**
        Array of all connected Peers from all Default/Custom session.
     */
    var deliveredNodes:[Int]?
    var deliveredNodesBLE: [String]?
    var recepients: [String]?
    public var expiredTime: Int = ConnectionManager.instance.timeToLive
    public var isDataBelongsToDefaultSesssion = false
    public static var supportsSecureCoding = true
    
    public init(data: Data, sender: String, linkSession: Bool, payloadType: PayloadType? = nil, deliveredNodes:[Int]? = nil,deliveredNodesBLE:[String]? = nil, recepients: [String]? = nil, isDataBelongsToDefaultSesssion: Bool = false) {
        self.data = data
        self.sender = sender
        self.linkSession = linkSession
        self.timeStamp = Date()
        self.payloadType = payloadType
        self.id = UUID()
        self.sessionID = linkSession ? ConnectionManager.instance.sessionName : nil
        self.deliveredNodes = deliveredNodes
        self.deliveredNodesBLE = deliveredNodesBLE
        self.recepients = recepients
        self.isDataBelongsToDefaultSesssion = isDataBelongsToDefaultSesssion
    }
    
    public enum CodingKeys: CodingKey {
        case data, timeStamp, dataOperation, sender, id, payloadType, linkSession, sessionID, deliveredNodes,deliveredNodesBLE, recepients,expiredTime,isDataBelongsToDefaultSesssion
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let data = try container.decodeIfPresent(Data.self, forKey: .data) {
            self.data = data
        } else {
            self.data = Data()
        }
        if let date = try container.decodeIfPresent(Date.self, forKey: .timeStamp) {
            self.timeStamp = date
        }
        if let type = try container.decodeIfPresent(Int32.self, forKey: .dataOperation) {
            self.dataOperation = DataOperation.init(rawValue: type) ?? .Add
        }
        if let sender = try container.decodeIfPresent(String.self, forKey: .sender) {
            self.sender = sender
        } else {
            self.sender = ""
        }
        if let id = try container.decodeIfPresent(UUID.self, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID()
        }
        if let linkSession = try container.decodeIfPresent(Bool.self, forKey: .linkSession) {
            self.linkSession = linkSession
        } else {
            self.linkSession = false
        }
        self.sessionID = try? container.decodeIfPresent(String.self, forKey: .sessionID)

        if let payloadType = try container.decodeIfPresent(String.self, forKey: .payloadType) {
            self.payloadType = PayloadType(rawValue: payloadType)
        }
        self.deliveredNodes = try? container.decodeIfPresent([Int].self, forKey: .deliveredNodes)
        self.deliveredNodesBLE = try? container.decodeIfPresent([String].self, forKey: .deliveredNodesBLE)
        self.recepients = try? container.decodeIfPresent([String].self, forKey: .recepients)
        if let time = try container.decodeIfPresent(Int.self, forKey: .expiredTime) {
            self.expiredTime = time
        } else {
            self.expiredTime = ConnectionManager.instance.timeToLive
        }
        if let forDefaultSession = try container.decodeIfPresent(Bool.self, forKey: .isDataBelongsToDefaultSesssion) {
            self.isDataBelongsToDefaultSesssion = forDefaultSession
        } else {
            self.isDataBelongsToDefaultSesssion = false
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(timeStamp, forKey: .timeStamp)
        try container.encodeIfPresent(dataOperation.rawValue, forKey: .dataOperation)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(linkSession, forKey: .linkSession)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(payloadType?.rawValue, forKey: .payloadType)
        try container.encodeIfPresent(deliveredNodes, forKey: .deliveredNodes)
        try container.encodeIfPresent(deliveredNodesBLE, forKey: .deliveredNodesBLE)
        try container.encodeIfPresent(recepients, forKey: .recepients)
        try container.encodeIfPresent(expiredTime, forKey: .expiredTime)
        try container.encodeIfPresent(isDataBelongsToDefaultSesssion, forKey: .isDataBelongsToDefaultSesssion)
    }
    
    public static func == (lhs: DataObject, rhs: DataObject) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
