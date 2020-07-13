' Used in the main thread and in the Render thread.
function SwrveConstants() as Object

	userID = SwrveGetStringFromPersistence("userID", "")

	return {
		SWRVE_SDK_VERSION: "Roku 4.0.1"

		SWRVE_INSTALL_DATE_KEY: "install_date"
		SWRVE_JOINED_DATE_KEY: userID + "install_date"

		SWRVE_QA_UNIQUE_DEVICE_ID_KEY: "unique_device_id"
		SWRVE_USER_ID_KEY: "userID"
		SWRVE_USER_IDS_KEY: "swrveUserIDs"
		SWRVE_LAST_SESSION_DATE_KEY: userID + "last_session_date"
		SWRVE_START_SESSION_DATE_KEY: userID + "start_session_date"
		SWRVE_USER_RESOURCES_FILENAME: userID + "resources"
		SWRVE_USER_CAMPAIGNS_FILENAME: userID + "campaigns"
		SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME: userID + "campaigns_lastmessagetime"
		SWRVE_USER_CAMPAIGNS_IMPRESSIONS: userID + "campaigns_impressions"

		SWRVE_CAMPAIGN_STATE_PREFIX: userID + "campaignState"

		SWRVE_USER_QA_FILENAME: userID + "qa"
		SWRVE_ETAG_FILENAME: userID + "etag"
		SWRVE_USER_RESOURCES_SIGNATURE_FILENAME: userID + "resources_signature"
		SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME: userID + "campaigns_signature"

		SWRVE_SEQNUM: userID + "swrve_seqnum"
		SWRVE_HTTPS: "https://"
		SWRVE_API_ENDPOINT: "api.swrve.com"
		SWRVE_CONTENT_ENDPOINT: "content.swrve.com"
		SWRVE_BATCH_URL: "/1/batch"
		SWRVE_IDENTIFY_URL: "identity.swrve.com/identify"
		SWRVE_USER_RESOURCES_AND_CAMPAIGNS_URL: "/api/1/user_resources_and_campaigns"
		SWRVE_USER_RESOURCES_DIFF_URL: "/api/1/user_resources_diff"

		SWRVE_EVENT_TYPE_EVENT: "event"
		SWRVE_EVENT_TYPE_USER_UPDATE: "user"
		SWRVE_EVENT_TYPE_DEVICE_UPDATE: "device_update"
		SWRVE_EVENT_TYPE_PURCHASE: "purchase"
		SWRVE_EVENT_TYPE_CURRENCY_GIVEN: "currency_given"
		SWRVE_EVENT_TYPE_IAP: "iap"
		SWRVE_EVENT_TYPE_SESSION_START: "session_start"
		SWRVE_EVENT_FIRST_SESSION_STRING: "Swrve.first_session"
		SWRVE_EVENT_CAMPAIGNS_DOWNLOADED: "Swrve.Messages.campaigns_downloaded"
		SWRVE_EVENT_AUTOSHOW_SESSION_START: "Swrve.Messages.showAtSessionStart"
		SWRVE_EVENTS_STORAGE: userID + "SWRVE_EVENTS_STORAGE"
		SWRVE_JSON_LOCATION: "pkg:/source/JSONFiles/"
		SWRVE_ASSETS_LOCATION: "tmp:/swrveAssets/"
		SWRVE_EQUAL: "eq"
		SWRVE_NOT_EQUAL: "not"
		SWRVE_AND: "and"
		SWRVE_OR: "or"
		SWRVE_BUTTON_DISMISS: "DISMISS"
		SWRVE_BUTTON_CUSTOM: "CUSTOM"
		SWRVE_DEFAULT_DELAY_FIRST_MESSAGE: 150
		SWRVE_DEFAULT_MAX_SHOWS: 99999
		SWRVE_DEFAULT_MIN_DELAY: 55
	}
end function

'gets the global Swrve Node'
function getSwrveNode() as Object
	return GetGlobalAA().global.Swrve
end function

'lig statements under the VERBOSE label and log level'
sub SWLogVerbose(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
	SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 5)
end sub

'lig statements under the DEBUG label and log level'
sub SWLogDebug(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
	SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 4)
end sub

'lig statements under the INFO label and log level'
sub SWLogInfo(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
	SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 3)
end sub

'lig statements under the WARN label and log level'
sub SWLogWarn(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
	SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 2)
end sub

'lig statements under the ERROR label and log level'
sub SWLogError(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
	SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 1)
end sub

