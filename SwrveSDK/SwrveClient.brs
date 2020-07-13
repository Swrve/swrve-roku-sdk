
' Swrve instance creator.'
function Swrve(config as Object)
	SWLogInfo("SwrveClient()")

	swrveInit = SwrveGetTimestamp()
	m.swrve_config = {
		version: "7"
		appVersion: SWGetValue(config.appVersion, CreateObject("roAppInfo").GetVersion())
		userId: SWGetValue(config.userId, GetDefaultUserID())
		orientation: "landscape"
		httpMaxRetries: 3
		httpTimeBetweenRetries: 2
		stack: SWGetValue(config.stack, "")
		logLevel: SWGetValue(config.logLevel, 3)
		sdkVersion: SwrveConstants().SWRVE_SDK_VERSION
		autoDownloadCampaignsAndResources: true
		newSessionInterval: SWGetValue(config.newSessionInterval, 30)
		appID: SWGetValue(config.appID, "Unknown")
		apiKey: SWGetValue(config.apiKey, "Unknown")
		deviceInfo: SWGetValue(config.deviceInfo, {})
		deviceToken: SWGetValue(config.deviceToken, "Unknown")
		uniqueDeviceID: checkOrWriteQADeviceID()

		queueMaxSize: SWGetValue(config.queueMaxSize, 1000)
		flushingDelay: SWGetValue(config.flushingDelay, 1)
		campaignsAndResourcesDelay: SWGetValue(config.campaignsAndResourcesDelay, 60)

		mockHTTPPOSTResponses: SWGetValue(config.mockHTTPPOSTResponses, false)
		mockedPOSTResponseCode: SWGetValue(config.mockedPOSTResponseCode, 200)
		mockHTTPGETResponses: SWGetValue(config.mockHTTPGETResponses, false)
		mockedGETResponseCode: SWGetValue(config.mockedGETResponseCode, 200)
		session_token: ""
		isQAUser: false
		stopped: false
		identifiedOnAnotherDevice: SWGetValue(config.identifiedOnAnotherDevice, false)
	}

	dateTimeObjects = SwrveGetTimestamp()
	m.installDate = CreateObject("roDateTime")
	m.joinedDate = CreateObject("roDateTime")

	m.eventsQueue = []
	m.eventsQAQueue = []
	'm.swrveNextFlush = CreateObject("roDateTime").AsSeconds()

	m.userResources = []
	m.userCampaigns = {}

	m.resourceManager = Invalid

	'used to control campaign refresh
	m.eventsSentOrQueuedRecently = true

	m.numberOfMessagesShown = 0
	m.startSessionAsSeconds = CreateObject("roDateTime").AsSeconds()
	m.swrveNextUpdateCampaignsAndResources = CreateObject("roDateTime").AsSeconds()

	'Development: Benchmarking
	SwrvePrintLoadingTimeFromTimestamp("Swrve() init dateTimeObjects", dateTimeObjects)

	m.swrve_config.uniqueDeviceID = checkOrWriteQADeviceID()

	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_ID_KEY, m.swrve_config.userID)

	'Development: Benchmarking
	globalObjects = SwrveGetTimestamp()
	SwrveNode = getSwrveNode()

	SwrveNode.setField("logLevel", m.swrve_config.logLevel)
	SwrveNode.setField("isQAUser", m.swrve_config.isQAUser)
	SwrveNode.observeField("showIAM", "SwrveOnShowIAM")
	SwrveNode.setField("currentIAM", {})
	SwrveNode.observeField("shutdown", "SwrveOnShutdown")
	SwrveNode.setField("assetsReady", false)
	SwrveNode.observeField("event", "SwrveOnGlobalEvent")
	SwrveNode.observeField("clickEvent", "SwrveOnClickEvent")
	SwrveNode.observeField("purchaseEvent", "SwrveOnPurchaseEvent")
	SwrveNode.observeField("userUpdate", "SwrveOnUserUpdate")
	SwrveNode.observeField("impressionEvent", "SwrveOnImpressionEvent")
	SwrveNode.setField("sdkHasCustomRenderer", false)

	SwrveNode.observeField("getNewResourcesDiff", "SwrveOnGetResourcesDiff")
	SwrveNode.observeField("globalCurrencyGiven", "SwrveOnGlobalCurrencyGiven")
	SwrveNode.observeField("globalUserUpdateWithDate", "SwrveOnGlobalUserUpdateWithDate")
	SwrveNode.observeField("globalIAPWithoutReceipt", "SwrveOnGlobalIAPWithoutReceipt")
	SwrveNode.observeField("globalFlushAndClean", "SwrveOnGlobalFlushAndClean")

	'Development: Benchmarking
	SwrvePrintLoadingTimeFromTimestamp("Swrve() init globalObjects", globalObjects)


	SwrveNode.observeField("globalIdentifyExternalID", "SwrveGlobalIdentify")

	SwrveStartSession()

	'Development: Benchmarking
	SwrvePrintLoadingTimeFromTimestamp("Swrve() init swrveInit", swrveInit)

