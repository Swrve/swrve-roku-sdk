
' Swrve instance creator.'
function Swrve(config as Object, port as Object) as Object
    di = CreateObject("roDeviceInfo")
    m.global = getGlobalAA().global
    this = {
        private: {
            ' configuration items.'
            config: {
                version: "7" 
                userId: SWObject(config.userId).default(GetDefaultUserID())
                orientation: "Landscape"
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
                deviceId: SWObject(config.deviceId).default("Unknown")
                deviceID: checkOrWriteQADeviceID()

                queueMaxSize: SWObject(config.queueMaxSize).default(1000)
                flushingDelay:  SWObject(config.flushingDelay).default(10)
                campaignsAndResourcesDelay:  SWObject(config.campaignsAndResourcesDelay).default(60)

                mockHTTPPOSTResponses: SWObject(config.mockHTTPPOSTResponses).default(false)
                mockedPOSTResponseCode: SWObject(config.mockedPOSTResponseCode).default(200)
                mockHTTPGETResponses: SWObject(config.mockHTTPGETResponses).default(false)
                mockedGETResponseCode: SWObject(config.mockedGETResponseCode).default(200)
                session_token : ""
                isQAUser: false
                mutedMode: false
            }
            installDate: CreateObject("roDateTime")
            lastSession: CreateObject("roDateTime")
        }

        eventsQueue: []

        userResources: []
        userCampaigns: {}

        numberOfMessagesShown : 0
        startSessionAsSeconds : CreateObject("roDateTime").AsSeconds()
        swrveNextFlush : CreateObject("roDateTime").AsSeconds()+1 'Set it as +1 to flush on startup after 1 sec'
        swrveNextUpdateCampaignsAndResources : CreateObject("roDateTime").AsSeconds()+1 'Set it as +1 to flush on startup after 1 sec'

        'Methods'
        swrveListener: SwrveListener
        SwrveEvent: SwrveEvent
        SwrveFlushQueue: SwrveFlushQueue
        PostQueueAndFlush: PostQueueAndFlush
        SwrveForceFlush: SwrveForceFlush
        SwrveUserUpdate: SwrveUserUpdate
        SwrvePurchaseEvent: SwrvePurchaseEvent
        SwrveCurrencyGiven: SwrveCurrencyGiven
        SwrveUserUpdateWithDate: SwrveUserUpdateWithDate
        SwrveIAPWithoutReceipt: SwrveIAPWithoutReceipt
        SwrveProduct: SwrveProduct
        SwrveReward: SwrveReward
        GetSessionStartDateAsReadable: GetSessionStartDateAsReadable
        SwrveShutdown: SwrveShutdown
        SwrveSessionStart: SwrveSessionStart
        SwrveFirstSession: SwrveFirstSession
        SwrveMute: SwrveMute
        SwrveUnmute: SwrveUnmute
        SwrveGetUserResourcesDiff: SwrveGetUserResourcesDiff
        GetSessionStartDateAsSeconds: GetSessionStartDateAsSeconds
        setCustomCallback: setCustomCallback
        setNewResourcesCallback: setNewResourcesCallback
        setNewResourcesDiffCallback: setNewResourcesDiffCallback
        setCustomMessageRender: setCustomMessageRender
        SwrveClickEvent: SwrveClickEvent
        SwrveImpressionEvent: SwrveImpressionEvent
        SwrveReturnedMessageEvent: SwrveReturnedMessageEvent

    }

    this.private.config.device_id = di.GetDeviceUniqueId()

    SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_ID_KEY, this.private.config.userID)
    ' Generate Token

    this.configuration = SWObject(this.private.config).copy(1)

    ' Set the config as an accessible object'

    'm.global is a global node accessible from anywhere in the app.'
    m.global.AddFields( {"swrve": this})

    'This will be used as an observed value to show IAMs from anywhere in the app'
    m.global.AddField("swrveShowIAM", "boolean", true)
    m.global.setField("swrveShowIAM", false)

    'This will be used as an observed value to show IAMs from anywhere in the app'
    m.global.AddField("swrveCurrentIAM", "assocarray", true)
    m.global.setField("swrveCurrentIAM", false)


    'This will be used as an observed value for users to get the resources Diff'
    m.global.AddFields( {"swrveResourcesDiff": false })
    m.global.observeField("swrveResourcesDiff", port)

    'This value can be observed and will be notified everytime we get a new campaign/resources file'
    m.global.AddField("swrveResourcesAndCampaigns", "boolean", true)
    m.global.setField("swrveResourcesAndCampaigns", false)

    'This value can be observed and will be notified when the diff is ready
    m.global.AddField("swrveResourcesDiffObjectReady", "assocarray", true)
    m.global.setField("swrveResourcesDiffObjectReady", {})

    'This value can be observed and will be notified when the assets have been downloaded
    m.global.AddField("swrveAssetsReady", "boolean", true)
    m.global.setField("swrveAssetsReady", false)

    'This will be observed in case we need to force flush the events. It means that notifying from a component can be done from any thread'
    'But receiving the notification and acting on it will be done on the main thread, which is safe.'
    m.global.AddFields( {"forceFlush": false })
    m.global.observeField("forceFlush", port)

     'This value will be used to notify the custom callback for rendering messages
    m.global.AddField("messageWillRender", "assocarray", true)
    m.global.setField("messageWillRender", {})

    m.global.AddField("swrveSDKHasCustomRenderer", "boolean", true)
    m.global.setField("swrveSDKHasCustomRenderer", false)

    ' True if there is no install date for this user, meaning it is the first ever session'
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

    this.configuration.session_token = generateToken(startTimestamp, this.private.config.userId, this.private.config.apikey, this.private.config.appId)

    this.private.addreplace("installDate", checkOrWriteInstallDate())
    this.private.addreplace("lastSession", updateLastSessionDate())
    this.private.addreplace("startSession", GetSessionStartDate())

    'Load campaigns, resources and qa dicts from persistence as they might not come down the feed (etag)'
    this.userCampaigns = LoadUserCampaignsFromPersistence()
    this.userResources = LoadUserResourcesFromPersistence()
    
    if this.userCampaigns.cdn_paths <> invalid
        this.userCampaigns.cdn_root = this.userCampaigns.cdn_paths.message_images
    end if
  
    qa = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_QA_FILENAME, "")    
    if qa <> ""
        this.qa = ParseJSON(qa)
        this.private.config.isQAUser = true
    end if
    SynchroniseSwrveInstance(this)
    if shouldSendSessionStart
        SWLog("Session started, send session_start.")
        'TODO Reset campaign states & global impression states'
        SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME)    
        SwrveSessionStart(this)
        SwrveUserUpdate(this, userInfosDictionary())
        if firstSession
            SWLog("It is the first session ever. Send a first_session event")
            SwrveFirstSession(this)
        end if
    else
        SWLog("Session continued, keep the session alive")
    end if
  
    return this
