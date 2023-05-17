function SwrveGetGlobalDisplayRules() as Object
	globalDisplayRules = m.userCampaigns.rules
	if globalDisplayRules = Invalid
		return {
			delay_first_message: SwrveConstants().SWRVE_DEFAULT_DELAY_FIRST_MESSAGE
			min_delay_between_messages: SwrveConstants().SWRVE_DEFAULT_MIN_DELAY
			max_messages_per_session: SwrveConstants().SWRVE_DEFAULT_MAX_SHOWS
		}
	else
		return globalDisplayRules
	end if
end function

function SwrveGetDisplayRulesFromCampaignWithID(id as Integer) as Object
	for each campaign in m.userCampaigns.campaigns
		if campaign.id = id
			return SwrveGetDisplayRulesFromCampaign(campaign)
		end if
	end for
end function

function SwrveGetDisplayRulesFromCampaign(campaign as Object) as Object
	return campaign.rules
end function

function SwrveLoadUserCampaignsFromPersistence() as Object
	campaignLocalSource = SwrveConstants().SWRVE_CAMPAIGNS_LOCATION + SwrveSDK().SwrveGetCurrentUserID() + SwrveConstants().SWRVE_USER_CAMPAIGNS_FILENAME
	SWLogDebug("Attempt to load campaign cache file ", campaignLocalSource)
	campaignString = SwrveGetStringFromFile(campaignLocalSource)
	if SwrveIsCampaignFileValid(campaignString) 'checks that signature is still correct'
		if campaignString = ""
			SwrveDeleteKeyFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_ETAG_FILENAME)
			return {}
		end if
		return ParseJSON(campaignString)
	else
		SwrveDeleteKeyFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_ETAG_FILENAME)
		return {}
	end if

end function

function SwrveCheckAssetsAllDownloaded(callback as String) as Boolean
	ids = SwrveBuildArrayOfAssetIDs(m.userCampaigns)
	ob = {
		ids: ids,
		assetLocation: SwrveConstants().SWRVE_ASSETS_LOCATION
	}
	_postTask = CreateObject("roSGNode", "CheckAssetsInFileSystemTask")
	_postTask.request = ob
	_postTask.ObserveField("response", callback)
	_postTask.Control = "Run"
end function

function SwrveCheckAssetsInCampaignAreReady(campaign as Object) as Boolean
	arrayOfCampaigns = []
	arrayOfCampaigns.push(campaign)
	ids = SwrveBuildArrayOfAssetIDs({ campaigns: arrayOfCampaigns })
	for each id in ids
		file = MatchFiles(SwrveConstants().SWRVE_ASSETS_LOCATION, id)
		if file.count() = 0 'Asset not found'
			return false
		end if
	end for
	return true
end function

function SwrveCheckAssetsInMessageAreReady(message as Object) as Boolean
	ids = SwrveBuildArrayOfAssetIDsFromMessage(message)
	for each id in ids
		file = MatchFiles(SwrveConstants().SWRVE_ASSETS_LOCATION, id)
		if file.count() = 0 'Asset not found'
			return false
		end if
	end for
	return true
end function

function SwrveBuildArrayOfComplyingCampaigns(event as Object) as Object
	ids = []
	if m.userCampaigns <> Invalid AND m.userCampaigns.campaigns <> Invalid AND m.userCampaigns.campaigns.count() > 0
		for each campaign in m.userCampaigns.campaigns
			if campaign.messages <> Invalid
				if SwrveEventValidForCampaign(event, campaign)
					ids.push(campaign)
				end if
			end if
		end for
	end if
	return ids
end function

function SwrveCheckEventForTriggers(event as Object)
	validCampaigns = SwrveBuildArrayOfComplyingCampaigns(event)

	if validCampaigns.count() = 0
		SWLogDebug("No campaigns matched the event named " + event.name)
	else
		SWLogInfo(validCampaigns.count(), "campaigns matched the event named:", event.name, "- Sorting them out by priority and checking display rules.")
		'check that assets have all been downloaded.'
		campaignsReady = []
		for each campaign in validCampaigns
			if SwrveCheckAssetsInCampaignAreReady(campaign)
				campaignsReady.push(campaign)
			end if
		end for

		if campaignsReady.count() > 0
			SWLogDebug("Assets are ready.")
			sortedCampaigns = SwrveSortCampaignsByPriority(campaignsReady)
			for each campaign in sortedCampaigns
				_canShowCampaign = SwrveCanShowCampaign(campaign)
				if _canShowCampaign
					_canShowCampaignAccordingToGlobalRules = SwrveCanShowCampaignAccordingToGlobalRules()
					if _canShowCampaignAccordingToGlobalRules
						'Show message'
						SwrveProcessShowIAM(campaign)
						exit for
					end if
				end if
			end for
		else
			SWLogWarn("Abort. Assets are not ready or missing.")
		end if
	end if
