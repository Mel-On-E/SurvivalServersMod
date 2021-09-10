--[[
	Copyright (c) 2021 Questionable Mark
]]

if PlayerManager then return end

PlayerManager = class()
PlayerManager.main_shape = nil

local SERVER_SETTINGS_FILE = "$MOD_DATA/Scripts/permissions.json"

local function LoadPlayerData()
	if PlayerManager.playerData then return end

	local ban_list = {}
	local mod_list = {}

	local success, error = pcall(sm.json.open, SERVER_SETTINGS_FILE)
	if success and type(error) == "table" then
		ban_list = error.banned
		mod_list = error.moderators
	end

	PlayerManager.playerData = {}
	PlayerManager.playerData.mod_list = mod_list or {}
	PlayerManager.playerData.banned_list = ban_list or {}
end

local function SavePlayerData()
	local pl_data = PlayerManager.playerData
	if not pl_data then return end

	local json_data = {
		banned = pl_data.banned_list or {},
		moderators = pl_data.mod_list or {}
	}

	sm.json.save(json_data, SERVER_SETTINGS_FILE)
end

function PlayerManager:server_YeetPlayer(player)
	local cur_world = nil

	local char = player:getCharacter()
	if char ~= nil then
		cur_world = char:getWorld()
	else
		cur_world = self.shape.body:getWorld()
	end

	local new_char = sm.character.createCharacter(player, cur_world, sm.vec3.new(69420, 69420, 69420), 0, 0, char)

	player:setCharacter(new_char)
	player:setCharacter(nil)
end

function PlayerManager:server_onFixedUpdate()
	local cur_tick = sm.game.getCurrentTick()
	
	if cur_tick % 2401 == 2400 then
		PlayerManager.playerData = nil
		LoadPlayerData()

		local player_table = sm.player.getAllPlayers()
		for k, player in pairs(player_table) do
			local is_banned = self:isBanned(player)
			
			if is_banned then
				local server_admin = self.server_admin_player
				self.network:sendToClient(player, "client_kickPlayer", server_admin)
				
				--Yeetus Deletus hotfix
				self:server_YeetPlayer(player)
				
				self.network:sendToClients("client_chatMessage", {mode = "ban", player = player, kicker = server_admin})
			else
				local is_moderator = self:isModerator(player)
				self.network:sendToClient(player, "client_receivePermission", is_moderator)
			end
		end
	end
	
end

function PlayerManager:server_onDestroy()
	local main_shape = PlayerManager.main_shape
	if main_shape and self.shape == main_shape then
		PlayerManager.main_shape = nil
	end
end

function PlayerManager:server_onCreate()
	if not PlayerManager.main_shape then
		PlayerManager.main_shape = self.shape
	else
		self.shape:destroyShape(0)
		return
	end

	LoadPlayerData()

	self.server_admin = true
end

function PlayerManager:isAllowed()
	return self.allowed or self.server_admin
end

function PlayerManager:isModerator(player)
	local pl_data = PlayerManager.playerData
	if not pl_data then return false end

	local player_id = tostring(player.id)
	local mod_list = pl_data.mod_list

	return (mod_list and mod_list[player_id])
end

function PlayerManager:isBanned(player)
	local pl_data = PlayerManager.playerData
	if not pl_data then return false end

	local player_id = tostring(player.id)
	local ban_list = pl_data.banned_list

	return (ban_list and ban_list[player_id])
end

function PlayerManager:server_requestPermission(data, player)
	if self:isModerator(player) then
		self.network:sendToClient(player, "client_receivePermission", true)
	end
end

function PlayerManager:client_receivePermission(state)
	self.allowed = state
end

function PlayerManager:server_checkBanned(data, player)
	if self:isBanned(player) then
		self:server_YeetPlayer(player)

		self.network:sendToClient(player, "client_kickPlayer", self.server_admin_player)
		self.network:sendToClients("client_chatMessage", {mode = "ban_rejoin", player = player})
	end
end

