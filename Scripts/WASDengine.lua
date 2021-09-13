WASDengine = class()
WASDengine.maxParentCount = 2
WASDengine.maxChildCount = 0
WASDengine.connectionInput = sm.interactable.connectionType.power + sm.interactable.connectionType.gasoline
WASDengine.connectionOutput = sm.interactable.connectionType.none
WASDengine.colorNormal = sm.color.new( 0xff8000ff )
WASDengine.colorHighlight = sm.color.new( 0xff9f3aff )

local gears = {
	{ power = 0 },
	{ power = 1 },
	{ power = 2 },
	{ power = 4 },
	{ power = 8 },--1
	{ power = 16 },
	{ power = 32 },--2
	{ power = 64 },
	{ power = 128 },--3
	{ power = 256 },
	{ power = 512 }, --4
	{ power = 1024 },
	{ power = 2048 }, --5
}

local EngineLevels = {
	["69696969-9340-46d9-83d6-69d7c68ad950"] = {
		upgrade = "69696969-9340-46d9-83d6-89d7c68a6950",
		cost = 8,
		gearCount = 5,
		pointsPerFuel = 3000,
		level = 1
	},
	["69696969-9340-46d9-83d6-89d7c68a6950"] = {
		upgrade = "69696969-9340-46d9-83d6-89d7c69ad950",
		cost = 12,
		gearCount = 7,
		pointsPerFuel = 5250,
		level = 2
	},
	["69696969-9340-46d9-83d6-89d7c69ad950"] = {
		upgrade = "69696969-9340-46d9-83d6-89d6968ad950",
		cost = 16,
		gearCount = 9,
		pointsPerFuel = 10000,
		level = 3
	},
	["69696969-9340-46d9-83d6-89d6968ad950"] = {
		upgrade = "69696969-9340-46d9-83d6-89d7c68ad969",
		cost = 20,
		gearCount = 11,
		pointsPerFuel = 13500,
		level = 4
	},
	["69696969-9340-46d9-83d6-89d7c68ad969"] = {
		gearCount = #gears,
		pointsPerFuel = 22500,
		level = 5
	}
}

function WASDengine.server_onCreate(self)
	self:server_init()
end

function WASDengine.server_onRefresh( self )
	self:server_init()
end

function WASDengine.server_init(self)
	local level = EngineLevels[tostring( self.shape:getShapeUuid() )]
	self.pointsPerFuel = level.pointsPerFuel
	local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, 1, 10 )
	end
	container:setFilters( { obj_consumable_gas } )
	
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
		self.saved.onGround = nil
		self.saved.power = 1
		self.saved.upTime = 0
		self.saved.animations = {}
		self.saved.animations.w = false
		self.saved.animations.a = false
		self.saved.animations.s = false
		self.saved.animations.d = false
		self.saved.animations.engine = false
		self.saved.animations.sparks = false
		self.saved.weight = nil
		self.saved.boom = false
		self.saved.fuelPoints = 0
		
		--Settings
		self.saved.ws = true
		self.saved.ad = true
		self.saved.ground = true
		self.saved.gear = 2
	end
	self.hasFuel = false
	
	self.network:setClientData( { gearId = self.saved.gear, ws = self.saved.ws, ad = self.saved.ad, ground = self.saved.ground } )
end

function WASDengine.sv_updateFuelStatus( self, fuelContainer )
	local hasFuel = self.saved.fuelPoints > 0 or sm.container.canSpend( fuelContainer, sm.uuid.new( "d4d68946-aa03-4b8f-b1af-96b81ad4e305" ), 1 )
	if self.hasFuel ~= hasFuel then
		self.hasFuel = hasFuel
	end
end