end function

function SwrveStartSession()
	' True if there is no joined date for this user, meaning it is the first ever session for this user'
	firstSession = SwrveFirstEverSession()

	'Checks the time elapsed from the last time the app was alive. If greater than the delay in the config, then we should send a session start event'
	shouldSendSessionStart = isThisANewSession()

	'Timestamp that will be used to generate the token. It depicts the time the current/new session was started'
	startTimeStamp = ""
	if shouldSendSessionStart
		startTimestamp = SetSessionStartDate()
	else
		startTimestamp = GetSessionStartDate()
	end if

	m.swrve_config.session_token = SwrveGenerateToken(startTimestamp, m.swrve_config.userId, m.swrve_config.apikey, m.swrve_config.appId)

	m.installDate = checkOrWriteInstallDate()
	m.joinedDate = checkOrWriteJoinedDate()

	updateLastSessionDate()
	m.startSession = GetSessionStartDate()

	'Load campaigns, resources and qa dicts from persistence as they might not come down the feed (etag)'
	m.userCampaigns = SwrveLoadUserCampaignsFromPersistence()
	getSwrveNode().userCampaigns = m.userCampaigns
	'TODO BRIGHTSCRIPT: ERROR: roSGNode.AddReplace: "userresources": Type mismatch: pkg:/source/SwrveSDK/SwrveClient.brs(123)'
	m.userResources = SwrveLoadUserResourcesFromPersistence()
	getSwrveNode().userResources = m.userResources

	if m.userCampaigns.cdn_paths <> Invalid
		m.userCampaigns.cdn_root = m.userCampaigns.cdn_paths.message_images
	end if

	qa = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_QA_FILENAME, "")
	if qa <> ""
		m.SwrveQA = ParseJSON(qa)
		m.swrve_config.isQAUser = true
		getSwrveNode().isQAUser = true
	end if

	if shouldSendSessionStart
		SWLogInfo("Session started, send session_start.")
		SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME)
		SwrveSessionStart()
		SwrveDeviceUpdate(SwrveUserInfosDictionary())
	else
		SWLogDebug("Session continued, keep the session alive")
	end if

	if firstSession AND m.swrve_config.identifiedOnAnotherDevice = false
		SWLogInfo("It is the first session ever and the user hasn't identified on another device. Send a first_session event")
		SwrveFirstSession()
	end if
end function

function SwrveOnGlobalCurrencyGiven(msg)
	msgObj = msg.getData()
	SwrveCurrencyGiven(msgObj.givenCurrency, msgObj.givenAmount)
end function

function SwrveOnGlobalUserUpdateWithDate(msg)
	msgObj = msg.getData()
	SwrveUserUpdateWithDate(msgObj.name, msgObj.date)
end function

function SwrveOnGlobalIAPWithoutReceipt(msg)
	msgObj = msg.getData()
	'no roku store, needs to be unknown for backend
	SwrveIAPWithoutReceipt(msgObj.product, msgObj.rewards, msgObj.currency, "unknown")
end function

function SwrveOnGlobalFlushAndClean()
	SwrveFlushAndClean()
end function

function SwrveGlobalIdentify(msg)
	SWLogInfo("SwrveGlobalIdentify() msg:", msg)
	SwrveIdentify(msg.getData())
end function

function SwrveStartHeartbeat()
	delayTimer = m.top.findNode("refreshTimer")
	delayTimer.duration = 5
	delayTimer.ObserveField("fire", "SwrveOnTimer")
	delayTimer.Control = "start"
	m.delayTimer = delayTimer

	SwrveOnTimer()
end function

function SwrveOnImpressionEvent(payload)
	if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
		eventOb = payload.getData()
		if(eventOb <> Invalid)
			SwrveImpressionEvent(eventOb)
		else
			SWLogWarn("SwrveImpressionEvent data is invalid")
		end if
	end if

end function

function SwrveOnUserUpdate(payload)
	if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
		eventOb = payload.getData()
		if(eventOb <> Invalid)
			SwrveUserUpdate(eventOb)
		else
			SWLogWarn("SwrveUserUpdate data is invalid")
		end if
	end if
end function