end function

function SwrveProcessShowIAM(campaign as Object)
	messageToShow = SwrvePriorityMessage(campaign)

	if getSwrveNode().sdkHasCustomRenderer = true
		getSwrveNode().messageWillRenderCallback = messageToShow
	else
		SwrveRenderIAM(messageToShow)
	end if

	SwrveUpdateGlobalRules()
	SwrveUpdateCampaignState(campaign)
	'SwrveReturnedMessageEvent(messageToShow)
	SwrveFlushAndClean()
end function

function SwrveShowIAM(message as Object)
	if SwrveCheckAssetsInMessageAreReady(message) = false
		SWLogWarn("Abort showing message. Assets are not ready or missing.")
	else 
		if getSwrveNode().sdkHasCustomRenderer = true
			getSwrveNode().messageWillRenderCallback = message
		else
			SwrveRenderIAM(message)
		end if
	end if
end function

function SwrveRenderIAM(message as Object)
	if getSwrveNode("SwrveRenderIAM") <> Invalid 
		SWLogInfo("Showing IAM -", message.id)
		getSwrveNode().currentIAM = message
		getSwrveNode().showIAM = true
	end if
end function

function SwrveUpdateGlobalRules()
	now = CreateObject("roDateTime")
	SwrveWriteValueToSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME, now.ToISOString())
	m.numberOfMessagesShown = m.numberOfMessagesShown + 1
end function

function SwrveUpdateCampaignState(campaign as Object)
	now = CreateObject("roDateTime")
	SwrveWriteValueToSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME + StrI(campaign.id), now.ToISOString())

	impressionsStr = SwrveGetValueFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_IMPRESSIONS + StrI(campaign.id))
	impressions = 0
	if impressionsStr <> ""
		impressions = impressionsStr.toInt()
	end if
	impressions = impressions + 1

	SwrveWriteValueToSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_IMPRESSIONS + StrI(campaign.id), StrI(impressions).trim())
end function

'Checking if we can show the message according to global display rules'
function SwrveCanShowCampaignAccordingToGlobalRules() as Boolean

	now = CreateObject("roDateTime").AsSeconds()

	globalRules = SwrveGetGlobalDisplayRules()

	delay_first_message = globalRules.delay_first_message
	min_delay_between_messages = globalRules.min_delay_between_messages
	max_messages_per_session = globalRules.max_messages_per_session

	'Take the rules and ensure there is a default if its invalid'
	if globalRules.delay_first_message = Invalid then delay_first_message = SwrveConstants().SWRVE_DEFAULT_DELAY_FIRST_MESSAGE
	if min_delay_between_messages = Invalid then min_delay_between_messages = SwrveConstants().SWRVE_DEFAULT_MIN_DELAY
	if max_messages_per_session = Invalid then max_messages_per_session = SwrveConstants().SWRVE_DEFAULT_MAX_SHOWS

	sessionStart = GetSessionStartDateAsSeconds()

	'Checking if the globl rules state that the first message needs to be delayed,
	'and if we're too early or not to show the message.
	if now - sessionStart < delay_first_message
		'Too soon'
		SWLogError("{Campaign throttle limit} Too soon after launch. Session length:", now - sessionStart, "Required first delay:", delay_first_message)
		return false
	end if

	'Checking that we don't go over the max number of impressions
	if m.numberOfMessagesShown >= max_messages_per_session
		SWLogError("{Campaign throttle limit} Campaign has been shown too many times already:", m.numberOfMessagesShown, "Max:", max_messages_per_session)
		return false
	end if
	
	lastMessageTime = SwrveGetValueFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME)
	'Checking if delay between last message shown and now is greater than allowed delay'

	if lastMessageTime = ""
		return true
	else
		date = CreateObject("roDateTime")
		date.FromISO8601String(lastMessageTime)
		lastMessageTimeAsSeconds = date.AsSeconds()

		if now - lastMessageTimeAsSeconds < min_delay_between_messages
			SWLogError("{Campaign throttle limit} Too soon after last message. Time since last message:", now - lastMessageTimeAsSeconds, "Required delay:", min_delay_between_messages)
			return false
		else
			return true
		end if
	end if
end function

