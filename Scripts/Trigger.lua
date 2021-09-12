Trigger = class( nil )
Trigger.maxChildCount = 255
Trigger.maxParentCount = 1
Trigger.connectionOutput = sm.interactable.connectionType.logic
Trigger.connectionInput = sm.interactable.connectionType.seated
Trigger.colorNormal = sm.color.new( 0xee2a7bff )
Trigger.colorHighlight = sm.color.new( 0xff4394ff )

function Trigger.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.owner = 0
		self.sv.saved.name = "your mum"
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name } )
end

function Trigger.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.name = params.name
end

function Trigger.client_canInteract( self, character, state )
	if self.owner == 0 then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
	elseif self.owner == sm.localPlayer.getPlayer().id then
		sm.gui.setInteractionText("You own this")
	else
		sm.gui.setInteractionText("Owned by", self.name)
		sm.gui.setInteractionText("")
		return false
	end
	return true
end

function Trigger.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer("sv_activate")
	end	
end

function Trigger.sv_activate( self, params, player )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		self.interactable:setActive(not self.interactable.active)
		self.network:sendToClients("client_playSound", "Lever " .. (self.interactable.active and "on" or "off" ))
	elseif player.character:getLockingInteractable() then
		self.network:sendToClient(player,"cl_onAlert", "This switch is owned by " .. self.sv.saved.name)
	end
end

function Trigger.client_canTinker( self, character, state )
	if self.owner == 0 then
		return true
	end
	return false
end

function Trigger.client_onTinker( self, character, state )
	if state == true then
		self.network:sendToServer("sv_claim")
	end	
end

function Trigger.sv_claim( self, params, player )
	if self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.sv.saved.name = player.name
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name } )
end

function Trigger.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		return true
	end
	sm.gui.displayAlertText("Only the owner can delete this")
	return false
end

function Trigger.server_canErase(self)
	if self.sv.saved.owner == 0 then return true end
	
	for k, player in pairs(sm.player.getAllPlayers()) do
		if player.id == self.sv.saved.owner then
			local char = player:getCharacter()
			if char ~= nil and sm.exists(char) then
				local offset = char:isCrouching() and 0.275 or 0.56
				local pos_offset = char.worldPosition + sm.vec3.new(0, 0, offset)
				local hit, result = sm.physics.raycast(pos_offset, pos_offset + char.direction * 7.5)
				if hit and result.type == "body" and result:getShape() == self.shape then
					return true 
				end
			end
		end
	end
	return false
end

function Trigger.client_playSound(self, name)
	sm.audio.play(name, self.shape.worldPosition)
end

function Trigger.cl_onAlert( self, params )
	sm.gui.displayAlertText(params)
end

SwitchTrigger = class( Trigger )
ButtonTrigger = class( Trigger )

function ButtonTrigger.client_canInteract( self, character, state )
	self.look = true
	if self.owner == 0 then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
	elseif self.owner == sm.localPlayer.getPlayer().id then
		sm.gui.setInteractionText("You own this")
	else
		sm.gui.setInteractionText("Owned by", self.name)
		sm.gui.setInteractionText("")
		return false
	end
	return true
end

function ButtonTrigger.client_onInteract( self, character, state )
	if state then
		self.network:sendToServer("sv_activate")
		character:setLockingInteractable(self.interactable)
	elseif character and character:getLockingInteractable() and character:getLockingInteractable() ~= self.interactable then
		self.network:sendToServer("sv_activate")
	end
end

function ButtonTrigger.client_onAction( self, controllerAction, state)
	if not state and controllerAction == 15 then
		sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
		self.network:sendToServer("sv_activate")
	end
	return false
end

function ButtonTrigger.client_onFixedUpdate( self)
	if not self.look and sm.localPlayer.getPlayer().character:getLockingInteractable() == self.interactable then
		sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
		self.network:sendToServer("sv_activate")
	end
	self.look = false
end

function ButtonTrigger.sv_activate( self, params, player )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		self.interactable:setActive(not self.interactable.active)
		self.network:sendToClients("client_playSound", "Button " .. (self.interactable.active and "on" or "off" ))
	elseif player.character:getLockingInteractable() then
		self.network:sendToClient(player,"cl_onAlert", "This button is owned by " .. self.sv.saved.name)
	end
end