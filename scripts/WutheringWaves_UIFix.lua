
UEVR_UObjectHook.set_disabled(true)

local api = uevr.api
local m_VR = uevr.params.vr
local log_functions = uevr.params.functions

local player_controller = api:get_player_controller(0)
local local_pawn = nil

	local relative_transform_c  = api:find_uobject("ScriptStruct /Script/CoreUObject.Transform")
	local relative_transform = StructObject.new(relative_transform_c)
	
	local kismet_math_library_c = api:find_uobject("Class /Script/Engine.KismetMathLibrary")
	local kismet_math_library = kismet_math_library_c:get_class_default_object()
	
	local fhitresult_c = api:find_uobject("ScriptStruct /Script/Engine.HitResult")
	local fhitresult = StructObject.new(fhitresult_c)

	local vector_c = api:find_uobject("ScriptStruct /Script/CoreUObject.Vector")
	local vector = StructObject.new(vector_c)

	local vector2d_c = api:find_uobject("ScriptStruct /Script/CoreUObject.Vector2D")
	local vector2d = StructObject.new(vector2d_c)

	local rotator_c = api:find_uobject("ScriptStruct /Script/CoreUObject.Rotator")
	local rotator = StructObject.new(rotator_c)

	local UIItem_c = api:find_uobject("Class /Script/LGUI.UIItem")
	local LGUICanvas_c = api:find_uobject("Class /Script/LGUI.LGUICanvas")
	local LGUICanvasScaler_c = api:find_uobject("Class /Script/LGUI.LGUICanvasScaler")
	local LGUISettings_c = api:find_uobject("Class /Script/LGUI.LGUISettings")
	local ScreenSpace_c = api:find_uobject("Class /Script/LGUI.LGUIScreenSpaceInteraction")
	local WorldSpace_c = api:find_uobject("Class /Script/LGUI.LGUIWorldSpaceInteraction")
	local LGUIBehaviour_c = api:find_uobject("Class /Script/LGUI.LGUIBehaviour")
	local ScreenSpaceUIMouseRayemitter_c = api:find_uobject("Class /Script/LGUI.LGUI_ScreenSpaceUIMouseRayemitter")
	local MainViewportMouseRayEmitter_c = api:find_uobject("Class /Script/LGUI.LGUI_MainViewportMouseRayEmitter")
	local UIContainerActor_c = api:find_uobject("Class /Script/LGUI.UIContainerActor")
	local UIDrawcallMesh_c = api:find_uobject("Class /Script/LGUI.UIDrawcallMesh")
	local PointerEventData_c = api:find_uobject("Class /Script/LGUI.LGUIPointerEventData")
	local TraceBaseElement_c = api:find_uobject("Class /Script/KuroData.TraceBaseElement")
	local CameraComponent_c = api:find_uobject("Class /Script/Engine.CameraComponent")
	local SceneComponent_c = api:find_uobject("Class /Script/Engine.SceneComponent")
	local Actor_c = api:find_uobject("Class /Script/Engine.Actor")
	local PrimitiveComponent_c = api:find_uobject("Class /Script/Engine.PrimitiveComponent")

	local ScreenSpace = nil
	local LGUICanvasScaler = nil
	local PointerEventData = nil
	
	local ScreenSpaceActor = nil
	local IsUIToWorld = false
	
	local dialog_detection
	local IsUIInteraction = false
	local CA_IsUIInteraction = false
	local IsDialogue = false
	local IsPaused = true
	
	print("-------------------")
	
	local function get_mod_value(str)

		str = tostring(m_VR:get_mod_value(str))
		str = str:gsub("[\r\n%z]", "")
		str = str:match("^%s*(%S+)") or ""
		return str
		
	end
	
	local function SetUIToWorld()
	
		ScreenSpace = UEVR_UObjectHook.get_first_object_by_class(ScreenSpace_c)
		LGUICanvasScaler = UEVR_UObjectHook.get_first_object_by_class(LGUICanvasScaler_c)
		PointerEventData = UEVR_UObjectHook.get_first_object_by_class(PointerEventData_c)
		
		ScreenSpaceActor = ScreenSpace:get_outer()
	
		if LGUICanvasScaler.Canvas:GetRenderMode() == 0 then -- Fix and force UI to be redrawn
			
			local LGUICanvas_arr = LGUICanvas_c:get_objects_matching(false)
			local UIDrawcallMesh_arr = UIDrawcallMesh_c:get_objects_matching(false)
			
			for i, nObj in ipairs(UIDrawcallMesh_arr) do

				nObj:SetVisibility(false, true)

			end
		
			for i, nObj in ipairs(LGUICanvas_arr) do

				nObj:SetRenderMode(0)

			end
				
			for i, nObj in ipairs(LGUICanvas_arr) do

				nObj:SetRenderMode(1)

			end
			
			print("Render Mode Changed!")
			log_functions.log_warn("LuaUIFix: Render Mode Changed!")
		
		end
		
		local scaleValueX = 0.12
		local scaleValueY = 0.12
		local scaleValueZ = 0.12

		ScreenSpaceActor:SetActorScale3D(Vector3d.new(scaleValueX, scaleValueY, scaleValueZ))
		
		print("UIItem Size", ScreenSpaceActor.UIItem:GetWidth(), ScreenSpaceActor.UIItem:GetHeight())
		log_functions.log_warn("LuaUIFix: UIItem Size " .. tostring(ScreenSpaceActor.UIItem:GetWidth()) .. "x" .. tostring(ScreenSpaceActor.UIItem:GetHeight()))
		
		IsUIToWorld = true
		
		print("SetUIToWorld Called!")
		log_functions.log_warn("LuaUIFix: SetUIToWorld Called!")
		
	end

