Keyboard2 = class()
Keyboard2.layout = nil
Keyboard2.gui = nil
Keyboard2.scriptedShape = nil
Keyboard2.buffer = nil
Keyboard2.shift = nil

local function generateCallbacks(scriptedShape, instance)
    scriptedShape.gui_keyboardButtonCallback = function (shape, buttonName)
        instance:onButtonClick(buttonName)
    end

    scriptedShape.gui_keyboardConfirm = function (shape, buttonName)
        instance:confirm()
    end

    scriptedShape.gui_keyboardCancel = function (shape, buttonName)
        instance:cancel()
    end

    scriptedShape.gui_keyboardBackspace = function (shape, buttonName)
        instance:backspace()
    end

    scriptedShape.gui_keyboardShift = function (shape, buttonName)
        instance:shiftKeys()
    end

    scriptedShape.gui_keyboardSpacebar = function (shape, buttonName)
        instance:spacebar()
    end

    scriptedShape.gui_keyboardCloseCallback = function (shape)
        instance:close()
    end
end

local function setCallbacks(instance)
    for i = 1, #instance.layout.keys, 1 do
        instance.gui:setText(tostring(i), instance.layout.keys[i][1])
        instance.gui:setButtonCallback(tostring(i), "gui_keyboardButtonCallback")
    end

	instance.gui:setVisible("blur", true)
    instance.gui:setButtonCallback("Confirm", "gui_keyboardConfirm")
    instance.gui:setButtonCallback("Cancel", "gui_keyboardCancel")
    instance.gui:setButtonCallback("Backspace", "gui_keyboardBackspace")
    instance.gui:setButtonCallback("Shift", "gui_keyboardShift")
    instance.gui:setButtonCallback("Space", "gui_keyboardSpacebar")
    instance.gui:setOnCloseCallback("gui_keyboardCloseCallback")
end

function Keyboard2.new(scriptedShape, title, charLimit, onConfirmCallback, onCloseCallback)
    assert(onConfirmCallback ~= nil and type(onConfirmCallback) == "function", "Invalid confirm callback passed.")
    assert(onCloseCallback ~= nil and type(onCloseCallback) == "function", "Invalid close callback passed.")

    local instance = Keyboard2()
    instance.scriptedShape = scriptedShape
    instance.buffer = ""
    instance.shift = false
    instance.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Scripts/SmKeyboardMaster/Gui/Keyboard.layout")
    instance.gui:setText("Title", title)
	instance.title = title
    instance.layout = sm.json.open("$MOD_DATA/Scripts/SmKeyboardMaster/Gui/KeyboardLayouts/default.json")
	instance.charLimit = charLimit

    instance.confirm = function (shape, buttonName)
        onConfirmCallback(instance.buffer)
        instance.gui:close()
    end

    instance.close = function (shape, buttonName)
        onCloseCallback()
        instance.buffer = ""
    end

    generateCallbacks(scriptedShape, instance)
    setCallbacks(instance)

    return instance
end

function Keyboard2:open(initialBuffer, title)
    self.buffer = initialBuffer or ""
    self.gui:setText("Textbox", self.buffer)
	self.gui:setText("Title", title)
	self.title = title
    self.gui:open()
end

function Keyboard2:onButtonClick(buttonName)
    local keyToAppend

    if self.shift then
        keyToAppend = self.layout.keys[tonumber(buttonName)][2]
        self:shiftKeys()
    else
        keyToAppend = self.layout.keys[tonumber(buttonName)][1]
    end

	if self.buffer:len() < self.charLimit then
		self.buffer = self.buffer .. keyToAppend
		sm.audio.play("Button on")
	else
		sm.gui.displayAlertText("Character limit reached!")
		sm.audio.play("RaftShark")
	end

    self.gui:setText("Textbox", self.buffer)
end

function Keyboard2:cancel()
	self.buffer = ""
    self.gui:setText("Textbox", self.buffer)
	sm.audio.play("Dancebass")
    --self.gui:close()
end

function Keyboard2:backspace()
    self.buffer = self.buffer:sub(1, -2)
    self.gui:setText("Textbox", self.buffer)
	sm.audio.play("Button off")
end

function Keyboard2:shiftKeys()
    self.shift = not self.shift
    self.gui:setButtonState("Shift", self.shift)

    for i = 1, #self.layout.keys, 1 do
        self.gui:setText(tostring(i), self.shift and self.layout.keys[i][2] or self.layout.keys[i][1])
    end
	sm.audio.play("Lever on")
end

function Keyboard2:spacebar()
    self.buffer = self.buffer .. " "
    self.gui:setText("Textbox", self.buffer)
	sm.audio.play("Button on")
end
