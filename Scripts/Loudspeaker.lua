--Include the on screen keyboard library
dofile( "TextPart.lua" )

Speaker = class()

--Initialize part properties
Speaker.maxParentCount = 1
Speaker.maxChildCount = 0
Speaker.connectionInput = sm.interactable.connectionType.logic
Speaker.colorNormal = sm.color.new( 0x989592ff )
Speaker.colorHighlight = sm.color.new( 0xb4b1aeff )

--Constants
Speaker.keyboardTitle = "S P E A K E R"
Speaker.maxDistanceBlocks = 75
Speaker.cooldownTimeSeconds = 5

--Effects
Speaker.confirmEffectName = "Sensor on - Level 5"
Speaker.activateEffectName = "Supervisor - Fail"
Speaker.claimEffectName = "LootProjectile - Hit"

function Speaker.client_onCreate(self)
	--Create effects
	self.confirmEffect = sm.effect.createEffect(Speaker.confirmEffectName, self.interactable)
	self.activateEffect = sm.effect.createEffect(Speaker.activateEffectName, self.interactable)
	self.claimEffect = sm.effect.createEffect(Speaker.claimEffectName, self.interactable)
	self.claimEffect:setOffsetPosition(sm.vec3.new(0, 0, -0.35))
	--Initialize
	self:cl_init()
end

function Speaker.server_onCreate(self)
	--Initialize
	self:sv_init()
end

--Client initialization
function Speaker.cl_init(self)
	self.data = {
		owner = {
			id = -1,
			name = "Joe Mama"
		}
	}
	--Create the TextPart helper (client-side version)
	self.textPart = TextPart.client_new(self, Speaker.keyboardTitle, 
		function(text)
			self.confirmEffect:start()
		end,
		function()
			
		end
	)
	self.cooldownTimer = 0
end

--Server initialization
function Speaker.sv_init(self)
	--Create data table; owner only (will be replaced when protected parts become a module)
	self.data = {
		owner = {
			id = 0,
			name = "Joe Mama"
		}
	}
	--Create the TextPart helper (server-side version)
	self.textPart = TextPart.server_new(self,
		function(data, player)
			local ownerId = self.data.owner.id
			if ownerId == 0 or player.id == ownerId then return true, data end
			return false
		end,
		function()
			self:sv_SaveData()
		end
	)
	
	--Try to load legacy data; if the data is normal or non existent, load the data normally
	if not self:sv_LoadDataBC() then
		self:sv_LoadData()
	end
	
	--Send the data to clients
	self.network:setClientData(self.saved.owner) --Owner only (will be replaced when protected parts become a module)
	self.textPart:server_sendToClients() --Sync TextPart data
end

function Speaker.client_onDestroy(self)
	--Stop all the effects
	self.confirmEffect:stopImmediate()
	self.activateEffect:stopImmediate()
	self.claimEffect:stopImmediate()
end

--Request to claim the part
function Speaker.sv_claim(self, params, player)
	if self.data.owner.id ~= 0 then return end
	self.data.owner.id = player.id
	self.data.owner.name = player.name
	self:sv_SaveData()
	self.network:setClientData(self.saved.owner) --Owner only (will be replaced when protected parts become a module)
end

--Owner only (will be replaced when protected parts become a module)
function Speaker.client_onClientDataUpdate( self, owner )
	self.data.owner = owner
end

function Speaker.client_canInteract(self, character, state)
	local ownerId = self.data.owner.id
	if ownerId == 0 then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
	elseif ownerId == sm.localPlayer.getPlayer().id then
		sm.gui.setInteractionText("You own this")
	else
		sm.gui.setInteractionText("Owned by", self.data.owner.name)
		sm.gui.setInteractionText("")
		return false
	end
	return true
end

function Speaker.client_onInteract(self, character, state)
	if state == true then
		--Request to begin editing the text
		self.textPart:client_beginTextEdit()
	end	
end

function Speaker.client_canTinker(self, character, state)
	if self.data.owner.id == 0 then
		return true
	end
	return false
end

function Speaker.client_onTinker(self, character, state)
	if state == true then
		self.claimEffect:start()
		self.network:sendToServer("sv_claim")
	end	
end

function Speaker.client_onFixedUpdate(self, delta)
	--If the cooldown timer has not ended yet, decrease it and abort
	if self.cooldownTimer > 0 then
		self.cooldownTimer = self.cooldownTimer - delta
		return
	end
	--Get the text from the TextPart
	text = self.textPart:client_getText()
	--Abort if there's no text
	if text == "" then return end
	
	local parent = self.shape:getInteractable():getSingleParent()
	if parent and parent.active then
		--Calculate the distance between the player and the part
		local playerPos = sm.localPlayer.getPlayer().character.worldPosition
		local shapePos = self.shape:getWorldPosition()
		local distance = euclideanDistance(playerPos, shapePos) * 4
		--Activate if the player is in range
		if distance <= Speaker.maxDistanceBlocks then
			self:cl_activate()
			self.cooldownTimer = Speaker.cooldownTimeSeconds
		end
	end
end

--Save part data
function Speaker.sv_SaveData(self)
	self.saved = 
	{
		owner = self.data.owner,
		textPartData = self.textPart.data
	}
	self.storage:save(self.saved)
	--print("Data saved!")
end

--Load part data
function Speaker.sv_LoadData(self)
	self.saved = self.storage:load()
	if not self.saved then self:sv_SaveData() end
	self.data.owner = self.saved.owner
	self.textPart.data = self.saved.textPartData
	--print("Data loaded!")
end

--(Try to) load legacy part data
function Speaker.sv_LoadDataBC(self)
	local saved = self.storage:load()
	if saved == nil or saved.textPartData ~= nil then return false end
	self.data.owner = saved.owner
	self.textPart.data.text = saved.text
	--print("Legacy data loaded!")
	self:sv_SaveData()
	return true
end

--Activate the speaker for a client
function Speaker.cl_activate(self)
	sm.gui.displayAlertText(self.textPart:client_getText(self.shape.color))
	self.activateEffect:start()
end

--Euclidean distance between points a and b
function euclideanDistance(a, b)
	local dif = a - b
	local distance = math.sqrt(dif.x * dif.x + dif.y * dif.y + dif.z * dif.z)
	return distance
end

--Chebyshev distance between points a and b
function chebyshevDistance(a, b)
	local dif = a - b
	local distance = math.max (
		math.abs(dif.x), 
		math.abs(dif.y), 
		math.abs(dif.z))
	return distance
end