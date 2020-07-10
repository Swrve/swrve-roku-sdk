function RequestObject() as Object
	req = CreateObject("roUrlTransfer")
	port = CreateObject("roMessagePort")
	' Set up request port. Note this will fail if called from the render thread
	req.SetPort(port)
	' Set request certificates
	req.SetCertificatesFile("common:/certs/ca-bundle.crt")
	req.InitClientCertificates()
	req.AddHeader("Content-Type", "application/json")

	return req
end function

function AddSwrveUrlParametersToURL(urlString as String) as String
	swrveConfig = m.swrve_config
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
	urlString += "&app_store=roku"
	urlString += "&app_version=" + appInfo.GetVersion()
	urlString += "&version=" + swrveConfig.version
	urlString += "&conversation_version=4" 'hardcoded to get the new CDN paths'
	urlString += "&device_name=Roku" + device.GetModel().Trim()
	urlString += "&os_version=" + device.GetVersion()
	urlString += "&language=" + device.GetCurrentLocale()
	urlString += "&orientation=" + swrveConfig.orientation

	return urlString
end function


function Identify(newId as String, observer as Dynamic) as object
	swrveConfig = m.swrve_config
	stack = GetStack(swrveConfig)
	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + stack + SwrveConstants().SWRVE_IDENTIFY_URL

	payload = {}
	payload.api_key = swrveConfig.apiKey
	payload.swrve_id = swrveConfig.userId
	payload.external_user_id = newId
	payload.unique_device_id = swrveConfig.uniqueDeviceId
	
	if swrveConfig.mockHTTPPOSTResponses = true
		return GenericPOST(urlString, payload, observer)
	else 
		GenericPOST(urlString, payload, observer)
	end if

	return Invalid
end function

function IdentifyWithUserID(userID as String, newId as String, observer as String) as object
	swrveConfig = m.swrve_config
	stack = GetStack(swrveConfig)
	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + stack + SwrveConstants().SWRVE_IDENTIFY_URL

	payload = {}
	payload.api_key = swrveConfig.apiKey
	payload.swrve_id = userID
	payload.external_user_id = newId
	payload.unique_device_id = swrveConfig.uniqueDeviceId
	
	if swrveConfig.mockHTTPPOSTResponses = true
		return GenericPOST(urlString, payload, observer)
	else 
		GenericPOST(urlString, payload, observer)
	end if

	return Invalid

end function

'Downloads and returns the User resources and campaign'
function GetUserResourcesAndCampaigns(observer as String) as Object
	swrveConfig = m.swrve_config
	stack = GetStack(swrveConfig)
	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + stack + SwrveConstants().SWRVE_CONTENT_ENDPOINT + SwrveConstants().SWRVE_USER_RESOURCES_AND_CAMPAIGNS_URL
	urlString = AddSwrveUrlParametersToURL(urlString)

	etag = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME, "")
	if etag <> ""
		urlString += "&etag=" + etag
	end if

	if swrveConfig.mockHTTPGETResponses = true
		rtn = GenericGET(urlString, "")
		return rtn
	else 
		GenericGET(urlString, observer)
	end if

	return Invalid
	
end Function

'Downloads the diff and returns the raw object'
function GetResourceDiff(observer as String) as Object
	swrveConfig = m.swrve_config
	stack = GetStack(swrveConfig)
	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + stack + SwrveConstants().SWRVE_CONTENT_ENDPOINT + SwrveConstants().SWRVE_USER_RESOURCES_DIFF_URL
	urlString = AddSwrveUrlParametersToURL(urlString)
	
	if swrveConfig.mockHTTPGETResponses = true
		rtn = GenericGET(urlString, "")
		return rtn
	else 
		GenericGET(urlString, observer)
	end if

	return Invalid
end function

'Transform the diff into the right struct with old/new pairs'
function SortResourceDiff(diff as Object) as object
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


function SwrveGetResourcesDiff() as Object
	rawDiff = GetResourceDiff("SwrveOnGetResourcesDiff")
	return rawDiff
end function

