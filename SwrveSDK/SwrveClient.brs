' Swrve instance creator.'
function Swrve(config as Object) as Void
    if getSwrveNode("Swrve") = Invalid then return
    
    'Development: Benchmarking
    'swrveInit = SwrveGetTimestamp()
    m.swrve_config = {
        'public
        appID: SWGetValue(config.appID, "Unknown")
        apiKey: SWGetValue(config.apiKey, "Unknown")
        appVersion: SWGetValue(config.appVersion, CreateObject("roAppInfo").GetVersion())
        stack: SWGetValue(config.stack, "")
        logLevel: SWGetValue(config.logLevel, 3)
        newSessionInterval: SWGetValue(config.newSessionInterval, 30)
        usersCacheDays: 30
        usersCacheSize: 5
        
        'private
        userId: SWGetValue(config.userId, GetDefaultUserID())
        orientation: "landscape"
        uniqueDeviceID: checkOrWriteDeviceID()
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

    Migrate()

    'dateTimeObjects = SwrveGetTimestamp()
    m.installDate = CreateObject("roDateTime")
    m.joinedDate = CreateObject("roDateTime")

    m.eventsQueue = []
    m.eventsQAQueue = []

    m.userResources = []
    m.userCampaigns = {}

    m.resourceManager = Invalid

    'Development: Benchmarking
    'SwrvePrintLoadingTimeFromTimestamp("Swrve() init dateTimeObjects", dateTimeObjects)

    m.swrve_config.uniqueDeviceID = checkOrWriteDeviceID()

    SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_USER_ID_KEY, m.swrve_config.userId)

    'Development: Benchmarking
    'globalObjects = SwrveGetTimestamp()

    getSwrveNode().setField("logLevel", m.swrve_config.logLevel)
    getSwrveNode().setField("isQAUser", m.swrve_config.isQAUser)
    getSwrveNode().setField("currentIAM", {})
    getSwrveNode().setField("assetsReady", false)
    getSwrveNode().setField("sdkHasCustomRenderer", false)
    getSwrveNode().setField("sdkHasCustomButtonFocusCallback", false)
    getSwrveNode().observeField("showIAM", "SwrveOnShowIAM")

    'Development: Benchmarking
    'SwrvePrintLoadingTimeFromTimestamp("Swrve() init globalObjects", globalObjects)
    SwrveStartSession()
    'Development: Benchmarking
    'SwrvePrintLoadingTimeFromTimestamp("Swrve() init swrveInit", swrveInit)

end function