local default_view_target = nil
local last_view_target = nil
local last_view_target_name = "BP_CharacterController_C"
local view_target_name = ""
local df_view_target_name = ""
local camera_actor = player_controller:GetViewTarget()
local camera_component = nil

local last_execution_time = 0
local last_drag_time = 0
local should_execute = false
local IsFOVdefined = false

local hud_actor = nil
local current_hud_actor = nil

local function setCameraComponent(camera_actor)

	hud_actor = player_controller:GetHUD()
	
		if hud_actor ~= nil then
		
			camera_component = hud_actor:GetComponentByClass(CameraComponent_c)
			
			if camera_component == nil then
			
				camera_component = hud_actor:AddComponentByClass(CameraComponent_c, false, relative_transform, false, "MyCameraComponent")
				
				print("new CameraComponent added!")
				log_functions.log_warn("LuaUIFix: new CameraComponent added!")
			
			end
			
			if not camera_component:IsActive() then camera_component:Activate() end
			
				--camera_component:SetFieldOfView(120)
				camera_component:SetFieldOfView(76)
			
				default_view_target = camera_actor
				log_functions.log_warn("LuaUIFix: default_view_target " .. default_view_target:get_full_name())
				
				player_controller:SetViewTargetWithBlend(hud_actor, 0, 0, 0, false,false)
		
		end

end

local ui_rotation = StructObject.new(rotator_c)
local forward_vector = nil
local new_location = nil

local t_rotation = nil
local t_location = nil

local df_rotation = nil
local df_location = nil

local hud_rotation = nil
local hud_location = nil

local isCameraFixed = false
local ZoomValue = 150
local ZOffset = 30

local start_timer = 0
local first_CameraActor = false

--[[uevr.sdk.callbacks.on_post_engine_tick(function(engine, delta)

	if PointerEventData ~= nil and IsUIToWorld then
	
		if PointerEventData.isDragging then
		
			if os.time() - last_drag_time >= 0.5 then
			
				--PointerEventData.eventType = 7
				--PointerEventData.nowIsTriggerPressed = false
				--PointerEventData.isDragging = false
				
				last_drag_time = os.time()
				
			end
			
		end
		
	end

end)]]

local hook_started = false
local UIDistanceDialog = 50
local UIHeightDialog = 10

local first_recenter = nil
local first_recenter_counter = 0

local is_freecam = false

