dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

Trader = class()

local OpenShutterDistance = 7.0
local CloseShutterDistance = 9.0

function Trader.server_onCreate(self)
end


function Trader.client_onCreate( self )
	self:cl_init()
end

function Trader.cl_init(self)
	if self.cl == nil then
		self.cl = {}
		self.cl.onlyExistsBecauseTheDevsCantFixTheirFuckingBrokenCode = { tick = 0, player = sm.localPlayer.getPlayer()}
	end
	self.cl.guiInterface = sm.gui.createHideoutGui()
	self.cl.guiInterface:setGridButtonCallback( "Trade", "cl_onCompleteQuest" )
	self.cl.guiInterface:setOnCloseCallback( "cl_onClose" )
	self:cl_updateTradeGrid()
	
	--Setup animations
	self.cl.animationEffects = {}
	local animations = {}
	if self.data then
		if self.data.animationList then
			for i, animation in ipairs( self.data.animationList ) do
				local duration = self.interactable:getAnimDuration( animation.name )
				animations[animation.name] = self:cl_createAnimation( animation.name, duration, animation.nextAnimation, animation.looping, animation.playForward )
				if animation.effect then
					self.cl.animationEffects[animation.name] = sm.effect.createEffect( animation.effect.name, self.interactable, animation.effect.joint )
				end
			end
		end
	end
	self.cl.animations = animations
	self:cl_setAnimation( self.cl.animations["Close"], 1.0 )
end

function Trader.cl_updateTradeGrid( self )
	self.cl.guiInterface:clearGrid( "TradeGrid" )
	self.cl.guiInterface:addGridItemsFromFile( "TradeGrid", "$CONTENT_3f7f4e0f-dc99-43a9-9a15-f7ccbaf7dd65/Scripts/market.json" )
end

function Trader.client_onInteract( self, character, state )
	if state == true then
		if self.cl.user == nil then
			character:setLockingInteractable( self.interactable )
			self.cl.user = character:getPlayer()
			--self.cl.guiInterface:setContainer("Hideout", self.interactable:getContainer() )
			self.cl.guiInterface:setContainer("Inventory", character:getPlayer():getInventory() )
			self.cl.guiInterface:open()
		end
	end
end

function Trader.cl_onCompleteQuest( self, buttonName, index, data )

	self.network:sendToServer( "sv_tryCompleteQuest", data )
end

function Trader.sv_tryCompleteQuest( self, params, player )

	sm.container.beginTransaction()

	-- Collect
	for i, collect in ipairs( params.ingredientList ) do
		local itemUid = sm.uuid.new( collect.itemId )
		local container = player:getInventory()
		sm.container.spend( container, itemUid, collect.quantity, true )
	end

	-- Reward
	--[[for i, reward in ipairs( params.rewardList ) do

		local itemUid = sm.uuid.new( reward.itemId )
		sm.container.collect( inventory, itemUid, reward.quantity, true )
	end]]--

	local inventory = player:getInventory()
	sm.container.collect( inventory, sm.uuid.new( params.itemId ), params.quantity, true )

	if not sm.container.endTransaction() then
		--The player failed the trade transaction, abort
		self.network:sendToClient(player, "client_msg", {msg = "#ff0000Trade failed", sound = "RaftShark"})
		return
	end
	self.network:sendToClient(player, "client_msg", {sound = "Button on"})

	self.network:sendToClients( "cl_questCompleted", player )
end

function Trader.cl_questCompleted( self, player )
	if sm.localPlayer.getPlayer() == player then
		-- Update the quest gui
		self.cl.guiInterface:close()
		self.cl.guiInterface:open()
		self.cl.onlyExistsBecauseTheDevsCantFixTheirFuckingBrokenCode = { tick = sm.game.getCurrentTick(), player = self.cl.user}
	end
	self.cl.playCompletedAnimation = true
end

function Trader.client_onFixedUpdate( self )
	if self.cl.onlyExistsBecauseTheDevsCantFixTheirFuckingBrokenCode.tick ~= 0 and self.cl.onlyExistsBecauseTheDevsCantFixTheirFuckingBrokenCode.tick < sm.game.getCurrentTick() then
		self.cl.user = self.cl.onlyExistsBecauseTheDevsCantFixTheirFuckingBrokenCode.player
		self.cl.onlyExistsBecauseTheDevsCantFixTheirFuckingBrokenCode.tick = 0
	end
end

function Trader.cl_IOnlyExistBecauseTheDevsHaveFuckingBrokenCode( self, params )
	self.cl.user = params
end

function Trader.client_msg(self, params)
	if params.msg then
		sm.gui.displayAlertText(params.msg)
	end
	if params.effect then
		sm.effect.playEffect(params.effect, self.shape.worldPosition)
	end
	if params.sound then
		sm.audio.play(params.sound, self.shape.worldPosition)
	end
end

function Trader.client_onDestroy(self)
	-- Destroy animation effects
	for name, effect in pairs( self.cl.animationEffects ) do
		effect:stop()
	end
end

