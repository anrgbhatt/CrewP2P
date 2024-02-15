//
//  MessageView.swift
//  Example
//
//  Created by Lufthansa on 27/02/23.
//

import SwiftUI
import CrewP2P

enum RowType {
    case Left
    case Right
}

struct MessageView: View {
    @StateObject var connectionVM: ConnectionViewModel

    var body: some View {
            ScrollView {
                ScrollViewReader { proxy in

                ForEach(connectionVM.dataSource) { data in
                    if connectionVM.isCurrentDevice(for: data) {
                        rowView(rowType:.Right, message: data.messageString(), image: data.imageObj(), sender: data.sender, time: data.timeStamp)
                            .id(data.id)
                            .padding(.bottom, 10)
                    } else {
                        rowView(rowType:.Left, message: data.messageString(), image: data.imageObj(), sender: data.sender, time: data.timeStamp)
                            .id(data.id)
                            .padding(.bottom, 10)
                    }
                }
                .onChange(of: connectionVM.dataSource) { newValue in
                    withAnimation {
                        proxy.scrollTo(newValue.last?.id)
                    }
                }
                .alert(connectionVM.dataObjectString, isPresented: $connectionVM.showAlertForDefaultSession) {
                    Button("OK", role: .cancel) {
                        connectionVM.showAlertForDefaultSession = false
                    }
                }
            }
            .padding()
        }

    }
    
    func rowView(rowType: RowType,  message: String?, image: UIImage?, sender: String, time: Date) -> some View {
        HStack {
            if rowType == .Right {
                Spacer()
            }
            VStack(alignment: rowType == .Right ? .trailing : .leading, spacing: 1)  {
                if let message = message {
                    Text(message)
                        .padding()
                        .background(connectionVM.getColor(for: sender.hashValue, rowType: rowType))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16.0, style: .continuous))
                }
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .background(connectionVM.getColor(for: sender.hashValue, rowType: rowType))
                        .clipShape(RoundedRectangle(cornerRadius: 16.0, style: .continuous))
                        .frame(width: 200, height: 150)
                        .padding()
                }

                HStack(spacing: 3) {
                    Text(sender)
                        .font(.caption2)
                    Text(time, style: .time)
                        .font(.caption2)
                }
                .padding(.horizontal)
            }
            if rowType == .Left {
                Spacer()
            }
        }
    }

}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ConnectionViewModel()
        MessageView(connectionVM: viewModel)
    }
}
