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
    
    if (self.tempFileURL != nil) {
      do {
        try FileManager.default.removeItem(at: self.tempFileURL!)
        print("removed files")
      } catch {
        print("failed to remove temporary url with error: \(error)")
      }
    }
    
  }
  
  @IBAction func dismissDocumentViewController() {
    dismiss(animated: true) {
      self.document?.close(completionHandler: nil)
    }
  }
  
  // MARK IB Actions for encryption
  @IBAction func encryptWithSpecificPasswordFlow() {
    // Set up alert controler to get password and new filename
    let alert = UIAlertController(title: "Enter Password", message: "", preferredStyle: .alert)
    // encrypt file on save
    let alertSaveAction = UIAlertAction(title: "Submit", style: .default) { action in
      guard let passwordField = alert.textFields?[0], let password = passwordField.text else { return }
      self.encryptCommonFlow(password){_ in}
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
  
  @IBAction func encryptWithDefaultPasswordFlow() {
    verifyIdentity(ReasonForAuthenticating: "Authorize use of default password") {authenticated in
      if(authenticated) {
        guard let password = getPasswordFromKeychain(forAccount: ".password") else { return }
        self.encryptCommonFlow(password){_ in}
      } else {
        self.activityIndicator.stopAnimating()
      }
    }
  }
  
  // MARK: Class Methods
  func encryptCommonFlow(_ passwd: String, completion: @escaping (Bool) -> Void) -> Void  {
    self.activityIndicator.startAnimating()
    
    guard let fileURL = self.document?.fileURL else { return }
    
    DispatchQueue.global(qos: .background).async {
      let result = encryptFile(fileURL, passwd, self.document!.fileURL.lastPathComponent, self.thumbnailString!)
      
      let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      let temporaryDir = ProcessInfo().globallyUniqueString
      
      let tempFileDirURL = temporaryDirectoryURL.appendingPathComponent(temporaryDir)
      self.tempFileURL = tempFileDirURL.appendingPathComponent(result!.fileName)
      
      do {
        try FileManager.default.createDirectory(at: tempFileDirURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        print("temp dir cr failed")
        return completion(false)
      }
      
      print(self.tempFileURL!)
      
      do {
        try result!.fileData.write(to: self.tempFileURL!, options: .atomic)
        print("Written temp file")
      } catch {
        print("error")
        return completion(false)
      }
      
      
      DispatchQueue.main.async {
        completion(true)
        self.activityIndicator.stopAnimating()
        
        let documentSaveController = UIDocumentPickerViewController(forExporting: [self.tempFileURL!], asCopy: true)
        documentSaveController.delegate = self
        documentSaveController.popoverPresentationController?.sourceView = self.view
        
        self.present(documentSaveController, animated: true, completion: nil)
      }
      
    }
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
  
  var tempFileURL: URL? = nil
  
  var thumbnailString: String? = nil
  
  // MARK: Class Variables
  var document: UIDocument?
  
}