end function

function SwrveGetUserResourcesDiff(swrveClient as Object) 
    m.global = getGlobalAA().global
    m.global.swrveResourcesDiff = true 'Triggers the call so that it originates from the listener on main thread'
end Function


' This will put the current instance into this. Because brightscript clears the functions and methods,
' we need to copy them again into the right pointers to functions in order to use them from anywhere in the app
function GetSwrveClientInstance() as Object
    this = m.global.swrve
    if this = invalid
        return invalid
    end if
    'Copy all the public methods'
    this.swrveListener = SwrveListener
    this.SwrveEvent = SwrveEvent
    this.SwrveFlushQueue = SwrveFlushQueue
    this.PostQueueAndFlush = PostQueueAndFlush
    this.SwrveForceFlush = SwrveForceFlush
    this.SwrveUserUpdate = SwrveUserUpdate
    this.SwrvePurchaseEvent = SwrvePurchaseEvent
    this.SwrveCurrencyGiven = SwrveCurrencyGiven
    this.SwrveUserUpdateWithDate = SwrveUserUpdateWithDate
    this.SwrveIAPWithoutReceipt = SwrveIAPWithoutReceipt
    this.SwrveProduct = SwrveProduct
    this.SwrveReward = SwrveReward
    this.GetSessionStartDateAsReadable = GetSessionStartDateAsReadable
    this.SwrveShutdown = SwrveShutdown
    this.SwrveSessionStart = SwrveSessionStart
    this.SwrveFirstSession = SwrveFirstSession
    this.GetCurrentUserID = GetCurrentUserID
    this.SwrveMute = SwrveMute
    this.SwrveUnmute = SwrveUnmute
    this.SwrveGetUserResourcesDiff = SwrveGetUserResourcesDiff
    this.resourceManager = SwrveResourceManager(this.userResources)
    this.GetSessionStartDateAsSeconds = GetSessionStartDateAsSeconds
    this.setCustomCallback = setCustomCallback
    this.setNewResourcesCallback = setNewResourcesCallback
    this.setNewResourcesDiffCallback = setNewResourcesDiffCallback
    this.SwrveClickEvent = SwrveClickEvent
    this.SwrveImpressionEvent = SwrveImpressionEvent
    this.SwrveReturnedMessageEvent = SwrveReturnedMessageEvent
    this.setCustomMessageRender = setCustomMessageRender
    return this
