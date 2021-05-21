//
//  DocumentBrowserViewController.swift
//  iCryptr
//
//  Created by Brendan Lindsey on 2/4/18.
//  Copyright © 2018 Brendan Lindsey. All rights reserved.
//

import UIKit
import MobileCoreServices


class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate, UIDocumentPickerDelegate {
  var queuedFailureInfo: ([URL], [CryptionManager.CryptionFailure])? = nil
  
  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self
    allowsDocumentCreation = false
    allowsPickingMultipleItems = false
    shouldShowFileExtensions = true
    
    // Update the style of the UIDocumentBrowserViewController
    browserUserInterfaceStyle = .white
    view.tintColor = UIColor.init(red: 14.0/255, green: 122.0/255, blue: 254.0/255, alpha: 1.0)
    
    let encryptDefaultAction = UIDocumentBrowserAction(identifier: "encryptDefault", localizedTitle: "Encrypt with Default Password", availability: [.menu, .navigationBar], handler: {urls in
      let documents = urls.map({Document(fileURL: $0)})
      
      self.crypt(towards: .encrypted, documents: documents, with: .default)
    })
    encryptDefaultAction.supportsMultipleItems = true
    encryptDefaultAction.image = UIImage(systemName: "lock")
    
    let encryptSpecificAction = UIDocumentBrowserAction(identifier: "encryptSpecific", localizedTitle: "Encrypt with Specific Password", availability: [.menu, .navigationBar], handler: {urls in
      let documents = urls.map({Document(fileURL: $0)})
      
      // Set up alert controler to get password and new filename
      let alert = UIAlertController(title: "Enter Encryption Password", message: "", preferredStyle: .alert)
      // encrypt file on save
      let alertSaveAction = UIAlertAction(title: "Submit", style: .default) { action in
        guard let passwordField = alert.textFields?[0], let password = passwordField.text else { return }
        self.crypt(towards: .encrypted, documents: documents, with: .specific(password))
      }
      // set up cancel action
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
    })
    encryptSpecificAction.supportsMultipleItems = true
    encryptSpecificAction.image = UIImage(systemName: "rectangle.and.pencil.and.ellipsis")
    
    let decryptAction = UIDocumentBrowserAction(identifier: "decrypt", localizedTitle: "Decrypt", availability: [.menu, .navigationBar], handler: {urls in
      let documents = urls.map({Document(fileURL: $0)})
      
      self.crypt(towards: .decrypted, documents: documents, with: .default)
    })
    decryptAction.supportsMultipleItems = true
    decryptAction.image = UIImage(systemName: "lock.open")
    decryptAction.supportedContentTypes = ["com.reuben.icryptr.encryptedfile"]

    
    customActions = [encryptSpecificAction, encryptDefaultAction, decryptAction]

