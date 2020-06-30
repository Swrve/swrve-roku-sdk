
' Swrve instance creator.'
function Swrve(config as Object)
    SWLog( "SwrveClient()" )

    swrveInit = SwrveGetTimestamp()
    di = CreateObject("roDeviceInfo")
    m.global = getGlobalAA().global
    m.swrve_config = {
                        version: "7" 
                        userId: SWObject(config.userId).default(GetDefaultUserID())
                        orientation: "landscape"
                        httpMaxRetries: 3
                        httpTimeBetweenRetries: 2
                        stack: SWObject(config.stack).default("")
                        debug :  SWObject(config.debug).default(true)
                        sdkVersion: SwrveConstants().SWRVE_SDK_VERSION
                        autoDownloadCampaignsAndResources: true
                        newSessionInterval : SWObject(config.newSessionInterval).default(30)
                        appID: SWObject(config.appID).default("Unknown")
                        apiKey: SWObject(config.apiKey).default("Unknown")
                        deviceInfo: SWObject(config.deviceInfo).default({})
                        deviceToken: SWObject(config.deviceToken).default("Unknown")
                        uniqueDeviceID: checkOrWriteQADeviceID()

                        queueMaxSize: SWObject(config.queueMaxSize).default(1000)
                        flushingDelay:  SWObject(config.flushingDelay).default(1)
                        campaignsAndResourcesDelay:  SWObject(config.campaignsAndResourcesDelay).default(60)

                        mockHTTPPOSTResponses: SWObject(config.mockHTTPPOSTResponses).default(false)
                        mockedPOSTResponseCode: SWObject(config.mockedPOSTResponseCode).default(200)
                        mockHTTPGETResponses: SWObject(config.mockHTTPGETResponses).default(false)
                        mockedGETResponseCode: SWObject(config.mockedGETResponseCode).default(200)
                        session_token : ""
                        isQAUser: false
                        stopped: false
                        identifiedOnAnotherDevice: SWObject(config.identifiedOnAnotherDevice).default(false)
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

    
    m.global.setField("SwrveDebug", m.swrve_config.debug)
    m.global.setField("SwrveIsQAUser", m.swrve_config.isQAUser)
    m.global.observeField("swrveShowIAM", "onShowSwrveIAM")
    m.global.setField("swrveCurrentIAM", {})
    m.global.observeField("SwrveShutdown", "SwrveShutdown")
    m.global.setField("swrveAssetsReady", false)
    m.global.observeField("SwrveEvent", "onSwrveGlobalEvent")
    m.global.observeField("SwrveClickEvent", "onSwrveClickEvent")
    m.global.observeField("SwrvePurchaseEvent", "onSwrvePurchaseEvent")
    m.global.observeField("SwrveUserUpdate", "onSwrveUserUpdate")
    m.global.observeField("SwrveImpressionEvent", "SwrveOnImpressionEvent")
    m.global.setField("swrveSDKHasCustomRenderer", false)

    m.global.observeField("SwrveGetNewResourcesDiff", "SwrveGetResourcesDiff")
    m.global.observeField("SwrveGlobalCurrencyGiven", "SwrveGlobalCurrencyGiven")
    m.global.observeField("SwrveGlobalUserUpdateWithDate", "SwrveGlobalUserUpdateWithDate")
    m.global.observeField("SwrveGlobalIAPWithoutReceipt", "SwrveGlobalIAPWithoutReceipt")
    m.global.observeField("SwrveGlobalFlushAndClean", "SwrveFlushAndClean")

    'Development: Benchmarking
    SwrvePrintLoadingTimeFromTimestamp("Swrve() init globalObjects", globalObjects)

    
    m.global.observeField("SwrveGlobalIdentifyExternalID", "SwrveGlobalIdentify")

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
    m.global.userCampaigns = m.userCampaigns
    'TODO BRIGHTSCRIPT: ERROR: roSGNode.AddReplace: "userresources": Type mismatch: pkg:/source/SwrveSDK/SwrveClient.brs(123)'
    m.userResources = SwrveLoadUserResourcesFromPersistence()
    m.global.userResources = m.userResources
    
    if m.userCampaigns.cdn_paths <> invalid
        m.userCampaigns.cdn_root = m.userCampaigns.cdn_paths.message_images
    end if
  
    qa = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_QA_FILENAME, "")    
    if qa <> ""
        m.SwrveQA = ParseJSON(qa)
        m.swrve_config.isQAUser = true
        m.global.SwrveIsQAUser = true
    end if

    if shouldSendSessionStart
        SWLog("Session started, send session_start.")
        SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME)    
        SwrveSessionStart()
        SwrveDeviceUpdate(SwrveUserInfosDictionary())
    else
        SWLog("Session continued, keep the session alive")
    end if

    if firstSession and m.swrve_config.identifiedOnAnotherDevice = false
         SWLog("It is the first session ever and the user hasn't identified on another device. Send a first_session event")
         SwrveFirstSession()
    end if
