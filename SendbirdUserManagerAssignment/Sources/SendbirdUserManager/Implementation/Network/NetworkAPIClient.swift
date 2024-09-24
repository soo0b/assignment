//
//
//

import Foundation

@globalActor
actor APIActor: GlobalActor {
    static let shared = APIActor()
}

enum NetworkError: Error {
    case invalidRequest
    case invalidResponse
    case unknownError
    case partialSuccess(successUsers: [SBUser], failedUsers: [Error])
}

final private class NetworkAPIModel: @unchecked Sendable {
    @APIActor var requestStream: AsyncStream<(AnyRequest, @Sendable (Result<Any, Error>) -> Void)>?
    @APIActor var requestStreamContinuation: AsyncStream<(AnyRequest, @Sendable (Result<Any, Error>) -> Void)>.Continuation?
    @APIActor var lastRequestTime: Date = .distantPast
    
    init() {
        Task { @APIActor [weak self] in
            guard let self = self else { return }
            
            let (stream, continuation) = AsyncStream<(AnyRequest, @Sendable (Result<Any, Error>) -> Void)>.makeStream()
            self.requestStream = stream
            self.requestStreamContinuation = continuation
        }
    }
}

public final class NetworkAPIClient: SBNetworkClient, Sendable {
    public static let shared = NetworkAPIClient()
    
    @APIActor private var model = NetworkAPIModel()
    
    private init() {
        Task { @APIActor [weak self] in
            guard let self = self else { return }
            await self.startProcessing()
        }
    }
    
    public func request<R: Request>(
        request: R,
        completionHandler: @Sendable @escaping (Result<R.Response, Error>) -> Void
    ) {
        let anyRequest = AnyRequest(request)
        let completionHandlerCopy = completionHandler
        
        let anyCompletionHandler: @Sendable (Result<Any, Error>) -> Void = { result in
            switch result {
            case .success(let response):
                if let typedResponse = response as? R.Response {
                    completionHandlerCopy(.success(typedResponse))
                } else {
                    completionHandlerCopy(.failure(NetworkError.invalidResponse))
                }
            case .failure(let error):
                completionHandlerCopy(.failure(error))
            }
        }
        
        Task { @APIActor [weak self] in
            guard let self = self else { return }
            self.model.requestStreamContinuation?.yield((anyRequest, anyCompletionHandler))
        }
    }
    
    @APIActor
    private func startProcessing() async {
        guard let requestStream = model.requestStream else { return }
        
        for await (request, completionHandler) in requestStream {
            await enforceRateLimit()
            await processRequest(request: request, completionHandler: completionHandler)
            model.lastRequestTime = Date() // 요청 처리 후 시간 업데이트
        }
    }
    
    private func processRequest(
        request: AnyRequest,
        completionHandler: @escaping (Result<Any, Error>) -> Void
    ) async {
        do {
            let (data, _) = try await URLSession.shared.data(for: request.urlRequest)
            let response = try request.decodeResponse(data: data)
            completionHandler(.success(response))
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    @APIActor
    private func enforceRateLimit() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(model.lastRequestTime)
        
        if timeSinceLastRequest < 1 {
            let waitTime = 1 - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
    }
}

private struct AnyRequest: Sendable {
    let urlRequest: URLRequest
    private let decode: (Data) throws -> Any
    
    init<R: Request>(_ request: R) {
        self.urlRequest = request.urlRequest
        self.decode = { data in
            let decodedResponse = try JSONDecoder().decode(R.Response.self, from: data)
            return decodedResponse
        }
    }
    
    func decodeResponse(data: Data) throws -> Any {
        return try decode(data)
    }
}
