//
//  API.swift
//  TurboApi
//
//  Created by Shahan Khan on 9/22/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import Foundation

enum APIError {
	case ServerError
	case NotAuthenticated
	case ClientError
}

enum APIUploadType {
	case JPG
	case MP4
	case MOV
}

enum APIRequestType {
	case GET
	case POST
	case PUT
	case DELETE
}

class API {
	class func handleError(request: AFHTTPRequestOperation, error: NSError, callback: ((APIError)->())?) {
		dump(request)
		dump(error)
		callback?(APIError.ServerError)
	}
	
	// for a GET request that returns a single object
	class func get(url: String, success: ((Dictionary<String, AnyObject>)->())?, error: ((APIError)->())?) {
		request(.GET, url: url, parameters: nil, success: {
			(data) in
			let dict = data as Dictionary<String, AnyObject>
			success?(dict)
		}, error: error)
	}
	
	// for a GET request that returns an array of dictionaries
	class func getArray(url: String, success: (([Dictionary<String, AnyObject>])->())?, error: ((APIError)->())?) {
		request(.GET, url: url, parameters: nil, success: {
			(data) in
			let dict = data as [Dictionary<String, AnyObject>]
			success?(dict)
		}, error: error)
	}
	
	class func delete(url: String, success: (()->())?, error: ((APIError)->())?) {
        request(.DELETE, url: url, parameters: nil, success: {
            (data) in
            success?()
            return
		}, error: error)
	}
    
    // for a DELETE request that returns an array of strings
    class func deleteArrayString(url: String, success: (([String])->())?, error: ((APIError)->())?) {
        request(.DELETE, url: url, parameters: nil, success: {
            (data) in
            let array = data as [String]
            success?(array)
            }, error: error)
    }
	
	class func put(url: String, parameters: Dictionary<String, AnyObject>?, success: ((Dictionary<String, AnyObject>)->())?, error: ((APIError)->())?) {
		request(.PUT, url: url, parameters: parameters, success: {
			(data) in
			let dict = data as Dictionary<String, AnyObject>
			success?(dict)
		}, error: error)
	}
	
	// for a POST request that returns an object
	class func post(url: String, parameters: Dictionary<String, AnyObject>?, success: ((Dictionary<String, AnyObject>)->())?, error: ((APIError)->())?) {
		request(.POST, url: url, parameters: parameters, success: {
			(data) in
			let dict = data as Dictionary<String, AnyObject>
			success?(dict)
		}, error: error)
	}

	// for a POST request that returns an array of objects
	class func postArray(url: String, parameters: Dictionary<String, AnyObject>?, success: (([Dictionary<String, AnyObject>])->())?, error: ((APIError)->())?) {
		request(.POST, url: url, parameters: parameters, success: {
			(data) in
			let array = data as [Dictionary<String, AnyObject>]
			success?(array)
		}, error: error)
	}
    
    // for a POST request that returns an array of strings
    class func postArrayString(url: String, parameters: Dictionary<String, AnyObject>?, success: (([String])->())?, error: ((APIError)->())?) {
        request(.POST, url: url, parameters: parameters, success: {
            (data) in
            let array = data as [String]
            success?(array)
            }, error: error)
    }
	
	private class func request(type: APIRequestType, url: String, parameters: Dictionary<String, AnyObject>?, success: ((AnyObject)->())?, error: ((APIError)->())?) {
		// analytics
		totalApiRequests++
		
		// do request
		let manager = API.manager()
		
		switch type {
		case .POST:
			manager.POST(API.url(url), parameters: parameters, success: {
				(operation, data) in
				if data == nil {
					error?(.ServerError)
					return
				}
				
				success?(data)
				return
			}, failure: {
				(task, err) in
				API.handleError(task, error: err, callback: error)
				return
			})
		case .PUT:
			manager.PUT(API.url(url), parameters: parameters, success: {
				(operation, data) in
				if data == nil {
					error?(.ServerError)
					return
				}
				
				success?(data)
				return
			}, failure: {
					(task, err) in
					API.handleError(task, error: err, callback: error)
					return
			})
		case .DELETE:
			manager.DELETE(API.url(url), parameters: parameters, success: {
                (operation, data) in
                success?( (data != nil ) ? data : "")
				return
			}, failure: {
				(task, err) in
				API.handleError(task, error: err, callback: error)
				return
			})
		default:
			manager.GET(API.url(url), parameters: parameters, success: {
				(operation, data) in
				if data == nil {
					error?(.ServerError)
					return
				}
				
				success?(data)
				return
			}, failure: {
				(task, err) in
				API.handleError(task, error: err, callback: error)
				return
			})
		}
	}
	