end function

function SwrveGlobalCurrencyGiven(msg)
    msgObj = msg.getData()
    SwrveCurrencyGiven(msgObj.givenCurrency, msgObj.givenAmount)
end function

function SwrveGlobalUserUpdateWithDate(msg)
    msgObj = msg.getData()
    SwrveUserUpdateWithDate(msgObj.name, msgObj.date)
end function

function SwrveGlobalIAPWithoutReceipt(msg)
    msgObj = msg.getData()
    'no roku store, needs to be unknown for backend
    SwrveIAPWithoutReceipt(msgObj.product, msgObj.rewards, msgObj.currency, "unknown")
end function

function SwrveGlobalIdentify(msg) 
    print "SwrveGlobalIdentify() msg:"; msg
    SwrveIdentify(msg.getData()) 
end function

function SwrveStartHeartbeat()
    delayTimer = m.top.findNode("refreshTimer")
    delayTimer.duration = 5
    delayTimer.ObserveField("fire","SwrveOnTimer")
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
            SWLog("m.global.SwrveImpressionEvent data is invalid")
        end if
    end if
    
end function

function onSwrveUserUpdate(payload)
    if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
        eventOb = payload.getData()
        if(eventOb <> Invalid)
            SwrveUserUpdate(eventOb)  
        else 
            SWLog("m.global.SwrveUserUpdate data is invalid")
        end if
    end if
end function

function onSwrvePurchaseEvent(payload)
    if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
        eventOb = payload.getData()
        if(eventOb.itemQuantity <> Invalid AND eventOb.itemName <> Invalid AND eventOb.itemPrice <> Invalid AND eventOb.itemCurrency <> Invalid)
            SwrvePurchaseEvent(eventOb.itemQuantity, eventOb.itemName, eventOb.itemPrice, eventOb.itemCurrency)  
        else 
            SWLog("m.global.SwrvePurchaseEvent itemQuantity, itemName, itemPrice or itemCurrency is invalid")
        end if
    end if
end function

function onSwrveClickEvent(payload)
    if(payload <> Invalid AND type(payload) = "roSGNodeEvent")
        eventOb = payload.getData()
        if(eventOb.message <> Invalid AND eventOb.buttonname <> Invalid)
            SwrveClickEvent(eventOb.message, eventOb.buttonname)
        else 
            SWLog("m.global.SwrveClickEvent eventName or buttonname is invalid")
        end if
    end if
end function

function onSwrveGlobalEvent(payload)
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
                SWLog("m.global.SwrveEvent eventName = \"\"")
            end if
        else 
            SWLog("m.global.SwrveEvent getData() returns Invalid")
        end if
    else 
        SWLog("m.global.SwrveEvent assigned as Invalid or is not of type roSGNodeEvent")
    end if
end function

function SwrveGetConfig()
    return m.swrve_config
end function

function onShowSwrveIAM()  
    showMessage = m.global.swrveShowIAM
    if NOT showMessage
        RemoveIAMInClient() 
    else if showMessage = true
        ShowIAMInClient()    
    end if
