' Used in the main thread and in the Render thread. 
function SwrveConstants() as Object

    userID = SwrveGetStringFromPersistence("userID", "")
    
    return {
        SWRVE_SDK_VERSION: "Roku 3.0"

        SWRVE_INSTALL_DATE_KEY: "install_date"
        SWRVE_JOINED_DATE_KEY: userID + "install_date"

        SWRVE_QA_UNIQUE_DEVICE_ID_KEY: "unique_device_id"
        SWRVE_USER_ID_KEY : "userID"
        SWRVE_USER_IDS_KEY : "swrveUserIDs"
        SWRVE_LAST_SESSION_DATE_KEY: userID + "last_session_date"
        SWRVE_START_SESSION_DATE_KEY: userID + "start_session_date"
        SWRVE_USER_RESOURCES_FILENAME: userID + "resources"
        SWRVE_USER_CAMPAIGNS_FILENAME: userID + "campaigns"
        SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME: userID + "campaigns_lastmessagetime"
        SWRVE_USER_CAMPAIGNS_IMPRESSIONS: userID + "campaigns_impressions"

        SWRVE_CAMPAIGN_STATE_PREFIX: userID + "campaignState"

        SWRVE_USER_QA_FILENAME: userID + "qa"
        SWRVE_ETAG_FILENAME: userID + "etag"
        SWRVE_USER_RESOURCES_SIGNATURE_FILENAME: userID + "resources_signature"
        SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME: userID + "campaigns_signature"

        SWRVE_SEQNUM: userID + "swrve_seqnum"
        SWRVE_HTTPS: "https://"
        SWRVE_API_ENDPOINT: "api.swrve.com"
        SWRVE_CONTENT_ENDPOINT: "content.swrve.com"
        SWRVE_BATCH_URL: "/1/batch"
        SWRVE_IDENTIFY_URL: "identity.swrve.com/identify"
        SWRVE_USER_RESOURCES_AND_CAMPAIGNS_URL: "/api/1/user_resources_and_campaigns"
        SWRVE_USER_RESOURCES_DIFF_URL: "/api/1/user_resources_diff"

        SWRVE_EVENT_TYPE_EVENT: "event"
        SWRVE_EVENT_TYPE_USER_UPDATE: "user"
        SWRVE_EVENT_TYPE_DEVICE_UPDATE: "device_update"
        SWRVE_EVENT_TYPE_PURCHASE: "purchase"
        SWRVE_EVENT_TYPE_CURRENCY_GIVEN: "currency_given"
        SWRVE_EVENT_TYPE_IAP: "iap"
        SWRVE_EVENT_TYPE_SESSION_START: "session_start"
        SWRVE_EVENT_FIRST_SESSION_STRING: "Swrve.first_session"
        SWRVE_EVENT_CAMPAIGNS_DOWNLOADED: "Swrve.Messages.campaigns_downloaded"
        SWRVE_EVENT_AUTOSHOW_SESSION_START: "Swrve.Messages.showAtSessionStart"
        SWRVE_EVENTS_STORAGE: userID + "SWRVE_EVENTS_STORAGE"
        SWRVE_JSON_LOCATION: "pkg:/source/JSONFiles/"
        SWRVE_ASSETS_LOCATION: "tmp:/swrveAssets/"
        SWRVE_EQUAL : "eq"
        SWRVE_NOT_EQUAL: "not"
        SWRVE_AND: "and"
        SWRVE_OR: "or"
        SWRVE_BUTTON_DISMISS: "DISMISS"
        SWRVE_BUTTON_CUSTOM: "CUSTOM"
        SWRVE_FHD_WIDTH: 1920
        SWRVE_FHD_HEIGHT: 1080
        SWRVE_DEFAULT_DELAY_FIRST_MESSAGE: 150
        SWRVE_DEFAULT_MAX_SHOWS: 99999
        SWRVE_DEFAULT_MIN_DELAY: 55
    }
end function
