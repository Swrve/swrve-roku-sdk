' Used in the main thread and in the Render thread.
function SwrveConstants() as Object

    return {
        SWRVE_SDK_VERSION: "Roku 5.0"
        SWRVE_CONVERSATION_VERSION: "4"
        SWRVE_CAMPAIGN_RESOURCES_API_VERSION: "7"

        SWRVE_INSTALL_DATE_KEY: "ind"
        SWRVE_JOINED_DATE_KEY: "ind"

        SWRVE_UNIQUE_DEVICE_ID_KEY: "udi"
        SWRVE_USER_ID_KEY: "sui"
        SWRVE_USER_IDS_KEY: "suids"
        SWRVE_LAST_SESSION_DATE_KEY: "lsd"
        SWRVE_START_SESSION_DATE_KEY: "ssd"

        SWRVE_EVENTS_FILENAME: "events"
        SWRVE_USER_RESOURCES_FILENAME: "resources"
        SWRVE_USER_CAMPAIGNS_FILENAME: "campaigns"

        SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME: "clmt"
        SWRVE_USER_CAMPAIGNS_IMPRESSIONS: "ci"

        SWRVE_CAMPAIGN_STATE_PREFIX: "cs"

        SWRVE_USER_QA_FILENAME: "qa"
        SWRVE_ETAG_FILENAME: "etag"
        SWRVE_USER_RESOURCES_SIGNATURE_FILENAME: "rsg"
        SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME: "csg"

        SWRVE_SEQNUM: "seq"
        SWRVE_HTTPS: "https://"
        SWRVE_API_ENDPOINT: "api.swrve.com"
        SWRVE_CONTENT_ENDPOINT: "content.swrve.com"
        SWRVE_BATCH_URL: "/1/batch"
        SWRVE_IDENTIFY_URL: "identity.swrve.com/identify"
        SWRVE_USER_CONTENT_URL: "/api/1/user_content"
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
        SWRVE_JSON_LOCATION: "pkg:/source/JSONFiles/"
        SWRVE_ASSETS_LOCATION: "cachefs:/"
        SWRVE_CAMPAIGNS_LOCATION: "cachefs:/"
        SWRVE_RESOURCES_LOCATION: "cachefs:/"
        SWRVE_EVENTS_LOCATION: "cachefs:/"
        SWRVE_EQUAL: "eq"
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
        SWRVE_MIGRATION_KEY: "mv"
        SWRVE_MIGRATION_VERSION: "1"
        SWRVE_SECTION_KEY: "Swrve"
    }
end function