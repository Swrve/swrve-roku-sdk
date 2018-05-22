' Named event creation & queue'
function SwrveEvent(swrveClient as Object, eventName as String, payload = {} as Object) as void
    m.global = getGlobalAA().global
   	event = SwrveCreateEvent(eventName, payload)
   	if SwrveIsEventValid(event)
   		CheckEventForTriggers(swrveClient, event)
   		SwrveAddEventToQueue(swrveClient, event)
   	end if
   	SynchroniseSwrveInstance(swrveClient)
end function

'Create a user update with a dictionary of attributes'
function SwrveUserUpdate(swrveClient as Object, attributes as Object) as void
	ua = SwrveCreateUserUpdate(attributes)
	if ua <> invalid
		if ua.attributes <> invalid
			SwrveAddEventToQueue(swrveClient, ua)
		end if
	end if
end function

'Create a user update with a name and a date'
function SwrveUserUpdateWithDate(swrveClient as Object, name as String, date as Object) as void
	ua = SwrveCreateUserUpdateWithDate(name, date)
	if ua <> invalid
		if ua.attributes <> invalid
			SwrveAddEventToQueue(swrveClient, ua)
		end if
	end if
end function

'Create a purchase event, with quantity, item name, price and currency'
function SwrvePurchaseEvent(swrveClient as Object, itemQuantity as Integer, itemName as String, itemPrice as Float, itemCurrency as String) as void
	pa = SwrveCreatePurchaseEvent(StrI(itemQuantity).Trim(), itemName, Str(itemPrice).Trim(), itemCurrency)
	if pa <> invalid
		SwrveAddEventToQueue(swrveClient, pa)
	end if
	swrveClient.SwrveForceFlush()
end function

'Create a currency given event, with given currency name and the given amount'
function SwrveCurrencyGiven(swrveClient as Object, givenCurrency as String, givenAmount as Integer) as void
	cg = SwrveCreateCurrencyGiven(givenCurrency, StrI(givenAmount).Trim())
	if cg <> invalid
		SwrveAddEventToQueue(swrveClient, cg)
	end if
end function

'Create a IAP event, without receipt'
function SwrveIAPWithoutReceipt(swrveClient as Object, product as Object, rewards as Object, currency as String, app_store) as void
	pa = SwrveCreateIAPWithoutReceipt(product, rewards, currency, app_store)
	if pa <> invalid and pa.count() > 0
		SwrveAddEventToQueue(swrveClient, pa)
	end if
	swrveClient.SwrveForceFlush()
end function

'Create a First session event and queues it'
function SwrveFirstSession(swrveClient as Object) as void
	ua = SwrveCreateEvent(SwrveConstants().SWRVE_EVENT_FIRST_SESSION_STRING)
	if ua <> invalid
		if ua.name <> invalid
			SwrveAddEventToQueue(swrveClient, ua)
		end if
	end if
end function

'Create a session start event and queues it'
function SwrveSessionStart(swrveClient as Object) as void
	ua = SwrveCreateSessionStartEvent()
	if ua <> invalid
		SwrveAddEventToQueue(swrveClient, ua)
	end if
end function

' Named event creation'
function SwrveCreateEvent(eventName as String, payload = {} as Object) as Object
 	this = {}
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_EVENT
    
    this.payload = payload
    this.name = eventName
    this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    return this
end function

'Create a click event (IAM)'
function SwrveClickEvent(swrveClient as object, message as Object, buttonName as String) as Object
	SwrveEvent(swrveClient, "Swrve.Messages.Message-"+StrI(message.id).Trim()+".click", { "name": buttonName})
end function

'Create an impression event (IAM)'
function SwrveImpressionEvent(swrveClient as object, message as Object) as Object
    m.global = getGlobalAA().global

	format = message.template.formats[0]
	SwrveEvent(swrveClient, "Swrve.Messages.Message-"+StrI(message.id).Trim()+".impression", { 
		"orientation": format.orientation,
        "size": StrI(format.size.w.value).Trim()+"x"+StrI(format.size.h.value).Trim(),
        "format": format.name
       })
	print "Sending impression event!!!!!!!"
end function

'Create a Returned event (IAM)'
function SwrveReturnedMessageEvent(swrveClient as object, message as Object) as Object
	SwrveEvent(swrveClient, "Swrve.Messages.message_returned", { "id": message.id})
end function

' Generic user update event'
function SwrveCreateUserUpdate(attributes as Object) as Object
	this = {}
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_USER_UPDATE
   
    this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()

    this.attributes = attributes

    return this
end function

' User update event creation'
function SwrveCreatePurchaseEvent(quantity as String, itemName as String, cost as String, currency as String) as Object
 	this = {}
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_PURCHASE
	this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()

	this.quantity = quantity
	this.item = itemName
	this.cost = cost
	this.currency = currency

    return this
end function

'Currency Given event creation'
function SwrveCreateCurrencyGiven(givenCurrency as String, givenAmount as String)
	this = {}
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_CURRENCY_GIVEN
	this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()

	this.given_currency = givenCurrency
	this.given_amount = givenAmount

    return this
end function

