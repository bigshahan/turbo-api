//
//  Users.swift
//  TurboApi
//
//  Created by Shahan Khan on 9/21/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import Foundation

struct SimpleUserModel {
	var id = ""
	var firstName = ""
	var lastName = ""
	var username = ""
	var avatarUrl: String?
	
	init() {
	}
	
	func getUserModel(success: ((UserModel)->())?, error: ((APIError)->())?) {
		User.getById(id, success: success, error: error)
	}
	
	static func serialize(model: SimpleUserModel) -> Dictionary<String, AnyObject> {
		var dictionary: Dictionary<String, AnyObject> = [
			"_id" : model.id as AnyObject,
			"firstName" : model.firstName as AnyObject,
			"lastName" : model.lastName as AnyObject,
			"username" : model.username as AnyObject]
		
		if let avatarUrl = model.avatarUrl {
			dictionary["avatarUrl"] = avatarUrl as AnyObject
		}
		
		return dictionary
	}
	
	static func serializeArray(models: [SimpleUserModel]) -> [Dictionary<String, AnyObject>] {
		var array: [Dictionary<String, AnyObject>] = []
		for model in models {
			array.append(SimpleUserModel.serialize(model))
		}
		
		return array
	}
	
	static func unserialize(dictionary: Dictionary<String, AnyObject>) -> SimpleUserModel {
		var model = SimpleUserModel()
		
		if let value = ((dictionary["_id"] as AnyObject?) as? String) {
			model.id = value
		}
		
		if let value = ((dictionary["username"] as AnyObject?) as? String) {
			model.username = value
		}
		
		if let value = ((dictionary["avatarUrl"] as AnyObject?) as? String) {
			model.avatarUrl = value
		}
		
		if let value = ((dictionary["firstName"] as AnyObject?) as? String) {
			model.firstName = value
		}
		
		if let value = ((dictionary["lastName"] as AnyObject?) as? String) {
			model.lastName = value
		}
		
		return model
	}
	
	static func unserializeArray(array: [Dictionary<String, AnyObject>]) -> [SimpleUserModel] {
		var models: [SimpleUserModel] = []
		
		for dictionary in array {
			models.append(unserialize(dictionary))
		}
		
		return models
	}
	
	static func arrayContainsUser(models: [SimpleUserModel], user: SimpleUserModel) -> Bool {
		// Checks an array of SimpleUserModels for a given user
		for model in models {
			if model.id == user.id {
				return true
			}
		}
		return false
	}
	
	static func arrayWithRemovedUser(models: [SimpleUserModel], removeUser: SimpleUserModel) -> [SimpleUserModel] {
		
		var array: [SimpleUserModel] = []
		array = models
		
		for (index, model) in enumerate(array) {
			
			if model.id == removeUser.id {
				array.removeAtIndex(index)
			}
		}
		return array
	}
	
	static func indexOfUserInArray(models: [SimpleUserModel], user: SimpleUserModel) -> Int? {
		
		var modelsCopy: [SimpleUserModel] = []
		modelsCopy = models
		
		for (index, model) in enumerate(modelsCopy) {
			
			if model.id == user.id {
				return index
			}
		}
		return nil
	}
	
}

class UserModel {
	var id = ""
	var firstName = ""
	var lastName = ""
	var username = ""
	var password: String?
	var email = ""
	var phone = ""
	var facebookId: String?
	var facebookToken: String?
	var avatarUrl: String?
	var coverUrl: String?
	
	init() {
	}
	
	// converts the UserModel into SimpleUserModel
	func toSimpleUser() -> SimpleUserModel {
		
		var simpleUser = SimpleUserModel()
		
		simpleUser.id = id
		simpleUser.firstName = firstName
		simpleUser.lastName = lastName
		simpleUser.username = username
		simpleUser.avatarUrl = avatarUrl
		
		return simpleUser
	}
	
	// make the current user in user follow this user
	func follow(success: (()->())?, error: ((APIError)->())?) {
		
		API.postArrayString("/users/\(id)/follow", parameters: nil, success: {
			(array) in
			success?()
			return
		}, error: error)
		
		Analytics.track("Followed a user")
	}
	
	// make the current user unfollow this user
	func unfollow(success: (()->())?, error: ((APIError)->())?) {
		API.delete("/users/\(id)/unfollow", success: {
			(array) in
			success?()
			return
		}, error: error)
		
		Analytics.track("Unfollowed a user")
	}
	
	func save(success: (()->())?, error: ((APIError)->())?) {
		// if user already exists
		if id != "" {
			API.put("/users/\(id)", parameters: serialize(), success: {
				(dictionary) in
				success?()
				return
			}, error: error)
			return
		}
		
		// if new users, use POST
		API.post("/users", parameters: serialize(), success: {
			(dictionary) in
			let model = User.unserialize(dictionary)
			self.id = model.id
			success?()
		}, error: error)
		
		Analytics.track("Created an account")
	}
	
