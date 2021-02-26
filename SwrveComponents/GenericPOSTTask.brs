'Executed when the Transaction TaskNode is created
function init()
  m.top.functionName = "load"
end function

'Executed when the Task control status is set to "RUN"
function load()
  if (m.top <> Invalid)

    request = m.top.request

    req = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    ' Set up request port. Note this will fail if called from the render thread
    req.SetPort(port)
    ' Set request certificates
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    req.AddHeader("Content-Type", "application/json")
    req.SetURL(request.url)

    requestSuccess = req.AsyncPostFromString(request.data)

    msg = port.WaitMessage (30000)

    ob = Invalid

    if (type(msg) = "roUrlEvent")
      if msg.GetResponseCode() = 200
        data = ""
        if msg.GetString() <> "" AND msg.GetString() <> Invalid
          data = ParseJSON(msg.GetString())
        end if
        ob = {
          Code: msg.GetResponseCode()
          Data: data
          RequestStr: request.data
        }
      else
        ob = {
          Code: msg.GetResponseCode()
          Data: msg.GetFailureReason()
          RequestStr: request.data
        }
      end if
    else if (msg = invalid)
      SWLogError("AsyncPostFromString failed: ", request.url)
      req.asynccancel()
    end if

    m.top.response = ob
    return ob
  end if
end function