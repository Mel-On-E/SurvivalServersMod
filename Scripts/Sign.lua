dofile( "./SmKeyboardMaster/Scripts/Keyboard.lua" )

Sign = class()
Sign.maxParentCount = 1
Sign.maxChildCount = 0
Sign.connectionInput = sm.interactable.connectionType.logic
Sign.colorNormal = sm.color.new( 0x989592ff )
Sign.colorHighlight = sm.color.new( 0xb4b1aeff )

function Sign.client_onCreate(self)
	-- Create keyboard
    self.keyboard = Keyboard.new(self, "S I G N",
        function (bufferedText)
			sm.audio.play("Retrowildblip")
			self.network:sendToServer("server_setText", bufferedText)
        end,

        function ()
        end
    )
	self.color = self.shape.color
end

function Sign.server_setText( self, text, player)
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		self.sv.saved.text = text
		self.storage:save( self.sv.saved )
		self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, text = self.sv.saved.text } )
	end
end

function Sign.client_onFixedUpdate(self, dt)
	if self.gui then
		self.gui:setWorldPosition( self.shape.worldPosition + self.shape.up*0.05)
		
		if self.color ~= self.shape.color then
			self.color = self.shape.color
			local r = string.format("%x", self.shape.color.r * 255)
			if r:len() == 1 then r = "0" .. r end
			local g = string.format("%x", self.shape.color.g * 255)
			if g:len() == 1 then g = "0" .. g end
			local b = string.format("%x", self.shape.color.b * 255)
			if b:len() == 1 then b = "0" .. b end
			self.gui:setText( "Text", "#" .. r .. g .. b .. self.text )
		end
		
		local parent = self.shape:getInteractable():getSingleParent()
		if not parent or parent.active then
			self.gui:open()
		else
			self.gui:close()
		end
	end
end

function Sign.client_onDestroy(self)
	if self.gui then
		self.gui:close()
	end
end

function Sign.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.owner = 0
		self.sv.saved.name = "your mum"
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, text = self.sv.saved.text } )
end

function Sign.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.name = params.name
	self.text = params.text
	
	if self.text then
		if self.gui then self.gui:close() end
		
		self.gui = sm.gui.createNameTagGui()
		self.gui:setWorldPosition( self.shape.worldPosition + sm.vec3.new( 0, 0, 0.5 ) )
		self.gui:setRequireLineOfSight( true )
		self.gui:setMaxRenderDistance( 100 )
		
		local r = string.format("%x", self.shape.color.r * 255)
		if r:len() == 1 then r = "0" .. r end
		local g = string.format("%x", self.shape.color.g * 255)
		if g:len() == 1 then g = "0" .. g end
		local b = string.format("%x", self.shape.color.b * 255)
		if b:len() == 1 then b = "0" .. b end
		self.gui:setText( "Text", "#" .. r .. g .. b .. self.text )
		
		self.gui:open()
	end
end

function Sign.client_canInteract( self, character, state )
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

function Sign.client_onInteract( self, character, state )
	if state == true then
		local text = ""
		if self.text then text = self.text end
		self.keyboard:open(text)
	end	
end

function Sign.sv_activate( self, params, player )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		
	end
end

function Sign.client_canTinker( self, character, state )
	if self.owner == 0 then
		return true
	end
	return false
end

function Sign.client_onTinker( self, character, state )
	if state == true then
		self.network:sendToServer("sv_claim")
	end	
end

function Sign.sv_claim( self, params, player )
	if self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.sv.saved.name = player.name
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, text = self.sv.saved.text } )
end

function Sign.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		return true
	end
	sm.gui.displayAlertText("Only the owner can delete this")
	return false
end

function Sign.server_canErase(self)
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

function Sign.cl_onAlert( self, params )
	sm.gui.displayAlertText(params)
end