uevr.sdk.callbacks.on_pre_engine_tick(function(engine, delta)

	player_controller = api:get_player_controller(0)

	camera_actor = player_controller:GetViewTarget()
	
	view_target_name = string.sub(camera_actor:get_full_name(), 0, 11)
	
	if string.sub(view_target_name, 0, 5) == "Actor" then
		is_freecam = true
	else
		is_freecam = false
	end
	
	if IsUIToWorld then
	
		current_hud_actor = player_controller:GetHUD()
		
		if current_hud_actor ~= nil then
		
			if current_hud_actor ~= hud_actor then
			
				setCameraComponent(camera_actor)
			
			end
		
		end
	
	end
	
	if view_target_name == "DefaultPawn" then
	
		if get_mod_value("VR_2DScreenMode") == "false" then
		
			m_VR.set_mod_value("VR_2DScreenMode", "true")
		
		end
		
		first_recenter = os.time()
		
		m_VR.set_mod_value("VR_SnapturnJoystickDeadzone", 0.200000)
		
	end
	
	if first_recenter ~= nil then
	
		if os.time() - first_recenter >= 3 then
		
			m_VR.recenter_view()
			m_VR.recenter_horizon()
			
			first_recenter = os.time()
			
			first_recenter_counter = first_recenter_counter + 1
			
			if first_recenter_counter >= 10 then
			
				first_recenter = nil
			
			end
			
			log_functions.log_warn("LuaUIFix: first_recenter " .. tostring(first_recenter_counter))
		
		end
	
	end
	
	if camera_actor ~= last_view_target then
	
		--if last_view_target ~= nil then last_view_target_name = string.sub(last_view_target:get_full_name(), 0, 11) end
	
		if IsUIToWorld then
		
			if string.sub(view_target_name, 0, 3) ~= "HUD" and not is_freecam then
			
				default_view_target = camera_actor
				log_functions.log_warn("LuaUIFix: default_view_target " .. default_view_target:get_full_name())
				
				player_controller:SetViewTargetWithBlend(hud_actor, 0, 0, 0, false,false)
			
			end
			
		end
	
		print("Current ViewTarget", camera_actor:get_full_name())
		log_functions.log_warn("LuaUIFix: Current ViewTarget " .. camera_actor:get_full_name())
		
		last_view_target = camera_actor
		
	end
	
	if default_view_target ~= nil then
	
		df_view_target_name = string.sub(default_view_target:get_fname():to_string(), 0, 11)
	
		if IsUIToWorld and isCameraFixed and df_view_target_name == "CameraActor" and not IsUIInteraction then
			
				local_pawn = api:get_local_pawn(0)
			
				t_rotation = default_view_target:K2_GetActorRotation()
				t_location = local_pawn:K2_GetActorLocation()
				
				forward_vector = kismet_math_library:Conv_RotatorToVector(t_rotation)
				new_location = t_location - (forward_vector * ZoomValue)
				
				new_location.Z = new_location.Z + ZOffset
				
				hud_actor:K2_SetActorRotation(t_rotation, false, fhitresult, false)
				
				new_location.Z = kismet_math_library:FInterpTo(hud_actor:K2_GetActorLocation().Z, new_location.Z, delta, 10)
				hud_actor:K2_SetActorLocation(new_location, false, fhitresult, false)
				
				forward_vector = kismet_math_library:Conv_RotatorToVector(t_rotation)
				new_location = new_location + (forward_vector * 200)
				
				ui_rotation.Pitch = 0
				ui_rotation.Yaw = t_rotation.Yaw + 90
				ui_rotation.Roll = t_rotation.Pitch - 90
				
				ScreenSpaceActor:K2_SetActorRotation(ui_rotation, false, fhitresult, false)
				
				if is_freecam then new_location.Z = -500; end
				
				ScreenSpaceActor:K2_SetActorLocation(kismet_math_library:VInterpTo(ScreenSpaceActor:K2_GetActorLocation(), new_location, delta, 60), false, fhitresult, false)
		
		elseif IsUIToWorld and IsUIInteraction then
		
			df_rotation = default_view_target:K2_GetActorRotation()
			df_location = default_view_target:K2_GetActorLocation()
			
			df_rotation.Roll = 0
			
				forward_vector = kismet_math_library:Conv_RotatorToVector(df_rotation)
				new_location = df_location - (forward_vector * UIDistanceDialog)
				
				new_location.Z = new_location.Z + UIHeightDialog
				
				hud_actor:K2_SetActorRotation(df_rotation, false, fhitresult, false)
				hud_actor:K2_SetActorLocation(new_location, false, fhitresult, false)
			
			hud_location = hud_actor:K2_GetActorLocation()
			
			forward_vector = kismet_math_library:Conv_RotatorToVector(df_rotation)
			new_location = hud_location + (forward_vector * 200)
			
			ui_rotation.Pitch = 0
			ui_rotation.Yaw = df_rotation.Yaw + 86
			ui_rotation.Roll = df_rotation.Pitch - 90
			
			ScreenSpaceActor:K2_SetActorRotation(ui_rotation, false, fhitresult, false)
			
			if is_freecam then new_location.Z = -500; end
					
			ScreenSpaceActor:K2_SetActorLocation(kismet_math_library:VInterpTo(ScreenSpaceActor:K2_GetActorLocation(), new_location, delta, 60), false, fhitresult, false)
		
		elseif IsUIToWorld then
		
			df_rotation = default_view_target:K2_GetActorRotation()
			df_location = default_view_target:K2_GetActorLocation()
			
			hud_actor:K2_SetActorRotation(df_rotation, false, fhitresult, false)
			hud_actor:K2_SetActorLocation(df_location, false, fhitresult, false)
			
			forward_vector = kismet_math_library:Conv_RotatorToVector(df_rotation)
			new_location = df_location + (forward_vector * 200)
			
			ui_rotation.Pitch = 0
			ui_rotation.Yaw = df_rotation.Yaw + 90
			ui_rotation.Roll = df_rotation.Pitch - 90
			
			ScreenSpaceActor:K2_SetActorRotation(ui_rotation, false, fhitresult, false)
			
			if is_freecam then new_location.Z = -500; end
					
			ScreenSpaceActor:K2_SetActorLocation(kismet_math_library:VInterpTo(ScreenSpaceActor:K2_GetActorLocation(), new_location, delta, 60), false, fhitresult, false)
		
		end
	
	end
	
    if not first_CameraActor and not IsUIToWorld and view_target_name == "CameraActor" then
	
		first_CameraActor = true
		start_timer = os.time()
			
    elseif not first_CameraActor and not IsUIToWorld and get_mod_value("VR_SnapturnJoystickDeadzone") == "0.200001" then
	
		first_CameraActor = true
		start_timer = os.time()
		
	end
	
	if first_CameraActor then
	
		if os.time() - start_timer >= 3 then
		
			if not hook_started then
			
				dialog_detection()
				
				print("hook_started!")
				log_functions.log_warn("LuaUIFix: hook_started!")
				
				hook_started = true
				
			end
			
			local MediaPlayer = api:find_uobject("MediaPlayer /Game/Aki/UI/UIResources/UiPlot/VideoPlayer/CommonVideoPlayer.CommonVideoPlayer")
			
			local IsPlaying = false
			
			if MediaPlayer ~= nil then
			
				IsPlaying = MediaPlayer:IsPlaying()
			
			end
		
			if not IsPlaying then
			
					setCameraComponent(camera_actor)

					if get_mod_value("VR_2DScreenMode") == "true" then
					
						m_VR.set_mod_value("VR_2DScreenMode", "false")
					
					end
					
					SetUIToWorld()
					
					first_CameraActor = false
					
					m_VR.set_mod_value("VR_SnapturnJoystickDeadzone", 0.200001)
			
			end
			
			start_timer = os.time()
		
		end
	
	end
	
	if not IsFOVdefined and IsUIToWorld then
	
        if not should_execute then
		
            should_execute = true
            last_execution_time = os.time()
			
        elseif os.time() - last_execution_time >= 3 then
		
            m_VR.recenter_view()
            m_VR.recenter_horizon()
			
			print("UI_Distance", get_mod_value("UI_Distance"))
			print("VR_WorldScale", get_mod_value("VR_WorldScale"))
			print("CameraFOV", camera_component.FieldOfView)
			
			log_functions.log_warn("LuaUIFix: UI_Distance " .. get_mod_value("UI_Distance"))
			log_functions.log_warn("LuaUIFix: VR_WorldScale " .. get_mod_value("VR_WorldScale"))
			log_functions.log_warn("LuaUIFix: CameraFOV " .. camera_component.FieldOfView)
			
			IsFOVdefined = true
			
        end
		
	end

end)

