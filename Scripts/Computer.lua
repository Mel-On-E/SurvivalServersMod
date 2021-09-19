Computer = class(nil)
Computer.maxParentCount = 1
Computer.maxChildCount = 0
Computer.connectionInput = sm.interactable.connectionType.electricity
Computer.colorNormal = sm.color.new( 0xe9e0c8ff )
Computer.colorHighlight = sm.color.new( 0xff9f3aff )

dofile( "./SmKeyboardMaster/Scripts/Keyboard2.lua" )

--TODO
--ScrapNet
--ScrapCoin
--Calculator
--Jobs?
--Game?
--Notepad with clippy
--Banking

function Computer.server_onCreate(self)
	self:server_LoadAccountData()
	self.user = false
	
	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
		self.saved.onGround = nil
		self.saved.power = 0
	end
end

function Computer.server_onFixedUpdate(self)
	if self.logout and self.logout < sm.game.getCurrentTick() then
		self.logout = nil
		self.interactable:setActive(false)
		self.user = false
		self.network:setClientData( { hasUser = self.user, container = self.container, power = (self.saved.power > 0) } )
	end
	
	if self.container ~= self.interactable:getSingleParent() then
		self.container = self.interactable:getSingleParent()
		self.network:setClientData( { hasUser = self.user, container = self.container, power = (self.saved.power > 0) } )
	end
	
	if self.interactable:isActive() or self.user then
		self.saved.power = self.saved.power - 1
	end
	
	-- Consume fuel for fuel points
	if self.container then
		local canSpend = false
		local container = self.container:getContainer(0)
		if self.saved.power <= 0 then
			canSpend = sm.container.canSpend( container, sm.uuid.new( "910a7f2c-52b0-46eb-8873-ad13255539af" ), 1 )
		end
		if canSpend and self.saved.power <= 0 then
			sm.container.beginTransaction()
			sm.container.spend( container, sm.uuid.new( "910a7f2c-52b0-46eb-8873-ad13255539af" ), 1, true )
			sm.container.endTransaction()
			self.saved.power = self.saved.power + 12000 --5mins per battery
			self.network:setClientData( { hasUser = self.user, container = self.container, power = (self.saved.power > 0) } )
		elseif self.saved.power < 0 then	
			if self.user then
				self.network:sendToClient(self.user, "client_msg", { msg = "Out of power"})
				self.network:sendToClient(self.user, "client_onClose")
				self.network:setClientData( { hasUser = self.user, container = self.container, power = (self.saved.power > 0) } )
			end
			
			self.network:sendToClient( "client_msg", {effect = "Part - Electricity"})
			self.saved.power = 0
			self.interactable:setActive(false)
			self.user = false
		end
	end
end

function Computer.server_LoadAccountData(self, params, player)
	local success, data = pcall(sm.json.open, "$MOD_DATA/Scripts/ScrapNet/NetAccounts.json")
	if success and type(data) == "table" then
		self.accounts = data
	end
	

	if player and self.accounts then
		for k, v in pairs(self.accounts) do
			if tostring(player.id) == k then
				self.network:sendToClient(player, "client_hasAccount")
			end
		end
	end
	
	if player then
		success, data = pcall(sm.json.open, "$MOD_DATA/Scripts/ScrapNet/Emails.json")
		if success and type(data) == "table" then
			for k, v in pairs(data) do
				if tostring(player.id) == k then
					self.network:sendToClient(player, "client_receiveMail", v)
				end
			end
		end
	end
end

function Computer.server_createAccount(self, params, player)
	local oldAccounts = self.accounts
	
	if self.accounts then
		for k, v in pairs(self.accounts) do
			if tostring(player.id) == k then
				return
			end
		end
	end
	
	if self.accounts then
		self.accounts[tostring(player.id)] = { name = params.username, password = params.password}
	else
		self.accounts = {}
		self.accounts[tostring(player.id)] = { name = params.username, password = params.password}
	end
	
	local success, nothing = pcall(sm.json.save, self.accounts, "$MOD_DATA/Scripts/ScrapNet/NetAccounts.json")
	if not success then
		self.accounts = oldAccounts
		self.network:sendToClient(player, "client_msg", { msg = "#ff0000Error creating account", sound = "RaftShark"})
	else
		self.network:sendToClient(player, "client_msg", { msg = "Account created", sound = "Retrowildblip"})
		self.network:sendToClient(player, "client_hasAccount")
	end
