function SwrveSDK() as Object
	prototype = {}
	prototype.global = GetGlobalAA().global

	prototype.SwrveSetIdentifyExternalIDCallback = function(callback as String) as Void
		if m.global.hasField("SwrveGlobalIdentifyExternalIDCallback")
			m.global.observeField("SwrveGlobalIdentifyExternalIDCallback", callback)
		end if 
	end function

	prototype.SwrveIdentifyExternalID = function(external_user_id as String) as Void
		if m.global.hasField("SwrveGlobalIdentifyExternalID")
			m.global.SwrveGlobalIdentifyExternalID = external_user_id
		end if
	end function

	prototype.SwrveClearIdentifyExternalIDCallback = function ()
		if m.global.hasField("SwrveGlobalIdentifyExternalIDCallback")
			m.global.unobserveField("SwrveGlobalIdentifyExternalIDCallback")
		end if
	end function
	
	prototype.SwrveEvent = function (eventName as String, payload = {} as Object) as Void
		if m.global.hasField("SwrveEvent")
			m.global.SwrveEvent = {eventName:eventName, payload:payload}
		end if
	end function

	prototype.SwrveSetCustomCallback = function (callback as String) as Void
		if m.global.hasField("SwrveCustomCallback")
			m.global.observeField("SwrveCustomCallback", callback)
		end if
	end function

	prototype.ClearCustomCallback = function() as Void
		if m.global.hasField("SwrveCustomCallback")
			m.global.unobserveField("SwrveCustomCallback")
		end if
	end function

	prototype.SwrveClickEvent = function(message as Object, buttonName as String) as Void
		if m.global.hasField("SwrveClickEvent")
			m.global.SwrveClickEvent = {message:message, buttonname:buttonName}
		end if
	end function

	prototype.SwrvePurchaseEvent = function(itemQuantity as Integer, itemName as String, itemPrice as Float, itemCurrency as String) as Void
		if m.global.hasField("SwrvePurchaseEvent")
			m.global.SwrvePurchaseEvent = {itemQuantity:itemQuantity, itemName:itemName, itemPrice:itemPrice, itemCurrency:itemCurrency}
		end if
	end function

	prototype.SwrveUserUpdate = function(attributes as Object) as Void
		if m.global.hasField("SwrveUserUpdate")
			m.global.SwrveUserUpdate = attributes
		end if
	end function

	prototype.SwrveImpressionEvent = function (message as Object) as Void
		if m.global.hasField("SwrveImpressionEvent")
			m.global.SwrveImpressionEvent = message
		end if
	end function

	prototype.SwrveSetNewResourcesCallback = function (callback as String) as Void
		if m.global.hasField("swrveResourcesAndCampaigns")
			m.global.observeField("swrveResourcesAndCampaigns", callback)
		end if
	end function

	prototype.SwrveClearNewResourcesCallback = function () as Void
		if m.global.hasField("swrveResourcesAndCampaigns")
			m.global.unobserveField("swrveResourcesAndCampaigns")
		end if
	end function

	prototype.SwrveGetNewResourcesDiff = function(callback as String) as Void
		if m.global.hasField("SwrveResourcesDiffObjectReady")
			m.global.observeField("SwrveResourcesDiffObjectReady", callback)
		end if
		if m.global.hasField("SwrveGetNewResourcesDiff")
			m.global.SwrveGetNewResourcesDiff = true
		end if
	end function

	prototype.SwrveClearNewResourcesDiffCallback = function() as Void
		if m.global.hasField("SwrveResourcesDiffObjectReady")
			m.global.unobserveField("SwrveResourcesDiffObjectReady")
		end if
	end function

	prototype.SwrveCurrencyGiven = function(givenCurrency as String, givenAmount as Integer) as Void
		if m.global.hasField("SwrveGlobalCurrencyGiven")
			m.global.SwrveGlobalCurrencyGiven = {givenCurrency:givenCurrency, givenAmount:givenAmount}
		end if
	end function

	prototype.SwrveUserUpdateWithDate = function(name as String, date as Object) as Void
		if m.global.hasField("SwrveGlobalUserUpdateWithDate")
			m.global.SwrveGlobalUserUpdateWithDate = {name:name, date:date}
		end if
	end function

	prototype.SwrveIAPWithoutReceipt = function(product as Object, rewards as Object, currency as String) as Void
		if m.global.hasField("SwrveGlobalIAPWithoutReceipt")
			m.global.SwrveGlobalIAPWithoutReceipt = {product:product, rewards:rewards, currency:currency}
		end if
	end function

	prototype.SwrveFlushAndClean = function(product as Object, rewards as Object, currency as String) as Void
		if m.global.hasField("SwrveGlobalFlushAndClean")
			m.global.SwrveGlobalFlushAndClean = true
		end if
	end function

	prototype.SwrveGetCurrentUserID = function() as String
		return SwrveGetStringFromPersistence("userID", "")
	end function

	prototype.SwrveSetCustomMessageRender = function(callback as String) as Void
		if m.global.hasField("messageWillRender") AND m.global.hasField("swrveSDKHasCustomRenderer")
	    	m.global.observeField("messageWillRender", callback)
	    	m.global.swrveSDKHasCustomRenderer = true
	    end if
	end function

	prototype.SwrveGetResourceManager = function() as Object
		return SwrveResourceManager(m.global.userResources)
	end function

	prototype.SwrveGetUserCampaigns = function() as Object
		return m.global.userCampaigns
	end function

	prototype.SwrveGetUserQAStatus = function() as Boolean
		return m.global.SwrveIsQAUser
	end function

	prototype.SwrveShutdown = function () as Void
		if m.global.hasField("SwrveShutdown")
			m.global.SwrveShutdown = true
		end if
	end function

	prototype.SwrveShowIAM = function (message as Object) as Void
		if m.global.hasField("swrveCurrentIAM") AND m.global.hasField("swrveShowIAM")
			m.global.swrveCurrentIAM = message
    		m.global.swrveShowIAM = true
    	end if
	end function

	return prototype
end function
