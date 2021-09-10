--[[
	Copyright (c) 2021 Questionable Mark
	*Modifed by Dr Pixel Plays
]]

--if CreationProtector then return end

dofile ("PlayerManager.lua")
dofile( "./SmKeyboardMaster/Scripts/Keyboard.lua" )

CreationProtector = class()
CreationProtector.poseWeightCount = 1
CreationProtector.maxParentCount = 255
CreationProtector.connectionInput = sm.interactable.connectionType.electricity
CreationProtector.colorNormal = sm.color.new( 0x32CC32ff )
CreationProtector.colorHighlight = sm.color.new( 0x52EE52ff )

CreationProtector.Ranges = {10,20,30,40,50}

local verified_shapes = {}

function CreationProtector:server_onCreate()
	self.creation_time = sm.game.getCurrentTick()

	local block_data = self.storage:load()

	local blk_owner = "NO_OWNER"
	local blk_state = false

	local tick_data = sm.game.getCurrentTick()
	if block_data then
		local owner_data = block_data.owner

		blk_owner = (owner_data ~= nil and owner_data or "NO_OWNER")
		blk_state = block_data.state or false
		tick_data = block_data.tick or sm.game.getCurrentTick()
	end
	
	self.creation_tick = tick_data
	verified_shapes[self.shape.id] = self.creation_tick

	self.block_owner = blk_owner
	self.state = blk_state
	
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.text = "Creation Name"
		self.sv.saved.parts = 0
		self.sv.saved.rent = 0
		self.sv.saved.coins = 0
		self.sv.saved.onlineOnly = true
		self.sv.saved.pvp = false
		self.sv.saved.build = false
		self.sv.saved.range = 20
		
		self.sv.saved.rentFraction = 0
		self.sv.saved.player = nil
		self.storage:save( self.sv.saved )
	end
	
	if self.sv.saved.player then
		self.block_owner = self.sv.saved.player
	end
	
	self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
end

function CreationProtector:server_removeDuplicates()
	local creation = sm.body.getCreationBodies(self.shape.body)
	local s_shape = self.shape

	local self_tick = verified_shapes[s_shape.id]

	for k, body in pairs(creation) do
		local body_shapes = body:getShapes()

		for k, shape in pairs(body_shapes) do
			if s_shape ~= shape and shape.uuid == s_shape.uuid then
				local ver_tick = verified_shapes[shape.id]

				local is_older = (self_tick < ver_tick)
				local is_same_time = (self_tick == ver_tick)
				local is_id_greater = (shape.id > s_shape.id)

				if is_same_time or is_older or is_id_greater then
					shape:destroyShape(0)
				end
			end
		end
	end

	return false
end

function CreationProtector:isModerator(player)
	local player_data = PlayerManager.playerData
	if not player_data then return false end

	local mod_list = player_data.mod_list
	local player_id = tostring(player.id)

	return (mod_list and mod_list[player_id] or false)
end

function CreationProtector:server_requestData(data, player)
	self.network:sendToClient(player, "client_receiveData", {
		owner = self.block_owner,
		state = self.state,
		is_mod = self:isModerator(player)
	})
end

function CreationProtector:client_receiveData(data)
	if data.is_mod ~= nil then
		self.is_mod = data.is_mod
	end

	if data.state ~= nil then
		self:client_setPose({state = data.state})
	end

	if data.owner ~= nil then
		self.client_block_owner = data.owner
	end
end

function CreationProtector:isOwner()
	local loc_player = sm.localPlayer.getPlayer()
	local client_owner = self.client_block_owner
	local owner_id = client_owner.id

	return (owner_id and owner_id == loc_player.id)
end

function CreationProtector:server_isCreationChanged()
	local creation = sm.body.getCreationBodies(self.shape.body)

	for k, body in pairs(creation) do
		if body:hasChanged(self.creation_time) then
			return true
		end
	end

	return false
end