function WASDengine.client_onCreate( self )
	local level = EngineLevels[tostring( self.shape:getShapeUuid() )]

	self.effect = {}
	self.effect.w = sm.effect.createEffect( "ThrusterW" .. tostring(level.level), self.interactable)
	self.effect.a = sm.effect.createEffect( "ThrusterA" .. tostring(level.level), self.interactable)
	self.effect.s = sm.effect.createEffect( "ThrusterS" .. tostring(level.level), self.interactable)
	self.effect.d = sm.effect.createEffect( "ThrusterD" .. tostring(level.level), self.interactable)
	self.effect.engine = sm.effect.createEffect( "GasEngine - Level " .. tostring(level.level), self.interactable)
	self.effect.sparks = sm.effect.createEffect( "Part - Electricity", self.interactable)
	
	self.client_gearId = 1
	self.client_ws = true
	self.client_ad = true
	self.client_ground = true
	self.gui = nil
end

function WASDengine.server_onFixedUpdate(self)
	local WASDEngineShape = self.shape
	local WASDEngineBody = self.shape:getBody()
	local WASDEngineInteractible = self.interactable
	local GearPower = gears[self.saved.gear].power
	
	-- Check engine connections (copy paste go brrr)
	local hadInput = self.hasInput == nil and true or self.hasInput --Pretend to have had input if nil to avoid starting engines at load
	local active, direction, fuelContainer, hasInput = self:getInputs()
	self.hasInput = hasInput
	local useCreativeFuel = not sm.game.getEnableFuelConsumption() and fuelContainer == nil
	
	-- Check fuel container
	if not fuelContainer or fuelContainer:isEmpty() then
		fuelContainer = self.shape.interactable:getContainer( 0 )
	end
	
	
	--explode engine
	if self.saved.boom then 
		sm.physics.explode( WASDEngineShape.worldPosition, 0, 0, 6, 25, "ThrusterBoom", nil)
		for _, body in ipairs(WASDEngineBody:getCreationBodies()) do
			for _, shape in ipairs(body:getShapes()) do
				shape:destroyShape()
			end
		end
	end
	
	--check if creation has changed
	local changed = false
	for _, body in ipairs(WASDEngineBody:getCreationBodies()) do
		if body:hasChanged(sm.game.getCurrentTick() - 1) then
			changed = true
		end
	end
	
	--Update weight if creation has changed or on creation
	if changed or not self.saved.weight then
		local weight = 0
		for _, body in ipairs(WASDEngineBody:getCreationBodies()) do
			weight = weight + body.mass
		end
		self.saved.weight = weight
	end


	local newAnimations = { w = false, a = false, s = false, d = false, engine = false, sparks = false }

	for _, parent in ipairs(WASDEngineInteractible:getParents()) do
		--don't do shit twice if parent == container
		if parent:getConnectionOutputType() == 14 then
		
		-- Consume fuel for fuel points
		local canSpend = false
		if self.saved.fuelPoints <= 0 then
			canSpend = sm.container.canSpend( fuelContainer, sm.uuid.new( "d4d68946-aa03-4b8f-b1af-96b81ad4e305" ), 1 )
		end
		if canSpend and self.saved.fuelPoints <= 0 then
			sm.container.beginTransaction()
			sm.container.spend( fuelContainer, sm.uuid.new( "d4d68946-aa03-4b8f-b1af-96b81ad4e305" ), 1, true )
			sm.container.endTransaction()
			self.saved.fuelPoints = self.saved.fuelPoints + self.pointsPerFuel
		elseif parent:getSeatCharacter() and self.saved.fuelPoints < 0 then
			self.saved.fuelPoints = 0
			self.network:sendToClient( parent:getSeatCharacter():getPlayer(), "client_msg", "Out of fuel" )
		end
		
		
		--find wheels
		if changed or self.saved.onGround == nil then
			self.saved.onGround  = false
			local hasWheels = false
			for __, child in ipairs(parent:getChildren()) do
				local childUuid = child.shape.shapeUuid
				if childUuid == sm.uuid.new("694324b1-0c50-4b74-bdc7-771374204b1f") or childUuid == sm.uuid.new("694202c3-32aa-4cd1-adc0-dcfc44312c0d") or childUuid == sm.uuid.new("694202c3-32aa-4cd1-adc0-d23147b69420") or childUuid == sm.uuid.new("694200b1-0c50-4b74-bdc7-732174269420") then
					
					if self.wheels == nil then
						self.wheels = {}
					end

					self.wheels[#self.wheels + 1] = child

					if child.shape:getInteractable():getPublicData() ~= nil then
						if child.shape:getInteractable():getPublicData().IsGrounded then
							self.saved.onGround = true
						end
					end

					hasWheels = true
				end
			end
			if self.saved.ground and not self.saved.onGround and not hasWheels and parent:getSeatCharacter() then
				self.network:sendToClient( parent:getSeatCharacter():getPlayer(), "client_msg", "Requires sci-fi wheels in ground mode (connect wheels to seat)" )
			end
		end

		--check if creation is touching the ground
		if self.wheels ~= nil then
			self.saved.onGround = false
			for i = 1, #self.wheels do
				if sm.exists(self.wheels[i])then
					if sm.exists(self.wheels[i].shape) then
						local publicData = self.wheels[i].shape:getInteractable():getPublicData()
						if publicData ~= nil then
							if publicData.IsGrounded then
								self.saved.onGround = true
								break
							end
						end
					end
				end
			end
		end

		if GearPower > 0 and ((not self.saved.ground and parent:getSeatCharacter()) or self.saved.onGround) and self.saved.fuelPoints > 0 or useCreativeFuel then
			--calculate upTime
			if self.saved.power == parent.power then
				self.saved.upTime = math.min(self.saved.upTime + 2, 100)
			elseif parent.power == 0 then
				self.saved.upTime = math.max(self.saved.upTime - 1, 0)
			else
				self.saved.power = parent.power
				self.saved.upTime = 0
			end
			
			
			--basic fuel calculation I guess
			if not useCreativeFuel then
				local appliedImpulseCost = 0.35
				local fuelCost = 0
				
				if self.saved.ws and parent:getPower() ~= 0 then
					fuelCost = appliedImpulseCost*GearPower*0.9
				end
				
				if self.saved.ad and parent:getSteeringAngle() ~= 0 then
					fuelCost = fuelCost + (self.saved.weight^0.8)/10000 * appliedImpulseCost *GearPower*0.9
				end

				self.saved.fuelPoints = self.saved.fuelPoints - fuelCost
				print(self.saved.fuelPoints)
				
				fuelCost = math.min( fuelCost, math.sqrt( fuelCost / 7 ) * 7 )
				--print(fuelCost)
				
				if self.saved.fuelPoints <= 0 and fuelCost > 0 then
					sm.container.beginTransaction()
					sm.container.spend( fuelContainer, sm.uuid.new( "d4d68946-aa03-4b8f-b1af-96b81ad4e305" ), 1, true )
					if sm.container.endTransaction() then
						self.saved.fuelPoints = self.saved.fuelPoints + self.pointsPerFuel
					end
				end
			end
			
			
			--add impulse
			if self.saved.ws then
				sm.physics.applyImpulse(WASDEngineBody, WASDEngineShape.up * parent:getPower() * GearPower  * self.saved.upTime * 0.5, 1)
			end
			
			local bodies = WASDEngineBody:getCreationBodies()
			local Sidevelocity = WASDEngineBody:getVelocity():dot(WASDEngineShape.right)
			
			for i = 1, #bodies, 1 do
				local body = bodies[i]
				local force = Sidevelocity * (body:getMass() / self.saved.weight)
				if Sidevelocity > 0 then
					sm.physics.applyImpulse(body, (WASDEngineShape.right + (WASDEngineShape.up * -0.5)) * force  * -100, 1)
				else
					sm.physics.applyImpulse(body, (WASDEngineShape.right + (WASDEngineShape.up * 0.5)) * force  * -100, 1)
				end
			end

			if Sidevelocity > 0 then
				sm.physics.applyImpulse(WASDEngineBody, (WASDEngineShape.right + (WASDEngineShape.up * -0.01)) * Sidevelocity  * -100, 1)
			else
				sm.physics.applyImpulse(WASDEngineBody, (WASDEngineShape.right + (WASDEngineShape.up * 0.01)) * Sidevelocity  * -100, 1)
			end
			
			
			--add turning torque
			local torque = WASDEngineShape.at * self.saved.weight/3 * parent:getSteeringAngle() * -0.01 * (10 - math.abs(WASDEngineBody:getAngularVelocity():dot(WASDEngineShape.at))) * math.pow(GearPower, 0.5)

			if self.saved.ad and math.abs(parent:getSteeringAngle()) > 0.5 then
				sm.physics.applyTorque( WASDEngineBody, torque, 1)
			end
			
			
			--stop spin if player is not turning
			local angularVelocity = WASDEngineBody:getAngularVelocity():dot(WASDEngineShape.at)

			if parent:getSteeringAngle() == 0 and math.abs(angularVelocity) > 0.01 and self.saved.ad then
				local steerAdjust = WASDEngineShape.at * angularVelocity * self.saved.weight * -0.2
				sm.physics.applyTorque( WASDEngineBody, steerAdjust, 1)
			end
			

			--explode engine if going too fast
			if WASDEngineBody:getVelocity():length() > 500 then
				self.network:sendToClient( parent:getSeatCharacter():getPlayer(), "client_msg", "#ff0000Too fast! Engine exploded!" )
				self.saved.boom = true
			end
			if WASDEngineBody:getAngularVelocity():length() > 50 then
				self.saved.boom = true
				self.network:sendToClient( parent:getSeatCharacter():getPlayer(), "client_msg", "#ff0000Too fast! Engine exploded!" )
			end
			
			--animations aka particles and sound (naming skills go brrrr)
			if parent.power == 1 and self.saved.ws then
				newAnimations.w = true
				newAnimations.s = false
			elseif parent.power == 0 or not self.saved.ws then
				newAnimations.w = false
				newAnimations.s = false
			else
				newAnimations.w = false
				newAnimations.s = true
			end
			
			if parent:getSteeringAngle() == 1 and self.saved.ad then
				newAnimations.a = true
				newAnimations.d = false
			elseif parent:getSteeringAngle() == 0 or not self.saved.ad then
				newAnimations.a = false
				newAnimations.d = false
			else
				newAnimations.a = false
				newAnimations.d = true
			end
			
			if WASDEngineBody:getAngularVelocity():length() > 10 then
				newAnimations.sparks = true
			elseif WASDEngineBody:getVelocity():length() > 100 then
				newAnimations.sparks = true
			end
				
		else
			self.saved.upTime = math.max(self.saved.upTime - 1, 0)
		end
		
		if parent:getSeatCharacter() and GearPower > 0 then
			newAnimations.engine = true
		else
			newAnimations.engine = false
		end
	end--double parent fix
	end
	
	--disconnect more than 1 seat or fuel container
	local seat = false
	for k,parent in ipairs(self.interactable:getParents()) do
		if parent:getConnectionOutputType() == 14 then
			if not seat then
				seat = true
			else
				sm.interactable.disconnect(parent, self.interactable)
			end
		elseif not seat and k == 2 then
			sm.interactable.disconnect(parent, self.interactable)
		end
	end
	
	--UpdateAnimation
	if newAnimations.w ~= self.saved.animations.w or newAnimations.a ~= self.saved.animations.a or newAnimations.s ~= self.saved.animations.s or newAnimations.d ~= self.saved.animations.d or newAnimations.engine ~= self.saved.animations.engine then
		self.network:sendToClients( "client_updateAnimation", newAnimations )
	end
	self.saved.animations = newAnimations
	
	self.storage:save( self.saved )
end

function WASDengine.sv_n_tryUpgrade( self, player )
	local level = EngineLevels[tostring( self.shape:getShapeUuid() )]
	local function fnUpgrade()
		local nextLevel = EngineLevels[level.upgrade]
		assert( nextLevel )
		self.network:sendToClients( "cl_n_onUpgrade", level.upgrade )

		if nextLevel.fn then
			nextLevel.fn( self )
		end
		self.shape:replaceShape( sm.uuid.new( level.upgrade ) )
	end

	if not sm.game.getEnableUpgradeCost() then
		fnUpgrade()
	else
		local inventory = player:getInventory()
		if sm.container.totalQuantity( inventory, sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ) ) >= level.cost then
			if sm.container.beginTransaction() then
				sm.container.spend( inventory, sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ), level.cost, true )
				if sm.container.endTransaction() then
					fnUpgrade()
				end
			end
		end
	end
