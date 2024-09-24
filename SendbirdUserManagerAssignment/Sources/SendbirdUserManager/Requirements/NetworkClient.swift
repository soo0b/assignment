//
//  NetworkClient.swift
//  
//
//  Created by Sendbird
//

import Foundation

public protocol Request: Sendable where Response: Decodable {
    associatedtype Response
    var urlRequest: URLRequest { get }
}

public protocol SBNetworkClient {
    /// 리퀘스트를 요청하고 리퀘스트에 대한 응답을 받아서 전달합니다
    func request<R: Request>(
        request: R,
        completionHandler: @Sendable @escaping (Result<R.Response, Error>) -> Void
    )
}