function PlayerManager:client_chatMessage(data)
	local t_player = data.player
	local d_Mode = data.mode

	if d_Mode == "ban_rejoin" then
		sm.gui.chatMessage(("#ff0000%s#ffffff is banned. Kicking..."):format(t_player.name))
	elseif d_Mode == "p_hck_attempt" then
		sm.gui.chatMessage(("#ff0000%s#ffffff has tried to use Player Manager without permission!"):format(t_player.name))
	else
		local t_reason = (d_Mode == "kick" and "kicked" or "banned")
		local msg_color = (d_Mode == "kick" and "#ffff00" or "#ff0000")
		local moderator = data.kicker

		sm.gui.chatMessage(("%s%s#ffffff has been %s by #11ab3a%s#ffffff"):format(msg_color, t_player.name, t_reason, moderator.name))
	end
end

function PlayerManager:client_onCreate()
	local loc_player = sm.localPlayer.getPlayer()

	if self.server_admin then
		self.server_admin_player = loc_player
	end

	self.network:sendToServer("server_checkBanned")

	if not self:isAllowed() then
		self.network:sendToServer("server_requestPermission")
	end
end

function PlayerManager:client_onInteract(character, state)
	if not state or not self:isAllowed() then return end

	self:client_initializeGUI()
end

function PlayerManager:client_canInteract()
	if self:isAllowed() then
		local use_key = sm.gui.getKeyBinding("Use")
		sm.gui.setInteractionText("Press", use_key, "to open Player Manager")
		return true
	end
	
	sm.gui.setInteractionText("", "Only allowed players can use this tool")
	return false
end

function PlayerManager:server_canErase()	
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

function PlayerManager:client_canErase()
	if self.server_admin then return true end

	sm.gui.displayAlertText("Only the server host can remove this tool", 1)
	return false
end

---GUI STUFF START

function PlayerManager:client_initializeGUI()
	local gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/PlayerManagerGUI.layout")

	for k, btn_name in pairs({"Next", "Prev"}) do
		gui:setButtonCallback(btn_name.."Player", "client_GUI_changeCurPlayer")
	end

	for k, btn_name in pairs({"Kick", "Ban"}) do
		gui:setButtonCallback(btn_name.."Player", "client_GUI_playerFunctionCallback")
	end

	gui:setOnCloseCallback("client_onGUIDestroyCallback")

	self.gui = {}
	self.gui.interface = gui
	self.gui.selected_player = nil
	self.gui.current_page = -1

	self:client_GUI_updateCurrentPage()

	gui:open()
end

function PlayerManager:server_kickPlayer(data, caller)
	local pl_to_kick = data.player

	local is_caller_mod = self:isModerator(caller)
	local is_admin = (caller == self.server_admin_player)

	local error_msg = nil

	if is_admin or is_caller_mod then
		local is_pl_mod = self:isModerator(pl_to_kick)
		local is_pl_admin = (pl_to_kick == self.server_admin_player)

		if not is_pl_admin then
			if (is_pl_mod and is_admin) or not is_pl_mod then
				if not self:isBanned(pl_to_kick) then
					if data.mode == "ban" then
						local pl_id = tostring(pl_to_kick.id)
						PlayerManager.playerData.banned_list[pl_id] = true

						SavePlayerData()
					end

					self:server_YeetPlayer(pl_to_kick)

					self.network:sendToClient(pl_to_kick, "client_kickPlayer", caller)
					self.network:sendToClients("client_chatMessage", {mode = data.mode, player = pl_to_kick, kicker = caller})
				else
					error_msg = "already_banned"
				end
			else
				error_msg = "mod_kick"
			end
		else
			error_msg = "admin_kick"
		end
	else
		error_msg = "no_permission"
		self.network:sendToClients("client_chatMessage", {mode = "p_hck_attempt", player = caller})
	end

	if error_msg then
		self.network:sendToClient(caller, "client_receiveMessage", error_msg)
	end
end