'lig statements under the INFO label and log level'
sub SWLogAny(paramArr as Object, level as Integer)
	if NOT createObject("roAppInfo").IsDev() then return
	logLevel = getSwrveNode().logLevel
	if logLevel < level then return

	filtered = []
	for each item in paramArr
		if NOT (SWIsString(item) AND item = "nil") then filtered.push(item)
	end for

	if level = 1 then
		levelInfo = "ERROR]"
	else if level = 2 then
		levelInfo = "WARN]"
	else if level = 3 then
		levelInfo = "INFO]"
	else if level = 4 then
		levelInfo = "DEBUG]"
	else
		levelInfo = "VERBOSE]"
	end if

	logStr = mid(createObject("roDateTime").toISOString(), 12, 5) + " | [Swrve-" + levelInfo

	print logStr; tab(23); " | ";
	for each item in filtered
		print item; " ";
	end for
	print ""
end sub

function SWIsString(value as Dynamic) as Boolean
	valueType = type(value)
	return (valueType = "String") OR (valueType = "roString")
end function

'Safely returns the user resources from the dictionary'
function SwrveGetUserResourcesFromDictionarySafe(dict as Object) as Object
	if SwrveDictionaryHasUserResource(dict)
		return dict.data.user_resources
	else
		return {}
	end if
end function

'Safely returns the campaigns from the dictionary'
function SwrveGetUserCampaignsFromDictionarySafe(dict as Object) as Object
	if SwrveDictionaryHasUserCampaigns(dict)
		return dict.data.campaigns
	else
		return {}
	end if
end function

'Safely returns true if user is QA user'
function SwrveIsQAUser(dict as Object) as Object
	if dict <> Invalid AND dict.code = 200 AND dict.data <> Invalid AND dict.data.qa <> Invalid
		return true
	else
		return false
	end if
end function

'Returns true if dictionary is not malformed and contains user resources'
function SwrveDictionaryHasUserResource(dict as Object) as Boolean
	if dict <> Invalid AND dict.code = 200 AND dict.data <> Invalid AND dict.data.user_resources <> Invalid
		return true
	else
		return false
	end if
end function

'Returns true if dictionary is not malformed and contains user campaigns'
function SwrveDictionaryHasUserCampaigns(dict as Object) as Boolean
	if dict <> Invalid AND dict.code = 200 AND dict.data <> Invalid AND dict.data.campaigns <> Invalid
		return true
	else
		return false
	end if
end function

' Get from registry the latest seqnum, increment it, and save it back.
function SwrveGetSeqNum() as Integer

	'-1 in case we never used it before, it'll get incremented to 0
	previousSNAsString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_SEQNUM, "-1")
	previousSeqNum = StrToI(previousSNAsString)
	currentSeqNum = previousSeqNum + 1
	currentSNAsString = StrI(currentSeqNum)
	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_SEQNUM, currentSNAsString)
	return currentSeqNum
end function

' Returns an md5 hashed cipher of a string'
function SwrveMd5(str as String) as Object

	ba1 = CreateObject("roByteArray")
	ba1.FromAsciiString(str)
	digest = CreateObject("roEVPDigest")
	digest.Setup("md5")
	digest.Update(ba1)
	result = digest.Final()
	return result

end function

function SwrveGenerateToken(time as String, userId as String, apiKey as String, appId as String)
	hash = SwrveMd5(userId + time + apiKey)
	token = appId + "=" + userId + "=" + time + "=" + hash
	return token
end function

'Util function to display an image downloaded to assets folder.
'Used this way SwrveAddImageToNode(m.top, "image_1", 150, 150, 1.0)
'DisplayMode is optional and can be noScale, scaleToFit, scaleToFill, scaleToZoom'
function SwrveAddImageToNode(node as Object, imageID as String, x as Float, y as Float, scale as Object, displayMode = "noScale" as String) as Object

	img = createObject("roSGNode", "Poster")
	img.id = imageID
	img.loadSync = true
	img.uri = node.asset_location + imageID

	width = img.bitmapWidth * scale.w
	height = img.bitmapHeight * scale.h

	img.width = width
	img.height = height
	img.loadDisplayMode = displayMode

	supportedRes = SWGetSupportedResolution()

	screenCenterX = supportedRes.width / 2.0
	rightX = screenCenterX + (x - width / 2)

	screenCenterY = supportedRes.height / 2.0
	rightY = screenCenterY + (y - height / 2)

	img.translation = [rightX, rightY]
	node.appendChild(img)

	return img
end function