End function

' the instance was only a copy, Sync it back to global
function SynchroniseSwrveInstance(instance as Object)
    m.global.swrve = instance
end function

Function GetStack(config as Object) as String
    if config.DoesExist("stack") and config.stack = "eu"
        return "eu-"
    else 
        return ""
    end if
End Function

Function SwrveMute(swrveClient as Object)
    'SaveQueueToPersistence(swrveClient)
    swrveClient.configuration.mutedMode = true
    SynchroniseSwrveInstance(swrveClient)
End Function

Function SwrveUnmute(swrveClient as Object)
    swrveClient.configuration.mutedMode = false
    SynchroniseSwrveInstance(swrveClient)
End Function

Function SwrveShutdown()
    m.global = getGlobalAA().global
    m.global.swrveResourcesAndCampaigns = false
    SWLog("Shutdown initiated.")
    SWLog("Shutdown initiated....Flushing queue")

    swrveClient = GetSwrveClientInstance()
    'Save queue to persistant storage. It will be sent to the backend the enxt time that user starts a session'
    'SaveQueueToPersistence(swrveClient)
    'Not needed anymore as every event is now going to persistence straight away'

    SWLog("Shutdown initiated....clearing persistent storage")
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_SEQNUM)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_EVENTS_STORAGE)
    SwrveClearKeyFromPersistence(SwrveConstants().SWRVE_ETAG_FILENAME)

    SWLog("Shutdown initiated....Clearing memory")

    SWLog("Shutdown. To use Swrve features you will need to create a new instance.")

    m.global.swrve = invalid
    swrveClient = invalid
    m.global.Delete("swrve")
End Function

' Has to be called by the use in the main while true loop in the Main file, to handle events and messages
function SwrveListener(swrveClient as Object, msg as dynamic) as Void
    msgType = type(msg)

    if msgType = "roSGNodeEvent"
        if msg.getField() = "forceFlush" and msg.getData() = true
            SWLog("Force flush has been requested.")
            m.global = getGlobalAA().global
            flushAndClean(swrveClient)
            m.global.forceFlush = false
        end if
    end if
    if msgType = "roSGNodeEvent"
        if msg.getField() = "swrveResourcesDiff" and msg.getData() = true
            SWLog("swrveResourcesDiff has been requested.")
            m.global = getGlobalAA().global
            m.global.swrveResourcesDiffObjectReady = GetResourcesDiffSorted()
            m.global.swrveResourcesDiff = false
        end if
    end if
    'This will check the time and see if it has been x seconds..if yes flush the buffer'
    now = CreateObject("roDateTime").AsSeconds()
    if now > swrveClient.swrveNextFlush then
        flushAndClean(swrveClient)
        updateLastSessionDate()
    end if
    if now > swrveClient.swrveNextUpdateCampaignsAndResources
        processUserCampaignsAndResources(swrveClient)
    end if
end function

'Sets an observer and a callback defined by user, for when users select a button on an iam'
Function setCustomCallback(context as Object, callbackName as String)
    if context.swrveiamgroup <> invalid
        context.swrveiamgroup.observeField("customActionCallback", callbackName)
    end if
End Function

'Sets an observer and a callback defined by user, for when users select a button on an iam'
Function setNewResourcesCallback(callbackName as String)
    m.global = getGlobalAA().global
    m.global.observeField("swrveResourcesAndCampaigns", callbackName)
End Function

Function setCustomMessageRender(callbackName as String)
    m.global = getGlobalAA().global
    m.global.observeField("messageWillRender", callbackName)
    swrve = GetSwrveClientInstance()
    m.global.swrveSDKHasCustomRenderer = true
    SynchroniseSwrveInstance(swrve)
End Function

Function setNewResourcesDiffCallback(callbackName as String)
    m.global = getGlobalAA().global
    m.global.observeField("swrveResourcesDiffObjectReady", callbackName)
End Function

