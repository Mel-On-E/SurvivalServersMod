dofile( "./SmKeyboardMaster/Scripts/Keyboard.lua" )

TextPart = class()

function TextPart.validateCallbackDummy(data, player)
	return true, data
end

function TextPart.requestSaveCallbackDummy()
	
end

function TextPart.onTextSetCallbackDummy(text)
	
end

function TextPart.onKeyboardCloseCallbackDummy()
	
end

TextPart.defaultData = {text = nil}

function TextPart.client_new(scriptedPart, keyboardTitle, onTextSetCallback, onKeyboardCloseCallback)
	local self = TextPart()
	self.scriptedPart = scriptedPart
	self.data = TextPart.defaultData
	self.scriptedPart.client_setTextPartData =
		function (partSelf, data)
		self:client_setTextPartData(data)
		end
	self.onTextSetCallback = onTextSetCallback or TextPart.onTextSetCallbackDummy
	self.onKeyboardCloseCallback = onKeyboardCloseCallback or TextPart.onKeyboardCloseCallbackDummy
	self.keyboardTitle = keyboardTitle
	return self
end

function TextPart.server_new(scriptedPart, validateCallback, requestSaveCallback)
	local self = TextPart()
	self.scriptedPart = scriptedPart
	self.data = TextPart.defaultData
	self.validateCallback = validateCallback or validateCallbackDummy
	self.requestSaveCallback = requestSaveCallback or validateCallbackDummy
	self.scriptedPart.server_setTextPartData =
		function (partSelf, data, player)
		self:server_setTextPartData(data, player)
		end
	return self
end

function TextPart.client_setTextPartData(self, data)
	self.data = data
end

function TextPart.client_sendToServer(self)
	if self.data.text == "" then self.data.text = nil end
	self.scriptedPart.network:sendToServer("server_setTextPartData", self.data)
end

function TextPart.server_setTextPartData(self, data, player)
	if data.text == nil then data.text = "" end
	
	local valid, processedData = self.validateCallback(data, player)
	if not valid then return end
	data = processedData
	
	if data.text == "" then data.text = nil end
	
	self.data = data
	self:requestSaveCallback()
	self:server_sendToClients()
end

function TextPart.server_sendToClients(self)
	self.scriptedPart.network:sendToClients("client_setTextPartData", self.data)
end

function TextPart.client_beginTextEdit(self)
	self:client_createKeyboard(self.keyboardTitle)
end

function TextPart.client_getText(self, color)
	local text = self.data.text
	if text == nil then text = "" end
	if color then return colorToHashtag(color)..text end
	return text
end

function TextPart.client_createKeyboard(self, keyboardTitle)
	if not self.keyboard then
	self.keyboard = Keyboard.new(self.scriptedPart, keyboardTitle,
		function (text)
			self:client_onKeyboardConfirm(text)
		end,
		function ()
			self:client_onKeyboardClose()
		end
	)
	end
	self.keyboard:open(self:client_getText())
end

function TextPart.client_destroyKeyboard(self)
	if self.keyboard then
		self.keyboard = nil 
	end
end

function TextPart.client_onKeyboardConfirm(self, text)
	self.data.text = text
	self:client_sendToServer()
	self:onTextSetCallback(text)
end

function TextPart.client_onKeyboardClose(self)
	self:client_destroyKeyboard()
	self:onKeyboardCloseCallback()
end

--Logistic curve function
function sigmoid(x, a, b)
	return 1/(1 + math.exp(-2 * a * (x + b)))
end

--Adjust and convert a sm.color to a hex encoded color hashtag string (e.g. paint tool white converts to "#fefefe")
function colorToHashtag(color)
	col = sm.color.new(
			sigmoid(color.r, 5, -0.25),
			sigmoid(color.g, 5, -0.25),
			sigmoid(color.b, 5, -0.25))
	return "#"..string.sub(tostring(col), 0, 6)
end