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
    
    
    if(!self.fileDecrypted && !specificPassword) {
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
      self.decrypt(with: .default)
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    if isBeingDismissed && (self.tempURL != nil) {
      CryptionManager.shared.clearTemporaryDirectory()
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
    if(self.fileDecrypted) {
      self.fileDecrypted = false
      if((self.presentedViewController) != nil) {self.presentedViewController!.dismiss(animated: false) {}}
      
      self.dismissDocumentViewController()
    }
  }
  
  @objc func appMovedToForeground() {
    if(ignoreActiveNotifications == true) {return}
    print("fg")
    self.isAppInBackground = false
    if(!self.fileDecrypted) {self.viewWillAppear(false)}
  }
  
  @IBAction func dismissDocumentViewController() {
    dismiss(animated: true) {
      self.document?.close(completionHandler: nil)
    }
  }

  @IBAction func decryptWithSpecificPassword() {
    specificPassword = true
    // Set up alert controller to get password
    let alert = UIAlertController(title: "Enter Decryption Password", message: "", preferredStyle: .alert)
    // decrypt file on save
    let alertSaveAction = UIAlertAction(title: "Submit", style: .default) { action in
      guard let passwordField = alert.textFields?[0], let password = passwordField.text else { return }
      self.decrypt(with: .specific(password))
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
  
  func decrypt(with: CryptionManager.PasswordMethod) {
    if case .default = with {
      self.ignoreActiveNotifications = true
      print("ignoreActiveNotifications true")

      if self.isAppInBackground {
        print("skipping touchid not active")
        print("ignoreActiveNotifications false")
        self.ignoreActiveNotifications = false
        return
      }
    }
    
    CryptionManager.shared.crypt(towards: .decrypted, documents: [self.document!], with: with){message in
      DispatchQueue.main.async {
        print(message)
        switch message {
          case .authenticationFailed:
            self.ignoreActiveNotifications = false
            self.activityIndicator.stopAnimating()
            
          case .authenticationSuccessful:
            self.ignoreActiveNotifications = false
            self.activityIndicator.startAnimating()
            
          case .decryptionComplete(let tempURLs, let failures):
            self.activityIndicator.stopAnimating()
            if let first = tempURLs.first {
              self.showDecryptedFile(first)
            }
            
            if(!failures.isEmpty){
              self.decryptWithSpecificPassword()
            }
          case .encryptionComplete: ()
        }
      }
    }
  }
  
  func showDecryptedFile(_ tempURL: URL){
    self.tempURL = tempURL
    self.fileDecrypted = true
    
    self.shareButton.isEnabled = true
    self.shareButton.action = #selector(self.share)
    self.shareButton.target = self
    
    self.navigationBar.topItem!.title = tempURL.lastPathComponent
    self.unlockButton.isEnabled = false
    
    let avAsset = AVURLAsset(url: tempURL)
    
    if(avAsset.isPlayable) {
      let player = AVPlayer(url: tempURL)
      let playerViewController = AVPlayerViewController()
      playerViewController.player = player
      
      self.present(playerViewController, animated: true) {
        playerViewController.player!.play()
      }
    } else {
      let quickLookViewController = QLPreviewController()
      
      let instance = QLPreviewControllerSingleDataSource(fileURL: tempURL)
      
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
  }
  
  @objc private func share() {
    let activityViewController: UIActivityViewController = UIActivityViewController(activityItems: [self.tempURL!], applicationActivities: nil)
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
  
  var specificPassword = false
  
  var fileDecrypted = false
  
  var tempURL: URL? = nil
  
  var ignoreActiveNotifications = false
  var isAppInBackground = false
  
  //Mark Class Variables
  var document: Document?
}
