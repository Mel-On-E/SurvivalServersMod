GrowingTree = class()

function GrowingTree.server_onCreate(self)
	self.growTick = sm.game.getCurrentTick() + math.random(2400,144000) --Debug
	self:server_init()
end

function GrowingTree.server_onFixedUpdate(self)
	if self.growTick < sm.game.getCurrentTick() then
		sm.harvestable.create( self.tree, self.shape.worldPosition - sm.vec3.new(0,0,0.5), self.shape.worldRotation )
		self.shape:destroyPart(0)
	end
end

BirchGrowingTree = class( GrowingTree )
function BirchGrowingTree.server_init(self)
	local i = math.random(1,3)
	if i == 1 then
		self.tree = sm.uuid.new("c4ea19d3-2469-4059-9f13-3ddb4f7e0b79")
	elseif i == 2 then
		self.tree = sm.uuid.new("711c3e72-7ba1-4424-ae70-c13d23afe818")
	elseif i == 3 then
		self.tree = sm.uuid.new("a7aa52af-4276-4b2d-af44-36bc41864e04")
	end
end

LeafyGrowingTree = class( GrowingTree )
function LeafyGrowingTree.server_init(self)
	local i = math.random(1,3)
	if i == 1 then
		self.tree = sm.uuid.new("91ec04ea-9bf7-4a9d-bb7f-3d0125ff78c7")
	elseif i == 2 then
		self.tree = sm.uuid.new("4d482999-98b7-4023-a149-d47be709b8f7")
	elseif i == 3 then
		self.tree = sm.uuid.new("3db0a60d-8668-4c8a-8dd2-f5ceb294977e")
	end
end

SpruceGrowingTree = class( GrowingTree )
function SpruceGrowingTree.server_init(self)
	local i = math.random(1,3)
	if i == 1 then
		self.tree = sm.uuid.new("73f968f0-d3a3-4334-86a8-a90203a3a56d")
	elseif i == 2 then
		self.tree = sm.uuid.new("86324c5b-e97a-41f6-aa2c-7c6462f1f2e7")
	elseif i == 3 then
		self.tree = sm.uuid.new("27aa53ea-1e09-4251-a284-437f93850409")
	end
end

PineGrowingTree = class( GrowingTree )
function PineGrowingTree.server_init(self)
	local i = math.random(1,3)
	if i == 1 then
		self.tree = sm.uuid.new("8411caba-63db-4b93-ad67-7ae8e350d360")
	elseif i == 2 then
		self.tree = sm.uuid.new("1cb503a4-9306-412f-9e13-371bc634af60")
	elseif i == 3 then
		self.tree = sm.uuid.new("fa864e51-67db-4ac9-823b-cfbdf523375d")
	end
end

EmberGrowingTree = class( GrowingTree )
function EmberGrowingTree.server_init(self)
	local i = math.random(1,8)
	if i == 1 then
		self.tree = sm.uuid.new("9ef210c0-ea30-4442-a1fe-924b5609b0cc")
	elseif i == 2 then
		self.tree = sm.uuid.new("2bae67d4-c8ef-4c6e-a1a7-42281d0b7489")
	elseif i == 3 then
		self.tree = sm.uuid.new("8f7a8108-2712-47b3-bce2-f25315165094")
	elseif i == 4 then
		self.tree = sm.uuid.new("515aed88-0594-42b6-a352-617e5f5a3e45")
	elseif i == 5 then
		self.tree = sm.uuid.new("2d5aa53d-eb9c-478c-a70f-c57a43753814")
	elseif i == 6 then
		self.tree = sm.uuid.new("c08b553a-a917-4e26-bbb6-7b8523789cad")
	elseif i == 7 then
		self.tree = sm.uuid.new("d3fcfc06-a6b6-4598-99b1-9a6445b976b3")
	elseif i == 8 then
		self.tree = sm.uuid.new("b5f90719-fbca-4c59-89c3-187cdb5553d4")
	end
end