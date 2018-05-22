Function GetGlobalDisplayRules(swrveClient as Object) as Object
	return swrveClient.userCampaigns.rules
End Function

Function GetDisplayRulesFromCampaignWithID(swrveClient as Object, id as Integer) as Object
	for each campaign in swrveClient.userCampaigns.campaigns
		if campaign.id = id
			return GetDisplayRulesFromCampaign(swrveClient, campaign)
		end if
	end for
End Function

Function GetDisplayRulesFromCampaign(swrveClient as Object, campaign as Object) as Object
	return campaign.rules
End Function

Function LoadUserCampaignsFromPersistence() as Object
	campaignLocalSource = SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME
	if SwrveIsCampaignFileValid() 'checks that signature is still correct'
		campaignString = SwrveGetStringFromPersistence(campaignLocalSource)
		if campaignString = ""
			return {}
		end if
		return ParseJSON(campaignString)
	else
		return {}
	end if

End Function

Function CheckAssetsAllDownloaded(swrveClient as Object) as Boolean
	ids = BuildArrayOfAssetIDs(swrveClient, swrveClient.userCampaigns)
	for each id in ids
		localUrl = SwrveConstants().SWRVE_ASSETS_LOCATION + id
		filesystem = CreateObject("roFilesystem")
		if not filesystem.Exists(localUrl)
			return false
	    end if
	end for
	return true
End Function

Function CheckAssetsInCampaignsAreReady(campaigns as Object) as Boolean
	ids = BuildArrayOfAssetIDs(swrveClient, {campaigns:campaigns})
	for each id in ids
		localUrl = SwrveConstants().SWRVE_ASSETS_LOCATION + id
		filesystem = CreateObject("roFilesystem")
		if not filesystem.Exists(localUrl)
			return false
	    end if
	end for
	return true
End Function

Function CheckAssetsInCampaignAreReady(campaign as Object) as Boolean
	arrayOfCampaigns = []
	arrayOfCampaigns.push(campaign)
	ids = BuildArrayOfAssetIDs(swrveClient, {campaigns:arrayOfCampaigns})
	for each id in ids
		localUrl = SwrveConstants().SWRVE_ASSETS_LOCATION + id
		file = MatchFiles(SwrveConstants().SWRVE_ASSETS_LOCATION, id)
		if file.count() = 0 'Asset not found'
			return false
		end if
	end for
	return true
End Function



Function BuildArrayOfComplyingCampaigns(swrveClient as Object, event as object) as object
	ids = []
	if swrveClient.userCampaigns.campaigns <> invalid and swrveClient.userCampaigns.campaigns.count() > 0
		for each campaign in swrveClient.userCampaigns.campaigns
			if EventValidForCampaign(event, campaign)
				ids.push(campaign)
			end if
		end for
	end if
	return ids
End function


Function CheckEventForTriggers(swrveClient as Object, event as object)
	validCampaigns = BuildArrayOfComplyingCampaigns(swrveClient, event)

	if validCampaigns.count() = 0
		SWLog("No campaigns matched the event named "+ event.name)
	else
		SWLog(StrI(validCampaigns.count()) + " campaigns matched the event named " + event.name + ". Sorting them out by priority and checking display rules.")
		'check that assets have all been downloaded.'
		campaignsReady = []
		for each campaign in validCampaigns
			if CheckAssetsInCampaignAreReady(campaign)
				campaignsReady.push(campaign)
			end if
		end for

		if campaignsReady.count() > 0
			SWLog("Assets are ready.")

			sortedCampaigns = SortCampaignsByPriority(campaignsReady)

			for each campaign in sortedCampaigns
				if CanShowCampaign(campaign)
					if CanShowCampaignAccordingToGlobalRules(campaign)
						'Show message'
						print "Campaign rules and Global display rules were OK. Show IAM"
						processShowIAM(swrveClient, campaign)
						EXIT FOR
					end if
				end if
			end for

		else
			SWLog("Abort. Assets are not ready or missing.")
		end if
		'trigger & update local display rules'

	end if
End Function

Function processShowIAM(swrveClient as Object, campaign as Object)

	updateGlobalRules(swrveClient)
	updateCampaignState(campaign)
	messageToShow = priorityMessage(campaign)
	swrveClient = GetSwrveClientInstance()
        
    swrveClient.SwrveReturnedMessageEvent(swrveClient, messageToShow)

	swrveClient.SwrveForceFlush()
	RenderIAM(messageToShow)
