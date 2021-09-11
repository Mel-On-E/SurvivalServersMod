TradeMachine = class( nil )

function TradeMachine.server_onCreate( self )
	--Containers: 0 - Offer, 1 - Price, 2 - Profits, 3 - Stock
	
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.owner = 0
		self.sv.saved.name = "your mum"
		self.sv.saved.sales = 0
		
		self.sv.saved.containers = {}
		local container = self.shape:getInteractable():addContainer( 0, 20, 1000 )
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		container = self.shape:getInteractable():addContainer( 1, 20, 1000 )
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		container = self.shape:getInteractable():addContainer( 2, 100, 1000 )
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		container = self.shape:getInteractable():addContainer( 3, 100, 1000 )
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		
		self.storage:save( self.sv.saved )
	else
		--fucking stupid container loading system because the game can't load in more than 1 fucking container
		sm.container.beginTransaction()
		
		local container = self.shape:getInteractable():addContainer( 1, 20, 1000 )
		for uuid, quantity in pairs(self.sv.saved.containers[1]) do
			sm.container.collect(container, sm.uuid.new(uuid), quantity, false)
		end
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		
		container = self.shape:getInteractable():addContainer( 2, 100, 1000 )
		for uuid, quantity in pairs(self.sv.saved.containers[2]) do
			sm.container.collect(container, sm.uuid.new(uuid), quantity, false)
		end
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		
		container = self.shape:getInteractable():addContainer( 3, 100, 1000 )
		for uuid, quantity in pairs(self.sv.saved.containers[3]) do
			sm.container.collect(container, sm.uuid.new(uuid), quantity, false)
		end
		container:setAllowCollect(false)
		container:setAllowSpend(false)
		
		sm.container.endTransaction()
		
		self.storage:save( self.sv.saved )
		
	
		--self.sv.saved.owner = 1 --DEBUG
	end
	self.used = false
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, sales = self.sv.saved.sales, used = self.used} )
end

function TradeMachine.client_onCreate( self )
	self.quantity = 0
end

function TradeMachine.client_onClientDataUpdate( self, params )
	self.owner = params.owner
	self.name = params.name
	self.sales = params.sales
end

function TradeMachine.client_onUpdate( self, params )
	if self.gui and self.gui:isActive() then
		self.gui:setText( "Sales", "Sales: " .. tostring(self.sales) )
		self.gui:setText( "Quantity", "Quantity: " .. tostring(2^self.quantity) )
	end
end

function TradeMachine.client_canInteract( self, character, state )
	if self.owner == 0 then
		sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Claim")
		sm.gui.setInteractionText("")
		return false
	elseif self.owner == sm.localPlayer.getPlayer().id then
		sm.gui.setInteractionText("You own this")
	else
		sm.gui.setInteractionText("Owned by", self.name)
	end
	if self.used then
		sm.gui.setInteractionText("#ff0000Machine in use")
		return false
	end
	return true
end

function TradeMachine.client_onInteract( self, character, state )
	if state == true and sm.localPlayer.getPlayer().id == self.owner then
		self.gui = {}
	
		self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/TradeMachine.layout")

		self.gui:setText("Offer", "Edit Offer")
		self.gui:setText("Price", "Edit Price")

		self.gui:setButtonCallback("Offer", "client_GUI_Offer")
		self.gui:setButtonCallback("Price", "client_GUI_Price")
		self.gui:setButtonCallback("Profits", "client_GUI_Profits")
		self.gui:setButtonCallback("Restock", "client_GUI_Restock")
		
		self.gui:setVisible("Profits", true)
		self.gui:setVisible("Restock", true)
		self.gui:setVisible("Buy", false)
		self.gui:setVisible("QuantityUp", false)
		self.gui:setVisible("QuantityDown", false)
		self.gui:setVisible("Quantity", false)
		
		--self.gui:setOnCloseCallback("client_onGUIDestroyCallback")

		self.gui:open()
	elseif state then
		self.gui = {}
	
		self.gui = sm.gui.createGuiFromLayout("$MOD_DATA/Gui/Layouts/TradeMachine.layout")

		self.gui:setText("Offer", "View Offer")
		self.gui:setText("Price", "View Price")

		self.gui:setButtonCallback("Offer", "client_GUI_Offer")
		self.gui:setButtonCallback("Price", "client_GUI_Price")
		self.gui:setButtonCallback("Buy", "client_GUI_Buy")
		self.gui:setButtonCallback("QuantityUp", "client_GUI_QuantityUp")
		self.gui:setButtonCallback("QuantityDown", "client_GUI_QuantityDown")
		
		self.gui:setVisible("Profits", false)
		self.gui:setVisible("Restock", false)
		self.gui:setVisible("Buy", true)
		self.gui:setVisible("QuantityUp", true)
		self.gui:setVisible("QuantityDown", true)
		self.gui:setVisible("Quantity", true)
		
		--self.gui:setOnCloseCallback("client_onGUIDestroyCallback")

		self.gui:open()
	end
end

