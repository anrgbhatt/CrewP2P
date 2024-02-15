//
//  DatabaseViewer.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 27/06/23.
//

import SwiftUI
import CoreData

struct EntityInfo {
    let name: String
    let recordCount: Int
}

public struct DatabaseViewer: View {
    
    @StateObject var viewModel = DatabaseViewerViewModel.instance
    @State private var selected: DataObject.ID?
    @State private var showDetailView = false
    @State private var showUserInfo = true
    @State private var showPayloadType = true
    @State private var showType = true
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
    
    @State private var sortOrder = [KeyPathComparator(\DataObject.timeStamp, order: .reverse)]

    public init() {}
    
    public var body: some View {
        
        NavigationView {
            
            VStack(alignment: .leading) {
                
                ForEach(DatabaseManager.sharedInstance.fetchEntities(), id: \.name) { entity in
                    HStack {
                        Text(entity.name)
                        Spacer()
                        Text("\(entity.recordCount) records")
                        Menu(content: {
                            Toggle("Sender/Recipients", isOn: $showUserInfo).padding()
                            Toggle("Payload Type", isOn: $showPayloadType).padding()
                            Toggle("Type", isOn: $showType).padding()
                        }, label: {
                            Label("", systemImage: "gearshape")
                        })
                        .padding(.leading)
                    }
                    .padding(.horizontal, 20)
                }
                
                Divider()
                
                if #available(iOS 16.0, *) {
                    
                    Table(self.viewModel.dataObjects, selection: $selected,
                          sortOrder: $sortOrder) {
                        
                        TableColumn("SessionID") { object in
                            VStack(alignment: .leading) {
                                Text(object.sessionID ?? "nil")
                                if isCompact {
                                    Text(object.timeStamp.formatted())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        TableColumn("Type") { object in
                            Text(object.dataOperation.name)
                        }
                        .width(min: showType ? 50 : .zero, max: showType ? 200 : .zero)
                        
                        TableColumn("Creation Date", value: \.timeStamp) {
                            Text($0.timeStamp.formatted())
                        }
                        
                        TableColumn("Payload Type") { object in
                            Text(object.payloadType?.rawValue ?? "nil")
                        }
                        .width(min: showPayloadType ? 50 : .zero, max: showPayloadType ? 200 : .zero)

                        
                        TableColumn("Sender", value: \.sender)
                            .width(min: showUserInfo ? 50 : .zero, max: showUserInfo ? 200 : .zero)

                        TableColumn("Recipients") { object in
                                Text(object.intendedRecepient ?? "nil")
                            }
                            .width(min: showUserInfo ? 50 : .zero, max: showUserInfo ? 200 : .zero)
                    }
                    .onChange(of: selected) { newValue in
                        if newValue != nil {
                            showDetailView = true
                        }
                    }
                    .onChange(of: sortOrder) {
                        self.viewModel.dataObjects.sort(using: $0)
                    }
                    
                    .sheet(isPresented: $showDetailView, onDismiss: {
                        selected = nil
                    }, content: {
                        if let value = selected, let dataObj = viewModel.getDataObjectFor(value) {
                            DescriptionView(object: dataObj)
                        }
                    })
                }
            }
            .padding(.top, 16)
            .modifier(NavigationBarModifier(title: "App Data", showDoneButton: true))
        }
        .onAppear {
            viewModel.setPublisher()
        }
    }
}

public struct DescriptionView: View {
    
    var object: DataObject
    
    public var body: some View {
        
        NavigationView {
            
            Form {
                
                Section {
                    HStack {
                        Text("UUID")
                        Spacer()
                        Text(object.id.uuidString)
                    }
                    
                    if let sessionID = object.sessionID {
                        HStack {
                            Text("SessionID")
                            Spacer()
                            Text(sessionID)
                        }
                    }
                    
                    HStack {
                        Text("Creation Date")
                        Spacer()
                        Text(object.timeStamp.formatted())
                    }
                    
                    HStack {
                        Text("Sender")
                        Spacer()
                        Text(object.sender)
                    }
                    
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(object.dataOperation.name)
                    }
                    
                    if let payloadType = object.payloadType {
                        HStack {
                            Text("Payload Type")
                            Spacer()
                            Text(payloadType.rawValue)
                        }
                    }
                    
                    if let recepients = object.intendedRecepient {
                        HStack {
                            Text("Recepients")
                            Spacer()
                            Text(recepients)
                        }
                    }
                }
                
                Section {
                    if let type = object.payloadType {
                        if type == .String {
                            Text(object.data.utf8String ?? "")
                        } else if type == .Image {
                            if let image = object.data.uiImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            }
                        } else if type == .JSON {
                            Text(object.data.prettyPrintedJSONString ?? "")
                        } else if type == .Number {
                            if let value = object.data.doubleValue {
                                Text("\(value)")
                            }
                        } else {
                            Text("<Unsupported type>")
                        }
                    } else {
                        Text(object.data.utf8String ?? "<Unsupported type>")
                    }
                } header: {
                    Text("Content")
                }
            }
            .modifier(NavigationBarModifier(title: "Details", showDoneButton: false))
        }
        .navigationViewStyle(.stack)
    }
    
}

struct NavigationBarModifier: ViewModifier {
    
    let title: String
    let showDoneButton: Bool
    @Environment(\.dismiss) var dismiss

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if showDoneButton {
                            Button("Done") { dismiss() }
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(
                    Color.blue,
                    for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if showDoneButton {
                            Button("Done") { dismiss() }
                                .foregroundStyle(Color.white)
                        }
                    }
                }
        }
    }
}