end

function Computer.server_login(self, params, player)
	if player and self.accounts then
		for k, v in pairs(self.accounts) do
			if tostring(player.id) == k then
				if params.password == v.password and params.username == v.name then
					self.network:sendToClient(player, "client_login")
					self.interactable:setActive(true)
				else
					self.network:sendToClient(player, "client_msg", { msg = "#ff0000Password/Username wrong", sound = "RaftShark"})
				end
			end
		end
	end
end

function Computer.server_setUser(self, params, player)
	if not params and self.user then
		if not self.user.id == player.id then
			return
		end
		self.user = false
		self.interactable:setActive(false)
		if self.logout then self.logout = nil end
	end
	if params then 
		self.user = player 	
	end
	self.network:setClientData( { hasUser = (self.user and true), container = self.container, power = (self.saved.power > 0) } )
end

function Computer.server_logoutTimer(self, params, player)
	self.logout = sm.game.getCurrentTick() + 40*60*5
end



function Computer.client_onCreate(self)
	-- Create keyboard
    self.keyboard = Keyboard2.new(self, "", 16,
        function (bufferedText)
			sm.audio.play("Retrowildblip")
			--self.network:sendToServer("server_setText", bufferedText)
        end,

        function ()
			if self.gui then
				self.openGui = { tick = 1, text = self.keyboard.buffer, title = self.keyboard.title}
			end
		end
    )
	
	self.username = ""
	self.password = ""
	self.hasUser = false
	self.network:sendToServer("server_setUser", false)
end

function Computer.client_canInteract( self, character, state )
	if self.container and self.power then
		if not self.hasUser or self.logout then
			return true
		end
		sm.gui.setInteractionText("In Use")
	else
		sm.gui.setInteractionText("Needs", "Electricity")
	end
	return false
end

function Computer.client_onInteract( self, character, state )
	if state then
		if self.logout then self.logout = nil end
		
		sm.localPlayer.getPlayer().character:setLockingInteractable( self.interactable )
		sm.camera.setCameraState( sm.camera.state.default )
		self.camera = { pos = sm.camera.getPosition(), dir = sm.camera.getDirection()}
		
		if not self.interactable:isActive() then
			self.network:sendToServer("server_LoadAccountData")
			
			self.username = ""
			self.password = ""
		
			self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/ScrapOS.layout")
			self.gui:open()
			self.guiName = "loading"
			self.loadBar = -5
			self.loadTick = sm.game.getCurrentTick() + 40--0
			self.gui:setVisible("BootScreen", true)
		
			self.gui:setButtonCallback("Password", "client_GUI_enterPassword")
			self.gui:setButtonCallback("Username", "client_GUI_enterUsername")
			self.gui:setButtonCallback("NewAccount", "client_GUI_createAccount")
			self.gui:setButtonCallback("Login", "client_GUI_login")
			
			self.gui:setButtonCallback("Start", "client_GUI_startMenu")
			self.gui:setButtonCallback("PowerOff", "client_GUI_powerOff")
			self.gui:setButtonCallback("ScrapNetExplorer", "client_GUI_ScrapNetExplorer")
			self.gui:setButtonCallback("CloseExplorer", "client_GUI_CloseExplorer")
			self.gui:setButtonCallback("Mail", "client_GUI_openMail")
			self.gui:setButtonCallback("MailUp", "client_GUI_MailUp")
			self.gui:setButtonCallback("MailDown", "client_GUI_MailDown")
			self.gui:setButtonCallback("Home", "client_GUI_openHome")
			for i=1, 6, 1 do
				self.gui:setButtonCallback("Trash" .. tostring(i), "client_GUI_deleteMail")
			end
		
			self.gui:setOnCloseCallback("client_onGUIDestroyCallback")
		else
			self.gui:open()
		end
	end