function TradeMachine.client_GUI_Offer( self, params, player )
	self.network:sendToServer("server_unlockContainer", 0)
	
	self.gui:close()
	self.gui = sm.gui.createContainerGui( true )
	self.gui:setText( "UpperName", "Offer" )
	self.gui:setContainer( "UpperGrid", self.shape:getInteractable():getContainer( 0 ) )
	self.gui:setText( "LowerName", "Inventory" )
	self.gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
	self.gui:setOnCloseCallback( "cl_lockContainers" )
	self.gui:open()
end

function TradeMachine.client_GUI_Price( self, params, player )
	self.network:sendToServer("server_unlockContainer", 1)
	
	self.gui:close()
	self.gui = sm.gui.createContainerGui( true )
	self.gui:setText( "UpperName", "Price" )
	self.gui:setContainer( "UpperGrid", self.shape:getInteractable():getContainer( 1 ) )
	self.gui:setText( "LowerName", "Inventory" )
	self.gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
	self.gui:setOnCloseCallback( "cl_lockContainers" )
	self.gui:open()
end

function TradeMachine.client_GUI_Profits( self, params, player )
	self.network:sendToServer("server_unlockContainer", 2)
	
	self.gui:close()
	self.gui = sm.gui.createContainerGui( true )
	self.gui:setText( "UpperName", "Profits" )
	self.gui:setContainer( "UpperGrid", self.shape:getInteractable():getContainer( 2 ) )
	self.gui:setText( "LowerName", "Inventory" )
	self.gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
	self.gui:setOnCloseCallback( "cl_lockContainers" )
	self.gui:open()
end

function TradeMachine.client_GUI_Restock( self, params, player )
	self.network:sendToServer("server_unlockContainer", 3)
	
	self.gui:close()
	self.gui = sm.gui.createContainerGui( true )
	self.gui:setText( "UpperName", "Stock" )
	self.gui:setContainer( "UpperGrid", self.shape:getInteractable():getContainer( 3 ) )
	self.gui:setText( "LowerName", "Inventory" )
	self.gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
	self.gui:setOnCloseCallback( "cl_lockContainers" )
	self.gui:open()
end

function TradeMachine.client_GUI_QuantityUp( self, params, player )
	self.quantity = math.min(self.quantity + 1, 8)
end

function TradeMachine.client_GUI_QuantityDown( self, params, player )
	self.quantity = math.max(self.quantity - 1, 0)
end

function TradeMachine.client_GUI_Buy( self )
	self.network:sendToServer("server_buy", 2^self.quantity )
end

function TradeMachine.server_buy( self, quantity, player )
	local offer = self.shape:getInteractable():getContainer(0)
	local price = self.shape:getInteractable():getContainer(1)
	local profits = self.shape:getInteractable():getContainer(2)
	profits:setAllowCollect(true)
	local stock = self.shape:getInteractable():getContainer(3)
	stock:setAllowSpend(true)
	local inventory = player:getInventory()
	
	--No empty offers or prices
	if offer:isEmpty() or price:isEmpty() then
		self.network:sendToClient(player, "client_msg", {msg = "#ff0000Invalid Offer", sound = "RaftShark"})
		return
	end
	
	--Check stock
	local itemList = {}
	for i=0, offer:getSize() - 1, 1 do
		local item = offer:getItem(i)
		if item.quantity > 0 then
			if itemList[tostring(item.uuid)] then
				itemList[tostring(item.uuid)] = itemList[tostring(item.uuid)] + item.quantity*quantity
			else
				itemList[tostring(item.uuid)] = item.quantity*quantity
			end
		end
	end
	
	for uuid, quant in pairs(itemList) do
		if not stock:canSpend(sm.uuid.new(uuid), quant) then
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Not Enough Stock", sound = "RaftShark"})
			return 
		end
	end
	
	--Check profits storage
	local priceList = {}
	for i=0, price:getSize() - 1, 1 do
		local item = price:getItem(i)
		if item.quantity > 0 then
			if priceList[tostring(item.uuid)] then
				priceList[tostring(item.uuid)] = priceList[tostring(item.uuid)] + item.quantity*quantity
			else
				priceList[tostring(item.uuid)] = item.quantity*quantity
			end
		end
	end
	for uuid, quant in pairs(priceList) do
		if not profits:canCollect(sm.uuid.new(uuid), quant) then
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Machine full", sound = "RaftShark"})
			return 
		end
	end
	
	
	--Check inventory
	for uuid, quant in pairs(priceList) do
		if not inventory:canSpend(sm.uuid.new(uuid), quant) then
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Insuffcient Funds", sound = "RaftShark"})
			return 
		end
	end
	
	for uuid, quant in pairs(itemList) do
		if not inventory:canCollect(sm.uuid.new(uuid), quant) then
			self.network:sendToClient(player, "client_msg", {msg = "#ff0000Inventory Full", sound = "RaftShark"})
			return 
		end
	end
	
	--Make purchase
	sm.container.endTransaction() --wtf?
	sm.container.beginTransaction()
	for uuid, quant in pairs(priceList) do
		sm.container.spend(inventory, sm.uuid.new(uuid), quant, false)
	end
	for uuid, quant in pairs(itemList) do
		sm.container.spend(stock, sm.uuid.new(uuid), quant, false)
	end
	for uuid, quant in pairs(priceList) do
		sm.container.collect(profits, sm.uuid.new(uuid), quant, false)
	end	
	for uuid, quant in pairs(itemList) do
		sm.container.collect(inventory, sm.uuid.new(uuid), quant, false)
	end	
	sm.container.endTransaction()
	
	profits:setAllowCollect(false)
	stock:setAllowSpend(false)
	
	itemList = {}
	for x=0, profits:getSize() - 1, 1 do
		local item = profits:getItem(x)
		if item.quantity > 0 then
			if itemList[tostring(item.uuid)] then
				itemList[tostring(item.uuid)] = itemList[tostring(item.uuid)] + item.quantity
			else
				itemList[tostring(item.uuid)] = item.quantity
			end
		end
	end
	self.sv.saved.containers[2] = itemList
	
	itemList = {}
	for x=0, stock:getSize() - 1, 1 do
		local item = stock:getItem(x)
		if item.quantity > 0 then
			if itemList[tostring(item.uuid)] then
				itemList[tostring(item.uuid)] = itemList[tostring(item.uuid)] + item.quantity
			else
				itemList[tostring(item.uuid)] = item.quantity
			end
		end
	end
	self.sv.saved.containers[3] = itemList
	
	self.network:sendToClient(player, "client_msg", {msg = "#00ff00Purchase Successful", sound = "Retrowildblip"})
	self.sv.saved.sales = self.sv.saved.sales + quantity
	self.storage:save( self.sv.saved )
		
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, sales = self.sv.saved.sales, used = self.used} )
end