local last_RIGHT_SHOULDER = false
local rouletteInteraction = false

uevr.sdk.callbacks.on_xinput_get_state(function(retval, user_index, state)

	player_controller = api:get_player_controller(0)
	camera_actor = player_controller:GetViewTarget()
	
	local bShowMouse = player_controller.bShowMouseCursor
	
	if default_view_target ~= nil then
	
		df_view_target_name = string.sub(default_view_target:get_fname():to_string(), 0, 11)
		
	end

    local gamepad = state.Gamepad
	
	local DPAD_UP = gamepad.wButtons & XINPUT_GAMEPAD_DPAD_UP ~= 0
	local DPAD_DOWN = gamepad.wButtons & XINPUT_GAMEPAD_DPAD_DOWN ~= 0
	local DPAD_LEFT = gamepad.wButtons & XINPUT_GAMEPAD_DPAD_LEFT ~= 0
	local DPAD_RIGHT = gamepad.wButtons & XINPUT_GAMEPAD_DPAD_RIGHT ~= 0
	local START = gamepad.wButtons & XINPUT_GAMEPAD_START ~= 0
	local BACK = gamepad.wButtons & XINPUT_GAMEPAD_BACK ~= 0
	local LEFT_THUMB = gamepad.wButtons & XINPUT_GAMEPAD_LEFT_THUMB ~= 0
	local RIGHT_THUMB = gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_THUMB ~= 0
	local LEFT_SHOULDER = gamepad.wButtons & XINPUT_GAMEPAD_LEFT_SHOULDER ~= 0
	local RIGHT_SHOULDER = gamepad.wButtons & XINPUT_GAMEPAD_RIGHT_SHOULDER ~= 0
	local GAMEPAD_Y = gamepad.wButtons & XINPUT_GAMEPAD_Y ~= 0
	local GAMEPAD_X = gamepad.wButtons & XINPUT_GAMEPAD_X ~= 0
	local GAMEPAD_A = gamepad.wButtons & XINPUT_GAMEPAD_A ~= 0
	local GAMEPAD_B = gamepad.wButtons & XINPUT_GAMEPAD_B ~= 0
	
	if not RIGHT_SHOULDER then -- Walk mode
		local max_speed = 12000
		
		local thumb_x = gamepad.sThumbLX
		local thumb_y = gamepad.sThumbLY
		
		local magnitude = math.sqrt(thumb_x^2 + thumb_y^2)
		
		if magnitude > max_speed then
			local ratio = max_speed / magnitude
			thumb_x = thumb_x * ratio
			thumb_y = thumb_y * ratio
		end
		
		gamepad.sThumbLX = thumb_x
		gamepad.sThumbLY = thumb_y
	end
	
	if RIGHT_THUMB and LEFT_SHOULDER then
	
		rouletteInteraction = true
	
	else
	
		rouletteInteraction = false
	
	end
	
	local leftTrigger = gamepad.bLeftTrigger ~= 0
	local rightTrigger = gamepad.bRightTrigger ~= 0
	
    if IsUIToWorld and df_view_target_name == "CameraActor" then

		if LEFT_THUMB then
			
			if RIGHT_SHOULDER then
			
				state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_RIGHT_SHOULDER
			
				if not last_RIGHT_SHOULDER then
					isCameraFixed = not isCameraFixed
					print("isCameraFixed Changed!")
					
				end
			
			end
			
			if GAMEPAD_X and isCameraFixed then
			
				state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_X
				ZOffset = ZOffset - 1
			
			end
			
			if GAMEPAD_Y and isCameraFixed then
			
				state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_Y
				ZOffset = ZOffset + 1
			
			end
			
		end
		
		if LEFT_SHOULDER then
		
			if leftTrigger and isCameraFixed then
			
				state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_LEFT_SHOULDER
				ZoomValue = ZoomValue + 2
			
			end
			
			if rightTrigger and isCameraFixed then
			
				state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_LEFT_SHOULDER
				ZoomValue = ZoomValue - 2
			
			end
		
		end
		
	end
	
		if LEFT_THUMB then
		
			if GAMEPAD_A then
			
				state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_A
				
			end
			
		end
		
		if IsUIInteraction and not rouletteInteraction then
		
			if leftTrigger then UIDistanceDialog = UIDistanceDialog - 2 end
			if rightTrigger then UIDistanceDialog = UIDistanceDialog + 2 end
			
			state.Gamepad.bLeftTrigger = 0
			state.Gamepad.bRightTrigger = 0
			
			if LEFT_SHOULDER then UIHeightDialog = UIHeightDialog - 2 end
			if RIGHT_SHOULDER then UIHeightDialog = UIHeightDialog + 2 end
			
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_LEFT_SHOULDER
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_RIGHT_SHOULDER
		
		end
		
		last_RIGHT_SHOULDER = RIGHT_SHOULDER
	
	-- Blocking gamepad commands
	
	if IsUIToWorld then
	
		if df_view_target_name ~= "CameraActor" or IsDialogue or bShowMouse or CA_IsUIInteraction or rouletteInteraction then
		
			--[[state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_A
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_B
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_X
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_Y
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_DPAD_UP
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_DPAD_DOWN
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_DPAD_LEFT
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_DPAD_RIGHT
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_START
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_BACK
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_LEFT_THUMB
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_RIGHT_THUMB
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_LEFT_SHOULDER
			state.Gamepad.wButtons = state.Gamepad.wButtons & ~XINPUT_GAMEPAD_RIGHT_SHOULDER

			state.Gamepad.bLeftTrigger = 0
			state.Gamepad.bRightTrigger = 0

			state.Gamepad.sThumbLX = 0
			state.Gamepad.sThumbLY = 0
			state.Gamepad.sThumbRX = 0
			state.Gamepad.sThumbRY = 0]]
			
			IsUIInteraction = true
			
			if get_mod_value("FrameworkConfig_AlwaysShowCursor") == "false" and not is_freecam then
			
				m_VR.set_mod_value("FrameworkConfig_AlwaysShowCursor", "true")
				print('IsUIInteraction', IsUIInteraction)
				
				IsPaused = true
				print('IsPaused', IsPaused)
				log_functions.log_warn("LuaUIFix: IsPaused true")
				
				UIDistanceDialog = 50
				UIHeightDialog = 10
				
				print('UIDistanceDialog', UIDistanceDialog)
			
			elseif get_mod_value("FrameworkConfig_AlwaysShowCursor") == "true" and is_freecam then
			
				m_VR.set_mod_value("FrameworkConfig_AlwaysShowCursor", "false")
			
			end
		
		else
		
			IsUIInteraction = false
			
			if get_mod_value("FrameworkConfig_AlwaysShowCursor") == "true" then
			
				m_VR.set_mod_value("FrameworkConfig_AlwaysShowCursor", "false")
				print('IsUIInteraction', IsUIInteraction)
			
			end
		
		end
	
	end
	
			if get_mod_value("FrameworkConfig_AlwaysShowCursor") == "true" and is_freecam then
			
				m_VR.set_mod_value("FrameworkConfig_AlwaysShowCursor", "false")
			
			end
	
end)