Function processUserCampaignsAndResources(swrveClient)
    
    gotNewResourcesOrCampaigns = false
    resAndCamp = GetUserResourcesAndCampaigns()
    if resAndCamp.code < 400
        if resAndCamp.headers <> invalid and resAndCamp.headers.etag <> invalid
            etag = resAndCamp.headers.etag
            SwrveSaveStringToPersistence(SwrveConstants().SWRVE_ETAG_FILENAME, etag)
        end if
        if DictionaryHasUserResource(resAndCamp) 'If not, it means it hasn't changed (etag check), just use the one from persistence
            gotNewResourcesOrCampaigns = true
            userResources = GetUserResourcesFromDictionarySafe(resAndCamp)
            userResoucesStr = FormatJSON(userResources)
            userResourcesSignature = md5(userResoucesStr)
            swrveClient.userResources = userResources
            swrveClient.resourceManager = SwrveResourceManager(userResources)
            userResourcesStoredSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME)

            if userResourcesStoredSignature <> userResourcesSignature
                'store it and its signature'
                SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_RESOURCES_FILENAME, userResoucesStr)
                SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME, userResourcesSignature)
            end if
        end if
        if DictionaryHasUserCampaigns(resAndCamp)
            gotNewResourcesOrCampaigns = true
            userCampaigns = GetUserCampaignsFromDictionarySafe(resAndCamp)
            userCampaignsStr = FormatJSON(userCampaigns)
            userCampaignsSignature = md5(userCampaignsStr)
            userCampaignsStoredSignature = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME)

            swrveClient.userCampaigns = userCampaigns
            if userCampaigns.cdn_root <> invalid
                swrveClient.userCampaigns.cdn_root = userCampaigns.cdn_root
            else if userCampaigns.cdn_paths <> invalid
                swrveClient.userCampaigns.cdn_root = userCampaigns.cdn_paths.message_images
            end if
            if userCampaignsStoredSignature <> userCampaignsSignature
                'store it and its signature'
                SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME, userCampaignsStr)
                SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME, userCampaignsSignature)
            end if
            SwrveCampaignsDownloaded(swrveClient)
            DownloadAssetsFromCampaigns(swrveClient, userCampaigns)
        else
          
            if not CheckAssetsAllDownloaded(swrveClient)
                DownloadAssetsFromCampaigns(swrveClient, swrveClient.userCampaigns)
            end if 

        end if
        if resAndCamp.data <> invalid and resAndCamp.data.flush_frequency <> invalid
            swrveClient.configuration.flushingDelay = Int(resAndCamp.data.flush_frequency / 1000)
            flushAndClean(swrveClient)
        end if
        if resAndCamp.data.qa <> invalid
            swrveClient.configuration.isQAUser = IsQAUser(resAndCamp)
            if swrveClient.configuration.isQAUser
                SwrveSaveObjectToPersistence(SwrveConstants().SWRVE_USER_QA_FILENAME, resAndCamp.data.qa)
                'Investigate as to why there is no logging_url in the qa json object.'
                'userPropertiesToBabble(swrveClient, resAndCamp.data.qa)
            end if
        end if
        swrveClient.swrveNextUpdateCampaignsAndResources += swrveClient.configuration.campaignsAndResourcesDelay
        SynchroniseSwrveInstance(swrveClient)
        if gotNewResourcesOrCampaigns or m.global.swrveResourcesAndCampaigns = false
         
            'Notify observers that we got new campaigns and resources'
            m.global = getGlobalAA().global
            m.global.swrveResourcesAndCampaigns = true
           
        end if
    else 
        swrveClient.swrveNextUpdateCampaignsAndResources += swrveClient.configuration.campaignsAndResourcesDelay
        SynchroniseSwrveInstance(swrveClient)
    end if
End Function

Function BuildArrayOfAssetIDs(swrveClient, campaigns as object) as object
    ids = []
    for each campaign in campaigns.campaigns
        if campaign.messages <> invalid
            for each message in campaign.messages
                if message.template <> invalid
                    if message.template.formats <> invalid
                        for each format in message.template.formats
                            if format.images <> invalid
                                for each image in format.images 
                                    if image.image <> invalid and image.image.type = "asset"
                                        id = image.image.value
                                        ids.push(id)
                                    end if
                                end for
                            end if
                            if format.buttons <> invalid
                                for each button in format.buttons 
                                    if button.image_up <> invalid and button.image_up.type = "asset"
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
End Function

Function DownloadAssetsFromCampaigns(swrveClient as Object, campaigns as Object) 
    if campaigns.campaigns <> invalid
        ids = BuildArrayOfAssetIDs(swrveClient, campaigns)
        DownloadAndStoreAssets(swrveClient, ids, assetsDownloadCallback)
    end if
End Function

Function assetsDownloadCallback()   
    swrveClient = GetSwrveClientInstance()
    m.global.swrveAssetsReady = true
    fakeEvent = SwrveCreateEvent(SwrveConstants().SWRVE_EVENT_AUTOSHOW_SESSION_START)
    CheckEventForTriggers(swrveClient, fakeEvent)
End function

