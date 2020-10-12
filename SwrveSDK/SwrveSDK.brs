function SwrveSDK() as Object
	prototype = {}

	' Observers

	prototype.SwrveSetIdentifyExternalIDCallback = function(callback as String) as Void
		if getSwrveNode().hasField("identityCallback")
			getSwrveNode().observeField("identityCallback", callback)
		end if
	end function

	prototype.SwrveClearIdentifyExternalIDCallback = function()
		if getSwrveNode().hasField("identityCallback")
			getSwrveNode().unobserveField("identityCallback")
		end if
	end function

	prototype.SwrveSetCustomCallback = function(callback as String) as Void
		if getSwrveNode().hasField("customCallback")
			getSwrveNode().observeField("customCallback", callback)
		end if
	end function

	prototype.ClearCustomCallback = function() as Void
		if getSwrveNode().hasField("customCallback")
			getSwrveNode().unobserveField("customCallback")
		end if
	end function

	prototype.SwrveSetNewResourcesCallback = function(callback as String) as Void
		if getSwrveNode().hasField("resourcesAndCampaignsCallback")
			getSwrveNode().observeField("resourcesAndCampaignsCallback", callback)
		end if
	end function

	prototype.SwrveClearNewResourcesCallback = function() as Void
		if getSwrveNode().hasField("resourcesAndCampaignsCallback")
			getSwrveNode().unobserveField("resourcesAndCampaignsCallback")
		end if
	end function

	prototype.SwrveClearNewResourcesDiffCallback = function() as Void
		if getSwrveNode().hasField("resourcesDiffObjectReady")
			getSwrveNode().unobserveField("resourcesDiffObjectReady")
		end if
	end function

	prototype.SwrveSetCustomMessageRender = function(callback as String) as Void
		if getSwrveNode().hasField("messageWillRenderCallback") AND getSwrveNode().hasField("sdkHasCustomRenderer")
			getSwrveNode().observeField("messageWillRenderCallback", callback)
			getSwrveNode().sdkHasCustomRenderer = true
		end if
	end function

	prototype.SwrveShowIAM = function(message as Object) as Void
		if getSwrveNode().hasField("currentIAM") AND getSwrveNode().hasField("showIAM")
			getSwrveNode().currentIAM = message
			getSwrveNode().showIAM = true
		end if
	end function

	' Call functions

	prototype.SwrveIdentifyExternalID = function(external_user_id as String) as Void
		payload = { external_user_id: external_user_id }
		getSwrveNode().callFunc("SwrveOnIdentify", payload)
	end function

	prototype.SwrveEvent = function(eventName as String, payload = {} as Object) as Void
		eventPayload = { eventName: eventName, payload: payload }
		getSwrveNode().callFunc("SwrveOnEvent", eventPayload)
	end function

	prototype.SwrvePurchaseEvent = function(itemQuantity as Integer, itemName as String, itemPrice as Float, itemCurrency as String) as Void
		payload = { itemQuantity: itemQuantity, itemName: itemName, itemPrice: itemPrice, itemCurrency: itemCurrency }
		getSwrveNode().callFunc("SwrveOnPurchase", payload)
	end function

	prototype.SwrveUserUpdate = function(attributes as Object) as Void
		getSwrveNode().callFunc("SwrveOnUserUpdate", attributes)
	end function

	prototype.SwrveCurrencyGiven = function(givenCurrency as String, givenAmount as Integer) as Void
		payload = { givenCurrency: givenCurrency, givenAmount: givenAmount }
		getSwrveNode().callFunc("SwrveOnCurrencyGiven", payload)
	end function

	prototype.SwrveUserUpdateWithDate = function(name as String, date as Object) as Void
		payload = { name: name, date: date }
		getSwrveNode().callFunc("SwrveOnUserUpdateWithDate", payload)
	end function

	prototype.SwrveIAPWithoutReceipt = function(product as Object, rewards as Object, currency as String) as Void
		payload = { product: product, rewards: rewards, currency: currency }
		getSwrveNode().callFunc("SwrveOnIAPWithoutReceipt", payload)
	end function

	prototype.SwrveFlushAndClean = function() as Void
		getSwrveNode().callFunc("SwrveFlushAndClean")
	end function

	prototype.SwrveGetNewResourcesDiff = function(callback as String) as Void
		if getSwrveNode().hasField("resourcesDiffObjectReady")
			getSwrveNode().observeField("resourcesDiffObjectReady", callback)
			getSwrveNode().callFunc("SwrveOnGetResourcesDiff")
		end if
	end function

	prototype.SwrveRefreshCampaignsResources = function(callback as String) as Void
		getSwrveNode().callFunc("processUserCampaignsAndResources")
	end function

	prototype.SwrveGetCurrentUserID = function() as String
		return getSwrveNode().callFunc("GetCurrentUserIDFromConfig")
	end function

	prototype.SwrveGetResourceManager = function() as Object
		return SwrveResourceManager(getSwrveNode().userResources)
	end function

	prototype.SwrveGetUserCampaigns = function() as Object
		return getSwrveNode().userCampaigns
	end function

	prototype.SwrveGetUserQAStatus = function() as Boolean
		return getSwrveNode().isQAUser
	end function

	prototype.SwrveShutdown = function() as Void
		getSwrveNode().callFunc("SwrveShutdown")
	end function

	return prototype
end function