function CreationProtector:server_onFixedUpdate()
	local cur_tick = sm.game.getCurrentTick()
	
	if (self.sv.saved.build or self.sv.saved.pvp) and cur_tick % 41 == 40 then
		local owner = self:FindOwner(self.block_owner.id)
		if not owner and not state then
			self:server_toggleProtection({},self.block_owner)
		end
		
		--get distance
		if owner then
			local length = owner:getCharacter():getWorldPosition() - self.shape.worldPosition
			length = length:length()
			
			if length > self.sv.saved.range then
				if not self.state then
					self:server_toggleProtection({},self.block_owner)
					self.network:sendToClient(self.block_owner, "client_onMsg", self.sv.saved.text .. ": #ff0000Out of range")
				end
			else
				if self.state then
					self:server_toggleProtection({},self.block_owner)
					self.network:sendToClient(self.block_owner, "client_onMsg", self.sv.saved.text .. ": #00ff00In range")
				end
			end
		end
	end

	if cur_tick % 2401 == 2400 then
		local pl_list = sm.player.getAllPlayers()
		for k, player in pairs(pl_list) do
			local is_mod = self:isModerator(player)

			self.network:sendToClient(player, "client_receiveData", {is_mod = is_mod})
		end
		if self.block_owner.id then
			self:server_calculateRent()
			self:server_payRent()
			if self.sv.saved.onlineOnly and not self:FindOwner(self.block_owner.id) then
				self:server_export(false, self.blk_owner)
			end
		end
	end

	local has_changed = self:server_isCreationChanged()
	if has_changed then
		self.creation_time = sm.game.getCurrentTick()

		self:server_removeDuplicates()
		
		local coins = 0
		for k, container in ipairs(self.interactable:getParents()) do
			if container.shape:getShapeUuid() ~= sm.uuid.new("056123f1-f030-40df-946a-b830bf494c92") then
				sm.interactable.disconnect(container, self.interactable)
			else
				coins = coins + sm.container.totalQuantity(container:getContainer(0), sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"))
			end
		end
		
		self.sv.saved.coins = coins
		
		self:server_calculateRent()
	end
end

function CreationProtector:server_payRent()
	
	self.sv.saved.rentFraction = self.sv.saved.rentFraction + 1
	
	local rentDue = self.sv.saved.rent*(self.sv.saved.rentFraction/60)
	
	--Add non full numbers back
	self.sv.saved.rentFraction = (rentDue%1)/rentDue
	rentDue = math.floor(rentDue)
	
	self.sv.saved.coins = self.sv.saved.coins - rentDue
	
	if self.sv.saved.coins >= 0 then
		for k, parent in ipairs(self.interactable:getParents()) do
			local container = parent:getContainer(0)
			container:setAllowSpend(true)
			
			local coins = sm.container.totalQuantity(container, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"))
			if coins > rentDue then
				sm.container.beginTransaction()
				sm.container.spend(container, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), rentDue, false)
				sm.container.endTransaction()
				rentDue = 0
			else
				sm.container.beginTransaction()
				sm.container.spend(container, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), coins, false)
				sm.container.endTransaction()
				rentDue = rentDue - coins
			end
			
			container:setAllowSpend(false)
		end
	else
		--export creation
		self:server_export(true, self.blk_owner)
	end
	
	self.storage:save( self.sv.saved )
	self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
end

