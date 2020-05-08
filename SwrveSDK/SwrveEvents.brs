' Named event creation & queue'
function SwrveEvent(eventName as String, payload = {} as Object) as void
	SWLog("SwrveEvent() eventName:" + eventName)
   	event = SwrveCreateEvent(eventName, payload)
   	if SwrveIsEventValid(event)
   		SwrveCheckEventForTriggers(event)
   		SwrveAddEventToQueue(event)
   		if(SwrveIsLoggingQAUser())
   			SwrveAddEventToQueue(SwrveCreateWrappedEvent(event))
   		end if
   	end if
end function


'Create a device update with a dictionary of attributes'
function SwrveDeviceUpdate(attributes as Object) as void
	ua = SwrveCreateDeviceUpdate(attributes)
	if ua <> invalid
		if ua.attributes <> invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
				SwrveAddEventToQueue(SwrveCreateWrappedUserUpdate(ua))
			end if
		end if
	end if
end function

'Create a user update with a dictionary of attributes'
function SwrveUserUpdate(attributes as Object) as void
	ua = SwrveCreateUserUpdate(attributes)
	if ua <> invalid
		if ua.attributes <> invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
				SwrveAddEventToQueue(SwrveCreateWrappedUserUpdate(ua))
			end if
		end if
	end if
end function

'Create a user update with a name and a date'
function SwrveUserUpdateWithDate(name as String, date as Object) as void
	ua = SwrveCreateUserUpdateWithDate(name, date)
	if ua <> invalid
		if ua.attributes <> invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
				SwrveAddEventToQueue(SwrveCreateWrappedUserUpdate(ua))
			end if
		end if
	end if
end function

'Create a purchase event, with quantity, item name, price and currency'
function SwrvePurchaseEvent(itemQuantity as Integer, itemName as String, itemPrice as Float, itemCurrency as String) as void
	pa = SwrveCreatePurchaseEvent(StrI(itemQuantity).Trim(), itemName, Str(itemPrice).Trim(), itemCurrency)
	if pa <> invalid
		SwrveAddEventToQueue(pa)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQueue(SwrveCreateWrappedPurchaseEvent(pa))
		end if
	end if
end function

'Create a currency given event, with given currency name and the given amount'
function SwrveCurrencyGiven(givenCurrency as String, givenAmount as Integer) as void
	cg = SwrveCreateCurrencyGiven(givenCurrency, StrI(givenAmount).Trim())
	if cg <> invalid
		SwrveAddEventToQueue(cg)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQueue(SwrveCreateWrappedCurrencyGiven(cg))
		end if
	end if
end function

'Create a IAP event, without receipt'
function SwrveIAPWithoutReceipt(product as Object, rewards as Object, currency as String, app_store) as void
	pa = SwrveCreateIAPWithoutReceipt(product, rewards, currency, app_store)
	if pa <> invalid and pa.count() > 0
		SwrveAddEventToQueue(pa)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQueue(SwrveCreateWrappedIAPWithoutReceipt(pa))
		end if
	end if
end function

'Create a First session event and queues it'
function SwrveFirstSession() as void
	ua = SwrveCreateEvent(SwrveConstants().SWRVE_EVENT_FIRST_SESSION_STRING)
	if ua <> invalid
		if ua.name <> invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
	   			SwrveAddEventToQueue(SwrveCreateWrappedEvent(ua))
	   		end if
		end if
	end if
end function

'Create a session start event and queues it'
function SwrveSessionStart() as void
	ua = SwrveCreateSessionStartEvent()
	if ua <> invalid
		SwrveAddEventToQueue(ua)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQueue(SwrveCreateWrappedSessionStart(ua))
		end if
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

function SwrveCreateWrappedEvent(event as Object) as object
	payload = {}
	for each key in event.payload.Keys()
		payload.AddReplace(key, event.payload[key])
	end for

	this = {}
	this.type = "qa_log_event"
	now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    this.log_type = "event"
    this.log_source = "sdk"
    this.log_details = {
    	type : "event",
    	parameters: {
    		name: event.name,
    		payload: payload
    		},
    	seqnum : SwrveGetSeqNum(),
    	client_time: now.toTimeToken()
    }
    return this