end

function WASDengine.client_onFixedUpdate(self)
	self.effect.engine:setParameter("rpm", self.interactable:getBody():getVelocity():length()*0.01)

	local active, direction, externalFuelTank, hasInput = self:getInputs()
	if self.gui then
		self.gui:setVisible( "FuelContainer", externalFuelTank ~= nil )
	end
end

function WASDengine.client_updateAnimation(self, params)
	if params.w then
		if not self.effect.w:isPlaying() then
			self.effect.w:start()
		end
	else
		self.effect.w:stop()
	end
	if params.a then
		if not self.effect.a:isPlaying() then
			self.effect.a:start()
		end
	else
		self.effect.a:stop()
	end
	if params.s then
		if not self.effect.s:isPlaying() then
			self.effect.s:start()
		end
	else
		self.effect.s:stop()
	end
	if params.d then
		if not self.effect.d:isPlaying() then
			self.effect.d:start()
		end
	else
		self.effect.d:stop()
	end
	if params.engine then
		if not self.effect.engine:isPlaying() then
			self.effect.engine:start()
		end
	else
		self.effect.engine:stop()
	end
	if not self.effect.sparks:isPlaying() and params.sparks then
		self.effect.sparks:start()
	end
end

function WASDengine.client_msg(self, msg)
	sm.gui.displayAlertText(msg)
