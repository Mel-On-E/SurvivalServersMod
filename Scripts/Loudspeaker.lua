--Include the on screen keyboard library
dofile( "./SmKeyboardMaster/Scripts/Keyboard.lua" )

Speaker = class()

--Initialize part properties
Speaker.maxParentCount = 1
Speaker.maxChildCount = 0
Speaker.connectionInput = sm.interactable.connectionType.logic
Speaker.colorNormal = sm.color.new( 0x989592ff )
Speaker.colorHighlight = sm.color.new( 0xb4b1aeff )

--Constants
keyboardTitle = "S P E A K E R"
maxDistanceBlocks = 75
cooldownTimeSeconds = 5

confirmEffectName = "Sensor on - Level 5"
activateEffectName = "Supervisor - Fail"
claimEffectName = "LootProjectile - Hit"

function Speaker.client_onCreate(self)
	--Create keyboard GUI
	self.keyboard = Keyboard.new(self, keyboardTitle,
		function (text)
			self:cl_onKeyboardConfirm(text)
		end,
		function ()
			self:cl_onKeyboardClose()
		end
	)
	--Create effects
	self.confirmEffect = sm.effect.createEffect(confirmEffectName, self.interactable)
	self.activateEffect = sm.effect.createEffect(activateEffectName, self.interactable)
	self.claimEffect = sm.effect.createEffect(claimEffectName, self.interactable)
	self.claimEffect:setOffsetPosition(sm.vec3.new(0, 0, -0.35))
	--Initialize
	self:cl_init()
end

function Speaker.server_onCreate(self)
	self:sv_init()
end

function Speaker.cl_onKeyboardConfirm(self, text)
	self.network:sendToServer("sv_setText", text)
	self.confirmEffect:start()
end

function Speaker.cl_onKeyboardClose(self)
	
end

--Client initialization
function Speaker.cl_init(self)
	self.data = {
		text = "sus",
		owner = {
			id = -1,
			name = "Joe Mama"
		}
	}
	self.cooldownTimer = 0
end

--Server initialization
function Speaker.sv_init(self)
	self.sv = {}
	--Load the save data
	self.sv.saved = self.storage:load()
	--Initialize the save data if it doesn't exist
	if not self.sv.saved then
		self.sv.saved = {
			text = "",
			owner = { 
				id = 0,
				name = "Joe Mama" 
			}
		}
		self.storage:save(self.sv.saved)
	end
	--Send the data to clients
	self.network:setClientData(self.sv.saved)
end

function Speaker.client_onDestroy(self)
	self.confirmEffect:stopImmediate()
	self.activateEffect:stopImmediate()
	self.claimEffect:stopImmediate()
end

--Request to set the text
function Speaker.sv_setText(self, text, player)
	local ownerId = self.sv.saved.owner.id
	if ownerId == 0 or player.id == ownerId then
		self.sv.saved.text = text
		self.storage:save( self.sv.saved )
		self.network:setClientData(self.sv.saved)
	end
end

function Speaker.sv_claim(self, params, player)
	if self.sv.saved.owner.id ~= 0 then return end
	self.sv.saved.owner.id = player.id
	self.sv.saved.owner.name = player.name
	self.storage:save(self.sv.saved)
	self.network:setClientData(self.sv.saved)
end

function Speaker.client_onClientDataUpdate( self, params )
	self.data = params
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
		self.keyboard:open(self.data.text)
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
	if self.cooldownTimer > 0 then
		self.cooldownTimer = self.cooldownTimer - delta
		return
	end
	if self.data.text == "" then return end
	local parent = self.shape:getInteractable():getSingleParent()
	if parent and parent.active then
		local playerPos = sm.localPlayer.getPlayer().character.worldPosition
		local shapePos = self.shape:getWorldPosition()
		local distance = euclideanDistance(playerPos, shapePos) * 4
		if distance <= maxDistanceBlocks then
			self:cl_activate()
			self.cooldownTimer = cooldownTimeSeconds
		end
	end
end

--Activate the speaker for a client
function Speaker.cl_activate(self)
	sm.gui.displayAlertText(self.data.text)
	
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