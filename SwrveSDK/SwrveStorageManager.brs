' Utils function all related to storing and restoring
function SwrveStorageManager() as Object
	this = {}
	this.SwrveSaveStringToFile = SwrveSaveStringToFile
	this.SwrveGetStringFromFile = SwrveGetStringFromFile
	this.SwrveSaveObjectToFile = SwrveSaveObjectToFile
	this.SwrveGetObjectFromFile = SwrveGetObjectFromFile
	this.SwrveSaveQueueToStorage = SwrveSaveQueueToStorage
	this.SwrveGetQueueFromStorage = SwrveGetQueueFromStorage
	this.SwrveClearQueueFromStorage = SwrveClearQueueFromStorage
	this.SwrveClearKeyFromStorage = SwrveClearKeyFromStorage
	this.SwrveClearKeyFromPersistence = SwrveClearKeyFromPersistence
	this.SwrveGetStringFromPersistence = SwrveGetStringFromPersistence
	this.SwrveSaveStringToPersistence = SwrveSaveStringToPersistence
	this.SwrveGetObjectFromPersistence = SwrveGetObjectFromPersistence
	this.SwrveSaveObjectToPersistence = SwrveSaveObjectToPersistence
	return this
end function

function GetEventFilePath(useQaPath = false as boolean)
	path = SwrveConstants().SWRVE_EVENTS_LOCATION + SwrveSDK().SwrveGetCurrentUserID() + SwrveConstants().SWRVE_EVENTS_FILENAME
	if useQaPath = true
		path = path + "QA"
	end if
 	return path
end function 

' Saves the queue to persistent storage so that we can restore it in between sessions
function SwrveSaveQueueToStorage(events as Object, useQaPath = false as boolean)
	strData = FormatJson(events)
	path = GetEventFilePath(useQaPath)
	SwrveSaveStringToFile(strData, path)
end function

' Restore what was saved from the buffer'
function SwrveGetQueueFromStorage(useQaPath = false as boolean) as Object
	path = GetEventFilePath(useQaPath)
	eventsString = SwrveGetStringFromFile(path)
	if eventsString = ""
		return []
	end if
	return ParseJSON(eventsString)
end function

'Clear the queue that was saved to persistent storage'
function SwrveClearQueueFromStorage(useQaPath = false as boolean)
	SwrveSaveQueueToStorage([],useQaPath)
end function

function SwrveClearKeyFromStorage(key as String)
	SwrveSaveStringToFile("", key)
end function

function SwrveClearKeyFromPersistence(key as String)
	SwrveSaveStringToPersistence(key, "")
end function

' Save to file, will not persist between launches'
function SwrveSaveObjectToFile(obj as Object, filename as String) as Boolean
	success = WriteAsciiFile(filename, FormatJSON(obj))
	return success
end function

'Read object from storage'
function SwrveGetObjectFromFile(filename as String) as Object
	val = ReadAsciiFile(filename)
	if val = ""
		return ""
	else
		return ParseJSON(val)
	end if
end function

' Save to file, will not persist between launches'
function SwrveSaveStringToFile(str as String, filename as String) as Boolean
	SWLogVerbose("Writing", str, "to", filename)
	success = WriteAsciiFile(filename, str)
	return success
end function

'Read string from tmp:/ storage'
function SwrveGetStringFromFile(filename as String) as String
	if SWCheckForFile(filename)
		val = ReadAsciiFile(filename)
		SWLogVerbose("Reading:", filename, "value:",val)
		return val
	else
		SWLogVerbose("Attempt to read file that does not exist", filename)
	end if
	return ""
end function

' Read from persistence'
function SwrveGetObjectFromPersistence(source as String, default = "" as Dynamic) as Object
	sec = CreateObject("roRegistrySection", source)
	if sec.Exists(source)
		val = sec.Read(source)
		SWLogVerbose("Reading:", source, "value:", val)
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
	SWLogVerbose("Writing:", str, "to:", destination)
	sec.Write(destination, str)
	sec.Flush()
end sub

' Read from persistence'
function SwrveGetStringFromPersistence(source as String, default = "" as Dynamic) as String
	sec = CreateObject("roRegistrySection", source)
	if sec.Exists(source)
		val = sec.Read(source)
		SWLogVerbose("Reading:", source, "value:", val)
		return val
	end if
	return default
end function

'Save to registry (persistent storage, do not use for large files)'
function SwrveSaveStringToPersistence(destination as String, value as String)
	sec = CreateObject("roRegistrySection", destination)
	sec.Write(destination, value)
	SWLogVerbose("Writing:", value, "to:", destination)
	sec.Flush()
end function

function SwrveIsCampaignFileValid(persistentCampaign as String) as Boolean
	persistentSignature = SwrveGetValueFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME)
	if persistentSignature = SwrveMd5(persistentCampaign)
		return true
	else
		SWLogWarn("Campaign file has been compromised. Reloading.")
		return false
	end if
end function

function SwrveIsResourceFileValid(persistentResource) as Boolean
	persistentSignature = SwrveGetValueFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME)
	if persistentSignature = SwrveMd5(persistentResource)
		return true
	else
		SWLogWarn("Resource file has been compromised. Reloading.")
		return false
	end if
end function

function SwrveGetValueFromSection(sectionName as String, key as String) as String
	sec = CreateObject("roRegistrySection", sectionName)
	if sec.Exists(key)
		val = sec.Read(key)
		SWLogVerbose("Reading:", key, "value:", val, "from section:", sectionName)
		return val
	end if
	return ""
end function

function SwrveWriteValueToSection(sectionName as String, key as String, value as String)
	sec = CreateObject("roRegistrySection", sectionName)
	sec.Write(key, value)
	SWLogVerbose("Writing:", key, "value:", value, "in section:", sectionName)
	sec.Flush()
end function

function SwrveDeleteSection(sectionName as String)
	ro = CreateObject("roRegistry")
	for each section in ro.GetSectionList()
		if section = sectionName
			SWLogVerbose("Deleting registry section", section)
			ro.delete(section)
			exit for
		end if
	end for
	ro.flush()
end function

function SwrveDeleteKeyFromSection(sectionName as String, key as String)
	sec = CreateObject("roRegistrySection", sectionName)
	if sec.Exists(key)
		SWLogVerbose("Deleting", key, "in section", sectionName)
		sec.Delete(key)
		sec.Flush()
	end if
end function
