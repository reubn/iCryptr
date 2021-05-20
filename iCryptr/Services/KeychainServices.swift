import Foundation
import Security
import LocalAuthentication

fileprivate func getRequestDict(forAccount account: String) -> Dictionary<String, Any> {
  var requestDict =  Dictionary<String, Any>()
  requestDict[kSecClass as String] = kSecClassGenericPassword
  requestDict[kSecAttrAccount as String] = account as Any?
  requestDict[kSecAttrService as String] = "iCryptr" as Any
  
  return requestDict
}


func setDefaultPasswordInKeychain(withPassword passwd: String, forAccount account: String) -> Bool {
  print("setDefaultPasswordInKeychain")
  // if account or password are empty strings
  guard !account.isEmpty, !passwd.isEmpty else { return false }
  print("accountNotEmpty")
  let passwordData = passwd.data(using: .utf8)
  var requestDict =  getRequestDict(forAccount: account)
  let attrDict = [kSecValueData as String : passwordData] as CFDictionary
  
  // try to update item
  guard SecItemUpdate(requestDict as CFDictionary, attrDict) == OSStatus(errSecSuccess) else {
    // update may have failed because item was not added, try to add
    requestDict[kSecValueData as String] = passwordData as Any?
    guard SecItemAdd(requestDict as CFDictionary, nil) == OSStatus(errSecSuccess) else { return false }
    return true
  }
  return true
}


func getPasswordFromKeychain(forAccount account: String ) -> String? {
  // if account is empty string
  guard !account.isEmpty else { return nil }
  
  var requestDict = getRequestDict(forAccount: account)
  requestDict[kSecMatchLimit as String] = kSecMatchLimitOne
  requestDict[kSecReturnData as String] = kCFBooleanTrue
  
  var result: AnyObject?
  let status = SecItemCopyMatching(requestDict as CFDictionary, &result)
  guard status == OSStatus(errSecSuccess), let data = result as? Data else { return nil }
  return String(data: data, encoding: .utf8)
}


func clearKeychainData(forAccount account: String) -> Bool {
  guard !account.isEmpty else { return false }
  let requestDict = getRequestDict(forAccount: account)
  guard SecItemDelete(requestDict as CFDictionary) == OSStatus(errSecSuccess) else { return false }
  return true
}


func verifyIdentity(ReasonForAuthenticating message: String, completion: @escaping (Bool) -> Void) -> Void {
  print("verifyIdentity")
  // check TouchID
  let reason = message.isEmpty ? "Authorize access" : message
  let context = LAContext()
  var error: NSError?
  
  if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalReason in
      DispatchQueue.main.async {
        if success {
          print("success")
          completion(true)
        } else {
          print(error?.localizedDescription ?? "Failed to authenticate")
          completion(false)
        }
      }
    }
  }
  
}

