
(function()

local api = uevr.api
local vr = uevr.params.vr
local functions = uevr.params.functions

local player_controller = api:get_player_controller(0)

local relative_transform_c  = api:find_uobject("ScriptStruct /Script/CoreUObject.Transform")
local relative_transform = StructObject.new(relative_transform_c)

local vector_c = api:find_uobject("ScriptStruct /Script/CoreUObject.Vector")
local vector = StructObject.new(vector_c)

local rotator_c = api:find_uobject("ScriptStruct /Script/CoreUObject.Rotator")
local rotator = StructObject.new(rotator_c)

local kismet_math_library_c = api:find_uobject("Class /Script/Engine.KismetMathLibrary")
local kismet_math_library = kismet_math_library_c:get_class_default_object()

local fhitresult_c = api:find_uobject("ScriptStruct /Script/Engine.HitResult")
local fhitresult = StructObject.new(fhitresult_c)

local CameraComponent_c = api:find_uobject("Class /Script/Engine.CameraComponent")
local Actor_c = api:find_uobject("Class /Script/Engine.Actor")

local GameplayStatics_c = api:find_uobject("Class /Script/Engine.GameplayStatics")
local GameplayStatics = GameplayStatics_c:get_class_default_object()

	local function get_mod_value(str)

		str = tostring(vr:get_mod_value(str))
		str = str:gsub("[\r\n%z]", "")
		str = str:match("^%s*(%S+)") or ""
		return str
		
	end

local world = nil
local level = nil
local last_level = nil

local game_camera_actor = nil
local freecam_actor = nil
local freecam_component = nil
local last_game_camera_actor = nil
local last_freecam_actor = nil
local default_game_camera_actor = nil

local is_freecam = false

local deadzone = 0.15
local freecam_rotation_speed = 2
local freecam_location_speed = 10
local freecam_up_speed = 6
local freecam_dash_speed = 2
local freecam_fov = 75

print("-------- Freecam Plugin!!! --------")

uevr.sdk.callbacks.on_script_reset(function()

	if default_game_camera_actor ~= nil then
		
		player_controller = api:get_player_controller(0)
		player_controller:SetViewTargetWithBlend(default_game_camera_actor, 1.5, 2, 2.0, false, false)
		
	end
		
end)

local function game_freecam(is_enable)
	if not world and not level then return end
	
	if is_enable then
	
		local game_camera_component = game_camera_actor:GetComponentByClass(CameraComponent_c)
		
		if not game_camera_component then return end
	
		local cam_rotation = game_camera_component:K2_GetComponentRotation()
		local cam_location = game_camera_component:K2_GetComponentLocation()
		
		freecam_actor = last_freecam_actor
		
		if freecam_actor == nil then
		
			freecam_actor = GameplayStatics:BeginDeferredActorSpawnFromClass(world, Actor_c, relative_transform, 1, nil, 0)
			print("[Freecam Plugin] Freecam Actor Added!: " .. freecam_actor:get_full_name())
		
		end
		
		if freecam_actor ~= nil then
		
			freecam_component = freecam_actor:GetComponentByClass(CameraComponent_c)
			
			if freecam_component == nil then
			
				freecam_component = freecam_actor:AddComponentByClass(CameraComponent_c, false, relative_transform, false, "myfreecam")
				print("[Freecam Plugin] Freecam Component Added!: " .. freecam_component:get_full_name())
			
			end
			
			freecam_actor:K2_SetActorRotation(cam_rotation, false, fhitresult, false)
			freecam_actor:K2_SetActorLocation(cam_location, false, fhitresult, false)
			
			freecam_component:SetAbsolute(false, false, false)
			freecam_component:SetFieldOfView(freecam_fov)
			
			if not freecam_component:IsActive() then freecam_component:Activate() end
			default_game_camera_actor = game_camera_actor
			print("[Freecam Plugin] Default ViewTarget: " .. game_camera_actor:get_full_name())
			
			player_controller:SetViewTargetWithBlend(freecam_actor, 1.5, 2, 2.0, false, false)
		
		end
		
		last_freecam_actor = freecam_actor
	
	else
	
		player_controller:SetViewTargetWithBlend(default_game_camera_actor, 1.5, 2, 2.0, false, false)
	
	end
	
	is_freecam = is_enable
	print("[Freecam Plugin] Freecam Is: " .. tostring(is_enable))

end

uevr.sdk.callbacks.on_pre_engine_tick(function(engine, delta)

	player_controller = api:get_player_controller(0)
	
	world = player_controller:get_outer():get_outer()
	level = player_controller:get_outer()
	
	game_camera_actor = player_controller:GetViewTarget()
	
	if game_camera_actor ~= last_game_camera_actor then
	
		print("[Freecam Plugin] Current ViewTarget: " .. game_camera_actor:get_full_name())

		if game_camera_actor ~= freecam_actor then
		
			print("[Freecam Plugin] Default ViewTarget: " .. game_camera_actor:get_full_name())
			
			default_game_camera_actor = game_camera_actor
			is_freecam = false
			print("[Freecam Plugin] Freecam Is: false")
		
		end
		
		last_game_camera_actor = game_camera_actor
	
	end
	
	if level ~= last_level then
	
		print("[Freecam Plugin] Current Level: " .. level:get_full_name())
		
		is_freecam = false
		print("[Freecam Plugin] Freecam Is: false")
		
		freecam_actor = nil
		freecam_component = nil
		last_freecam_actor = nil
		last_level = level
	
	end

end)

local last_LEFT_THUMB = false
local last_RIGHT_THUMB = false
local leftThumbStartTime, hasTriggered

local function normalize_thumbstick(value, deadzone)
	local normalized = math.max(-1.0, math.min(1.0, value / 32767.0))
	return math.abs(normalized) > deadzone and normalized or 0.0
end

local up_speed = 0
local location_speed = 0

local lastClickTime_L = 0
local lastClickTime_R = 0
local doubleClickThreshold = 0.3
	
uevr.sdk.callbacks.on_xinput_get_state(function(retval, user_index, state)

	local gamepad = state.Gamepad
	
    local LEFT_THUMB = gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB ~= 0
    local RIGHT_THUMB = gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB ~= 0
	
	local ClickTime = os.clock()
	
	if is_freecam then
	
		local leftTrigger = gamepad.bLeftTrigger ~= 0
		local rightTrigger = gamepad.bRightTrigger ~= 0
		
		if leftTrigger then
		
			up_speed = freecam_up_speed
		
		else
		
			up_speed = 0
		
		end
		
		if rightTrigger then
		
			location_speed = freecam_location_speed * freecam_dash_speed
		
		else
		
			location_speed = freecam_location_speed
		
		end
		
		gamepad.bLeftTrigger = 0
		gamepad.bRightTrigger = 0
	
		local rx = gamepad.sThumbRX
		local ry = gamepad.sThumbRY
		local lx = gamepad.sThumbLX
		local ly = gamepad.sThumbLY
		
		local lx_norm = normalize_thumbstick(lx, deadzone)
		local ly_norm = normalize_thumbstick(ly, deadzone)
		local rx_norm = normalize_thumbstick(rx, deadzone)
		local ry_norm = normalize_thumbstick(ry, deadzone)
		
		if not freecam_actor then return end
		if not freecam_actor.K2_GetActorRotation then return end
		
		local current_rotation = freecam_actor:K2_GetActorRotation()
		local current_location = freecam_actor:K2_GetActorLocation()
		
		local forward = kismet_math_library:Multiply_VectorFloat(
			kismet_math_library:GetForwardVector(current_rotation), 
			ly_norm * location_speed
		)
		local right = kismet_math_library:Multiply_VectorFloat(
			kismet_math_library:GetRightVector(current_rotation), 
			lx_norm * location_speed
		)
		local combined_movement = kismet_math_library:Add_VectorVector(forward, right)
		
		local new_location = kismet_math_library:Add_VectorVector(
			current_location, 
			combined_movement
		)
		
		local new_pitch = current_rotation.Pitch + (ry_norm * freecam_rotation_speed)
		
		new_pitch = new_pitch > 89.0 and 89.0 or (new_pitch < -89.0 and -89.0 or new_pitch)
		local new_yaw = current_rotation.Yaw + (rx_norm * freecam_rotation_speed)
		
		local new_rotation = StructObject.new(rotator_c)
		new_rotation.Pitch = new_pitch
		new_rotation.Yaw = new_yaw
		new_rotation.Roll = current_rotation.Roll
		
		new_location.Z = new_location.Z + up_speed
		
		freecam_actor:K2_SetActorRotation(new_rotation, false, fhitresult, false)
		freecam_actor:K2_SetActorLocation(new_location, false, fhitresult, false)
		
		gamepad.sThumbRX = 0
		gamepad.sThumbRY = 0
		gamepad.sThumbLX = 0
		gamepad.sThumbLY = 0
	
	else
	
			if get_mod_value("VR_EnableGUI") == "false" then
			
				vr.set_mod_value("VR_EnableGUI", "true")
				print("[Freecam Plugin] VR_EnableGUI true!")
				
			end
	
	end
	
	if LEFT_THUMB and not last_LEFT_THUMB then
	
		if (ClickTime - lastClickTime_L) < doubleClickThreshold then
		
			vr.set_mod_value("VR_JoystickDeadzone", "0.200005")
		
		else
		
			lastClickTime_L = ClickTime
		
		end
	
	end
	
		if RIGHT_THUMB and not last_RIGHT_THUMB then
		
			if (ClickTime - lastClickTime_R) < doubleClickThreshold then
			
				--[[if get_mod_value("VR_EnableGUI") == "true" then
					vr.set_mod_value("VR_EnableGUI", "false")
					print("[Freecam Plugin] VR_EnableGUI false!")
				else
					vr.set_mod_value("VR_EnableGUI", "true")
					print("[Freecam Plugin] VR_EnableGUI true!")
				end]]
				
				game_freecam(not is_freecam)
			
			else
			
				lastClickTime_R = ClickTime
			
			end
		
		end
	
	last_LEFT_THUMB = LEFT_THUMB
	last_RIGHT_THUMB = RIGHT_THUMB
	
end)

end)()
