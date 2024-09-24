//
//

import Foundation

protocol UserAPI: Request, Sendable {}

extension UserAPI {
    static func request<T: Encodable>(with urlString: String, httpMethod: String, params: T? = (nil as Optional<EmptyParams>)) -> URLRequest {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("bd7f8130982171c8fc5f88caf800c1a5cba8fd90", forHTTPHeaderField: "Api-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let params {
            do {
                request.httpBody = try JSONEncoder().encode(params)
            } catch {
                fatalError("Failed to serialize JSON: \(error)")
            }
        }
        
        return request
    }
}

struct UserCreateAPI: UserAPI, Sendable {
    typealias Response = UserResponse
    let params: UserCreationParams
    
    var urlRequest: URLRequest {
        return Self.request(
            with: "\(NetworkConfig.baseURL)/users",
            httpMethod: "POST",
            params: params
        )
    }
}

struct UserReadAPI: UserAPI, Sendable {
    typealias Response = UserListResponse
    let params: UserCreationParams
    
    var urlRequest: URLRequest {
        var urlString = "\(NetworkConfig.baseURL)/users"
        var path = ""
        
        if params.userId.count > 0 {
            path.append("user_ids=\(params.userId)")
        }
        
        if let nickname = params.nickname, !nickname.isEmpty {
            if !path.isEmpty {
                path.append("&")
            }
            path.append("nickname=\(nickname)")
        }
        
        if !path.isEmpty {
            urlString.append("?\(path)")
        }
        
        return Self.request(
            with: urlString,
            httpMethod: "GET"
        )
    }
}

struct UserUpdateAPI: UserAPI, Sendable {
    typealias Response = UserResponse
    let params: UserUpdateParams
    
    var urlRequest: URLRequest {
        return Self.request(
            with: "\(NetworkConfig.baseURL)/users/\(params.userId)",
            httpMethod: "PUT",
            params: params
        )
    }
}
