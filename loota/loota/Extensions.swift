import UIKit

extension UIDevice {
  var vendorId: String? {
    return self.identifierForVendor?.uuidString
  }
}