end function


function GetStack(config as Object) as String
    if config.DoesExist("stack") and config.stack = "eu"
        return "eu-"
    else 
        return ""
    end if
end function

function SwrveIdentify(externalID as String) as object

    SWLog("SwrveIdentify() externalID:" + externalID)

    if(m.swrve_config = Invalid) return Invalid

    m.swrve_config.identifiedOnAnotherDevice = false
    
    SwrveFlushAndClean()
    SwrveStop()
    shouldIdentify = false
    m.dictionaryOfSwrveIDS = SwrveGetObjectFromPersistence(SwrveConstants().SWRVE_USER_IDS_KEY, invalid)
    

    ' Special case : Identify used wil nil or "" '
    if externalID = ""
        SWLog( "SwrveIdentify() Anonymous identify" )
        di = CreateObject("roDeviceInfo")
        udid = di.GetRandomUUID()
        m.swrve_config.userID = udid

        SwrveResume()    
        return {
            status : "Anonymous restart"
            swrve_id : udid
        }            
    end if

    if m.dictionaryOfSwrveIDS = invalid
        m.dictionaryOfSwrveIDS = {}
        shouldIdentify = true
    else 
        if m.dictionaryOfSwrveIDS[externalID] <> invalid
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
    if(responseEvent <> invalid AND type(responseEvent) = "roSGNodeEvent")
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
    if(responseEvent <> invalid AND type(responseEvent) = "roSGNodeEvent")
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
    m.global.SwrveGlobalIdentifyExternalIDCallback = res
    SwrveResume()
    return res
end function



function SwrveIdentifyMocked(externalID as Object, mockedResponse as String) as object

    m.swrve_config.identifiedOnAnotherDevice = false

    SwrveFlushAndClean()
    SwrveStop()
    shouldIdentify = false
    m.dictionaryOfSwrveIDS = SwrveGetObjectFromPersistence(SwrveConstants().SWRVE_USER_IDS_KEY, invalid)
    if m.dictionaryOfSwrveIDS = invalid
        m.dictionaryOfSwrveIDS = {}
        shouldIdentify = true
    else 
        if m.dictionaryOfSwrveIDS[externalID] <> invalid
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

function SwrveIdentifyWithUserID(userID as String, externalID as Object) as object
    return IdentifyWithUserID(userID, externalID)
end function


function SwrveStop()
    m.swrve_config.stopped = true
    if m.delayTimer <> Invalid then m.delayTimer.control = "stop"
end function

function SwrveResume()
    m.swrve_config.stopped = false
    if m.delayTimer <> Invalid then m.delayTimer.control = "start"
end function

