GrowingTree = class()

function GrowingTree.server_onCreate(self)
	self.growTick = sm.game.getCurrentTick() + math.random(2400,144000)
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