end function


'Create a click event (IAM)'
function SwrveClickEvent(message as Object, buttonName as String) as Object
	SwrveEvent("Swrve.Messages.Message-"+StrI(message.id).Trim()+".click", { "name": buttonName})
end function

'Create an impression event (IAM)'
function SwrveImpressionEvent(message as Object) as Object
    eventName = "Swrve.Messages.Message-"+StrI(message.id).Trim()+".impression"
	format = message.template.formats[0]
	payload = { 
		"orientation": format.orientation,
        "size": StrI(format.size.w.value).Trim()+"x"+StrI(format.size.h.value).Trim(),
        "format": format.name
       }
	SwrveEvent(eventName, payload)
end function

'Create a Returned event (IAM)'
function SwrveReturnedMessageEvent(message as Object) as Object
	'TODO new campaign triggered qa log
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


' Generic device update event'
function SwrveCreateDeviceUpdate(attributes as Object) as Object
	this = {}
    this.type = SwrveConstants().SWRVE_EVENT_TYPE_DEVICE_UPDATE
   
    this.seqnum = SwrveGetSeqNum()
    now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()

    this.attributes = attributes

    return this
end function

function SwrveCreateWrappedUserUpdate(event as Object) as object

	attributes = {}
	for each key in event.attributes.Keys()
		attributes.AddReplace(key, event.attributes[key])
	end for

	this = {}
	this.type = "qa_log_event"
	now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    this.log_type = "event"
    this.log_source = "sdk"
    this.log_details = { 
    	type : "user",
    	parameters: { 
    		"attributes" : attributes
    		},
    	seqnum : SwrveGetSeqNum(),
    	client_time: now.toTimeToken()
    }

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


function SwrveCreateWrappedPurchaseEvent(event as Object) as object
	this = {}
	this.type = "qa_log_event"
	now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    this.log_type = "event"
    this.log_source = "sdk"
    this.log_details = { 
    	type : "purchase",
    	parameters: {
    		quantity: event.quantity,
    		item: event.item,
    		cost: event.cost,
    		currency: event.currency
    		},
    	seqnum :SwrveGetSeqNum(),
    	client_time: now.toTimeToken()
    }
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


function SwrveCreateWrappedCurrencyGiven(event as Object) as object
	this = {}
	this.type = "qa_log_event"
	now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    this.log_type = "event"
    this.log_source = "sdk"
    this.log_details = { 
    	type : "currency_given",
    	parameters: {
    		given_amount: event.given_amount,
    		given_currency: event.given_currency,
    	
    		},
    	seqnum : SwrveGetSeqNum(),
    	client_time: now.toTimeToken()
    }
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
end function


function SwrveCreateWrappedIAPWithoutReceipt(event as Object) as object

	rewards = {}
	for each key in event.rewards.Keys()
		reward = {
			type : event.rewards[key].type
			amount: event.rewards[key].amount
		}
		rewards.AddReplace(key, reward)
	end for


	this = {}
	this.type = "qa_log_event"
	now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    this.log_type = "event"
    this.log_source = "sdk"
    this.log_details = { 
    	type : "iap",
    	parameters: {
			item:event.name
			quantity :event.quantity
    		product_id: event.product_id,
    		app_store: event.app_store,
    		cost: event.cost,
    		local_currency: event.local_currency
    		"rewards": rewards
    		},
    	seqnum : SwrveGetSeqNum(),
    	client_time: now.toTimeToken()
    }
    return this
end function

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

function SwrveCreateWrappedSessionStart(event as Object) as object
	this = {}
	this.type = "qa_log_event"
	now = SwrveDate(CreateObject("roDateTime"))
    this.time = now.toTimeToken()
    this.log_type = "event"
    this.log_source = "sdk"
    this.log_details = { 
    	type : "session_start",
    	parameters: {},
    	seqnum : SwrveGetSeqNum(),
    	client_time: now.toTimeToken()
    }
    return this