function SwrveOnPurchaseEvent(payload)
	if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
		eventOb = payload.getData()
		if(eventOb.itemQuantity <> Invalid AND eventOb.itemName <> Invalid AND eventOb.itemPrice <> Invalid AND eventOb.itemCurrency <> Invalid)
			SwrvePurchaseEvent(eventOb.itemQuantity, eventOb.itemName, eventOb.itemPrice, eventOb.itemCurrency)
		else
			SWLogError("SwrvePurchaseEvent missing values: itemQuantity:", itemQuantity, "itemName:", itemName, "itemPrice:", itemPrice, "itemCurrency", itemCurrency)
		end if
	end if
end function

function SwrveOnClickEvent(payload)
	if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
		eventOb = payload.getData()
		if(eventOb.message <> Invalid AND eventOb.buttonname <> Invalid)
			SwrveClickEvent(eventOb.message, eventOb.buttonname)
		else
			SWLogError("SwrveClickEvent missing values: eventName:", eventName, "buttonname:", buttonname)
		end if
	end if
end function

function SwrveOnGlobalEvent(payload)
	if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
		eventOb = payload.getData()
		if(eventOb <> Invalid)
			eventName = ""
			payload = Invalid

			if(eventOb.eventName <> Invalid)
				eventName = eventOb.eventName
			end if

			if(eventOb.payload <> Invalid)
				payload = eventOb.payload
			end if

			if(eventName <> "" AND payload = Invalid)
				SwrveEvent(eventName)
			else if (eventName <> "" AND payload <> Invalid)
				SwrveEvent(eventName, payload)
			else
				SWLogError("SwrveGlobalEvent eventName is an empty string")
			end if
		else
			SWLogError("SwrveGlobalEvent getData() was Invalid")
		end if
	else
		SWLogError("SwrveGlobalEvent Invalid or is not of type roSGNodeEvent", type(payload))
	end if
end function

function SwrveGetConfig()
	return m.swrve_config
end function

function SwrveOnShowIAM()
	showMessage = getSwrveNode().showIAM
	if NOT showMessage
		RemoveIAMInClient()
	else if showMessage = true
		ShowIAMInClient()
	end if
end function


function GetStack(config as Object) as String
	if config.DoesExist("stack") AND config.stack = "eu"
		return "eu-"
	else
		return ""
	end if
end function

function SwrveIdentify(externalID as String) as Object
	SWLogInfo("SwrveIdentify() externalID:", externalID)

	if(m.swrve_config = Invalid) return Invalid

	m.swrve_config.identifiedOnAnotherDevice = false

	SwrveFlushAndClean()
	SwrveStop()
	shouldIdentify = false
	m.dictionaryOfSwrveIDS = SwrveGetObjectFromPersistence(SwrveConstants().SWRVE_USER_IDS_KEY, Invalid)


	' Special case : Identify used wil nil or "" '
	if externalID = ""
		SWLogWarn("SwrveIdentify() Anonymous identify")
		di = CreateObject("roDeviceInfo")
		udid = di.GetRandomUUID()
		m.swrve_config.userID = udid

		SwrveResume()
		return {
			status: "Anonymous restart"
			swrve_id: udid
		}
	end if

	if m.dictionaryOfSwrveIDS = Invalid
		m.dictionaryOfSwrveIDS = {}
		shouldIdentify = true
	else
		if m.dictionaryOfSwrveIDS[externalID] <> Invalid
			m.swrve_config.userID = m.dictionaryOfSwrveIDS[externalID]
		else
			shouldIdentify = true
		end if
	end if

	res = {}
	res.swrve_id = m.swrve_config.userID
	if shouldIdentify
		response = Identify(externalID, "onIdentifyCallback")
		return {}
	end if

	onSwrveIdentifyComplete(res)

end function