function SwrveTidyRegistry() as Void
    suids = SwrveGetValueFromSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_USER_IDS_KEY)
    if suids = "" then return
    userIds = ParseJson(suids)
    if userIds = Invalid then return

    userIdsCount = userIds.Count()
    if userIdsCount > m.swrve_config.usersCacheSize
        threshold = CreateObject("roDateTime").AsSeconds() - (m.swrve_config.usersCacheDays * 24 * 60 * 60)
        thresholdDate = CreateObject("roDateTime")
        thresholdDate.FromSeconds(threshold)

        removeUserIds = []
        for EACH key in userIds
            'dont delete current user
            if key <> m.swrve_config.userId
                dateString = SwrveGetValueFromSection(key, SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY)
                lastSession = CreateObject("roDateTime")
                lastSession.fromISO8601String(dateString)
                lastSession = lastSession.AsSeconds()
                if lastSession < threshold
                    SWLogDebug("Remvoing user data for", key, "no sessions since", thresholdDate.ToISOString())
                    SwrveDeleteSection(key)
                    removeUserIds.push(key)
                    
                    'Delete the files stored in cachefs
					DeleteFile(SwrveConstants().SWRVE_CAMPAIGNS_LOCATION + key + "campaigns")
					DeleteFile(SwrveConstants().SWRVE_RESOURCES_LOCATION + key + "resources")
					DeleteFile(SwrveConstants().SWRVE_EVENTS_LOCATION + key + "events")
                end if
            end if
        end for

        'Remove from Swrve user ids
        for EACH user in removeUserIds
            userIds.Delete(user)
        end for

        if userIdsCount <> userIds.Count()
            ' there has been a removal so re save
            SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_USER_IDS_KEY, FormatJson(userIds))
        end if
    end if
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

    'used to control campaign refresh
    m.eventsSentOrQueuedRecently = true

    m.eventSendingTimer = 0
    m.numberOfMessagesShown = 0
    m.swrveNextUpdateCampaignsAndResources = CreateObject("roDateTime").AsSeconds()

    updateLastSessionDate()
   
    'Load campaigns, resources and qa dicts from persistence as they might not come down the feed (etag)'
    m.userCampaigns = SwrveLoadUserCampaignsFromPersistence()
    getSwrveNode().userCampaigns = m.userCampaigns

    m.userResources = SwrveLoadUserResourcesFromPersistence()
    getSwrveNode().userResources = m.userResources

    qa = SwrveGetValueFromSection(m.swrve_config.userId, SwrveConstants().SWRVE_USER_QA_FILENAME)
    if qa <> ""
        m.SwrveQA = ParseJSON(qa)
        m.swrve_config.isQAUser = true
        getSwrveNode().isQAUser = true
    end if

    if shouldSendSessionStart
        SWLogDebug("Session started, send session_start for user", m.swrve_config.userId)
        SwrveSessionStart()
        SwrveDeviceUpdate(SwrveDeviceInfosDictionary())
    else
        SWLogDebug("Session continued, keep the session alive for user", m.swrve_config.userId)
    end if

    if firstSession AND m.swrve_config.identifiedOnAnotherDevice = false
        SWLogInfo("It is the first session ever and the user hasn't identified on another device. Send a first_session event")
        SwrveFirstSession()
    end if

    SwrveTidyRegistry()

end function

function SwrveStartHeartbeat()
    delayTimer = m.top.findNode("refreshTimer")
    delayTimer.duration = 5
    delayTimer.ObserveField("fire", "SwrveOnTimer")
    delayTimer.Control = "start"
    m.delayTimer = delayTimer

    SwrveOnTimer()
end function

function SwrveOnClickEvent(payload)
    if(payload <> Invalid)
        if(payload.message <> Invalid AND payload.buttonName <> Invalid)
            SwrveClickEvent(payload.message, payload.buttonName)
        else
            SWLogError("SwrveOnClickEvent invalid values", payload)
        end if
    else
        SWLogError("SwrveOnClickEvent invalid", payload)
    end if
end function


function SwrveOnCurrencyGiven(payload)
    if(payload <> Invalid)
        if(payload.givenCurrency <> Invalid AND payload.givenAmount <> Invalid)
            SwrveCurrencyGiven(payload.givenCurrency, payload.givenAmount)
        else
            SWLogError("SwrveOnCurrencyGiven invalid values", payload)
        end if
    else
        SWLogError("SwrveOnCurrencyGiven invalid", payload)
    end if
end function

function SwrveOnUserUpdateWithDate(payload)
    if(payload <> Invalid)
        if(payload.name <> Invalid AND payload.date <> Invalid)
            SwrveUserUpdateWithDate(payload.name, payload.date)
        else
            SWLogError("SwrveOnUserUpdateWithDate invalid values", payload)
        end if
    else
        SWLogError("SwrveOnUserUpdateWithDate invalid", payload)
    end if
end function

function SwrveOnIAPWithoutReceipt(payload)
    if(payload <> Invalid)
        if(payload.product <> Invalid AND payload.rewards <> Invalid AND payload.currency <> Invalid)
            'no roku store, needs to be unknown for backend
            SwrveIAPWithoutReceipt(payload.product, payload.rewards, payload.currency, "unknown")
        else
            SWLogError("SwrveIAPWithoutReceipt invalid values", payload)
        end if
    else
        SWLogError("SwrveOnIAPWithoutReceipt invalid", payload)
    end if
end function