end function


function SwrveCampaignsDownloaded() as void
	'TODO new campaign downloaded qa log
end Function

' Add event to the general event queue 
function SwrveAddEventToQueue(event as Object) as void
	if m.swrve_config.stopped = false		
		m.eventsQueue.push(event)
		SwrveCheckQueueSize()
		oldqueue = SwrveGetQueueFromStorage()
		if oldqueue <> invalid and type(oldqueue) = "roArray"
			oldqueue.push(event)
		else 
			oldqueue = [event]
		end if
		SwrveSaveQueueToStorage(oldqueue)
		SwrveFlushQueue()
		'SynchroniseSwrveInstance(swrveClient)
	end if

end function

'Will check the queue size compared to max size, and flush if we get over'
function SwrveCheckQueueSize() as void
	if SwrveQueueSize() > m.swrve_config.queueMaxSize
		SWLog("Event queue is too large. Sending events now to backend and flushing buffer")
		SwrveFlushAndClean()
	end if
end function

' Flush the queue
function SwrveFlushQueue() as void
	m.eventsQueue.clear()
end function

' Returns the size of the queue
function SwrveQueueSize() as Integer
	return m.eventsQueue.Count()
end function

' Build the meta fields that are at the root of the json'
function SwrveBuildBatchMeta() as Object
	config = m.swrve_config
	jsonObject = {}
	jsonObject.user = config.userID
	jsonObject.unique_device_id = config.uniqueDeviceId
	jsonObject.app_version = config.version
	jsonObject.session_token = config.session_token
	return jsonObject
end function

' Build the batch json'
function SwrveBuildBatchFromQueue() as Object
	jsonObject = SwrveBuildBatchMeta()
	if m.eventsQueue.count() < 1
		m.eventsQueue = CheckForSavedQueue()
	end if
	jsonObject.data = m.eventsQueue
	return jsonObject
end Function

function SwrveIsEventValid(event as Object) as boolean
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
function SwrvePostQueueAndFlush() as Object
	payload = SwrveBuildBatchFromQueue()
	SWLog("SwrvePostQueueAndFlush - Preparing request. ")
	if(payload <> invalid AND payload.data <> invalid)
		SWLog("SwrvePostQueueAndFlush - Items in batch que = " + payload.data.count().ToStr())
	end if

	if payload <> invalid and payload.data.count() > 0
		if(m.swrve_config.mockHTTPPOSTResponses = true)
			rtn = SendBatchPOST(payload, SwrveOnPostQueueAndFlush)
			return rtn
		else 
			SendBatchPOST(payload, "SwrveOnPostQueueAndFlush")
		end if
	end if
end function

function SwrveOnPostQueueAndFlush(responseEvent = {} as Dynamic) as Object
	if(responseEvent <> invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
		responseEvent.getRoSGNode().unobserveField(responseEvent.getField())
	else 
		response = responseEvent
	end if
	
	if response <> invalid
		if response.Code < 400 'Success or redirection: Events have gone through'
			SWLog("Success sending events to Swrve")
		else if response.code < 500 'Failure, Client error, will not retry'
			SWLog("HTTP Error - not adding events back into the queue : " + response.data)
		else if response.code >= 500 'Failure, Server error, will retry'
			SWLog("Error sending event data to Swrve (" + response.data + ") Adding data back onto unsent message buffer")
		    SaveQueueToPersistence()
		end if
		SwrveFlushQueue()

		if(m.swrve_config.mockHTTPPOSTResponses = true)
			return response
		end if
	end if

	return {}
end function

function SwrveIsLoggingQAUser() as Boolean
  qa = m.SwrveQA
  if(qa <> invalid AND qa.logging <> invalid AND qa.logging = true)
    return true
  else
   return false
  end if
end function

