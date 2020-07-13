function init()
	m.top.observeField("startSwrve", "SwrveOnStartSwrve")

	cfg = {
		appId: "<Your ID>",
		apiKey: "<Your Key>",
		logLevel: 3 'Used for debug logs, levels ranges are: off 0, error 1, warn 2, info 3, debug 4, verbose 5 or higher'
	}

	date = CreateObject("roDateTime")
	m.top.addFields({ startSeconds: date.AsSeconds(), startMilli: date.GetMilliseconds(), appStartSecondsDesc: (date.AsSeconds() + (date.GetMilliseconds() / 1000)) - 1000000000 })
	m.global.addFields({ "Swrve": m.top })

	if cfg.appId.Instr("Your ID") = -1 AND cfg.apiKey.Instr("Your Key") = -1 then
		Swrve(cfg)
	else
		m.top.observeField("configuration", "SwrveOnConfiguration")
	end if
end function

function SwrveOnConfiguration(event as Object)
	m.top.unobserveField(event.getField())
	Swrve(event.getData())
end function

function SwrveOnStartSwrve()
	if(m.top.startSwrve = true)
		SwrveStartHeartbeat()
	end if
end function
