'Structure that will provide the array of resources and a method for getting a specific resource'
function SwrveResourceManager(userResources as Object) as Object
	this = {}
	this.userResources = userResources
	this.SwrveResource = SwrveResource
	return this
end function

'Method for getting and constructing a Resource object. This resource object will have all the util functions
'for getting attributes as types.
function SwrveResource(name as String) as Object
	for each resource in m.userResources
		if resource.name = name
			return SwrveResourceBuilder(resource)
			EXIT FOR
		end if
	end for
	return {}
end function

'Resource structure, with attributes and attribute getters'
function SwrveResourceBuilder(dict as Object) as Object
	res = {}
	res.append(dict)

	res.SwrveAttributeAsString = SwrveAttributeAsString
	res.SwrveAttributeAsInteger = SwrveAttributeAsInteger
	res.SwrveAttributeAsFloat = SwrveAttributeAsFloat
	res.SwrveAttributeAsBoolean = SwrveAttributeAsBoolean
	res.SwrveAttributeAsColour = SwrveAttributeAsColour
	return res
end function

'attribute getters will actually be straightforward as all attribute will come down the json as string'
function SwrveAttributeAsString(name as String, default = "" as String) as String
	attribute = box(m[name])
	if attribute <> invalid
		return attribute
	else
		return default
	end if
end function

function SwrveAttributeAsInteger(name as String, default = 0 as Integer) as Integer
	attribute = box(m[name])
	if attribute <> invalid
		asInt = attribute.ToInt()
		if asInt <> invalid
			if StrI(asInt).Trim() <> attribute 'It's not possible to convert it to a number <- conversion failed
				return default
			else
				return AsInt
			end if
		else 
			return default
		end if
	else
		return default
	end if
end function

function SwrveAttributeAsBoolean(name as String, default = false as Boolean) as Boolean
	attribute = box(m[name])
	if attribute <> invalid
		if attribute = "1" or LCase(attribute) = "true"
			return true
		else if attribute = "0" or LCase(attribute) = "false"
			return false
		else
			return default
		end if
	else
		return default
	end if
end function

function SwrveAttributeAsFloat(name as String, default = 0.0 as Float) as Float
	attribute = box(m[name])
	if attribute <> invalid
		asFloat = attribute.ToFloat()
		if asFloat <> invalid
			if Str(asFloat).Trim() <> attribute 'It's not possible to convert it to a float <- conversion failed
				return default
			else
				return asFloat
			end if
		else 
			return default
		end if
	else
		return default
	end if
end function

'Colours in brightscript are 0xRRGGBBAA or 0xRRGGBB'
function SwrveAttributeAsColour(name as String, default = "0xFFFFFF" as String) as String
	attribute = box(m[name])
	if attribute <> invalid
		attribute = attribute.replace("#", "")
		if Left(attribute, 2) <> "0x"
			return "0x" + attribute
		else
			return attribute
		end if
	else
		return default
	end if
end function

function SwrveLoadUserResourcesFromPersistence() as Object
	resourceLocalSource = SwrveConstants().SWRVE_USER_RESOURCES_FILENAME
	if SwrveIsResourceFileValid() 'checks that signature is still correct'
		resourceString = SwrveGetStringFromPersistence(resourceLocalSource)
		if resourceString = ""
			return {}
		end if
		return ParseJSON(resourceString)
	else
		return {}
	end if

end function