//
//  Analytics.swift
//  TurboApi
//
//  Created by Shahan Khan on 10/25/14.
//  Copyright (c) Shahan Khan. All rights reserved.
//

import Foundation

class Analytics {
	// called by AppDelegate to setup MixPanel
	// should also be called after login or sign up
	class func setup() {
		Mixpanel.sharedInstanceWithToken("")
		
		if !User.loggedIn() {
			return
		}
		
		if let userId = User.currentUserId() {
			Mixpanel.sharedInstance().identify(userId)
			Mixpanel.sharedInstance().people.set(["userId": userId])
		}
	}
	
	// Record an action
	class func track(event: String, properties: [String: String]? = nil) {
		if let dict = properties {
			Mixpanel.sharedInstance().track(event, properties: dict)
			return
		}
		Mixpanel.sharedInstance().track(event)
	}
	
	// Start an action timer
	class func start(event: String) {
		Mixpanel.sharedInstance().timeEvent(event)
	}
}