Bed = class( nil )

function Bed.server_onDestroy( self )
	if self.loaded then
		if g_respawnManager then
			g_respawnManager:sv_destroyBed( self.shape )
		end
		self.loaded = false
	end
end

function Bed.server_onUnload( self )
	if self.loaded then
		g_respawnManager:sv_updateBed( self.shape )
		self.loaded = false
	end
end

function Bed.sv_activateBed( self, character )
	if g_respawnManager then
		g_respawnManager:sv_registerBed( self.shape, character )
	end
end

function Bed.server_onCreate( self )
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

function Bed.server_onFixedUpdate( self )
	--ClientHack anti system
	if self.interactable:getSeatCharacter() and self.sv.saved.owner ~= 0 and self.interactable:getSeatCharacter():getPlayer().id ~= self.sv.saved.owner then
		self.interactable:getSeatCharacter():setLockingInteractable(nil)
	end

	local prevWorld = self.currentWorld
	self.currentWorld = self.shape.body:getWorld()
	if prevWorld ~= nil and self.currentWorld ~= prevWorld then
		g_respawnManager:sv_updateBed( self.shape )
	end
end

function Bed.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.name = params.name
end

function Bed.client_canInteract( self, character, state )
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

function Bed.client_canTinker( self, character, state )
	if self.owner == 0 then
		return true
	end
	return false
end

function Bed.client_onTinker( self, character, state )
	if state == true then
		self.network:sendToServer("sv_claim")
	end	
end

function Bed.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		return true
	end
	sm.gui.displayAlertText("Only the owner can delete this")
	return false
end

function Bed.server_canErase(self)
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


function Bed.sv_claim( self, params, player )
	if self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.sv.saved.name = player.name
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name } )
end

function Bed.client_onInteract( self, character, state )
	if state == true then
		if self.shape.body:getWorld().id > 1 then
			sm.gui.displayAlertText( "#{INFO_HOME_NOT_STORED}" )
		else
			self.network:sendToServer( "sv_activateBed", character )
			self:cl_seat()
			sm.gui.displayAlertText( "#{INFO_HOME_STORED}" )
		end
	end
end

function Bed.cl_seat( self )
    if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
        self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
    end
end

function Bed.client_onAction( self, controllerAction, state )
    local consumeAction = true
    if state == true then
        if controllerAction == sm.interactable.actions.use or controllerAction == sm.interactable.actions.jump then
            self:cl_seat()
		else
            consumeAction = false
        end
    else
		consumeAction = false
    end
    return consumeAction
end