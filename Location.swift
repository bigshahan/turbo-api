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
	
	override init() {
		// setup CLLocationManager to get location
		locationManager = CLLocationManager()
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		
		// super init
		super.init()
		locationManager.delegate = self
		
		// Get Location Permissions if Needed
		// ios7 doesn't support requestAlwaysAuthorization
		if CLLocationManager.authorizationStatus() == .NotDetermined && !ios7() {
			locationManager.requestAlwaysAuthorization()
		}
	}
	
	func refresh() {
		delegate?.dataRefreshing()
		
		// start updating location if authorized
		if CLLocationManager.authorizationStatus() != .NotDetermined && CLLocationManager.authorizationStatus() != .Restricted && CLLocationManager.authorizationStatus() != .Denied {
			locationManager.startUpdatingLocation()
		} else {
			delegate?.dataError()
		}
	}
	
	// MARK: Location Services
	func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
		locationManager.stopUpdatingLocation()
		delegate?.dataUpdated()
		location = locations[0] as? CLLocation
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