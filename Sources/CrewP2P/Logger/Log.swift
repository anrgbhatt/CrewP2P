//
//  Log.swift
//  CrewP2PFramework
//
//  Created by Lufthansa on 15/03/23.
//

import Foundation

/** Prints only if in debug mode */
func printDebug(_ string: String) {
    if ConnectionManager.instance.debugMode {
        print("***************************")
        print(" ")
        print(string)
        print(" ")
    }
}
