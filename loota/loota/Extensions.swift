import UIKit
import Foundation

extension UIDevice {
  var vendorId: String? {
    return self.identifierForVendor?.uuidString
  }
}

// MARK: - Phone Number Validation

extension String {
  /// Validates phone number format using regex
  /// Accepts international and US formats
  func isValidPhoneNumber() -> Bool {
    let phoneRegex = "^[+]?[1-9]?[0-9]{7,15}$"
    let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
    return phonePredicate.evaluate(with: self.digitsOnly())
  }
  
  /// Returns only the digit characters from the string
  func digitsOnly() -> String {
    return self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
  }
  
  /// Formats phone number for display (US format)
  func formattedPhoneNumber() -> String {
    let digits = self.digitsOnly()
    
    // US phone number formatting
    if digits.count == 10 {
      let areaCode = String(digits.prefix(3))
      let prefix = String(digits.dropFirst(3).prefix(3))
      let suffix = String(digits.suffix(4))
      return "(\(areaCode)) \(prefix)-\(suffix)"
    }
    
    // International or other formats - return as is with basic formatting
    if digits.count > 10 {
      return "+\(digits)"
    }
    
    return digits
  }
}

// MARK: - Contact Actions

extension UIApplication {
  /// Opens phone dialer with the given number
  static func makePhoneCall(_ phoneNumber: String) {
    let cleanNumber = phoneNumber.digitsOnly()
    if let url = URL(string: "tel://\(cleanNumber)") {
      UIApplication.shared.open(url)
    }
  }
  
  /// Opens SMS app with the given number
  static func sendText(_ phoneNumber: String) {
    let cleanNumber = phoneNumber.digitsOnly()
    if let url = URL(string: "sms:\(cleanNumber)") {
      UIApplication.shared.open(url)
    }
  }
  
  /// Opens email app with the given address
  static func sendEmail(_ email: String) {
    if let url = URL(string: "mailto:\(email)") {
      UIApplication.shared.open(url)
    }
  }
}
