//
//  RestManager.swift
//  RestManager
//
//  Created by Gabriel Theodoropoulos.
//  Copyright © 2019 Appcoda. All rights reserved.
//

import Foundation

class RestManager {
    
    // MARK: - Properties
    
    var requestHttpHeaders = RestEntity()
    
    var urlQueryParameters = RestEntity()
    
    var httpBodyParameters = RestEntity()
    
    var httpBody: Data?
    
    
    // MARK: - Public Methods
    
    func makeRequest(toURL url: URL,
                     withHttpMethod httpMethod: HttpMethod,
                     completion: @escaping (_ result: Results) -> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let targetURL = self?.addURLQueryParameters(toURL: url)
            let httpBody = self?.getHttpBody()
            
            guard let request = self?.prepareRequest(withURL: targetURL, httpBody: httpBody, httpMethod: httpMethod) else
            {
                completion(Results(withError: CustomError.failedToCreateRequest))
                return
            }
            
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.dataTask(with: request) { (data, response, error) in
                completion(Results(withData: data,
                                   response: Response(fromURLResponse: response),
                                   error: error))
            }
            task.resume()
        }
    }
    
    
    
    func getData(fromURL url: URL, completion: @escaping (_ data: Data?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
                guard let data = data else { completion(nil); return }
                completion(data)
            })
            task.resume()
        }
    }
    
    
    
    // MARK: - Private Methods
    
    private func addURLQueryParameters(toURL url: URL) -> URL {
        if urlQueryParameters.totalItems() > 0 {
            guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
            var queryItems = [URLQueryItem]()
            for (key, value) in urlQueryParameters.allValues() {
                let item = URLQueryItem(name: key, value: value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
                
                queryItems.append(item)
            }
            
            urlComponents.queryItems = queryItems
            
            guard let updatedURL = urlComponents.url else { return url }
            return updatedURL
        }
        
        return url
    }
    
    
    
    private func getHttpBody() -> Data? {
        guard let contentType = requestHttpHeaders.value(forKey: "Content-Type") else { return nil }
        
        if contentType.contains("application/json") {
            return try? JSONSerialization.data(withJSONObject: httpBodyParameters.allValues(), options: [.prettyPrinted, .sortedKeys])
        } else if contentType.contains("application/x-www-form-urlencoded") {
            let bodyString = httpBodyParameters.allValues().map { "\($0)=\(String(describing: $1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)))" }.joined(separator: "&")
            return bodyString.data(using: .utf8)
        } else {
            return httpBody
        }
    }
    
    
    
    private func prepareRequest(withURL url: URL?, httpBody: Data?, httpMethod: HttpMethod) -> URLRequest? {
        guard let url = url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        for (header, value) in requestHttpHeaders.allValues() {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        request.httpBody = httpBody
        return request
    }
}


// MARK: - RestManager Custom Types

extension RestManager {
    enum HttpMethod: String {
        case get
        case post
        case put
        case patch
        case delete
    }

    
    
    struct RestEntity {
        private var values: [String: String] = [:]
        
        mutating func add(value: String, forKey key: String) {
            values[key] = value
        }
        
        func value(forKey key: String) -> String? {
            return values[key]
        }
        
        func allValues() -> [String: String] {
            return values
        }
        
        func totalItems() -> Int {
            return values.count
        }
    }
    
    
    
    struct Response {
        var response: URLResponse?
        var httpStatusCode: Int = 0
        var headers = RestEntity()
        
        init(fromURLResponse response: URLResponse?) {
            guard let response = response else { return }
            self.response = response
            httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if let headerFields = (response as? HTTPURLResponse)?.allHeaderFields {
                for (key, value) in headerFields {
                    headers.add(value: "\(value)", forKey: "\(key)")
                }
            }
        }
    }
    
    
    
    struct Results {
        var data: Data?
        var response: Response?
        var error: Error?
        
        init(withData data: Data?, response: Response?, error: Error?) {
            self.data = data
            self.response = response
            self.error = error
        }
        
        init(withError error: Error) {
            self.error = error
        }
    }

    
    
    enum CustomError: Error {
        case failedToCreateRequest
    }
}


// MARK: - Custom Error Description
extension RestManager.CustomError: LocalizedError {
    public var localizedDescription: String {
        switch self {
        case .failedToCreateRequest: return NSLocalizedString("Unable to create the URLRequest object", comment: "")
        }
    }
}




// MARK: - File Upload Related Implementation

extension RestManager {
    struct FileInfo{
        var fileContents: Data?
        var mimetype:String?
        var filename:String?
        var name: String?
        
        init(withFileURL url: URL?, filename: String, name: String, mimetype: String) {
                guard let url = url else { return }
                fileContents = try? Data(contentsOf: url)
                self.filename = filename
                self.name = name
                self.mimetype = mimetype
            }}
    
    private func createBoundary() -> String? {
        var uuid = UUID().uuidString
        uuid = uuid.replacingOccurrences(of: "-", with: "")
        uuid = uuid.map { $0.lowercased() }.joined()
     
        let boundary = String(repeating: "-", count: 20) + uuid + "\(Int(Date.timeIntervalSinceReferenceDate))"
     
        return boundary
    }
    private func getHttpBody(withBoundary boundary: String) -> Data {
        var body = Data()
     
        for (key, value) in httpBodyParameters.allValues() {
            let values = ["--\(boundary)\r\n",
                "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n",
                "\(value)\r\n"]
     
            _ = body.append(values: values)
        }
     
        return body
    }
    private func add(files: [FileInfo], toBody body: inout Data, withBoundary boundary: String) -> [String]? {
        var status = true
        var failedFilenames: [String]?
     
        for file in files {
            guard let filename = file.filename, let content = file.fileContents, let mimetype = file.mimetype, let name = file.name else { continue }
            status = false
            var data = Data()
     
            let formattedFileInfo = ["--\(boundary)\r\n",
                "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n",
                "Content-Type: \(mimetype)\r\n\r\n"]
     
            if data.append(values: formattedFileInfo) {
                if data.append(values: [content]) {
                    if data.append(values: ["\r\n"]) {
                        status = true
                    }
                }
            }
     
            if status {
                body.append(data)
            } else {
                if failedFilenames == nil {
                    failedFilenames = [String]()
                }
     
                failedFilenames?.append(filename)
            }
        }
     
        return failedFilenames
    }
    
    
    func upload(files: [FileInfo], toURL url: URL,
                withHttpMethod httpMethod: HttpMethod,
                completion: @escaping(_ result: Results, _ failedFiles: [String]?) -> Void) {
     
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let targetURL = self?.addURLQueryParameters(toURL: url)
            guard let boundary = self?.createBoundary() else { completion(Results(withError: CustomError.failedToCreateBoundary), nil); return }
            self?.requestHttpHeaders.add(value: "multipart/form-data; boundary=\(boundary)", forKey: "content-type")
     
            guard var body = self?.getHttpBody(withBoundary: boundary) else { completion(Results(withError: CustomError.failedToCreateHttpBody), nil); return }
            let failedFilenames = self?.add(files: files, toBody: &body, withBoundary: boundary)
            self?.close(body: &body, usingBoundary: boundary)
     
            guard let request = self?.prepareRequest(withURL: targetURL, httpBody: body, httpMethod: httpMethod) else { completion(Results(withError: CustomError.failedToCreateRequest), nil); return }
     
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.uploadTask(with: request, from: nil, completionHandler: { (data, response, error) in
                completion(Results(withData: data,
                                   response: Response(fromURLResponse: response),
                                   error: error),
                           failedFilenames)
            })
            task.resume()
        }
     
    }

    
    


}
// MARK: - Data Extension
extension Data {
    mutating func append<T>(values: [T]) -> Bool {
            var newData = Data()
            var status = true
     
            if T.self == String.self {
                for value in values {
                    guard let convertedString = (value as! String).data(using: .utf8) else { status = false; break }
                    newData.append(convertedString)
                }
            } else if T.self == Data.self {
                for value in values {
                    newData.append(value as! Data)
                }
            } else {
                status = false
            }
     
            if status {
                self.append(newData)
            }
     
            return status
        }
}
