function SwrveSDK() as Object
	prototype = {}
	prototype.global = GetGlobalAA().global

	prototype.SwrveSetIdentifyExternalIDCallback = function(callback as String) as Void
		if getSwrveNode().hasField("globalIdentifyExternalIDCallback")
			getSwrveNode().observeField("globalIdentifyExternalIDCallback", callback)
		end if
	end function

	prototype.SwrveIdentifyExternalID = function(external_user_id as String) as Void
		if getSwrveNode().hasField("globalIdentifyExternalID")
			getSwrveNode().globalIdentifyExternalID = external_user_id
		end if
	end function

	prototype.SwrveClearIdentifyExternalIDCallback = function()
		if getSwrveNode().hasField("globalIdentifyExternalIDCallback")
			getSwrveNode().unobserveField("globalIdentifyExternalIDCallback")
		end if
	end function

	prototype.SwrveEvent = function(eventName as String, payload = {} as Object) as Void
		if getSwrveNode().hasField("event")
			getSwrveNode().event = { eventName: eventName, payload: payload }
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

	prototype.SwrveClickEvent = function(message as Object, buttonName as String) as Void
		if getSwrveNode().hasField("clickEvent")
			getSwrveNode().clickEvent = { message: message, buttonname: buttonName }
		end if
	end function

	prototype.SwrvePurchaseEvent = function(itemQuantity as Integer, itemName as String, itemPrice as Float, itemCurrency as String) as Void
		if getSwrveNode().hasField("purchaseEvent")
			getSwrveNode().purchaseEvent = { itemQuantity: itemQuantity, itemName: itemName, itemPrice: itemPrice, itemCurrency: itemCurrency }
		end if
	end function

	prototype.SwrveUserUpdate = function(attributes as Object) as Void
		if getSwrveNode().hasField("userUpdate")
			getSwrveNode().userUpdate = attributes
		end if
	end function

	prototype.SwrveImpressionEvent = function(message as Object) as Void
		if getSwrveNode().hasField("impressionEvent")
			getSwrveNode().impressionEvent = message
		end if
	end function

	prototype.SwrveSetNewResourcesCallback = function(callback as String) as Void
		if getSwrveNode().hasField("resourcesAndCampaigns")
			getSwrveNode().observeField("resourcesAndCampaigns", callback)
		end if
	end function

	prototype.SwrveClearNewResourcesCallback = function() as Void
		if getSwrveNode().hasField("resourcesAndCampaigns")
			getSwrveNode().unobserveField("resourcesAndCampaigns")
		end if
	end function

	prototype.SwrveGetNewResourcesDiff = function(callback as String) as Void
		if getSwrveNode().hasField("resourcesDiffObjectReady")
			getSwrveNode().observeField("resourcesDiffObjectReady", callback)
		end if
		if getSwrveNode().hasField("getNewResourcesDiff")
			getSwrveNode().getNewResourcesDiff = true
		end if
	end function

	prototype.SwrveClearNewResourcesDiffCallback = function() as Void
		if getSwrveNode().hasField("resourcesDiffObjectReady")
			getSwrveNode().unobserveField("resourcesDiffObjectReady")
		end if
	end function

	prototype.SwrveCurrencyGiven = function(givenCurrency as String, givenAmount as Integer) as Void
		if getSwrveNode().hasField("globalCurrencyGiven")
			getSwrveNode().globalCurrencyGiven = { givenCurrency: givenCurrency, givenAmount: givenAmount }
		end if
	end function

	prototype.SwrveUserUpdateWithDate = function(name as String, date as Object) as Void
		if getSwrveNode().hasField("globalUserUpdateWithDate")
			getSwrveNode().globalUserUpdateWithDate = { name: name, date: date }
		end if
	end function

	prototype.SwrveIAPWithoutReceipt = function(product as Object, rewards as Object, currency as String) as Void
		if getSwrveNode().hasField("globalIAPWithoutReceipt")
			getSwrveNode().globalIAPWithoutReceipt = { product: product, rewards: rewards, currency: currency }
		end if
	end function

	prototype.SwrveFlushAndClean = function(product as Object, rewards as Object, currency as String) as Void
		if getSwrveNode().hasField("globalFlushAndClean")
			getSwrveNode().globalFlushAndClean = true
		end if
	end function

	prototype.SwrveGetCurrentUserID = function() as String
		return SwrveGetStringFromPersistence("userID", "")
	end function

	prototype.SwrveSetCustomMessageRender = function(callback as String) as Void
		if getSwrveNode().hasField("messageWillRender") AND getSwrveNode().hasField("sdkHasCustomRenderer")
			getSwrveNode().observeField("messageWillRender", callback)
			getSwrveNode().sdkHasCustomRenderer = true
		end if
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
		if getSwrveNode().hasField("shutdown")
			getSwrveNode().shutdown = true
		end if
	end function

	prototype.SwrveShowIAM = function(message as Object) as Void
		if getSwrveNode().hasField("currentIAM") AND getSwrveNode().hasField("showIAM")
			getSwrveNode().currentIAM = message
			getSwrveNode().showIAM = true
		end if
	end function

	return prototype
end function
