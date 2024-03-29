' Used in the main thread and in the Render thread.

'gets the global Swrve Node'
function getSwrveNode(functionName = "") as Object
  if GetGlobalAA().global.Swrve <> Invalid 
    return GetGlobalAA().global.Swrve
  else
    if createObject("roAppInfo").IsDev() 
      print "[Swrve-Error] "; functionName; " Swrve Node is invalid, SDK has not be intialised yet"
    end if
    return Invalid
  end if 
end function

'log statements under the VERBOSE label and log level'
sub SWLogVerbose(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
  SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 5)
end sub

'log statements under the DEBUG label and log level'
sub SWLogDebug(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
  SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 4)
end sub

'log statements under the INFO label and log level'
sub SWLogInfo(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
  SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 3)
end sub

'log statements under the WARN label and log level'
sub SWLogWarn(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
  SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 2)
end sub

'log statements under the ERROR label and log level'
sub SWLogError(param1 as Dynamic, param2 = "nil", param3 = "nil", param4 = "nil", param5 = "nil", param6 = "nil", param7 = "nil", param8 = "nil", param9 = "nil", param10 = "nil")
  SWLogAny([param1, param2, param3, param4, param5, param6, param7, param8, param9, param10], 1)
end sub

'log statements under the INFO label and log level'
sub SWLogAny(paramArr as Object, level as Integer)
  if NOT createObject("roAppInfo").IsDev() then return
  if getSwrveNode("SWLogAny") = Invalid then return
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
  img.uri = m.top.asset_location + imageID

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
  img.uri = m.top.asset_location + imageID
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
  btn.scaleRotateCenter = [width/2.0, height/2.0]
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

'Returns 'value' if set or 'defaultValue' if not set.
function SWGetValue(value as Dynamic, defaultValue as Dynamic) as Dynamic
  if value <> Invalid then return value else return defaultValue
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

'Util function depending on resolution, return supported width and height'
function SWGetSupportedResolution()
	return m.top.getScene().currentDesignResolution
end function

'------------- Date Utils --------------'
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
  SWLogInfo("--- [BENCHMARKING] --- " + msg)
end function

function SwrveGetTimestamp() as Object
  d = CreateObject("roDateTime")
  return { s: d.AsSeconds(), ms: d.GetMilliSeconds() }
end function