End Function

Function RenderIAM(message as Object)
	SWLog("Showing IAM - " + StrI(message.id)) 
	m.global.swrveCurrentIAM = message
	m.global.swrveShowIAM = true
End Function

Function updateGlobalRules(swrveClient as Object)

	now = CreateObject("roDateTime")
	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME, now.ToISOString())
	swrveClient.numberOfMessagesShown = swrveClient.numberOfMessagesShown + 1
	SynchroniseSwrveInstance(swrveClient)

end function

Function updateCampaignState(campaign as Object)
	now = CreateObject("roDateTime")
	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME + StrI(campaign.id), now.ToISOString())

	impressionsStr = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_IMPRESSIONS + StrI(campaign.id), "")	
	impressions = 0
	if impressionsStr <> ""
		impressions = impressionsStr.toInt()
	end if
	impressions = impressions + 1

	SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_IMPRESSIONS + StrI(campaign.id), StrI(impressions).trim())
End Function


'Checking if we can show the message according to global display rules'
Function CanShowCampaignAccordingToGlobalRules(campaign as Object) as Boolean

	swrveClient = GetSwrveClientInstance()
	now = CreateObject("roDateTime").AsSeconds()

	globalRules = GetGlobalDisplayRules(swrveClient)

	delay_first_message = globalRules.delay_first_message
	min_delay_between_messages = globalRules.min_delay_between_messages
	max_messages_per_session = globalRules.max_messages_per_session

	sessionStart = swrveClient.GetSessionStartDateAsSeconds()

	
	'Checking if the globl rules state that the first message needs to be delayed, 
	'and if we're too early or not to show the message.
	if now - sessionStart < delay_first_message
		'Too soon'
		SWLog("{Campaign throttle limit} Too soon after launch.")
		return false
	end if

	
	'Checking that we don't go over the max number of impressions
	if swrveClient.numberOfMessagesShown >= max_messages_per_session
		SWLog("{Campaign throttle limit} Campaign has been shown too many times already")
		return false
	end if


    lastMessageTime = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME, "")
    'Checking if delay between last message shown and now is greater than allowed delay'

	if lastMessageTime = ""
		return true
	else
		date = CreateObject("roDateTime")
        date.FromISO8601String(lastMessageTime)
        lastMessageTimeAsSeconds = date.AsSeconds()

        if now - lastMessageTimeAsSeconds < min_delay_between_messages
       		SWLog("{Campaign throttle limit} Too soon after last message.")
        	return false
        else
        	return true
        end if
	end if
	
End Function


'Checking if we can show the message according to the specific campaign rules'
Function CanShowCampaign(campaign as Object) as Boolean
	'check campaign rules
	swrveClient = GetSwrveClientInstance()
	now = CreateObject("roDateTime").AsSeconds()

	delay_first_message = campaign.rules.delay_first_message
	min_delay_between_messages = campaign.rules.min_delay_between_messages
	max_impressions = campaign.rules.dismiss_after_views
	sessionStart = swrveClient.GetSessionStartDateAsSeconds()

	'Checking if the campaign wants the first message to be delayed, and if we're too early to show the message.
	if now - sessionStart < delay_first_message			
		SWLog("{Campaign throttle limit} Too soon after launch.")
		return false
	end if

	'Checking that we don't go over the max number of impressions for that campaign
	impressionsStr = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_IMPRESSIONS + StrI(campaign.id), "")	
	
	'If string is nil, we've never shown it, so we're good to go
	if impressionsStr <> ""
		impressions = impressionsStr.toInt()
		if impressions >= max_impressions ' We're over the max, cant show it.
			SWLog("{Campaign throttle limit} Campaign has been shown too many times already")
			return false
		end if
	end if

    lastMessageTime = SwrveGetStringFromPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME + StrI(campaign.id), "")
    'Last check of rules'
    'If string is nil, then we've never shown a message from this campaign
	if lastMessageTime = ""
		return true
	else
		date = CreateObject("roDateTime")
        date.FromISO8601String(lastMessageTime)
        lastMessageTimeAsSeconds = date.AsSeconds()
        'Checking if delay between last message shown and now is greater than allowed delay'
        if now - lastMessageTimeAsSeconds < min_delay_between_messages
        	'Too soon, return false
        	SWLog("{Campaign throttle limit} Too soon after last message.")
        	return false
        else
        	'Passed all test'
        	return true
        end if
	end if