function SwrveOnGetResourcesDiff(responseEvent as Dynamic) as Object
	if(responseEvent <> invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
		responseEvent.getRoSGNode().unobserveField(responseEvent.getField())
	else 
		response = responseEvent
	end if

	sorted = SortResourceDiff(response)
	m.global.SwrveResourcesDiffObjectReady = sorted
	return sorted
end function


'Loads from file user resources and campaigns'
function GetMockedUserResourcesAndCampaigns(filename) as Object
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
end function

'Will send some JSON payload to the batch endpoint
function SendBatchPOST(payload as Object, observer as Dynamic) as Object
	swrveConfig = m.swrve_config
	stack = GetStack(swrveConfig)
	urlString = SwrveConstants().SWRVE_HTTPS + swrveConfig.appId + "." + stack + SwrveConstants().SWRVE_API_ENDPOINT + SwrveConstants().SWRVE_BATCH_URL

	if swrveConfig.mockHTTPPOSTResponses = true
		return GenericPOST(urlString, payload, observer)
	else 
		GenericPOST(urlString, payload, observer)
	end if

	return Invalid
end function

' Generic POST function
function GenericPOST(url as String, data as Object, observer as Dynamic) as Object
	swrveConfig = m.swrve_config

	if swrveConfig.mockHTTPPOSTResponses = true
		if(type(observer) = "String")
			return { Code: swrveConfig.mockedPOSTResponseCode, Data: "Mocked response", requestUrl: url.Trim()}
		else 
			return observer({ Code: swrveConfig.mockedPOSTResponseCode, Data: "Mocked response", requestUrl: url.Trim()})
		end if
	end if

	' make the data a json string
	strData = FormatJson(data)

	request = {
		url:url.Trim(),
		data:strData
	}

	SWLogDebug("GenericPOST() Sending POST to:", url)

	_postTask = CreateObject("roSGNode", "GenericPOSTTask")
	_postTask.request = request
	_postTask.ObserveField("response", observer)
	_postTask.Control = "Run"

	return {}
end function



function GenericGET(url as String, observer as Dynamic) as Object
	swrveConfig = m.swrve_config

	if swrveConfig.mockHTTPGETResponses = true
		return { Code: swrveConfig.mockedGETResponseCode, Data: {"user_resources" : {}, campaigns : {} }, requestUrl:url.Trim()}
	end if

	request = {
		url:url.Trim()
	}

	SWLogDebug("GenericGET() to:", url)

	_getTask = createObject("roSGNode", "GenericGETTask")
	_getTask.request = request
	_getTask.ObserveField("response", observer)
	_getTask.Control = "Run"
	m._getTask = _getTask

	return Invalid
end Function


function DownloadAndStoreAssets(ids as Object) as Object
	m._assetIds = []
	
	for each id in ids
		m._assetIds.Push(id)
	end for

	for each id in ids
		response = DownloadAndStoreImage(id)
	end for
end function

function _SwrveOnDownloadAndStoreImage(responseEvent)
	if(responseEvent <> invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
	end if
	responseEvent.getRoSGNode().unobserveField(responseEvent.getField())

	if(m._assetIds.Count() > 0)
		for id = 0 to m._assetIds.Count() - 1
			if(m._assetIds[id] = response.id)
				m._assetIds.Delete(id)
				exit for
			end if
		end for
	end if

	if(m._assetIds.Count() = 0)
		assetsDownloadCallback()
	end if
end function

function DownloadAndStoreImage(id as String) as Object
	swrveConfig = m.swrve_config

	cdn = m.userCampaigns.cdn_root

	url = cdn + id
	SWLogInfo("Downloading:", url)
	localUrl = SwrveConstants().SWRVE_ASSETS_LOCATION + id


	request = {
		id:id,
		url:url.Trim(),
		localUrl:localUrl,
		assetLocation:SwrveConstants().SWRVE_ASSETS_LOCATION
	}

	_getTask = createObject("roSGNode", "DownloadAndStoreImageTask")
	_getTask.request = request
	_getTask.ObserveField("response", "_SwrveOnDownloadAndStoreImage")
	_getTask.Control = "Run"
end function