function onIdentifyCallback(responseEvent) as Object
	if(responseEvent <> Invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
	else
		return {}
	end if

	requestObj = Invalid
	requestStr = response.RequestStr
	externalID = ""
	if(response.requeststr <> Invalid) requestObj = ParseJSON(response.requeststr)
	if(requestObj.external_user_id <> Invalid) externalID = requestObj.external_user_id


	if response.code = 403
		di = CreateObject("roDeviceInfo")
		udid = di.GetRandomUUID()
		response = IdentifyWithUserID(udid, externalID, "onIdentifyWithUserID")
		return {}
	end if

	return onIdentifyWithUserID(responseEvent)

end function

function onIdentifyWithUserID(responseEvent)
	if(responseEvent <> Invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
	else
		return {}
	end if

	requestObj = Invalid
	requestStr = response.RequestStr
	externalID = ""
	if(response.requeststr <> Invalid) requestObj = ParseJSON(response.requeststr)
	if(requestObj.external_user_id <> Invalid) externalID = requestObj.external_user_id

	res = {}

	if response.code < 400
		res.swrve_id = response.data.swrve_id
		m.dictionaryOfSwrveIDs[externalID] = response.data.swrve_id

		if m.swrve_config.userID <> response.data.swrve_id
			m.swrve_config.userID = response.data.swrve_id
			m.swrve_config.identifiedOnAnotherDevice = true
		end if
		res.status = response.data.status
	else
		res.status = response.data
	end if

	return onSwrveIdentifyComplete(res)
end function

function onSwrveIdentifyComplete(res)
	m.swrve_config.userId = res.swrve_id
	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_ID_KEY, res.swrve_id)
	SwrveSaveObjectToPersistence(SwrveConstants().SWRVE_USER_IDS_KEY, m.dictionaryOfSwrveIDs)
	SwrveStartSession() 'Restart the session for the new user'
	getSwrveNode().globalIdentifyExternalIDCallback = res
	SwrveResume()
	return res
end function



function SwrveIdentifyMocked(externalID as Object, mockedResponse as String) as Object

	m.swrve_config.identifiedOnAnotherDevice = false

	SwrveFlushAndClean()
	SwrveStop()
	shouldIdentify = false
	m.dictionaryOfSwrveIDS = SwrveGetObjectFromPersistence(SwrveConstants().SWRVE_USER_IDS_KEY, Invalid)
	if m.dictionaryOfSwrveIDS = Invalid
		m.dictionaryOfSwrveIDS = {}
		shouldIdentify = true
	else
		if m.dictionaryOfSwrveIDS[externalID] <> Invalid
			m.swrve_config.userID = m.dictionaryOfSwrveIDS[externalID]
		else
			shouldIdentify = true
		end if
	end if

	res = {}
	res.swrve_id = ""
	if shouldIdentify
		response = GetMockedUserResourcesAndCampaigns(mockedResponse)
		if response.code = 403
			di = CreateObject("roDeviceInfo")
			udid = di.GetRandomUUID()
			res.status = "external_user_id duplicate or bad userid"
		end if

		if response.code < 400
			res.swrve_id = response.data.swrve_id
			m.dictionaryOfSwrveIDs[externalID] = response.data.swrve_id

			if m.swrve_config.userID <> response.data.swrve_id
				m.swrve_config.userID = response.data.swrve_id
				m.swrve_config.identifiedOnAnotherDevice = true
			end if
			res.status = response.data.status
		else
			res.status = response.data
		end if
	end if

	SwrveSaveObjectToPersistence(SwrveConstants().SWRVE_USER_IDS_KEY, m.dictionaryOfSwrveIDs)
	SwrveResume()
	return res

end function

function SwrveIdentifyWithUserID(userID as String, externalID as Object, callback as String) as Object
	return IdentifyWithUserID(userID, externalID, callback)
end function


function SwrveStop()
	m.swrve_config.stopped = true
	if m.delayTimer <> Invalid then m.delayTimer.control = "stop"
end function

function SwrveResume()
	m.swrve_config.stopped = false
	if m.delayTimer <> Invalid then m.delayTimer.control = "start"
end function

function SwrveOnShutdown() as Object
	if(m.delayTimer <> Invalid)
		m.delayTimer.control = "stop"
		m.delayTimer = Invalid
	end if

	SWLogWarn("Shutdown initiated.")
	SWLogWarn("Shutdown initiated....Flushing queue")

	SWLogWarn("Shutdown initiated....clearing persistent storage")
	SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY)
	SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY)
	SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_SEQNUM)
	SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY)
	SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_EVENTS_STORAGE)
	SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME)

	SWLogWarn("Shutdown initiated....Clearing memory")
	SWLogWarn("Shutdown. To use Swrve features you will need to reinitialize.")

	m.startSession = Invalid
	m.userCampaigns = Invalid
	m.userResources = Invalid
	m.installDate = Invalid
	m.joinedDate = Invalid
	m.eventsQueue = Invalid
	m.eventsQAQueue = Invalid
	'm.swrveNextFlush = Invalid
	m.numberOfMessagesShown = Invalid
	m.startSessionAsSeconds = Invalid
	m.swrveNextUpdateCampaignsAndResources = Invalid

	m.swrve_config = Invalid
	SwrveNode = getSwrveNode()
	fields = SwrveNode.keys()

	' Stop watching for public api events
	for each field in fields
		SwrveNode.unobserveField(field)
	end for
end function