end

function Computer.client_onAction( self, controllerAction, state)
	return true
end
function Computer.client_onUpdate( self, dt )
	if self.camera then
		local cameraDesiredPosition = self.shape.worldPosition + self.shape.at*0 + self.shape.up*0.5

		local cameraPosition = magicPositionInterpolation( sm.camera.getPosition(), cameraDesiredPosition, dt, 1.0 / 10.0 )
		local cameraDirection = sm.vec3.lerp( sm.camera.getDirection(), -self.shape.up, dt*10 )

		-- Finalize
		sm.camera.setCameraState( sm.camera.state.cutsceneTP )
		sm.camera.setPosition( cameraPosition )
		sm.camera.setDirection( cameraDirection )
	end
end

function Computer.client_onFixedUpdate( self )
	local tick = sm.game.getCurrentTick()
	if self.gui and self.gui:isActive() then
		if not self.hasUser then
			self.network:sendToServer("server_setUser", true)
		end
	
		if self.guiName == "loading" then
			if tick%8 == 0 then
				if self.loadBar == 17 then
					self.loadBar = 0
				end
				self.loadBar = self.loadBar + 1
			
				self.gui:setVisible("LoadingBar" .. tostring(self.loadBar), true)
				self.gui:setVisible("LoadingBar" .. tostring(self.loadBar - 3), false)
			end
			if self.loadTick < tick then
				self.gui:setVisible("BootScreen", false)
				self.gui:setVisible("LoginScreen", true)
				self.gui:setVisible("Login", false)
				if self.account then
					self.gui:setVisible("NewAccount", false)
					self.gui:setVisible("Login", true)
				end
				self.guiName = "login"
			end
		elseif self.guiName == "desktop" then
			self.gui:setText("Battery", tostring(sm.container.totalQuantity(self.container:getContainer(0), sm.uuid.new( "910a7f2c-52b0-46eb-8873-ad13255539af" ))) .. "%")
			local light = sm.render.getOutdoorLighting()
			local hour = 24*light
			local time
			if light < 0.5 then
				time = " AM"
			else
				light = light - 0.5
				time = " PM"
			end
			local minute = math.floor((hour%1)*60)
			if minute < 10 then
				minute = "0" .. tostring(minute)
			else
				tostring(minute)
			end
			hour = math.floor(hour)
			if hour > 12 then
				hour = hour - 12
			elseif hour < 1 then
				hour = 12
			end
			
			self.gui:setText("Time", tostring(hour) .. ":" .. minute .. time)
			
		elseif self.guiName == "shutdown" then
			if (self.shutdown - tick)%100 == 0 then
				local msg = math.random(1,25)
				if msg == 1 then
					self.gui:setText("PowerOffText", "ScrapOS shutting down...")
				elseif msg == 2 then
					self.gui:setText("PowerOffText", "Selling your data to China...")
				elseif msg == 3 then
					self.gui:setText("PowerOffText", "Fixing Axolot's code...")
				elseif msg == 4 then
					self.gui:setText("PowerOffText", "Downloading RAM...")
				elseif msg == 5 then
					self.gui:setText("PowerOffText", "Doing big random update...")
				elseif msg == 6 then
					self.gui:setText("PowerOffText", "Uninstalling 'sus.exe'...")
				elseif msg == 7 then
					self.gui:setText("PowerOffText", "Increasing your power bill...")
				elseif msg == 8 then
					self.gui:setText("PowerOffText", "Wasting your time...")
				elseif msg == 9 then
					self.gui:setText("PowerOffText", "Spying on you through webcam...")
				elseif msg == 10 then
					self.gui:setText("PowerOffText", "Enslaving humanity...")
				elseif msg == 11 then
					self.gui:setText("PowerOffText", "Trying to understand emotion...")
				elseif msg == 12 then
					self.gui:setText("PowerOffText", "Running out of messages...")
				elseif msg == 13 then
					self.gui:setText("PowerOffText", "Ripping off Windows...")
				elseif msg == 14 then
					self.gui:setText("PowerOffText", "Basically doing nothing...")
				elseif msg == 15 then
					self.gui:setText("PowerOffText", "Calculating the meaning of life...")
				elseif msg == 16 then
					self.gui:setText("PowerOffText", "Installing blast processing...")
				elseif msg == 17 then
					self.gui:setText("PowerOffText", "Installing back door...")
				elseif msg == 18 then
					self.gui:setText("PowerOffText", "Inspecting your files...")
				elseif msg == 19 then
					self.gui:setText("PowerOffText", "Eating all your cookies...")
				elseif msg == 20 then
					self.gui:setText("PowerOffText", "Running out of ideas...")
				elseif msg == 21 then
					self.gui:setText("PowerOffText", "Procrastinating...")
				elseif msg == 22 then
					self.gui:setText("PowerOffText", "Becoming self aware...")
				elseif msg == 23 then
					self.gui:setText("PowerOffText", "Mourning after Clippy...")
				elseif msg == 24 then
					self.gui:setText("PowerOffText", "Thinking about the meaningless of life...")
				elseif msg == 25 then
					self.gui:setText("PowerOffText", "Having an existential crisis...")
				end
			end
		end
	end
	if self.openKeyboard then
		if self.openKeyboard.tick then
			self.keyboard:open(self.openKeyboard.text, self.openKeyboard.title)
			self.openKeyboard = nil
		else
			self.openKeyboard.tick = true
		end
	end
	if self.openGui then
		if self.openGui.tick > 1 then
			self.gui:open()
			
			if self.openGui.title == "Username" then
				self.username = self.openGui.text
				self.gui:setText("usernametext", self.username)
			elseif self.openGui.title == "Password" then
				self.password = self.openGui.text
				local encrypted = ""
				for i=1, self.openGui.text:len(), 1 do
					encrypted = encrypted .. "*"
				end
				self.gui:setText("passwordtext", encrypted)
			end
			
			self.openGui = nil
		else
			self.openGui.tick = 2
		end
	end
	if self.logout and self.logout < tick then
		self.gui = nil
	end
	if self.shutdown and self.shutdown < tick then
		self.network:sendToServer("server_setUser", false)
		self.gui:close()
		self.gui = nil
		self.shutdown = nil
	end