	func serialize() -> Dictionary<String, AnyObject> {
		return User.serialize(self)
	}
	
	func isFollowing(userId: String) -> Bool {
		return contains(following, userId) ? true : false
	}
	
	func getFacebookCover(success:(()->())?, error: ((APIError)->())?) {
		let manager = API.manager()
		
		if facebookId != nil {
			
			let fbCoverUrl = "http://graph.facebook.com/" + facebookId! + "?fields=cover"
			manager.GET(fbCoverUrl, parameters: nil, success: {
				(operation, data) in
				
				let dict = data as Dictionary<String, AnyObject>
				
				if let coverDict = ((dict["cover"] as AnyObject?) as? Dictionary<String, AnyObject>) {
					if let value = ((coverDict["source"] as AnyObject?) as? String) {
						self.coverUrl = value
					}
				}
				
				success?()
				
				return
				}, failure: {
					(task, err) in
					API.handleError(task, error: err, callback: error)
					return
			})
		}
	}
}

class User {
	class func savePushToken(token: String) {
		if let userId = currentUserId() {
			if let authToken = NSUserDefaults.standardUserDefaults().stringForKey("authToken") {
				API.put("/users/\(userId)/devices/\(authToken)", parameters: ["pushToken": token], nil, nil)
			}
		}
	}
	
	class func loggedIn() -> Bool {
		let userId = NSUserDefaults.standardUserDefaults().stringForKey("userId")
		let authToken = NSUserDefaults.standardUserDefaults().stringForKey("authToken")
		
		if userId == nil || authToken == nil {
			return false
		}
		
		return true
	}
	
	class func login(username: String, password: String, success: (()->())?, error: ((APIError)->())?) {
		// TODO: Login - device uuid
		let params: [String: AnyObject] = ["username": username, "password": password, "type": "ios", "uuid": "unknown"]
		
		API.post("/login", parameters: params, success: {
			(dictionary) in
			
			// get userId and authToken from json dictionary
			let userId = (dictionary["id"] as AnyObject?) as? String
			let authToken = (dictionary["authToken"] as AnyObject?) as? String
			
			// save login info
			NSUserDefaults.standardUserDefaults().setObject(userId!, forKey: "userId")
			NSUserDefaults.standardUserDefaults().setObject(authToken!, forKey: "authToken")
			NSUserDefaults.standardUserDefaults().synchronize()
			
			// Reupdate analytics
			Analytics.setup()
			Analytics.track("Logged in", properties: ["type": "email"])
			
			success?()
			return
			}, error: error)
	}
	
	class func loginFacebook(id: String, token: String, success: (()->())?, error: ((APIError)->())?) {
		// TODO: Login - device uuid
		let params: [String: AnyObject] = ["facebookId": id, "facebookToken": token, "type": "ios", "uuid": "unknown"]
		
		API.post("/login", parameters: params, success: {
			(dictionary) in
			// get userId and authToken from json dictionary
			let userId = (dictionary["id"] as AnyObject?) as? String
			let authToken = (dictionary["authToken"] as AnyObject?) as? String
			
			if userId == nil || authToken == nil {
				NSLog("Did not fetch correct authentication tokens.")
				error?(APIError.ServerError)
				return
			}
			
			// save login info
			NSUserDefaults.standardUserDefaults().setObject(userId!, forKey: "userId")
			NSUserDefaults.standardUserDefaults().setObject(authToken!, forKey: "authToken")
			NSUserDefaults.standardUserDefaults().synchronize()
			
			// Reupdate analytics
			Analytics.setup()
			Analytics.track("Logged in", properties: ["type": "facebook"])
			
			success?()
			return
			}, error: error)
	}
	
	class func logout() {
		// TODO: delete token from server
		
		
		// clear token from device
		Analytics.track("Logged out")
		NSUserDefaults.standardUserDefaults().removeObjectForKey("userId")
		NSUserDefaults.standardUserDefaults().removeObjectForKey("authToken")
		
		// Reupdate analytics
		Analytics.setup()
		
		// TODO: clear facebook token
	}
	
	class func currentUser(success: ((UserModel)->())? = nil, error: ((APIError)->())? = nil) {
		let userId = NSUserDefaults.standardUserDefaults().stringForKey("userId")
		
		if userId == nil {
			error?(.NotAuthenticated)
			return
		}
		
		getById(userId!, success, error)
	}
	
	class func currentUserId() -> String? {
		return NSUserDefaults.standardUserDefaults().stringForKey("userId")
	}
	