function SwrveOnTimer()
	now = CreateObject("roDateTime").AsSeconds()
	SWLogVerbose("SwrveOnTimer now:", now)

	SWLogVerbose("SwrveOnTimer next process campaigns and resources:", m.swrveNextUpdateCampaignsAndResources)
	SWLogVerbose("SwrveOnTimer m.swrve_config.flushingDelay:", m.swrve_config.flushingDelay)
	SWLogVerbose("SwrveOnTimer m.swrve_config.campaignsAndResourcesDelay:", m.swrve_config.campaignsAndResourcesDelay)

	qa = m.SwrveQA
	if(qa <> Invalid AND qa.logging <> Invalid AND qa.logging = true)
		SWLogDebug("QA User sending events")
		SwrvePostQAQueueAndFlush()
	end if

	if now >= m.swrveNextUpdateCampaignsAndResources
		m.swrveNextUpdateCampaignsAndResources = now + m.swrve_config.campaignsAndResourcesDelay
		if m.swrve_config.flushingDelay <> Invalid AND m.swrveDelayProcessUserCampaignsAndResources = Invalid
			SwrveFlushAndClean()
			updateLastSessionDate()
			if m.eventsSentOrQueuedRecently = true
				m.eventsSentOrQueuedRecently = false
				swrveDelayProcessUserCampaignsAndResources = CreateObject("RoSGNode", "Timer")
				swrveDelayProcessUserCampaignsAndResources.duration = m.swrve_config.flushingDelay
				swrveDelayProcessUserCampaignsAndResources.ObserveField("fire", "SwrveOnDelayProcessUserCampaignsAndResources")
				swrveDelayProcessUserCampaignsAndResources.Control = "start"
				m.swrveDelayProcessUserCampaignsAndResources = swrveDelayProcessUserCampaignsAndResources
			end if
		end if
	end if
end function

function SwrveOnDelayProcessUserCampaignsAndResources()
	SWLogDebug("SwrveOnDelayProcessUserCampaignsAndResources()")
	if m.swrveDelayProcessUserCampaignsAndResources <> Invalid
		m.swrveDelayProcessUserCampaignsAndResources.control = "stop"
		m.swrveDelayProcessUserCampaignsAndResources = Invalid
	end if
	processUserCampaignsAndResources()
end function

function processUserCampaignsAndResources()
	GetUserResourcesAndCampaigns("SwrveOnUserCampaignsAndResources")
end function

function SwrveOnUserCampaignsAndResources(response = {} as Dynamic)

	if(response <> Invalid AND type(response) = "roSGNodeEvent")
		resAndCamp = response.getData()
	end if

	gotNewResourcesOrCampaigns = false

	if resAndCamp <> Invalid AND resAndCamp.code < 400 AND resAndCamp.code > 0
		if resAndCamp.headers <> Invalid AND resAndCamp.headers.etag <> Invalid
			etag = resAndCamp.headers.etag
			SwrveSaveStringToPersistence(SwrveConstants().SWRVE_ETAG_FILENAME, etag)
		end if
		if SwrveDictionaryHasUserResource(resAndCamp) 'If not, it means it hasn't changed (etag check), just use the one from persistence
			gotNewResourcesOrCampaigns = true
			userResources = SwrveGetUserResourcesFromDictionarySafe(resAndCamp)
			userResoucesStr = FormatJSON(userResources)
			userResourcesSignature = SwrveMd5(userResoucesStr)
			m.userResources = userResources
			getSwrveNode().userResources = m.userResources
			m.resourceManager = SwrveResourceManager(userResources)
			userResourcesStoredSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME)

			if userResourcesStoredSignature <> userResourcesSignature
				'store it and its signature'
				SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_RESOURCES_FILENAME, userResoucesStr)
				SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME, userResourcesSignature)
			end if
		end if
		if SwrveDictionaryHasUserCampaigns(resAndCamp)
			gotNewResourcesOrCampaigns = true
			userCampaigns = SwrveGetUserCampaignsFromDictionarySafe(resAndCamp)
			userCampaignsStr = FormatJSON(userCampaigns)
			userCampaignsSignature = SwrveMd5(userCampaignsStr)
			userCampaignsStoredSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME)

			m.userCampaigns = userCampaigns
			if userCampaigns.cdn_root <> Invalid
				m.userCampaigns.cdn_root = userCampaigns.cdn_root
			else if userCampaigns.cdn_paths <> Invalid
				m.userCampaigns.cdn_root = userCampaigns.cdn_paths.message_images
			end if
			getSwrveNode().userCampaigns = m.userCampaigns

			if userCampaignsStoredSignature <> userCampaignsSignature
				'store it and its signature'
				SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME, userCampaignsStr)
				SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME, userCampaignsSignature)
			end if
			SwrveCampaignsDownloaded()
			DownloadAssetsFromCampaigns()
		else
			SwrveCheckAssetsAllDownloaded("SwrveDownloadAssetsIfAllAssetsNotDownloaded")
		end if

		SWLogDebug("!!!!!!!!!!!!!!!!!!! SwrveOnUserCampaignsAndResources() !!!!!!!!!!!!!!!!!!!")
		SWLogDebug("resAndCamp.data:", resAndCamp.data)

		if resAndCamp.data <> Invalid AND resAndCamp.data.flush_refresh_delay <> Invalid
			SWLogDebug("Updating config flush delay to " + (resAndCamp.data.flush_refresh_delay / 1000).toStr() + " seconds")
			m.swrve_config.flushingDelay = Int(resAndCamp.data.flush_refresh_delay / 1000)
			SwrveFlushAndClean()
		end if

		if resAndCamp.data.qa <> Invalid
			m.SwrveQA = resAndCamp.data.qa
			m.swrve_config.isQAUser = SwrveIsQAUser(resAndCamp)
			getSwrveNode().isQAUser = m.swrve_config.isQAUser
			if m.swrve_config.isQAUser
				SwrveSaveObjectToPersistence(SwrveConstants().SWRVE_USER_QA_FILENAME, resAndCamp.data.qa)
				'Investigate as to why there is no logging_url in the qa json object.'
				'userPropertiesToBabble(swrveClient, resAndCamp.data.qa)
			end if
		end if

		if resAndCamp.data <> Invalid AND resAndCamp.data.flush_frequency <> Invalid
			SWLogDebug("Updating config campaignsAndResourcesDelay delay to " + (resAndCamp.data.flush_frequency / 1000).toStr() + " seconds")
			m.swrve_config.campaignsAndResourcesDelay = Int(resAndCamp.data.flush_frequency / 1000)
		end if

		'TODO: m.swrve_config.campaignsAndResourcesDelay should update with value from back end. User this ? "flush_frequency": 60000
		now = CreateObject("roDateTime").AsSeconds()
		m.swrveNextUpdateCampaignsAndResources = now + m.swrve_config.campaignsAndResourcesDelay

		if gotNewResourcesOrCampaigns OR getSwrveNode().resourcesAndCampaigns = false
			'Notify observers that we got new campaigns and resources'
			getSwrveNode().resourcesAndCampaigns = true
		end if
	end if
