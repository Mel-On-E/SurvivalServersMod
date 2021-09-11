dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

Sapling = class()

function Sapling.server_onCreate(self)
	self.valid = false
	local success, result = sm.physics.raycast( self.shape.worldPosition + sm.vec3.new(0,0,0.125), self.shape.worldPosition + sm.vec3.new(0,0,-0.3) )
	if success and result.type == "terrainSurface" then
		self.valid = true
	end
	if self.shape.at.z ~= 1 then
		self.valid = false
	end
	self.network:setClientData( { valid = self.valid } )
	self:server_init()
end

function Sapling.client_onClientDataUpdate( self, params )
	self.valid = params.valid
end

function Sapling.client_canInteract(self)
	if self.valid then
		sm.gui.setInteractionText("Splash with", "Water")
	else
		sm.gui.setInteractionText("Place on", "#ff0000TerrainSurface")
	end
	return true
end

function Sapling.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if self.valid and projectileName == "water" then
		--local lootList = {}
		--lootList[1] = { uuid = sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), quantity = 1 }
		--SpawnLoot( self.shape, lootList, self.shape.worldPosition + sm.vec3.new( 0, 0, 1.0 ) )
		
		if math.random(0,1) == 1 then
			sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
			if math.random(0,1) == 1 then
				sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
				if math.random(0,1) == 1 then
					sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
					if math.random(0,1) == 1 then
						sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
						if math.random(0,1) == 1 then
							sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
						end
					end
				end
			end
		end
		
		
		local offset = self.shape.xAxis*0.375
		if offset.x == 0 then
			offset.x = offset.y
		end
		if offset.y == 0 then
			offset.y = -offset.x
		end
		sm.shape.createPart(self.tree, self.shape.worldPosition - sm.vec3.new( 0, 0, 0.25 ) - offset, self.shape.worldRotation, false, true)
		self.valid = false
		self.shape:destroyPart(0)
	end
end

BirchSapling = class( Sapling )
function BirchSapling.server_init(self)
	self.tree = sm.uuid.new("111b101c-508b-4630-9f9d-47ef1c834183")
end

LeafySapling = class( Sapling )
function LeafySapling.server_init(self)
	self.tree = sm.uuid.new("222b101c-508b-4630-9f9d-47ef1c834183")
end

SpruceSapling = class( Sapling )
function SpruceSapling.server_init(self)
	self.tree = sm.uuid.new("333b101c-508b-4630-9f9d-47ef1c834183")
end

PineSapling = class( Sapling )
function PineSapling.server_init(self)
	self.tree = sm.uuid.new("444b101c-508b-4630-9f9d-47ef1c834183")
end

EmberSapling = class( Sapling )
function EmberSapling.server_init(self)
	self.tree = sm.uuid.new("555b101c-508b-4630-9f9d-47ef1c834183")
end

function EmberSapling.client_canInteract(self)
	if self.valid then
		sm.gui.setInteractionText("Splash with", "Chemical")
	else
		sm.gui.setInteractionText("Place on", "#ff0000TerrainSurface")
	end
	return true
end

function EmberSapling.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if self.valid and projectileName == "chemical" then
		--local lootList = {}
		--lootList[1] = { uuid = sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), quantity = 1 }
		--SpawnLoot( self.shape, lootList, self.shape.worldPosition + sm.vec3.new( 0, 0, 1.0 ) )
		
		if math.random(0,1) == 1 then
			sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
			if math.random(0,1) == 1 then
				sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
				if math.random(0,1) == 1 then
					sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
					if math.random(0,1) == 1 then
						sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
						if math.random(0,1) == 1 then
							sm.shape.createPart(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), self.shape.worldPosition + sm.vec3.new( 0, 0, 1 ))
						end
					end
				end
			end
		end
		
		
		local offset = self.shape.xAxis*0.375
		if offset.x == 0 then
			offset.x = offset.y
		end
		if offset.y == 0 then
			offset.y = -offset.x
		end
		sm.shape.createPart(self.tree, self.shape.worldPosition - sm.vec3.new( 0, 0, 0.25 ) - offset, self.shape.worldRotation, false, true)
		self.valid = false
		self.shape:destroyPart(0)
	end
end

StoneSapling = class( Sapling )
function StoneSapling.server_onCreate(self)
	self.valid = false
	local success, result = sm.physics.raycast( self.shape.worldPosition + sm.vec3.new(0,0,0.375), self.shape.worldPosition + sm.vec3.new(0,0,-0.8) )
	if success and result.type == "terrainSurface" then
		self.valid = true
	end
	if self.shape.at.z ~= 1 then
		self.valid = false
	end
	self.network:setClientData( { valid = self.valid } )
	self:server_init()
end

function StoneSapling.server_init(self)
	local i = math.random(1,3)
	if i == 1 then
		self.tree = sm.uuid.new( "0d3362ae-4cb3-42ae-8a08-d3f9ed79e274" )
	elseif i == 2 then
		self.tree = sm.uuid.new( "f6b8e9b8-5592-46b6-acf9-86123bf630a9" )
	elseif i == 3 then
		self.tree = sm.uuid.new( "60ad4b7f-a7ef-4944-8a87-0844e6305513" )
	end
	self.growTick = sm.game.getCurrentTick() + math.random(24,1440)
end

function StoneSapling.client_canInteract(self)
	if self.valid then
		sm.gui.setInteractionText("Drilling...")
	else
		sm.gui.setInteractionText("Place on", "#ff0000TerrainSurface")
	end
	return true
end

function StoneSapling.server_onFixedUpdate(self)
	if self.growTick < sm.game.getCurrentTick() then
		sm.harvestable.create( self.tree, self.shape.worldPosition + sm.vec3.new(0,0,1), self.shape.worldRotation )
		self.shape:destroyPart(0)
	end
end

function StoneSapling.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	return
end

--birch, leafy, spruce, pine