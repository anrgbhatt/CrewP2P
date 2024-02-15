//
//  DBManager.swift
//
//  Created by Lufthansa on 01/03/23.
//

import Foundation
import CoreData

open class DatabaseManager{
    
    /// Implements the Singleton Design Pattern
    static let sharedInstance = DatabaseManager()
    
    let myModel: NSManagedObjectModel = Stack.defaultModel
    let myStoreType = NSSQLiteStoreType
    let myStoreURL = Stack.defaultURL
    let myOptions = [NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true]
    
    /// Struct that holds different instances of managed object context.
    public struct Context {
        /// Managed object context for current thread.
        public static var `default`: NSManagedObjectContext { return Stack.shared.defaultContext }
        
        /// Managed object context for main thread.
        public static var main: NSManagedObjectContext { return Stack.shared.mainContext }
        
        /// Managed object context for background thread.
        public static var background: NSManagedObjectContext { return Stack.shared.backgroundContext }
    }
    
    /// Persistent Store Coordinator for current stack.
    open class var storeCoordinator: NSPersistentStoreCoordinator? { return Stack.shared.coordinator }
    
    // MARK: - Core Data stack
    func loadCoreDataStackOnce() {
        do {
            try Stack.shared.loadCoreDataStack(managedObjectModel: myModel, storeType: myStoreType, configuration: nil, storeURL: myStoreURL, options: myOptions)
        } catch {
            printDebug(error.localizedDescription)
        }
        
    }
    
    // MARK: - Writing to DB
    func save(moc: NSManagedObjectContext? = nil) {
        var context = DatabaseManager.Context.main
        if let moc = moc {
            context = moc
        }
        Stack.shared.save(context: context)
    }
    
    func saveDataObject(obj: DataObject) {
        let context = DatabaseManager.Context.main
        let managedObject = DataEntity.firstOrCreate(with: "id", value: obj.id, in: context)
        managedObject.sender = obj.sender
        managedObject.sessionID = obj.sessionID
        managedObject.data = obj.data
        managedObject.creationDate = obj.timeStamp
        managedObject.dataOperation = String(obj.dataOperation.rawValue)
        managedObject.payloadType = obj.payloadType?.rawValue
        managedObject.linkSession = obj.linkSession
        managedObject.timeToLive = Int16(obj.expiredTime)
        save()
    }
    
    func saveDataObjects(objs: [DataObject]) async {
        await saveObjectsToDB(objs:objs)
    }
    
    func saveObjectsToDB(objs: [DataObject]) async {
        let context = DatabaseManager.Context.background
        for obj in objs {
            let managedObject = DataEntity.firstOrCreate(with: "id", value: obj.id, in: context)
            managedObject.sender = obj.sender
            managedObject.sessionID = obj.sessionID
            managedObject.data = obj.data
            managedObject.creationDate = obj.timeStamp
            managedObject.dataOperation = String(obj.dataOperation.rawValue)
            managedObject.payloadType = obj.payloadType?.rawValue
            managedObject.linkSession = obj.linkSession
            managedObject.timeToLive = Int16(obj.expiredTime)
        }
        save(moc: context)
    }
    
