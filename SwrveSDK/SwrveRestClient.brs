Function RequestObject() as Object
	req = CreateObject("roUrlTransfer")
	port = CreateObject("roMessagePort")
	' Set up request port. Note this will fail if called from the render thread
	req.SetPort(port)
	' Set request certificates
	req.SetCertificatesFile("common:/certs/ca-bundle.crt")
	req.InitClientCertificates()
	req.AddHeader("Content-Type", "application/json")

	return req
End Function

Function AddSwrveUrlParametersToURL(urlString as String) as String
	swrveConfig = GetSwrveClientInstance().configuration
	swrveJoinedDateEpochMilli = SwrveDateFromString(checkOrWriteJoinedDate()).toMillisToken()
	appInfo = CreateObject("roAppInfo")
	device = CreateObject("roDeviceInfo")

	urlString += "?"
	urlString += "&device_width=" + StrI(device.GetDisplaySize().w).Trim()
	urlString += "&device_height=" + StrI(device.GetDisplaySize().h).Trim()
	urlString += "&joined=" + swrveJoinedDateEpochMilli
	urlString += "&api_key=" + swrveConfig.apiKey
	urlString += "&appId=" + swrveConfig.appId
	urlString += "&user=" + swrveConfig.userId
	urlString += "&app_store=google" 'can't be roku right now (21.01/2018) because it is not supported by the backend. Will change back to roku once it's fixed.
	urlString += "&app_version=" + appInfo.GetVersion()
	urlString += "&version=" + swrveConfig.version
	urlString += "&conversation_version=4" 'hardcoded to get the new CDN paths'
	urlString += "&device_name=Roku" + device.GetModel().Trim()
	urlString += "&os_version=" + device.GetVersion()
	urlString += "&language=" + device.GetCurrentLocale()
	urlString += "&orientation=both"

	return urlString
End Function


Function Identify(newId as String) as object
    print "[SwrveSDK] Identify - " + newId
	swrveConfig = GetSwrveClientInstance().configuration

	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + SwrveConstants().SWRVE_IDENTIFY_URL

	payload = {}
	payload.api_key = swrveConfig.apiKey
	payload.swrve_id = swrveConfig.userId
	payload.external_user_id = newId
	payload.unique_device_id = swrveConfig.uniqueDeviceId
	resp = GenericPost(urlString, payload)

	return resp
End Function

Function IdentifyWithUserID(userID as String, newId as String) as object
    print "[SwrveSDK] IdentifyWitUserID - " + newId
	swrveConfig = GetSwrveClientInstance().configuration

	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + SwrveConstants().SWRVE_IDENTIFY_URL

	payload = {}
	payload.api_key = swrveConfig.apiKey
	payload.swrve_id = userID
	payload.external_user_id = newId
	payload.unique_device_id = swrveConfig.uniqueDeviceId
	resp = GenericPost(urlString, payload)

	return resp
End Function

'Downloads and returns the User resources and campaign'
Function GetUserResourcesAndCampaigns() as Object
	swrveConfig = GetSwrveClientInstance().configuration
	stack = GetStack(swrveConfig)
	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + stack + SwrveConstants().SWRVE_CONTENT_ENDPOINT + SwrveConstants().SWRVE_USER_RESOURCES_AND_CAMPAIGNS_URL
	urlString = AddSwrveUrlParametersToURL(urlString)

	etag = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME, "")
	if etag <> ""
		urlString += "&etag=" + etag
	end if
	return GenericGET(urlString)
End Function

'Downloads the diff and returns the raw object'
Function GetResourceDiff() as Object
	swrveConfig = GetSwrveClientInstance().configuration
	stack = GetStack(swrveConfig)
	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + stack + SwrveConstants().SWRVE_CONTENT_ENDPOINT + SwrveConstants().SWRVE_USER_RESOURCES_DIFF_URL
	urlString = AddSwrveUrlParametersToURL(urlString)
	return GenericGET(urlString)
End Function

'Transform the diff into the right struct with old/new pairs'
Function SortResourceDiff(diff as Object) as object
	flatStructure = {}
	if diff.code < 400 and diff.data <> invalid
		old = {}
		new = {}
		for each resource in diff.data
			oldValues = {}
			newValues = {}
			if resource.diff <> invalid
				for each key in resource.diff.keys()
					if resource.diff[key]["old"] <> invalid
						oldValues[key] = resource.diff[key]["old"]
					end if
					if resource.diff[key]["new"] <> invalid
						newValues[key] = resource.diff[key]["new"]
					end if
				end for
				old[resource.uid] = oldValues
				new[resource.uid] = newValues
			end if
		end for
		flatStructure.old = old
		flatStructure.new = new
	end if 
	
	return flatStructure
end Function

Function GetResourcesDiffSorted() as Object
	rawDiff = GetResourceDiff()
	sorted = SortResourceDiff(rawDiff)
	return sorted
End Function

'Loads from file user resources and campaigns'
Function GetMockedUserResourcesAndCampaigns(filename) as Object
	obj = SwrveGetObjectFromFile(SwrveConstants().SWRVE_JSON_LOCATION + filename) 
	if obj <> invalid and type(obj) <> "roString"
		mockedResponse = {
			code: 200
			data: obj
		}
		return mockedResponse
	else 
		mockedResponse = {
			code: 999
			data: "Invalid or non existent file"
		}
		return mockedResponse
	end if
End Function

'Will send some JSON payload to the batch endpoint
Function SendBatchPOST(payload as Object) as Object
	urlString = SwrveConstants().SWRVE_HTTPS + SwrveConstants().SWRVE_API_ENDPOINT + SwrveConstants().SWRVE_BATCH_URL
	return GenericPOST(urlString, payload)