'Util function to display a button downloaded
'Used this way SwrveAddButtonToNode(m.top, "image_1", 150, 150, 1.0)
'DisplayMode is optional and can be noScale, scaleToFit, scaleToFill, scaleToZoom'
function SwrveAddButtonToNode(node as Object, imageID as String, x as Float, y as Float, scale as Object) as Object
	di = CreateObject("roDeviceInfo")
	screenSize = di.GetDisplaySize()

	supportedRes = SWGetSupportedResolution()

	screenRatioX = supportedRes.width / screenSize.w
	screenRatioY = supportedRes.height / screenSize.h

	img = createObject("roSGNode", "Poster")
	img.id = imageID
	img.loadSync = true
	img.uri = node.asset_location + imageID
	img.translation = [20, 20]

	width = img.bitmapWidth * scale.w
	height = img.bitmapHeight * scale.h

	img.width = width
	img.height = height

	btn = createObject("roSGNode", "Button")
	btn.id = imageID
	btn.height = height + 40
	btn.minWidth = width + 40
	btn.maxWidth = width + 40

	'This is to get rid of the dot or dash in the button.
	'It will give a console glyph error but it is the recommended way #justrokuthings'
	btn.focusedIconUri = " "
	btn.iconUri = " "

	screenCenterX = supportedRes.width / 2.0
	rightX = screenCenterX + (x * screenRatioX - btn.maxWidth / 2)

	screenCenterY = supportedRes.height / 2.0
	rightY = screenCenterY + (y * screenRatioY - btn.height / 2)

	btn.translation = [rightX, rightY]
	btn.showFocusFootprint = false
	btn.appendChild(img)
	node.appendChild(btn)

	return btn
end function

'Util function for copying the whole object, not just as a reference'
function SwrveCopy(obj as Object) as Object
	res = {}
	for each key in obj.Keys()
		res[key] = obj[key]
	end for
	return res
end function

'Util function for checking to see if the file(or folder) exists'
function SWCheckForFile(path as String) as Boolean
	pathParts = SWSplitFileFromPath(path)
	items = ListDir(pathParts[0]).toArray()
	for each item in items
		if item = pathParts[1] OR item = pathParts[1] + ".tmp" then
			return true
		end if
	end for
	return false
end function

'Util function for getting the last folder or file nice from a uri path.'
'Returns an array with index 0 is the path before the file/folder and index 1 is the file or folder name'
function SWSplitFileFromPath(path as String) as Object
	pathParts = path.tokenize("/").toArray()
	parts = ["", ""]

	if pathParts.count() >= 2 then
		parts[1] = pathParts.pop()
		parts[0] = pathParts.join("/") + "/"
	end if

	return parts
end function

'Returns 'value' if set or 'defaultValue' if not set.
function SWGetValue(value as Dynamic, defaultValue as Dynamic) as Dynamic
	if value <> Invalid then return value else return defaultValue
end function

'Util function depending on resolution, return supported width and height'
function SWGetSupportedResolution()
	return m.top.getScene().currentDesignResolution
end function


'------------- Duplicated from Swrve Client for Render Thread ------------'
' Read from persistence'
function SwrveGetObjectFromPersistence(source as String, default = "" as Dynamic) as Object
	sec = CreateObject("roRegistrySection", source)
	if sec.Exists(source)
		val = sec.Read(source)
		if val = Invalid OR val = ""
			return default
		else
			return ParseJSON(val)
		end if
	end if
	return default
end function

'Save to registry (persistent storage, do not use for large files)'
sub SwrveSaveObjectToPersistence(destination as String, value as Object)
	sec = CreateObject("roRegistrySection", destination)
	str = ""
	if value <> Invalid
		str = FormatJson(value)
	end if
	sec.Write(destination, str)
	sec.Flush()
end sub

' Read from persistence'
function SwrveGetStringFromPersistence(source as String, default = "" as Dynamic) as String
	sec = CreateObject("roRegistrySection", source)
	if sec.Exists(source)
		return sec.Read(source)
	end if
	return default
end function

'Save to registry (persistent storage, do not use for large files)'
sub SwrveSaveStringToPersistence(destination as String, value as String)
	sec = CreateObject("roRegistrySection", destination)
	sec.Write(destination, value)
	sec.Flush()
end sub

'------------- Date Utils --------------'
function SwrvePrintLoadingTimeFromAppLaunch(msg as String) as Void
	date = CreateObject("roDateTime")
	milli = date.GetMilliSeconds() / 1000
	milliDiff = milli - (getSwrveNode().startmilli / 1000)

	sec = date.AsSeconds()
	secDiff = sec - getSwrveNode().startseconds

	if(milliDiff < 0)
		milliDiff = 1 + milliDiff
		secDiff = secDiff - 1
	end if

	SwrvePrintMsg(msg + ": " + (secDiff + milliDiff).toStr() + " seconds since app launch")
end function

function SwrvePrintLoadingTimeFromTimestamp(msg as String, time as Object) as Void
	date = CreateObject("roDateTime")
	milli = date.GetMilliSeconds()
	milliDiff = milli - time.ms
	milliDiff = milliDiff / 1000
	sec = date.AsSeconds()
	secDiff = sec - time.s

	if(milliDiff < 0)
		milliDiff = 1 + milliDiff
		secDiff = secDiff - 1
	end if

	SwrvePrintMsg(msg + ": " + (secDiff + milliDiff).toStr() + " seconds")
end function

function SwrvePrintMsg(msg)
	SWLogInfo("--- [BENCHMARKING] --- ", msg)
end function

function SwrveGetTimestamp() as Object
	d = CreateObject("roDateTime")
	return { s: d.AsSeconds(), ms: d.GetMilliSeconds() }
end function
