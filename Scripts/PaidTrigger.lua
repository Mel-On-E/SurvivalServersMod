PaidTrigger = class( nil )
PaidTrigger.maxChildCount = 255
PaidTrigger.maxParentCount = 2
PaidTrigger.connectionOutput = sm.interactable.connectionType.logic
PaidTrigger.connectionInput = sm.interactable.connectionType.seated + sm.interactable.connectionType.electricity
PaidTrigger.colorNormal = sm.color.new( 0xee2a7bff )
PaidTrigger.colorHighlight = sm.color.new( 0xff4394ff )

dofile( "./SmKeyboardMaster/Scripts/Keypad.lua" )

function PaidTrigger.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.owner = 0
		self.sv.saved.name = "your mum"
		self.sv.saved.price = 1
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, price = self.sv.saved.price } )
end

function PaidTrigger.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.name = params.name
	self.price = params.price
end

function PaidTrigger.client_onCreate( self )
	self.keypad = Keypad.new(self, "Price",
        function (bufferedValue)
            sm.audio.play("Retrowildblip")
			self.network:sendToServer("server_setPrice", bufferedValue)
        end,

        function ()
        end
    )
end

function PaidTrigger.server_onFixedUpdate( self )
	local seat = false
	for k,parent in ipairs(self.interactable:getParents()) do
		--print(k)
		-- 8 or 14 == seat 512 = battery
		if parent:getConnectionOutputType() == 8 or parent:getConnectionOutputType() == 14 then
			if not seat then
				seat = true
			else
				sm.interactable.disconnect(parent, self.interactable)
			end
		elseif (not seat and k == 2) or parent.shape:getShapeUuid() ~= sm.uuid.new("056123f1-f030-40df-946a-b830bf494c92") then --2nd cointainer or not cointainer
			sm.interactable.disconnect(parent, self.interactable)
		end
	end
end

function PaidTrigger.client_canInteract( self, character, state )
	local hasCointainer = false
	for k, container in ipairs(self.interactable:getParents()) do
		if container:getContainer(0) then
			if self.owner == 0 then
				sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
				return false
			elseif self.owner == sm.localPlayer.getPlayer().id then
				sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Edit price: #FFD700" .. tostring(self.price) .. "#FFFFFF WoCoins™")
				return true
			else
				sm.gui.setInteractionText("Owned by", self.name)
				sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use"), "Use (#FFD700" .. tostring(self.price) .. "#FFFFFF WoCoins™)")
				return true
			end
		end
	end
	if not hasCointainer then
		sm.gui.setInteractionText("Connect to ", "Cointainer")
		if self.owner == 0 then
			sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
		end
		return false
	end
end

function PaidTrigger.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer("sv_activate")
	end
end

function PaidTrigger.sv_activate( self, params, player )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		self.interactable:setActive(not self.interactable.active)
		self.network:sendToClients("client_msg", {sound = "Lever " .. (self.interactable.active and "on" or "off" )})
	elseif player.character:getLockingInteractable() then
		self.network:sendToClient(player, "client_msg", {msg = "This switch is owned by " .. self.sv.saved.name})
	else --transaction
		local inventory = player:getInventory()
		local cointainer
		for k, container in ipairs(self.interactable:getParents()) do
			if container:getContainer(0) then
				cointainer = container:getContainer(0)
			end
		end
		
		if inventory:canSpend(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price) then
			if cointainer:canCollect(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price) then
				sm.container.beginTransaction()
				sm.container.spend(inventory, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price, false)
				sm.container.collect(cointainer, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price, false)
				sm.container.endTransaction()
				
				self.interactable:setActive(not self.interactable.active)
				self.network:sendToClients("client_msg", {sound = "Lever " .. (self.interactable.active and "on" or "off" )})
			else
				self.network:sendToClient(player, "client_msg", {msg = "#ff0000Cointainer full", sound = "RaftShark"})
			end
		else
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Insufficent funds", sound = "RaftShark"})
		end
	end
end

function PaidTrigger.client_canTinker( self, character, state )
	if self.owner == 0 or sm.localPlayer.getPlayer().id == self.owner then
		for k, container in ipairs(self.interactable:getParents()) do
			if container:getContainer(0) then
				if sm.localPlayer.getPlayer().id == self.owner then
					return true
				end
			end
		end
		if self.owner == 0 then
			return true
		end
	end
	return false
end

function PaidTrigger.client_onTinker( self, character, state )
	if state == true then
		if self.owner == 0 then
		self.network:sendToServer("sv_claim")
		elseif sm.localPlayer.getPlayer().id == self.owner then
			self.keypad:open(self.price)
		end
	end	
end

function PaidTrigger.server_setPrice( self, price, player)
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		self.sv.saved.price = price
		self.storage:save( self.sv.saved )
		self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, price = self.sv.saved.price } )
	end
