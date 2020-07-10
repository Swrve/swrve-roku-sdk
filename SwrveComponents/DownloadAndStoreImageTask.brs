'Executed when the Transaction TaskNode is created
function init()
	m.top.functionName = "load"
end function

'Executed when the Task control status is set to "RUN"
function load() as Object
	if (m.top <> Invalid)

		request = m.top.request
		if NOT SWCheckForFile(request.assetLocation)
			CreateDirectory(request.assetLocation)
		end if

		req = CreateObject("roUrlTransfer")
		port = CreateObject("roMessagePort")
		' Set up request port. Note this will fail if called from the render thread
		req.SetPort(port)
		' Set request certificates
		req.SetCertificatesFile("common:/certs/ca-bundle.crt")
		req.InitClientCertificates()
		req.AddHeader("Content-Type", "application/json")
		req.SetURL(request.url)

		requestSuccess = req.AsyncGetToFile(request.localUrl.Trim())

		msg = Wait(30000, port)

		ob = Invalid

		if msg.GetResponseCode() = 200
			data = ""
			if msg.GetString() <> "" AND msg.GetString() <> Invalid
				data = ParseJSON(msg.GetString())
			end if
			ob = {
				Code: msg.GetResponseCode()
				Data: data
				id: request.id
			}
		else
			ob = {
				Code: msg.GetResponseCode()
				Data: msg.GetFailureReason()
				id: request.id
			}
		end if

		m.top.response = ob
		return ob
	end if
end function
