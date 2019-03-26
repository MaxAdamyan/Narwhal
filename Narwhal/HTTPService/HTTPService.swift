//
//  Service.swift
//  Narwhal
//
//  Created by Max Adamyan on 2/28/19.
//

import Foundation
import Alamofire
import ObjectMapper

public protocol HTTPServiceRequest {
    func progress(_ closure: @escaping (Progress) -> Void)
    func suspend()
    func resume()
    func cancel()
}

extension DataRequest: HTTPServiceRequest {
    public func progress(_ closure: @escaping (Progress) -> Void) {
        downloadProgress(closure: closure)
    }
}

open class HTTPService {
    public enum RequestError: Error {
        case seralizationFailed
        case middlewareValidation
    }
    
    public struct MiddlewareResponse {
        public var body: Data?
        public var request: URLRequest?
        public var response: HTTPURLResponse?
    }
    
    public enum MiddlewareResult {
        case `continue`
        case abort
    }
    
    public struct Response<T, E> {
        public var value: T?
        public var error: Error?
        public var errorBody: E?
        public var response: HTTPURLResponse?
    }
    
    public typealias EmptyCallback = (Response<Empty, [String: Any]>) -> Void
    public typealias EmptyErrorCallback<E: Mappable> = (Response<Empty, E>) -> Void
    public typealias Callback<T: Mappable> = (Response<T, [String: Any]>) -> Void
    public typealias ErrorCallback<T: Mappable, E: Mappable> = (Response<T, E>) -> Void
    public typealias ArrayCallback<T: Mappable> = (Response<[T], [String: Any]>) -> Void
    public typealias ArrayErrorCallback<T: Mappable, E: Mappable> = (Response<[T], E>) -> Void
    
    //MARK: -
    
    open var baseURL: String? = nil
    open func additionalHeaders(for endpoint: String) -> [String:String] { return [:] }
    open var errorKeyPath: String? { return nil }
    open var valueKeyPath: String? { return nil }
    open var responseMiddlewares: [(MiddlewareResponse) -> MiddlewareResult] { return [] }
    
    public init() {}
    
    private func dataRequest(endpoint: String, method: HTTPMethod,
                             params: [String: Any]?, headers: [String: String] = [:],
                             callback: @escaping (DefaultDataResponse) -> Void) -> DataRequest {
        
        var allHeaders = additionalHeaders(for: endpoint)
        for (key, value) in headers {
            allHeaders.updateValue(value, forKey: key)
        }
        
        var url = endpoint
        if let base = baseURL, !endpoint.contains("http") {
            url  = base + endpoint
        }
        
        let encoding: ParameterEncoding = (method == .get || method == .delete ?
            URLEncoding(arrayEncoding: .noBrackets) : JSONEncoding.default)
        
        return Alamofire.request(url, method: method, parameters: params, encoding: encoding, headers: allHeaders)
            .validate() //For more flexibilite one can write custome validator
            .response(completionHandler: {(response) in
                let middlewareResponse = MiddlewareResponse(body: response.data,
                                                            request: response.request,
                                                            response: response.response)
                
                for middleware in self.responseMiddlewares {
                    let result = middleware(middlewareResponse)
                    switch result {
                    case .continue: break
                    case .abort: return
                    }
                }
                callback(response)
            })
    }
    
    private class ResponseSerilizer<T: Mappable, E: Mappable> {
        var valueKeyPath: String?
        var errorKeyPath: String?
        
        init(valueKeyPath: String?, errorKeyPath: String? = nil) {
            self.valueKeyPath = valueKeyPath
            self.errorKeyPath = errorKeyPath
        }
        
        func errorBody(fromJSON json: [String: Any]?) -> [String: Any]? {
            guard let errorKeyPath = errorKeyPath, errorKeyPath != "",
            let json = json else { return nil }
            
            return (json as AnyObject).value(forKeyPath: errorKeyPath) as? [String : Any]
        }
        
        func baseTransform<_T, _E: Mappable>(response: inout Response<_T,_E>, data: Data?, error: Error?,
                                             httpResponse: HTTPURLResponse?) -> Any? {
            var json: [String: Any]?
            do {
                if let data = data, data.count > 0 {
                    json = (try JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
                }
            } catch(_) {
                response.error = error ?? RequestError.seralizationFailed
                return nil
            }
            
            if error != nil {
                if let errorBody = self.errorBody(fromJSON: json) {
                    response.errorBody = Mapper<_E>().map(JSON: errorBody)
                }
                response.error = error
                return nil
            }
            
            if let keyPath = valueKeyPath, keyPath != "" {
                return (json as AnyObject).value(forKeyPath: keyPath)
            }
            
            return json
        }
        
        func transoform(data: Data?, error: Error?,
                        httpResponse: HTTPURLResponse?) -> Response<T, E> {
            
            var response = Response<T, E>()
            response.response = httpResponse
            
            let json = baseTransform(response: &response, data: data, error: error,
                                     httpResponse: httpResponse)
            
            if let valueBody = json as? [String: Any] {
                response.value = Mapper<T>().map(JSON: valueBody)
            }
            
            return response
        }
    }
    
    private class ResponseArraySerilizer<T: Mappable, E: Mappable>: ResponseSerilizer<T, E> {
        func transoform(data: Data?, error: Error?,
                        httpResponse: HTTPURLResponse?) -> Response<[T], E> {
            
            var response = Response<[T], E>()
            response.response = httpResponse
            
            let json = baseTransform(response: &response, data: data, error: error,
                                     httpResponse: httpResponse)
            
            if let valueBody = json as? [[String: Any]] {
                response.value = Mapper<T>().mapArray(JSONArray: valueBody)
            }
            
            return response
        }
    }
    
    @discardableResult public
    func request<T: Mappable, E: Mappable>(endpoint: String, method: HTTPMethod = .get,
                                           params: [String: Any]? = nil, headers: [String: String] = [:],
                                           valueKeyPath: String? = nil, errorKeyPath: String? = nil,
                                           callback: @escaping ErrorCallback<T, E>) -> HTTPServiceRequest {
        
        let request = dataRequest(endpoint: endpoint, method: method, params: params, headers: headers)
        { (response) in
            let serilizer = ResponseSerilizer<T, E>(valueKeyPath: valueKeyPath ?? self.valueKeyPath,
                                                    errorKeyPath: errorKeyPath ?? self.errorKeyPath)
            
            callback(serilizer.transoform(data: response.data, error: response.error,
                                          httpResponse: response.response))
        }
        return request
    }
    
    @discardableResult public
    func requestArray<T: Mappable, E: Mappable>(endpoint: String, method: HTTPMethod = .get,
                                                params: [String: Any]? = nil, headers: [String: String] = [:],
                                                valueKeyPath: String? = nil, errorKeyPath: String? = nil,
                                                callback: @escaping ArrayErrorCallback<T, E>) -> HTTPServiceRequest {
        
        let request = dataRequest(endpoint: endpoint, method: method, params: params, headers: headers)
        { (response) in
            let serilizer = ResponseArraySerilizer<T, E>(valueKeyPath: valueKeyPath ?? self.valueKeyPath,
                                                         errorKeyPath: errorKeyPath ?? self.errorKeyPath)
            
            callback(serilizer.transoform(data: response.data, error: response.error,
                                          httpResponse: response.response))
        }
        return request
    }
}