    func fetchData(for sessionID: String? = nil,
                   from date: Date?,
                   intendedRecepient: String?,sortOrder: SortOrder = .forward,completion: @escaping (([DataObject]) -> ())) {
        
        let context = DatabaseManager.Context.background
        var resultTemp: [DataEntity]?
        var datePredicate = NSPredicate()
        var sessionPredicate = NSPredicate()

        if let date = date {
            datePredicate = NSPredicate(format: "creationDate >= %@", date as CVarArg)
        }
        
        if let id = sessionID {
            sessionPredicate = NSPredicate(format: "sessionID == %@ OR sessionID == nil", id as CVarArg)
        }
        
        let sortDescriptor = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .forward)]
        
        if date != nil && sessionID != nil {
            DataEntity.allInBackground(with: NSCompoundPredicate(
                andPredicateWithSubpredicates: [datePredicate, sessionPredicate]),orderedBy: sortDescriptor,in: context) { manageobject in
                    
                    resultTemp = manageobject as? [DataEntity]
                    if let resultTemp = resultTemp {
                            let result = self.convertDataEntityToDataObjects(dataEntity: resultTemp, intendedRecepient: intendedRecepient)
                            completion(result)
                    }
                }
        } else if sessionID != nil {
            DataEntity.allInBackground(with: sessionPredicate,orderedBy: sortDescriptor,in: context) { manageobject in
                resultTemp = manageobject as? [DataEntity]
                if let resultTemp = resultTemp {
                        let result = self.convertDataEntityToDataObjects(dataEntity: resultTemp, intendedRecepient: intendedRecepient)
                        completion(result)
                }
                
            }
        } else if date != nil {
            DataEntity.allInBackground(with: datePredicate,orderedBy: sortDescriptor,in: context) { manageobject in
                resultTemp = manageobject as? [DataEntity]
                if let resultTemp = resultTemp {
                        let result = self.convertDataEntityToDataObjects(dataEntity: resultTemp, intendedRecepient: intendedRecepient)
                        completion(result)
                }
            }
        } else {
            DataEntity.allInBackground(orderedBy: sortDescriptor,in: context) { manageobject in
                resultTemp = manageobject as? [DataEntity]
                
                if let resultTemp = resultTemp {
                        let result = self.convertDataEntityToDataObjects(dataEntity: resultTemp, intendedRecepient: intendedRecepient)
                        completion(result)
                }
            }
        }
    }
    
    func convertDataEntityToDataObjects(dataEntity: [DataEntity], intendedRecepient: String?) -> [DataObject] {
        var result = [DataObject]()
        for obj in dataEntity {
            result.append(self.convert(data: obj, intendedRecepient: intendedRecepient))
        }
        return result
    }
 
    func fetchDataFor(_ uuid: UUID?, intendedRecepient: String?) -> DataObject? {
        let context = DatabaseManager.Context.main
        if let id = uuid {
            let resultTemp = DataEntity.all(with: NSPredicate(format: "id == %@", id as CVarArg), in: context) as? [DataEntity]
            
            if let result = resultTemp?.first {
                return convert(data: result, intendedRecepient: intendedRecepient)
            }
        }
        
        return nil
    }
    
    func fetchEntities() -> [EntityInfo] {
        loadCoreDataStackOnce()
        let entityNames = myModel.entities.compactMap { $0.name }
        return entityNames.map {EntityInfo(name: $0, recordCount: fetchRecordCount($0))}
    }
    
    func fetchRecordCount(_ entityName: String) -> Int {
        
        var count = 0
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let context = DatabaseManager.Context.main
        do {
            count = try context.count(for: fetchRequest)
        } catch {
            printDebug("\(error)")
        }
        return count
    }
    
    func deleteData(before date: Date, for sessionID: String) {
        let context = DatabaseManager.Context.main
        DataEntity.deleteAll(with: NSPredicate(format: "creationDate < %@ AND sessionID == %@", date as CVarArg , sessionID as CVarArg), from: context)
        save()
    }
    
    func deleteExpiredData() {
        let context = DatabaseManager.Context.background
         DatabaseManager.sharedInstance.fetchData(from: nil, intendedRecepient: nil) { data in
             for record in data {
                 if let sessionID = record.sessionID {
                     let allowedDataDate = Date().addingTimeInterval(-Double(record.expiredTime*24*60*60))
                     DataEntity.deleteAll(with: NSPredicate(format: "creationDate < %@ AND sessionID == %@", allowedDataDate as CVarArg , sessionID as CVarArg), from: context)
                     self.save(moc: context)
                 }
             }
        }
    }

    func convert(data: DataEntity, intendedRecepient: String?) -> DataObject {
        var dataObj = DataObject(data: data.data ?? Data(), sender: data.sender ?? "", linkSession: data.linkSession)
        dataObj.id = data.id ?? UUID()
        dataObj.sessionID = data.sessionID
        dataObj.timeStamp = data.creationDate ?? Date()
        dataObj.dataOperation = DataOperation(rawValue: Int32(data.dataOperation ?? "0") ?? 0) ?? .Add
        dataObj.payloadType = PayloadType(rawValue: data.payloadType ?? "")
        dataObj.expiredTime = Int(data.timeToLive)
        if let intendedRecepient = intendedRecepient {
            dataObj.intendedRecepient = intendedRecepient
            dataObj.dataOperation = .FetchResponse
        }
        return dataObj
    }
}
