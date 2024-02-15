//
//  ConnectionViewModel.swift
//  Example
//
//  Created by Lufthansa on 27/02/23.
//

import Foundation
import CrewP2P
import UIKit
import MultipeerConnectivity
import SwiftUI

class ConnectionViewModel: ObservableObject  {
    @Published var message: String = ""
    @Published var deviceList = [Peer]()
    @Published var dataSource = [DataObject]()
    @Published var sessionName: String = "" 
    @Published var deviceName: String = ""
    @Published var autoSendButtonText: String = ""
    @Published var showAlertForDefaultSession = false
    @Published var dataObjectString: String = ""
    var timer: Timer?
    var isRunning = false
    var colors = [Int: Color]()
    var dataTransmissionMode: DataTransmissionMode = .Wifi
    var dataTransmissionModes = ["Wifi", "Bluetooth"]
    @Published var selectedOption = 0 {
        didSet {
            if selectedOption == 0 {
                dataTransmissionMode = .Wifi
            } else {
                dataTransmissionMode = .Bluetooth
            }
        }
    }
    
    init() {
        self.deviceName = UIDevice.current.name
        self.autoSendButtonText = "Auto Send Start"
        ConnectionManager.instance.delegate = self
        ConnectionManager.instance.debugMode = true
    }
    
    func startSession() {
        ConnectionManager.instance.start(dataTransmissionMode: dataTransmissionMode, sessionName: sessionName, deviceName: deviceName,retentionPeriod: 15)
        ConnectionManager.instance.delegate = self
        ConnectionManager.instance.debugMode = true
        ConnectionManager.instance.fetchData(since: nil) { [weak self] result in
            result.forEach { obj in
                if !(self?.dataSource.contains(where: {$0.id == obj.id}) ?? false) {
                    DispatchQueue.main.async {
                        self?.dataSource.append(obj)
                    }
                }
            }
        }
        ConnectionManager.instance.syncDatabase(since: nil)
    }
    
    func stopSession() {
        ConnectionManager.instance.stop()
        self.sessionName = ""
    }

    func sendMessage(message: String) {
        
        if let data = message.data(using: .utf8), data.count > 0 {
            let dataObject = DataObject(data: data, sender: getSelf(), linkSession: true, payloadType: PayloadType.String,isDataBelongsToDefaultSesssion: message == "Default" ? true : false)
            ConnectionManager.instance.sendData(data: dataObject)
            if !dataObject.isDataBelongsToDefaultSesssion {
                dataSource.append(dataObject)
            }
            self.message = ""
        }

    }
    
    func sendImage(image: UIImage) {
        if let image = image.jpegData(compressionQuality: 0.2), image.count > 0 {
            let dataObject = DataObject(data: image, sender: getSelf(), linkSession: true, payloadType: PayloadType.Image)
            ConnectionManager.instance.sendData(data: dataObject)
            dataSource.append(dataObject)
            self.message = ""
        }
    }
    
    func sendJSON() {
        guard let filePath = Bundle.main.url(forResource: "A319", withExtension: "json") else {
            debugPrint("File not found.")
            return
        }

        do {
            let jsonData = try Data(contentsOf: filePath)
            let dataObject = DataObject(data: jsonData, sender: getSelf(), linkSession: true, payloadType: PayloadType.JSON)
            ConnectionManager.instance.sendData(data: dataObject)
            dataSource.append(dataObject)
            self.message = ""
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func getSelf() -> String {
        return UIDevice.current.name
    }
    
    func isCurrentDevice(for data: DataObject) -> Bool {
        if data.sender == getSelf() { return true}
        return false
    }
    
    func getAllMessages() -> [DataObject] {
        return dataSource
    }
}


extension ConnectionViewModel: ConnectionDelegate {
    func didReceiveDefaultSessionData(data: DataObject) {
        print("Got Default Data:\(data)")
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(data)
        let json = String(data: jsonData, encoding: String.Encoding.utf8)
        dataObjectString = json!
      //  showAlertForDefaultSession = true
    }
    
    func didReceiveDeviceListInNetwork(devices: [String : [String]]) {
        print("Devices in Network:\(devices.count)\n------------------------")
            for dic in devices {
                print("\(dic.key)")
            }
            print("------------------------")
            for dic in devices {
                print("Device: \(dic.key) Directly Connected With:  --> \(dic.value)")
            }
    }
    
    func databaseSynced() {
        ConnectionManager.instance.fetchData(since: nil) { [weak self] result in
            result.forEach { obj in
                if !(self?.dataSource.contains(where: {$0.id == obj.id}) ?? false) {
                    DispatchQueue.main.async {
                        self?.dataSource.removeAll()
                        self?.dataSource.append(obj)
                    }
                }
            }
        }
    }

    func peerDidReceiveData(data: DataObject) {
        if !dataSource.contains(where: {$0.id == data.id}) {
            dataSource.append(data)
        }
    }

    func peerListChanged(devices: [Peer]) {
        if deviceList.count == 0 {
            ConnectionManager.instance.syncDatabase(since: nil)
        }
        deviceList = devices
    }
}

extension ConnectionViewModel {
    
    func getColor(for key: Int, rowType: RowType) -> Color {
        if rowType == .Right {
            return .blue
        }
        if colors[key] == nil {
            let color = generateRandomPastelColor(withMixedColor: .green)
            self.colors[key] = Color(color)
            return Color(color)

        } else {
            return colors[key] ?? .red
        }
    }
    
    func generateRandomPastelColor(withMixedColor mixColor: UIColor?) -> UIColor {
        // Randomly generate number in closure
        let randomColorGenerator = { ()-> CGFloat in
            CGFloat(arc4random() % 256 ) / 256
        }
            
        var red: CGFloat = randomColorGenerator()
        var green: CGFloat = randomColorGenerator()
        var blue: CGFloat = randomColorGenerator()
            
        // Mix the color
        if let mixColor = mixColor {
            var mixRed: CGFloat = 0, mixGreen: CGFloat = 0, mixBlue: CGFloat = 0;
            mixColor.getRed(&mixRed, green: &mixGreen, blue: &mixBlue, alpha: nil)
            
            red = (red + mixRed) / 3;
            green = (green + mixGreen) / 3;
            blue = (blue + mixBlue) / 3;
        }
            
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension DataObject {
    func messageString() -> String? {
        do {
            let string = String(data: self.data, encoding: .utf8)
            return string
        }
    }
    
    func imageObj() -> UIImage? {
        
        do {
            let imageObj = UIImage(data: self.data)
            return imageObj
        }
    }
}
extension ConnectionViewModel {

    func autoSendButtonTapped() {
        if autoSendButtonText == "Auto Send Start" {
           autoSendButtonText = "Auto Send Stop"
           start()
        } else {
            stop()
            autoSendButtonText = "Auto Send Start"
        }
    }
    
    func start() {
        if !isRunning {
            timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(sendMsg), userInfo: nil, repeats: true)
            isRunning = true
        }
    }

    func stop() {
        if isRunning {
            timer?.invalidate()
            timer = nil
            isRunning = false
        }
    }

    @objc func sendMsg() {
        let msg = sessionName + "-" + deviceName + "-" + getDate()
        if let data = msg.data(using: .utf8), data.count > 0 {
            let dataObject = DataObject(data: data, sender: getSelf(), linkSession: true, payloadType: PayloadType.String)
            ConnectionManager.instance.sendData(data: dataObject)
            dataSource.append(dataObject)
            self.message = ""
        }

    }
    func clearDataSource() {
        self.dataSource.removeAll()
    }
    
    func getDate() -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return dateFormatter.string(from: date)
    }
}
