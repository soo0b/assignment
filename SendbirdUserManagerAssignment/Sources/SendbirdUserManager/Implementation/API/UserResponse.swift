//
//

import Foundation

struct UserResponse: Decodable, Sendable {
    let userId: String
    let nickname: String
    let profileURL: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname = "nickname"
        case profileURL = "profile_url"
    }
    
    func toSBUser() -> SBUser {
        return SBUser(userId: userId, nickname: nickname, profileURL: profileURL)
    }
}

struct UserListResponse: Decodable, Sendable {
    let users: [UserResponse]
}