function SwrveShutdown() as Object
    if(m.delayTimer <> Invalid)
        m.delayTimer.control = "stop"
        m.delayTimer = Invalid
    end if

    m.global = getGlobalAA().global
    SWLog("Shutdown initiated.")
    SWLog("Shutdown initiated....Flushing queue")

    SWLog("Shutdown initiated....clearing persistent storage")
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_SEQNUM)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_EVENTS_STORAGE)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME)

    SWLog("Shutdown initiated....Clearing memory")
    SWLog("Shutdown. To use Swrve features you will need to reinitiate.")

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

    m.global.SwrveDebug = Invalid
    m.swrve_config = Invalid

    m.global.unobserveField("SwrveDebug")
    m.global.unobserveField("SwrveIsQAUser")
    m.global.unobserveField("SwrveCustomCallback")
    m.global.unobserveField("swrveShowIAM")
    m.global.unobserveField("swrveCurrentIAM")
    m.global.unobserveField("SwrveShutdown")
    m.global.unobserveField("swrveResourcesAndCampaigns")
    m.global.unobserveField("SwrveResourcesDiffObjectReady")
    m.global.unobserveField("swrveAssetsReady")
    m.global.unobserveField("SwrveEvent")
    m.global.unobserveField("SwrveClickEvent")
    m.global.unobserveField("SwrvePurchaseEvent")
    m.global.unobserveField("SwrveUserUpdate")
    m.global.unobserveField("SwrveImpressionEvent")
    m.global.unobserveField("messageWillRender")
    m.global.unobserveField("swrveSDKHasCustomRenderer")
    m.global.unobserveField("SwrveGlobalIdentifyExternalID")
    m.global.unobserveField("SwrveGlobalIdentifyExternalIDCallback")
    m.global.unobserveField("SwrveGetNewResourcesDiff")
    m.global.unobserveField("SwrveGlobalCurrencyGiven")
    m.global.unobserveField("SwrveGlobalUserUpdateWithDate")
    m.global.unobserveField("SwrveGlobalIAPWithoutReceipt")
    m.global.unobserveField("SwrveGlobalFlushAndClean")

    m.global.removeField("SwrveDebug")
    m.global.removeField("SwrveIsQAUser")
    m.global.removeField("SwrveCustomCallback")
    m.global.removeField("swrveShowIAM")
    m.global.removeField("swrveCurrentIAM")
    m.global.removeField("SwrveShutdown")
    m.global.removeField("swrveResourcesAndCampaigns")
    m.global.removeField("SwrveResourcesDiffObjectReady")
    m.global.removeField("swrveAssetsReady")
    m.global.removeField("SwrveEvent")
    m.global.removeField("SwrveClickEvent")
    m.global.removeField("SwrvePurchaseEvent")
    m.global.removeField("SwrveUserUpdate")
    m.global.removeField("SwrveImpressionEvent")
    m.global.removeField("messageWillRender")
    m.global.removeField("swrveSDKHasCustomRenderer")
    m.global.removeField("SwrveGlobalIdentifyExternalID")
    m.global.removeField("SwrveGlobalIdentifyExternalIDCallback")
    m.global.removeField("SwrveGetNewResourcesDiff")
    m.global.removeField("SwrveGlobalCurrencyGiven")
    m.global.removeField("SwrveGlobalUserUpdateWithDate")
    m.global.removeField("SwrveGlobalIAPWithoutReceipt")
    m.global.removeField("SwrveGlobalFlushAndClean")
end function



function SwrveOnTimer()
    now = CreateObject("roDateTime").AsSeconds()
    SWLog("SwrveOnTimer now:" + now.toStr())

    SWLog("SwrveOnTimer next process campaigns and resources:" + m.swrveNextUpdateCampaignsAndResources.toStr())
    SWLog("SwrveOnTimer m.swrve_config.flushingDelay:" + m.swrve_config.flushingDelay.toStr())
    SWLog("SwrveOnTimer m.swrve_config.campaignsAndResourcesDelay:" + m.swrve_config.campaignsAndResourcesDelay.toStr())

    qa = m.SwrveQA
    if(qa <> invalid AND qa.logging <> invalid AND qa.logging = true)
        SWLog("QA User sending events")
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
                swrveDelayProcessUserCampaignsAndResources.ObserveField("fire","SwrveOnDelayProcessUserCampaignsAndResources")
                swrveDelayProcessUserCampaignsAndResources.Control = "start"
                m.swrveDelayProcessUserCampaignsAndResources = swrveDelayProcessUserCampaignsAndResources
            end if
        end if
    end if
end function

