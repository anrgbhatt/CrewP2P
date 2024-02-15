//
//  DateFormatter+Extension.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 27/06/23.
//

import Foundation

extension DateFormatter {
    
    static var current: DateFormatter {
        let dict = Thread.current.threadDictionary
        let key = "CachedDateformatter"
        
        if let dformatter = dict[key] as? DateFormatter {
            return dformatter
            
        }
        let dformatter = DateFormatter()
        dformatter.timeZone = TimeZone(abbreviation: "UTC")
        dformatter.locale = Locale(identifier: "en_US_POSIX")
        Thread.current.threadDictionary[key] = dformatter
        return dformatter
    }
}