function SwrveOnIdentify(payload)
    if(payload <> Invalid)
        if(payload.external_user_id <> Invalid)
            SwrveIdentify(payload.external_user_id)
        else
            SWLogError("SwrveOnIdentify invalid values", payload)
        end if
    else
        SWLogError("SwrveIdentify invalid", payload)
    end if
end function

function SwrveOnUserUpdate(payload)
    if(payload <> Invalid)
        SwrveUserUpdate(payload)
    else
        SWLogError("SwrveUserUpdate invalid", payload)
    end if
end function

function SwrveOnPurchase(payload)
    if(payload <> Invalid)
        if(payload.itemQuantity <> Invalid AND payload.itemName <> Invalid AND payload.itemPrice <> Invalid AND payload.itemCurrency <> Invalid)
            SwrvePurchaseEvent(payload.itemQuantity, payload.itemName, payload.itemPrice, payload.itemCurrency)
        else
            SWLogError("SwrvePurchase invalid values", payload)
        end if
    else
        SWLogError("SwrveUserUpdate invalid", payload)
    end if
end function

function SwrveOnEvent(payload)
    if(payload <> Invalid)
        eventName = ""
        eventPayload = Invalid

        if(payload.eventName <> Invalid)
            eventName = payload.eventName
        end if

        if(payload.payload <> Invalid)
            eventPayload = payload.payload
        end if

        if(eventName <> "" AND eventPayload = Invalid)
            SwrveEvent(eventName)
        else if (eventName <> "" AND eventPayload <> Invalid)
            SwrveEvent(eventName, eventPayload)
        else
            SWLogError("SwrveEvent invalid values")
        end if
    else
        SWLogError("SwrveEvent invalid")
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
    if config <> Invalid AND config.DoesExist("stack") AND config.stack = "eu"
        return "eu-"
    else
        return ""
    end if
end function

function SwrveIdentify(externalID as String) as Object
    if(m.swrve_config = Invalid) return Invalid

    m.swrve_config.identifiedOnAnotherDevice = false

    qa = m.SwrveQA
    if(qa <> Invalid AND qa.logging <> Invalid AND qa.logging = true)
        SWLogDebug("QA User sending events")
        SwrveFlushAndCleanQA()
    end if
    SwrveFlushAndClean()

    SwrveStop()
    shouldIdentify = false
    userIDs = SwrveGetValueFromSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_USER_IDS_KEY)
    
    m.dictionaryOfSwrveIDS = Invalid
    if userIDs <> ""
        m.dictionaryOfSwrveIDS = ParseJson(userIDs)
    end if
   
    ' Special case : Identify used wil nil or "" '
    if externalID = ""
        SWLogWarn("SwrveIdentify() Anonymous identify")
        di = CreateObject("roDeviceInfo")
        udid = di.GetRandomUUID()
        m.swrve_config.userId = udid
        SWLogDebug("Event queuing resumed")
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
            m.swrve_config.userId = m.dictionaryOfSwrveIDS[externalID]
        else
            shouldIdentify = true
        end if
    end if

    res = {}
    res.swrve_id = m.swrve_config.userId
    if shouldIdentify
        Identify(externalID, "onIdentifyCallback")
        return {}
    else
        SWLogInfo("Swrve identify: Identity API call skipped, user loaded from cache")
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
    externalID = ""
    if(response.requeststr <> Invalid) requestObj = ParseJSON(response.requeststr)
    if(requestObj.external_user_id <> Invalid) externalID = requestObj.external_user_id


    if response.code = 403
        di = CreateObject("roDeviceInfo")
        udid = di.GetRandomUUID()
        SWLogInfo("Swrve identify: returned 403", response)
        SWLogInfo("Swrve retry identity with new swrve user id")
        IdentifyWithUserID(udid, externalID, "onIdentifyWithUserID")
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
    externalID = ""
    if(response.requeststr <> Invalid) requestObj = ParseJSON(response.requeststr)
    if(requestObj.external_user_id <> Invalid) externalID = requestObj.external_user_id

    res = {}

    if response.code < 400
        res.swrve_id = response.data.swrve_id
        m.dictionaryOfSwrveIDs[externalID] = response.data.swrve_id

        if m.swrve_config.userId <> response.data.swrve_id
            m.swrve_config.userId = response.data.swrve_id
            m.swrve_config.identifiedOnAnotherDevice = true
        end if
        res.status = response.data.status
    else
        if(requestObj.swrve_id <> Invalid) swrve_id = requestObj.swrve_id
        res.swrve_id = swrve_id
        res.status = response.data
    end if

    SWLogInfo("Swrve identity call finished result:",res)
    return onSwrveIdentifyComplete(res)
