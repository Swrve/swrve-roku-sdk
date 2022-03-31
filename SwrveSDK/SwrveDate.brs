'Helpers for dates'
function SwrveDate(date as Object) as Object
    this = { private: { value: date } }
    this.toMillisToken = sw_dateToTimeToken
    this.toTimeToken = sw_dateToTimeToken

    this.toSecondsToken = sw_dateToTimeTokenAsSeconds
    return this
end function

'Create date object from string'
function SwrveDateFromString(date as String) as Object
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(date)
    return SwrveDate(dt)
end function

'returns date to epoch in milliseconds'
function sw_dateToTimeToken() as String
    seconds = box(m.private.value.asSeconds()).toStr()
    milliseconds = box(m.private.value.getMilliseconds()).toStr()
    if Len(milliseconds) = 2
        milliseconds = "0" + milliseconds
    else if Len(milliseconds) = 1
        milliseconds = "00" + milliseconds
    end if
    return seconds + milliseconds
end function

'returns date to epoch in seconds'
function sw_dateToTimeTokenAsSeconds() as String
    seconds = box(m.private.value.asSeconds()).toStr()

    return seconds
end function
