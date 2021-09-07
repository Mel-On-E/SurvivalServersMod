--Thanks to TechnologicNick for sponsoring this code!

--TODO check part count to verify creation!!

CreationSpawner = class( nil )

function CreationSpawner.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.owner = 0
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, blueprints = self.blueprints, preview = self.preview } )
end

function CreationSpawner.sv_createPreview( self, params, player )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.preview = params.pos
		self.interactable:setActive(true)
		
		local success, data = pcall( sm.creation.importFromFile( player:getCharacter():getWorld(), "$MOD_DATA/Scripts/Blueprints/" .. player.id .. "/" .. self.blueprints[self.preview].file, sm.vec3.new(0,0,1200) ) )
		local char = sm.character.createCharacter(player, player.character:getWorld(), sm.vec3.new(0,0,1000), 0, 0, player.character)
		
		self.new = player
		
		self.network:setClientData( { owner = self.sv.saved.owner, blueprints = self.blueprints, preview = self.preview } )
	else
		self.network:sendToClient(player,"cl_onAlert", "This part is already in use")
	end
end

function CreationSpawner.sv_build( self, params, player )
	if player.id == self.sv.saved.owner or self.sv.saved.owner == 0 then
		local success, data = pcall( sm.creation.importFromFile( player:getCharacter():getWorld(), "$MOD_DATA/Scripts/Blueprints/" .. player.id .. "/" .. self.blueprints[self.preview].file, self.shape.worldPosition + sm.vec3.new(0,0,1) ) )
	
		--Remove blueprint from list and empty JSON file
		local newBlueprints = {}
		for k, value in ipairs(self.blueprints) do
			if k ~= self.pos then
				table.insert(newBlueprints, value)
			end
		end
		sm.json.save( {blueprints = newBlueprints}, "$MOD_DATA/Scripts/Blueprints/" .. player.id .. "/index.json" )
		sm.json.save( "SUS", "$MOD_DATA/Scripts/Blueprints/" .. player.id .. "/" .. self.blueprints[self.preview].file )
	
		self.shape:destroyShape()
	end
end

function CreationSpawner.server_onFixedUpdate( self)
	if self.new and self.tick then
		--find new creation
		local id = 0
		for k, body in ipairs(sm.body.getAllBodies()) do
			if body.id > id then
				id = body.id
				self.creation = body:getCreationShapes()
			end
		end
		self.network:sendToClient(self.new,"cl_createPreview", self.creation)
		self.new = nil
		self.tick = nil
	end
	if self.new then
		self.tick = "delay"
	end
end

function CreationSpawner.client_canInteract( self, character, state )
	if not self.shape:getBody():isStatic() then
		sm.gui.setInteractionText("Needs to be attached to ground!")
		return false
	end
	if self.owner == 0 or self.owner == sm.localPlayer.getPlayer().id then
		return true
	else
		sm.gui.setInteractionText("This part is in use!")
		return false
	end
end

function CreationSpawner.client_onInteract( self, character, state )
	if state == true then
		sm.effect.playEffect("Sensor on - Level 3", self.shape.worldPosition)
		
		self.network:sendToServer("server_LoadBlueprintData")
	
		self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/CreationSpawner.layout")

		self.gui:setButtonCallback("Preview", "client_Preview")
		self.gui:setButtonCallback("Next", "client_Next")
		self.gui:setButtonCallback("Prev", "client_Prev")

		self.gui:setOnCloseCallback("client_onGUIDestroyCallback")

		self.gui:open()
		
		if not self.pos then
			self.pos = 1
		end
	end	
end

function CreationSpawner:client_Preview()
	if self.preview and self.pos == self.preview then
		self.network:sendToServer("sv_build")
		sm.audio.play("Blueprint - Build")
	else
		self.network:sendToServer("sv_createPreview", {pos = self.pos})
		sm.audio.play("Blueprint - Open")
	end
end