local IsDialogueHook = nil
local IsNotDialogHook = nil

function dialog_detection()

	IsDialogueHook = LGUIBehaviour_c:find_function("OnEnableBP")

	if IsDialogueHook ~= nil then

		IsDialogueHook:set_function_flags(IsDialogueHook:get_function_flags() | 0x400)
		IsDialogueHook:hook_ptr(function(fn, obj, locals, result)

			if obj:get_class():get_full_name() == "Class /Script/LGUI.UIExtendToggleSpriteTransition" then
			
				if obj.TransitionState.CheckedHoverState.Sprite:get_fname():to_string() == "SP_PlotSkipBgIcon1" then
					
					IsDialogue = true
					IsUIInteraction = true
					print('IsDialogue', IsDialogue)
					log_functions.log_warn("LuaUIFix: IsDialogue true")
					
				end
				
			end
			
			if not IsDialogue then
			
				if obj:get_class():get_full_name() == "Class /Script/LGUI.UISpriteTransition" then
				
					if obj.TransitionInfo.PressedTransition.Sprite:get_full_name() == 
					   "LGUITexturePackerSpriteData /Game/Aki/UI/UIResources/Common/Atlas/SP_BtnBack.SP_BtnBack" then
						
						CA_IsUIInteraction = true
						
					end
					
				end
			
			end

			return false
		end)
		
	end
	
	IsNotDialogHook = LGUIBehaviour_c:find_function("OnDestroyBP")

	if IsNotDialogHook ~= nil then

		IsNotDialogHook:set_function_flags(IsNotDialogHook:get_function_flags() | 0x400)
		IsNotDialogHook:hook_ptr(function(fn, obj, locals, result)

			if obj:get_class():get_full_name() == "Class /Script/LGUI.UIExtendToggleSpriteTransition" then
			
				if obj.TransitionState.CheckedHoverState.Sprite:get_fname():to_string() == "SP_PlotSkipBgIcon1" then
					
					IsDialogue = false
					IsUIInteraction = false
					print('IsDialogue', IsDialogue)
					log_functions.log_warn("LuaUIFix: IsDialogue false")
					
				end
				
			end
			
			if not IsDialogue then
			
				if obj:get_class():get_full_name() == "Class /Script/LGUI.UISpriteTransition" then
				
					if obj.TransitionInfo.PressedTransition.Sprite:get_full_name() == 
					   "LGUITexturePackerSpriteData /Game/Aki/UI/UIResources/Common/Atlas/SP_BtnBack.SP_BtnBack" then
						
						CA_IsUIInteraction = false
						
					end
					
				end
			
			end

			return false
		end)
		
	end
	
