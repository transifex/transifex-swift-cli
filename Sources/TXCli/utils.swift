//
//  utils.swift
//  TXCli
//
//  Created by Stelios Petrakis on 1/12/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import Foundation

/// Prints the passed message to the console, if verbose logging is activated.
/// - Parameter message: The message to be logged
func verboseLog(_ message: String) {
    guard TXCli.verbose else {
        return
    }
    
    print(message)
}