function Trader.cl_onClose( self, params )
	if self.cl.user then
		self.cl.user.character:setLockingInteractable( nil )
		self.cl.user = nil
		sm.camera.setCameraState( sm.camera.state.default )
	end
end

function Trader.client_onRefresh( self )
	if self.cl then
		if self.cl.user then
			self.cl.user.character:setLockingInteractable( nil )
			self.cl.user = nil
			sm.camera.setCameraState( sm.camera.state.default )
			self.cl.guiInterface:close()
		end
	end
	self:cl_init()
end

--Animations and shit

function Trader.cl_createAnimation( self, name, playTime, nextAnimation, looping, playForward )
	local animation =
	{
		-- Required
		name = name,
		playProgress = 0.0,
		playTime = playTime,
		isActive = false,
		-- Optional
		looping = looping,
		playForward = ( playForward or playForward == nil ),
		nextAnimation = nextAnimation
	}
	return animation
end

function Trader.cl_setAnimation( self, animation, playProgress )
	self:cl_unsetAnimation()
	animation.isActive = true
	animation.playProgress = playProgress
	self.interactable:setAnimEnabled(animation.name, true)
	local effect = self.cl.animationEffects[animation.name]
	if playProgress == 0.0 and effect then
		effect:start()
	end
end

function Trader.cl_unsetAnimation( self )
	for name, animation in pairs( self.cl.animations ) do
		animation.isActive = false
		animation.playProgress = 0.0
		self.interactable:setAnimEnabled( animation.name, false )
		self.interactable:setAnimProgress( animation.name, animation.playProgress )
	end
end

function Trader.cl_updateAnimation( self, dt )

	for name, animation in pairs( self.cl.animations ) do
		if animation.isActive then
			self.interactable:setAnimEnabled(animation.name, true)
			if animation.playForward then
				animation.playProgress = animation.playProgress + dt / animation.playTime
				if animation.playProgress > 1.0 then
					if animation.looping then
						animation.playProgress = animation.playProgress - 1.0
					else
						if animation.nextAnimation then
							self:cl_setAnimation( self.cl.animations[animation.nextAnimation], 0.0)
							return
						else
							animation.playProgress = 1.0
						end
					end
				end
				self.interactable:setAnimProgress(animation.name, animation.playProgress )
			else
				animation.playProgress = animation.playProgress - dt / animation.playTime
				if animation.playProgress < -1.0 then
					if animation.looping then
						animation.playProgress = animation.playProgress + 1.0
					else
						if animation.nextAnimation then
							self:cl_setAnimation( self.cl.animations[animation.nextAnimation], 0.0)
							return
						else
							animation.playProgress = -1.0
						end
					end
				end
				self.interactable:setAnimProgress(animation.name, 1.0 + animation.playProgress )
			end
		end
	end

end

function Trader.client_onUpdate( self, dt )

	self:cl_selectAnimation()
	self:cl_updateAnimation( dt )

	if self.cl.user == sm.localPlayer.getPlayer() then
		
		local cameraDesiredDirection = sm.camera.getDirection()
		local cameraDesiredPosition = sm.camera.getPosition()

		if true then
			cameraDesiredDirection = sm.quat.lookRotation( self.shape.right, -self.shape.up + self.shape.at )*sm.vec3.new( 0, 1, 0 )--self.cl.cameraNode.rotation * sm.vec3.new( 0, 1, 0 )
			cameraDesiredPosition = self.shape.worldPosition + self.shape.at*-0.5 + self.shape.up*2 --self.cl.cameraNode.position
		end

		local cameraPosition = magicPositionInterpolation( sm.camera.getPosition(), cameraDesiredPosition, dt, 1.0 / 10.0 )
		local cameraDirection = magicDirectionInterpolation( sm.camera.getDirection(), cameraDesiredDirection, dt, 1.0 / 10.0 )

		-- Finalize
		sm.camera.setCameraState( sm.camera.state.cutsceneTP )
		sm.camera.setPosition( cameraPosition )
		sm.camera.setDirection( cameraDirection )
	end
end

function Trader.cl_selectAnimation( self )

	if self.cl.animations["Close"].isActive and self.cl.animations["Close"].playProgress >= 1.0 then
		if GetClosestPlayer( self.shape.worldPosition, OpenShutterDistance, self.shape.body:getWorld() ) ~= nil then
			self:cl_setAnimation( self.cl.animations["Open"], 0.0 )
		end
	end

	if self.cl.animations["Idle"].isActive then
		if self.cl.playCompletedAnimation then
			local randIndex = math.random( 1, 3)
			if randIndex == 1 then
				self:cl_setAnimation( self.cl.animations["Confirm01"], 0.0 )
			elseif randIndex == 2 then
				self:cl_setAnimation( self.cl.animations["Confirm02"], 0.0 )
			elseif randIndex == 3 then
				self:cl_setAnimation( self.cl.animations["Confirm03"], 0.0 )
			end
		else
			if GetClosestPlayer( self.shape.worldPosition, CloseShutterDistance, self.shape.body:getWorld() ) == nil then
				self:cl_setAnimation( self.cl.animations["Close"], 0.0 )
			end
		end
	end
	self.cl.playCompletedAnimation = false

end