end function

function SwrveDownloadAssetsIfAllAssetsNotDownloaded(responseEvent)
	if(responseEvent <> Invalid AND type(responseEvent) = "roSGNodeEvent")
		response = responseEvent.getData()
	end if
	responseEvent.getRoSGNode().unobserveField(responseEvent.getField())
	if(response.allFilesExist = false)
		DownloadAssetsFromCampaigns()
	end if
end function

function SwrveBuildArrayOfAssetIDs(campaigns as Object) as Object
	ids = []
	for each campaign in campaigns.campaigns
		if campaign.messages <> Invalid
			for each message in campaign.messages
				if message.template <> Invalid
					if message.template.formats <> Invalid
						for each format in message.template.formats
							if format.images <> Invalid
								for each image in format.images
									if image.image <> Invalid AND image.image.type = "asset" AND image.image.value <> Invalid AND NOT SwrveArrayContains(ids, image.image.value)
										id = image.image.value
										ids.push(id)
									end if
								end for
							end if
							if format.buttons <> Invalid
								for each button in format.buttons
									if button.image_up <> Invalid AND button.image_up.type = "asset" AND button.image_up.value <> Invalid AND NOT SwrveArrayContains(ids, button.image_up.value)
										id = button.image_up.value
										ids.push(id)
									end if
								end for
							end if
						end for
					end if
				end if
			end for
		end if
	end for
	return ids
end function

function SwrveArrayContains(arr as Object, value as String) as Boolean
	for each entry in arr
		if entry = value
			return true
		end if
	end for
	return false
end function

function DownloadAssetsFromCampaigns()
	campaigns = m.userCampaigns
	if campaigns.campaigns <> Invalid
		ids = SwrveBuildArrayOfAssetIDs(campaigns)
		DownloadAndStoreAssets(ids)
	end if
end function

function assetsDownloadCallback()
	getSwrveNode().assetsReady = true
	fakeEvent = SwrveCreateEvent(SwrveConstants().SWRVE_EVENT_AUTOSHOW_SESSION_START)
	SwrveCheckEventForTriggers(fakeEvent)
end function

' Returns what's in the saved queue. returns an empty array if nothing was saved
function CheckForSavedQueue() as Object
	savedQueue = SwrveStorageManager().SwrveGetQueueFromStorage()
	'print "CheckForSavedQueue() savedQueue:"; savedQueue
	if savedQueue <> Invalid AND type(savedQueue) = "roArray" AND savedQueue.count() > 0
		'print "CheckForSavedQueue() savedQueue:"; savedQueue.count()
		return savedQueue
	end if
	return []
