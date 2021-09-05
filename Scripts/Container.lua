dofile "$SURVIVAL_DATA/Scripts/game/survival_items.lua"

--table.insert(ContainerUuids, sm.uuid.new("ad35f395-af8f-40fa-aef4-77d827ac8a8a"))
--table.insert(ContainerUuids, sm.uuid.new("056123f1-f030-40df-946a-b830bf494c92"))

Container = class( nil )

function Container.server_onCreate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, self.data.containerSize, self.data.stackSize )
	end
	if self.data.filterUid then
		local filters = { sm.uuid.new( self.data.filterUid ) }
		container:setFilters( filters )
	end
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.owner = 0
		self.sv.saved.name = "your mum"
		self.storage:save( self.sv.saved )
	end
	container:setAllowCollect(false)
	container:setAllowSpend(false)
	self.hasPipes = false
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name } )
end

function Container.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.name = params.name
end

function Container.client_canCarry( self )
	local container = self.shape.interactable:getContainer( 0 )
	if container and sm.exists( container ) then
		return not container:isEmpty()
	end
	return false
end

function Container.client_onInteract( self, character, state )
	if state == true then
		local container = self.shape.interactable:getContainer( 0 )
		if container then
			local gui = nil
			
			if gui == nil then
				gui = sm.gui.createContainerGui( true )
				gui:setText( "UpperName", "#{CONTAINER_TITLE_GENERIC}" )
			end
			
			gui:setContainer( "UpperGrid", container )
			gui:setText( "LowerName", "#{INVENTORY_TITLE}" )
			gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
			gui:setOnCloseCallback( "cl_onClose" )
			self.network:sendToServer("server_open")
			gui:open()
		end
	end	
end

function Container.cl_onClose( self )
	self.network:sendToServer("server_close")
end

function Container.server_open( self, params, player )
	local container = self.shape.interactable:getContainer( 0 )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		container:setAllowCollect(true)
		container:setAllowSpend(true)
	else
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		self.network:sendToClients("cl_onMsg", player.name .. "#ff0000 is trying to steal from a chest.\nPlease report him to moderators so we can ban them!")
	end
end

function Container.cl_onMsg( self, params )
	sm.gui.chatMessage(params)
end

function Container.server_close( self, params, player )
	local container = self.shape.interactable:getContainer( 0 )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		container:setAllowCollect(false)
		container:setAllowSpend(false)
	end
end

function Container.client_canInteract( self, character, state )
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

function Container.client_canTinker( self, character, state )
	if self.owner == 0 then
		return true
	end
	return false
end

function Container.client_onTinker( self, character, state )
	if state == true then
		self.network:sendToServer("sv_claim")
	end	
end

function Container.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		return true
	end
	sm.gui.displayAlertText("Only the owner can delete this")
	return false
end

function Container.server_canErase(self)
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

function Container.sv_claim( self, params, player )
	if self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.sv.saved.name = player.name
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name } )
end

function Container.client_onUpdate( self, dt )

	local container = self.shape.interactable:getContainer( 0 )
	if container then
		local quantities = sm.container.quantity( container )
		
		local quantity = 0
		for _,q in ipairs(quantities) do
			quantity = quantity + q
		end
		local frame = 5 - math.ceil(((quantity )/(self.data.stackSize*self.data.containerSize))*5)
		self.interactable:setUvFrameIndex( frame )
	end
end

CoinContainer = class( Container )
CoinContainer.maxChildCount = 255
CoinContainer.connectionOutput = sm.interactable.connectionType.electricity
CoinContainer.colorNormal = sm.color.new( 0xffd700ff )
CoinContainer.colorHighlight = sm.color.new( 0xffe666ff )

function CoinContainer.server_onFixedUpdate( self )
	for k,interactable in ipairs(self.interactable:getChildren()) do
		if interactable:getConnectionOutputType() == 4 then
			sm.interactable.disconnect(self.interactable, interactable)
		end
	end
end
