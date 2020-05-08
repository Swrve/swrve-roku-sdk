function init()
    m.top.observeField("startSwrve", "onStartSwrve")

    cfg = {
        appId: "<Your ID>", 
        apikey: "<Your Key>", 
        debug: true 'Used for debug logs'
    }

    Swrve(cfg)
end function

function onStartSwrve()
	if(m.top.startSwrve = true)
	    SwrveStartHeartbeat()
	end if
end function