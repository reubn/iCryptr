import UIKit
import MobileCoreServices

import AVFoundation
import AVKit

import QuickLook

class EncryptDocumentViewController: UIViewController, UIDocumentPickerDelegate {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    self.navigationBar.layer.zPosition = 1
    self.navigationBar.topItem!.title = self.document?.fileURL.lastPathComponent
    self.activityIndicator.stopAnimating()
    
    var data: Data? = nil
    
    do {
      data = try Data(contentsOf: self.document!.fileURL as URL)
    } catch {
      print("Unable to load data: \(error)")
      
      return
    }
    
    if data != nil {
      createThumbnail(self.document!.fileURL) {thumbnailString, tintColour in
        DispatchQueue.main.async {
          self.thumbnailString = thumbnailString
          self.view.tintColor = tintColour
        }
      }
      
      let quickLookViewController = QLPreviewController()
      
      let instance = QLPreviewControllerSingleDataSource(fileURL: self.document!.fileURL)
      
      quickLookViewController.dataSource = instance
      quickLookViewController.currentPreviewItemIndex = 0
      
      quickLookViewController.view.bounds = self.scrollView.bounds
      quickLookViewController.view.frame = self.scrollView.frame
      
      self.addChild(quickLookViewController)
      self.scrollView.contentInset = UIEdgeInsets(top: 28 + 16 + 6, left: 0, bottom: 0, right: 0)
      self.scrollView.insertSubview(quickLookViewController.view, at: 1)
      
      quickLookViewController.reloadData()
    }
    
    
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    CryptionManager.shared.clearTemporaryDirectory()
  }
  
  @IBAction func dismissDocumentViewController() {
    dismiss(animated: true) {
      self.document?.close(completionHandler: nil)
    }
  }
  
  // MARK IB Actions for encryption
  @IBAction func encryptWithSpecificPassword() {
    // Set up alert controler to get password and new filename
    let alert = UIAlertController(title: "Enter Encryption Password", message: "", preferredStyle: .alert)
    // encrypt file on save
    let alertSaveAction = UIAlertAction(title: "Submit", style: .default) { action in
      guard let passwordField = alert.textFields?[0], let password = passwordField.text else { return }
      self.encrypt(with: .specific(password))
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
    present(alert, animated: true)
  }
  
  func encrypt(with: CryptionManager.PasswordMethod) {
    CryptionManager.shared.crypt(towards: .encrypted, documents: [self.document!], with: with){message in
      DispatchQueue.main.async {
        switch message {
          case .authenticationFailed:
            self.activityIndicator.stopAnimating()
            
          case .authenticationSuccessful:
            self.activityIndicator.startAnimating()
            
          case .encryptionComplete(let tempURLs, _):
            self.activityIndicator.stopAnimating()
            
            let documentSaveController = UIDocumentPickerViewController(forExporting: tempURLs, asCopy: true)
            documentSaveController.delegate = self
            documentSaveController.popoverPresentationController?.sourceView = self.view
            
            self.present(documentSaveController, animated: true, completion: nil)
        case .decryptionComplete: ()
        }
      }
    }
  }
  
  @IBAction func encryptWithDefaultPassword() {
    encrypt(with: .default)
  }
  
  func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt: [URL]){
    // When User Saves File
    self.dismissDocumentViewController()
  }
  
  // MARK: IB Outlets
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var navigationBar: UINavigationBar!
  
  @IBOutlet weak var lockButton: UIBarButtonItem!
  @IBOutlet weak var lockWithPasswordButton: UIBarButtonItem!
  
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  var thumbnailString: String? = nil
  
  // MARK: Class Variables
  var document: Document?
}
