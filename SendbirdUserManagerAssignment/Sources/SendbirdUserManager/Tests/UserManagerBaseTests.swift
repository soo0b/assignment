//
//  UserManagerBaseTests.swift
//  SendbirdUserManager
//
//  Created by Sendbird
//

import Foundation
import XCTest

/// Unit Testing을 위해 제공되는 base test suite입니다.
/// 사용을 위해서는 해당 클래스를 상속받고,
/// `open func userManager() -> SBUserManager?`를 override한뒤, 본인이 구현한 SBUserManager의 인스턴스를 반환하도록 합니다.
open class UserManagerBaseTests: XCTestCase {
    open func userManager() -> SBUserManager? { nil }
    
    public let applicationId = "3EAE307E-D0C9-4F8E-9069-22DE03825639"   // Note: add an application ID
    public let apiToken = "bd7f8130982171c8fc5f88caf800c1a5cba8fd90"        // Note: add an API Token
    
    public func testInitApplicationWithDifferentAppIdClearsData() throws {
        let userManager = try XCTUnwrap(self.userManager())
        
        // First init
        userManager.initApplication(applicationId: "AppID1", apiToken: "Token1")    // Note: Add the first application ID and API Token
        
        let userId = UUID().uuidString
        let initialUser = UserCreationParams(userId: userId, nickname: "hello", profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        // 서버 성공인 경우, 스토리지 저장을 하는 스펙이라고 이해했습니다
        // 앱 아이디가 틀린경우, 유저 생성이 실패해서 로컬 스토리지 저장으로 변경하겠습니다
        //userManager.createUser(params: initialUser) { _ in }
        userManager.userStorage.upsertUser(SBUser(userId: initialUser.userId, nickname: initialUser.nickname, profileURL: initialUser.profileURL))
        
        // Check if the data exist
        let users = userManager.userStorage.getUsers()
        XCTAssertEqual(users.count, 1, "User should exist with an initial Application ID")
        
        // Second init with a different App ID
        userManager.initApplication(applicationId: "AppID2", apiToken: "Token2")    // Note: Add the second application ID and API Token
        
        // Check if the data is cleared
        let clearedUsers = userManager.userStorage.getUsers()
        XCTAssertEqual(clearedUsers.count, 0, "Data should be cleared after initializing with a different Application ID")
    }
    
    public func testCreateUser() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let userId = UUID().uuidString
        let userNickname = UUID().uuidString
        let params = UserCreationParams(userId: userId, nickname: userNickname, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        let expectation = self.expectation(description: "Wait for user creation")
        
        userManager.createUser(params: params) { result in
            switch result {
            case .success(let user):
                XCTAssertNotNil(user)
                XCTAssertEqual(user.nickname, userNickname)
            case .failure(let error):
                XCTFail("Failed with error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    public func testCreateUsers() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let userId1 = UUID().uuidString
        let userNickname1 = UUID().uuidString
        
        let userId2 = UUID().uuidString
        let userNickname2 = UUID().uuidString
        
        let params1 = UserCreationParams(userId: userId1, nickname: userNickname1, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        let params2 = UserCreationParams(userId: userId2, nickname: userNickname2, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        
        let expectation = self.expectation(description: "Wait for users creation")
        
        userManager.createUsers(params: [params1, params2]) { result in
            switch result {
            case .success(let users):
                XCTAssertEqual(users.count, 2)
                XCTAssertEqual(users[0].nickname, userNickname1)
                XCTAssertEqual(users[1].nickname, userNickname2)
            case .failure(let error):
                XCTFail("Failed with error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    public func testUpdateUser() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let userId = UUID().uuidString
        let initialUserNickname = UUID().uuidString
        let updatedUserNickname = UUID().uuidString
        
        let initialParams = UserCreationParams(userId: userId, nickname: initialUserNickname, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        let updatedParams = UserUpdateParams(userId: userId, nickname: updatedUserNickname, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        
        let expectation = self.expectation(description: "Wait for user update")
        
        userManager.createUser(params: initialParams) { creationResult in
            switch creationResult {
            case .success(_):
                userManager.updateUser(params: updatedParams) { updateResult in
                    switch updateResult {
                    case .success(let updatedUser):
                        XCTAssertEqual(updatedUser.nickname, updatedUserNickname)
                    case .failure(let error):
                        XCTFail("Failed with error: \(error)")
                    }
                    expectation.fulfill()
                }
            case .failure(let error):
                XCTFail("Failed with error: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    public func testGetUser() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let userId = UUID().uuidString
        let userNickname = UUID().uuidString
        
        let params = UserCreationParams(userId: userId, nickname: userNickname, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        
        let expectation = self.expectation(description: "Wait for user retrieval")
        
        userManager.createUser(params: params) { creationResult in
            switch creationResult {
            case .success(let createdUser):
                userManager.getUser(userId: createdUser.userId) { getResult in
                    switch getResult {
                    case .success(let retrievedUser):
                        XCTAssertEqual(retrievedUser.nickname, userNickname)
                    case .failure(let error):
                        XCTFail("Failed with error: \(error)")
                    }
                    expectation.fulfill()
                }
            case .failure(let error):
                XCTFail("Failed with error: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    public func testGetUsersWithNicknameFilter() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let userId1 = UUID().uuidString
        let userNickname1 = UUID().uuidString
        
        let userId2 = UUID().uuidString
        let userNickname2 = UUID().uuidString
        
        let params1 = UserCreationParams(userId: userId1, nickname: userNickname1, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        let params2 = UserCreationParams(userId: userId2, nickname: userNickname2, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        
        let expectation = self.expectation(description: "Wait for users retrieval with nickname filter")
        
        userManager.createUsers(params: [params1, params2]) { creationResult in
            switch creationResult {
            case .success(_):
                userManager.getUsers(nicknameMatches: userNickname1) { getResult in
                    switch getResult {
                    case .success(let users):
                        XCTAssertEqual(users.count, 1)
                        XCTAssertEqual(users[0].nickname, userNickname1)
                    case .failure(let error):
                        XCTFail("Failed with error: \(error)")
                    }
                    expectation.fulfill()
                }
            case .failure(let error):
                XCTFail("Failed with error: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // Test that trying to create more than 10 users at once should fail
    public func testCreateUsersLimit() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let users = (0..<11).map { UserCreationParams(userId: "user_id_\(UUID().uuidString)\($0)", nickname: "nickname_\(UUID().uuidString)\($0)", profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6") }
        
        let expectation = self.expectation(description: "Wait for users creation with limit")
        
        userManager.createUsers(params: users) { result in
            switch result {
            case .success(_):
                XCTFail("Shouldn't successfully create more than 10 users at once")
            case .failure(let error):
                // Ideally, check for a specific error related to the limit
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // Test race condition when simultaneously trying to update and fetch a user
    public func testUpdateUserRaceCondition() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let userId = UUID().uuidString
        let initialUserNickname = UUID().uuidString
        let updatedUserNickname = UUID().uuidString
        
        let initialParams = UserCreationParams(userId: userId, nickname: initialUserNickname, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        let updatedParams = UserUpdateParams(userId: userId, nickname: updatedUserNickname, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
        
        let expectation1 = self.expectation(description: "Wait for user update")
        let expectation2 = self.expectation(description: "Wait for user retrieval")
        
        userManager.createUser(params: initialParams) { creationResult in
            guard let createdUser = try? creationResult.get() else {
                XCTFail("Failed to create user")
                return
            }
            
            DispatchQueue.global().async {
                userManager.updateUser(params: updatedParams) { _ in
                    expectation1.fulfill()
                }
            }
            
            DispatchQueue.global().async {
                userManager.getUser(userId: createdUser.userId) { getResult in
                    if case .success(let user) = getResult {
                        XCTAssertTrue(user.nickname == initialUserNickname || user.nickname == updatedUserNickname)
                    } else {
                        XCTFail("Failed to retrieve user")
                    }
                    expectation2.fulfill()
                }
            }
        }
        
        wait(for: [expectation1, expectation2], timeout: 10.0)
    }
    
    // Test for edge cases where the nickname to be matched is either empty or consists of spaces
    public func testGetUsersWithEmptyNickname() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        let expectation = self.expectation(description: "Wait for users retrieval with empty nickname filter")
        
        userManager.getUsers(nicknameMatches: "") { result in
            if case .failure(let error) = result {
                // Ideally, check for a specific error related to the invalid nickname
                XCTAssertNotNil(error)
            } else {
                XCTFail("Fetching users with empty nickname should not succeed")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    public func testRateLimitCreateUser() throws {
        let userManager = try XCTUnwrap(self.userManager())
        userManager.initApplication(applicationId: applicationId, apiToken: apiToken)
        
        // Concurrently create 11 users
        let dispatchGroup = DispatchGroup()
        var results: [UserResult] = []
        let syncQueue = DispatchQueue(label: "com.example.syncQueue")
        
        let startTime = Date()
        
        for _ in 0..<11 {
            dispatchGroup.enter()
            let params = UserCreationParams(userId: UUID().uuidString, nickname: UUID().uuidString, profileURL: "https://images.app.goo.gl/CLb6eteCBcZ7WHoQ6")
            userManager.createUser(params: params) { result in
                syncQueue.async {
                    results.append(result)
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.wait()
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        XCTAssertGreaterThanOrEqual(totalTime, 11, "총 처리 시간은 최소 11초 이상이어야 합니다.")
        
        // Assess the results
        let successResults = results.filter {
            if case .success = $0 { return true }
            return false
        }
        let rateLimitResults = results.filter {
            if case .failure(_) = $0 { return true }
            return false
        }
        
        /**
         예를 들면 createUsers() request로 5개의 UserCreationParams list가 넘어왔다면 1초에 1개의 UserCreationParams를 user creation API 요청을 주어, 총 5번의 요청을 1초 간격으로 요청해야 합니다. 이때 총 소요시간은 5초 (performance에 따라 그 이상) 걸려야 합니다.
           
          인터페이스에 따라 테스트 케이스는 11초 이상 걸리고, 모두 성공했는지 확인해야 할 것 같습니다
         */
        //XCTAssertEqual(successResults.count, 10)
        //XCTAssertEqual(rateLimitResults.count, 1)
        
        // 성공한 결과는 11개여야 하고, 레이트 리미트로 인한 실패는 없어야 함
        XCTAssertEqual(successResults.count, 11)
        XCTAssertEqual(rateLimitResults.count, 0)
    }
}
