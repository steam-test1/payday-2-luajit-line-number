if _G.IS_VR then
	require("lib/units/cameras/ScopeCamera")
end

PlayerCamera = PlayerCamera or class()
PlayerCamera.IDS_NOTHING = Idstring("")

-- Lines: 12 to 42
function PlayerCamera:init(unit)
	self._unit = unit
	self._m_cam_rot = unit:rotation()
	self._m_cam_pos = unit:position() + math.UP * 140
	self._m_cam_fwd = self._m_cam_rot:y()
	self._camera_object = World:create_camera()

	self._camera_object:set_near_range(3)
	self._camera_object:set_far_range(250000)
	self._camera_object:set_fov(75)
	self:spawn_camera_unit()
	self:_setup_sound_listener()

	self._sync_dir = {
		pitch = 0,
		yaw = unit:rotation():yaw()
	}
	self._last_sync_t = 0

	self:setup_viewport(managers.player:viewport_config())

	if _G.IS_VR then
		self._scope_camera = ScopeCamera:new(self)
	end
end

-- Lines: 47 to 92
function PlayerCamera:setup_viewport(data)
	if self._vp then
		self._vp:destroy()
	end

	local dimensions = data.dimensions
	local name = "player" .. tostring(self._id)
	local vp = managers.viewport:new_vp(dimensions.x, dimensions.y, dimensions.w, dimensions.h, name)
	self._director = vp:director()
	self._shaker = self._director:shaker()

	self._shaker:set_timer(managers.player:player_timer())

	if not _G.IS_VR then
		self._camera_controller = self._director:make_camera(self._camera_object, Idstring("fps"))

		self._director:set_camera(self._camera_controller)
		self._director:position_as(self._camera_object)
		self._camera_controller:set_both(self._camera_unit)
		self._camera_controller:set_timer(managers.player:player_timer())
	end

	self._shakers = {}

	if not _G.IS_VR then
		self._shakers.breathing = self._shaker:play("breathing", 0.3)
	end

	self._shakers.headbob = self._shaker:play("headbob", 0)

	vp:set_camera(self._camera_object)

	self._vp = vp

	if false then
		vp:set_width_mul_enabled()
		vp:camera():set_width_multiplier(CoreMath.width_mul(1.7777777777777777))
		self:_set_dimensions()
	end
end

-- Lines: 94 to 96
function PlayerCamera:_set_dimensions()
	self._vp._vp:set_dimensions(0, (1 - RenderSettings.aspect_ratio / 1.7777777777777777) / 2, 1, RenderSettings.aspect_ratio / 1.7777777777777777)
end

-- Lines: 100 to 118
function PlayerCamera:spawn_camera_unit()
	local lvl_tweak_data = Global.level_data and Global.level_data.level_id and tweak_data.levels[Global.level_data.level_id]
	local unit_folder = "suit"
	self._camera_unit = World:spawn_unit(Idstring("units/payday2/characters/fps_criminals_suit_1/fps_criminals_suit_1"), self._m_cam_pos, self._m_cam_rot)
	self._machine = self._camera_unit:anim_state_machine()

	self._unit:link(self._camera_unit)
	self._camera_unit:base():set_parent_unit(self._unit)
	self._camera_unit:base():reset_properties()
	self._camera_unit:base():set_stance_instant("standard")

	if _G.IS_VR then
		self._camera_unit:set_visible(false)
	end
end

-- Lines: 122 to 123
function PlayerCamera:camera_object()
	return self._camera_object
end

-- Lines: 126 to 127
function PlayerCamera:camera_unit()
	return self._camera_unit
end

-- Lines: 132 to 133
function PlayerCamera:anim_state_machine()
	return self._camera_unit:anim_state_machine()
end

-- Lines: 138 to 140
function PlayerCamera:play_redirect(redirect_name, speed, offset_time)
	local result = self._camera_unit:base():play_redirect(redirect_name, speed, offset_time)

	return result ~= PlayerCamera.IDS_NOTHING and result
end

-- Lines: 143 to 145
function PlayerCamera:play_redirect_timeblend(state, redirect_name, offset_time, t)
	local result = self._camera_unit:base():play_redirect_timeblend(state, redirect_name, offset_time, t)

	return result ~= PlayerCamera.IDS_NOTHING and result
end

-- Lines: 150 to 152
function PlayerCamera:play_state(state_name, at_time)
	local result = self._camera_unit:base():play_state(state_name, at_time)

	return result ~= PlayerCamera.IDS_NOTHING and result
end

-- Lines: 155 to 157
function PlayerCamera:play_raw(name, params)
	local result = self._camera_unit:base():play_raw(name, params)

	return result ~= PlayerCamera.IDS_NOTHING and result
end

-- Lines: 162 to 164
function PlayerCamera:set_speed(state_name, speed)
	self._machine:set_speed(state_name, speed)
end

-- Lines: 166 to 167
function PlayerCamera:anim_data()
	return self._camera_unit:anim_data()
end

-- Lines: 174 to 176
function PlayerCamera:link_scope(camera_object, screen_object, material, texture_channel, zoom)
	self._scope_camera:link_scope(camera_object, screen_object, material, texture_channel, zoom)
end

-- Lines: 178 to 180
function PlayerCamera:unlink_scope()
	self._scope_camera:unlink_scope()
end

-- Lines: 182 to 186
function PlayerCamera:update(unit, t, dt)
	if self._scope_camera then
		self._scope_camera:update(t, dt)
	end
end

-- Lines: 192 to 204
function PlayerCamera:destroy()
	self._vp:destroy()

	self._unit = nil

	if alive(self._camera_object) then
		World:delete_camera(self._camera_object)
	end

	self._camera_object = nil

	self:remove_sound_listener()
