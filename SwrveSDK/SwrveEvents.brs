' Named event creation & queue'
function SwrveEvent(eventName as String, payload = {} as Object) as Void
	SWLogDebug("SwrveEvent() eventName:", eventName)
	event = SwrveCreateEvent(eventName, payload)
	if SwrveIsEventValid(event)
		SwrveCheckEventForTriggers(event)
		SwrveAddEventToQueue(event)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(event))
		end if
	end if
end function

'Create a device update with a dictionary of attributes'
function SwrveDeviceUpdate(attributes as Object) as Void
	ua = SwrveCreateDeviceUpdate(attributes)
	if ua <> Invalid
		if ua.attributes <> Invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
				SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(ua))
			end if
		end if
	end if
end function

'Create a user update with a dictionary of attributes'
function SwrveUserUpdate(attributes as Object) as Void
	ua = SwrveCreateUserUpdate(attributes)
	if ua <> Invalid
		if ua.attributes <> Invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
				SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(ua))
			end if
		end if
	end if
end function

'Create a user update with a name and a date'
function SwrveUserUpdateWithDate(name as String, date as Object) as Void
	ua = SwrveCreateUserUpdateWithDate(name, date)
	if ua <> Invalid
		if ua.attributes <> Invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
				SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(ua))
			end if
		end if
	end if
end function

'Create a purchase event, with quantity, item name, price and currency'
function SwrvePurchaseEvent(itemQuantity as Integer, itemName as String, itemPrice as Float, itemCurrency as String) as Void
	pa = SwrveCreatePurchaseEvent(StrI(itemQuantity).Trim(), itemName, Str(itemPrice).Trim(), itemCurrency)
	if pa <> Invalid
		SwrveAddEventToQueue(pa)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(pa))
		end if
	end if
end function

'Create a currency given event, with given currency name and the given amount'
function SwrveCurrencyGiven(givenCurrency as String, givenAmount as Integer) as Void
	cg = SwrveCreateCurrencyGiven(givenCurrency, StrI(givenAmount).Trim())
	if cg <> Invalid
		SwrveAddEventToQueue(cg)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(cg))
		end if
	end if
end function

'Create a IAP event, without receipt'
function SwrveIAPWithoutReceipt(product as Object, rewards as Object, currency as String, app_store) as Void
	pa = SwrveCreateIAPWithoutReceipt(product, rewards, currency, app_store)
	if pa <> Invalid AND pa.count() > 0
		SwrveAddEventToQueue(pa)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(pa))
		end if
	end if
end function

'Create a First session event and queues it'
function SwrveFirstSession() as Void
	ua = SwrveCreateEvent(SwrveConstants().SWRVE_EVENT_FIRST_SESSION_STRING)
	if ua <> Invalid
		if ua.name <> Invalid
			SwrveAddEventToQueue(ua)
			if(SwrveIsLoggingQAUser())
				SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(ua))
			end if
		end if
	end if
end function

'Create a session start event and queues it'
function SwrveSessionStart() as Void
	ua = SwrveCreateSessionStartEvent()
	if ua <> Invalid
		SwrveAddEventToQueue(ua)
		if(SwrveIsLoggingQAUser())
			SwrveAddEventToQAQueue(SwrveCreateWrappedEvent(ua))
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

function SwrveCreateWrappedEvent(event as Object) as Object
	new_parameters = {}
	new_log_details = {}
	for each key in event.Keys()
		if key = "type"
			new_log_details.AddReplace(key, event[key])
		else if key = "time"
			'Dashboard QA event expects a client_time key
			new_log_details.AddReplace("client_time", event[key])
		else if key = "seqnum"
			seqnum = event[key]
			new_log_details.AddReplace("seqnum", seqnum)
		else if key = "payload"
			'Dashboard QA, expects payload as string
			payloadString = FormatJSON(event[key])
			if payloadString <> Invalid
				new_log_details.AddReplace(key, payloadString)
			end if
		else
			'All other values add to parameters dictionary
			new_parameters.AddReplace(key, event[key])
		end if
	end for

	new_log_details.AddReplace("parameters", new_parameters)

	this = {}
	this.type = "qa_log_event"
	now = SwrveDate(CreateObject("roDateTime"))
	this.time = now.toTimeToken()
	this.log_type = "event"
	this.log_source = "sdk"
	this.log_details = new_log_details

	return this
end function

'Create a click event (IAM)'
function SwrveClickEvent(message as Object, buttonName as String) as Object
	SwrveEvent("Swrve.Messages.Message-" + StrI(message.id).Trim() + ".click", { "name": buttonName })
end function

'Create an impression event (IAM)'
function SwrveImpressionEvent(message as Object) as Object
	eventName = "Swrve.Messages.Message-" + StrI(message.id).Trim() + ".impression"
	format = message.template.formats[0]
	payload = {
		"orientation": format.orientation,
		"size": StrI(format.size.w.value).Trim() + "x" + StrI(format.size.h.value).Trim(),
		"format": format.name
	}
	SwrveEvent(eventName, payload)