end function

function onSwrveIdentifyComplete(res)
    m.swrve_config.userId = res.swrve_id

    SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_USER_ID_KEY, res.swrve_id)
    SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_USER_IDS_KEY, FormatJson(m.dictionaryOfSwrveIDs))

    SWLogDebug("Event queuing resumed")
    m.swrve_config.stopped = false ' allow events to be queued
    SwrveStartSession() 'Restart the session for the new user'
    getSwrveNode().identityCallback = res
    SwrveResume() ' resart timer heartbeat
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
            m.swrve_config.userId = m.dictionaryOfSwrveIDS[externalID]
        else
            shouldIdentify = true
        end if
    end if

    res = {}
    res.swrve_id = ""
    if shouldIdentify
        response = GetMockedUserResourcesAndCampaigns(mockedResponse)
        if response.code = 403
            res.status = "external_user_id duplicate or bad userid"
        end if

        if response.code < 400
            res.swrve_id = response.data.swrve_id
            m.dictionaryOfSwrveIDs[externalID] = response.data.swrve_id

            if m.swrve_config.userId <> response.data.swrve_id
                m.swrve_config.userId = response.data.swrve_id
                m.swrve_config.identifiedOnAnotherDevice = true
            end if
            res.status = response.data.status
        else
            res.status = response.data
        end if
    end if

    SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_USER_IDS_KEY, FormatJson(m.dictionaryOfSwrveIDs))

    SwrveResume()
    return res

end function

function SwrveStop()
    SWLogDebug("Pausing event queuing and Swrve Timer")
    if m.swrve_config <> Invalid then m.swrve_config.stopped = true
    if m.delayTimer <> Invalid then m.delayTimer.control = "stop"
end function

function SwrveResume()
    SWLogDebug("Resume Swrve Timer")
    if m.swrve_config <> Invalid then m.swrve_config.stopped = false
    if m.delayTimer <> Invalid
        m.delayTimer.control = "start"
        SwrveOnTimer()
    end if
end function

function SwrveShutdown() as object
    SWLogWarn("Shutdown initiated.")
    SWLogWarn("Shutdown. To use Swrve features you will need to reinitiate.")
    if(m.delayTimer <> Invalid)
        m.delayTimer.control = "stop"
        m.delayTimer = Invalid
    end if

    m.userCampaigns = Invalid
    m.userResources = Invalid
    m.installDate = Invalid
    m.joinedDate = Invalid
    m.eventsQueue = Invalid
    m.eventsQAQueue = Invalid
    m.numberOfMessagesShown = Invalid
    m.swrveNextUpdateCampaignsAndResources = Invalid
    m.swrve_config = Invalid

    SwrveNode = getSwrveNode()
    if SwrveNode <> invalid
        fields = SwrveNode.keys()
        ' Stop watching for public api events
        for each field in fields
            SwrveNode.unobserveField(field)
        end for
    end if

end function

