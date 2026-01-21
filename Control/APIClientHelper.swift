import Foundation
import OpenAPIClient

extension OpenAPIClientAPIConfiguration {
    func alternate(basePath: String, postAuthKey: String) {
        self.basePath = basePath
        customHeaders = [
            "X-Post-Auth-Key": postAuthKey,
        ]
        interceptor = ControlOpenAPIInterceptor(baseURL: URL(string: basePath)!)
    }
}

struct ControlOpenAPIInterceptor: OpenAPIInterceptor {
    private let origin: String?
    
    init(baseURL: URL) {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = ""
        self.origin = components.url?.absoluteString
    }
    
    func intercept<T>(urlRequest: URLRequest, urlSession: URLSessionProtocol, requestBuilder: RequestBuilder<T>, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        if let origin {
            switch urlRequest.httpMethod {
            case "PUT":
                fallthrough
            case "POST":
                fallthrough
            case "OPTIONS":
                fallthrough
            case "PATCH":
                fallthrough
            case "DELETE":
                var newRequest = urlRequest
                newRequest.addValue(origin, forHTTPHeaderField: "Origin")
                completion(.success(newRequest))
                return
            default: break
            }
        }
        
        completion(.success(urlRequest))
    }

    func retry<T>(urlRequest: URLRequest, urlSession: URLSessionProtocol, requestBuilder: RequestBuilder<T>, data: Data?, response: URLResponse?, error: Error, completion: @escaping (OpenAPIInterceptorRetry) -> Void) {
        completion(.dontRetry)
    }
}
