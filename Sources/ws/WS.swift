//
//  WS.swift
//  ws
//
//  Created by Sacha Durand Saint Omer on 13/11/15.
//  Copyright © 2015 s4cha. All rights reserved.
//

import Alamofire
import Arrow
import Foundation
import Combine

public typealias WSCall<T> = AnyPublisher<T, Error>

open class WS {
    
    /**
        Instead of using the same keypath for every call eg: "collection",
        this enables to use a default keypath for parsing collections.
        This is overidden by the per-request keypath if present.
     
     */
    open var defaultCollectionParsingKeyPath: String?
    
    @available(*, unavailable, renamed:"defaultCollectionParsingKeyPath")
    open var jsonParsingColletionKey: String?
    
    /**
        Prints network calls to the console. 
        Values Available are .None, Calls and CallsAndResponses.
        Default is None
    */
    open var logLevels = WSLogLevel.off
    open var postParameterEncoding: ParameterEncoding = URLEncoding()
    
    /**
        Displays network activity indicator at the top left hand corner of the iPhone's screen in the status bar.
        Is shown by dafeult, set it to false to hide it.
     */
    open var showsNetworkActivityIndicator = true
    
    /**
     Custom error handler block, to parse error returned in response body.
     For example: `{ error: { code: 1, message: "Server error" } }`
     */
    open var errorHandler: ((JSON) -> Error?)?
    
    open var baseURL = ""
    open var headers = [String: String]()
    open var requestAdapter: RequestAdapter?
    open var requestRetrier: RequestRetrier?

    /**
     Create a webservice instance.
     @param Pass the base url of your webservice, E.g : "http://jsonplaceholder.typicode.com"
     
     */
    public init(_ aBaseURL: String) {
        baseURL = aBaseURL
    }
    
    // MARK: - Calls
    
    internal func call(_ url: String, verb: WSHTTPVerb = .get, params: Params = Params()) -> WSRequest {
        let c = defaultCall()
        c.httpVerb = verb
        c.URL = url
        c.params = params
        return c
    }
    
    open func defaultCall() -> WSRequest {
        let r = WSRequest()
        r.baseURL = baseURL
        r.logLevels = logLevels
        r.postParameterEncoding = postParameterEncoding
        r.showsNetworkActivityIndicator = showsNetworkActivityIndicator
        r.headers = headers
        r.requestAdapter = requestAdapter
        r.requestRetrier = requestRetrier
        r.errorHandler = errorHandler
        return r
    }
    
    // MARK: JSON calls
    
    open func get(_ url: String, params: Params = Params()) -> WSCall<JSON> {
        return getRequest(url, params: params).fetch().receiveOnMainThread()
    }
    
    open func post(_ url: String, params: Params = Params()) -> WSCall<JSON> {
        return postRequest(url, params: params).fetch().receiveOnMainThread()
    }
    
    open func put(_ url: String, params: Params = Params()) -> WSCall<JSON> {
        return putRequest(url, params: params).fetch().receiveOnMainThread()
    }
    
    open func delete(_ url: String, params: Params = Params()) -> WSCall<JSON> {
        return deleteRequest(url, params: params).fetch().receiveOnMainThread()
    }
    
    // MARK: Void calls
    
    open func get(_ url: String, params: Params = Params()) -> WSCall<Void> {
        let r = getRequest(url, params: params)
        r.returnsJSON = false
        return r.fetch().toVoid().receiveOnMainThread()
    }
    
    open func post(_ url: String, params: Params = Params()) -> WSCall<Void> {
        let r = postRequest(url, params: params)
        r.returnsJSON = false
        return r.fetch().toVoid().receiveOnMainThread()
    }
    
    open func put(_ url: String, params: Params = Params()) -> WSCall<Void> {
        let r = putRequest(url, params: params)
        r.returnsJSON = false
        return r.fetch().toVoid().receiveOnMainThread()
    }
    
    open func delete(_ url: String, params: Params = Params()) -> WSCall<Void> {
        let r = deleteRequest(url, params: params)
        r.returnsJSON = false
        return r.fetch().toVoid().receiveOnMainThread()
    }
    
    // MARK: - Multipart
    
    open func postMultipart(_ url: String,
                            params: Params = Params(),
                            name: String,
                            data: Data,
                            fileName: String,
                            mimeType: String) -> WSCall<JSON> {
        let r = postMultipartRequest(url,
                                     params: params,
                                     name: name,
                                     data: data,
                                     fileName: fileName,
                                     mimeType: mimeType)
        return r.fetch().receiveOnMainThread()
    }
    
    open func putMultipart(_ url: String,
                           params: Params = Params(),
                           name: String,
                           data: Data,
                           fileName: String,
                           mimeType: String) -> WSCall<JSON> {
        let r = putMultipartRequest(url, params: params, name: name, data: data, fileName: fileName, mimeType: mimeType)
        return r.fetch().receiveOnMainThread()
    }
    
}

public extension Publisher where Output == JSON, Failure == Error {
        
    func toVoid() -> AnyPublisher<Void, Error> {
        return self.map { _ in }.eraseToAnyPublisher()
    }
}

public extension Publisher where Failure == Error {

    func receiveOnMainThread() -> AnyPublisher<Output, Error> {
        return self.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
}


extension Publisher {
    
    @discardableResult
    func then(_ closure: @escaping (Output) -> Void) -> Self {
        var cancellable: AnyCancellable?
        cancellable = self.sink(receiveCompletion: { completion in
            cancellable = nil
        }) { value in
            closure(value)
        }
        return self
    }
    
    @discardableResult
    func onError(_ closure: @escaping (Failure) -> Void) -> Self {
//        self.catch { (e:Failure) -> AnyPublisher<Output, Failure> in
//            closure(e)
//            return self
//        }
        return self
    }
        
    @discardableResult
    func finally(_ closure: @escaping () -> Void) -> Self {
        return then { value in
            closure()
        }
    }
}

var cancellable: AnyCancellable?
