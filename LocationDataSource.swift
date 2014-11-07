//
//  LocationDataSource.swift
//  TurboApi
//
//  Created by Shahan Khan on 11/6/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import Foundation

class LocationDataSource: DataSource, CLLocationManagerDelegate {
	var locationManager :CLLocationManager
	var location :CLLocation?
	private var refreshing = false
	private var timer: NSTimer?
	
	override init() {
		// setup CLLocationManager to get location
		locationManager = CLLocationManager()
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		
		// super init
		super.init()
		locationManager.delegate = self

		// Get Location Permissions if Needed
		if CLLocationManager.authorizationStatus() == .NotDetermined {
			// ios7 doesn't support requestAlwaysAuthorization
			if ios7() {
				locationManager.startUpdatingLocation()
			} else {
				locationManager.requestAlwaysAuthorization()
			}
		}
	}
	
	func refresh() {
		delegate?.dataRefreshing()
		refreshing = true
		
		// start updating location if authorized
		if CLLocationManager.authorizationStatus() != .Restricted && CLLocationManager.authorizationStatus() != .Denied {
			locationManager.startUpdatingLocation()
			
			// start timer
			timer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "timedOut", userInfo: nil, repeats: false)
		} else {
			delegate?.dataError()
			refreshing = false
		}
	}
	
	// MARK: Handle NSTimer
	func timedOut() {
		timer = nil
		
		if refreshing {
			delegate?.dataError()
			refreshing = false
		}
	}
	
	// MARK: Location Services
	func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		if CLLocationManager.authorizationStatus() != .Restricted && CLLocationManager.authorizationStatus() != .Denied {
			locationManager.startUpdatingLocation()
		} else if refreshing {
			timer?.invalidate()
			timer = nil
			delegate?.dataError()
			refreshing = false
		}
	}
	
	func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
		locationManager.stopUpdatingLocation()
		location = locations[0] as? CLLocation
		
		if refreshing {
			timer?.invalidate()
			timer = nil
			delegate?.dataUpdated()
			refreshing = false
		}
	}
	
	
	// MARK: Private Helper Functions
	private func ios7() -> Bool {
		var version = UIDevice.currentDevice().systemVersion as NSString
		
		if version.doubleValue < 8.0 {
			return true
		}
		
		return false
	}
}