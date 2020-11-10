//
//  main.swift
//  iCryptrCLI
//
//  Created by Reuben Eggar on 10/11/2020.
//  Copyright © 2020 Reuben. All rights reserved.
//

import Foundation

let arguments = Array(CommandLine.arguments[1...])
var stderr = StandardErrorOutputStream()
var isDir : ObjCBool = false

if(arguments.count == 0) {print("umm where's the key?", to: &stderr); exit(1)}

let key = arguments[0]
let paths = Array(arguments[1...])

if(paths.count == 0) {print("can't decrypt thin air mate", to: &stderr); exit(1)}

func decrypt(_ url: URL){
    let (fileData, fileName) = decryptFile(url, key) ?? (nil, nil)
    
    if(fileData == nil) {print("decryption failure", url); return}
    
    let outURL = url.deletingLastPathComponent().appendingPathComponent(fileName!)
    
    do {
        try fileData!.write(to: outURL, options: .atomic)
        print("written", outURL)
    } catch {
        print("file write error", outURL)
    }
}

for path in paths {
    let url = URL(fileURLWithPath: path)
    
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
        if(isDir.boolValue){
            if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                for file in contents {decrypt(file)}
            } else {print("read error", url)}
        } else {decrypt(url)}
    } else {
        print("read error", url)
    }
    
}



final class StandardErrorOutputStream: TextOutputStream {
    func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}