end

function WASDengine.getInputs( self )
	local parents = self.interactable:getParents()
	local active = true
	local direction = 1
	local fuelContainer = nil
	local hasInput = false
	if parents[2] then
		if parents[2]:hasOutputType( sm.interactable.connectionType.power ) then
			active = parents[2]:isActive()
			direction = parents[2]:getPower()
			hasInput = true
		end
		if parents[2]:hasOutputType( sm.interactable.connectionType.gasoline ) then
			fuelContainer = parents[2]:getContainer( 0 )
		end
	end
	if parents[1] then
		if parents[1]:hasOutputType( sm.interactable.connectionType.power ) then
			active = parents[1]:isActive()
			direction = parents[1]:getPower()
			hasInput = true
		end
		if parents[1]:hasOutputType( sm.interactable.connectionType.gasoline ) then
			fuelContainer = parents[1]:getContainer( 0 )
		end
	end

	return active, direction, fuelContainer, hasInput
end

function WASDengine.cl_n_onUpgrade( self, upgrade )
	local level = EngineLevels[upgrade]

	if self.gui and self.gui:isActive() then
		self.gui:setSliderRangeLimit( "Setting", level.gearCount )
		self.gui:setIconImage( "Icon", sm.uuid.new(upgrade) )
		self.gui:setText( "SubTitle", "LEVEL " .. tostring(level.level) )
	
		if level.upgrade then
			self.gui:setData( "UpgradeInfo", { Gears = 2, Efficiency = 1 } )
			if level.level == 4 then
				self.gui:setText( "UpgradeInfo", "#9f9e9eEfficiency #c4f42b+1\n#9f9e9eGears #c4f42b+2\n+Advanced Settings" )
			end
			self.gui:setIconImage( "UpgradeIcon", sm.uuid.new( level.upgrade ) )
		else
			self.gui:setText( "UpgradeInfo", "Press #c4f42bUPGRADE#ffffff for advanced settings" )
		end

		if level.cost then
			if not sm.game.getEnableUpgradeCost() then
				self.gui:setData( "Upgrade", { cost = level.cost, available = 1000 } )
			else
				local inventory = sm.localPlayer.getPlayer():getInventory()
				local availableKits = sm.container.totalQuantity( inventory, sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ) )
				local upgradeData = { cost = level.cost, available = availableKits }
				self.gui:setData( "Upgrade", upgradeData )
			end
		else
			local upgradeData = { cost = 0, available = 69420 }
			self.gui:setData( "Upgrade", upgradeData )
			self.gui:setVisible( "Upgrade", true )
		end
	self.gui:open()
	end

	self.effect.w = sm.effect.createEffect( "ThrusterW" .. tostring(level.level), self.interactable)
	self.effect.a = sm.effect.createEffect( "ThrusterA" .. tostring(level.level), self.interactable)
	self.effect.s = sm.effect.createEffect( "ThrusterS" .. tostring(level.level), self.interactable)
	self.effect.d = sm.effect.createEffect( "ThrusterD" .. tostring(level.level), self.interactable)
	self.effect.engine = sm.effect.createEffect( "GasEngine - Level " .. tostring(level.level), self.interactable)
	sm.effect.playHostedEffect( "Part - Upgrade", self.interactable )