function SwrveOnDelayProcessUserCampaignsAndResources()
    SWLog("SwrveOnDelayProcessUserCampaignsAndResources()")
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

    if(response <> invalid AND type(response) = "roSGNodeEvent")
        resAndCamp = response.getData()
    end if

    gotNewResourcesOrCampaigns = false

    if resAndCamp <> Invalid AND resAndCamp.code < 400 AND resAndCamp.code > 0
        if resAndCamp.headers <> invalid and resAndCamp.headers.etag <> invalid
            etag = resAndCamp.headers.etag
            SwrveSaveStringToPersistence(SwrveConstants().SWRVE_ETAG_FILENAME, etag)
        end if
        if SwrveDictionaryHasUserResource(resAndCamp) 'If not, it means it hasn't changed (etag check), just use the one from persistence
            gotNewResourcesOrCampaigns = true
            userResources = SwrveGetUserResourcesFromDictionarySafe(resAndCamp)
            userResoucesStr = FormatJSON(userResources)
            userResourcesSignature = SwrveMd5(userResoucesStr)
            m.userResources = userResources
            m.global.userResources = m.userResources
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
            if userCampaigns.cdn_root <> invalid
                m.userCampaigns.cdn_root = userCampaigns.cdn_root
            else if userCampaigns.cdn_paths <> invalid
                m.userCampaigns.cdn_root = userCampaigns.cdn_paths.message_images
            end if
            m.global.userCampaigns = m.userCampaigns

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

        print "!!!!!!!!!!!!!!!!!!! SwrveOnUserCampaignsAndResources() !!!!!!!!!!!!!!!!!!!"
        print "resAndCamp.data:"; resAndCamp.data

        if resAndCamp.data <> invalid and resAndCamp.data.flush_refresh_delay <> invalid
            SWLog("Updating config flush delay to " + (resAndCamp.data.flush_refresh_delay / 1000).toStr() + " seconds")
            m.swrve_config.flushingDelay = Int(resAndCamp.data.flush_refresh_delay / 1000)
            SwrveFlushAndClean()
        end if

        if resAndCamp.data.qa <> invalid
            m.SwrveQA = resAndCamp.data.qa
            m.swrve_config.isQAUser = SwrveIsQAUser(resAndCamp)
            m.global.SwrveIsQAUser = m.swrve_config.isQAUser
            if m.swrve_config.isQAUser
                SwrveSaveObjectToPersistence(SwrveConstants().SWRVE_USER_QA_FILENAME, resAndCamp.data.qa)
                'Investigate as to why there is no logging_url in the qa json object.'
                'userPropertiesToBabble(swrveClient, resAndCamp.data.qa)
            end if
        end if

        if resAndCamp.data <> invalid and resAndCamp.data.flush_frequency <> invalid
            SWLog("Updating config campaignsAndResourcesDelay delay to " + (resAndCamp.data.flush_frequency / 1000).toStr() + " seconds")
            m.swrve_config.campaignsAndResourcesDelay = Int(resAndCamp.data.flush_frequency / 1000)
        end if

        'TODO: m.swrve_config.campaignsAndResourcesDelay should update with value from back end. User this ? "flush_frequency": 60000
        now = CreateObject("roDateTime").AsSeconds()
        m.swrveNextUpdateCampaignsAndResources = now + m.swrve_config.campaignsAndResourcesDelay
        
        if gotNewResourcesOrCampaigns or m.global.swrveResourcesAndCampaigns = false
            'Notify observers that we got new campaigns and resources'
            m.global.swrveResourcesAndCampaigns = true
        end if
    end if
end function

function SwrveDownloadAssetsIfAllAssetsNotDownloaded(responseEvent)
    if(responseEvent <> invalid AND type(responseEvent) = "roSGNodeEvent")
        response = responseEvent.getData()
    end if
    responseEvent.getRoSGNode().unobserveField(responseEvent.getField())
    if(response.allFilesExist = false)
        DownloadAssetsFromCampaigns()
    end if
end function

function SwrveBuildArrayOfAssetIDs(campaigns as object) as object
    ids = []
    for each campaign in campaigns.campaigns
        if campaign.messages <> invalid
            for each message in campaign.messages
                if message.template <> invalid
                    if message.template.formats <> invalid
                        for each format in message.template.formats
                            if format.images <> invalid
                                for each image in format.images 
                                    if image.image <> invalid and image.image.type = "asset" AND image.image.value <> Invalid AND NOT SwrveArrayContains(ids, image.image.value)
                                        id = image.image.value
                                        ids.push(id)
                                    end if
                                end for
                            end if
                            if format.buttons <> invalid
                                for each button in format.buttons 
                                    if button.image_up <> invalid and button.image_up.type = "asset" AND button.image_up.value <> Invalid AND NOT SwrveArrayContains(ids, button.image_up.value)
                                        id = button.image_up.value
                                        ids.push(id)
                                    end if
                                end for
                            end if
                        end for
                    end if
                end If
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
    if campaigns.campaigns <> invalid
        ids = SwrveBuildArrayOfAssetIDs(campaigns)
        DownloadAndStoreAssets(ids)
    end if
