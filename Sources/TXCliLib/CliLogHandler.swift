//
//  CliLogHandler.swift
//  TXCli
//
//  Created by Stelios Petrakis on 20/1/21.
//  Copyright © 2021 Transifex. All rights reserved.
//

import Foundation
import Transifex

public class CliLogHandler: TXLogHandler {
    /// Flag that controls whether the `log()` method will print the verbose messages in the console
    /// (verbose: true) or not (verbose: false).
    public var verbose: Bool = false
    
    public init() { }
    
    public func info(_ message: String) {
        log(message)
    }
    
    public func warning(_ message: String) {
        warning(message, trailingLine: false)
    }

    public func warning(_ message: String, trailingLine: Bool = false) {
        if trailingLine {
            log("""
[prompt]\(message)[end]

""")
        }
        else {
            log("[prompt]\(message)[end]")
        }
    }
    
    public func error(_ message: String) {
        error(message, trailingLine: false)
    }

    public func error(_ message: String, trailingLine: Bool = false) {
        if trailingLine {
            log("""
[error]\(message)[end]

""")
        }
        else {
            log("[error]\(message)[end]")
        }
    }
    
    public func verbose(_ message: String) {
        guard verbose else {
            return
        }
        
        log(message)
    }
    
    private func log(_ message: String) {
        print(CliSyntaxColor.format(message))
    }
}

/// Extension responsible for printing the debug description of a TXSourceString to the console with proper
/// styling.
extension TXSourceString {
    /// Stylize the debug description of the TXSourceString for the CLI needs.
    ///
    /// We are aware of the 'method in category overrides method from class' warning(s) produced here.
    public override var debugDescription: String {
        var description = "\n"
        
        description += "[yel]\"\(key)\"[end]: "
        description += "[green]\"\(sourceString)\"[end]\n"

        if let context = context {
            description += "[high]context:[end] \(context.debugDescription)\n"
        }

        if let developerComment = developerComment {
            description += "[high]comment:[end] \(developerComment)\n"
        }

        if characterLimit > 0 {
            description += "[high]character limit:[end] \(characterLimit)\n"
        }

        if let tags = tags, tags.count > 0 {
            description += "[high]tags:[end] \(tags.joined(separator: ", "))\n"
        }
        
        description += "   [high]occurrences:[end] [file]\(occurrences.joined(separator: ", "))[end]\n"

        return description
    }
}

/// Convenience class for adding color to console output.
class CliSyntaxColor {
    static let WHITE_BOLD = "\u{001B}[0;1m"
    static let RED = "\u{001B}[0;0;31m"
    static let GREEN = "\u{001B}[0;32m"
    static let YELLOW = "\u{001B}[0;33m"
    static let BLUE = "\u{001B}[0;34m"
    static let MAGENTA = "\u{001B}[0;35m"
    static let CYAN = "\u{001B}[0;36m"
    static let PINK = "\u{001B}[0;91m"
    static let GREEN_BRIGHT = "\u{001B}[0;92m"
    static let YELLOW_BRIGHT = "\u{001B}[0;93m"
    static let BLUE_BRIGHT = "\u{001B}[0;94m"
    static let MAGENTA_BRIGHT = "\u{001B}[0;95m"
    static let CYAN_BRIGHT = "\u{001B}[0;96m"
    static let END = "\u{001B}[0;0m"

    /// Format given string, adding color support.
    ///
    /// - Parameter string: The provided string
    /// - Returns: Color supported string
    static func format(_ string: String) -> String {
        return
            string.replacingOccurrences(of: "[high]", with: CliSyntaxColor.WHITE_BOLD)
            .replacingOccurrences(of: "[warn]", with: CliSyntaxColor.PINK)
            .replacingOccurrences(of: "[file]", with: CliSyntaxColor.CYAN)
            .replacingOccurrences(of: "[opt]", with: CliSyntaxColor.PINK)
            .replacingOccurrences(of: "[prompt]", with: CliSyntaxColor.YELLOW)
            .replacingOccurrences(of: "[error]", with: CliSyntaxColor.RED)
            .replacingOccurrences(of: "[errdesc]", with: CliSyntaxColor.PINK)
            .replacingOccurrences(of: "[num]", with: CliSyntaxColor.GREEN)
            .replacingOccurrences(of: "[success]", with: CliSyntaxColor.GREEN_BRIGHT)
            .replacingOccurrences(of: "[end]", with: CliSyntaxColor.END)

            // Colors
            .replacingOccurrences(of: "[cyan]", with: CliSyntaxColor.CYAN)
            .replacingOccurrences(of: "[green]", with: CliSyntaxColor.GREEN)
            .replacingOccurrences(of: "[red]", with: CliSyntaxColor.RED)
            .replacingOccurrences(of: "[yel]", with: CliSyntaxColor.YELLOW)
            .replacingOccurrences(of: "[blue]", with: CliSyntaxColor.BLUE)
    }
}