end


---GUI STUFF START
function WASDengine.client_onInteract(self, character, state)
	if state then
		self:client_initializeGUI()
	end
end

function WASDengine.client_initializeGUI(self)	
	local level = EngineLevels[tostring( self.shape:getShapeUuid() )]
	self.gui = sm.gui.createEngineGui()

	self.gui:setText( "Name", "WASD ENGINE" )
	self.gui:setText( "Interaction", "#{CONTROLLER_ENGINE_INSTRUCTION}" )
	self.gui:setOnCloseCallback( "cl_onGuiClosed" )
	self.gui:setSliderCallback( "Setting", "cl_onSliderChange" )
	self.gui:setSliderData( "Setting", 13, self.client_gearId - 1 )
	self.gui:setSliderRangeLimit( "Setting", level.gearCount )
	self.gui:setIconImage( "Icon", self.shape:getShapeUuid() )
	self.gui:setButtonCallback( "Upgrade", "cl_onUpgradeClicked" )
	self.gui:setText( "SubTitle", "LEVEL " .. tostring(level.level) )
	self.gui:setText( "Interaction", "#ff0000WARNING!#ffffff High velocity can cause a\nfusion-based reactor backfeed reaction. BOOM!" )

	local fuelContainer = self.shape.interactable:getContainer( 0 )

	if not sm.game.getEnableFuelConsumption() then
		self.gui:setVisible( "BackgroundGas", false )
		self.gui:setVisible( "FuelGrid", false )
	end

	if fuelContainer and sm.game.getEnableFuelConsumption() then
		self.gui:setContainer( "Fuel", fuelContainer )
	end
	
	if level.upgrade then
		local nextLevel = EngineLevels[ level.upgrade ]
		self.gui:setData( "UpgradeInfo", { Gears = nextLevel.gearCount - level.gearCount, Efficiency = 1 } )
		if level.level == 4 then
			self.gui:setText( "UpgradeInfo", "#9f9e9eEfficiency #c4f42b+1\n#9f9e9eGears #c4f42b+2\n+Advanced Settings" )
		end
		self.gui:setIconImage( "UpgradeIcon", sm.uuid.new( level.upgrade ) )
	else
		--self.gui:setImage( "UpgradeIcon", "$CONTENT_3f7f4e0f-dc99-43a9-9a15-f7ccbaf7dd65/Gui/Images/panel.png" )
		self.gui:setIconImage( "UpgradeIcon", sm.uuid.new( tostring(self.shape.shapeUuid) ) )
		self.gui:setText( "UpgradeInfo", "Press #c4f42bUPGRADE#ffffff for advanced settings" )
	end

	if level.cost then
		if not sm.game.getEnableUpgradeCost() then
			self.gui:setData( "Upgrade", { cost = level.cost, available = 1000 } )
		else
			local inventory = sm.localPlayer.getPlayer():getInventory()
			local availableKits = sm.container.totalQuantity( inventory, sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ) )
			local upgradeData = { cost = level.cost, available = availableKits }
			self.gui:setData( "Upgrade", upgradeData )
		end
	else
		local upgradeData = { cost = 0, available = 69420 }
		self.gui:setData( "Upgrade", upgradeData )
		self.gui:setVisible( "Upgrade", true )
	end

	self.gui:open()