end function

function RestoreSavedQueue()
	savedQueue = CheckForSavedQueue() 'Checking if there are any saved events we need to recover'
	if savedQueue.count() > 0 'If so, add them first to the current queue'
		SwrveStorageManager().SwrveClearQueueFromStorage()

		wholeQueue = []
		wholeQueue.append(savedQueue)
		wholeQueue.append(m.eventsQueue)
		m.eventsQueue = wholeQueue
	end if
end function

function SwrveSetUserCampaigns(campaigns)
	m.userCampaigns = campaigns
end function

function SwrveGetUserCampaigns() as Object
	return m.userCampaigns
end function

function SwrveSetResourceManager(resourceManager)
	m.resourceManager = resourceManager
end function

function SwrveGetResourceManager() as Object
	return m.resourceManager
end function

function SwrveSetEventsQueue(que)
	m.eventsQueue = que
end function

function SwrveGetEventsQueue() as Object
	return m.eventsQueue
end function

function SwrveFlushAndClean()
	RestoreSavedQueue()
	SwrvePostQueueAndFlush()
	'm.swrveNextFlush = m.swrveNextFlush + m.swrve_config.flushingDelay
end function


function SaveQueueToPersistence() as Boolean
	if m.eventsQueue <> Invalid AND m.eventsQueue.Count() > 0
		oldqueue = SwrveGetQueueFromStorage()
		oldqueue.append(m.eventsQueue)
		success = SwrveStorageManager().SwrveSaveQueueToStorage(oldqueue)
		m.eventsQueue.Clear()
	end if
end function


' Returns a dictionary of default user update properties'
function SwrveUserInfosDictionary() as Object
	device = CreateObject("roDeviceInfo")

	dt = CreateObject ("roDateTime")
	utcSeconds = dt.AsSeconds()
	dt.ToLocalTime()
	localSeconds = dt.AsSeconds()
	utcSecondsOffset = localSeconds - utcSeconds

	date = CreateObject("roDateTime")
	date.fromISO8601String(checkOrWriteInstallDate())

	strDate = StrI(date.GetYear()).trim()

	if date.GetMonth() < 10
		strDate += "0"
	end if
	strDate += strI(date.GetMonth()).Trim()

	if date.GetDayOfMonth() < 10
		strDate += "0"
	end if
	strDate += StrI(date.GetDayOfMonth()).Trim()

	attributes = {
		"swrve.device_name": "Roku" + device.GetModel().Trim(),
		"swrve.os": "Roku",
		"swrve.os_version": device.GetVersion(),
		"swrve.device_width": box(device.GetDisplaySize().w),
		"swrve.device_height": device.GetDisplaySize().h,
		"swrve.language": device.GetCurrentLocale(),
		"swrve.device_region": "US",
		"swrve.sdk_version": SwrveConstants().SWRVE_SDK_VERSION,
		"swrve.app_store": "google", 'Will have to be changed to roku when supported by backend'
		"swrve.timezone_name": device.GetTimeZone(),
		"swrve.utc_offset_seconds": utcSecondsOffset,
		"swrve.install_date": strDate
	}
	return attributes
end function

' Read the installation date. If it doesn't exist, save it to registry
function checkOrWriteInstallDate() as Object
	dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_INSTALL_DATE_KEY, "")
	if dateString = ""
		date = CreateObject("roDateTime")
		dateString = date.ToISOString()
		SwrveSaveStringToPersistence(SwrveConstants().SWRVE_INSTALL_DATE_KEY, dateString)
		SWLogInfo("Updating first install date:", dateString)
	else
		SWLogDebug("First install date:", dateString)
	end if
	return dateString
end function

' Read the joined date. If it doesn't exist, save it to registry
function checkOrWriteJoinedDate() as Object
	dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_JOINED_DATE_KEY, "")
	if dateString = ""
		date = CreateObject("roDateTime")
		dateString = date.ToISOString()
		SwrveSaveStringToPersistence(SwrveConstants().SWRVE_JOINED_DATE_KEY, dateString)
		SWLogInfo("Updating first joined date:", dateString)
	else
		SWLogDebug("First joined date:", dateString)
	end if
	return dateString
end function


' Read the QA device id . If it doesn't exist, save it to registry
function checkOrWriteQADeviceID() as Object
	did = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_QA_UNIQUE_DEVICE_ID_KEY, "")
	if did = ""
		di = CreateObject("roDeviceInfo")
		udid = di.GetRandomUUID()
		SwrveSaveStringToPersistence(SwrveConstants().SWRVE_QA_UNIQUE_DEVICE_ID_KEY, udid)
	end if
	return did
