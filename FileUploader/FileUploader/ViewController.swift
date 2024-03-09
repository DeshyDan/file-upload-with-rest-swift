//
//  ViewController.swift
//  FileUploader
//
//  Created by Gabriel Theodoropoulos.
//  Copyright © 2019 Appcoda. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let rest = RestManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        uploadSingleFile()
        // Do any additional setup after loading the view.
    }
    func uploadSingleFile() {
        let fileURL = Bundle.main.url(forResource: "sampleText", withExtension: "txt")
        let fileInfo = RestManager.FileInfo(withFileURL: fileURL, filename: "sampleText.txt", name: "uploadedFile", mimetype: "text/plain")
    }
    func upload(files: [RestManager.FileInfo], toURL url: URL?) {
        if let uploadURL = url {
            rest.upload(files: files, toURL: uploadURL, withHttpMethod: .post) { (results, failedFilesList) in
                print("HTTP status code:", results.response?.httpStatusCode ?? 0)
     
                if let error = results.error {
                    print(error)
                }
     
                if let data = results.data {
                    if let toDictionary = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) {
                        print(toDictionary)
                    }
                }
     
                if let failedFiles = failedFilesList {
                    for file in failedFiles {
                        print(file)
                    }
                }
            }
        }
    }

}

