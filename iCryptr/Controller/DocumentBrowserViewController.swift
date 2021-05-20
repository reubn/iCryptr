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
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        allowsDocumentCreation = false
        allowsPickingMultipleItems = true
        shouldShowFileExtensions = true
        
        // Update the style of the UIDocumentBrowserViewController
        browserUserInterfaceStyle = .white
        view.tintColor = UIColor.init(red: 14.0/255, green: 122.0/255, blue: 254.0/255, alpha: 1.0)
        
        let settingsBarButton = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(self.presentSettings))
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
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentURLs documentURLs: [URL]) {
      if(documentURLs.count == 1){
        let document = Document(fileURL: documentURLs.first!)
        
        presentDocument(document)
      } else {
        let documents = documentURLs.map({Document(fileURL: $0)})
        let cryptionStates = documents.map({CryptionManager.CryptionState(document: $0)})
        
        let currentCryptionState = cryptionStates.first!
        let homogenous = cryptionStates.allSatisfy({$0 == currentCryptionState})
        
        if(!homogenous) {
          print("documents must be of same encryption state")
          return
        }
        
        CryptionManager.shared.crypt(towards: currentCryptionState.to, documents: documents, with: .default){message in
          DispatchQueue.main.async {
            switch message {
              case .encryptionComplete(let tempURLs), .decryptionComplete(let tempURLs):
                let documentSaveController = UIDocumentPickerViewController(forExporting: tempURLs, asCopy: true)
                documentSaveController.delegate = self
                documentSaveController.popoverPresentationController?.sourceView = self.view
                
                self.present(documentSaveController, animated: true, completion: nil)
              default: ()
            }
          }
        }
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
        
        if(CryptionManager.CryptionState(document: document) == .encrypted) {
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