end

function WASDengine.cl_onGuiClosed( self )
	if self.gui then
		--self.gui = nil
	end
end

function WASDengine.cl_onSliderChange( self, sliderName, sliderPos )
	self.client_gearId = sliderPos + 1
	self.network:sendToServer( "sv_setGear", sliderPos + 1 )
end

function WASDengine.sv_setGear( self, gearId )
	self.saved.gear = gearId
	self.storage:save( self.saved )
	self.network:setClientData( { gearId = gearId, ws = self.saved.ws, ad = self.saved.ad, ground = self.saved.ground } )
end

function WASDengine.client_onClientDataUpdate( self, params )

	if self.gui then
		if self.gui:isActive() and params.gearId ~= self.client_gearId then
			self.gui:setSliderPosition("Setting", params.gearId)
		end
	end
	
	self.client_ws = params.ws
	self.client_ad = params.ad
	self.client_ground = params.ground
	self.client_gearId = params.gearId
end

function WASDengine.cl_onUpgradeClicked( self, buttonName )
	local level = EngineLevels[tostring( self.shape:getShapeUuid() )]
	if level.level < 5 then
		self.network:sendToServer("sv_n_tryUpgrade", sm.localPlayer.getPlayer() )
	else
		self.gui:close()

		self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/WASDEngineGUI.layout")
	
		self.gui:setText( "Grounded Button", self.client_ground and "ON" or "OFF" )
		self.gui:setButtonCallback( "Grounded Button", "cl_onGroundedButtonClicked" )
	
		self.gui:setText( "CurMode", (self.client_ws and "W" or "") .. (self.client_ad and "A" or "") .. (self.client_ws and "S" or "") .. (self.client_ad and "D" or ""))
		self.gui:setButtonCallback( "NextMode", "cl_onNextClicked" )
		self.gui:setButtonCallback( "PrevMode", "cl_onPrevClicked" )


		self.gui:setButtonCallback( "BackButton", "cl_onBackButtonClicked" )
	
		self.gui:open()
	end
