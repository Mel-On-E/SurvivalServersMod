ATM = class()

function ATM.server_onCreate(self)
	self:server_LoadAccountData()
end

function ATM.server_LoadAccountData(self, params, player)
	local success, data = pcall(sm.json.open, "$MOD_DATA/Scripts/accounts.json")
	if success and type(data) == "table" then
		self.accounts = data
		
		--Create New Account
		if player and not self.accounts[tostring(player.id)] then
			local oldAccounts = self.accounts
			self.accounts[tostring(player.id)] = { balance = 69, interest = "1.01"}
			local success, nothing = pcall(sm.json.save, self.accounts, "$MOD_DATA/Scripts/accounts.json")
			if not success then
				self.accounts = oldAccounts
				self.network:sendToClient(player, "client_msg", { msg = "#ff0000Error creating account. Please try again", sound = "RaftShark"})
			else
				self.network:sendToClient(player, "client_msg", {msg = "#ffff00Welcome to capitalsim!"})
			end
		end
		
		--Check for interest
		local dif = os.difftime(os.time(), self.accounts["time"])
		local interval = (60*60*24)
		if dif > interval then
			oldAccounts = self.accounts
			local stonks = math.floor(dif/interval)
			
			for id,account in pairs(oldAccounts) do
				if id ~= "time" then
					self.accounts[id].balance = math.floor(self.accounts[id].balance * tonumber(account.interest)^stonks)
				end
			end
			
			self.accounts["time"] = self.accounts["time"] + interval*stonks
			
			local success, nothing = pcall(sm.json.save, self.accounts, "$MOD_DATA/Scripts/accounts.json")
			if not success then
				self.accounts = oldAccounts
				self.network:sendToClient(player, "client_msg", { msg = "#ff0000Error calculating interest. Please try again", sound = "RaftShark"})
			else
				self.network:sendToClients("client_msg", {msg = "#00ff00Daily interest earned!", effect = "Gui - LogbookNotification"})
			end
		end
		
		self.network:setClientData( { accounts = data } )
	end
end

function ATM.client_onClientDataUpdate( self, params )
	self.accounts = params.accounts
end

function ATM.client_onFixedUpdate(self)
	if self.gui then
		if self.gui:isActive() and self.accounts[tostring(self.playerID)] then
			local balance = tostring(self.accounts[tostring(self.playerID)].balance)
			local money = ""
			for i=1, math.floor(balance:len()/3 - 1/3), 1 do
				money = "," .. balance:sub(-3*i, 2 - 3*i) .. money
			end
			money = balance:sub(1,-1 -3*math.floor(balance:len()/3 - 1/3)) .. money
			self.gui:setText("Balance", "$" .. money)
		end
	end
end

function ATM.client_onInteract(self, character, state)
	if state then
		sm.effect.playEffect("Sensor on - Level 3", self.shape.worldPosition)
		self.playerID = character:getPlayer().id
		self.network:sendToServer("server_LoadAccountData")
	
		self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/ATM.layout")

		self.gui:setButtonCallback("Take1", "client_GUI_changeBalance")
		self.gui:setButtonCallback("Take10", "client_GUI_changeBalance")
		self.gui:setButtonCallback("Take100", "client_GUI_changeBalance")
		self.gui:setButtonCallback("Take1000", "client_GUI_changeBalance")
		
		self.gui:setButtonCallback("Add1", "client_GUI_changeBalance")
		self.gui:setButtonCallback("Add10", "client_GUI_changeBalance")
		self.gui:setButtonCallback("Add100", "client_GUI_changeBalance")
		self.gui:setButtonCallback("Add1000", "client_GUI_changeBalance")
		
		self.gui:setText("Interest", "Daily interest: " .. self.accounts[tostring(self.playerID)].interest:sub(4,4) .. "." .. self.accounts[tostring(self.playerID)].interest:sub(5) .. "%")

		self.gui:setOnCloseCallback("client_onGUIDestroyCallback")

		self.gui:open()
	end
end

function ATM:client_GUI_changeBalance(btn_name)
	local amount = 0
	if btn_name:sub(0,-btn_name:len()) == "A" then
		amount = tonumber(btn_name:sub(4,btn_name:len()))
	else
		amount = tonumber(btn_name:sub(5,btn_name:len()))*-1
	end
	self.network:sendToServer("server_changeBalance", amount)
end

function ATM:client_onGUIDestroyCallback()
	sm.effect.playEffect("Sensor off - Level 3", self.shape.worldPosition)
end

function ATM.server_changeBalance(self, amount, player)
	local oldAccounts = self.accounts
	local inventory = player:getInventory()
	
	if amount > 0 then	
		if inventory:canSpend(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), amount) then
			self.accounts[tostring(player.id)].balance = self.accounts[tostring(player.id)].balance + amount
			
			sm.container.beginTransaction()
			sm.container.spend(inventory, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), amount, false)
			sm.container.endTransaction()
			self.network:sendToClient(player, "client_msg", {sound = "Button on"})
		else
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Insufficent funds", sound = "RaftShark"})
		end
	else
		if amount*-1 <= self.accounts[tostring(player.id)].balance then
			if inventory:canCollect(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), amount*-1) then
				self.accounts[tostring(player.id)].balance = self.accounts[tostring(player.id)].balance + amount
			
				sm.container.beginTransaction()
				sm.container.collect(inventory, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), amount*-1, false)
				sm.container.endTransaction()
				self.network:sendToClient(player, "client_msg", {sound = "Button off"})
			else
				self.network:sendToClient(player, "client_msg", {msg = "#ff0000Inventory full", sound = "RaftShark"})
			end
		else
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Insufficent funds", sound = "RaftShark"})
		end
	end
	
	local success, data = pcall(sm.json.save, self.accounts, "$MOD_DATA/Scripts/accounts.json")
	if not success then
		self.accounts = oldAccounts
		self.network:sendToClient(player, "client_msg", {msg = "#ff0000Error. Please try again", sound = "RaftShark"})
	end
	self.network:setClientData( { accounts = self.accounts } )
end

function ATM.client_msg(self, params)
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