function init()
    m.top.observeField("startSwrve", "onStartSwrve")

    cfg = {
        appId: "<Your ID>", 
        apikey: "<Your Key>", 
        logLevel: 3 'Used for debug logs, levels ranges are: off 0, error 1, warn 2, info 3, debug 4, verbose 5 or higher'
    }

    m.global.addFields({"Swrve": m.top })
    if cfg.appId.Instr("Your ID") = -1 AND cfg.apiKey.Instr("Your Key") = -1 then
        Swrve(cfg)
    else
        m.top.observeField("configuration", "onConfiguration")
    end if
end function

function onConfiguration(event as Object)
    m.top.unobserveField(event.getField())
    Swrve(event.getData())
end function

function onStartSwrve()
    if(m.top.startSwrve = true)
        SwrveStartHeartbeat()
    end if
end function