function CreationProtector:server_export(disconnect, player)
	if not player or (self:isModerator(player) or player.id == self.block_owner.id) then
		local name = tostring(os.time()) .. tostring(math.random(100,999)) ..".blueprint"
		local id = self.block_owner.id
		
		--remove cointainers to prevent runnig out of rent again
		if disconnect then
			for k, container in ipairs(self.interactable:getParents()) do
				sm.interactable.disconnect(container, self.interactable)
			end
			print(self.block_owner)
			sm.event.sendToPlayer( self.block_owner, "sv_e_onMsg", "#ff0000Failed to pay rent for #ffffff" .. self.sv.saved.text )
			self.sv.saved.player = nil
			self.storage:save( self.sv.saved )
		end

		--export
		local obj = sm.json.parseJsonString( sm.creation.exportToString( self.shape.body ) )
		sm.json.save( obj, "$MOD_DATA/Scripts/Blueprints/".. tostring(id) .. "/" .. name )
		print("export")
	
		--add to index
		local success, data = pcall(sm.json.open, "$MOD_DATA/Scripts/Blueprints/" .. id .. "/index.json")
		if success and type(data) == "table" then
			if data.blueprints then
				data.blueprints[#data.blueprints + 1] = { date = os.time(), file = name, info = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent}
			end
		else
			data = {}
			data.blueprints = {}
			data.blueprints[1] = { date = os.time(), file = name, info = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.parts}
		end
		
		print("index")
		
		sm.json.save( {blueprints = data.blueprints}, "$MOD_DATA/Scripts/Blueprints/" .. id .. "/index.json" )
		
		print("new index")
	
		--delete
		for k, shape in ipairs(self.shape.body:getCreationShapes()) do
			shape:destroyShape(0)
		end
	end
end

function CreationProtector:server_calculateRent()
	local creation = sm.body.getCreationShapes(self.shape.body)
	
	--print("parts: " .. tostring(#creation))
	local bodies = sm.body.getCreationBodies(self.shape.body)
	--print("joints: " .. tostring(#bodies -1))
	
	local interactables = 0
	for k, shape in ipairs(creation) do
		if shape.interactable then
			interactables = interactables + 1
		end
	end
	
	--print("interactables: " .. tostring(interactables))
	
	self.sv.saved.parts = #creation + #bodies -1
	
	local grossRent = #creation + interactables*10 + (#bodies - 1)*25
	self.sv.saved.rent = math.ceil((grossRent/25)^1.2)
	
	local coins = 0
	for k, container in ipairs(self.interactable:getParents()) do
		coins = coins + sm.container.totalQuantity(container:getContainer(0), sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"))
	end
		
	self.sv.saved.coins = coins
	
	
	self.storage:save( self.sv.saved )
	self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
end

function CreationProtector:server_calculateCoins()
	local creation = sm.body.getCreationShapes(self.shape.body)
	
	local coins = 0
	for k, container in ipairs(self.interactable:getParents()) do
		coins = coins + sm.container.totalQuantity(container:getContainer(0), sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"))
	end
	self.sv.saved.coins = coins
	
	self.storage:save( self.sv.saved )
	self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
end

function CreationProtector:isAllowed()
	return self.is_mod
end

function CreationProtector:client_onCreate()
	local loc_pl = sm.localPlayer.getPlayer()

	self.is_mod = false
	
	self.anim_state = false
	self.anim_value = 0

	self.client_block_owner = "WAITING"

	self.network:sendToServer("server_requestData")
	
	-- Create keyboard
    self.keyboard = Keyboard.new(self, "C R E A T I O N",
        function (bufferedText)
			sm.audio.play("Retrowildblip")
			self.network:sendToServer("server_setText", bufferedText)
        end,

        function ()
			
            self:client_onTinker(sm.localPlayer.getPlayer():getCharacter(), true)
        end
    )
	self.openKeyboard = 0
end

function CreationProtector.server_setText( self, text, player)
	local block_owner = self.block_owner
	local owner_id = block_owner.id

	if self:isModerator(player) or player.id == self.block_owner.id then
		self.sv.saved.text = text
		self.storage:save( self.sv.saved )
		self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
	end
end

function CreationProtector.client_onClientDataUpdate( self, params )
	self.text = params.text
	self.parts = params.parts
	self.rent = params.rent
	self.coins = params.coins
	self.onlineOnly = params.onlineOnly
	self.pvp = params.pvp
	self.build = params.build
	self.range = params.range
end

function CreationProtector:server_requestOwner(data, player)
	if self.block_owner == "NO_OWNER" then
		self.block_owner = player
		
		if self.sv.saved.onlineOnly then
			self.sv.saved.player = player
		end
		
		self.storage:save({tick = self.creation_tick, state = self.state, owner = self.block_owner})

		self.network:sendToClients("client_receiveData", {owner = self.block_owner})
	else
		self.network:sendToClient(player, "client_receiveMessage", "has_owner")
	end
end

local message_ids = {
	has_owner = "This Creation Protector is already owned by another player",
	no_permission = "You do not have permission to use that Creation Protector"
}

function CreationProtector:client_receiveMessage(msg_id)
	local current_msg = message_ids[msg_id]
	sm.gui.displayAlertText(current_msg, 3)
end

function CreationProtector:client_onMsg(msg)
	sm.gui.displayAlertText(msg)
end

function CreationProtector:server_setProtectionState(state)
	local creation = sm.body.getCreationBodies(self.shape.body)

	local cur_state = not state
	for k, body in pairs(creation) do
		body:setDestructable(cur_state)
		body:setBuildable(cur_state)
		body:setPaintable(cur_state)
		body:setConnectable(cur_state)
		body:setLiftable(cur_state)
		body:setUsable(cur_state)
		body:setErasable(cur_state)
		body:setConvertibleToDynamic(cur_state)
	end
end

function CreationProtector:client_onUpdate()
	if not sm.exists(self.interactable) then return end

	local old_value = self.anim_value
	local new_value = sm.util.lerp(old_value, self.anim_state and 1.0 or 0.0, 0.15)

	if new_value ~= old_value then
		self.anim_value = new_value
		self.interactable:setPoseWeight(0, new_value)
	end
	
	if self.gui and self.gui:isActive() then
		self.gui:setText("PartCount", "Parts: " .. tostring(self.parts))
		self.gui:setText("Rent", "Rent: $" .. tostring(self.rent) .. "/h")
		self.gui:setText("Coins", "Coins: $" .. tostring(self.coins))
		
		self.gui:setText("RentMode", "Rent: " .. (self.onlineOnly and "Online Only" or "Always"))
		self.gui:setText("PVP", "PVP: " .. (self.pvp and "On" or "Off"))
		self.gui:setText("Build", "Build Mode: " .. (self.build and "On" or "Off"))
		self.gui:setText("Range", "Range: " .. tostring(self.range))
	end
end

function CreationProtector:client_setPose(data)
	local state = data.state
	self.anim_state = state
	self.interactable:setUvFrameIndex(state and 1 or 0)

	if data.snd then
		sm.audio.play(state and "Lever on" or "Lever off", self.shape.worldPosition)
	end
end

local barrier_effects = {
	[true] = "Barrier - Activation",
	[false] = "Barrier - Deactivation"
}

local encryptor_effects = {
	[true] = "Encryptor - Activation",
	[false] = "Encryptor - Deactivation"
}

function CreationProtector:server_toggleProtection(data, player)
	local block_owner = self.block_owner
	local owner_id = block_owner.id

	local is_mod = self:isModerator(player)

	if is_mod or (owner_id and player.id == owner_id) then
		self.state = not self.state

		local shape = self.shape
		local _state = self.state
		sm.effect.playEffect(barrier_effects[_state], shape.worldPosition, nil, shape.worldRotation)
		sm.effect.playEffect(encryptor_effects[_state], shape.worldPosition, nil, shape.worldRotation)

		self:server_setProtectionState(_state)
		self.storage:save({tick = self.creation_tick, state = _state, owner = self.block_owner})
		self.network:sendToClients("client_setPose", {state = _state, snd = true})
	else
		self.network:sendToClient(player, "client_receiveMessage", "no_permission")
	end
end

function CreationProtector:client_onInteract(character, state)
	if not state then return end

	local block_owner = self.client_block_owner
	local no_owner = (block_owner == "NO_OWNER")

	local loc_pl = sm.localPlayer.getPlayer()
	if (not no_owner and self:isOwner()) or self:isAllowed() then
		self.network:sendToServer("server_toggleProtection")
	elseif no_owner then
		self.network:sendToServer("server_requestOwner")
	end
end

function CreationProtector:client_onTinker(character, state)
	if not state or not (self:isOwner() or self:isAllowed()) then return end

	if self:isOwner() or self:isAllowed() then
		self.network:sendToServer("server_calculateRent")
	
		self.gui = {}
	
		self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/CreationProtector.layout")

		self.gui:setButtonCallback("ChangeName", "client_GUI_changeName")
		
		self.gui:setText("ChangeName", self.text)
		self.gui:setText("PartCount", "Parts: " .. tostring(self.parts))
		
		self.gui:setButtonCallback("RentMode", "client_changeRent")
		self.gui:setButtonCallback("PVP", "client_changePVP")
		self.gui:setButtonCallback("Build", "client_changeBuild")
		self.gui:setButtonCallback("Range+", "client_rangeUp")
		self.gui:setButtonCallback("Range-", "client_rangeDown")
		self.gui:setButtonCallback("Export", "client_export")
		
		--self.gui:setOnCloseCallback("client_onGUIDestroyCallback")

		self.gui:open()
	end
end

function CreationProtector.client_changeRent(self)
	self.network:sendToServer("server_changeRent")
end

function CreationProtector.server_changeRent(self, params, player)
	if self:isModerator(player) or player.id == self.block_owner.id then
		self.sv.saved.onlineOnly = not self.sv.saved.onlineOnly
		self.sv.saved.player = nil
		if self.sv.saved.onlineOnly then self.sv.saved.player = player end
		self.storage:save( self.sv.saved )
		self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
	end
end

function CreationProtector.client_changePVP(self)
	self.network:sendToServer("server_changePVP")
end

function CreationProtector.server_changePVP(self, params, player)
	if self:isModerator(player) or player.id == self.block_owner.id then
		self.sv.saved.pvp = not self.sv.saved.pvp
		self.storage:save( self.sv.saved )
		self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
	end
end

function CreationProtector.client_changeBuild(self)
	self.network:sendToServer("server_changeBuild")
end

function CreationProtector.server_changeBuild(self, params, player)
	if self:isModerator(player) or player.id == self.block_owner.id then
		self.sv.saved.build = not self.sv.saved.build
		self.storage:save( self.sv.saved )
		self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
	end
end

function CreationProtector.client_rangeUp(self)
	self.network:sendToServer("server_changeRange", 1)
end

function CreationProtector.client_rangeDown(self)
	self.network:sendToServer("server_changeRange", -1)
end

function CreationProtector.server_changeRange(self, params, player)
	if self:isModerator(player) or player.id == self.block_owner.id then
		self.sv.saved.range = self.Ranges[math.max(math.min(((self.sv.saved.range/10) + params),#self.Ranges),1)]
		self.storage:save( self.sv.saved )
		self.network:setClientData( { text = self.sv.saved.text, parts = self.sv.saved.parts, rent = self.sv.saved.rent, coins = self.sv.saved.coins, onlineOnly = self.sv.saved.onlineOnly, pvp = self.sv.saved.pvp, build = self.sv.saved.build, range = self.sv.saved.range } )
	end
end

function CreationProtector.client_export(self)
	self.gui:close()
	self.confirmClearGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout" )
	self.confirmClearGui:setButtonCallback( "Yes", "cl_onExport" )
	self.confirmClearGui:setButtonCallback( "No", "client_close" )
	self.confirmClearGui:setText( "Title", "Sure?" )
	self.confirmClearGui:setText( "Message", "#909191Exporting your creation will #ffffffDELETE#909191 it. However, you can import it again with a #ffffffCREATION SPAWNER#909191." )
	self.confirmClearGui:setOnCloseCallback("client_openMainGui")
	
	self.confirmClearGui:open()
end

function CreationProtector.cl_onExport(self)
	sm.audio.play("Blueprint - Save")
	self.confirmClearGui:close()
	self.network:sendToServer("server_export", false)
end

function CreationProtector.client_openMainGui(self)
	self:client_onTinker(sm.localPlayer.getPlayer():getCharacter(), true)
end

function CreationProtector.client_close(self)
	self.confirmClearGui:close()
end

function CreationProtector.client_GUI_changeName(self)
	self.gui:close()
	self.openKeyboard = sm.game.getCurrentTick() + 1
end

function CreationProtector.client_onFixedUpdate(self)
	if sm.game.getCurrentTick() == self.openKeyboard then
		self.openKeyboard = 0
		self.keyboard:open(self.text)
	end
end

function CreationProtector:client_canInteract()
	local _use_key = sm.gui.getKeyBinding("Use")
	local block_owner = self.client_block_owner
	local owner_name = block_owner.name

	if block_owner == "WAITING" then
		sm.gui.setInteractionText("", "Waiting for data...")
		sm.gui.setInteractionText("")

		return false
	end

	local is_allowed = self:isAllowed()

	if block_owner == "NO_OWNER" then
		self.network:sendToServer("server_calculateCoins")
		if self.coins > 0 then
			sm.gui.setInteractionText("", _use_key, "Claim ownership")
		else
			sm.gui.setInteractionText("Connect to filled", "Cointainer")
			return false
		end

		if not is_allowed then
			sm.gui.setInteractionText("")
			return true
		end
	else
		if is_allowed and owner_name then
			local owner_msg = ("#00aa00%s#222222 owns this"):format(owner_name)

			sm.gui.setInteractionText("", owner_msg)
		end
	end

	if self:isOwner() or is_allowed then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Settings")
		sm.gui.setInteractionText("", _use_key, (self.anim_state and "Deactivate" or "Activate") .. " protection")
		
		return true
	end

	if owner_name then
		local owner_msg = ("#00aa00%s#222222 owns this"):format(owner_name)

		sm.gui.setInteractionText("", owner_msg)
		sm.gui.setInteractionText("")
	end

	return false
end

function CreationProtector.client_canTinker( self, character, state )
	if self.client_block_owner.id and (self:isOwner() or self:isAllowed()) then
		return true
	end
	return false
end

function CreationProtector:client_canErase()
	local block_owner = self.client_block_owner

	if block_owner == "NO_OWNER" or self:isOwner() or self:isAllowed() then return true end
	
	sm.gui.displayAlertText("Only the Owner / Moderators can delete this tool", 1)
	return false
end

function CreationProtector:FindOwner(id)
	if id == nil then return end

	local pl_list = sm.player.getAllPlayers()
	for k, player in pairs(pl_list) do
		if player.id == id then
			return player
		end
	end
end

function CreationProtector:IsAllModeratorsOrOwners(pl_list)
	if #pl_list == 0 then return false end

	local owner = self:FindOwner(self.block_owner.id)
	for k, player in pairs(pl_list) do
		local is_owner = (owner ~= nil and owner == player or false)
		local is_moderator = self:isModerator(player)

		if not (is_owner or is_moderator) then
			return false
		end
	end
	
	return true
end

function CreationProtector:server_canErase()
	local owner_id = self.block_owner.id
	if not owner_id then return true end
	for k, player in pairs(sm.player.getAllPlayers()) do
		if player.id == owner_id then
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

function CreationProtector:server_onDestroy()
	verified_shapes[self.shape.id] = nil
end