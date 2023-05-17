function SwrveSDK() as Object
	prototype = {}

	' Observers

	prototype.SwrveSetIdentifyExternalIDCallback = function(callback as String) as Void
		if getSwrveNode("SwrveSetIdentifyExternalIDCallback") <> Invalid AND getSwrveNode().hasField("identityCallback")
			getSwrveNode().observeField("identityCallback", callback)
		end if
	end function

	prototype.SwrveClearIdentifyExternalIDCallback = function()
		if getSwrveNode("SwrveClearIdentifyExternalIDCallback") <> Invalid AND getSwrveNode().hasField("identityCallback")
			getSwrveNode().unobserveField("identityCallback")
		end if
	end function

	prototype.SwrveSetCustomCallback = function(callback as String) as Void
		if getSwrveNode("SwrveSetCustomCallback") <> Invalid AND getSwrveNode().hasField("customCallback")
			getSwrveNode().observeField("customCallback", callback)
		end if
	end function

	prototype.ClearCustomCallback = function() as Void
		if getSwrveNode("ClearCustomCallback") <> Invalid AND getSwrveNode().hasField("customCallback")
			getSwrveNode().unobserveField("customCallback")
		end if
	end function

	prototype.SwrveSetNewResourcesCallback = function(callback as String) as Void
		if getSwrveNode("SwrveSetNewResourcesCallback") <> Invalid AND getSwrveNode().hasField("resourcesAndCampaignsCallback")
			getSwrveNode().observeField("resourcesAndCampaignsCallback", callback)
		end if
	end function

	prototype.SwrveClearNewResourcesCallback = function() as Void
		if getSwrveNode("SwrveClearNewResourcesCallback") <> Invalid AND getSwrveNode().hasField("resourcesAndCampaignsCallback")
			getSwrveNode().unobserveField("resourcesAndCampaignsCallback")
		end if
	end function

	prototype.SwrveClearNewResourcesDiffCallback = function() as Void
		if getSwrveNode("SwrveClearNewResourcesDiffCallback") <> Invalid AND getSwrveNode().hasField("resourcesDiffObjectReady")
			getSwrveNode().unobserveField("resourcesDiffObjectReady")
		end if
	end function

	prototype.SwrveSetCustomMessageRender = function(callback as String) as Void
		if getSwrveNode("SwrveSetCustomMessageRender") <> Invalid AND getSwrveNode().hasField("messageWillRenderCallback") AND getSwrveNode().hasField("sdkHasCustomRenderer")
			getSwrveNode().observeField("messageWillRenderCallback", callback)
			getSwrveNode().sdkHasCustomRenderer = true
		end if
	end function

	prototype.SwrveShowIAM = function(message as Object) as Void
		if getSwrveNode("SwrveShowIAM") <> Invalid AND getSwrveNode().hasField("currentIAM") AND getSwrveNode().hasField("showIAM")
			'Note rules are skipped.
			getSwrveNode().callFunc("SwrveShowIAM", message)
		end if
	end function

	' Call functions

	prototype.SwrveSetCustomButtonFocusCallback = function(callback as String) as Void
		if getSwrveNode("SwrveSetCustomButtonFocusCallback") <> Invalid AND getSwrveNode().hasField("customButtonFocusCallback") AND getSwrveNode().hasField("sdkHasCustomButtonFocusCallback")
			getSwrveNode().observeField("customButtonFocusCallback", callback)
			getSwrveNode().sdkHasCustomButtonFocusCallback = true
		end if
	end function

	prototype.SwrveIdentifyExternalID = function(external_user_id as String) as Void
		if getSwrveNode("SwrveIdentifyExternalID") <> Invalid
			payload = { external_user_id: external_user_id }
			getSwrveNode().callFunc("SwrveOnIdentify", payload)
		end if
	end function

	prototype.SwrveEvent = function(eventName as String, payload = {} as Object) as Void
		if getSwrveNode("SwrveEvent") <> Invalid
			eventPayload = { eventName: eventName, payload: payload }
			getSwrveNode().callFunc("SwrveOnEvent", eventPayload)
		end if
	end function

	prototype.SwrvePurchaseEvent = function(itemQuantity as Integer, itemName as String, itemPrice as Float, itemCurrency as String) as Void
		if getSwrveNode("SwrvePurchaseEvent") <> Invalid
			payload = { itemQuantity: itemQuantity, itemName: itemName, itemPrice: itemPrice, itemCurrency: itemCurrency }
			getSwrveNode().callFunc("SwrveOnPurchase", payload)
		end if
	end function

	prototype.SwrveUserUpdate = function(attributes as Object) as Void
		if getSwrveNode("SwrveUserUpdate") <> Invalid
			getSwrveNode().callFunc("SwrveOnUserUpdate", attributes)
		end if
	end function

	prototype.SwrveCurrencyGiven = function(givenCurrency as String, givenAmount as Integer) as Void
		if getSwrveNode("SwrveCurrencyGiven") <> Invalid
			payload = { givenCurrency: givenCurrency, givenAmount: givenAmount }
			getSwrveNode().callFunc("SwrveOnCurrencyGiven", payload)
		end if
	end function

	prototype.SwrveUserUpdateWithDate = function(name as String, date as Object) as Void
		if getSwrveNode("SwrveUserUpdateWithDate") <> Invalid
			payload = { name: name, date: date }
			getSwrveNode().callFunc("SwrveOnUserUpdateWithDate", payload)
		end if
	end function

	prototype.SwrveIAPWithoutReceipt = function(product as Object, rewards as Object, currency as String) as Void
		if getSwrveNode("SwrveIAPWithoutReceipt") <> Invalid
			payload = { product: product, rewards: rewards, currency: currency }
			getSwrveNode().callFunc("SwrveOnIAPWithoutReceipt", payload)
		end if
	end function

	prototype.SwrveFlushAndClean = function() as Void
		if getSwrveNode("SwrveFlushAndClean") <> Invalid
			getSwrveNode().callFunc("SwrveFlushAndClean")
		end if
	end function

	prototype.SwrveGetNewResourcesDiff = function(callback as String) as Void
		if getSwrveNode("SwrveGetNewResourcesDiff") <> Invalid AND getSwrveNode().hasField("resourcesDiffObjectReady")
			getSwrveNode().observeField("resourcesDiffObjectReady", callback)
			getSwrveNode().callFunc("SwrveOnGetResourcesDiff")
		end if
	end function

	prototype.SwrveRefreshCampaignsResources = function(callback as String) as Void
		if getSwrveNode("SwrveRefreshCampaignsResources") <> Invalid
			getSwrveNode().callFunc("ProcessUserCampaignsAndResources")
		end if
	end function

	prototype.SwrveGetCurrentUserID = function() as String
		if getSwrveNode("SwrveGetCurrentUserID") <> Invalid
			return getSwrveNode().callFunc("GetCurrentUserIDFromConfig")
		end if
		return ""
	end function

	prototype.SwrveGetResourceManager = function() as Object
		if getSwrveNode("SwrveGetResourceManager") <> Invalid
			return SwrveResourceManager(getSwrveNode().userResources)
		end if
		return {}
	end function

	prototype.SwrveGetUserCampaigns = function() as Object
		if getSwrveNode("SwrveGetUserCampaigns") <> Invalid
			return getSwrveNode().userCampaigns
		end if
		return {}
	end function

	prototype.SwrveGetUserQAStatus = function() as Boolean
		if getSwrveNode("SwrveGetUserQAStatus") <> Invalid
			return getSwrveNode().isQAUser
		end if
		return false
	end function

	prototype.SwrveShutdown = function() as Void
		if getSwrveNode("SwrveShutdown") <> Invalid
			getSwrveNode().callFunc("SwrveShutdown")
		end if
	end function

	return prototype
end function

