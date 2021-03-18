//
//  File.swift
//  
//
//  Created by Bryce Buchanan on 1/20/21.
//

import Foundation

internal struct ProgrammerError: Error, CustomStringConvertible {
    init(description: String) { self.description = description }
    let description: String
}