' Returns what's in the saved queue. returns an empty array if nothing was saved
Function CheckForSavedQueue(swrveClient as Object) as Object
    savedQueue = SwrveStorageManager().SwrveGetQueueFromStorage()
    if savedQueue <> invalid and type(savedQueue) = "roArray" and savedQueue.count() > 0
        return savedQueue
    end if
    return []
End Function

Function RestoreSavedQueue(swrveClient as Object) as Object
    savedQueue = CheckForSavedQueue(swrveClient) 'Checking if there are any saved events we need to recover'
    if savedQueue.count() > 0 'If so, add them first to the current queue'
        SwrveStorageManager().SwrveClearQueueFromStorage()

        wholeQueue = []
        wholeQueue.append(savedQueue)
        wholeQueue.append(swrveClient.eventsQueue)
        swrveClient.eventsQueue = wholeQueue
    end if    

    SynchroniseSwrveInstance(swrveClient)
    return swrveClient
end function

Function flushAndClean(swrveClient as Object)
 
    swrveClient = RestoreSavedQueue(swrveClient) 'Checking if there are any saved events we need to recover'

    success = swrveClient.PostQueueAndFlush(swrveClient) 
    swrveClient.swrveNextFlush = swrveClient.swrveNextFlush + swrveClient.configuration.flushingDelay
    SynchroniseSwrveInstance(swrveClient)
End Function


Function SwrveForceFlush()
    'request that we force the update to flush
    if m.global = invalid
        m.global = getGlobalAA().global
    end if
    m.global.forceFlush = true
End Function


Function SaveQueueToPersistence(swrveClient as Object) as Boolean
    if swrveClient.eventsQueue <> invalid and swrveClient.eventsQueue.Count() > 0
        oldqueue = SwrveGetQueueFromStorage()
        oldqueue.append(swrveClient.eventsQueue)
        success = SwrveStorageManager().SwrveSaveQueueToStorage(oldqueue)
        swrveClient.eventsQueue.Clear()
        SynchroniseSwrveInstance(swrveClient)
    end if
End Function


' Returns a dictionary of default user update properties'
Function userInfosDictionary() as Object
    device = CreateObject("roDeviceInfo")

    dt = CreateObject ("roDateTime")
    utcSeconds = dt.AsSeconds()
    dt.ToLocalTime()
    localSeconds = dt.AsSeconds()
    utcSecondsOffset = localSeconds - utcSeconds

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
        "swrve.utc_offset_seconds": utcSecondsOffset
    }
    return attributes
End Function

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

' Read the QA device id . If it doesn't exist, save it to registry
function checkOrWriteQADeviceID() as Object
    
    did = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_QA_DEVICE_ID_KEY, "")
    if did = ""
        nb = Rnd(65535) 'unsigned short int'
        did = StrI(nb).Trim()
        SwrveSaveStringToPersistence(SwrveConstants().SWRVE_QA_DEVICE_ID_KEY, did)
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
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_INSTALL_DATE_KEY, "")
    if dateString = ""
        return true
    else
        return false
    end if
end function

Function SetSessionStartDate() as String
    date = CreateObject("roDateTime")
    SwrveSaveStringToPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, date.ToISOString())
    return StrI(date.AsSeconds()).Trim()
End Function

Function GetSessionStartDate() as String
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
    date = CreateObject("roDateTime")
    if dateString <> ""
        date.FromISO8601String(dateString)
        return StrI(date.AsSeconds()).Trim()
    end if
End Function

Function GetSessionStartDateAsSeconds() as Integer
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
    date = CreateObject("roDateTime")
    if dateString <> ""
        date.FromISO8601String(dateString)
        return date.AsSeconds()
    end if
    return -1
end Function

Function GetSessionStartDateAsReadable() as String
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_START_SESSION_DATE_KEY, "")
    return dateString
End Function

Function GetCurrentUserID() as String
    dateString = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_ID_KEY, "")
    return dateString
End Function

Function GetUserQAStatus(swrveClient as Object) as Boolean
    return swrveClient.configuration.isQAUser
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
    SWLog("Last session was " + str(difference) + " seconds ago. Session interval is " +  str(m.global.swrve.private.config.newSessionInterval) + " seconds")
    if difference > m.global.swrve.private.config.newSessionInterval
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
        SWLog("Updating last session time " + dateString)
    end if
    return dateString 

end function

'Returns the api key'
Function GetAPIKey(swrveClient) as String
    return swrveClient.configuration.apikey
End Function

'returns the install date'
Function GetInstallDate(swrveClient) as Integer
    date = checkOrWriteInstallDate()
    return date.AsSeconds()
End Function

