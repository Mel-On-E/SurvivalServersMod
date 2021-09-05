FoodMachine = class()

function FoodMachine.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer("sv_buyFood")
	end
end

function FoodMachine.client_onTinker( self, character, state )
	if state == true then
		self.network:sendToServer("sv_buyDrink")
	end
end

function FoodMachine.client_canInteract( self, character, state )
	sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Buy drink (5 WoCoins™)")
	sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use"), "Buy Soylent Scrap (10 WoCoins™)")
	return true
end

function FoodMachine.sv_buyFood( self, params, player )
	local inventory = player:getInventory()
	
	if inventory:canSpend(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), 10) then
		sm.container.beginTransaction()
		sm.container.spend(inventory, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), 10, false)
		sm.container.endTransaction()
		
		sm.event.sendToPlayer( player, "sv_e_eat", {foodGain = 50} )
		self.network:sendToClient(player, "client_msg", {sound = "Button on"})
	else
		self.network:sendToClient(player, "client_msg", {msg = "#ff0000Insufficent funds", sound = "RaftShark"})
	end
end

function FoodMachine.sv_buyDrink( self, params, player )
	local inventory = player:getInventory()
	
	if inventory:canSpend(sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), 5) then
		sm.container.beginTransaction()
		sm.container.spend(inventory, sm.uuid.new("9f0f57e8-2c31-4d83-996c-d00a9b296c3f"), 5, false)
		sm.container.endTransaction()
		
		sm.event.sendToPlayer( player, "sv_e_eat", {foodGain = 0, waterGain = 50} )
		self.network:sendToClient(player, "client_msg", {sound = "Button on"})
	else
		self.network:sendToClient(player, "client_msg", {msg = "#ff0000Insufficent funds", sound = "RaftShark"})
	end
end

function FoodMachine.client_msg(self, params)
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