local message_ids = {
	no_permission = "You do not have permission to kick or ban players!",
	mod_kick = "Only server admin can kick or ban moderators",
	admin_kick = "You can't kick or ban server admin!",
	already_banned = "The specified player is already banned!"
}

function PlayerManager:client_receiveMessage(msg_id)
	local msg = message_ids[msg_id]

	sm.gui.displayAlertText(msg, 5)
	sm.audio.play("WeldTool - Error")
end

function PlayerManager:client_GUI_kickSuccess(data)
	local pl_name = data.player.name
	local p_reason = (data.mode == "ban" and "banned" or "kicked")

	sm.gui.displayAlertText(("#ffff00%s#ffffff has been successfully %s"):format(pl_name, p_reason), 3)
	sm.audio.play("Retrowildblip")
end

function PlayerManager:client_GUI_playerFunctionCallback(btn_name)
	local sel_player = self.gui.selected_player

	if sel_player then
		if sm.exists(sel_player) then
			local btn_id = btn_name:sub(0, 4)

			local is_kick = (btn_id == "Kick")
			local cur_mode = (is_kick and "kick" or "ban")

			self.network:sendToServer("server_kickPlayer", {
				mode = (is_kick and "kick" or "ban"),
				player = self.gui.selected_player
			})
		else
			sm.gui.displayAlertText("The specified player does no longer exist!")
			sm.audio.play("WeldTool - Error")
		end

		self:client_GUI_reset()
	else
		sm.gui.displayAlertText("Select a player")
		sm.audio.play("WeldTool - Error")
	end
end

function PlayerManager:client_onGUIDestroyCallback()
	if not self.gui then return end
	local gui_int = self.gui.interface

	if gui_int and sm.exists(gui_int) then
		if gui_int:isActive() then
			gui_int:close()
		end

		gui_int:destroy()
	end

	self.gui = nil
end

function PlayerManager:getPlayerList()
	local loc_player = sm.localPlayer.getPlayer()
	local player_list = sm.player.getAllPlayers()

	local output_list = {}
	for k, player in pairs(player_list) do
		if player ~= loc_player then
			table.insert(output_list, player)
		end
	end

	return output_list
end

function PlayerManager:client_GUI_reset()
	self.gui.current_page = -1
	self.gui.selected_player = nil

	self:client_GUI_updateCurrentPage()
end

function PlayerManager:client_onFixedUpdate()

	--Pixel's time manager stuff
	local time = (sm.game.getCurrentTick()%57600)/57600
	
	--Reduce night time
	if time < 0.5 then
		time = math.sqrt(time*2)/2
	else
		time = 0.5 + (((time-0.5)*2)^2)/2
	end
	
	sm.game.setTimeOfDay(time)
	sm.render.setOutdoorLighting(time)
	--end
	
	if not self.gui then return end

	local gui_int = self.gui.interface
	
	if self:isAllowed() then
		local cur_player = self.gui.selected_player
		if cur_player then
			if sm.exists(cur_player) then
				local pl_char = cur_player:getCharacter()

				local gui_msg = "No Character"
				if pl_char and sm.exists(pl_char) then
					local c_pos = pl_char:getWorldPosition()
					gui_msg = ("Pos: [#ffff00%.1f#ffffff, #ffff00%.1f#ffffff, #ffff00%.1f#ffffff]"):format(c_pos.x, c_pos.y, c_pos.z)
				end

				gui_int:setText("PlayerPos", gui_msg)
			else
				sm.gui.displayAlertText("Selected player doesn't exist anymore, resetting GUI...", 4)
				sm.audio.play("WeldTool - Error")
				self:client_GUI_reset()
			end
		end
	else
		if gui_int:isActive() then
			gui_int:close()
		end
	end
end

