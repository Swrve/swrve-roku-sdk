'Executed when the Transaction TaskNode is created
function init()
  m.top.functionName = "execute"
end function

'Executed when the Task control status is set to "RUN"
function execute()
  if (m.top <> Invalid)

    request = m.top.request

    allFilesExist = true
    for each id in request.ids
      localUrl = request.assetLocation + id
      filesystem = CreateObject("roFilesystem")
      fileExists = filesystem.Exists(localUrl)
      if not fileExists
        allFilesExist = false
      end if

      if(NOT allFilesExist) exit for
    end for

    m.top.response = {allFilesExist:allFilesExist}
    return {allFilesExist:allFilesExist}

  end if
end function