end

function PaidTrigger.sv_claim( self, params, player )
	if self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.sv.saved.name = player.name
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, price = self.sv.saved.price } )
end

function PaidTrigger.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		return true
	end
	sm.gui.displayAlertText("Only the owner can delete this")
	return false
end

function PaidTrigger.server_canErase(self)
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

function PaidTrigger.client_msg(self, params)
	if params.msg then
		sm.gui.displayAlertText(params.msg)
	end
	if params.sound then
		sm.audio.play(params.sound, self.shape.worldPosition)
	end
end

PaidSwitchTrigger = class( PaidTrigger )
PaidButtonTrigger = class( PaidTrigger )

function PaidButtonTrigger.client_canInteract( self, character, state )
	self.look = true

	local hasCointainer = false
	for k, container in ipairs(self.interactable:getParents()) do
		if container:getContainer(0) then
			if self.owner == 0 then
				sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
				return false
			elseif self.owner == sm.localPlayer.getPlayer().id then
				sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Edit price: #FFD700" .. tostring(self.price) .. "#FFFFFF WoCoins™")
				return true
			else
				sm.gui.setInteractionText("Owned by", self.name)
				sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use"), "Use (#FFD700" .. tostring(self.price) .. "#FFFFFF WoCoins™)")
				return true
			end
		end
	end
	if not hasCointainer then
		sm.gui.setInteractionText("Connect to ", "Cointainer")
		if self.owner == 0 then
			sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
		end
		return false
	end
end

function PaidButtonTrigger.client_onInteract( self, character, state )
	if state then
		self.network:sendToServer("sv_activate")
		character:setLockingInteractable(self.interactable)
	elseif character and character:getLockingInteractable() and character:getLockingInteractable() ~= self.interactable then
		self.network:sendToServer("sv_activate")
	end
end

function PaidButtonTrigger.client_onAction( self, controllerAction, state)
	if not state and controllerAction == 15 then
		sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
		self.network:sendToServer("sv_activate")
	end
	return false
end

function PaidButtonTrigger.client_onFixedUpdate( self)
	if not self.look and sm.localPlayer.getPlayer().character:getLockingInteractable() == self.interactable then
		sm.localPlayer.getPlayer().character:setLockingInteractable(nil)
		self.network:sendToServer("sv_activate")
	end
	self.look = false
end

function PaidButtonTrigger.sv_activate( self, params, player )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		self.interactable:setActive(not self.interactable.active)
		self.network:sendToClients("client_msg", {sound = "Lever " .. (self.interactable.active and "on" or "off" )})
	elseif player.character:getLockingInteractable() then
		self.network:sendToClient(player, "client_msg", {msg = "This button is owned by " .. self.sv.saved.name})
	else --transaction
		if self.interactable.active then 
			self.interactable:setActive(not self.interactable.active)
			return
		end
			
		local inventory = player:getInventory()
		local cointainer
		for k, container in ipairs(self.interactable:getParents()) do
			if container:getContainer(0) then
				cointainer = container:getContainer(0)
			end
		end
		
		if inventory:canSpend(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price) then
			if cointainer:canCollect(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price) then
				sm.container.beginTransaction()
				sm.container.spend(inventory, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price, false)
				sm.container.collect(cointainer, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.sv.saved.price, false)
				sm.container.endTransaction()
				
				self.interactable:setActive(not self.interactable.active)
				self.network:sendToClients("client_msg", {sound = "Lever " .. (self.interactable.active and "on" or "off" )})
			else
				self.network:sendToClient(player, "client_msg", {msg = "#ff0000Cointainer full", sound = "RaftShark"})
			end
		else
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Insufficent funds", sound = "RaftShark"})
		end
	end
end