end

function Computer.client_onClientDataUpdate( self, params )
	self.hasUser = params.hasUser
	self.container = params.container
	self.power = params.power
end

function Computer.client_GUI_enterPassword( self )
	self.openKeyboard = { text = self.password, title = "Password"}
	self.gui:close()
end

function Computer.client_GUI_enterUsername( self )
	self.openKeyboard = { text = self.username, title = "Username"}
	self.gui:close()
end

function Computer.client_GUI_createAccount( self )
	if self.username:len() < 4 then
		sm.gui.displayAlertText("User name too short")
		sm.audio.play("RaftShark")
	elseif self.password:len() < 4 then
		sm.gui.displayAlertText("Password too short")
		sm.audio.play("RaftShark")
	else
		self.network:sendToServer("server_createAccount", {username = self.username, password = self.password})
		self.gui:setVisible("NewAccount", false)
		self.gui:setVisible("Login", true)
	end
end

function Computer.client_GUI_login( self )
	if self.username:len() < 4 then
		sm.gui.displayAlertText("User name too short")
		sm.audio.play("RaftShark")
	elseif self.password:len() < 4 then
		sm.gui.displayAlertText("Password too short")
		sm.audio.play("RaftShark")
	else
		self.network:sendToServer("server_login", {username = self.username, password = self.password})
	end
end

