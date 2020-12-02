//
//  utils.swift
//  TXCli
//
//  Created by Stelios Petrakis on 1/12/20.
//  Copyright © 2020 Transifex. All rights reserved.
//

import Foundation

/// Simple utility class that is responsible for printing messages in the console if verbose logging is enabled.
public class TXLogger {
    /// Flag that controls whether the `log()` method will print the passed messages in the console
    /// (verbose: true) or not (verbose: false).
    public static var verbose: Bool = false
    
    /// Prints the passed message to the console, if verbose logging is activated.
    /// - Parameter message: The message to be logged
    public static func log(_ message: String) {
        guard verbose else {
            return
        }
        
        print(message)
    }
}