function SwrveOnTimer()
    now = CreateObject("roDateTime")
    nowDate = now.ToISOString()

    nextDate = CreateObject("roDateTime")
    nextDate.FromSeconds(m.swrveNextUpdateCampaignsAndResources)
    nextDate = nextDate.ToISOString()

    SWLogVerbose("")
    SWLogVerbose("SwrveOnTimer now:", nowDate, "nextUpdate", nextDate)
    SWLogVerbose("SwrveOnTimer m.swrve_config.flushingDelay:", m.swrve_config.flushingDelay)
    SWLogVerbose("SwrveOnTimer m.swrve_config.campaignsAndResourcesDelay:", m.swrve_config.campaignsAndResourcesDelay)

    qa = m.SwrveQA
    if(qa <> Invalid AND qa.logging <> Invalid AND qa.logging = true)
        SWLogDebug("QA User sending events")
        SwrveFlushAndCleanQA()
    end if

    m.eventSendingTimer += 5

    nowSeconds = now.AsSeconds()
    if nowSeconds >= m.swrveNextUpdateCampaignsAndResources
        m.swrveNextUpdateCampaignsAndResources = nowSeconds + m.swrve_config.campaignsAndResourcesDelay
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
    else
        'send events every 10 seconds
        if m.eventSendingTimer MOD 10 = 0 
            SwrveFlushAndClean()
        end if 
    end if
end function

function SwrveOnDelayProcessUserCampaignsAndResources()
    SWLogDebug("SwrveOnDelayProcessUserCampaignsAndResources()")
    if m.swrveDelayProcessUserCampaignsAndResources <> Invalid
        m.swrveDelayProcessUserCampaignsAndResources.control = "stop"
        m.swrveDelayProcessUserCampaignsAndResources = Invalid
    end if
    ProcessUserCampaignsAndResources()
end function

function ProcessUserCampaignsAndResources()
    GetUserResourcesAndCampaigns("SwrveOnUserCampaignsAndResources")
end function