function TradeMachine.server_unlockContainer( self, id, player )
	if player.id == self.sv.saved.owner then
		local container = self.shape:getInteractable():getContainer( id )
		if id ~= 2 then
			container:setAllowCollect(true)
		end
		container:setAllowSpend(true)
		self.used = true
		self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, sales = self.sv.saved.sales, used = self.used} )
	end
end

function TradeMachine.server_lockContainers( self, id, player )
	if player.id == self.sv.saved.owner then
		for i = 0, 3, 1 do
			local container = self.shape:getInteractable():getContainer( i )
			container:setAllowCollect(false)
			container:setAllowSpend(false)
			
			if i > 0 then
				local itemList = {}
				for x=0, container:getSize() - 1, 1 do
					local item = container:getItem(x)
					if item.quantity > 0 then
						if itemList[tostring(item.uuid)] then
							itemList[tostring(item.uuid)] = itemList[tostring(item.uuid)] + item.quantity
						else
							itemList[tostring(item.uuid)] = item.quantity
						end
					end
				end
				self.sv.saved.containers[i] = itemList
			end
			
			
			
		end
		self.used = false
		self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, sales = self.sv.saved.sales, used = self.used} )
	end
	self.storage:save( self.sv.saved )
end

function TradeMachine.cl_lockContainers( self)
	self.network:sendToServer("server_lockContainers")
	self:client_onInteract({}, true)
end

function TradeMachine.client_canTinker( self, character, state )
	if self.owner == 0 then
		return true
	end
	return false
end

function TradeMachine.client_onTinker( self, character, state )
	if state == true then
		self.network:sendToServer("sv_claim")
	end	
end

function TradeMachine.sv_claim( self, params, player )
	if self.sv.saved.owner == 0 then
		self.sv.saved.owner = player.id
		self.sv.saved.name = player.name
		self.storage:save( self.sv.saved )
	end
	self.network:setClientData( { owner = self.sv.saved.owner, name = self.sv.saved.name, sales = self.sv.saved.sales, used = self.used} )
end

function TradeMachine.client_canErase(self)
	if sm.localPlayer.getPlayer().id == self.owner or self.owner == 0 then
		for i=0, 3, 1 do
			local container = self.shape:getInteractable():getContainer(0)
			if not container:isEmpty() then
				sm.gui.displayAlertText("Machine not empty")
				return false
			end
		end
		return true
	end
	sm.gui.displayAlertText("Only the owner can delete this")
	return false
end

function TradeMachine.server_canErase(self)
	if self.sv.saved.owner == 0 then return true end
	
	for k, player in pairs(sm.player.getAllPlayers()) do
		if player.id == self.sv.saved.owner then
			local char = player:getCharacter()
			if char ~= nil and sm.exists(char) then
				local offset = char:isCrouching() and 0.275 or 0.56
				local pos_offset = char.worldPosition + sm.vec3.new(0, 0, offset)
				local hit, result = sm.physics.raycast(pos_offset, pos_offset + char.direction * 7.5)
				if hit and result.type == "body" and result:getShape() == self.shape then
					for i=0, 3, 1 do
						local container = self.shape:getInteractable():getContainer(0)
						if not container:isEmpty() then
							return false
						end
					end
					return true
				end
			end
		end
	end
	return false
end

function TradeMachine.client_msg(self, params)
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