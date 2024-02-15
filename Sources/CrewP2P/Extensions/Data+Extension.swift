//
//  Data+Extension.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 27/06/23.
//

import SwiftUI

extension Data {
    
    var utf8String: String? {
        return String(data: self, encoding: .utf8)
    }
    
    var uiImage: UIImage? { UIImage(data: self) }
    
    var doubleValue: Double? {
        var value: Double = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value
    }

    var prettyPrintedJSONString: String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: jsonObject,
                                                     options: [.prettyPrinted]),
              let prettyJSON = String(data: data, encoding: .utf8) else {
            return nil
        }
        return prettyJSON
    }
    
}