end function

function assetsDownloadCallback()  
    m.global.swrveAssetsReady = true
    fakeEvent = SwrveCreateEvent(SwrveConstants().SWRVE_EVENT_AUTOSHOW_SESSION_START)
    SwrveCheckEventForTriggers(fakeEvent)
End function

' Returns what's in the saved queue. returns an empty array if nothing was saved
function CheckForSavedQueue() as Object
    savedQueue = SwrveStorageManager().SwrveGetQueueFromStorage()
    'print "CheckForSavedQueue() savedQueue:"; savedQueue
    if savedQueue <> invalid and type(savedQueue) = "roArray" and savedQueue.count() > 0
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
    if m.eventsQueue <> invalid and m.eventsQueue.Count() > 0
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
        "swrve.device_name": "Roku"+device.GetModel().Trim(),
        "swrve.os":"Roku",
        "swrve.os_version": device.GetVersion(),
        "swrve.device_width": box(device.GetDisplaySize().w),
        "swrve.device_height": device.GetDisplaySize().h,
        "swrve.language": device.GetCurrentLocale(),
        "swrve.device_region":"US",
        "swrve.sdk_version": SwrveConstants().SWRVE_SDK_VERSION,
        "swrve.app_store":"google", 'Will have to be changed to roku when supported by backend'
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
    end if
    SWLog("First install date " + dateString)
    return dateString
end function

' Read the joined date. If it doesn't exist, save it to registry
function checkOrWriteJoinedDate() as Object
    
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_JOINED_DATE_KEY, "")
    if dateString = ""
        date = CreateObject("roDateTime")
        dateString = date.ToISOString()
        SwrveSaveStringToPersistence(SwrveConstants().SWRVE_JOINED_DATE_KEY, dateString)
    end if
    SWLog("First install date " + dateString)
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
    di = CreateObject("roDeviceInfo")
    did = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY, "")
    if did = ""
        did = di.GetRandomUUID()    
        SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_ID_KEY, did)
    end if
    
    return did
End function

' read the last date the channel was live'
function lastSessionDate() as Object
    key = SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY

    dateString = SwrveGetStringFromPersistence(key, "")
    date = CreateObject("roDateTime")

    if dateString = ""
        return invalid
    end if
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
    date = CreateObject("roDateTime")
    if dateString <> ""
        date.FromISO8601String(dateString)
        return StrI(date.AsSeconds()).Trim()
    end if
end function

function GetSessionStartDateAsSeconds() as Integer
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
    date = CreateObject("roDateTime")
    if dateString <> ""
        date.FromISO8601String(dateString)
        return date.AsSeconds()
    end if
    return -1
end Function

function GetSessionStartDateAsReadable() as String
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
    return dateString
end function

function GetCurrentUserID() as String
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY, "")
    return dateString
end function

function GetUserQAStatus() as Boolean
    return m.swrve_config.isQAUser
end Function

