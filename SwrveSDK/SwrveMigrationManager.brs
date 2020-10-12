function Migrate() as Object
    ' Migration 1 check
    currentUserID = SwrveGetStringFromPersistence("userID", "")
    if (currentUserID <> "")
        Migration1()
        ' save migration value for future migration checks
        SwrveWriteValueToSection(SwrveConstants().SWRVE_SECTION_KEY, SwrveConstants().SWRVE_MIGRATION_KEY, SwrveConstants().SWRVE_MIGRATION_VERSION)
    end if
end function

function Migration1()
    SWLogInfo("Swrve running migration 1")
    registry = CreateObject("roRegistry")

    currentUserID = SwrveGetStringFromPersistence("userID", "")
    otherUserIDs = SwrveGetObjectFromPersistence("swrveUserIDs")

    ' migrate core data to Swrve registry section
    MigrateValueToNewSection(registry, SwrveConstants().SWRVE_SECTION_KEY, "install_date", SwrveConstants().SWRVE_INSTALL_DATE_KEY)
    MigrateValueToNewSection(registry, SwrveConstants().SWRVE_SECTION_KEY, "unique_device_id", SwrveConstants().SWRVE_UNIQUE_DEVICE_ID_KEY)
    MigrateValueToNewSection(registry, SwrveConstants().SWRVE_SECTION_KEY, "userID", SwrveConstants().SWRVE_USER_ID_KEY)

    ' migrate campaigns and resources from registry to cachefs
    MigrateValueToNewCache(registry, SwrveConstants().SWRVE_CAMPAIGNS_LOCATION + currentUserID + SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME, currentUserID + "campaigns")
    MigrateValueToNewCache(registry, SwrveConstants().SWRVE_RESOURCES_LOCATION + currentUserID + SwrveConstants().SWRVE_USER_RESOURCES_FILENAME, currentUserID + "resources")

    ' migrate single user data to per user registry section
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "install_date", SwrveConstants().SWRVE_JOINED_DATE_KEY)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "last_session_date", SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "start_session_date", SwrveConstants().SWRVE_START_SESSION_DATE_KEY)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "qa", SwrveConstants().SWRVE_USER_QA_FILENAME)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "etag", SwrveConstants().SWRVE_ETAG_FILENAME)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "resources_signature", SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "campaigns_signature", SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "swrve_seqnum", SwrveConstants().SWRVE_SEQNUM)
    MigrateValueToNewSection(registry, currentUserID, currentUserID + "campaigns_lastmessagetime", SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME)
            
    ' Migrate all other users
    for EACH key in otherUserIDs
        if key <> currentUserID
            ' migrate campaigns and resources from registry to cachefs
            MigrateValueToNewCache(registry, SwrveConstants().SWRVE_CAMPAIGNS_LOCATION + key + SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME, key + "campaigns")
            MigrateValueToNewCache(registry, SwrveConstants().SWRVE_RESOURCES_LOCATION + key + SwrveConstants().SWRVE_USER_RESOURCES_FILENAME, key + "resources")

            ' migrate single user data to per user registry section
            MigrateValueToNewSection(registry, key, key + "install_date", SwrveConstants().SWRVE_JOINED_DATE_KEY)
            MigrateValueToNewSection(registry, key, key + "last_session_date", SwrveConstants().SWRVE_LAST_SESSION_DATE_KEY)
            MigrateValueToNewSection(registry, key, key + "start_session_date", SwrveConstants().SWRVE_START_SESSION_DATE_KEY)
            MigrateValueToNewSection(registry, key, key + "qa", SwrveConstants().SWRVE_USER_QA_FILENAME)
            MigrateValueToNewSection(registry, key, key + "etag", SwrveConstants().SWRVE_ETAG_FILENAME)
            MigrateValueToNewSection(registry, key, key + "resources_signature", SwrveConstants().SWRVE_USER_RESOURCES_SIGNATURE_FILENAME)
            MigrateValueToNewSection(registry, key, key + "campaigns_signature", SwrveConstants().SWRVE_USER_CAMPAIGNS_SIGNATURE_FILENAME)
            MigrateValueToNewSection(registry, key, key + "swrve_seqnum", SwrveConstants().SWRVE_SEQNUM)
            MigrateValueToNewSection(registry, key, key + "campaigns_lastmessagetime", SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME)
            
        end if
    end for

    'special cases that have dynamic keys: campaigns_lastmessagetime and campaigns_impressions

    secList = registry.GetSectionList()
    FOR EACH oldKey IN secList
        'we need to split the old key to get the user id and campaign id eg XXXcampaigns_impressionsYYY
        middleString = "campaigns_impressions"
        position = Instr(1, oldKey, middleString)
        if position <> 0
            newKey = Right(oldKey, Len(oldKey) - position - Len(middleString) + 1)
            userID = Left(oldKey, position - 1)
            MigrateValueToNewSection(registry, userID, oldKey, SwrveConstants().SWRVE_USER_CAMPAIGNS_IMPRESSIONS + newKey)
        end if

        middleString = "campaigns_lastmessagetime"
        position = Instr(1, oldKey, middleString)
        if position <> 0
            newKey = Right(oldKey, Len(oldKey) - position - Len(middleString) + 1)
            userID = Left(oldKey, position - 1)
            MigrateValueToNewSection(registry, userID, oldKey, SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME + newKey)
        end if
    end for

    MigrateValueToNewSection(registry, SwrveConstants().SWRVE_SECTION_KEY, "swrveUserIDs", SwrveConstants().SWRVE_USER_IDS_KEY)

    registry.flush()
end function

function MigrateValueToNewSection(registry, section as String, oldKey as String, newKey as String)
    value = SwrveGetStringFromPersistence(oldKey)
    if value <> ""
        SwrveWriteValueToSection(section, newKey, value)
        SWLogDebug("Deleting registry section for value", oldKey)
        registry.delete(oldKey)
    end if
end function

function MigrateValueToNewCache(registry, path as String, oldKey as String)
    value = SwrveGetStringFromPersistence(oldKey)
    if value <> ""
        SwrveSaveStringToFile(value, path)
        SWLogDebug("Deleting registry section for value", oldKey)
        registry.delete(oldKey)
    end if
end function