end function

'Create a Returned event (IAM)'
'function SwrveReturnedMessageEvent(message as Object) as Object
	'TODO new campaign triggered qa log
'end function

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

	if product.product_id = Invalid
		SWLogError("Product ID mustn't be nil")
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

' Generic user update event'
function SwrveCreateUserUpdateWithDate(name as String, date as Object) as Object
	this = {}
	this.type = SwrveConstants().SWRVE_EVENT_TYPE_USER_UPDATE

	this.seqnum = SwrveGetSeqNum()
	now = SwrveDate(CreateObject("roDateTime"))
	this.time = now.toTimeToken()
	if date <> Invalid
		this.attributes = {}
		this.attributes.AddReplace(name, date)
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

function SwrveCampaignsDownloaded() as Void
	'TODO new campaign downloaded qa log
end function

' Add event to the general event queue
function SwrveAddEventToQueue(event as Object) as Void
	if m.swrve_config <> Invalid AND m.eventsQueue <> Invalid AND m.swrve_config.stopped = false
		SWLogDebug("Adding event to queue", event)
		m.eventsSentOrQueuedRecently = true
		m.eventsQueue.push(event)
		if m.eventsQueue.Count() > m.swrve_config.queueMaxSize
			SWLogWarn("Event QA queue is too large. Sending events now to backend and flushing buffer")
			SwrveFlushAndClean()
		else
			oldqueue = SwrveGetQueueFromStorage()
			oldqueue.push(event)
			SwrveSaveQueueToStorage(oldqueue)
			SwrveFlushQueue()
		end if
	else
		SWLogDebug("Attempt to add event to queue while swrve is stopped", event)
	end if
end function

' Add event to QA queue
function SwrveAddEventToQAQueue(event as Object) as Void
	if m.swrve_config <> Invalid AND m.swrve_config.stopped = false
		SWLogDebug("Adding event to QA queue", event)
		m.eventsSentOrQueuedRecently = true
		m.eventsQAQueue.push(event)
		if m.eventsQAQueue.Count() > m.swrve_config.queueMaxSize
			SWLogWarn("Event QA queue is too large. Sending events now to backend and flushing buffer")
			SwrveFlushAndCleanQA()
		else
			oldqueueQA = SwrveGetQueueFromStorage(true)
			oldqueueQA.push(event)
			SwrveSaveQueueToStorage(oldqueueQA, true)
			SwrveFlushQAQueue()
		end if
	else
		SWLogDebug("Attempt to add event to QA queue while swrve is stopped", event)
	end if
end function

'Will check the queue size compared to max size, and flush if we get over'
function SwrveCheckQueueSize() as Void
	if  m.swrve_config <> Invalid
		if SwrveQueueSize() > m.swrve_config.queueMaxSize
			SWLogError("Event queue is too large. Sending events now to backend and flushing buffer")
			SwrveFlushAndClean()
		end if
	end if
end function

' Flush the queue
function SwrveFlushQueue() as Void
	if m.eventsQueue <> Invalid 
		m.eventsQueue.clear()
	end if
end function

' Flush the QA queue
function SwrveFlushQAQueue() as Void
	if m.eventsQAQueue <> Invalid 
		m.eventsQAQueue.clear()
	end if
end function

' Returns the size of the queue
function SwrveQueueSize() as Integer
	if m.eventsQueue <> Invalid 
		return m.eventsQueue.Count()
	end if
	return 0
end function

' Build the meta fields that are at the root of the json'
function SwrveBuildBatchMeta() as Object
	jsonObject = {}
	if m.swrve_config = Invalid then return jsonObject

	jsonObject.user = m.swrve_config.userId
	jsonObject.unique_device_id = m.swrve_config.uniqueDeviceId
	jsonObject.app_version = m.swrve_config.appVersion
	jsonObject.version = SwrveConstants().SWRVE_CAMPAIGN_RESOURCES_API_VERSION
	jsonObject.session_token = m.swrve_config.session_token
	return jsonObject
end function

' Build the batch json'
function SwrveBuildBatchFromQueue() as Object
	jsonObject = SwrveBuildBatchMeta()
	if m.eventsQueue <> Invalid AND m.eventsQueue.count() < 1
		m.eventsQueue = SwrveGetQueueFromStorage()
	end if
	jsonObject.data = m.eventsQueue
	return jsonObject
end function

function SwrveBuildBatchFromQAQueue() as Object
	jsonObject = SwrveBuildBatchMeta()
	if m.eventsQAQueue <> Invalid AND m.eventsQAQueue.count() < 1
		m.eventsQAQueue = SwrveGetQueueFromStorage(true)
	end if
	jsonObject.data = m.eventsQAQueue
	return jsonObject