	class func upload(url: NSURL, type: APIUploadType, success: ((String)->())?, error: ((APIError)->())?) {
		if !User.loggedIn() {
			error?(.NotAuthenticated)
			return
		}
		
		var mime = "image/jpeg"
		var ext = "jpg"
		if type == APIUploadType.MP4 {
			mime = "video/mp4"
			ext = "mp4"
		} else if type == APIUploadType.MOV {
			mime = "video/quicktime"
			ext = "mov"
		}
		
		let params: AnyObject = ["type": ext]
		let manager = API.manager()
		
		Analytics.start("\(ext) upload")
		
		manager.POST(API.url("/uploads"), parameters: params, success: {
			(operation, data) in
			// nil check
			if data == nil {
				error?(.ServerError)
				return
			}
			
			// typecast data to dictionary
			let dictionary = data as Dictionary<String, AnyObject>

			// get signed url from json dictionary
			let signedUrl = (dictionary["url"] as AnyObject?) as? String
			let publicUrl = (dictionary["publicUrl"] as AnyObject?) as? String
			
			if signedUrl == nil || publicUrl == nil {
				error?(APIError.ServerError)
				return
			}
			
			// do upload to s3
			var requestUrl = NSURL(string: signedUrl!)
			var client = AFHTTPSessionManager(baseURL: requestUrl)
			
			client.responseSerializer = AFHTTPResponseSerializer()
			client.responseSerializer.acceptableContentTypes = NSSet(object: "application/xml")
			
			var request = NSMutableURLRequest()
			request.HTTPMethod = "PUT"
			request.setValue(mime, forHTTPHeaderField: "Content-Type")
			
			var data = NSData(contentsOfURL: url)
			
			if data == nil {
				error?(APIError.ServerError)
				return
			}
			
			request.HTTPBody = data
			request.setValue(String(data!.length), forHTTPHeaderField: "Content-Length")
			request.URL = requestUrl

			var task = client.dataTaskWithRequest(request, completionHandler: {
				(response, responseObject, err) in
				
				if response == nil {
					error?(APIError.ServerError)
					return
				}
				
				var responseData = responseObject as NSData?

				if responseData != nil {
					let string = NSString(data: responseData!, encoding: NSUTF8StringEncoding)

				}
				
				if let errorOcurred = err {
					error?(APIError.ServerError)
					return
				}
				
				success?(publicUrl!)
				
				Analytics.track("\(ext) upload", properties: ["bytes": String(data!.length)])
			})
			
			task.resume()
			
			return
		}, failure: {
			(task, err) in
			API.handleError(task, error: err, callback: error)
			return
		})
	}
	
	class func uploadImage(image:UIImage, success: ((String)->())?, error: ((APIError)->())?) {
		// save image to jpeg in a temp file
		var imageData = UIImageJPEGRepresentation(image, 0.8)
		var tmpDir = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)!
		var fileUrl = tmpDir.URLByAppendingPathComponent("image").URLByAppendingPathExtension("jpg")
		
		if !imageData.writeToFile(fileUrl.path!, atomically: false) {
			error?(APIError.ClientError)
		}

		// upload the jpeg image
		upload(fileUrl, type: APIUploadType.JPG, success, error)
	}
	
	class func url(endpoint: String) -> String {
		return "http://server.co\(endpoint)"
	}
	
	class func manager() -> AFHTTPRequestOperationManager {
		let manager = AFHTTPRequestOperationManager()
		manager.requestSerializer = AFJSONRequestSerializer() as AFJSONRequestSerializer
		manager.responseSerializer = AFJSONResponseSerializer() as AFJSONResponseSerializer
		
		// add authorization header if logged in
		if User.loggedIn() {
			let userId = NSUserDefaults.standardUserDefaults().stringForKey("userId")!
			let authToken = NSUserDefaults.standardUserDefaults().stringForKey("authToken")!
			manager.requestSerializer.setAuthorizationHeaderFieldWithUsername(userId, password: authToken)
		}
		
		return manager
	}
}