    let settingsBarButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.presentSettings))

    additionalTrailingNavigationBarButtonItems = [settingsBarButton]
  }
  
  
  // MARK: UIDocumentBrowserViewControllerDelegate
  func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
    let newDocumentURL: URL? = nil
    
    // Set the URL for the new document here. Optionally, you can present a template chooser before calling the importHandler.
    // Make sure the importHandler is always called, even if the user cancels the creation request.
    if newDocumentURL != nil {
      importHandler(newDocumentURL, .move)
    } else {
      importHandler(nil, .none)
    }
  }
  
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    print("dp dpda", urls)
    
    CryptionManager.shared.clearTemporaryDirectory()
    
    if let info = queuedFailureInfo {
      self.processDecryptionFailures(successes: info.0, failures: info.1)
      queuedFailureInfo = nil
    }
  }
  
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    print("dp dpwc")
    
    CryptionManager.shared.clearTemporaryDirectory()
    
    if let info = queuedFailureInfo {
      self.processDecryptionFailures(successes: info.0, failures: info.1)
      queuedFailureInfo = nil
    }
  }
  
  func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentURLs documentURLs: [URL]) {
    if(documentURLs.count == 1){
      let document = Document(fileURL: documentURLs.first!)
      
      presentDocument(document)
    } else {
      let documents = documentURLs.map({Document(fileURL: $0)})
      let cryptionStates = documents.map({$0.cryptionState})
      
      let currentCryptionState = cryptionStates.first!
      let homogenous = cryptionStates.allSatisfy({$0 == currentCryptionState})
      
      if(!homogenous) {
        print("documents must be of same encryption state")
        return
      }
      
      crypt(towards: currentCryptionState.to, documents: documents, with: .default)
    }
  }
  
  func crypt(towards: CryptionManager.CryptionState, documents: [Document], with: CryptionManager.PasswordMethod){
    CryptionManager.shared.crypt(towards: towards, documents: documents, with: with){message in
      DispatchQueue.main.async {
        switch message {
        case .encryptionComplete(let tempURLs, _):
          let documentSaveController = UIDocumentPickerViewController(forExporting: tempURLs, asCopy: true)
          documentSaveController.delegate = self
          documentSaveController.popoverPresentationController?.sourceView = self.view
          
          self.present(documentSaveController, animated: true, completion: nil)
        case .decryptionComplete(let tempURLs, let failures):
          if(!tempURLs.isEmpty) {
            let documentSaveController = UIDocumentPickerViewController(forExporting: tempURLs, asCopy: true)
            documentSaveController.delegate = self
            documentSaveController.popoverPresentationController?.sourceView = self.view
            
            self.queuedFailureInfo = (tempURLs, failures)
            
            self.present(documentSaveController, animated: true, completion: nil)
          } else {
            self.processDecryptionFailures(successes: tempURLs, failures: failures)
          }
        default: ()
        }
      }
    }
  }
  
  func processDecryptionFailures(successes: [URL], failures: [CryptionManager.CryptionFailure]){
    if(!failures.isEmpty) {
      let documents = failures.map({$0.document})
      
      let successCount = successes.count
      let failureCount = failures.count
      
      var message: String {
        get {
          if(successCount == 0) {
            return ""
          }
          
          let successItemsPlural = successCount == 1 ? "item" : "items"
          let failureItemsPlural = failureCount == 1 ? "item" : "items"
          
          return "\(successCount) \(successItemsPlural) succeeded, but \(failureCount) \(failureItemsPlural) failed. \nEnter Decryption Password for \(failureCount) \(failureItemsPlural)"
        }
      }
      
      // Set up alert controler to get password and new filename
      let alert = UIAlertController(title: "Enter Decryption Password", message: message, preferredStyle: .alert)
      // encrypt file on save
      let alertSaveAction = UIAlertAction(title: "Submit", style: .default) { action in
        guard let passwordField = alert.textFields?[0], let password = passwordField.text else { return }
        self.crypt(towards: .decrypted, documents: documents, with: .specific(password))
      }
      // set up cancel action
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
  
  func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
    // Present the Document View Controller for the new newly created document
    let document = Document(fileURL: destinationURL)
    presentDocument(document)
  }
  
  func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
    // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
  }
  
  // MARK: View Presentation
  func presentDocument(_ document: Document) {
    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
    
    if(document.cryptionState == .encrypted) {
      let documentViewController = storyBoard.instantiateViewController(withIdentifier: "DecryptViewController") as! DecryptDocumentViewController
      documentViewController.document = document
      present(documentViewController, animated: true, completion: nil)
    } else {
      let documentViewController = storyBoard.instantiateViewController(withIdentifier: "EncryptViewController") as! EncryptDocumentViewController
      documentViewController.document = document
      present(documentViewController, animated: true, completion: nil)
    }
  }
  
  @objc func presentSettings() {
    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
    let settingsViewController = storyBoard.instantiateViewController(withIdentifier: "SettingsNavigationController") as! UINavigationController
    present(settingsViewController, animated: true, completion: nil)
    
  }
}
