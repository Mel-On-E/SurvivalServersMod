RuleBook = class(nil)

local pages = 3
g_rules = nil


function RuleBook.server_onCreate(self)
	if g_rules == nil then
		local success, data = pcall(sm.json.open, "$MOD_DATA/Scripts/RuleAccept.json")
		if success and type(data) == "table" then
			g_rules = data
		end
	end
	self.network:setClientData( { rules = g_rules } )
end

function RuleBook.sv_accept(self, params, player)
	g_rules[#g_rules +1] = player.id
	sm.json.save( g_rules, "$MOD_DATA/Scripts/RuleAccept.json" )
	self.network:setClientData( { rules = g_rules } )
end

function RuleBook.client_onCreate(self)
	--use self.g_rules?
	if g_rules then
		local localId = sm.localPlayer.getPlayer().id
		for k, id in ipairs(g_rules) do
			if id == localId then
				self.accept = true
			end
		end
	end
	if not self.accept then
		self:client_onInteract(sm.localPlayer.getPlayer():getCharacter(),true)
	end
end

function RuleBook.client_onClientDataUpdate( self, params )
	self.g_rules = params.rules
end

function RuleBook.client_onInteract(self, character, state)
	if state then
		self.gui = {}
		--sm.effect.playEffect("Sensor on - Level 3", self.shape.worldPosition)
	
		self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/RuleBook.layout")

		--self.gui:setButtonCallback("Take1", "client_GUI_changeBalance")
		
		--self.gui:setText("Interest", "Daily interest: " .. self.accounts[tostring(self.playerID)].interest:sub(4,4) .. "." .. self.accounts[tostring(self.playerID)].interest:sub(5) .. "%")
		self.gui:setButtonCallback("Next", "client_Next")
		self.gui:setButtonCallback("Prev", "client_Prev")
		self.gui:setButtonCallback("AcceptRules", "client_Accept")


		self.gui:setOnCloseCallback("client_onGUIDestroyCallback")
		
		if not self.pos then
			self.pos = 1
		end
		
		self.guiUpdate = true

		self.gui:open()
	end
end

function RuleBook.client_guiUpdate(self)
	if self.gui then
		if self.gui:isActive() then
			self.gui:setText("Page", self.pos .. " / " .. pages)
			
			self.gui:setVisible("RickAstley", false)
			self.gui:setVisible("Sus", false)
			self.gui:setVisible("AcceptRules", false)
			
			if self.pos == -69 then
				self.gui:setText("PageTitle","Welcome to the server!")
				self.gui:setText("PageText","Please read the rules carefully!\n\n\n1. Never gonna give you up\n2. Never gonna let you down\n3. Never gonna run around and desert you\n4. Never gonna make you cry\n5. Never gonna say goodbye\n6. Never gonna tell a lie and hurt you")
				self.gui:setVisible("RickAstley", true)
			elseif self.pos <= 0 then
				local sus = ""
				for i=0,self.pos,-1 do
					if (-i)%16 == 0 then
						sus = sus .. " \nSUS"
					else
						sus = sus .. " SUS"
					end
				end
				self.gui:setText("PageText",sus)
				self.gui:setText("PageTitle","Welcome to the server!")
				self.gui:setVisible("Sus", true)
			elseif self.pos == 1 then
				self.gui:setText("PageTitle","Welcome to the server!")
				self.gui:setText("PageText","Please read the rules carefully!\n\n1. Be respectful to ALL players\n2. Do NOT cause lag or crashes\n3. Listen to #11ab3amoderators#ffffff\n4. Keep conversations in English\n5. Don't use modded clients\n\n#ff0000Violation of these rules will result in KICK or BAN!")
			elseif self.pos == 2 then
				self.gui:setText("PageTitle","Page 2 go brrrr!")
				self.gui:setText("PageText","Lorem ipsim dolor sit amet.")
			elseif self.pos == 3 then
				self.gui:setText("PageTitle","Accept rules?")
				self.gui:setText("PageText","By clicking the button below you accept the rules.\nAnd also the consequences for breaking them.\n\n")
				self.gui:setVisible("AcceptRules", true)
			end
		end
	end
end

function RuleBook.client_onUpdate(self)
	if self.guiUpdate and self.gui:isActive() then
		self:client_guiUpdate()
		self.guiUpdate = nil
	end
	sm.visualization.setBlockVisualization(self.shape.localPosition, true, self.shape)
end

function RuleBook:client_Next()
	self.pos = math.min(math.max(self.pos + 1, 1), pages)
	self:client_guiUpdate()
	sm.audio.play("Handbook - Turn page")
end

function RuleBook:client_Prev()
	self.pos = math.max(self.pos - 1, -69)
	self:client_guiUpdate()
	sm.audio.play("Handbook - Turn page")
end

function RuleBook:client_Accept()
	self.accept = true
	self.gui:close()
	sm.audio.play("Retrowildblip")
	self.network:sendToServer("sv_accept")
end

function RuleBook:client_onGUIDestroyCallback()
	if self.accept == nil then
		sm.audio.play("RaftShark")
		sm.gui.displayAlertText("#ff0000Accept the rules first!")
		self:client_onInteract(sm.localPlayer.getPlayer():getCharacter(),true)
	end
end