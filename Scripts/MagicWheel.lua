dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )

MagicWheel = class()
MagicWheel.maxParentCount = 1
MagicWheel.maxChildCount = 0
MagicWheel.connectionInput = sm.interactable.connectionType.power
MagicWheel.connectionOutput = sm.interactable.connectionType.none

local Uuid1_Str = "694202c3-32aa-4cd1-adc0-dcfc47b92c0d"
local Uuid2_Str = "694202c3-32aa-4cd1-adc0-dcfc47b69420"
local Uuid3_Str = "694200b1-0c50-4b74-bdc7-771374204b1f"
local Uuid4_Str = "694200b1-0c50-4b74-bdc7-771374269420"

local Uuid1 = sm.uuid.new(Uuid1_Str)
local Uuid2 = sm.uuid.new(Uuid2_Str)
local Uuid3 = sm.uuid.new(Uuid3_Str)
local Uuid4 = sm.uuid.new(Uuid4_Str)

function MagicWheel:server_onFixedUpdate(dt)
	local s_Shape = self.shape
	local s_Body = s_Shape:getBody()
	local s_WorldPos = s_Shape.worldPosition
	local s_Uuid = tostring(s_Shape.uuid)

	for _, parent in ipairs(self.interactable:getParents()) do
		local down = -1.1
		local p_Power = parent.power
		local p_SteerAngle = parent:getSteeringAngle()
		
		if s_Uuid == Uuid1_Str or s_Uuid == Uuid2_Str then
			down = -0.85
		end
		
		local valid, result = sm.physics.raycast(s_WorldPos, sm.vec3.new(0,0,down) + s_WorldPos, s_Body)

		if valid and result.type == "Body" then
			if result:getBody():isDynamic() then
				valid = false
			end
		end


		self.interactable:setPublicData( { IsGrounded = valid } )

		local Condition1 = (p_Power ~= 0 or p_SteerAngle ~= 0)
		local Condition2 = (p_Power == 0 and p_SteerAngle == 0)

		if valid and Condition1 and s_Uuid == Uuid1_Str then
			s_Shape:replaceShape(Uuid2)
		elseif (not valid or Condition2) and s_Uuid == Uuid2_Str then
			s_Shape:replaceShape(Uuid1)
		end
		
		if valid and Condition1 and s_Uuid == Uuid3_Str then
			s_Shape:replaceShape(Uuid4)
		elseif (not valid or Condition2) and s_Uuid == Uuid4_Str then
			s_Shape:replaceShape(Uuid3)
		end
	end
end

function MagicWheel:client_canInteract()
	return false
end