end

-- Lines: 206 to 215
function PlayerCamera:remove_sound_listener()
	if not self._listener_id then
		return
	end

	managers.sound_environment:remove_check_object(self._sound_check_object)
	managers.listener:remove_listener(self._listener_id)
	managers.listener:remove_set("player_camera")

	self._listener_id = nil
end

-- Lines: 219 to 223
function PlayerCamera:clbk_fp_enter(aim_dir)
	if self._camera_manager_mode ~= "first_person" then
		self._camera_manager_mode = "first_person"
	end
end

-- Lines: 227 to 237
function PlayerCamera:_setup_sound_listener()
	self._listener_id = managers.listener:add_listener("player_camera", self._camera_object, self._camera_object, nil, false)

	managers.listener:add_set("player_camera", {"player_camera"})

	self._listener_activation_id = managers.listener:activate_set("main", "player_camera")
	self._sound_check_object = managers.sound_environment:add_check_object({
		primary = true,
		active = true,
		object = self._unit:orientation_object()
	})
end

-- Lines: 239 to 241
function PlayerCamera:set_default_listener_object()
	self:set_listener_object(self._camera_object)
end

-- Lines: 244 to 246
function PlayerCamera:set_listener_object(object)
	managers.listener:set_listener(self._listener_id, object, object, nil)
end

-- Lines: 250 to 251
function PlayerCamera:position()
	return self._m_cam_pos
end

-- Lines: 257 to 258
function PlayerCamera:rotation()
	return self._m_cam_rot
end

-- Lines: 264 to 265
function PlayerCamera:forward()
	return self._m_cam_fwd
end
local camera_mvec = Vector3()
local reticle_mvec = Vector3()

-- Lines: 273 to 275
function PlayerCamera:position_with_shake()
	self._camera_object:m_position(camera_mvec)

	return camera_mvec
end

-- Lines: 280 to 285
function PlayerCamera:forward_with_shake_toward_reticle(reticle_obj)
	reticle_obj:m_position(reticle_mvec)
	self._camera_object:m_position(camera_mvec)
	mvector3.subtract(reticle_mvec, camera_mvec)
	mvector3.normalize(reticle_mvec)

	return reticle_mvec
end

-- Lines: 291 to 300
function PlayerCamera:set_position(pos)
	if _G.IS_VR then
		self._camera_object:set_position(pos)
		mvector3.set(self._m_cam_pos, pos)

		return
	end

	self._camera_controller:set_camera(pos)
	mvector3.set(self._m_cam_pos, pos)
end

-- Lines: 305 to 307
function PlayerCamera:update_transform()
	self._camera_object:transform()
end
local mvec1 = Vector3()

-- Lines: 313 to 372
function PlayerCamera:set_rotation(rot)
	if _G.IS_VR then
		self._camera_object:set_rotation(rot)
	end

	mrotation.y(rot, mvec1)
	mvector3.multiply(mvec1, 100000)
	mvector3.add(mvec1, self._m_cam_pos)

	if not _G.IS_VR then
		self._camera_controller:set_target(mvec1)
	end

	mrotation.z(rot, mvec1)

	if not _G.IS_VR then
		self._camera_controller:set_default_up(mvec1)
	end

	mrotation.set_yaw_pitch_roll(self._m_cam_rot, rot:yaw(), rot:pitch(), rot:roll())
	mrotation.y(self._m_cam_rot, self._m_cam_fwd)

	local t = TimerManager:game():time()
	local sync_dt = t - self._last_sync_t
	local sync_yaw = rot:yaw()
	sync_yaw = sync_yaw % 360

	if sync_yaw < 0 then
		sync_yaw = 360 - sync_yaw
	end

	sync_yaw = math.floor((255 * sync_yaw) / 360)
	local sync_pitch = math.clamp(rot:pitch(), -85, 85) + 85
	sync_pitch = math.floor((127 * sync_pitch) / 170)
	local angle_delta = math.abs(self._sync_dir.yaw - sync_yaw) + math.abs(self._sync_dir.pitch - sync_pitch)

	if tweak_data.network then
		local update_network = tweak_data.network.camera.network_sync_delta_t < sync_dt and angle_delta > 0 or tweak_data.network.camera.network_angle_delta < angle_delta

		if self._forced_next_sync_t and t < self._forced_next_sync_t then
			update_network = false
		end

		if update_network then
			self._unit:network():send("set_look_dir", sync_yaw, sync_pitch)

			self._sync_dir.yaw = sync_yaw
			self._sync_dir.pitch = sync_pitch
			self._last_sync_t = t
		end
	end
end

-- Lines: 374 to 376
function PlayerCamera:set_forced_sync_delay(t)
	self._forced_next_sync_t = t
end

-- Lines: 380 to 385
function PlayerCamera:set_FOV(fov_value)
	self._camera_object:set_fov(fov_value)
end

-- Lines: 389 to 390
function PlayerCamera:viewport()
	return self._vp
end

-- Lines: 395 to 405
function PlayerCamera:set_shaker_parameter(effect, parameter, value)
	if not self._shakers then
		return
	end

	if self._shakers[effect] then
		self._shaker:set_parameter(self._shakers[effect], parameter, value)
	end
end

-- Lines: 410 to 415
function PlayerCamera:play_shaker(effect, amplitude, frequency, offset)
	if _G.IS_VR then
		return
	end

	return self._shaker:play(effect, amplitude or 1, frequency or 1, offset or 0)
end

-- Lines: 418 to 420
function PlayerCamera:stop_shaker(id)
	self._shaker:stop_immediately(id)
end

-- Lines: 422 to 423
function PlayerCamera:shaker()
	return self._shaker
end

