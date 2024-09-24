//
//

import Foundation

public final class UserAPIManager: SBUserManager, Sendable {
    
    public var networkClient: SBNetworkClient {
        return NetworkAPIClient.shared
    }
    
    public var userStorage: SBUserStorage {
        return UserCache.shared
    }
    
    public func initApplication(applicationId: String, apiToken: String) {
        let info = UserCache.shared.getInfo()

        if info.appId != applicationId || info.apiToken != apiToken {
            UserCache.shared.resetUsers()
        }
        
        UserCache.shared.setInfo(applicationId, token: apiToken)
    }
    
    public func createUser(params: UserCreationParams, completionHandler: (@Sendable (UserResult) -> Void)?) {
        let createUserAPI = UserCreateAPI(params: params)
        
        networkClient.request(request: createUserAPI) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let userResponse):
                let sbUser = userResponse.toSBUser()
                self.userStorage.upsertUser(sbUser)
                completionHandler?(.success(sbUser))
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
    public func createUsers(params: [UserCreationParams], completionHandler: ((UsersResult) -> Void)?) {
        guard params.count <= 10 else {
            completionHandler?(.failure(NetworkError.invalidRequest))
            return
        }
        
        var results: [Result<SBUser, Error>?] = Array(repeating: nil, count: params.count)
        let syncQueue = DispatchQueue(label: "com.userCreationSyncQueue")
        let dispatchGroup = DispatchGroup()
        
        for (index, param) in params.enumerated() {
            dispatchGroup.enter()
            let createUserAPI = UserCreateAPI(params: param)
            
            // 네트워크 요청 바로 실행 (request에서 1초 버퍼가 걸려있음)
            networkClient.request(request: createUserAPI) { [weak self] result in
                guard let self = self else {
                    dispatchGroup.leave()
                    return
                }
                
                switch result {
                case .success(let userResponse):
                    let sbUser = userResponse.toSBUser()
                    self.userStorage.upsertUser(sbUser)
                    syncQueue.sync {
                        results[index] = .success(sbUser)
                    }
                case .failure(let error):
                    syncQueue.sync {
                        results[index] = .failure(error)
                    }
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let successUsers = results.compactMap { result -> SBUser? in
                if case .success(let user) = result {
                    return user
                }
                return nil
            }
            
            let errors = results.compactMap { result -> Error? in
                if case .failure(let error) = result {
                    return error
                }
                return nil
            }
            
            if errors.isEmpty {
                completionHandler?(.success(successUsers))
            } else {
                completionHandler?(.failure(NetworkError.partialSuccess(successUsers: successUsers,
                                                                        failedUsers: errors)))
            }
        }
    }
    
    public func updateUser(params: UserUpdateParams, completionHandler: ((UserResult) -> Void)?) {
        let updateUserAPI = UserUpdateAPI(params: params)
        
        networkClient.request(request: updateUserAPI) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let userResponse):
                let sbUser = userResponse.toSBUser()
                self.userStorage.upsertUser(sbUser)
                completionHandler?(.success(sbUser))
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
    public func getUser(userId: String, completionHandler: ((UserResult) -> Void)?) {
        if let user = userStorage.getUser(for: userId) {
            completionHandler?(.success(user))
            return
        }
        
        let readUserAPI = UserReadAPI(params: UserCreationParams(userId: userId, nickname: nil, profileURL: nil))
        
        networkClient.request(request: readUserAPI) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let userResponse):
                if let sbUser = userResponse.users.first?.toSBUser() {
                    self.userStorage.upsertUser(sbUser)
                    completionHandler?(.success(sbUser))
                } else {
                    completionHandler?(.failure(NetworkError.invalidResponse))
                }
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
    public func getUsers(nicknameMatches: String, completionHandler: ((UsersResult) -> Void)?) {
        guard nicknameMatches.isEmpty == false else {
            completionHandler?(.failure(NetworkError.invalidRequest))
            return
        }
        let users = userStorage.getUsers(for: nicknameMatches)
        if users.count > 0 {
            completionHandler?(.success(users))
            return
        }
        
        let readUserAPI = UserReadAPI(params: UserCreationParams(userId: "", nickname: nicknameMatches, profileURL: nil))
        var usersResult: [SBUser] = []
        let syncQueue = DispatchQueue(label: "com.userCreationSyncQueue")
        
        networkClient.request(request: readUserAPI) { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let userResponses):
                for userResponse in userResponses.users {
                    let sbUser = userResponse.toSBUser()
                    self.userStorage.upsertUser(sbUser)
                    syncQueue.sync {
                        usersResult.append(sbUser)
                    }
                }
                syncQueue.async {
                    completionHandler?(.success(usersResult))
                }
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
}