End Function


Function UpdateCampaignRulesData(campaign as Object)
	swrveClient = GetSwrveClientInstance()
	date = CreateObject("roDateTime")
    SwrveSaveStringToPersistence(SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME + campaign.id, date.ToISOString())
End Function

Function SortCampaignsByPriority(campaigns as Object) as object
	if campaigns.Count() < 2
		return campaigns
	end if

	for i = 0 to campaigns.Count()-2 step 1
		campaignA = SWCopy(campaigns[i])
		campaignB = SWCopy(campaigns[i+1])

		if campaignPriority(campaignA) > campaignPriority(campaignB)
			campaigns[i] = SWCopy(campaignB)
			campaigns[i+1] = SWCopy(campaignA)
			i = -1
		end if
	end for

	return campaigns
End Function

Function campaignPriority(campaign as Object) as Integer
	lowest = 10000

	for each message in campaign.messages
		if message.priority < lowest
			lowest = message.priority
		end if
	end for
	return lowest
End Function

Function priorityMessage(campaign as Object) as object
	if campaign.messages.count() < 2
		return campaign.messages[0]
	end if
	for i = 0 to campaign.messages.Count()-2 step 1
		messageA = SWCopy(campaign.messages[i])
		messageB = SWCopy(campaign.messages[i+1])

		if messageA.priority > messageB.priority
			campaign.messages[i] = SWCopy(messageB)
			campaign.messages[i+1] = SWCopy(messageA)
			i = -1
		end if
	end for
	return campaign.messages[0]
end Function

Function EventValidForCampaign(event as object, campaign as object) as Boolean
	if campaign.triggers <> invalid
		for each trigger in campaign.triggers 
			if EventValidForTrigger(event, trigger)
				return true 'Found a good trigger that matched!
			end if
		end for
		return false 'none of the triggers were good for that event'
	end if
	return false
End Function


Function EventValidForTrigger(event as Object, trigger as Object) as Boolean
	if event.name <> trigger.event_name
		return false
	else
		if trigger.conditions <> invalid and trigger.conditions.Keys().Count() > 0 ' Has 1 or more conditions'
			if trigger.conditions.args <> invalid ' Has more than 1 condition'
				stopCriteria = false
				if trigger.conditions.op = SwrveConstants().SWRVE_AND 'All conditions need to be true. Return false as soon as we get a false result.'
					stopCriteria = false
				else if trigger.conditions.op = SwrveConstants().SWRVE_OR '1 condition is true and we're good to go.
					stopCriteria = true
				else 'Not sure how to interpret that, fail'
					return false
				end if
				for each condition in trigger.conditions 
					isValid = EventValidForCondition(event, condition)
					if isValid = stopCriteria 
						return stopCriteria
					end if
				end for
				return not stopCriteria 'we got to the end without finding our stop criteria, return the opposite!'
			else 'Only has one condition'
				isValid = EventValidForCondition(event, trigger.conditions)
				return isValid
			end if
		else ' Has no condition, just name based.'
			return true
		end if
	end if
End Function

Function EventValidForCondition(event as Object, condition as Object) as Boolean
	if condition = invalid 'problem here, return false'
		return false
	else if condition.keys().count() = 0 'Condition is empty array, so event complies with condition...'
		return true
	else if event.payload <> invalid 'Check the condition'
		if condition.op = SwrveConstants().SWRVE_EQUAL
			if event.payload[condition.key] = condition.value
				return true
			else
				return false
			end if
		else if condition.op = SwrveConstants().SWRVE_NOT_EQUAL
			if event.payload[condition.key] <> condition.value
				return true
			else
				return false
			end if
		end if
	end if
End Function

Function CampaignStateForCampaignID(id as integer) as Object
	location = CampaignStateFilenameForCampaign(id)
	campaignState = SwrveGetObjectFromFile(location)
End Function

Function CampaignStateFilenameForCampaign(campaignID as String) as String
	return SwrveConstants().SWRVE_CAMPAIGN_STATE_PREFIX + campaignID
End Function