'Checking if we can show the message according to the specific campaign rules'
function SwrveCanShowCampaign(campaign as Object) as Boolean
	'check campaign rules
	now = CreateObject("roDateTime").AsSeconds()

	delay_first_message = campaign.rules.delay_first_message
	min_delay_between_messages = campaign.rules.min_delay_between_messages
	max_impressions = campaign.rules.dismiss_after_views
	sessionStart = GetSessionStartDateAsSeconds()

	'Checking if the campaign wants the first message to be delayed, and if we're too early to show the message.
	if now - sessionStart < delay_first_message
		SWLogError("{Campaign throttle limit} Too soon after launch. Session length:", now - sessionStart, "Required first delay:", delay_first_message)
		SWLogVerbose("now:", now)
		SWLogVerbose("sessionStart:", sessionStart)
		SWLogVerbose("delay_first_message seconds:", delay_first_message)
		SWLogVerbose("(seconds) now - sessionStart =", now - sessionStart)
		SWLogVerbose("campaign.rules:", campaign.rules)
		return false
	end if

	'Checking that we don't go over the max number of impressions for that campaign
	impressionsStr = SwrveGetValueFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_IMPRESSIONS + StrI(campaign.id))

	'If string is nil, we've never shown it, so we're good to go
	if impressionsStr <> ""
		impressions = impressionsStr.toInt()
		if impressions >= max_impressions ' We're over the max, cant show it.
			SWLogError("{Campaign throttle limit} Campaign has been shown too many times already:", impressions, "Max:", max_impressions)
			return false
		end if
	end if

	lastMessageTime = SwrveGetValueFromSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME + StrI(campaign.id))
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
			SWLogError("{Campaign throttle limit} Too soon after last message. Time since last message:", now - lastMessageTimeAsSeconds, "Required delay:", min_delay_between_messages)
			return false
		else
			'Passed all test'
			return true
		end if
	end if
end function

function SwrveUpdateCampaignRulesData(campaign as Object)
	date = CreateObject("roDateTime")
	SwrveWriteValueToSection(SwrveSDK().SwrveGetCurrentUserID(), SwrveConstants().SWRVE_USER_CAMPAIGNS_LASTMESSAGETIME + campaign.id, date.ToISOString())
end function

function SwrveSortCampaignsByPriority(campaigns as Object) as Object
	if campaigns.Count() < 2
		return campaigns
	end if

	for i = 0 to campaigns.Count() - 2 step 1
		campaignA = SwrveCopy(campaigns[i])
		campaignB = SwrveCopy(campaigns[i + 1])

		if SwrveCampaignPriority(campaignA) > SwrveCampaignPriority(campaignB)
			campaigns[i] = SwrveCopy(campaignB)
			campaigns[i + 1] = SwrveCopy(campaignA)
			i = -1
		end if
	end for

	return campaigns
end function

function SwrveCampaignPriority(campaign as Object) as Integer
	lowest = 10000

	for each message in campaign.messages
		if message.priority < lowest
			lowest = message.priority
		end if
	end for
	return lowest
end function

function SwrvePriorityMessage(campaign as Object) as Object
	if campaign.messages.count() < 2
		return campaign.messages[0]
	end if
	for i = 0 to campaign.messages.Count() - 2 step 1
		messageA = SwrveCopy(campaign.messages[i])
		messageB = SwrveCopy(campaign.messages[i + 1])

		if messageA.priority > messageB.priority
			campaign.messages[i] = SwrveCopy(messageB)
			campaign.messages[i + 1] = SwrveCopy(messageA)
			i = -1
		end if
	end for
	return campaign.messages[0]
end function

function SwrveEventValidForCampaign(event as Object, campaign as Object) as Boolean
	if campaign.triggers <> Invalid
		for each trigger in campaign.triggers
			if SwrveEventValidForTrigger(event, trigger)
				return true 'Found a good trigger that matched!
			end if
		end for
		return false 'none of the triggers were good for that event'
	end if
	return false
end function

function SwrveEventValidForTrigger(event as Object, trigger as Object) as Boolean
	if event.name <> trigger.event_name
		return false
	else
		if trigger.conditions <> Invalid AND trigger.conditions.Keys().Count() > 0 ' Has 1 or more conditions'
			if trigger.conditions.args <> Invalid ' Has more than 1 condition'
				stopCriteria = false
				if trigger.conditions.op = SwrveConstants().SWRVE_AND 'All conditions need to be true. Return false as soon as we get a false result.'
					stopCriteria = false
				else if trigger.conditions.op = SwrveConstants().SWRVE_OR '1 condition is true and we're good to go.
					stopCriteria = true
				else 'Not sure how to interpret that, fail'
					return false
				end if
				for each condition in trigger.conditions
					isValid = SwrveEventValidForCondition(event, condition)
					if isValid = stopCriteria
						return stopCriteria
					end if
				end for
				return NOT stopCriteria 'we got to the end without finding our stop criteria, return the opposite!'
			else 'Only has one condition'
				isValid = SwrveEventValidForCondition(event, trigger.conditions)
				return isValid
			end if
		else ' Has no condition, just name based.'
			return true
		end if
	end if
end function

function SwrveEventValidForCondition(event as Object, condition as Object) as Boolean
	if condition = Invalid 'problem here, return false'
		return false
	else if condition.keys().count() = 0 'Condition is empty array, so event complies with condition...'
		return true
	else if event.payload <> Invalid 'Check the condition'
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
end function