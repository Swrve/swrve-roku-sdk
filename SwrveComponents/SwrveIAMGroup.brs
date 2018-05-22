function init()
    'Will store buttons as assoc array, for future reference of actions'
    m.buttonsJSON = []
    'Will store button nodes, to set focus, and determine current selected button'
    m.buttonsNodes = []
    'As default, nothing is focused, then next will focus item 0'
    m.currentButtonIndex = -1
End Function

'Set the scene as a reset state.'
Function clean()
    m.currentButtonIndex = -1
    m.buttonsJSON.clear()
    m.buttonsNodes.clear()

    'Remove every image and button in the scene, except the background'
    for each child in m.top.getChildren(m.top.getChildCount(), 0)
        if child.id <> "background"
            m.top.removeChild(child)
        end if
    end for 
end Function

'Callback method for when a new message has to be rendered'
function OnNewMessage()

    clean()
    format = m.top.message.template.formats
    if format.count() > 0
        
        f = format[0]

        di = CreateObject("roDeviceInfo")
        screenSize = di.GetDisplaySize()
        
        scaleH = f.scale*(screenSize.h) / f.size.h.value
        scaleW = f.scale*(screenSize.w) / f.size.w.value

        scale = {"h" : scaleH, "w": scaleW}
        'There will be two scales used to render things:'
        '1. Scale between real screen size and template size'
        '2. Scale in the message JSON, which will be used later in other methods'

        m.buttonsJSON = f.buttons

        renderImages(f.images, scale)
        renderButtons(f.buttons, scale)
        swrveClient = GetSwrveClientInstance()

        swrveClient.SwrveImpressionEvent(swrveClient, m.top.message)

    end if
End Function

'Render an array of images'
Function renderImages(images as object, scale as object)
    for each image in images
        imgName = image.image.value
        SwrveAddImageToNode(m.top, imgName, image.x.value, image.y.value, scale)
    end for
End Function

'Render buttons and setup an observer for remote presses'
Function renderButtons(buttons as object, scale as object)
    for each button in buttons
        imgName = button.image_up.value
        button = SwrveAddButtonToNode(m.top, imgName, button.x.value, button.y.value, scale)
        button.observeField("buttonSelected", "buttonSelected")
        'add it to our array for future reference'
        m.buttonsNodes.push(button)
    end for
End Function

'Next behaviour (right or down arrow)'
function nextButton()
    if m.currentButtonIndex < m.buttonsNodes.count() -1
        m.currentButtonIndex = m.currentButtonIndex + 1
    end if
    if m.buttonsNodes.count() > m.currentButtonIndex
        m.buttonsNodes[m.currentButtonIndex].setFocus(true)
    end if
end Function

'Previous behaviour (left or up arrow)'
function previousButton()
    if m.currentButtonIndex > 0
        m.currentButtonIndex = m.currentButtonIndex - 1
    else
        m.currentButtonIndex = 0
    end if

    if m.buttonsNodes.count() > m.currentButtonIndex
        m.buttonsNodes[m.currentButtonIndex].setFocus(true)
    end if
end function

'Dismiss behaviour (press on back, or on a button with dismiss action)'
function dismiss()
    m.global.swrveShowIAM = false
    m.top.visible = "false"
end function

'Internal callback function for when a user selects a button'
function buttonSelected()
    if m.currentButtonIndex < 0
        'Pressed on background OR unknown behaviour'
        dismiss()
        return 0
    end if
    actionType = m.buttonsJSON[m.currentButtonIndex].type
    if actionType.value = SwrveConstants().SWRVE_BUTTON_DISMISS
        SWLog("User pressed on button with dismiss action: ")
        dismiss()
    else if actionType.value = SwrveConstants().SWRVE_BUTTON_CUSTOM

        action = m.buttonsJSON[m.currentButtonIndex].action.value

        swrveClient = GetSwrveClientInstance()
        swrveClient.SwrveClickEvent(swrveClient, m.top.message, m.buttonsJSON[m.currentButtonIndex].name)
        SWLog("User pressed on button with custom action: " + action)
        m.top.customActionCallback = action
        dismiss()
    end if
end function


function onKeyEvent(key as String, press as Boolean) as Boolean
    result = false
    if press then
        SWLog("SwrveIAMGroup Key Handler")
        if key = "back"
        	dismiss()
        end if
        if key = "OK" 'Will not happen on buttons, as the callback will take care of events. Might happen on images'
            buttonSelected()
        end if
        if key = "right" or key = "down"
            nextButton()
        else if key = "left" or key = "up"
            previousButton()
        end if
    end if
    return true
End Function