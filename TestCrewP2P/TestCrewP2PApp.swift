//
//  TestCrewP2PApp.swift
//  TestCrewP2P
//
//  Created by Anurag bhatt on 14/02/24.
//

import SwiftUI
import CrewP2P
@main
struct TestCrewP2PApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification), perform: { output in
                    ConnectionManager.instance.stop()
                         })
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { output in
                    ConnectionManager.instance.initialization(deviceName: UIDevice.current.name, userDefaultsKeyForDefaultSession: "FlightObjects")
                    ConnectionManager.instance.deleteExpiredDataFromDatabase()
                }

        }
    }
}