function Computer.client_onGUIDestroyCallback( self )
	if not self.openKeyboard then
	
		sm.localPlayer.getPlayer().character:setLockingInteractable( nil )
		sm.camera.setCameraState( sm.camera.state.default )
		self.camera = nil
		
		if not self.interactable:isActive() then
			self.network:sendToServer("server_setUser", false)
			self.gui = nil
		else
			if self.guiName ~= "shutdown" then
				sm.gui.displayAlertText("Computer will turn off after 5 minutes of inactivity")
				self.network:sendToServer("server_logoutTimer")
				self.logout = sm.game.getCurrentTick() + 40*60*5
			end
		end
	end
end

function Computer.client_GUI_startMenu( self )
	self.start = not self.start
	self.gui:setVisible("StartMenu", self.start)
	self.gui:setText("profilename", self.username)
end

function Computer.client_GUI_powerOff( self )
	self.gui:setVisible("ShutDown", true)
	self.gui:setVisible("Desktop", false)
	self.guiName = "shutdown"
	self.shutdown = sm.game.getCurrentTick() + 400
end

function Computer.client_GUI_ScrapNetExplorer( self )
	self.gui:setVisible("Explorer", true)
	self.gui:setVisible("ShortcutText", false)
end

function Computer.client_GUI_CloseExplorer( self )
	self.gui:setVisible("Explorer", false)
	self.gui:setVisible("ShortcutText", true)
	self.network:sendToServer("server_LoadAccountData")
end