end

	uevr.sdk.callbacks.on_script_reset(function()

		if IsDialogueHook ~= nil then
			IsDialogueHook:set_function_flags(IsDialogueHook:get_function_flags() & ~0x400)
		end
		
		if IsNotDialogHook ~= nil then
			IsNotDialogHook:set_function_flags(IsNotDialogHook:get_function_flags() & ~0x400)
		end
		
		if IsUIToWorld and default_view_target then
		
			player_controller = api:get_player_controller(0)
			player_controller:SetViewTargetWithBlend(default_view_target, 0, 0, 0, false,false)
		
		end
		
	end)

--[[m_VR.set_mod_value("VR_RenderingMethod", 1)
m_VR.set_mod_value("VR_AimMethod", 0)
m_VR.set_mod_value("VR_DecoupledPitch", "false")
m_VR.set_mod_value("VR_DecoupledPitchUIAdjust", "true")
m_VR.set_mod_value("FrameworkConfig_AlwaysShowCursor", "true")
m_VR.set_mod_value("UI_Distance", 1.007000)
m_VR.set_mod_value("VR_WorldScale", 2.000000)]]

m_VR.set_mod_value("VR_RenderingMethod", 1)
m_VR.set_mod_value("VR_AimMethod", 0)
m_VR.set_mod_value("VR_DecoupledPitch", "false")
m_VR.set_mod_value("VR_DecoupledPitchUIAdjust", "true")
m_VR.set_mod_value("FrameworkConfig_AlwaysShowCursor", "true")
m_VR.set_mod_value("UI_Distance", 2.313000)
m_VR.set_mod_value("VR_WorldScale", 0.875000)