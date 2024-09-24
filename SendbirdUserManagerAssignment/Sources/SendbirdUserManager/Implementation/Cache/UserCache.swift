//

import Foundation

final class CacheModel: @unchecked Sendable {
    private var cachedUsers: [String: SBUser] = [:]
    private var userOrder: [String] = []
    private var appId: String?
    private var apiToken: String?
    
    private let queue = DispatchQueue(label: "com.CacheModel", attributes: .concurrent)
    
    func addUser(_ user: SBUser) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            
            self.cachedUsers[user.userId] = user
            
            if let index = self.userOrder.firstIndex(of: user.userId) {
                self.userOrder.remove(at: index)
            }
            self.userOrder.insert(user.userId, at: 0)
        }
    }
    
    func getUsers() -> [SBUser] {
        queue.sync { [weak self] in
            guard let self else { return [] }
            return self.userOrder.compactMap { self.cachedUsers[$0] }
        }
    }
    
    func getUsers(for nickname: String) -> [SBUser] {
        queue.sync { [weak self] in
            guard let self else { return [] }
            
            return self.userOrder
                .compactMap { self.cachedUsers[$0] }
                .filter { $0.nickname == nickname }
        }
    }
    
    func getUser(for userId: String) -> SBUser? {
        queue.sync { [weak self] in
            guard let self else { return nil}
            return self.cachedUsers[userId]
        }
    }
    
    func setInfo(_ appId: String? = nil, token: String? = nil) {
        queue.sync { [weak self] in
            guard let self else { return }
            
            self.appId = appId
            self.apiToken = token
        }
    }
    
    func getInfo() -> (appId: String?, apiToken: String?) {
        queue.sync { [weak self] in
            guard let self else { return (nil, nil) }
            return (self.appId, self.apiToken)
        }
    }
    
    func resetUsers() {
        queue.sync { [weak self] in
            guard let self else { return }
            
            self.cachedUsers.removeAll()
            self.userOrder.removeAll()
            appId = nil
            apiToken = nil
        }
    }
}

struct UserCache: SBUserStorage, Sendable {
    static let shared = UserCache()
    
    private let model = CacheModel()
    
    private init() {}
    
    func upsertUser(_ user: SBUser) {
        model.addUser(user)
    }
    
    func getUsers() -> [SBUser] {
        return model.getUsers()
    }
    
    func getUsers(for nickname: String) -> [SBUser] {
        return model.getUsers(for: nickname)
    }
    
    func getUser(for userId: String) -> SBUser? {
        return model.getUser(for: userId)
    }
    
    func setInfo(_ appId: String? = nil, token: String? = nil) {
        model.setInfo(appId, token: token)
    }
    
    func getInfo() -> (appId: String?, apiToken: String?) {
        return model.getInfo()
    }
    
    func resetUsers() {
        model.resetUsers()
    }
}