function PlayerManager:client_GUI_updateCurrentPage()
	local gui = self.gui
	local gui_int = gui.interface
	local cur_page = gui.current_page

	local state = (cur_page > -1)
	for k, lbl in pairs({"PlayerId", "PlayerName", "PlayerPos"}) do
		gui_int:setVisible(lbl, state)
	end

	gui_int:setVisible("SelPlayerLabel", not state)

	local player_list = self:getPlayerList()
	gui_int:setText("CurPlayerPage", ("%s / %s"):format(gui.current_page + 1, #player_list))
end

function PlayerManager:client_GUI_changeCurPlayer(btn_name)
	local btn_id = btn_name:sub(0, 4)
	local cur_idx = (btn_id == "Next" and 1 or -1)

	local pl_list = self:getPlayerList()

	local player_count = #pl_list
	if player_count > 0 then
		local new_value = (self.gui.current_page + 1) % player_count

		if new_value ~= self.gui.current_page then
			self.gui.current_page = new_value

			local cur_player = pl_list[self.gui.current_page + 1]
			local gui_int = self.gui.interface

			sm.audio.play("GUI Item drag")

			gui_int:setText("PlayerName", ("Name: #ffff00%s#ffffff"):format(cur_player.name))
			gui_int:setText("PlayerId", ("Id: #ffff00%s#ffffff"):format(cur_player.id))

			self:client_GUI_updateCurrentPage()

			self.gui.selected_player = cur_player
		end
	else
		sm.gui.displayAlertText("No players on the server", 2)
		sm.audio.play("WeldTool - Error")
	end
end

---GUI STUFF END

function PlayerManager:client_kickPlayer(caller)
	local loc_pl = sm.localPlayer.getPlayer()

	if caller ~= loc_pl then
		while true do end
	end
end

function PlayerManager:client_onDestroy()
	self:client_onGUIDestroyCallback()
end

--Questionable Spudgun Mod Detector
local Proj_ShootCache = {}
local Proj_AllowedProjectiles = {potato = true, fries = true, smallpotato = true, glowstick = true}

local function Proj_BasicCheck(dir, damage, proj_name)
	if dir:length() > 140 or damage > 28 or Proj_AllowedProjectiles[proj_name] == nil then
		return false
	end

	return true
end

local function Proj_PositionCheck(projOwner, shootPos)
	if type(projOwner) == "Player" then
		local char = projOwner:getCharacter()

		if char ~= nil and sm.exists(char) then
			local char_pos = char.worldPosition
			local shoot_dst = (shootPos - char.worldPosition):length()

			if shoot_dst > 2 then
				return false
			end
		else
			return false
		end
	end

	return true
end

local function Proj_CacheCheck(ownerId)
	local shootData = Proj_ShootCache[ownerId]
	local curTick = sm.game.getCurrentTick()

	if shootData then
		local durTick = curTick - shootData.tick

		if durTick > 40 then
			Proj_ShootCache[ownerId].shots = 1
			Proj_ShootCache[ownerId].tick = curTick
			Proj_ShootCache[ownerId].tickShot = 0
		else
			Proj_ShootCache[ownerId].shots = shootData.shots + 1
		end

		if durTick == 0 then
			Proj_ShootCache[ownerId].tickShot = shootData.tickShot + 1
		end

		if Proj_ShootCache[ownerId].shots > 12 or Proj_ShootCache[ownerId].tickShot > 1 then
			return false
		end
	else
		Proj_ShootCache[ownerId] = {tick = curTick, shots = 1, tickShot = 1}
	end

	return true
end

local oldProjAttack = sm.projectile.projectileAttack
sm.projectile.projectileAttack = function(proj_name, damage, shootPos, shootDir, projOwner)
	if sm.exists(projOwner) then
		if
			true or --REMOVE
			Proj_BasicCheck(shootDir, damage, proj_name) and
			Proj_PositionCheck(projOwner, shootPos) and
			Proj_CacheCheck(projOwner:getId())
		then
			oldProjAttack(proj_name, damage, shootPos, shootDir, projOwner)
		else
			sm.gui.displayAlertText("Stop cheating with your spudgun!", 3)
		end
	end
end

function PlayerManager:cl_onMessage(msg)
	sm.gui.displayAlertText(msg, 3)
end