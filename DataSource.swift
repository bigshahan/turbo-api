//
//  DataSource.swift
//  TurboApi
//
//  Created by Shahan Khan on 10/8/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import Foundation

protocol DataSourceDelegate {
	func dataUpdated()
	func dataRefreshing()
	func dataError()
}

class DataSource: NSObject {
	var delegate: DataSourceDelegate?
	
	override init() {
		super.init()
	}
	
	func async(task: ()->(), cb: ()->()) {
		dispatch_async(dispatch_get_main_queue(), {
			task()
			cb()
		})
	}
}