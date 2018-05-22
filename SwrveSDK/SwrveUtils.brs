'Util function to log strings'
function SWLog(msg as String)
	if m.global.swrve.configuration.debug
		print "[SwrveSDK] " + msg
	end if
end function

'Util function to log ints'
function SWLogI(msg as Integer)
	if m.global.swrve.configuration.debug
		print "[SwrveSDK] " + StrI(msg)
	end if
end function

'Util function to log floats'
function SWLogF(msg as Float)
	if m.global.swrve.configuration.debug
		print "[SwrveSDK] " + Str(msg)
	end if
end function

'Safely returns the user resources from the dictionary'
Function GetUserResourcesFromDictionarySafe(dict as Object) as Object
	if DictionaryHasUserResource(dict) 
		return dict.data.user_resources
	else 
		return {}
	end if
End Function 

'Safely returns the campaigns from the dictionary'
Function GetUserCampaignsFromDictionarySafe(dict as Object) as Object
	if DictionaryHasUserCampaigns(dict) 
		return dict.data.campaigns
	else 
		return {}
	end if
End Function 

'Safely returns true if user is QA user'
Function IsQAUser(dict as Object) as Object
	if dict <>invalid and dict.code = 200 and  dict.data <> invalid and dict.data.qa <> invalid
		return true
	else 
		return false
	end if
End Function 

'Returns true if dictionary is not malformed and contains user resources'
Function DictionaryHasUserResource(dict as Object) as Boolean
	if dict <> invalid and dict.code = 200 and dict.data <> invalid and dict.data.user_resources <> invalid
		return true
	else 
		return false
	end if
End Function

'Returns true if dictionary is not malformed and contains user campaigns'
Function DictionaryHasUserCampaigns(dict as Object) as Boolean
	if dict <> invalid and dict.code = 200 and dict.data <> invalid and dict.data.campaigns <> invalid
		return true
	else 
		return false
	end if
End Function

' Get from registry the latest seqnum, increment it, and save it back.
Function SwrveGetSeqNum() as Integer

	'-1 in case we never used it before, it'll get incremented to 0
	previousSNAsString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_SEQNUM, "-1")
	previousSeqNum = StrToI(previousSNAsString)
	currentSeqNum = previousSeqNum + 1
	currentSNAsString = StrI(currentSeqNum)
	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_SEQNUM, currentSNAsString)
	return currentSeqNum
end Function

' Returns an md5 hashed cipher of a string'
Function md5(str as String) as Object

	ba1 = CreateObject("roByteArray")
	ba1.FromAsciiString(str)
	digest = CreateObject("roEVPDigest")
	digest.Setup("md5")
	digest.Update(ba1)
	result = digest.Final()
	return result

End Function

Function generateToken(time as String, userId as String, apiKey as String, appId as String)
    hash = md5(userId + time + apiKey)
    token = appId + "=" + userId + "=" + time + "=" + hash
    return token
End Function

'Util function to display an image downloaded to assets folder.
'Used this way SwrveAddImageToNode(m.top, "image_1", 150, 150, 1.0)
'DisplayMode is optional and can be noScale, scaleToFit, scaleToFill, scaleToZoom'
Function SwrveAddImageToNode(node as Object, imageID as String, x as float, y as float, scale as object, displayMode = "noScale" as String) as Object
	
    img = createObject("roSGNode", "Poster")
    img.id = imageID
    img.loadSync = true
    img.uri = SwrveConstants().SWRVE_ASSETS_LOCATION + imageID

    width = img.bitmapWidth * scale.w
    height = img.bitmapHeight * scale.h

    img.width = width
    img.height = height
    img.loadDisplayMode = displayMode
    screenCenterX = SwrveConstants().SWRVE_FHD_WIDTH/2.0
    rightX = screenCenterX + (x-width/2)

    screenCentery = SwrveConstants().SWRVE_FHD_HEIGHT/2.0
    rightY = screenCenterY + (y-height/2)
  
    img.translation = [rightX,  rightY]
    node.appendChild(img)

    return img
End Function


'Util function to display a button downloaded 
'Used this way SwrveAddButtonToNode(m.top, "image_1", 150, 150, 1.0)
'DisplayMode is optional and can be noScale, scaleToFit, scaleToFill, scaleToZoom'
Function SwrveAddButtonToNode(node as Object, imageID as String, x as float, y as float, scale as object) as Object
	di = CreateObject("roDeviceInfo")
    screenSize = di.GetDisplaySize()
    screenRatioX = SwrveConstants().SWRVE_FHD_WIDTH / screenSize.w
    screenRatioY = SwrveConstants().SWRVE_FHD_HEIGHT / screenSize.h
   
    img = createObject("roSGNode", "Poster")
    img.id = imageID
    img.loadSync = true
    img.uri = SwrveConstants().SWRVE_ASSETS_LOCATION + imageID
    img.translation = [20, 20]

    width = img.bitmapWidth * scale.w
    height = img.bitmapHeight * scale.h

    img.width = width
    img.height = height

    btn = createObject("roSGNode", "Button")
    btn.id = imageID
    btn.height = height+40
    btn.minWidth = width+40
    btn.maxWidth = width+40

    'This is to get rid of the dot or dash in the button. 
    'It will give a console glyph error but it is the recommended way #justrokuthings'
    btn.focusedIconUri = " "
    btn.iconUri = " "

    screenCenterX = SwrveConstants().SWRVE_FHD_WIDTH/2.0
    rightX = screenCenterX + (x*screenRatioX-btn.maxWidth/2)

    screenCentery = SwrveConstants().SWRVE_FHD_HEIGHT/2.0
    rightY = screenCenterY + (y*screenRatioY-btn.height/2)
 
    btn.translation = [rightX,  rightY]
    btn.showFocusFootprint = false
    btn.appendChild(img)
    node.appendChild(btn)

    return btn
End Function

'Util function for copying the whole object, not just as a reference'
Function SWCopy(obj as Object) as Object
	res = {}
	for each key in obj.Keys()
		res[key] = obj[key]
	end for
	return res
End Function