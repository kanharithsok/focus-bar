import Foundation
import Security

enum CodeSigningInfo {
    /// The running process's Apple team identifier, or nil for an unsigned or
    /// ad-hoc build. Used to give a clear setup message instead of attempting
    /// an XPC connection that the helper will correctly reject.
    static func teamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
            return nil
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode
        else {
            return nil
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
            let dictionary = information as? [String: Any]
        else {
            return nil
        }

        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