end

--WASD WS AD
function WASDengine.cl_onPrevClicked( self, buttonName )
	
	if self.client_ws and self.client_ad then
		self.client_ws = false
	elseif self.client_ws then
		self.client_ad = true
	else
		self.client_ws = true
		self.client_ad = false
	end
	
	self.gui:setText( "CurMode", (self.client_ws and "W" or "") .. (self.client_ad and "A" or "") .. (self.client_ws and "S" or "") .. (self.client_ad and "D" or ""))
	self.network:sendToServer( "sv_setMode", {ws = self.client_ws, ad = self.client_ad} )
end

function WASDengine.cl_onNextClicked( self, buttonName )
	
	if self.client_ws and self.client_ad then
		self.client_ad = false
	elseif self.client_ws then
		self.client_ws = false
		self.client_ad = true
	else
		self.client_ws = true
	end
	
	self.gui:setText( "CurMode", (self.client_ws and "W" or "") .. (self.client_ad and "A" or "") .. (self.client_ws and "S" or "") .. (self.client_ad and "D" or ""))
	self.network:sendToServer( "sv_setMode", {ws = self.client_ws, ad = self.client_ad} )
end

function WASDengine.sv_setMode( self, params )
	self.saved.ws = params.ws
	self.saved.ad = params.ad
	self.storage:save( self.saved )
	self.network:setClientData( { gearId = self.saved.gear, ws = self.saved.ws, ad = self.saved.ad, ground = self.saved.ground } )
end


function WASDengine.cl_onGroundedButtonClicked( self, buttonName )
	self.client_ground = not self.client_ground
	self.gui:setText( "Grounded Button", self.client_ground and "ON" or "OFF" )
	self.network:sendToServer( "sv_setGrounded", self.client_ground )
end

function WASDengine.sv_setGrounded( self, ground )
	self.saved.ground = ground
	self.storage:save( self.saved )
	self.network:setClientData( { gearId = self.saved.gear, ws = self.saved.ws, ad = self.saved.ad, ground = self.saved.ground } )
end

function WASDengine.cl_onBackButtonClicked( self, buttonName )
	self.gui:close()
	self:client_initializeGUI()
end