	// get current user's facebook friends (that are Linx users)
	class func getFacebookFriends(success: (([SimpleUserModel])->())?, error: ((APIError)->())?) {
		if let userId = currentUserId() {
			API.getArray("/users/\(userId)/facebookFriends", success: {
				(array) in
				success?(SimpleUserModel.unserializeArray(array))
				return
				}, error: error)
		} else {
			error?(.NotAuthenticated)
		}
		
		Analytics.track("Viewed Facebook Friends on Linx")
	}
	
	class func getFriendsFromContacts(phoneNumbers: [String], success: (([SimpleUserModel])->())?, error: ((APIError)->())?) {
		if let userId = currentUserId() {
			let params: [String: AnyObject] = ["phoneNumbers": phoneNumbers as AnyObject]
			API.postArray("/users/\(userId)/findFriendsFromContacts", parameters: params, success: {
				(array) in
				success?(SimpleUserModel.unserializeArray(array))
				return
				}, error: error)
		} else {
			error?(.NotAuthenticated)
		}
		
		Analytics.track("Viewed friends from contacts")
	}
	
	class func getById(userId: String, success: ((UserModel)->())?, error: ((APIError)->())?) {
		API.get("/users/\(userId)", success: {
			(dictionary) in
			success?(User.unserialize(dictionary))
			return
			}, error: error)
	}
	
	class func getByUserName(username: String, success: (([SimpleUserModel])->())?, error: ((APIError)->())?) {
		API.getArray("/users?username=\(username)", success: {
			(array) in
			success?(SimpleUserModel.unserializeArray(array))
			return
			}, error: error)
	}
	
	class func getByIds(userIds: [String], success: (([SimpleUserModel])->())?, error: ((APIError)->())?) {
		let params: [String: AnyObject] = ["userIds": userIds]
		
		API.postArray("/populate/users", parameters: params, success: {
			(array) in
			success?(SimpleUserModel.unserializeArray(array))
			return
			}, error: error)
	}
	
	class func searchByUsername(username: String, success: (([SimpleUserModel])->())?, error: ((APIError)->())?) {
		API.getArray("/users?username=\(username)", success: {
			(array) in
			success?(SimpleUserModel.unserializeArray(array))
			return
			}, error: error)
		
		Analytics.track("Searched by username")
	}
	
	class func serialize(model: UserModel) -> Dictionary<String, AnyObject> {
		var dictionary: [String: AnyObject] = [
			"_id": model.id as AnyObject,
			"firstName": model.firstName as AnyObject,
			"lastName": model.lastName as AnyObject,
			"username": model.username as AnyObject
		]
		
		if model.email != "" {
			dictionary["email"] = model.email as AnyObject
		}
		
		if model.phone != "" {
			dictionary["phone"] = model.phone as AnyObject
		}
		
		if let password = model.password {
			dictionary["password"] = password as AnyObject
		}
		
		if let avatarUrl = model.avatarUrl {
			dictionary["avatarUrl"] = avatarUrl as AnyObject
		}
		
		if let coverUrl = model.coverUrl {
			dictionary["coverUrl"] = coverUrl as AnyObject
		}
		
		if let facebookId = model.facebookId {
			dictionary["facebookId"] = facebookId as AnyObject
		}
		
		if let facebookToken = model.facebookToken {
			dictionary["facebookToken"] = facebookToken as AnyObject
		}
		
		return dictionary
	}
	
	class func unserialize(dictionary: Dictionary<String, AnyObject>) -> UserModel {
		var model = UserModel()
		
		if let value = ((dictionary["firstName"] as AnyObject?) as? String) {
			model.firstName = value
		}
		
		if let value = ((dictionary["lastName"] as AnyObject?) as? String) {
			model.lastName = value
		}
		
		if let value = ((dictionary["username"] as AnyObject?) as? String) {
			model.username = value
		}
		
		if let value = ((dictionary["_id"] as AnyObject?) as? String) {
			model.id = value
		}
		
		if let value = ((dictionary["email"] as AnyObject?) as? String) {
			model.email = value
		}
		
		if let value = ((dictionary["phone"] as AnyObject?) as? String) {
			model.phone = value
		}
		
		if let value = ((dictionary["facebookToken"] as AnyObject?) as? String) {
			model.facebookToken = value
		}
		
		if let value = ((dictionary["facebookId"] as AnyObject?) as? String) {
			model.facebookId = value
		}
		
		if let value = ((dictionary["avatarUrl"] as AnyObject?) as? String) {
			if value != "" {
				model.avatarUrl = value
			}
		}
		
		if let value = ((dictionary["coverUrl"] as AnyObject?) as? String) {
			if value != "" {
				model.coverUrl = value
			}
		}
		
		return model
	}
}