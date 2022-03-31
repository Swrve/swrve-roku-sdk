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
	device = CreateObject("roDeviceInfo")

	urlString += "?"
	urlString += "&device_width=" + StrI(device.GetDisplaySize().w).Trim()
	urlString += "&device_height=" + StrI(device.GetDisplaySize().h).Trim()
	urlString += "&joined=" + swrveJoinedDateEpochMilli
	urlString += "&api_key=" + swrveConfig.apiKey
	urlString += "&appId=" + swrveConfig.appId
	urlString += "&user=" + swrveConfig.userId
	urlString += "&app_store=roku"
	urlString += "&app_version=" + swrveConfig.appVersion
	urlString += "&version=" + SwrveConstants().SWRVE_CAMPAIGN_RESOURCES_API_VERSION
	urlString += "&conversation_version=" + SwrveConstants().SWRVE_CONVERSATION_VERSION
	urlString += "&device_name=Roku" + device.GetModel().Trim()
	urlString += "&os_version=" + device.GetVersion()
	urlString += "&language=" + device.GetCurrentLocale()
	urlString += "&orientation=" + swrveConfig.orientation
	urlString += "&os=roku"
	urlString += "&device_type=tv"

	return urlString
end function

function Identify(newId as String, observer as Dynamic) as Object
	if m.swrve_config = Invalid then return Invalid
	stack = GetStack(m.swrve_config)
	urlString = SwrveConstants().SWRVE_HTTPS + m.swrve_config.appId + "." + stack + SwrveConstants().SWRVE_IDENTIFY_URL

	payload = {}
	payload.api_key = m.swrve_config.apiKey
	payload.swrve_id = m.swrve_config.userId
	payload.external_user_id = newId
	payload.unique_device_id = m.swrve_config.uniqueDeviceId

	SWLogInfo("Swrve identifying with externalID:", newId, "swrve user id:", m.swrve_config.userId)
	if m.swrve_config.mockHTTPPOSTResponses = true
		return GenericPOST(urlString, payload, observer)
	else
		GenericPOST(urlString, payload, observer)
	end if

	return Invalid
end function

function IdentifyWithUserID(userID as String, newId as String, observer as String) as Object
	if m.swrve_config = Invalid then return Invalid
	stack = GetStack(m.swrve_config)
	urlString = SwrveConstants().SWRVE_HTTPS + m.swrve_config.appId + "." + stack + SwrveConstants().SWRVE_IDENTIFY_URL

	payload = {}
	payload.api_key = m.swrve_config.apiKey
	payload.swrve_id = userID
	payload.external_user_id = newId
	payload.unique_device_id = m.swrve_config.uniqueDeviceId

	SWLogInfo("Swrve identifying with externalID:", newId, "swrve user id:", userID)

	if m.swrve_config.mockHTTPPOSTResponses = true
		return GenericPOST(urlString, payload, observer)
	else
		GenericPOST(urlString, payload, observer)
	end if

	return Invalid

end function

'Downloads and returns the User resources and campaign'
function GetUserResourcesAndCampaigns(observer as String) as Object
	if m.swrve_config = Invalid then return Invalid
	stack = GetStack(m.swrve_config)
	urlString = SwrveConstants().SWRVE_HTTPS + m.swrve_config.appId + "." + stack + SwrveConstants().SWRVE_CONTENT_ENDPOINT + SwrveConstants().SWRVE_USER_CONTENT_URL
	urlString = AddSwrveUrlParametersToURL(urlString)

	etag = SwrveGetValueFromSection(GetCurrentUserIDFromConfig(), SwrveConstants().SWRVE_ETAG_FILENAME)
	if etag <> ""
		urlString += "&etag=" + etag
	end if

	if m.swrve_config.mockHTTPGETResponses = true
		return GenericGET(urlString, "")
	else
		GenericGET(urlString, observer)
	end if

	return Invalid

end function

'Downloads the diff and returns the raw object'
function GetResourceDiff(observer as String) as Object
	if m.swrve_config = Invalid then return Invalid
	stack = GetStack(m.swrve_config )
	urlString = SwrveConstants().SWRVE_HTTPS + m.swrve_config .appId + "." + stack + SwrveConstants().SWRVE_CONTENT_ENDPOINT + SwrveConstants().SWRVE_USER_RESOURCES_DIFF_URL
	urlString = AddSwrveUrlParametersToURL(urlString)

	if m.swrve_config .mockHTTPGETResponses = true
		return GenericGET(urlString, "")
	else
		GenericGET(urlString, observer)
	end if

	return Invalid