function SwrveOnUserCampaignsAndResources(response = {} as Dynamic)

    if(response <> Invalid AND type(response) = "roSGNodeEvent")
        resAndCamp = response.getData()
    end if

    gotNewResourcesOrCampaigns = false

    if resAndCamp <> Invalid AND resAndCamp.code < 400 AND resAndCamp.code > 0
        if m.swrve_config <> Invalid AND resAndCamp.headers <> Invalid AND resAndCamp.headers.etag <> Invalid
            etag = resAndCamp.headers.etag
            SwrveWriteValueToSection(m.swrve_config.userId, SwrveConstants().SWRVE_ETAG_FILENAME, etag)
        end if
        if m.swrve_config <> Invalid AND SwrveDictionaryHasUserResource(resAndCamp) 'If not, it means it hasn't changed (etag check), just use the one from persistence
            gotNewResourcesOrCampaigns = true
            userResources = SwrveGetUserResourcesFromDictionarySafe(resAndCamp)
            userResoucesStr = FormatJSON(userResources)
            userResourcesSignature = SwrveMd5(userResoucesStr)
            m.userResources = userResources
            getSwrveNode().userResources = m.userResources
            m.resourceManager = SwrveResourceManager(userResources)

            SWLogDebug("Saving resources to", SwrveConstants().SWRVE_RESOURCES_LOCATION + GetCurrentUserIDFromConfig() + SwrveConstants().SWRVE_USER_RESOURCES_FILENAME)
            SwrveSaveStringToFile(userResoucesStr, SwrveConstants().SWRVE_RESOURCES_LOCATION  + GetCurrentUserIDFromConfig() + SwrveConstants().SWRVE_USER_RESOURCES_FILENAME)
            SwrveWriteValueToSection(m.swrve_config.userId, SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME, userResourcesSignature)

        end if
        if m.swrve_config <> Invalid AND SwrveDictionaryHasUserCampaigns(resAndCamp)
            gotNewResourcesOrCampaigns = true
            userCampaigns = SwrveGetUserCampaignsFromDictionarySafe(resAndCamp)
            userCampaignsStr = FormatJSON(userCampaigns)
            userCampaignsSignature = SwrveMd5(userCampaignsStr)

            m.userCampaigns = userCampaigns
            getSwrveNode().userCampaigns = m.userCampaigns
           
            SWLogDebug("Saving campaigns to", SwrveConstants().SWRVE_CAMPAIGNS_LOCATION + GetCurrentUserIDFromConfig() + SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME)
            SwrveSaveStringToFile(userCampaignsStr, SwrveConstants().SWRVE_CAMPAIGNS_LOCATION + GetCurrentUserIDFromConfig() + SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME)
            SwrveWriteValueToSection(m.swrve_config.userId, SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME, userCampaignsSignature)

            SwrveCampaignsDownloaded()
            DownloadAssetsFromCampaigns()
        else
            SwrveCheckAssetsAllDownloaded("SwrveDownloadAssetsIfAllAssetsNotDownloaded")
        end if

        if  m.swrve_config <> Invalid  AND resAndCamp.data <> Invalid AND resAndCamp.data.flush_refresh_delay <> Invalid
            SWLogDebug("Updating config flush delay to " + (resAndCamp.data.flush_refresh_delay / 1000).toStr() + " seconds")
            m.swrve_config.flushingDelay = Int(resAndCamp.data.flush_refresh_delay / 1000)
            SwrveFlushAndClean()
        end if

        if  m.swrve_config <> Invalid  AND resAndCamp.data.qa <> Invalid
            m.SwrveQA = resAndCamp.data.qa
            m.swrve_config.isQAUser = SwrveIsQAUser(resAndCamp)
            getSwrveNode().isQAUser = m.swrve_config.isQAUser
            if m.swrve_config.isQAUser
                SwrveWriteValueToSection(m.swrve_config.userId, SwrveConstants().SWRVE_USER_QA_FILENAME, FormatJson(resAndCamp.data.qa))
            end if
        end if

        if m.swrve_config <> Invalid AND resAndCamp.data <> Invalid AND resAndCamp.data.flush_frequency <> Invalid
            SWLogDebug("Updating config campaignsAndResourcesDelay delay to " + (resAndCamp.data.flush_frequency / 1000).toStr() + " seconds")
            m.swrve_config.campaignsAndResourcesDelay = Int(resAndCamp.data.flush_frequency / 1000)
        end if

        'TODO: m.swrve_config.campaignsAndResourcesDelay should update with value from back end. User this ? "flush_frequency": 60000
        if  m.swrve_config <> Invalid 
            now = CreateObject("roDateTime").AsSeconds()
            m.swrveNextUpdateCampaignsAndResources = now + m.swrve_config.campaignsAndResourcesDelay    
        end if

        if getSwrveNode("SwrveOnUserCampaignsAndResources") <> Invalid AND (gotNewResourcesOrCampaigns OR getSwrveNode().resourcesAndCampaignsCallback = false)
            'Notify observers that we got new campaigns and resources'
            getSwrveNode().resourcesAndCampaignsCallback = true
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
    if campaigns <> Invalid
        for each campaign in campaigns.campaigns
            if campaign.messages <> Invalid
                for each message in campaign.messages
                    messageIDs = SwrveBuildArrayOfAssetIDsFromMessage(message)
                    for each id in messageIDs
                        ids.push(id)
                    end for
                end for
            end if
        end for
    end if
    return ids
end function

function SwrveBuildArrayOfAssetIDsFromMessage(message as Object) as Object
    ids = []
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
    if campaigns <> Invalid AND campaigns.campaigns <> Invalid
        ids = SwrveBuildArrayOfAssetIDs(campaigns)
        DownloadAndStoreAssets(ids)
    end if
end function

function assetsDownloadCallback()
    SWLogDebug("Assets downloaded", ListDir(SwrveConstants().SWRVE_ASSETS_LOCATION))
    if getSwrveNode() <> Invalid then getSwrveNode().assetsReady = true
    fakeEvent = SwrveCreateEvent(SwrveConstants().SWRVE_EVENT_AUTOSHOW_SESSION_START)
    SwrveCheckEventForTriggers(fakeEvent)
end function

