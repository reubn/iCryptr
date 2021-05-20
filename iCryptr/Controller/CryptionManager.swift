//
//  EncryptionManager.swift
//  iCryptr
//
//  Created by Reuben Eggar on 18/05/2021.
//  Copyright © 2021 Reuben. All rights reserved.
//

import Foundation
import UIKit
import Promises


class CryptionManager {
  func crypt(towards: CryptionState, documents: [Document], with passwordMethod: PasswordMethod, notifier: @escaping (Update) -> Void){
    switch towards {
      case .encrypted: return encrypt(documents: documents, with: passwordMethod, notifier: notifier)
      case .decrypted: return decrypt(documents: documents, with: passwordMethod, notifier: notifier)
    }
  }
  
  func encrypt(documents: [Document], with passwordMethod: PasswordMethod, notifier: @escaping (Update) -> Void){
    switch passwordMethod {
      case .default:
        verifyIdentity(ReasonForAuthenticating: "Use Default Password to Encrypt") {authenticated in
            if(authenticated) {
              guard let password = getPasswordFromKeychain(forAccount: ".password") else {
                notifier(.authenticationFailed)
                
                return
              }
              
              notifier(.authenticationSuccessful)
              
              self.encrypt(documents: documents, password: password, notifier: notifier)
            } else {
              notifier(.authenticationFailed)
            }
        }
    case .specific(let password):
      notifier(.authenticationSuccessful)
      
      self.encrypt(documents: documents, password: password, notifier: notifier)
    }
  }
  
  func encrypt(documents: [Document], password: String, notifier: @escaping (Update) -> Void){
    DispatchQueue.global(qos: .userInitiated).async {
      let promises = documents.map({document -> Promise<CryptionResult> in
        return self.createThumbnailP(document.fileURL).then({thumbnailResult -> CryptionResult in
          let (fileName, fileData) = encryptFile(document.fileURL, password, document.fileURL.lastPathComponent, thumbnailResult.string)!
          
          return CryptionResult(fileName: fileName, fileData: fileData)
        })
      })
      
      let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      let temporaryDir = ProcessInfo().globallyUniqueString
      let tempFileDirURL = temporaryDirectoryURL.appendingPathComponent(temporaryDir)
      
      do {
        try FileManager.default.createDirectory(at: tempFileDirURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
          print("temp dir cr failed")
      }
      
      all(promises).then({encryptedResults in
        return encryptedResults.map({result -> URL in
          let tempFileURL = tempFileDirURL.appendingPathComponent(result.fileName)
          
          try! result.fileData.write(to: tempFileURL, options: .atomic)
          
          return tempFileURL
        })
      }).then({tempFileURLs in
        notifier(.encryptionComplete(tempFileURLs))
      })
    }
  }
  
  func decrypt(documents: [Document], with passwordMethod: PasswordMethod, notifier: @escaping (Update) -> Void){
    switch passwordMethod {
      case .default:
        verifyIdentity(ReasonForAuthenticating: "Use Default Password to Decrypt") {authenticated in
            if(authenticated) {
              guard let password = getPasswordFromKeychain(forAccount: ".password") else {
                notifier(.authenticationFailed)
                
                return
              }
              
              notifier(.authenticationSuccessful)
              
              self.decrypt(documents: documents, password: password, notifier: notifier)
            } else {
              notifier(.authenticationFailed)
            }
        }
    case .specific(let password):
      notifier(.authenticationSuccessful)
      
      self.encrypt(documents: documents, password: password, notifier: notifier)
    }
  }
  
  func decrypt(documents: [Document], password: String, notifier: @escaping (Update) -> Void){
    DispatchQueue.global(qos: .userInitiated).async {
      let decryptedResults = documents.map({document -> CryptionResult in
        let (fileData, fileName) = decryptFile(document.fileURL, password)!
        
        return CryptionResult(fileName: fileName, fileData: fileData)
      })
      
      let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      let temporaryDir = ProcessInfo().globallyUniqueString
      let tempFileDirURL = temporaryDirectoryURL.appendingPathComponent(temporaryDir)
      
      do {
        try FileManager.default.createDirectory(at: tempFileDirURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
          print("temp dir cr failed")
      }
      
      let tempFileURLs = decryptedResults.map({result -> URL in
        let tempFileURL = tempFileDirURL.appendingPathComponent(result.fileName)
        
        try! result.fileData.write(to: tempFileURL, options: .atomic)
        
        return tempFileURL
      })
      
      notifier(.decryptionComplete(tempFileURLs))

    }
  }
  
  func createThumbnailP(_ url: URL) -> Promise<ThumbnailResult> {
    Promise<ThumbnailResult> { fulfill, reject in
      createThumbnail(url, completion: {string, colour in
        fulfill(ThumbnailResult(string: string, colour: colour))
      })
    }
  }
  
  struct ThumbnailResult {
    let string: String
    let colour: UIColor
  }
  
  struct CryptionResult {
    let fileName: String
    let fileData: Data
  }
  
  enum PasswordMethod {
    case `default`
    case specific(String)
  }
  
  enum Update {
    case authenticationSuccessful
    case authenticationFailed
    
    case encryptionComplete([URL])
    case decryptionComplete([URL])
  }
  
  enum CryptionState: Equatable {
    case encrypted
    case decrypted
    
    init(document: Document) {
      self = document.savingFileType == "com.reuben.icryptr.encryptedfile" ? .encrypted : .decrypted
    }
    
    var to: Self {
      switch self {
        case .encrypted: return .decrypted
        case .decrypted: return .encrypted
      }
    }
    
    var from: Self {
      to
    }
  }
  
  static let shared = CryptionManager()
}
