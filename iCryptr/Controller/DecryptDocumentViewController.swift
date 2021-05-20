import UIKit
import AVFoundation
import AVKit
import QuickLook
import ImageScrollView

class DecryptDocumentViewController: UIViewController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.activityIndicator.stopAnimating()
    self.navigationBar.layer.zPosition = 1
    
    
    if(self.decryptedData == nil) {
      self.imageScrollView.setup()
      //            self.resultImageScrollView.setup()
      
      
      self.navigationBar.topItem!.title = self.document?.fileURL.lastPathComponent
      self.shareButton.isEnabled = false
      
      
      if let tuple = extractThumbnail(self.document!.fileURL){
        let (image, tintColour) = tuple
        self.view.tintColor = tintColour
        
        self.imageScrollView.display(image: image!)
        self.imageScrollView.alpha = 1
        self.unlockButton.isEnabled = true
      }
      self.decryptWithDefaultPasswordFlow()
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    if isBeingDismissed && (self.tempFileURL != nil) {
      do {
        try FileManager.default.removeItem(at: self.tempFileURL!)
        self.tempFileURL = nil
        print("removed files")
      } catch {
        print("failed to remove temporary url with error: \(error)")
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
  }
  
  @objc func appMovedToBackground() {
    if(ignoreActiveNotifications == true) {return}
    print("bg")
    self.isAppInBackground = true
    if(self.decryptedData != nil) {
      self.decryptedData = nil
      if((self.presentedViewController) != nil) {self.presentedViewController!.dismiss(animated: false) {}}
      
      self.dismissDocumentViewController()
    }
  }
  
  @objc func appMovedToForeground() {
    if(ignoreActiveNotifications == true) {return}
    print("fg")
    self.isAppInBackground = false
    if(self.decryptedData == nil) {self.viewWillAppear(false)}
  }
  
  @IBAction func dismissDocumentViewController() {
    dismiss(animated: true) {
      self.document?.close(completionHandler: nil)
    }
  }
  
  // MARK: UIActions for decryption
  @IBAction func decryptWithSpecificPasswordFlow() {
    // Set up alert controller to get password
    let alert = UIAlertController(title: "Enter Password", message: "", preferredStyle: .alert)
    // decrypt file on save
    let alertSaveAction = UIAlertAction(title: "Submit", style: .default) { action in
      guard let passwordField = alert.textFields?[0], let password = passwordField.text else { return }
      self.decryptCommonFlow(password){_ in}
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
    present(alert, animated: true)
  }
  
  @IBAction func decryptWithDefaultPasswordFlow() {
    self.ignoreActiveNotifications = true
    print("ignoreActiveNotifications true")
    
    if self.isAppInBackground {
      print("skipping touchid not active")
      print("ignoreActiveNotifications false")
      self.ignoreActiveNotifications = false
      return
    }
    verifyIdentity(ReasonForAuthenticating: "Authorize use of default password") {authenticated in
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        print("ignoreActiveNotifications false")
        self.ignoreActiveNotifications = false
      }
      
      if(authenticated) {
        guard let passwd = getPasswordFromKeychain(forAccount: ".password") else { return }
        self.decryptCommonFlow(passwd) {success in
          if(!success) {
            self.decryptWithSpecificPasswordFlow()
          }
        }
      } else {
        self.activityIndicator.stopAnimating()
      }
    }
  }
  
  
  // MARK: Class Methods
  func decryptCommonFlow(_ passwd: String, completion: @escaping (Bool) -> Void) -> Void  {
    self.activityIndicator.startAnimating()
    // Dencrypt the file and display UIActivityIndicatorView
    guard let fileURL = self.document?.fileURL else { return completion(false)}
    DispatchQueue.global(qos: .background).async {
      let (fileData, fileName) = decryptFile(fileURL, passwd) ?? (nil, nil)
      
      
      
      DispatchQueue.main.async {
        self.activityIndicator.stopAnimating()
        
        if(fileData != nil) {
          completion(true)
          
          self.decryptedData = fileData
          
          self.shareButton.isEnabled = true
          self.shareButton.action = #selector(self.share)
          self.shareButton.target = self
          
          self.navigationBar.topItem!.title = fileName!
          self.unlockButton.isEnabled = false
          
          let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
          let temporaryDir = ProcessInfo().globallyUniqueString
          
          let tempFileDirURL = temporaryDirectoryURL.appendingPathComponent(temporaryDir)
          self.tempFileURL = tempFileDirURL.appendingPathComponent(fileName!)
          
          do {
            try FileManager.default.createDirectory(at: tempFileDirURL, withIntermediateDirectories: true, attributes: nil)
          } catch {
            print("temp dir cr failed")
            return completion(false)
          }
          
          print(self.tempFileURL!)
          
          do {
            try fileData!.write(to: self.tempFileURL!, options: .atomic)
            print("Written temp file")
          } catch {
            print("error")
            return completion(false)
          }
          
          
          let avAsset = AVURLAsset(url: self.tempFileURL!)
          
          if(avAsset.isPlayable) {
            let player = AVPlayer(url: self.tempFileURL!)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            
            self.present(playerViewController, animated: true) {
              playerViewController.player!.play()
            }
          } else {
            let quickLookViewController = QLPreviewController()
            
            let instance = QLPreviewControllerSingleDataSource(fileURL: self.tempFileURL!)
            
            quickLookViewController.dataSource = instance
            quickLookViewController.currentPreviewItemIndex = 0
            
            quickLookViewController.view.bounds = self.scrollView.bounds
            quickLookViewController.view.frame = self.scrollView.frame
            
            self.addChild(quickLookViewController)
            self.scrollView.contentInset = UIEdgeInsets(top: 28 + 16 + 6, left: 0, bottom: 0, right: 0)
            self.scrollView.insertSubview(quickLookViewController.view, at: 1)
            
            quickLookViewController.reloadData()
          }
          
          
          UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut){
            self.imageScrollView.alpha = 0
          }
        } else {
          print("Decrypt Failed")
          
          completion(false)
        }
      }
    }
  }
  
  @objc private func share() {
    let activityViewController: UIActivityViewController = UIActivityViewController(activityItems: [self.tempFileURL!], applicationActivities: nil)
    activityViewController.popoverPresentationController?.sourceView = self.view
    self.present(activityViewController, animated: true, completion: nil)
  }
  
  // MARK IBOutlets
  @IBOutlet weak var imageScrollView: ImageScrollView!
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var resultImageScrollView: ImageScrollView!
  @IBOutlet weak var navigationBar: UINavigationBar!
  @IBOutlet weak var shareButton: UIBarButtonItem!
  @IBOutlet weak var unlockButton: UIBarButtonItem!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  enum DecryptedType {
    case image
    case video
  }
  
  var decryptedData: Data? = nil
  
  var tempFileURL: URL? = nil
  
  var ignoreActiveNotifications = false
  var isAppInBackground = false
  
  //Mark Class Variables
  var document: UIDocument?
}