function CreationSpawner:client_Next()
	self.pos = math.min(self.pos + 1, #self.blueprints)
	sm.audio.play("Button on")
end

function CreationSpawner:client_Prev()
	self.pos = math.max(self.pos - 1, 1)
	sm.audio.play("Button on")
end

function CreationSpawner:client_onGUIDestroyCallback()
	sm.effect.playEffect("Sensor off - Level 3", self.shape.worldPosition)
end

function CreationSpawner.cl_createPreview( self, creation )

    -- Destroy all previously created effects
    self:destroyEffects()

    self.effects = {}
    self.offset = self.offset or sm.vec3.zero()
    self.rotation = self.rotation or sm.quat.identity()

    for _, shape in ipairs(creation) do
        if shape ~= self.shape then

            local effect = sm.effect.createEffect( "ShapeRenderable" )
            effect:setParameter( "uuid", shape.shapeUuid )
            effect:setParameter( "color", shape.color )
    
            if sm.item.isBlock(shape.shapeUuid) then
                -- Blocks
                effect:setParameter( "boundingBox", shape:getBoundingBox() )
                effect:setScale( shape:getBoundingBox() )
            else
                -- Parts
    
                effect:setScale( sm.vec3.one() * sm.construction.constants.subdivideRatio )
            end
    
            effect:start()
    
            self.effects[shape] = effect

        end
    end
	
	for shape, effect in pairs(self.effects) do
        effect:setPosition( self.shape.worldPosition + shape.worldPosition + sm.vec3.new(0,0,-1199) )
        effect:setRotation( shape.worldRotation )
    end
	
	self.network:sendToServer("sv_destoryCreation")
end

function CreationSpawner.sv_destoryCreation(self)
	if self.creation then
		for k, shape in ipairs(self.creation) do
			shape:destroyShape()
		end
	end
end

function CreationSpawner.server_LoadBlueprintData(self, params, player)
	local success, data = pcall(sm.json.open, "$MOD_DATA/Scripts/Blueprints/" .. player.id .. "/index.json")
	if success and type(data) == "table" then
		if self.blueprints and #self.blueprints ~= #data.blueprints then
			self.network:sendToClient(player, "destroyEffects")
			self.preview = nil
		end
		self.blueprints = data.blueprints
		if not self.blueprints then
			self.network:sendToClient(player, "cl_onAlert", "You don't have any blueprints")
		end
		self.network:setClientData( { owner = self.sv.saved.owner, blueprints = self.blueprints, preview = self.preview } )
	end
end

function CreationSpawner.client_onFixedUpdate(self)
	if self.gui then
		if self.gui:isActive() and self.blueprints then
			local blueprint = self.blueprints[self.pos]
			self.gui:setText("BlueprintInfo", "Parts: " .. blueprint.parts .. "\nDate: " .. blueprint.date .. "\nRent: $" .. blueprint.rent .. "\nInfo: " .. blueprint.info)
			self.gui:setText("Page", self.pos .. " / " .. #self.blueprints)
			if self.preview and self.pos == self.preview then
				self.gui:setText("Preview", "Build Creation")
				self.gui:setVisible("Warning", true)
			else
				self.gui:setText("Preview", "Preview Creation")
				self.gui:setVisible("Warning", false)
			end
		end
	end
end

function CreationSpawner.destroyEffects( self )
    if self.effects then
        for k, v in pairs(self.effects) do
            v:destroy()
			self.effects = nil
        end
    end
end

function CreationSpawner.client_onDestroy( self )
    self:destroyEffects()
	if self.gui then
		self.gui:close()
	end
end

function CreationSpawner.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.blueprints = params.blueprints
	self.preview = params.preview
end

function CreationSpawner.client_playSound(self, name)
	sm.audio.play(name, self.shape.worldPosition)
end

function CreationSpawner.cl_onAlert( self, params )
	sm.gui.displayAlertText(params)
	if self.gui then
		self.gui:close()
	end
end

function CreationSpawner.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		return true
	end
	sm.gui.displayAlertText("Object is currently in use")
	return false
end

function CreationSpawner.server_canErase(self)
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