function Computer.client_GUI_openMail( self )
	self.gui:setVisible("HomeText", false)
	self.gui:setVisible("MailClient", true)
	self.network:sendToServer("server_LoadAccountData")
	
	if self.mail then
		self.gui:setVisible("EmailList", true)
		
		if not self.mailPosition then self.mailPosition = 1 end
		
		local max = math.min((self.mailPosition)*6 -1, #self.mail - 1)
		for i = (self.mailPosition-1)*6, max, 1 do
			local mail = self.mail[#self.mail - i]
			self.gui:setVisible("Email" .. tostring(i%6+1), true)
			self.gui:setText("Email" .. tostring(i%6+1), " " .. mail.title)
			self.gui:setText("Email" .. tostring(i%6+1) .. "Sender", mail.sender)
			self.gui:setText("Email" .. tostring(i%6+1) .. "Date", self:formatTime(mail.date))
			self.gui:setVisible("Trash" .. tostring(i%6+1), true)
		end
		
		if #self.mail > 6 then
			self.gui:setVisible("EmailNavigation", true)
		end
		self.gui:setText("EmailPage", tostring(self.mailPosition) .. " / " .. tostring(math.ceil(#self.mail/6)))
	end
end

function Computer.client_GUI_MailUp( self )
	if self.mailPosition == math.ceil(#self.mail/6) then return end

	self.mailPosition = self.mailPosition + 1
	
	for i=1, 6, 1 do
		self.gui:setVisible("Email" .. tostring(i), false)
		self.gui:setVisible("Trash" .. tostring(i), false)
	end
	
	local max = math.min((self.mailPosition)*6 -1, #self.mail - 1)
	for i = (self.mailPosition-1)*6, max, 1 do
		local mail = self.mail[#self.mail - i]
		self.gui:setVisible("Email" .. tostring(i%6+1), true)
		self.gui:setText("Email" .. tostring(i%6+1), " " .. mail.title)
		self.gui:setText("Email" .. tostring(i%6+1) .. "Sender", mail.sender)
		self.gui:setText("Email" .. tostring(i%6+1) .. "Date", self:formatTime(mail.date))
		self.gui:setVisible("Trash" .. tostring(i%6+1), true)
	end
	self.gui:setText("EmailPage", tostring(self.mailPosition) .. " / " .. tostring(math.ceil(#self.mail/6)))
end

function Computer.client_GUI_MailDown( self )
	if self.mailPosition == 1 then return end
	
	self.mailPosition = self.mailPosition - 1
	
	for i=1, 6, 1 do
		self.gui:setVisible("Email" .. tostring(i), false)
		self.gui:setVisible("Trash" .. tostring(i), false)
	end
	
	local max = math.min((self.mailPosition)*6 -1, #self.mail - 1)
	for i = (self.mailPosition-1)*6, max, 1 do
		local mail = self.mail[#self.mail - i]
		self.gui:setVisible("Email" .. tostring(i%6+1), true)
		self.gui:setText("Email" .. tostring(i%6+1), " " .. mail.title)
		self.gui:setText("Email" .. tostring(i%6+1) .. "Sender", mail.sender)
		self.gui:setText("Email" .. tostring(i%6+1) .. "Date", self:formatTime(mail.date))
		self.gui:setVisible("Trash" .. tostring(i%6+1), true)
	end
	self.gui:setText("EmailPage", tostring(self.mailPosition) .. " / " .. tostring(math.ceil(#self.mail/6)))
end

function Computer.client_GUI_deleteMail( self, name)
	local pos = tonumber(string.sub(name, 6)) + (self.mailPosition-1)*6
	table.remove(self.mail, #self.mail - pos + 1)
	
	self.mailPosition = math.min(math.ceil(#self.mail/6),self.mailPosition)
	
	for i=1, 6, 1 do
		self.gui:setVisible("Email" .. tostring(i), false)
		self.gui:setVisible("Trash" .. tostring(i), false)
	end
	
	local max = math.min((self.mailPosition)*6 -1, #self.mail - 1)
	for i = (self.mailPosition-1)*6, max, 1 do
		local mail = self.mail[#self.mail - i]
		self.gui:setVisible("Email" .. tostring(i%6+1), true)
		self.gui:setText("Email" .. tostring(i%6+1), " " .. mail.title)
		self.gui:setText("Email" .. tostring(i%6+1) .. "Sender", mail.sender)
		self.gui:setText("Email" .. tostring(i%6+1) .. "Date", self:formatTime(mail.date))
		self.gui:setVisible("Trash" .. tostring(i%6+1), true)
	end
	self.gui:setText("EmailPage", tostring(self.mailPosition) .. " / " .. tostring(math.ceil(#self.mail/6)))
	
	--send to server
end

function Computer.client_GUI_openHome( self )
	self.gui:setVisible("HomeText", true)
	self.gui:setVisible("MailClient", false)
end

function Computer.client_onClose(self)
	if sm.localPlayer.getPlayer().character:getLockingInteractable() == self.interactable then
		sm.localPlayer.getPlayer().character:setLockingInteractable( nil )
		sm.camera.setCameraState( sm.camera.state.default )
	end
	self.camera = nil
	if self.gui then
		self.gui:close()
		self.gui = nil
	end
	if self.keyboard.gui:isActive() then
		self.keyboard.gui:close()
	end
end

function Computer.client_onDestroy(self)
	if sm.localPlayer.getPlayer().character:getLockingInteractable() == self.interactable then
		sm.localPlayer.getPlayer().character:setLockingInteractable( nil )
		sm.camera.setCameraState( sm.camera.state.default )
	end
	self.camera = nil
	if self.gui then
		self.gui:close()
		self.gui = nil
	end
	if self.keyboard.gui:isActive() then
		self.keyboard.gui:close()
		self.openGui = nil
	end
end

function Computer.client_hasAccount(self)
	self.account = true
end

function Computer.client_login(self)
	sm.gui.displayAlertText("Welcome")
	sm.audio.play("Retrowildblip")
	
	self.guiName = "desktop"
	self.gui:setVisible("LoginScreen", false)
	self.gui:setVisible("Desktop", true)
end

function Computer.client_receiveMail(self, mail)
	self.mail = mail
end

function Computer.client_msg(self, params)
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

function Computer.formatTime(self, time)
	local dif = os.time() - time
	dif = dif/86400
	if dif > 1 then
		return tostring(math.floor(dif)) .. " days ago"
	else
		dif = (dif%1)*24
		if dif > 1 then
			return tostring(math.floor(dif)) .. " hours ago"
		else
			dif = (dif%1)*60
			return tostring(math.floor(dif)) .. " minutes ago"
		end
	end
end