' Determine if we need to send a new session_start of if we keep the session live'
function isThisANewSession() as Boolean 

    lastSessionObj = lastSessionDate()
    if lastSessionObj = invalid
        return true
    end if
    lastSession = lastSessionObj.AsSeconds()
    now = CreateObject("roDateTime").AsSeconds()

    difference = Abs(now-lastSession)
    SWLog("Last session was " + str(difference) + " seconds ago. Session interval is " +  str(m.swrve_config.newSessionInterval) + " seconds")
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
    if dateString = ""
        SWLog("")
    else
        'SWLog("Updating last session time " + dateString)
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
    if m.global.swrveShowIAM
        SWLog("SwrveClient() Swrve has been asked to show an IAM")
        message = m.global.swrveCurrentIAM

        d = CreateObject("RoSGNode", "SwrveDialog")
        d.title = ""
        d.maxHeight = 200
        d.graphicWidth = 1385
        d.graphicHeight = 862

        d.asset_location = SwrveConstants().SWRVE_ASSETS_LOCATION
        d.iam = message
        m.top.GetScene().dialog = d
        d.setFocus = true

        swreveSendImpressionAfterIAMTimer = CreateObject("RoSGNode", "Timer")
        swreveSendImpressionAfterIAMTimer.duration = 2
        swreveSendImpressionAfterIAMTimer.ObserveField("fire","SwrveOnDelaySendImpressionEvent")
        swreveSendImpressionAfterIAMTimer.Control = "start"
        m.swreveSendImpressionAfterIAMTimer = swreveSendImpressionAfterIAMTimer
    end if
end function

function SwrveOnDelaySendImpressionEvent()
    if m.swreveSendImpressionAfterIAMTimer <> Invalid
        m.swreveSendImpressionAfterIAMTimer.control = "stop"
        m.swreveSendImpressionAfterIAMTimer = Invalid
    end if

    if(m.global.swrveCurrentIAM <> Invalid)
        SwrveImpressionEvent(m.global.swrveCurrentIAM)
    end if
end function

function SwrveSetupGlobals() as Void
    m.date = CreateObject("roDateTime")
    g = GetGlobalAA().global
    'date values used to benchmark set up times. 
    g.addFields( {startSeconds: m.date.AsSeconds(), startMilli: m.date.GetMilliseconds(), appStartSecondsDesc: (m.date.AsSeconds() + (m.date.GetMilliseconds() / 1000)) - 1000000000 })
    'This will be used as an observed value to show IAMs from anywhere in the app'
    g.AddField("swrveShowIAM", "boolean", true)
    'This will be used as an observed value to show IAMs from anywhere in the app'
    g.AddField("swrveCurrentIAM", "assocarray", true)
    'This value can be observed and will be notified when the diff is ready
    g.AddField("SwrveResourcesDiffObjectReady", "assocarray", true)

     'Shut down Swrve SDK from Render Thread
    g.AddField("SwrveShutdown", "boolean", true)
     'This value can be observed and will be notified when the assets have been downloaded
    g.AddField("swrveAssetsReady", "boolean", true)

    g.AddField("swrveResourcesAndCampaigns", "boolean", true)
    g.setField("swrveResourcesAndCampaigns", false)
    g.AddField("messageWillRender", "assocarray", true)
    g.setField("messageWillRender", {})
    g.AddField("SwrveCustomCallback", "string", true)
    g.AddField("SwrveEvent", "assocarray", true)
    g.AddField("SwrveGlobalIdentifyExternalIDCallback", "assocarray", true)
    g.setField("SwrveGlobalIdentifyExternalIDCallback", {})
    g.AddField("SwrveGlobalIdentifyExternalID", "string", true)
    g.AddField("SwrveDebug", "boolean", true)
    g.AddField("SwrveIsQAUser", "boolean", true)
    g.AddField("SwrveClickEvent", "assocarray", true)
    g.AddField("SwrvePurchaseEvent", "assocarray", true)
    g.AddField("SwrveUserUpdate", "assocarray", true)
    g.AddField("SwrveImpressionEvent", "assocarray", true)
    g.AddField("swrveSDKHasCustomRenderer", "boolean", true)
    g.AddField("userResources", "array", true)
    g.AddField("userCampaigns", "assocarray", true)

    g.AddField("SwrveGetNewResourcesDiff", "boolean", true)
    g.AddField("SwrveGlobalCurrencyGiven", "assocarray", true)
    g.AddField("SwrveGlobalUserUpdateWithDate", "assocarray", true)
    g.AddField("SwrveGlobalIAPWithoutReceipt", "assocarray", true)
    g.AddField("SwrveGlobalFlushAndClean", "boolean", true)
    
end function

