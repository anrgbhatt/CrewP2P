//
//  DatabaseViewerViewModel.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 27/06/23.
//

import Foundation

class DatabaseViewerViewModel: ObservableObject {
    
    static let instance = DatabaseViewerViewModel()
    @Published var dataObjects = [DataObject]()
    
    func setPublisher() {
        ConnectionManager.instance.fetchData(since: nil, sortOrder: .reverse) { objects in
            DispatchQueue.main.async {
                self.dataObjects = objects
            }
        }
    }
    
    func getDataObjectFor(_ id: UUID) -> DataObject? {
        return DatabaseManager.sharedInstance.fetchDataFor(id, intendedRecepient: nil)
    }
    
}