end function

'Creates or returns a random user id'
function GetDefaultUserID() as String
	did = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY, "")
	if did = ""
		di = CreateObject("roDeviceInfo")
		did = di.GetRandomUUID()
		SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_ID_KEY, did)
	end if
	return did
end function

' read the last date the channel was live'
function lastSessionDate() as Object
	key = SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY

	dateString = SwrveGetStringFromPersistence(key, "")

	if dateString = ""
		return Invalid
	end if

	date = CreateObject("roDateTime")
	date.fromISO8601String(dateString)
	return date
end function


function SwrveFirstEverSession() as Boolean
	dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_JOINED_DATE_KEY, "")
	if dateString = ""
		return true
	else
		return false
	end if
end function

function SetSessionStartDate() as String
	date = CreateObject("roDateTime")
	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, date.ToISOString())
	return StrI(date.AsSeconds()).Trim()
end function

function GetSessionStartDate() as String
	dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
	if dateString <> ""
		date = CreateObject("roDateTime")
		date.FromISO8601String(dateString)
		return StrI(date.AsSeconds()).Trim()
	end if
end function

function GetSessionStartDateAsSeconds() as Integer
	dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
	if dateString <> ""
		date = CreateObject("roDateTime")
		date.FromISO8601String(dateString)
		return date.AsSeconds()
	end if
	return -1
end function

function GetSessionStartDateAsReadable() as String
	return SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
end function

function GetCurrentUserID() as String
	return SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY, "")
end function

function GetUserQAStatus() as Boolean
	return m.swrve_config.isQAUser
end function

' Determine if we need to send a new session_start of if we keep the session live'
function isThisANewSession() as Boolean

	lastSessionObj = lastSessionDate()
	if lastSessionObj = Invalid
		return true
	end if
	lastSession = lastSessionObj.AsSeconds()
	now = CreateObject("roDateTime").AsSeconds()

	difference = Abs(now - lastSession)
	SWLogInfo("Last session was", difference, "seconds ago. Session interval is", m.swrve_config.newSessionInterval, "seconds")
	if difference > m.swrve_config.newSessionInterval
		return true
	else
		return false
	end if

end function

' This will basically be called regularly to save the current time to make sure we have an approximate time
' of the last time the app was running, in case the app is closed or closes unexpectedly.
function updateLastSessionDate() as Object
	dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY, "")
	date = CreateObject("roDateTime")
	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY, date.ToISOString())
	if NOT dateString = ""
		SWLogVerbose("Updating last session time:", dateString)
	end if
	return dateString
end function

'Returns the api key'
function GetAPIKey(swrveClient) as String
	return m.swrve_config.apikey
end function

'returns the install date'
function GetInstallDate(swrveClient) as Integer
	date = checkOrWriteInstallDate()
	return date.AsSeconds()
end function

'returns the joined date'
function GetJoinedDate(swrveClient) as Integer
	date = checkOrWriteJoinedDate()
	return date.AsSeconds()
end function

function RemoveIAMInClient()
	m.top.GetScene().dialog = Invalid
end function


function ShowIAMInClient()
	if getSwrveNode().showIAM
		SWLogInfo("SwrveClient() Swrve has been asked to show an IAM")
		message = getSwrveNode().currentIAM

		d = CreateObject("RoSGNode", "SwrveDialog")
		d.title = ""
		d.maxHeight = 200
		d.graphicWidth = 1385
		d.graphicHeight = 862

		d.asset_location = SwrveConstants().SWRVE_ASSETS_LOCATION
		d.iam = message
		m.top.GetScene().dialog = d
		d.setFocus = true

		swrveSendImpressionAfterIAMTimer = CreateObject("RoSGNode", "Timer")
		swrveSendImpressionAfterIAMTimer.duration = 2
		swrveSendImpressionAfterIAMTimer.ObserveField("fire", "SwrveOnDelaySendImpressionEvent")
		swrveSendImpressionAfterIAMTimer.Control = "start"
		m.swrveSendImpressionAfterIAMTimer = swrveSendImpressionAfterIAMTimer
	end if
end function

function SwrveOnDelaySendImpressionEvent()
	if m.swrveSendImpressionAfterIAMTimer <> Invalid
		m.swrveSendImpressionAfterIAMTimer.control = "stop"
		m.swrveSendImpressionAfterIAMTimer = Invalid
	end if

	if(getSwrveNode().currentIAM <> Invalid)
		SwrveImpressionEvent(getSwrveNode().currentIAM)
	end if
end function
