dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")

FirstClassSeat = class()
FirstClassSeat.maxChildCount = 10
FirstClassSeat.connectionOutput = sm.interactable.connectionType.seated
FirstClassSeat.colorNormal = sm.color.new( 0x00ff80ff )
FirstClassSeat.colorHighlight = sm.color.new( 0x6affb6ff )

--[[ Server ]]

function FirstClassSeat.server_onCreate( self )
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

function FirstClassSeat.server_onFixedUpdate( self )
	
	--ClientHack anti system
	if self.interactable:getSeatCharacter() and self.sv.saved.owner ~= 0 and self.interactable:getSeatCharacter():getPlayer().id ~= self.sv.saved.owner then
		self.interactable:getSeatCharacter():setLockingInteractable(nil)
	end

	self.interactable:setActive( self.interactable:getSeatCharacter() ~= nil )
end

function FirstClassSeat.sv_claim( self, params, player )
	if self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.sv.saved.name = player.name
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name } )
end

--[[ Client ]]

function FirstClassSeat.client_onCreate( self )
	self.cl = {}
	self.cl.seatedCharacter = nil
end

function FirstClassSeat.client_onDestroy( self )
	if self.gui then
		self.gui:destroy()
		self.gui = nil
	end
end

function FirstClassSeat.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.name = params.name
end

function FirstClassSeat.client_onUpdate( self, dt )
	-- Update gui upon character change in seat
	local seatedCharacter = self.interactable:getSeatCharacter()
	if self.cl.seatedCharacter ~= seatedCharacter then
		if seatedCharacter and seatedCharacter:getPlayer() and seatedCharacter:getPlayer():getId() == sm.localPlayer.getId() then
			self.gui = sm.gui.createSeatGui()
			self.gui:open()
		else
			if self.gui then
				self.gui:destroy()
				self.gui = nil
			end
		end
		self.cl.seatedCharacter = seatedCharacter
	end

	-- Update gui upon toolbar updates
	if self.gui then

		local interactables = self.interactable:getSeatInteractables()
		for i=1, 10 do
			local value = interactables[i]
			if value and value:getConnectionInputType() == sm.interactable.connectionType.seated then
				self.gui:setGridItem( "ButtonGrid", i-1, {
					["itemId"] = tostring(value:getShape():getShapeUuid()),
					["active"] = value:isActive()
				})
			else
				self.gui:setGridItem( "ButtonGrid", i-1, nil)
			end
		end
	end

end

function FirstClassSeat.client_canInteract( self, character, state )
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

function FirstClassSeat.cl_seat( self )
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end

function FirstClassSeat.client_onInteract( self, character, state )
	if state then
		self:cl_seat()
		if self.shape.interactable:getSeatCharacter() ~= nil then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_OCCUPIED}", 4.0 )
		end
	end
end

function FirstClassSeat.client_canTinker( self )
	if self.owner == 0 then
		return true
	end
	return false
end

function FirstClassSeat.client_onTinker( self, character, state )
	if state == true then
		self.network:sendToServer("sv_claim")
	end	
end

function FirstClassSeat.client_onAction( self, controllerAction, state )
	local consumeAction = true
	if state == true then
		if controllerAction == sm.interactable.actions.use or controllerAction == sm.interactable.actions.jump then
			self:cl_seat()
		elseif controllerAction == sm.interactable.actions.item0 then
			self.interactable:pressSeatInteractable( 0 )
		elseif controllerAction == sm.interactable.actions.item1 then
			self.interactable:pressSeatInteractable( 1 )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:pressSeatInteractable( 2 )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:pressSeatInteractable( 3 )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:pressSeatInteractable( 4 )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:pressSeatInteractable( 5 )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:pressSeatInteractable( 6 )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:pressSeatInteractable( 7 )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:pressSeatInteractable( 8 )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:pressSeatInteractable( 9 )
		elseif controllerAction == sm.interactable.actions.attack or controllerAction == sm.interactable.actions.create then
		else
			consumeAction = false
		end
	else
		if controllerAction == sm.interactable.actions.item0 then
			self.interactable:releaseSeatInteractable( 0 )
		elseif controllerAction == sm.interactable.actions.item1 then
			self.interactable:releaseSeatInteractable( 1 )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:releaseSeatInteractable( 2 )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:releaseSeatInteractable( 3 )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:releaseSeatInteractable( 4 )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:releaseSeatInteractable( 5 )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:releaseSeatInteractable( 6 )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:releaseSeatInteractable( 7 )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:releaseSeatInteractable( 8 )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:releaseSeatInteractable( 9 )
		elseif controllerAction == sm.interactable.actions.attack or controllerAction == sm.interactable.actions.create then
		else
			consumeAction = false
		end
	end
	return consumeAction
end

function FirstClassSeat.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		return true
	end
	sm.gui.displayAlertText("Only the owner can delete this")
	return false
end

function FirstClassSeat.server_canErase(self)
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

function FirstClassSeat.client_getAvailableChildConnectionCount( self, connectionType )
	local maxButtonCount = 10
	return maxButtonCount - #self.interactable:getChildren( sm.interactable.connectionType.seated )
end