end function

function SwrveIsEventValid(event as Object) as Boolean
	isValid = event <> Invalid
	hasName = event.name <> Invalid AND event.name <> ""
	noSpaces = Instr(1, event.name, " ") = 0 'From documentation, the first position is 1.'
	'For when I know the max length'
	'nameShortEnough = Length(event.name) < 256
	hasSeq = event.seqnum <> Invalid AND event.seqnum > -1
	hasTime = event.time <> Invalid
	if isValid AND hasName AND hasSeq AND hasTime AND noSpaces
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
		SWLogError(message)
	end if
end function

' Post the batch json to the batch endpoint. On success flush the queue, on failure, we'll see when we start caching
function SwrvePostQueueAndFlush() as Object
	payload = SwrveBuildBatchFromQueue()
	SWLogDebug("SwrvePostQueueAndFlush - Preparing request. ")
	if(payload <> Invalid AND payload.data <> Invalid)
		SWLogDebug("SwrvePostQueueAndFlush - Items in batch que = ", payload.data.count())
	end if

	if payload <> Invalid AND payload.data <> Invalid AND payload.data.count() > 0
		m.eventsSentOrQueuedRecently = true
		if(m.swrve_config.mockHTTPPOSTResponses = true)
			rtn = SendBatchPOST(payload, SwrveOnPostQueueAndFlush)
			return rtn
		else
			SendBatchPOST(payload, "SwrveOnPostQueueAndFlush")
		end if
	end if
end function

function SwrveOnPostQueueAndFlush(responseEvent = {} as Dynamic) as Object
	if(responseEvent <> Invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
		responseEvent.getRoSGNode().unobserveField(responseEvent.getField())
	else
		response = responseEvent
	end if

	if response <> Invalid
		if response.Code < 400 'Success or redirection: Events have gone through'
			SWLogDebug("Success sending events to Swrve")
		else if response.code < 500 'Failure, Client error, will not retry'
			SWLogDebug("HTTP Error - not adding events back into the queue : ", response.data)
		else if response.code >= 500 'Failure, Server error, will retry'
			SWLogDebug("Error sending event data to Swrve (", response.data, ") Adding data back onto unsent message buffer")
			SaveQueueToPersistence()
		end if
		SwrveFlushQueue()

		if(m.swrve_config <> Invalid AND m.swrve_config.mockHTTPPOSTResponses = true)
			return response
		end if
	end if

	return {}
end function

function SwrveIsLoggingQAUser() as Boolean
	qa = m.SwrveQA
	if(qa <> Invalid AND qa.logging <> Invalid AND qa.logging = true)
		return true
	else
		return false
	end if
end function

function SwrvePostQAQueueAndFlush() as Object
	payload = SwrveBuildBatchFromQAQueue()
	SWLogDebug("SwrvePostQAQueueAndFlush - Preparing request. ")
	if(payload <> Invalid AND payload.data <> Invalid)
		SWLogDebug("SwrvePostQAQueueAndFlush - Items in batch QA que = ", payload.data.count())
	end if

	if payload <> Invalid AND payload.data <> Invalid AND payload.data.count() > 0
		m.eventsSentOrQueuedRecently = true
		if(m.swrve_config.mockHTTPPOSTResponses = true)
			rtn = SendBatchPOST(payload, SwrveOnPostQueueAndFlush)
			return rtn
		else
			SendBatchPOST(payload, "SwrveOnPostQAQueueAndFlush")
		end if
	end if
end function

function SwrveOnPostQAQueueAndFlush(responseEvent = {} as Dynamic) as Object
	if(responseEvent <> Invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
		responseEvent.getRoSGNode().unobserveField(responseEvent.getField())
	else
		response = responseEvent
	end if

	if response <> Invalid
		if response.Code < 400 'Success or redirection: Events have gone through'
			SWLogDebug("Success sending QA events to Swrve")
		else if response.code < 500 'Failure, Client error
			SWLogDebug("QA client error sending events.", response.data)
		else if response.code >= 500 'Failure, Server error
			SWLogDebug("QA server error sending events.", response.data)
		end if
		SwrveFlushQAQueue()

		if(m.swrve_config.mockHTTPPOSTResponses = true)
			return response
		end if
	end if
	return {}
end function

' Get from registry the latest seqnum, increment it, and save it back.
function SwrveGetSeqNum() as Integer

	'-1 in case we never used it before, it'll get incremented to 0
	previousSNAsString = SwrveGetValueFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_SEQNUM)
	if previousSNAsString = ""
	  previousSNAsString = "-1"
	end if
	previousSeqNum = StrToI(previousSNAsString)
	currentSeqNum = previousSeqNum + 1
	currentSNAsString = StrI(currentSeqNum)
  
	SwrveWriteValueToSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_SEQNUM, currentSNAsString)
	return currentSeqNum
  end function