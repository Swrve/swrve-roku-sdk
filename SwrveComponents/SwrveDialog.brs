function init() as void
    m.top.observeField("focusedChild", "onFocusChanged")
    m.top.observeField("setFocus", "setInitFocus")
    m.top.observeField("iam", "OnNewMessage")

    'Will store buttons as assoc array, for future reference of actions'
    m.buttonsJSON = []
    'Will store button nodes, to set focus, and determine current selected button'
    m.buttonsNodes = []
    'As default, nothing is focused, then next will focus item 0'
    m.currentButtonIndex = -1

    m._swrveConstants = SwrveConstants()
end function

'Callback method for when a new message has to be rendered'
function OnNewMessage() as Void
    clean()
    format = m.top.iam.template.formats
    if format.count() > 0
        
        f = format[0]

        di = CreateObject("roDeviceInfo")
        screenSize = di.GetUIResolution()
        
        scaleH = f.scale*(screenSize.height) / f.size.h.value
        scaleW = f.scale*(screenSize.width) / f.size.w.value

        scale = {"h" : scaleH, "w": scaleW}
        'There will be two scales used to render things:'
        '1. Scale between real screen size and template size'
        '2. Scale in the message JSON, which will be used later in other methods'

        m.buttonsJSON = f.buttons

        renderImages(f.images, scale)
        renderButtons(f.buttons, scale)
    end if
end function

function setInitFocus() as Void
    nextButton()
end function

function onFocusChanged() as Void

end function


'Render an array of images'
function renderImages(images as object, scale as object)
    for each image in images
        imgName = image.image.value
        SwrveAddImageToNode(m.top, imgName, image.x.value, image.y.value, scale)
    end for
end function

'Render buttons and setup an observer for remote presses'
function renderButtons(buttons as object, scale as object)
    for each button in buttons
        imgName = button.image_up.value
        button = SwrveAddButtonToNode(m.top, imgName, button.x.value, button.y.value, scale)
        button.observeField("buttonSelected", "buttonSelected")
        'add it to our array for future reference'
        m.buttonsNodes.push(button)
    end for
end function

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
    'm.top.visible = "false"
end function

'Internal callback function for when a user selects a button'
function buttonSelected()
    if m.currentButtonIndex < 0
        'Pressed on background OR unknown behaviour'
        dismiss()
        return 0
    end if

    actionType = m.buttonsJSON[m.currentButtonIndex].type
    if actionType.value = m._swrveConstants.SWRVE_BUTTON_DISMISS
        SWLogInfo("User pressed on button with dismiss action: No Callback triggered")
    else if actionType.value = m._swrveConstants.SWRVE_BUTTON_CUSTOM

        action = m.buttonsJSON[m.currentButtonIndex].action.value

        SwrveSDK().SwrveClickEvent(m.top.iam, m.buttonsJSON[m.currentButtonIndex].name)

        SWLogInfo("User pressed on button with custom action:", action, "type:", type(action))
        m.global.SwrveCustomCallback = action
    end if

    dismiss()
end function

'Set the scene as a reset state.'
function clean()
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


function onKeyEvent(key as String, press as Boolean) as Boolean
    result = false
    if press then
        if key = "right" or key = "down"
            nextButton()
            result = true
        else if key = "left" or key = "up"
            previousButton()
            result = true
        end if
    end if

    return result

end function
