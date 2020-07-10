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
	this.SwrveClearWholePersistence = SwrveClearWholePersistence
	return this
end function

function SwrveGetEventStoragePath() as String
	return SwrveConstants().SWRVE_EVENTS_STORAGE
end function

' Saves the queue to persistent storage so that we can restore it in between sessions
function SwrveSaveQueueToStorage(events as Object)
	strData = FormatJson(events)
	SwrveSaveStringToPersistence(SwrveGetEventStoragePath(), strData)
end function

' Restore what was saved from the buffer'
function SwrveGetQueueFromStorage() as Object
	eventsString = SwrveGetStringFromPersistence(SwrveGetEventStoragePath())
	if eventsString = ""
		return eventsString
	end if
	return ParseJSON(eventsString)
End function

'Clear the queue that was saved to persistent storage'
function SwrveClearQueueFromStorage()
	strData = FormatJson([])
	SwrveSaveStringToPersistence(SwrveGetEventStoragePath(), strData)
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

'Read object from tmp:/ storage' 
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
	success = WriteAsciiFile(filename, str)
	return success
end function

'Read string from tmp:/ storage' 
function SwrveGetStringFromFile(filename as String) as String
	return ReadAsciiFile(filename)
end function

function SwrveIsCampaignFileValid() as Boolean
	persistentCampaign = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME)
	persistentSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME)
	if persistentSignature = SwrveMd5(persistentCampaign)
		return true
	else
		SWLogWarn("Campaign file has been compromised. Reloading.")
		return false
	end if
end function

function SwrveIsResourceFileValid() as Boolean
	persistentResource = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_RESOURCES_FILENAME)
	persistentSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME)
	if persistentSignature = SwrveMd5(persistentResource)
		return true
	else
		SWLogWarn("Resource file has been compromised. Reloading.")
		return false
	end if
end function

function SwrveClearWholePersistence()
	ro = CreateObject("roRegistry")
    for each section in ro.GetSectionList()
        ro.delete(section)
    end for
    ro.flush()
end function