End Function

' Generic POST function
Function GenericPOST(url as String, data as Object) as Object
	
	swrveConfig = GetSwrveClientInstance().configuration
	if swrveConfig.mockHTTPPOSTResponses = true
		return { Code: swrveConfig.mockedPOSTResponseCode, Data: "Mocked response"}
	end if

	req = RequestObject()
	' Set up URL
	url = GetStack(swrveConfig) + url
	req.SetURL(url)

	' make the data a json string
	strData = FormatJson(data)

	SWLog("Sending POST to " + url)
    requestSuccess = false
	retries = swrveConfig.httpMaxRetries
	retrySleepTime = swrveConfig.httpTimeBetweenRetries
	while retries > 0 and requestSuccess = false
		requestSuccess = req.AsyncPostFromString(strData)
	    while true
	      	msg = Wait (0, req.GetMessagePort())
		    if type (msg) = "roUrlEvent"
		        if msg.GetResponseCode() = 200
		        	data = ""
		        	if msg.GetString() <> "" and msg.GetString() <> invalid
		        		data = ParseJSON(msg.GetString())
		        	end if
		         	return {
		            	Code: msg.GetResponseCode()
		            	Data: data
		          	}
		        else
		         	return {
		            	Code: msg.GetResponseCode()
		            	Data: msg.GetFailureReason()
		          	}
		        endif
		      	else if type (msg) = "Invalid"
		        	res.AsyncCancel()
		        	return invalid
		      	endif
	    end while

	    if requestSuccess = false and retries > 0 then
			SWLog("Retrying in " + str(retrySleepTime) + " seconds...")
	      	time.Sleep(time.Duration(retrySleepTime) * time.Second)
	      	retrySleepTime = retrySleepTime * 2
	      	retries--
	    end if
	end while

	if requestSuccess = false
		SWLog("Could not POST to "+ url)
		return invalid
	end if

End Function



Function GenericGET(url as String) as Object
	swrveConfig = GetSwrveClientInstance().configuration

	if swrveConfig.mockHTTPGETResponses = true
		return { Code: swrveConfig.mockedGETResponseCode, Data: "Mocked response"}
	end if
	req = RequestObject()
	req.SetURL(url.Trim())
	requestSuccess = false

	retries = swrveConfig.httpMaxRetries
	retrySleepTime = swrveConfig.httpTimeBetweenRetries
	while retries > 0 and requestSuccess = false

		requestSuccess = req.AsyncGetToString()
	    while true
	        msg = Wait (0, req.GetMessagePort())
	        if type (msg) = "roUrlEvent"
	        	if msg.GetResponseCode() = 200	
	         		return {
			           Code: msg.GetResponseCode()
			           Data: ParseJSON(msg.GetString())
			           Headers: msg.GetResponseHeaders()
	          		}
		        else
		          	return {
			           Code: msg.GetResponseCode()
			           Data: msg.GetFailureReason()
		          	}
	            endif
	      	else if type (msg) = "Invalid"
		        res.AsyncCancel()
		        return invalid
	      	endif
	    end while

	    if requestSuccess = false and retries > 0 then
			SWLog("Retrying in " + str(retrySleepTime) + " seconds...")
	      	Sleep(retrySleepTime * 1000)
	      	retrySleepTime = retrySleepTime * 2
	      	retries--
	    end if
	end while

	if requestSuccess = false
		SWLog("Failed GET request")
		return invalid
	end if
end Function


Function DownloadAndStoreAssets(swrveClient as Object, ids as Object, fo as function) as Object
	allGood = true
	for each id in ids
		response = DownloadAndStoreImage(swrveClient, id)
		if response.code >= 400
			allGood = false
			EXIT FOR
		end if
	end for
	if allGood
		fo()
	end if
End Function

Function DownloadAndStoreImage(swrveClient as Object, id as String) as Object
	filesystem = CreateObject("roFilesystem")
	if not filesystem.Exists(SwrveConstants().SWRVE_ASSETS_LOCATION)
    	filesystem.CreateDirectory(SwrveConstants().SWRVE_ASSETS_LOCATION)
    end if
	swrveConfig = GetSwrveClientInstance().configuration

	cdn = swrveClient.userCampaigns.cdn_root

	url = cdn + id
	localUrl = SwrveConstants().SWRVE_ASSETS_LOCATION + id

	req = RequestObject()

	req.SetURL(url.Trim())
	requestSuccess = false

	retries = swrveConfig.httpMaxRetries
	retrySleepTime = swrveConfig.httpTimeBetweenRetries
	while retries > 0 and requestSuccess = false
		requestSuccess = req.AsyncGetToFile(localUrl.Trim())
	
	    while true
	        msg = Wait (0, req.GetMessagePort())
	        if type (msg) = "roUrlEvent"
	        	if msg.GetResponseCode() = 200	
	         		return {
			           Code: msg.GetResponseCode()
			           Data: "Successful Download"
	          		}
		        else
		          	return {
			           Code: msg.GetResponseCode()
			           Data: msg.GetFailureReason()
		          	}
	            endif
	      	else if type (msg) = "Invalid"
		        res.AsyncCancel()
		        return invalid
	      	endif
	    end while

	    if requestSuccess = false and retries > 0 then
			SWLog("Retrying in " + str(retrySleepTime) + " seconds...")
	      	Sleep(retrySleepTime * 1000)
	      	retrySleepTime = retrySleepTime * 2
	      	retries--
	    end if
	end while

	if requestSuccess = false
		SWLog("Failed GET request")
		return invalid
	end if
End Function