'Create IAP without receipt'
function SwrveCreateIAPWithoutReceipt(product as Object, rewards as Object, currency as String, app_store) as Object
	this = {}
    	
    if product.product_id = invalid
    	SWLog("Product ID mustn't be nil")
    	return this
    end if	
  
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_IAP
	this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()

    this.quantity = product.quantity
    this.app_store = app_store
    this.product_id = product.product_id
    this.item = product.name
    this.cost = product.cost
    this.local_currency = currency
    this.rewards = rewards.rewardsData 

    return this
End Function

' Generic user update event'
function SwrveCreateUserUpdateWithDate(name as String, date as Object) as Object
	this = {}
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_USER_UPDATE
   
    this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()

    if date <> invalid and type(date) = "roDateTime"
	    this.attributes = {}
	    this.attributes.AddReplace(name, date.ToISOString())
	end if
    return this
end function


' session start event'
function SwrveCreateSessionStartEvent() as Object
	this = {}
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_SESSION_START
   
    this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    return this
end function

function SwrveCampaignsDownloaded(swrveClient as Object) as void
	ids = ""
	idx = 0
	for each campaign in swrveClient.userCampaigns.campaigns
		id = campaign.id
		if idx > 0
			ids = ids + ","
		end if
		ids = ids + id.ToStr().Trim()
		idx++
	end for
	payload = { "ids" : ids, "Count": idx}
	SwrveEvent(swrveClient, SwrveConstants().SWRVE_EVENT_CAMPAIGNS_DOWNLOADED, payload)
end Function

' Add event to the general event queue 
function SwrveAddEventToQueue(swrveClient as Object, event as Object) as void
	if swrveClient.configuration.mutedMode = false		
		swrveClient.eventsQueue.push(event)
		SwrveCheckQueueSize(swrveClient)
		oldqueue = SwrveGetQueueFromStorage()
		if oldqueue <> invalid and type(oldqueue) = "roArray"
			oldqueue.push(event)
		else 
			oldqueue = [event]
		end if
		SwrveSaveQueueToStorage(oldqueue)
		SwrveFlushQueue(swrveClient)
		SynchroniseSwrveInstance(swrveClient)
	end if

end function

'Will check the queue size compared to max size, and flush if we get over'
function SwrveCheckQueueSize(swrveClient as Object) as void
	if SwrveQueueSize(swrveClient) > swrveClient.configuration.queueMaxSize
		SWLog("Event queue is too large. Sending events now to backend and flushing buffer")
		SwrveForceFlush()
	end if
end function

' Flush the queue
function SwrveFlushQueue(swrveClient as Object) as void
	swrveClient.eventsQueue.clear()
	SynchroniseSwrveInstance(swrveClient)
end function

' Returns the size of the queue
function SwrveQueueSize(swrveClient as Object) as Integer
	return swrveClient.eventsQueue.Count()
end function

' Build the meta fields that are at the root of the json'
Function BuildBatchMeta(swrveClient as Object) as Object
	jsonObject = {}
	jsonObject.user = swrveClient.configuration.userID
	jsonObject.device_id = swrveClient.configuration.deviceId.ToInt()
	jsonObject.app_version = swrveClient.configuration.version
	jsonObject.session_token = swrveClient.configuration.session_token
	return jsonObject
End Function

' Build the batch json'
Function BuildBatchFromQueue(swrveClient as Object) as Object
	jsonObject = BuildBatchMeta(swrveClient)
	if swrveClient.eventsQueue.count() < 1
		swrveClient.eventsQueue = CheckForSavedQueue(swrveClient)
	end if
	jsonObject.data = swrveClient.eventsQueue
	return jsonObject
end Function

Function SwrveIsEventValid(event as Object) as boolean
	isValid = event <> invalid
	hasName = event.name <> invalid and event.name <> ""
	noSpaces = Instr(1, event.name, " ") = 0 'From documentation, the first position is 1.'
	'For when I know the max length'
	'nameShortEnough = Length(event.name) < 256
	hasSeq = event.seqnum <> invalid and event.seqnum > -1
	hasTime = event.time <> invalid
	if isValid and hasName and hasSeq and hasTime and noSpaces
		return true
	else
		message = "Event was malformed - "
		if hasName = false
			message = message + "Event name can't be empty "
		end if
		if noSpaces = false
			message = message + "Event name can't contains spaces "
		end if	
		' if nameShortEnough = false
		' 	message = message + "Event name is too long"
		' end if
		SWLog(message)
	end if
end Function

' Post the batch json to the batch endpoint. On success flush the queue, on failure, we'll see when we start caching
Function PostQueueAndFlush(swrveClient as Object) as Object
	payload = BuildBatchFromQueue(swrveClient)
	SWLog("Preparing request")
	response = invalid

	if payload <> invalid and payload.data.count() > 0
		response = SendBatchPOST(payload)
		if response <> invalid
			if response.Code < 400 'Success or redirection: Events have gone through'
				SWLog("Success sending events to Swrve")
			else if response.code < 500 'Failure, Client error, will not retry'
				SWLog("HTTP Error - not adding events back into the queue : " + response.data)
			else if response.code >= 500 'Failure, Server error, will retry'
				SWLog("Error sending event data to Swrve (" + response.data + ") Adding data back onto unsent message buffer")
			    SaveQueueToPersistence(swrveClient)
			end if
			swrveClient.SwrveFlushQueue(swrveClient)

		end if
	end if
	return response
End Function

