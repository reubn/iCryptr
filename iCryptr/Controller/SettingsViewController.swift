import Foundation
import UIKit

class SettingsViewController: UITableViewController {
  // IBActions
  @IBAction func dismissWhenDone() {
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func setDefaultPassword() {
    verifyIdentity(ReasonForAuthenticating: "Authorize changing default password") {authenticated in
      if(authenticated) {
        // Set up alert controller to get password
        let alert = UIAlertController(title: "Enter Password", message: nil, preferredStyle: .alert)
        // set default password on save
        let alertSaveAction = UIAlertAction(title: "Submit", style: .default) { action in
          guard let passwordField = alert.textFields?[0], let password = passwordField.text else { return }
          let _ = setDefaultPasswordInKeychain(withPassword: password, forAccount: ".password")
        }
        let alertCancelAction = UIAlertAction(title: "Cancel", style: .default)
        
        // build alert from parts
        alert.addTextField { passwordField in
          passwordField.placeholder = "Password"
          passwordField.clearButtonMode = .whileEditing
          passwordField.isSecureTextEntry = true
          passwordField.autocapitalizationType = .none
          passwordField.autocorrectionType = .no
        }
        alert.addAction(alertCancelAction)
        alert.addAction(alertSaveAction)
        alert.preferredAction = alertSaveAction
        
        // present alert
        self.present(alert, animated: true)
      }
    }
  }
}