end function

'Transform the diff into the right struct with old/new pairs'
function SortResourceDiff(diff as Object) as Object
	flatStructure = {}
	if diff.code < 400 AND diff.data <> Invalid
		old = {}
		new = {}
		for each resource in diff.data
			oldValues = {}
			newValues = {}
			if resource.diff <> Invalid
				for each key in resource.diff.keys()
					if resource.diff[key]["old"] <> Invalid
						oldValues[key] = resource.diff[key]["old"]
					end if
					if resource.diff[key]["new"] <> Invalid
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
end function

function SwrveOnGetResourcesDiff() as Object
	rawDiff = GetResourceDiff("SwrveResourcesDiff")
	return rawDiff
end function

function SwrveResourcesDiff(responseEvent as Dynamic) as Object
	if(responseEvent <> Invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
		responseEvent.getRoSGNode().unobserveField(responseEvent.getField())
	else
		response = responseEvent
	end if

	sorted = SortResourceDiff(response)
	getSwrveNode().resourcesDiffObjectReady = sorted
	return sorted
end function

'Loads from file user resources and campaigns'
function GetMockedUserResourcesAndCampaigns(filename) as Object
	obj = SwrveGetObjectFromFile(SwrveConstants().SWRVE_JSON_LOCATION + filename)
	if obj <> Invalid AND type(obj) <> "roString"
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
	if m.swrve_config = Invalid then return Invalid
	stack = GetStack(m.swrve_config)
	urlString = SwrveConstants().SWRVE_HTTPS + m.swrve_config.appId + "." + stack + SwrveConstants().SWRVE_API_ENDPOINT + SwrveConstants().SWRVE_BATCH_URL

	if m.swrve_config.mockHTTPPOSTResponses = true
		return GenericPOST(urlString, payload, observer)
	else
		GenericPOST(urlString, payload, observer)
	end if

	return Invalid
end function

' Generic POST function
function GenericPOST(url as String, data as Object, observer as Dynamic) as Object
	if m.swrve_config = Invalid then return {}

	if m.swrve_config.mockHTTPPOSTResponses = true
		if(type(observer) = "String")
			return { Code: m.swrve_config.mockedPOSTResponseCode, Data: "Mocked response", requestUrl: url.Trim() }
		else
			return observer({ Code: m.swrve_config.mockedPOSTResponseCode, Data: "Mocked response", requestUrl: url.Trim() })
		end if
	end if

	' make the data a json string
	strData = FormatJson(data)

	request = {
		url: url.Trim(),
		data: strData
	}

	SWLogDebug("GenericPOST() Sending POST to " + url)
	SWLogDebug("GenericPOST() POST body " + strData)

	_postTask = CreateObject("roSGNode", "GenericPOSTTask")
	_postTask.request = request
	_postTask.ObserveField("response", observer)
	_postTask.Control = "Run"

	return {}
end function

function GenericGET(url as String, observer as Dynamic) as Object
	if m.swrve_config = Invalid then return Invalid

	if m.swrve_config.mockHTTPGETResponses = true
		return { Code: m.swrve_config.mockedGETResponseCode, Data: { "user_resources": {}, campaigns: {} }, requestUrl: url.Trim() }
	end if

	request = {
		url: url.Trim()
	}

	SWLogDebug("GenericGET() to " + url)

	_getTask = createObject("roSGNode", "GenericGETTask")
	_getTask.request = request
	_getTask.ObserveField("response", observer)
	_getTask.Control = "Run"
	m._getTask = _getTask

	return Invalid
end function

function DownloadAndStoreAssets(ids as Object) as Object
	m._assetIds = []

	for each id in ids
		m._assetIds.Push(id)
	end for

	if m._assetIds.count() > 0
		for each id in ids
			DownloadAndStoreImage(id)
		end for
	end if
end function

function _SwrveOnDownloadAndStoreImage(responseEvent)
	if(responseEvent <> Invalid AND type(responseEvent) = "roSGNodeEvent")
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
	cdn = m.userCampaigns.cdn_paths.message_images

	url = cdn + id
	SWLogInfo("Downloading " + url)
	localUrl = SwrveConstants().SWRVE_ASSETS_LOCATION + id

	request = {
		id: id,
		url: url.Trim(),
		localUrl: localUrl
	}

	_getTask = createObject("roSGNode", "DownloadAndStoreImageTask")
	_getTask.request = request
	_getTask.ObserveField("response", "_SwrveOnDownloadAndStoreImage")
	_getTask.Control = "Run"
end function
