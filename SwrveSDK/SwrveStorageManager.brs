' Utils function all related to storing and restoring
Function SwrveStorageManager() as Object
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
End Function

Function SwrveGetEventStoragePath() as String
	return SwrveConstants().SWRVE_EVENTS_STORAGE
End Function

' Saves the queue to persistent storage so that we can restore it in between sessions
Function SwrveSaveQueueToStorage(events as Object)
	strData = FormatJson(events)
	SwrveSaveStringToPersistence(SwrveGetEventStoragePath(), strData)
End Function

' Restore what was saved from the buffer'
Function SwrveGetQueueFromStorage() as Object
	eventsString = SwrveGetStringFromPersistence(SwrveGetEventStoragePath())
	if eventsString = ""
		return eventsString
	end if
	return ParseJSON(eventsString)
End function

'Clear the queue that was saved to persistent storage'
Function SwrveClearQueueFromStorage()
	strData = FormatJson([])
	SwrveSaveStringToPersistence(SwrveGetEventStoragePath(), strData)
End Function

Function SwrveClearKeyFromStorage(key as String)
	SwrveSaveStringToFile("", key)	
End Function

Function SwrveClearKeyFromPersistence(key as String)
	SwrveSaveStringToPersistence(key, "")
End Function

' Save to file, will not persist between launches'
Function SwrveSaveObjectToFile(obj as Object, filename as String) as Boolean
	success = WriteAsciiFile(filename, FormatJSON(obj))
	return success
End Function

'Read object from tmp:/ storage' 
Function SwrveGetObjectFromFile(filename as String) as Object
	val = ReadAsciiFile(filename)
	if val = ""
		return ""
	else 		
		return ParseJSON(val)
	end if
End Function


' Save to file, will not persist between launches'
Function SwrveSaveStringToFile(str as String, filename as String) as Boolean
	success = WriteAsciiFile(filename, str)
	return success
End Function

'Read string from tmp:/ storage' 
Function SwrveGetStringFromFile(filename as String) as String
	return ReadAsciiFile(filename)
End Function

' Read from persistence'
Function SwrveGetObjectFromPersistence(source as String, default = "" as Dynamic) As Object
    sec = CreateObject("roRegistrySection", source)
    if sec.Exists(source)
    	val = sec.Read(source)
    	if val = invalid or val = ""
    		return default
    	else
        	return ParseJSON(val)
        end if
    end if
    return default
End Function

'Save to registry (persistent storage, do not use for large files)'
Sub SwrveSaveObjectToPersistence(destination As String, value As Object)
    sec = CreateObject("roRegistrySection", destination)
    str = ""
    if value <> invalid
    	str = FormatJson(value)
    end if
    sec.Write(destination, str)
    sec.Flush()
End Sub

' Read from persistence'
Function SwrveGetStringFromPersistence(source as String, default = "" as Dynamic) As String
    sec = CreateObject("roRegistrySection", source)
    if sec.Exists(source)
        return sec.Read(source)
    end if
    return default
End Function

'Save to registry (persistent storage, do not use for large files)'
Sub SwrveSaveStringToPersistence(destination As String, value As String)
    sec = CreateObject("roRegistrySection", destination)
    sec.Write(destination, value)
    sec.Flush()
End Sub

Function SwrveIsCampaignFileValid() as Boolean
	persistentCampaign = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME)
	persistentSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME)
	if persistentSignature = md5(persistentCampaign)
		return true
	else
		SWLog("Campaign file has been compromised. Reloading.")
		return false
	end if
End Function

Function SwrveIsResourceFileValid() as Boolean
	persistentResource = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_RESOURCES_FILENAME)
	persistentSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME)
	if persistentSignature = md5(persistentResource)
		return true
	else
		SWLog("Resource file has been compromised. Reloading.")
		return false
	end if
End Function

Function SwrveClearWholePersistence()
	ro = CreateObject("roRegistry")
    for each section in ro.GetSectionList()
        ro.delete(section)
    end for
    ro.flush()
End Function