function RestoreSavedQueueQA()
    savedQueueQA = SwrveGetQueueFromStorage(true)
    SWLogDebug("Saved QA Queue", FormatJson(savedQueueQA))
    if savedQueueQA.Count() > 0 'If so, add them first to the current queue'
        SwrveStorageManager().SwrveClearQueueFromStorage(true)
        wholeQueueQA = []
        wholeQueueQA.append(savedQueueQA)
        wholeQueueQA.append(m.eventsQAQueue)
        m.eventsQAQueue = wholeQueueQA
    end if
end function

function RestoreSavedQueue()
    savedQueue = SwrveGetQueueFromStorage()
    SWLogDebug("Saved Queue", FormatJson(savedQueue))
    if savedQueue.Count() > 0 'If so, add them first to the current queue'
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

function SwrveGetEventsQueue() as Object
    return m.eventsQueue
end function

function SwrveGetQAEventsQueue() as Object
    return m.eventsQAQueue
end function

function SwrveFlushAndClean()
    RestoreSavedQueue()
    SwrvePostQueueAndFlush()
end function

function SwrveFlushAndCleanQA()
    RestoreSavedQueueQA()
    SwrvePostQAQueueAndFlush()
end function

function SaveQueueToPersistence() as Boolean
    if m.eventsQueue <> Invalid AND m.eventsQueue.Count() > 0
        oldqueue = SwrveGetQueueFromStorage()
        oldqueue.append(m.eventsQueue)
        SwrveStorageManager().SwrveSaveQueueToStorage(oldqueue)
        m.eventsQueue.Clear()
    end if
end function

' Returns a dictionary of default user update properties'
function SwrveDeviceInfosDictionary() as Object
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

    osVersion = device.GetOsVersion()
    osVersion = osVersion.major + "." + osVersion.minor + "." + osVersion.revision + "." + osVersion.build

    attributes = {
        "swrve.device_name": "Roku" + device.GetModel().Trim(),
        "swrve.os": "roku",
        "swrve.os_version": osVersion,
        "swrve.device_width": box(device.GetDisplaySize().w),
        "swrve.device_height": device.GetDisplaySize().h,
        "swrve.language": device.GetCurrentLocale(),
        "swrve.device_region": "US",
        "swrve.sdk_version": SwrveConstants().SWRVE_SDK_VERSION,
        "swrve.app_store": "google", 'Will have to be changed to roku when supported by backend'
        "swrve.timezone_name": device.GetTimeZone(),
        "swrve.utc_offset_seconds": utcSecondsOffset,
        "swrve.install_date": strDate,
        "swrve.device_type": "tv"
    }
    return attributes
end function

' Read the installation date. If it doesn't exist, save it to registry
function checkOrWriteInstallDate() as Object
    dateString = SwrveGetValueFromSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_INSTALL_DATE_KEY)
    if dateString = ""
        date = CreateObject("roDateTime")
        dateString = date.ToISOString()
        SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_INSTALL_DATE_KEY, dateString)
        SWLogInfo("Updating first install date:", dateString)
    else
        SWLogDebug("First install date:", dateString)
    end if
    return dateString
end function

' Read the joined date. If it doesn't exist, save it to registry
function checkOrWriteJoinedDate() as Object

    dateString = SwrveGetValueFromSection(m.swrve_config.userId, SwrveConstants().SWRVE_JOINED_DATE_KEY)
    if dateString = ""
        date = CreateObject("roDateTime")
        dateString = date.ToISOString()
        SwrveWriteValueToSection(m.swrve_config.userId, SwrveConstants().SWRVE_JOINED_DATE_KEY, dateString)
        SWLogInfo("Updating first joined date:", dateString)
    else
        SWLogDebug("First joined date:", dateString)
    end if
    return dateString
end function

' Read the device id . If it doesn't exist, save it to registry
function checkOrWriteDeviceID() as Object
    key = SwrveConstants().SWRVE_UNIQUE_DEVICE_ID_KEY
    udid = SwrveGetValueFromSection(SwrveConstants().SWRVE_SECTION_KEY, key)
    if udid = ""
        di = CreateObject("roDeviceInfo")
        udid = di.GetRandomUUID()
        SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, key, udid)
    end if

    return udid
end function

'Creates or returns a random user id'
function GetDefaultUserID() as String
    key = SwrveConstants().SWRVE_USER_ID_KEY
    userID = SwrveGetValueFromSection(SwrveConstants().SWRVE_SECTION_KEY, key)
    if userID = ""
        di = CreateObject("roDeviceInfo")
        userID = di.GetRandomUUID()
        SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, key, userID)
    end if

    return userID
end function

' read the last date the channel was live'
function lastSessionDate() as Object
    key = SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY
    dateString = SwrveGetValueFromSection(m.swrve_config.userId, key)
    if dateString = ""
        return Invalid
    end if
    date = CreateObject("roDateTime")
    date.fromISO8601String(dateString)
    return date
end function

function SwrveFirstEverSession() as Boolean
    dateString = SwrveGetValueFromSection(m.swrve_config.userId, SwrveConstants().SWRVE_JOINED_DATE_KEY)
    if dateString = ""
        return true
    else
        return false
    end if
end function

function SetSessionStartDate() as String
    date = CreateObject("roDateTime")
    SwrveWriteValueToSection(m.swrve_config.userId, SwrveConstants().SWRVE_START_SESSION_DATE_KEY, date.ToISOString())
    return StrI(date.AsSeconds()).Trim()
end function

function GetSessionStartDate() as String
    dateString = SwrveGetValueFromSection(m.swrve_config.userId, SwrveConstants().SWRVE_START_SESSION_DATE_KEY)
    if dateString <> ""
        date = CreateObject("roDateTime")
        date.FromISO8601String(dateString)
        return StrI(date.AsSeconds()).Trim()
    end if
    return ""
end function

function GetSessionStartDateAsSeconds() as Integer
    dateString = SwrveGetValueFromSection(m.swrve_config.userId, SwrveConstants().SWRVE_START_SESSION_DATE_KEY)
    if dateString <> ""
        date = CreateObject("roDateTime")
        date.FromISO8601String(dateString)
        return date.AsSeconds()
    end if
    return -1
end function

function GetCurrentUserIDFromConfig() as String
    if m.swrve_config = Invalid then return ""
    return m.swrve_config.userId
end function

function GetUserQAStatus() as Boolean
    if m.swrve_config = Invalid then return false
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
function updateLastSessionDate()
    date = CreateObject("roDateTime")
    SwrveWriteValueToSection(m.swrve_config.userId, SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY, date.ToISOString())
end function

'Returns the api key'
function GetAPIKey() as String
    return m.swrve_config.apikey
end function

'returns the install date'
function GetInstallDate() as Integer
    date = checkOrWriteInstallDate()
    return date.AsSeconds()
end function

'returns the joined date'
function GetJoinedDate() as Integer
    date = checkOrWriteJoinedDate()
    return date.AsSeconds()
end function

function RemoveIAMInClient()
    m.top.GetScene().dialog = Invalid
end function

function ShowIAMInClient()
    if getSwrveNode() <> Invalid AND getSwrveNode().showIAM
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

function SwrveLoadUserResourcesFromPersistence() as Object
	resourceLocalSource = SwrveConstants().SWRVE_RESOURCES_LOCATION + GetCurrentUserIDFromConfig() + SwrveConstants().SWRVE_USER_RESOURCES_FILENAME
	SWLogDebug("Attempt to load resource cache file ", resourceLocalSource)
	resourceString = SwrveGetStringFromFile(resourceLocalSource)
	if SwrveIsResourceFileValid(resourceString) 'checks that signature is still correct'
		if resourceString = ""
			SwrveDeleteKeyFromSection(GetCurrentUserIDFromConfig(), SwrveConstants().SWRVE_ETAG_FILENAME)
			return []
		end if
		return ParseJSON(resourceString)
	else
		SwrveDeleteKeyFromSection(GetCurrentUserIDFromConfig(), SwrveConstants().SWRVE_ETAG_FILENAME)
		return []
	end if
end function