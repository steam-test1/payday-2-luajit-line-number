local tmp_rot1 = Rotation()
UnitNetworkHandler = UnitNetworkHandler or class(BaseNetworkHandler)

-- Lines: 5 to 51
function UnitNetworkHandler:set_unit(unit, character_name, outfit_string, outfit_version, peer_id, team_id)
	print("[UnitNetworkHandler:set_unit]", unit, character_name, peer_id)
	Application:stack_dump()

	if not alive(unit) then
		return
	end

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if peer_id == 0 then
		local loadout = managers.blackmarket:unpack_henchman_loadout_string(outfit_string)

		managers.blackmarket:verfify_recived_crew_loadout(loadout, true)

		local crim_data = managers.criminals:character_data_by_name(character_name)

		if not crim_data or not crim_data.ai then
			managers.criminals:add_character(character_name, unit, peer_id, true, loadout)
		else
			managers.criminals:set_unit(character_name, unit, loadout)
		end

		unit:movement():set_character_anim_variables()

		return
	end

	local peer = managers.network:session():peer(peer_id)

	if not peer then
		return
	end

	if peer ~= managers.network:session():local_peer() then
		peer:set_outfit_string(outfit_string, outfit_version)
	end

	peer:set_unit(unit, character_name)
	self:_chk_flush_unit_too_early_packets(unit)
end

-- Lines: 55 to 60
function UnitNetworkHandler:switch_weapon(unit, unequip_multiplier, equip_multiplier, sender)
	if not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:movement():sync_switch_weapon(unequip_multiplier, equip_multiplier)
end

-- Lines: 64 to 75
function UnitNetworkHandler:set_equipped_weapon(unit, item_index, blueprint_string, cosmetics_string, sender)
	if not self._verify_character(unit) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	unit:inventory():synch_equipped_weapon(item_index, blueprint_string, cosmetics_string, peer)
end

-- Lines: 77 to 82
function UnitNetworkHandler:set_weapon_gadget_state(unit, gadget_state, sender)
	if not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:inventory():synch_weapon_gadget_state(gadget_state)
end

-- Lines: 85 to 90
function UnitNetworkHandler:set_weapon_gadget_color(unit, red, green, blue, sender)
	if not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:inventory():sync_weapon_gadget_color(Color(red / 255, green / 255, blue / 255))
end

-- Lines: 93 to 97
function UnitNetworkHandler:first_aid_kit_sync(unit, min_distance)
	if min_distance ~= 0 then
		unit:base():sync_auto_recovery(min_distance)
	end
end

-- Lines: 101 to 112
function UnitNetworkHandler:set_look_dir(unit, yaw_in, pitch_in, sender)
	if not self._verify_character_and_sender(unit, sender) then
		return
	end

	local dir = Vector3()
	local yaw = (360 * yaw_in) / 255
	local pitch = math.lerp(-85, 85, pitch_in / 127)
	local rot = Rotation(yaw, pitch, 0)

	mrotation.y(rot, dir)
	unit:movement():sync_look_dir(dir)
end

-- Lines: 116 to 171
function UnitNetworkHandler:action_walk_start(unit, first_nav_point, nav_link_yaw, nav_link_act_index, from_idle, haste_code, end_yaw, no_walk, no_strafe, pose_code, end_pose_code)
	if not self._verify_character(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local end_rot = nil

	if end_yaw ~= 0 then
		end_rot = Rotation((360 * (end_yaw - 1)) / 254, 0, 0)
	end

	local nav_path = {}

	if nav_link_act_index ~= 0 then
		local nav_link_rot = (360 * nav_link_yaw) / 255
		local nav_link = unit:movement()._actions.walk.synthesize_nav_link(first_nav_point, nav_link_rot, unit:movement()._actions.act:_get_act_name_from_index(nav_link_act_index), from_idle)

		-- Lines: 129 to 130
		nav_link.element.value = function (element, name)
			return element[name]
		end

		-- Lines: 130 to 131
		nav_link.element.nav_link_wants_align_pos = function (element)
			return element.from_idle
		end

		table.insert(nav_path, nav_link)
	else
		table.insert(nav_path, first_nav_point)
	end

	local pose = nil

	if pose_code == 1 then
		pose = "stand"
	elseif pose_code == 2 then
		pose = "crouch"
	end

	local end_pose = nil

	if end_pose_code == 1 then
		end_pose = "stand"
	elseif end_pose_code == 2 then
		end_pose = "crouch"
	end

	local action_desc = {
		path_simplified = true,
		type = "walk",
		persistent = true,
		body_part = 2,
		variant = haste_code == 1 and "walk" or "run",
		end_rot = end_rot,
		nav_path = nav_path,
		no_walk = no_walk,
		no_strafe = no_strafe,
		pose = pose,
		end_pose = end_pose,
		blocks = {
			act = -1,
			idle = -1,
			turn = -1,
			walk = -1
		}
	}

	unit:movement():action_request(action_desc)
end

-- Lines: 175 to 180
function UnitNetworkHandler:action_walk_nav_point(unit, nav_point, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_walk_nav_point(nav_point)
end

-- Lines: 182 to 187
function UnitNetworkHandler:player_action_walk_nav_point(unit, nav_point, speed, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_walk_nav_point(nav_point, speed)
end

-- Lines: 192 to 197
function UnitNetworkHandler:action_change_run(unit, is_running, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_change_run(is_running)
end

-- Lines: 201 to 206
function UnitNetworkHandler:action_change_speed(unit, speed, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_change_speed(speed)
end

-- Lines: 210 to 215
function UnitNetworkHandler:action_walk_stop(unit)
	if not self._verify_character(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_walk_stop()
end

-- Lines: 219 to 225
function UnitNetworkHandler:action_walk_nav_link(unit, pos, yaw, anim_index, from_idle)
	if not self._verify_character(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local rot = (360 * yaw) / 255

	unit:movement():sync_action_walk_nav_link(pos, rot, anim_index, from_idle)
end

-- Lines: 229 to 234
function UnitNetworkHandler:action_change_pose(unit, pose_code, pos)
	if not self._verify_character(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_change_pose(pose_code, pos)
end

-- Lines: 238 to 267
function UnitNetworkHandler:action_spooc_start(unit, target_u_pos, flying_strike, action_id)
	if not self._verify_character(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local action_desc = {
		block_type = "walk",
		type = "spooc",
		path_index = 1,
		body_part = 1,
		nav_path = {unit:position()},
		target_u_pos = target_u_pos,
		flying_strike = flying_strike,
		action_id = action_id,
		blocks = {
			act = -1,
			idle = -1,
			turn = -1,
			walk = -1
		}
	}

	if flying_strike then
		action_desc.blocks.light_hurt = -1
		action_desc.blocks.hurt = -1
		action_desc.blocks.heavy_hurt = -1
		action_desc.blocks.expl_hurt = -1
	end

	unit:movement():action_request(action_desc)
end

-- Lines: 271 to 276
function UnitNetworkHandler:action_spooc_stop(unit, pos, nav_index, action_id, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_spooc_stop(pos, nav_index, action_id)
end

-- Lines: 280 to 285
function UnitNetworkHandler:action_spooc_nav_point(unit, pos, action_id, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_spooc_nav_point(pos, action_id)
end

-- Lines: 289 to 294
function UnitNetworkHandler:action_spooc_strike(unit, pos, action_id, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():sync_action_spooc_strike(pos, action_id)
end

-- Lines: 298 to 310
function UnitNetworkHandler:action_warp_start(unit, has_pos, pos, has_rot, yaw, sender)
	if not self._verify_character(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local action_desc = {
		body_part = 1,
		type = "warp",
		position = has_pos and pos,
		rotation = has_rot and Rotation((360 * (yaw - 1)) / 254, 0, 0)
	}

	unit:movement():action_request(action_desc)
end

-- Lines: 314 to 319
function UnitNetworkHandler:friendly_fire_hit(subject_unit)
	if not self._verify_character(subject_unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	subject_unit:character_damage():friendly_fire_hit()
end

-- Lines: 323 to 331
function UnitNetworkHandler:damage_bullet(subject_unit, attacker_unit, damage, i_body, height_offset, variant, death, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_bullet(attacker_unit, damage, i_body, height_offset, variant, death)
end

-- Lines: 336 to 350
function UnitNetworkHandler:damage_explosion_fire(subject_unit, attacker_unit, damage, i_attack_variant, death, direction, weapon_unit, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	if i_attack_variant == 3 then
		subject_unit:character_damage():sync_damage_fire(attacker_unit, damage, i_attack_variant, death, direction)
	else
		subject_unit:character_damage():sync_damage_explosion(attacker_unit, damage, i_attack_variant, death, direction, weapon_unit)
	end
end

-- Lines: 354 to 365
function UnitNetworkHandler:damage_explosion_stun(subject_unit, attacker_unit, damage, i_attack_variant, death, direction, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	if i_attack_variant then
		subject_unit:character_damage():sync_damage_stun(attacker_unit, damage, i_attack_variant, death, direction)
	end
end

-- Lines: 368 to 377
function UnitNetworkHandler:damage_fire(subject_unit, attacker_unit, damage, start_dot_dance_antimation, death, direction, weapon_type, weapon_unit, healed, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_fire(attacker_unit, damage, start_dot_dance_antimation, death, direction, weapon_type, weapon_unit, healed)
end

-- Lines: 381 to 389
function UnitNetworkHandler:damage_dot(subject_unit, attacker_unit, damage, death, variant, hurt_animation, weapon_id, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_dot(attacker_unit, damage, death, variant, hurt_animation, weapon_id)
end

-- Lines: 393 to 401
function UnitNetworkHandler:damage_tase(subject_unit, attacker_unit, damage, variant, death, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_tase(attacker_unit, damage, variant, death)
end

-- Lines: 405 to 413
function UnitNetworkHandler:damage_melee(subject_unit, attacker_unit, damage, damage_effect, i_body, height_offset, variant, death, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_melee(attacker_unit, damage, damage_effect, i_body, height_offset, variant, death)
end

-- Lines: 418 to 427
function UnitNetworkHandler:damage_simple(subject_unit, attacker_unit, damage, i_attack_variant, i_result, death, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_simple(attacker_unit, damage, i_attack_variant, i_result, death)
end

-- Lines: 431 to 439
function UnitNetworkHandler:from_server_damage_bullet(subject_unit, attacker_unit, hit_offset_height, result_index, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_bullet(attacker_unit, hit_offset_height, result_index)
end

-- Lines: 443 to 457
function UnitNetworkHandler:from_server_damage_explosion_fire(subject_unit, attacker_unit, result_index, i_attack_variant, sender)
	if not self._verify_character(subject_unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	if i_attack_variant == 3 then
		subject_unit:character_damage():sync_damage_fire(attacker_unit, result_index, i_attack_variant)
	else
		subject_unit:character_damage():sync_damage_explosion(attacker_unit, result_index, i_attack_variant)
	end
end

-- Lines: 461 to 469
function UnitNetworkHandler:from_server_damage_melee(subject_unit, attacker_unit, hit_offset_height, result_index, sender)
	if not self._verify_character(subject_unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	subject_unit:character_damage():sync_damage_melee(attacker_unit, attacker_unit, hit_offset_height, result_index)
end

-- Lines: 473 to 478
function UnitNetworkHandler:from_server_damage_incapacitated(subject_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(subject_unit) then
		return
	end

	subject_unit:character_damage():sync_damage_incapacitated()
end

-- Lines: 482 to 487
function UnitNetworkHandler:from_server_damage_bleeding(subject_unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(subject_unit) then
		return
	end

	subject_unit:character_damage():sync_damage_bleeding()
end

-- Lines: 491 to 496
function UnitNetworkHandler:from_server_damage_tase(subject_unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(subject_unit) then
		return
	end

	subject_unit:character_damage():sync_damage_tase()
end

-- Lines: 500 to 505
function UnitNetworkHandler:from_server_unit_recovered(subject_unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(subject_unit) then
		return
	end

	subject_unit:character_damage():sync_unit_recovered()
end

-- Lines: 509 to 514
function UnitNetworkHandler:shot_blank(shooting_unit, impact, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(shooting_unit, sender) then
		return
	end

	shooting_unit:movement():sync_shot_blank(impact)
end

-- Lines: 516 to 521
function UnitNetworkHandler:sync_start_auto_fire_sound(shooting_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(shooting_unit, sender) then
		return
	end

	shooting_unit:movement():sync_start_auto_fire_sound()
end

-- Lines: 523 to 528
function UnitNetworkHandler:sync_stop_auto_fire_sound(shooting_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(shooting_unit, sender) then
		return
	end

	shooting_unit:movement():sync_stop_auto_fire_sound()
end

-- Lines: 533 to 538
function UnitNetworkHandler:shot_blank_reliable(shooting_unit, impact, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(shooting_unit, sender) then
		return
	end

	shooting_unit:movement():sync_shot_blank(impact)
end

-- Lines: 542 to 547
function UnitNetworkHandler:reload_weapon(unit, empty_reload, reload_speed_multiplier, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:movement():sync_reload_weapon(empty_reload, reload_speed_multiplier)
end

-- Lines: 551 to 565
function UnitNetworkHandler:reload_weapon_cop(unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	local inventory = alive(unit) and unit:inventory()
	local weapon = inventory and inventory:equipped_unit()
	local weapon_base = weapon and weapon:base()
	local ammo_base = weapon_base and weapon_base:ammo_base()

	if ammo_base then
		ammo_base:set_ammo_remaining_in_clip(0)
	end
end

-- Lines: 569 to 574
function UnitNetworkHandler:reload_weapon_interupt(unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:movement():sync_reload_weapon_interupt()
end

-- Lines: 578 to 588
function UnitNetworkHandler:run_mission_element(id, unit, orientation_element_index)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		if self._verify_gamestate(self._gamestate_filter.any_end_game) then
			managers.mission:client_run_mission_element_end_screen(id, unit, orientation_element_index)

			return
		end

		print("UnitNetworkHandler:run_mission_element discarded id:", id)

		return
	end

	managers.mission:client_run_mission_element(id, unit, orientation_element_index)
end

-- Lines: 590 to 598
function UnitNetworkHandler:run_mission_element_no_instigator(id, orientation_element_index)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		if self._verify_gamestate(self._gamestate_filter.any_end_game) then
			managers.mission:client_run_mission_element_end_screen(id, nil, orientation_element_index)
		end

		return
	end

	managers.mission:client_run_mission_element(id, nil, orientation_element_index)
end

-- Lines: 602 to 607
function UnitNetworkHandler:to_server_mission_element_trigger(id, unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.mission:server_run_mission_element_trigger(id, unit)
end

-- Lines: 609 to 614
function UnitNetworkHandler:to_server_area_event(event_id, id, unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.mission:to_server_area_event(event_id, id, unit)
end

-- Lines: 630 to 636
function UnitNetworkHandler:to_server_access_camera_trigger(id, trigger, instigator)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.mission:to_server_access_camera_trigger(id, trigger, instigator)
end

-- Lines: 640 to 676
function UnitNetworkHandler:sync_body_damage_bullet(body, attacker, normal_yaw, normal_pitch, position, direction_yaw, direction_pitch, damage, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(body) then
		return
	end

	if not body:extension() then
		print("[UnitNetworkHandler:sync_body_damage_bullet] body has no extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage then
		print("[UnitNetworkHandler:sync_body_damage_bullet] body has no damage extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage.damage_bullet then
		print("[UnitNetworkHandler:sync_body_damage_bullet] body has no damage damage_bullet function", body:name(), body:unit():name())

		return
	end

	local normal = Vector3()

	mrotation.set_yaw_pitch_roll(tmp_rot1, math.lerp(-180, 180, normal_yaw / 127), math.lerp(-90, 90, normal_pitch / 63), 0)
	mrotation.y(tmp_rot1, normal)

	local direction = Vector3()

	mrotation.set_yaw_pitch_roll(tmp_rot1, math.lerp(-180, 180, direction_yaw / 127), math.lerp(-90, 90, direction_pitch / 63), 0)
	mrotation.y(tmp_rot1, direction)
	body:extension().damage:damage_bullet(attacker, normal, position, direction, 1)
	body:extension().damage:damage_damage(attacker, normal, position, direction, damage / 163.84)

	local weapon_categories = attacker and alive(attacker) and attacker:inventory() and attacker:inventory():equipped_unit() and attacker:inventory():equipped_unit():base():categories()

	if weapon_categories then
		for _, category in ipairs(weapon_categories) do
			body:extension().damage:damage_bullet_type(category, attacker, normal, position, direction, 1)
		end
	end
end

-- Lines: 680 to 701
function UnitNetworkHandler:sync_body_damage_lock(body, damage, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(body) then
		return
	end

	if not body:extension() then
		print("[UnitNetworkHandler:sync_body_damage_lock] body has no extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage then
		print("[UnitNetworkHandler:sync_body_damage_lock] body has no damage extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage.damage_lock then
		print("[UnitNetworkHandler:sync_body_damage_lock] body has no damage damage_lock function", body:name(), body:unit():name())

		return
	end

	body:extension().damage:damage_lock(nil, nil, nil, nil, damage)
end

-- Lines: 705 to 726
function UnitNetworkHandler:sync_body_damage_explosion(body, attacker, normal, position, direction, damage, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(body) then
		return
	end

	if not body:extension() then
		print("[UnitNetworkHandler:sync_body_damage_explosion] body has no extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage then
		print("[UnitNetworkHandler:sync_body_damage_explosion] body has no damage extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage.damage_explosion then
		print("[UnitNetworkHandler:sync_body_damage_explosion] body has no damage damage_explosion function", body:name(), body:unit():name())

		return
	end

	body:extension().damage:damage_explosion(attacker, normal, position, direction, damage / 163.84)
	body:extension().damage:damage_damage(attacker, normal, position, direction, damage / 163.84)
end

-- Lines: 730 to 732
function UnitNetworkHandler:sync_body_damage_explosion_no_attacker(body, normal, position, direction, damage, sender)
	self:sync_body_damage_explosion(body, nil, normal, position, direction, damage, sender)
end

-- Lines: 736 to 757
function UnitNetworkHandler:sync_body_damage_fire(body, attacker, normal, position, direction, damage, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(body) then
		return
	end

	if not body:extension() then
		print("[UnitNetworkHandler:sync_body_damage_fire] body has no extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage then
		print("[UnitNetworkHandler:sync_body_damage_fire] body has no damage extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage.damage_fire then
		print("[UnitNetworkHandler:sync_body_damage_fire] body has no damage damage_fire function", body:name(), body:unit():name())

		return
	end

	body:extension().damage:damage_fire(attacker, normal, position, direction, damage / 163.84)
	body:extension().damage:damage_damage(attacker, normal, position, direction, damage / 163.84)
end

-- Lines: 761 to 763
function UnitNetworkHandler:sync_body_damage_fire_no_attacker(body, normal, position, direction, damage, sender)
	self:sync_body_damage_fire(body, nil, normal, position, direction, damage, sender)
end

-- Lines: 767 to 787
function UnitNetworkHandler:sync_body_damage_melee(body, attacker, normal, position, direction, damage, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(body) then
		return
	end

	if not body:extension() then
		print("[UnitNetworkHandler:sync_body_damage_melee] body has no extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage then
		print("[UnitNetworkHandler:sync_body_damage_melee] body has no damage extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage.damage_melee then
		print("[UnitNetworkHandler:sync_body_damage_melee] body has no damage damage_melee function", body:name(), body:unit():name())

		return
	end

	body:extension().damage:damage_melee(attacker, normal, position, direction, damage)
end

-- Lines: 791 to 823
function UnitNetworkHandler:sync_interacted(unit, unit_id, tweak_setting, status, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	if Network:is_server() and unit_id ~= -2 then
		if alive(unit) and unit:interaction() and unit:interaction().tweak_data == tweak_setting and unit:interaction():active() then
			sender:sync_interaction_reply(true)
		else
			sender:sync_interaction_reply(false)

			return
		end
	end

	if alive(unit) and unit:interaction() then
		if unit:interaction()._special_equipment and unit:interaction().apply_item_pickup then
			managers.network:session():send_to_peer(peer, "special_eq_response", unit)

			if unit:interaction():can_remove_item() then
				unit:set_slot(0)
			end
		end

		local char_unit = managers.criminals:character_unit_by_peer_id(peer:id())

		unit:interaction():sync_interacted(peer, char_unit, status)
	end
end

-- Lines: 827 to 841
function UnitNetworkHandler:sync_multiple_equipment_bag_interacted(unit, amount_wanted, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	if unit and alive(unit) and unit:interaction() then
		local char_unit = managers.criminals:character_unit_by_peer_id(peer:id())

		unit:interaction():sync_interacted(peer, char_unit, amount_wanted)
	end
end

-- Lines: 845 to 856
function UnitNetworkHandler:sync_interacted_by_id(unit_id, tweak_setting, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) and not self._verify_sender(sender) then
		return
	end

	local u_data = managers.enemy:get_corpse_unit_data_from_id(unit_id)

	if not u_data then
		sender:sync_interaction_reply(false)

		return
	end

	self:sync_interacted(u_data.unit, unit_id, tweak_setting, 1, sender)
end

-- Lines: 860 to 870
function UnitNetworkHandler:sync_interaction_reply(status)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(managers.player:player_unit()) then
		return
	end

	managers.player:from_server_interaction_reply(status)
end

-- Lines: 874 to 894
function UnitNetworkHandler:interaction_set_active(unit, u_id, active, tweak_data, flash, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		local u_data = managers.enemy:get_corpse_unit_data_from_id(u_id)

		if not u_data then
			return
		end

		unit = u_data.unit
	end

	unit:interaction():set_tweak_data(tweak_data)
	unit:interaction():set_active(active)

	if flash then
		unit:interaction():set_outline_flash_state(true, nil)
	end
end

-- Lines: 898 to 906
function UnitNetworkHandler:sync_teammate_progress(type_index, enabled, tweak_data_id, timer, success, sender)
	local sender_peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not sender_peer then
		return
	end

	local peer_id = sender_peer:id()

	managers.hud:teammate_progress(peer_id, type_index, enabled, tweak_data_id, timer, success)
end

-- Lines: 909 to 919
function UnitNetworkHandler:action_aim_state(cop)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(cop) then
		return
	end

	local shoot_action = {
		block_type = "action",
		body_part = 3,
		type = "shoot"
	}

	cop:movement():action_request(shoot_action)
end

-- Lines: 923 to 928
function UnitNetworkHandler:action_aim_end(cop)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(cop) then
		return
	end

	cop:movement():sync_action_aim_end()
end

-- Lines: 932 to 951
function UnitNetworkHandler:action_hurt_start(unit, hurt_type, body_part, death_type, type, variant, direction_vec, hit_pos)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	if unit:movement():can_request_actions() then
		local hurt_action = {
			allow_network = false,
			block_type = CopActionHurt.idx_to_hurt_type(hurt_type),
			blocks = {
				tase = -1,
				act = -1,
				action = -1,
				walk = -1,
				aim = -1
			},
			body_part = body_part,
			death_type = CopActionHurt.idx_to_death_type(death_type),
			hurt_type = CopActionHurt.idx_to_hurt_type(hurt_type),
			type = CopActionHurt.idx_to_type(type),
			variant = CopActionHurt.idx_to_variant(variant),
			direction_vec = direction_vec,
			hit_pos = hit_pos
		}

		unit:movement():action_request(hurt_action)
	end
end

-- Lines: 953 to 958
function UnitNetworkHandler:action_hurt_end(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:movement():sync_action_hurt_end()
end

-- Lines: 962 to 988
function UnitNetworkHandler:set_attention(unit, target_unit, reaction, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	if not alive(target_unit) then
		unit:movement():synch_attention()

		return
	end

	local handler = nil

	if target_unit:attention() then
		handler = target_unit:attention()
	elseif target_unit:brain() and target_unit:brain().attention_handler then
		handler = target_unit:brain():attention_handler()
	elseif target_unit:movement() and target_unit:movement().attention_handler then
		handler = target_unit:movement():attention_handler()
	elseif target_unit:base() and target_unit:base().attention_handler then
		handler = target_unit:base():attention_handler()
	end

	if not handler and (not target_unit:movement() or not target_unit:movement().m_head_pos) then
		debug_pause_unit(target_unit, "[UnitNetworkHandler:set_attention] no attention handler or m_head_pos", target_unit)

		return
	end

	unit:movement():synch_attention({
		unit = target_unit,
		u_key = target_unit:key(),
		handler = handler,
		reaction = reaction
	})
end

-- Lines: 992 to 997
function UnitNetworkHandler:cop_set_attention_pos(unit, pos)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:movement():synch_attention({
		pos = pos,
		reaction = AIAttentionObject.REACT_IDLE
	})
end

-- Lines: 1001 to 1006
function UnitNetworkHandler:set_allow_fire(unit, state)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:movement():synch_allow_fire(state)
end

-- Lines: 1010 to 1015
function UnitNetworkHandler:set_stance(unit, stance_code, instant, execute_queued, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:movement():sync_stance(stance_code, instant, execute_queued)
end

-- Lines: 1019 to 1024
function UnitNetworkHandler:set_pose(unit, pose_code, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:movement():sync_pose(pose_code)
end

-- Lines: 1028 to 1060
function UnitNetworkHandler:long_dis_interaction(target_unit, amount, aggressor_unit, secondary)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(target_unit) or not self._verify_character(aggressor_unit) then
		return
	end

	local target_is_criminal = target_unit:in_slot(managers.slot:get_mask("criminals")) or target_unit:in_slot(managers.slot:get_mask("harmless_criminals"))
	local target_is_civilian = not target_is_criminal and target_unit:in_slot(21)
	local aggressor_is_criminal = aggressor_unit:in_slot(managers.slot:get_mask("criminals")) or aggressor_unit:in_slot(managers.slot:get_mask("harmless_criminals"))

	if target_is_criminal then
		if aggressor_is_criminal then
			if target_unit:brain() then
				if target_unit:brain().on_long_dis_interacted then
					target_unit:movement():set_cool(false)
					target_unit:brain():on_long_dis_interacted(amount, aggressor_unit, secondary)
				end
			elseif amount == 1 then
				target_unit:movement():on_morale_boost(aggressor_unit)
			end
		else
			target_unit:brain():on_intimidated(amount / 10, aggressor_unit)
		end
	elseif amount == 0 and target_is_civilian and aggressor_is_criminal then
		if self._verify_in_server_session() then
			aggressor_unit:movement():sync_call_civilian(target_unit)
		end
	elseif target_unit:brain() then
		target_unit:brain():on_intimidated(amount / 10, aggressor_unit)
	end
end

-- Lines: 1064 to 1086
function UnitNetworkHandler:alarm_pager_interaction(u_id, tweak_table, status, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local unit_data = managers.enemy:get_corpse_unit_data_from_id(u_id)

	if unit_data and unit_data.unit:interaction():active() and unit_data.unit:interaction().tweak_data == tweak_table then
		local peer = self._verify_sender(sender)

		if peer then
			local status_str = nil
			status_str = status == 1 and "started" or status == 2 and "interrupted" or "complete"

			unit_data.unit:interaction():sync_interacted(peer, nil, status_str)
		end
	end
end

-- Lines: 1090 to 1100
function UnitNetworkHandler:remove_corpse_by_id(u_id, carry_bodybag, peer_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if carry_bodybag and Network:is_client() then
		managers.player:register_carry(managers.network:session():peer(peer_id), "person")
	end

	managers.enemy:remove_corpse_by_id(u_id)
end

-- Lines: 1104 to 1109
function UnitNetworkHandler:unit_tied(unit, aggressor, can_flee)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:brain():on_tied(aggressor, false, can_flee)
end

-- Lines: 1113 to 1118
function UnitNetworkHandler:unit_traded(unit, position, rotation)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:brain():on_trade(position, rotation, true)
end

-- Lines: 1122 to 1127
function UnitNetworkHandler:hostage_trade(unit, enable, trade_success, skip_hint)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	CopLogicTrade.hostage_trade(unit, enable, trade_success, skip_hint)
end

-- Lines: 1129 to 1134
function UnitNetworkHandler:set_unit_invulnerable(unit, enable)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:character_damage():set_invulnerable(enable)
end

-- Lines: 1136 to 1141
function UnitNetworkHandler:set_trade_countdown(enable)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.trade:set_trade_countdown(enable)
end

-- Lines: 1143 to 1148
function UnitNetworkHandler:set_trade_death(criminal_name, respawn_penalty, hostages_killed)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.trade:sync_set_trade_death(criminal_name, respawn_penalty, hostages_killed)
end

-- Lines: 1150 to 1155
function UnitNetworkHandler:set_trade_spawn(criminal_name)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.trade:sync_set_trade_spawn(criminal_name)
end

-- Lines: 1157 to 1162
function UnitNetworkHandler:set_trade_replace(replace_ai, criminal_name1, criminal_name2, respawn_penalty)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.trade:sync_set_trade_replace(replace_ai, criminal_name1, criminal_name2, respawn_penalty)
end

-- Lines: 1166 to 1171
function UnitNetworkHandler:action_idle_start(unit, body_part, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:movement():action_request({
		type = "idle",
		body_part = body_part
	})
end

-- Lines: 1175 to 1177
function UnitNetworkHandler:action_act_start(unit, act_index, blocks_hurt, clamp_to_graph, needs_full_blend)
	self:action_act_start_align(unit, act_index, blocks_hurt, clamp_to_graph, needs_full_blend, nil, nil)
end

-- Lines: 1181 to 1192
function UnitNetworkHandler:action_act_start_align(unit, act_index, blocks_hurt, clamp_to_graph, needs_full_blend, start_yaw, start_pos)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	local start_rot = nil

	if start_yaw and start_yaw ~= 0 then
		start_rot = Rotation((360 * (start_yaw - 1)) / 254, 0, 0)
	end

	unit:movement():sync_action_act_start(act_index, blocks_hurt, clamp_to_graph, needs_full_blend, start_rot, start_pos)
end

-- Lines: 1194 to 1199
function UnitNetworkHandler:action_act_end(unit)
	if not alive(unit) or unit:character_damage():dead() then
		return
	end

	unit:movement():sync_action_act_end()
end

-- Lines: 1203 to 1208
function UnitNetworkHandler:action_dodge_start(unit, body_part, variation, side, rotation, speed, shoot_acc)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:movement():sync_action_dodge_start(body_part, variation, side, rotation, speed, shoot_acc)
end

-- Lines: 1210 to 1215
function UnitNetworkHandler:action_dodge_end(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:movement():sync_action_dodge_end()
end

-- Lines: 1219 to 1248
function UnitNetworkHandler:action_tase_event(taser_unit, event_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(taser_unit) then
		return
	end

	local sender_peer = self._verify_sender(sender)

	if not sender_peer then
		return
	end

	if event_id == 1 then
		if not managers.network:session():is_client() or managers.network:session():server_peer() ~= sender_peer then
			return
		end

		local tase_action = {
			body_part = 3,
			type = "tase"
		}

		taser_unit:movement():action_request(tase_action)
	elseif event_id == 2 then
		if not managers.network:session():is_client() or managers.network:session():server_peer() ~= sender_peer then
			return
		end

		taser_unit:movement():sync_action_tase_end()
	else
		taser_unit:movement():sync_taser_fire()
	end
end

-- Lines: 1252 to 1270
function UnitNetworkHandler:alert(alerted_unit, aggressor)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(alerted_unit) or not self._verify_character(aggressor) then
		return
	end

	local record = managers.groupai:state():criminal_record(aggressor:key())

	if not record then
		return
	end

	local aggressor_pos = nil
	aggressor_pos = aggressor:movement() and aggressor:movement().m_head_pos and aggressor:movement():m_head_pos() or aggressor:position()

	alerted_unit:brain():on_alert({
		"aggression",
		aggressor_pos,
		false,
		[5] = aggressor
	})
end

-- Lines: 1274 to 1296
function UnitNetworkHandler:revive_player(revive_health_level, revive_damage_reduction, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.need_revive) or not peer then
		return
	end

	local player = managers.player:player_unit()

	if revive_health_level > 0 and alive(player) then
		player:character_damage():set_revive_boost(revive_health_level)
	end

	if revive_damage_reduction > 0 then
		revive_damage_reduction = math.clamp(revive_damage_reduction, 1, 2)
		local tweak = tweak_data.upgrades.first_aid_kit.revived_damage_reduction[revive_damage_reduction]

		managers.player:activate_temporary_property("revived_damage_reduction", tweak[2], tweak[1])
	end

	if alive(player) then
		player:character_damage():revive()
	end
end

-- Lines: 1298 to 1308
function UnitNetworkHandler:start_revive_player(timer, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.downed) or not peer then
		return
	end

	local player = managers.player:player_unit()

	if alive(player) then
		player:character_damage():pause_downed_timer(timer, peer:id())
	end
end

-- Lines: 1310 to 1314
function UnitNetworkHandler:pause_downed_timer(unit, sender)
	if alive(unit) and unit.interaction then
		unit:interaction():set_waypoint_paused(true)
	end
end

-- Lines: 1316 to 1320
function UnitNetworkHandler:unpause_downed_timer(unit, sender)
	if alive(unit) and unit.interaction then
		unit:interaction():set_waypoint_paused(false)
	end
end

-- Lines: 1322 to 1332
function UnitNetworkHandler:interupt_revive_player(sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.downed) or not peer then
		return
	end

	local player = managers.player:player_unit()

	if alive(player) then
		player:character_damage():unpause_downed_timer(peer:id())
	end
end

-- Lines: 1334 to 1344
function UnitNetworkHandler:start_free_player(sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.arrested) or not peer then
		return
	end

	local player = managers.player:player_unit()

	if alive(player) then
		player:character_damage():pause_arrested_timer(peer:id())
	end
end

-- Lines: 1346 to 1356
function UnitNetworkHandler:interupt_free_player(sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.arrested) or not peer then
		return
	end

	local player = managers.player:player_unit()

	if alive(player) then
		player:character_damage():unpause_arrested_timer(peer:id())
	end
end

-- Lines: 1358 to 1364
function UnitNetworkHandler:pause_arrested_timer(unit, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer or not self._verify_character(unit) then
		return
	end

	unit:character_damage():pause_arrested_timer(peer:id())
end

-- Lines: 1366 to 1372
function UnitNetworkHandler:unpause_arrested_timer(unit, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer or not self._verify_character(unit) then
		return
	end

	unit:character_damage():unpause_arrested_timer(peer:id())
end

-- Lines: 1376 to 1381
function UnitNetworkHandler:revive_unit(unit, reviving_unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) or not alive(reviving_unit) then
		return
	end

	unit:interaction():interact(reviving_unit)
end

-- Lines: 1383 to 1390
function UnitNetworkHandler:pause_bleed_out(unit, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer or not self._verify_character(unit) then
		return
	end

	unit:character_damage():pause_bleed_out(peer:id())
end

-- Lines: 1392 to 1398
function UnitNetworkHandler:unpause_bleed_out(unit, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer or not self._verify_character(unit) then
		return
	end

	unit:character_damage():unpause_bleed_out(peer:id())
end

-- Lines: 1400 to 1412
function UnitNetworkHandler:interaction_set_waypoint_paused(unit, paused, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		return
	end

	if not unit:interaction() then
		return
	end

	unit:interaction():set_waypoint_paused(paused)
end

-- Lines: 1416 to 1431
function UnitNetworkHandler:place_trip_mine(pos, normal, sensor_upgrade, rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	if not managers.player:verify_equipment(peer:id(), "trip_mine") then
		return
	end

	local rot = Rotation(normal, math.UP)
	local peer = self._verify_sender(rpc)
	local unit = TripMineBase.spawn(pos, rot, sensor_upgrade, peer:id())

	unit:base():set_server_information(peer:id())
	rpc:activate_trip_mine(unit)
end

-- Lines: 1433 to 1441
function UnitNetworkHandler:activate_trip_mine(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if alive(unit) then
		unit:base():set_active(true, managers.player:player_unit())
	end
end

-- Lines: 1443 to 1451
function UnitNetworkHandler:sync_trip_mine_setup(unit, sensor_upgrade, peer_id)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.player:verify_equipment(peer_id, "trip_mine")
	unit:base():sync_setup(sensor_upgrade)
end

-- Lines: 1453 to 1463
function UnitNetworkHandler:sync_trip_mine_explode(unit, user_unit, ray_from, ray_to, damage_size, damage, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(user_unit) then
		user_unit = nil
	end

	if alive(unit) then
		unit:base():sync_trip_mine_explode(user_unit, ray_from, ray_to, damage_size, damage)
	end
end

-- Lines: 1465 to 1475
function UnitNetworkHandler:sync_trip_mine_explode_spawn_fire(unit, user_unit, ray_from, ray_to, damage_size, damage, added_time, range_multiplier, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(user_unit) then
		user_unit = nil
	end

	if alive(unit) then
		unit:base():sync_trip_mine_explode_and_spawn_fire(user_unit, ray_from, ray_to, damage_size, damage, added_time, range_multiplier)
	end
end

-- Lines: 1477 to 1479
function UnitNetworkHandler:sync_trip_mine_explode_no_user(unit, ray_from, ray_to, damage_size, damage, sender)
	self:sync_trip_mine_explode(unit, nil, ray_from, ray_to, damage_size, damage, sender)
end

-- Lines: 1481 to 1486
function UnitNetworkHandler:sync_trip_mine_set_armed(unit, bool, length, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:base():sync_trip_mine_set_armed(bool, length)
end

-- Lines: 1490 to 1512
function UnitNetworkHandler:request_place_ecm_jammer(battery_life_upgrade_lvl, body, rel_pos, rel_rot, rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	local owner_unit = peer:unit()

	if not alive(owner_unit) or owner_unit:id() == -1 then
		rpc:from_server_ecm_jammer_place_result(nil)

		return
	end

	if not managers.player:verify_equipment(peer:id(), "ecm_jammer") then
		return
	end

	local peer = self._verify_sender(rpc)
	local unit = ECMJammerBase.spawn(Vector3(), Rotation(), battery_life_upgrade_lvl, owner_unit, peer:id())

	unit:base():set_server_information(peer:id())
	unit:base():set_active(true)
	unit:base():link_attachment(body, rel_pos, rel_rot)
	rpc:from_server_ecm_jammer_place_result(unit, body, rel_pos, rel_rot)
end

-- Lines: 1516 to 1533
function UnitNetworkHandler:from_server_ecm_jammer_place_result(unit, body, rel_pos, rel_rot, rpc)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit = alive(unit) and unit or nil

	if alive(managers.player:player_unit()) then
		managers.player:player_unit():equipment():from_server_ecm_jammer_placement_result(unit and true or false)
	end

	if not unit then
		return
	end

	unit:base():set_owner(managers.player:player_unit())
	unit:base():link_attachment(body, rel_pos, rel_rot)
end

-- Lines: 1538 to 1548
function UnitNetworkHandler:sync_deployable_attachment(unit, body, relative_pos, relative_rot, rpc)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:base():link_attachment(body, relative_pos, relative_rot)
end

-- Lines: 1552 to 1560
function UnitNetworkHandler:from_server_ecm_jammer_rejected(rpc)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if alive(managers.player:player_unit()) then
		managers.player:player_unit():equipment():from_server_ecm_jammer_placement_result(false)
	end
end

-- Lines: 1564 to 1577
function UnitNetworkHandler:sync_unit_event_id_16(unit, ext_name, event_id, rpc)
	local peer = self._verify_sender(rpc)

	if not peer or not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local extension = unit[ext_name](unit)

	if not extension then
		debug_pause("[UnitNetworkHandler:sync_unit_event_id_16] unit", unit, "does not have extension", ext_name)

		return
	end

	extension:sync_net_event(event_id, peer)
end

-- Lines: 1581 to 1587
function UnitNetworkHandler:m79grenade_explode_on_client(position, normal, user, damage, range, curve_pow, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(user, sender) then
		return
	end

	ProjectileBase._explode_on_client(position, normal, user, damage, range, curve_pow)
end

-- Lines: 1590 to 1596
function UnitNetworkHandler:element_explode_on_client(position, normal, damage, range, curve_pow, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.explosion:client_damage_and_push(position, normal, nil, damage, range, curve_pow)
end

-- Lines: 1598 to 1610
function UnitNetworkHandler:picked_up_sentry_gun(unit, rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	if alive(unit) then
		local sentry_type = unit:base():get_type()
		local sentry_type_index = sentry_type == "sentry_gun" and 1 or sentry_type == "sentry_gun_silent" and 2

		managers.network:session():send_to_peer(peer, "picked_up_sentry_gun_response", unit:id(), unit:weapon():ammo_total(), unit:weapon():ammo_max(), sentry_type_index)
		unit:base():remove()
	end
end

-- Lines: 1613 to 1624
function UnitNetworkHandler:picked_up_sentry_gun_response(sentry_uid, ammo, max_ammo, sentry_type_index, rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	local sentry_type_list = {
		"sentry_gun",
		"sentry_gun_silent"
	}
	local sentry_type = sentry_type_list[sentry_type_index]
	local ammo_ratio = ammo / max_ammo

	SentryGunBase.on_picked_up(sentry_type, ammo_ratio, sentry_uid)
end

-- Lines: 1628 to 1640
function UnitNetworkHandler:place_sentry_gun(pos, rot, equipment_selection_index, user_unit, unit_idstring_index, ammo_level, rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	local unit, spread_level, rot_level = SentryGunBase.spawn(user_unit, pos, rot, peer:id(), true, unit_idstring_index)

	if unit then
		unit:base():set_server_information(peer:id())

		local has_shield = unit:base():has_shield()

		managers.network:session():send_to_peers_synched("from_server_sentry_gun_place_result", peer:id(), equipment_selection_index or 0, unit, rot_level, spread_level, has_shield, ammo_level)
	end
end

-- Lines: 1644 to 1681
function UnitNetworkHandler:from_server_sentry_gun_place_result(owner_peer_id, equipment_selection_index, sentry_gun_unit, rot_level, spread_level, shield, ammo_level, rpc)
	local local_peer = managers.network:session():local_peer()

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(rpc) or not alive(sentry_gun_unit) or not managers.network:session():peer(owner_peer_id) then
		if alive(local_peer:unit()) then
			local_peer:unit():equipment():from_server_sentry_gun_place_result(sentry_gun_unit:id())
		end

		return
	end

	sentry_gun_unit:base():set_owner_id(owner_peer_id)

	if owner_peer_id == local_peer:id() and alive(local_peer:unit()) then
		managers.player:from_server_equipment_place_result(equipment_selection_index, local_peer:unit(), sentry_gun_unit)
	end

	if shield then
		sentry_gun_unit:base():enable_shield()
	end

	local rot_speed_mul = SentryGunBase.ROTATION_SPEED_MUL[rot_level]

	sentry_gun_unit:movement():setup(rot_speed_mul)
	sentry_gun_unit:brain():setup(1 / rot_speed_mul)

	local spread_mul = SentryGunBase.SPREAD_MUL[spread_level]
	local setup_data = {
		spread_mul = spread_mul,
		ignore_units = {sentry_gun_unit}
	}

	sentry_gun_unit:weapon():setup(setup_data)

	local ammo_mul = SentryGunBase.AMMO_MUL[ammo_level]

	sentry_gun_unit:weapon():setup_virtual_ammo(ammo_mul)
	sentry_gun_unit:event_listener():call("on_setup", sentry_gun_unit:base():is_owner())
	sentry_gun_unit:base():post_setup()
end

-- Lines: 1685 to 1691
function UnitNetworkHandler:sync_sentrygun_dynamic(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:base():sync_set_dynamic()
end

-- Lines: 1695 to 1700
function UnitNetworkHandler:sentrygun_ammo(unit, ammo_ratio, owner_id)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:weapon():sync_ammo(ammo_ratio)
end

-- Lines: 1704 to 1706
function UnitNetworkHandler:sentrygun_sync_armor_piercing(unit, use_armor_piercing)
	unit:weapon():set_fire_mode_net(use_armor_piercing)
end

-- Lines: 1710 to 1712
function UnitNetworkHandler:sync_fire_mode_interaction(unit, fire_mode_unit, owner_id)
	unit:weapon():interaction_setup(fire_mode_unit, owner_id)
end

-- Lines: 1716 to 1721
function UnitNetworkHandler:sentrygun_health(unit, health_ratio)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:character_damage():sync_health(health_ratio)
end

-- Lines: 1725 to 1730
function UnitNetworkHandler:turret_idle_state(unit, state)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:brain():set_idle(state)
end

-- Lines: 1734 to 1739
function UnitNetworkHandler:turret_update_shield_smoke_level(unit, ratio, up)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:character_damage():update_shield_smoke_level(ratio, up)
end

-- Lines: 1743 to 1749
function UnitNetworkHandler:turret_repair(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():repair()
end

-- Lines: 1753 to 1759
function UnitNetworkHandler:turret_complete_repairing(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:movement():complete_repairing()
end

-- Lines: 1763 to 1768
function UnitNetworkHandler:turret_repair_shield(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:character_damage():repair_shield()
end

-- Lines: 1772 to 1782
function UnitNetworkHandler:sync_unit_module(parent_unit, module_unit, align_obj_name, module_id, parent_extension_name)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(parent_unit) or not alive(module_unit) then
		return
	end

	parent_unit[parent_extension_name](parent_unit):spawn_module(module_unit, align_obj_name, module_id)
end

-- Lines: 1786 to 1797
function UnitNetworkHandler:run_unit_module_function(parent_unit, module_id, parent_extension_name, module_extension_name, func_name, params)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(parent_unit) then
		return
	end

	local params_split = string.split(params, " ")

	parent_unit[parent_extension_name](parent_unit):run_module_function_unsafe(module_id, module_extension_name, func_name, params_split[1], params_split[2])
end

-- Lines: 1801 to 1807
function UnitNetworkHandler:sync_equipment_setup(unit, upgrade_lvl, peer_id)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:base():sync_setup(upgrade_lvl, peer_id)
end

-- Lines: 1811 to 1817
function UnitNetworkHandler:sync_ammo_bag_setup(unit, upgrade_lvl, peer_id, bullet_storm_level)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:base():sync_setup(upgrade_lvl, peer_id, bullet_storm_level)
end

-- Lines: 1821 to 1826
function UnitNetworkHandler:sync_ammo_bag_ammo_taken(unit, amount, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:base():sync_ammo_taken(amount)
end

-- Lines: 1830 to 1835
function UnitNetworkHandler:sync_grenade_crate_grenade_taken(unit, amount, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:base():sync_grenade_taken(amount)
end

-- Lines: 1839 to 1856
function UnitNetworkHandler:place_deployable_bag(class_name, pos, rot, upgrade_lvl, rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	local class_name_to_deployable_id = tweak_data.equipments.class_name_to_deployable_id

	if not managers.player:verify_equipment(peer:id(), class_name_to_deployable_id[class_name]) then
		return
	end

	local class = CoreSerialize.string_to_classtable(class_name)

	if class then
		local unit = class.spawn(pos, rot, upgrade_lvl, peer:id())

		unit:base():set_server_information(peer:id())
	end
end

-- Lines: 1860 to 1875
function UnitNetworkHandler:place_ammo_bag(pos, rot, upgrade_lvl, bullet_storm_level, rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	if not managers.player:verify_equipment(peer:id(), "ammo_bag") then
		return
	end

	local unit = AmmoBagBase.spawn(pos, rot, upgrade_lvl, peer:id(), bullet_storm_level)

	if unit then
		unit:base():set_server_information(peer:id())
	end
end

-- Lines: 1879 to 1886
function UnitNetworkHandler:used_deployable(rpc)
	local peer = self._verify_sender(rpc)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	peer:set_used_deployable(true)
end

-- Lines: 1890 to 1895
function UnitNetworkHandler:sync_doctor_bag_taken(unit, amount, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:base():sync_taken(amount)
end

-- Lines: 1899 to 1904
function UnitNetworkHandler:sync_money_wrap_money_taken(unit, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:base():sync_money_taken()
end

-- Lines: 1908 to 1921
function UnitNetworkHandler:sync_pickup(unit, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local pickup_extension = unit:base()

	if not pickup_extension or not pickup_extension.sync_pickup then
		pickup_extension = unit:pickup()
	end

	if pickup_extension and pickup_extension.sync_pickup then
		pickup_extension:sync_pickup(self._verify_sender(sender))
	end
end

-- Lines: 1925 to 1935
function UnitNetworkHandler:unit_sound_play(unit, event_id, source, sender)
	if not alive(unit) or not self._verify_sender(sender) then
		return
	end

	if source == "" then
		source = nil
	end

	unit:sound():play(event_id, source, false)
end

-- Lines: 1939 to 1960
function UnitNetworkHandler:corpse_sound_play(unit_id, event_id, source)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local u_data = managers.enemy:get_corpse_unit_data_from_id(unit_id)

	if not u_data then
		return
	end

	if not u_data.unit then
		debug_pause("[UnitNetworkHandler:corpse_sound_play] u_data without unit", inspect(u_data))

		return
	end

	if not u_data.unit:sound() then
		return
	end

	u_data.unit:sound():play(event_id, source, false)
end

-- Lines: 1964 to 1973
function UnitNetworkHandler:say(unit, event_id, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if unit:in_slot(managers.slot:get_mask("all_criminals")) and not managers.groupai:state():is_enemy_converted_to_criminal(unit) then
		unit:sound():say(event_id, nil, false)
	else
		unit:sound():say(event_id, nil, true)
	end
end

-- Lines: 1977 to 1982
function UnitNetworkHandler:sync_remove_one_teamAI(name, replace_with_player)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_remove_one_teamAI(name, replace_with_player)
end

-- Lines: 1986 to 1991
function UnitNetworkHandler:sync_smoke_grenade(detonate_pos, shooter_pos, duration, flashbang)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_smoke_grenade(detonate_pos, shooter_pos, duration, flashbang)
end

-- Lines: 1995 to 2000
function UnitNetworkHandler:sync_smoke_grenade_kill()
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_smoke_grenade_kill()
end

-- Lines: 2004 to 2009
function UnitNetworkHandler:sync_cs_grenade(detonate_pos, shooter_pos, duration)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_cs_grenade(detonate_pos, shooter_pos, duration)
end

-- Lines: 2013 to 2018
function UnitNetworkHandler:sync_cs_grenade_kill()
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_cs_grenade_kill()
end

-- Lines: 2022 to 2027
function UnitNetworkHandler:sync_hostage_headcount(value)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_hostage_headcount(value)
end

-- Lines: 2031 to 2036
function UnitNetworkHandler:play_distance_interact_redirect(unit, redirect, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:movement():play_redirect(redirect)
end

-- Lines: 2040 to 2056
function UnitNetworkHandler:play_distance_interact_redirect_delay(unit, redirect, delay, sender)
	local sender_peer = self._verify_sender(sender)

	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not sender_peer then
		return
	end

	delay = delay - sender_peer:qos().ping / 1000

	if unit:movement().play_redirect_delayed then
		unit:movement():play_redirect_delayed(redirect, nil, delay)
	else
		unit:movement():play_redirect(redirect)
	end
end

-- Lines: 2060 to 2065
function UnitNetworkHandler:start_timer_gui(unit, timer, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:timer_gui():sync_start(timer)
end

-- Lines: 2078 to 2083
function UnitNetworkHandler:give_equipment(equipment, amount, transfer, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.player:add_special({
		name = equipment,
		amount = amount,
		transfer = transfer
	})
end

-- Lines: 2087 to 2092
function UnitNetworkHandler:on_sole_criminal_respawned(peer_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.player:on_sole_criminal_respawned(peer_id)
end

-- Lines: 2096 to 2101
function UnitNetworkHandler:killzone_set_unit(type)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.killzone:set_unit(managers.player:player_unit(), type)
end

-- Lines: 2105 to 2110
function UnitNetworkHandler:dangerzone_set_level(level)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.player:player_unit():character_damage():set_danger_level(level)
end

-- Lines: 2114 to 2200
function UnitNetworkHandler:sync_player_movement_state(unit, state, down_time, unit_id_str)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	self:_chk_unit_too_early(unit, unit_id_str, "sync_player_movement_state", 1, unit, state, down_time, unit_id_str)

	if not alive(unit) then
		return
	end

	Application:trace("[UnitNetworkHandler:sync_player_movement_state]: ", unit:movement():current_state_name(), "->", state)

	local local_peer = managers.network:session():local_peer()

	if local_peer:unit() and unit:key() == local_peer:unit():key() then
		local valid_transitions = {
			standard = {
				arrested = true,
				incapacitated = true,
				carry = true,
				bleed_out = true,
				tased = true
			},
			carry = {
				arrested = true,
				incapacitated = true,
				standard = true,
				bleed_out = true,
				tased = true
			},
			mask_off = {
				arrested = true,
				carry = true,
				standard = true
			},
			bleed_out = {
				carry = true,
				fatal = true,
				standard = true
			},
			fatal = {
				carry = true,
				standard = true
			},
			arrested = {
				carry = true,
				standard = true
			},
			tased = {
				incapacitated = true,
				carry = true,
				standard = true
			},
			incapacitated = {
				carry = true,
				standard = true
			},
			clean = {
				arrested = true,
				carry = true,
				mask_off = true,
				standard = true,
				civilian = true
			},
			civilian = {
				arrested = true,
				carry = true,
				clean = true,
				standard = true,
				mask_off = true
			}
		}

		if unit:movement():current_state_name() == state then
			return
		end

		if unit:movement():current_state_name() and valid_transitions[unit:movement():current_state_name()][state] then
			managers.player:set_player_state(state)
		else
			debug_pause_unit(unit, "[UnitNetworkHandler:sync_player_movement_state] received invalid transition", unit, unit:movement():current_state_name(), "->", state)
		end
	else
		unit:movement():sync_movement_state(state, down_time)
	end
end

-- Lines: 2204 to 2209
function UnitNetworkHandler:sync_show_hint(id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.hint:sync_show_hint(id)
end

-- Lines: 2213 to 2218
function UnitNetworkHandler:sync_show_action_message(unit, id, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.action_messaging:sync_show_message(id, unit)
end

-- Lines: 2222 to 2227
function UnitNetworkHandler:sync_waiting_for_player_start(variant, soundtrack)
	if not self._verify_gamestate(self._gamestate_filter.waiting_for_players) then
		return
	end

	game_state_machine:current_state():sync_start(variant, soundtrack)
end

-- Lines: 2229 to 2234
function UnitNetworkHandler:sync_waiting_for_player_skip()
	if not self._verify_gamestate(self._gamestate_filter.waiting_for_players) then
		return
	end

	game_state_machine:current_state():sync_skip()
end

-- Lines: 2238 to 2248
function UnitNetworkHandler:criminal_hurt(criminal_unit, attacker_unit, damage_ratio, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(criminal_unit, sender) then
		return
	end

	if not alive(attacker_unit) or criminal_unit:key() == attacker_unit:key() then
		attacker_unit = nil
	end

	managers.hud:set_mugshot_damage_taken(criminal_unit:unit_data().mugshot_id)
	managers.groupai:state():criminal_hurt_drama(criminal_unit, attacker_unit, damage_ratio * 0.01)
end

-- Lines: 2252 to 2257
function UnitNetworkHandler:arrested(unit)
	if not alive(unit) then
		return
	end

	unit:movement():sync_arrested()
end

-- Lines: 2261 to 2273
function UnitNetworkHandler:suspect_uncovered(enemy_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local suspect_member = managers.network:session():local_peer()
	local suspect_unit = suspect_member and suspect_member:unit()

	if not suspect_unit then
		return
	end

	suspect_unit:movement():on_uncovered(enemy_unit)
end

-- Lines: 2277 to 2285
function UnitNetworkHandler:add_synced_team_upgrade(category, upgrade, level, sender)
	local sender_peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not sender_peer then
		return
	end

	local peer_id = sender_peer:id()

	managers.player:add_synced_team_upgrade(peer_id, category, upgrade, level)
end

-- Lines: 2288 to 2295
function UnitNetworkHandler:sync_deployable_equipment(deployable, amount, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:set_synced_deployable_equipment(peer, deployable, amount)
end

-- Lines: 2298 to 2305
function UnitNetworkHandler:sync_cable_ties(amount, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:set_synced_cable_ties(peer:id(), amount)
end

-- Lines: 2308 to 2315
function UnitNetworkHandler:sync_grenades(grenade, amount, register_peer_id, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:set_synced_grenades(peer:id(), grenade, amount, register_peer_id)
end

-- Lines: 2317 to 2327
function UnitNetworkHandler:sync_grenades_cooldown(end_time, duration, sender)
	local peer = self._verify_sender(sender)

	if not peer or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local teammate_panel = managers.hud:get_teammate_panel_by_peer(peer)

	if teammate_panel then
		teammate_panel:set_grenade_cooldown({
			end_time = end_time,
			duration = duration
		})
	end
end

-- Lines: 2330 to 2337
function UnitNetworkHandler:sync_ammo_amount(selection_index, max_clip, current_clip, current_left, max, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:set_synced_ammo_info(peer:id(), selection_index, max_clip, current_clip, current_left, max)
end

-- Lines: 2340 to 2347
function UnitNetworkHandler:activate_temporary_team_upgrade(category, upgrade, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:activate_synced_temporary_team_upgrade(peer:id(), category, upgrade)
end

-- Lines: 2350 to 2357
function UnitNetworkHandler:sync_bipod(bipod_pos, body_pos, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:set_synced_bipod(peer, bipod_pos, body_pos)
end

-- Lines: 2360 to 2367
function UnitNetworkHandler:sync_carry(carry_id, multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:set_synced_carry(peer, carry_id, multiplier, dye_initiated, has_dye_pack, dye_value_multiplier)
end

-- Lines: 2369 to 2376
function UnitNetworkHandler:sync_remove_carry(sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:remove_synced_carry(peer)
end

-- Lines: 2378 to 2385
function UnitNetworkHandler:server_drop_carry(carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, rotation, dir, throw_distance_multiplier_upgrade_level, zipline_unit, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.player:server_drop_carry(carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, rotation, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer)
end

-- Lines: 2387 to 2397
function UnitNetworkHandler:sync_carry_data(unit, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer_id, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.player:verify_carry(managers.network:session():peer(peer_id), carry_id)
	managers.player:sync_carry_data(unit, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer_id)
end

-- Lines: 2410 to 2425
function UnitNetworkHandler:sync_cocaine_stacks(amount, in_use, upgrade_level, power_level, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	local peer_id = peer:id()
	local current_cocaine_stacks = managers.player:get_synced_cocaine_stacks(peer_id)

	if current_cocaine_stacks then
		amount = math.min((current_cocaine_stacks and current_cocaine_stacks.amount or 0) + (tweak_data.upgrades.max_cocaine_stacks_per_tick or 20), amount)
	end

	managers.player:set_synced_cocaine_stacks(peer_id, amount, in_use, upgrade_level, power_level)
end

-- Lines: 2431 to 2448
function UnitNetworkHandler:request_throw_projectile(projectile_type_index, position, dir, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	local peer_id = peer:id()
	local projectile_type = tweak_data.blackmarket:get_projectile_name_from_index(projectile_type_index)
	local no_cheat_count = tweak_data.blackmarket.projectiles[projectile_type].no_cheat_count

	if not no_cheat_count and not managers.player:verify_grenade(peer_id) then
		return
	end

	ProjectileBase.throw_projectile(projectile_type, position, dir, peer_id)
end

-- Lines: 2451 to 2500
function UnitNetworkHandler:sync_throw_projectile(unit, pos, dir, projectile_type_index, peer_id, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		print("_verify failed!!!")

		return
	end

	local projectile_type = tweak_data.blackmarket:get_projectile_name_from_index(projectile_type_index)
	local tweak_entry = tweak_data.blackmarket.projectiles[projectile_type]

	if tweak_entry.client_authoritative then
		if not unit then
			local unit_name = Idstring(tweak_entry.local_unit)
			unit = World:spawn_unit(unit_name, pos, Rotation(dir, math.UP))
		end

		unit:base():set_owner_peer_id(peer_id)
	end

	if not alive(unit) then
		print("unit is not alive!!!")

		return
	end

	local server_peer = managers.network:session():server_peer()

	if tweak_entry.throwable and not peer == server_peer then
		print("projectile is throwable, should not be thrown by client!!!")

		return
	end

	local no_cheat_count = tweak_entry.no_cheat_count

	if not no_cheat_count then
		managers.player:verify_grenade(peer_id)
	end

	local member = managers.network:session():peer(peer_id)
	local thrower_unit = member and member:unit()

	if alive(thrower_unit) then
		unit:base():set_thrower_unit(thrower_unit)

		if not tweak_entry.throwable and thrower_unit:movement() and thrower_unit:movement():current_state() then
			unit:base():set_weapon_unit(thrower_unit:movement():current_state()._equipped_unit)
		end
	end

	unit:base():sync_throw_projectile(dir, projectile_type)
end

-- Lines: 2507 to 2550
function UnitNetworkHandler:sync_attach_projectile(unit, instant_dynamic_pickup, parent_unit, parent_body, parent_object, local_pos, dir, projectile_type_index, peer_id, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		print("_verify failed!!!")

		return
	end

	local world_position = parent_object and local_pos:rotate_with(parent_object:rotation()) + parent_object:position() or local_pos

	if Network:is_server() then
		local projectile_type = tweak_data.blackmarket:get_projectile_name_from_index(projectile_type_index)
		local tweak_entry = tweak_data.blackmarket.projectiles[projectile_type]
		local unit_name = Idstring(tweak_entry.unit)
		local synced_unit = World:spawn_unit(unit_name, world_position, Rotation(dir, math.UP))

		managers.network:session():send_to_peers_synched("sync_attach_projectile", synced_unit, instant_dynamic_pickup, alive(parent_unit) and parent_unit:id() ~= -1 and parent_unit or nil, alive(parent_unit) and parent_unit:id() ~= -1 and parent_body or nil, alive(parent_unit) and parent_unit:id() ~= -1 and parent_object or nil, local_pos, dir, projectile_type_index, peer_id)
		synced_unit:base():set_thrower_unit_by_peer_id(peer_id)
		synced_unit:base():sync_attach_to_unit(instant_dynamic_pickup, parent_unit, parent_body, parent_object, local_pos, dir)
	elseif unit then
		unit:set_position(world_position)
		unit:base():set_thrower_unit_by_peer_id(peer_id)
		unit:base():sync_attach_to_unit(instant_dynamic_pickup, parent_unit, parent_body, parent_object, local_pos, dir)
	end

	if peer_id ~= 1 then
		local dummy_unit = ArrowBase.find_nearest_arrow(peer_id, world_position)

		if dummy_unit then
			dummy_unit:set_slot(0)
		end
	end
end

-- Lines: 2552 to 2565
function UnitNetworkHandler:sync_detonate_incendiary_grenade(unit, ext_name, event_id, normal, rpc)
	local peer = self._verify_sender(rpc)

	if not peer or not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local extension = unit[ext_name](unit)

	if not extension then
		debug_pause("[UnitNetworkHandler:sync_detonate_incendiary_grenade] unit", unit, "does not have extension", ext_name)

		return
	end

	extension:sync_detonate_incendiary_grenade(event_id, normal, peer)
end

-- Lines: 2567 to 2580
function UnitNetworkHandler:sync_detonate_molotov_grenade(unit, ext_name, event_id, normal, rpc)
	local peer = self._verify_sender(rpc)

	if not peer or not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local extension = unit[ext_name](unit)

	if not extension then
		debug_pause("[UnitNetworkHandler:sync_detonate_molotov_grenade] unit", unit, "does not have extension", ext_name)

		return
	end

	extension:sync_detonate_molotov_grenade(event_id, normal, peer)
end

-- Lines: 2585 to 2589
function UnitNetworkHandler:sync_add_doted_enemy(enemy_unit, fire_damage_received_time, weapon_unit, dot_length, dot_damage, user_unit, is_molotov, rpc)
	local peer = self._verify_sender(rpc)

	managers.fire:sync_add_fire_dot(enemy_unit, fire_damage_received_time, weapon_unit, dot_length, dot_damage, user_unit, peer, is_molotov)
end

-- Lines: 2593 to 2600
function UnitNetworkHandler:server_secure_loot(carry_id, multiplier_level, peer_id, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.loot:server_secure_loot(carry_id, multiplier_level, nil, peer_id)
end

-- Lines: 2602 to 2608
function UnitNetworkHandler:sync_secure_loot(carry_id, multiplier_level, silent, peer_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) and not self._verify_gamestate(self._gamestate_filter.any_end_game) or not self._verify_sender(sender) then
		return
	end

	managers.loot:sync_secure_loot(carry_id, multiplier_level, silent, peer_id)
end

-- Lines: 2610 to 2620
function UnitNetworkHandler:sync_small_loot_taken(unit, multiplier_level, sender)
	if not alive(unit) and self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	unit:base():taken(multiplier_level, peer:id())
end

-- Lines: 2624 to 2631
function UnitNetworkHandler:server_unlock_asset(asset_id, is_show_chat_message, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.assets:server_unlock_asset(asset_id, is_show_chat_message, peer)
end

-- Lines: 2633 to 2640
function UnitNetworkHandler:sync_unlock_asset(asset_id, is_show_chat_message, unlocker_peer_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local peer = managers.network:session():peer(unlocker_peer_id)

	managers.assets:sync_unlock_asset(asset_id, is_show_chat_message, peer)
end

-- Lines: 2644 to 2650
function UnitNetworkHandler:sync_heist_time(time, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.game_play_central:sync_heist_time(time)
end

-- Lines: 2654 to 2660
function UnitNetworkHandler:run_mission_door_sequence(unit, sequence_name, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:base():run_sequence_simple(sequence_name)
end

-- Lines: 2662 to 2668
function UnitNetworkHandler:set_mission_door_device_powered(unit, powered, interaction_enabled, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	MissionDoor.set_mission_door_device_powered(unit, powered, interaction_enabled)
end

-- Lines: 2670 to 2676
function UnitNetworkHandler:run_mission_door_device_sequence(unit, sequence_name, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	MissionDoor.run_mission_door_device_sequence(unit, sequence_name)
end

-- Lines: 2678 to 2686
function UnitNetworkHandler:server_place_mission_door_device(unit, player, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local result = unit:interaction():server_place_mission_door_device(player, sender)
end

-- Lines: 2688 to 2694
function UnitNetworkHandler:result_place_mission_door_device(unit, result, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	unit:interaction():result_place_mission_door_device(result)
end

-- Lines: 2738 to 2752
function UnitNetworkHandler:set_armor(unit, percent, max_mul, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local peer = self._verify_sender(sender)
	local peer_id = peer:id()
	local character_data = managers.criminals:character_data_by_peer_id(peer_id)

	if character_data and character_data.panel_id then
		managers.hud:set_teammate_armor(character_data.panel_id, {
			current = percent * max_mul,
			total = 100 * max_mul,
			max = 100 * max_mul
		})
	else
		managers.hud:set_mugshot_armor(unit:unit_data().mugshot_id, percent / 100)
	end
end

-- Lines: 2755 to 2771
function UnitNetworkHandler:set_health(unit, percent, max_mul, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local peer = self._verify_sender(sender)
	local peer_id = peer:id()
	local character_data = managers.criminals:character_data_by_peer_id(peer_id)

	if character_data and character_data.panel_id then
		managers.hud:set_teammate_health(character_data.panel_id, {
			current = percent * max_mul,
			total = 100 * max_mul,
			max = 100 * max_mul
		})
	else
		managers.hud:set_mugshot_health(unit:unit_data().mugshot_id, percent / 100)
	end

	if percent ~= 100 then
		managers.mission:call_global_event("player_damaged")
	end
end

-- Lines: 2774 to 2779
function UnitNetworkHandler:sync_equipment_possession(peer_id, equipment, amount, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.player:set_synced_equipment_possession(peer_id, equipment, amount)
end

-- Lines: 2781 to 2791
function UnitNetworkHandler:sync_remove_equipment_possession(peer_id, equipment, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local equipment_peer = managers.network:session():peer(peer_id)

	if not equipment_peer then
		print("[UnitNetworkHandler:sync_remove_equipment_possession] unknown peer", peer_id)

		return
	end

	managers.player:remove_equipment_possession(peer_id, equipment)
end

-- Lines: 2795 to 2800
function UnitNetworkHandler:sync_start_anticipation()
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.hud:sync_start_anticipation()
end

-- Lines: 2802 to 2807
function UnitNetworkHandler:sync_start_anticipation_music()
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.hud:sync_start_anticipation_music()
end

-- Lines: 2809 to 2817
function UnitNetworkHandler:sync_start_assault(assault_number)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.hud:sync_start_assault(assault_number)
	managers.skirmish:sync_start_assault(assault_number)
end

-- Lines: 2819 to 2824
function UnitNetworkHandler:sync_end_assault(result)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.hud:sync_end_assault(result)
end

-- Lines: 2826 to 2831
function UnitNetworkHandler:sync_assault_dialog(index)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.hud:sync_assault_dialog(index)
end

-- Lines: 2835 to 2860
function UnitNetworkHandler:sync_contour_state(unit, u_id, type, state, multiplier, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local contour_unit = nil

	if alive(unit) and unit:id() ~= -1 then
		contour_unit = unit
	else
		local unit_data = managers.enemy:get_corpse_unit_data_from_id(u_id)

		if unit_data then
			contour_unit = unit_data.unit
		end
	end

	if not contour_unit then
		Application:error("[UnitNetworkHandler:sync_contour_state] Unit is missing")

		return
	end

	if state then
		contour_unit:contour():add(ContourExt.indexed_types[type], false, multiplier)
	else
		contour_unit:contour():remove(ContourExt.indexed_types[type], nil)
	end
end

-- Lines: 2864 to 2884
function UnitNetworkHandler:mark_minion(unit, minion_owner_peer_id, convert_enemies_health_multiplier_level, passive_convert_enemies_health_multiplier_level, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	local health_multiplier = 1

	if convert_enemies_health_multiplier_level > 0 then
		health_multiplier = health_multiplier * tweak_data.upgrades.values.player.convert_enemies_health_multiplier[convert_enemies_health_multiplier_level]
	end

	if passive_convert_enemies_health_multiplier_level > 0 then
		health_multiplier = health_multiplier * tweak_data.upgrades.values.player.passive_convert_enemies_health_multiplier[passive_convert_enemies_health_multiplier_level]
	end

	unit:character_damage():convert_to_criminal(health_multiplier)
	unit:contour():add("friendly", false)
	managers.groupai:state():sync_converted_enemy(unit, minion_owner_peer_id)

	if minion_owner_peer_id == managers.network:session():local_peer():id() then
		managers.player:count_up_player_minions()
	end
end

-- Lines: 2886 to 2895
function UnitNetworkHandler:remove_minion(unit, sender)
	if not self._verify_sender(sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if unit then
		local u_key = unit:key()

		managers.groupai:state():_set_converted_police(u_key, nil)
	end
end

-- Lines: 2898 to 2899
function UnitNetworkHandler:spot_enemy(unit)
end

-- Lines: 2901 to 2906
function UnitNetworkHandler:count_down_player_minions()
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.player:count_down_player_minions()
end

-- Lines: 2910 to 2915
function UnitNetworkHandler:sync_teammate_helped_hint(hint, helped_unit, helping_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(helped_unit, sender) or not self._verify_character(helping_unit, sender) then
		return
	end

	managers.trade:sync_teammate_helped_hint(helped_unit, helping_unit, hint)
end

-- Lines: 2919 to 2924
function UnitNetworkHandler:sync_assault_mode(enabled)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_assault_mode(enabled)
end

-- Lines: 2928 to 2933
function UnitNetworkHandler:sync_hostage_killed_warning(warning)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_hostage_killed_warning(warning)
end

-- Lines: 2937 to 2943
function UnitNetworkHandler:set_interaction_voice(unit, voice, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	unit:brain():set_interaction_voice(voice ~= "" and voice or nil)
end

-- Lines: 2947 to 2952
function UnitNetworkHandler:sync_teammate_comment(message, pos, pos_based, radius, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.groupai:state():sync_teammate_comment(message, pos, pos_based, radius)
end

-- Lines: 2954 to 2959
function UnitNetworkHandler:sync_teammate_comment_instigator(unit, message)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.groupai:state():sync_teammate_comment_instigator(unit, message)
end

-- Lines: 2963 to 2968
function UnitNetworkHandler:begin_gameover_fadeout()
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():begin_gameover_fadeout()
end

-- Lines: 2972 to 2987
function UnitNetworkHandler:send_statistics(total_kills, total_specials_kills, total_head_shots, accuracy, downs, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_end_game) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	managers.network:session():on_statistics_recieved(peer:id(), total_kills, total_specials_kills, total_head_shots, accuracy, downs)
end

-- Lines: 2991 to 2995
function UnitNetworkHandler:sync_statistics_result(...)
	if game_state_machine:current_state().on_statistics_result then
		game_state_machine:current_state():on_statistics_result(...)
	end
end

-- Lines: 2999 to 3004
function UnitNetworkHandler:statistics_tied(name, sender)
	if not self._verify_sender(sender) then
		return
	end

	managers.statistics:tied({name = name})
end

-- Lines: 3008 to 3020
function UnitNetworkHandler:bain_comment(bain_line, sender)
	if not self._verify_sender(sender) then
		return
	end

	if managers.dialog and managers.groupai and managers.groupai:state():bain_state() then
		managers.dialog:queue_narrator_dialog(bain_line, {})
	end
end

-- Lines: 3024 to 3031
function UnitNetworkHandler:is_inside_point_of_no_return(is_inside, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	managers.groupai:state():set_is_inside_point_of_no_return(peer:id(), is_inside)
end

-- Lines: 3035 to 3048
function UnitNetworkHandler:mission_ended(win, num_is_inside, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if managers.platform:presence() == "Playing" then
		if win then
			game_state_machine:change_state_by_name("victoryscreen", {
				num_winners = num_is_inside,
				personal_win = not managers.groupai:state()._failed_point_of_no_return and alive(managers.player:player_unit())
			})
		else
			game_state_machine:change_state_by_name("gameoverscreen")
		end
	end
end

-- Lines: 3052 to 3059
function UnitNetworkHandler:sync_level_up(level, sender)
	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	peer:set_level(level)
end

-- Lines: 3072 to 3078
function UnitNetworkHandler:sync_disable_shout(unit, state, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	ElementDisableShout.sync_function(unit, state)
end

-- Lines: 3080 to 3089
function UnitNetworkHandler:sync_run_sequence_char(unit, seq, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	if unit and alive(unit) and unit:damage() then
		unit:damage():run_sequence_simple(seq)
	end
end

-- Lines: 3091 to 3100
function UnitNetworkHandler:sync_player_kill_statistic(tweak_table_name, is_headshot, weapon_unit, variant, stats_name, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) or not alive(weapon_unit) then
		return
	end

	local data = {
		name = tweak_table_name,
		stats_name = stats_name,
		head_shot = is_headshot,
		weapon_unit = weapon_unit,
		variant = variant
	}

	managers.statistics:killed_by_anyone(data)

	local attacker_state = managers.player:current_state()
	data.attacker_state = attacker_state

	managers.statistics:killed(data)
end

-- Lines: 3104 to 3115
function UnitNetworkHandler:set_attention_enabled(unit, setting_index, state, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(unit, sender) then
		return
	end

	if unit:in_slot(managers.slot:get_mask("players")) and unit:base().is_husk_player then
		local setting_name = tweak_data.attention:get_attention_name(setting_index)

		unit:movement():sync_attention_setting(setting_name, state, false)
	else
		debug_pause_unit(unit, "[UnitNetworkHandler:set_attention_enabled] invalid unit", unit)
	end
end

-- Lines: 3119 to 3125
function UnitNetworkHandler:link_attention_no_rot(parent_unit, attention_object, parent_object, local_pos, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not alive(parent_unit) or not alive(attention_object) then
		return
	end

	attention_object:attention():link(parent_unit, parent_object, local_pos)
end

-- Lines: 3129 to 3135
function UnitNetworkHandler:unlink_attention(attention_object, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not alive(attention_object) then
		return
	end

	attention_object:attention():link(nil)
end

-- Lines: 3139 to 3163
function UnitNetworkHandler:suspicion(suspect_peer_id, susp_value, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local suspect_member = managers.network:session():peer(suspect_peer_id)

	if not suspect_member then
		return
	end

	local suspect_unit = suspect_member:unit()

	if not suspect_unit then
		return
	end

	susp_value = (susp_value ~= 0 or false) and (susp_value == 255 and true or susp_value / 254)

	suspect_unit:movement():on_suspicion(nil, susp_value)
end

-- Lines: 3167 to 3187
function UnitNetworkHandler:suspicion_hud(observer_unit, status)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not alive(observer_unit) then
		return
	end

	if status == 0 then
		status = false
	elseif status == 1 then
		status = 1
	elseif status == 2 then
		status = true
	elseif status == 3 then
		status = "calling"
	elseif status == 4 then
		status = "called"
	elseif status == 5 then
		status = "call_interrupted"
	end

	managers.groupai:state():on_criminal_suspicion_progress(nil, observer_unit, status)
end

-- Lines: 3191 to 3197
function UnitNetworkHandler:group_ai_event(event_id, blame_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():sync_event(event_id, blame_id)
end

-- Lines: 3201 to 3221
function UnitNetworkHandler:start_timespeed_effect(effect_id, timer_name, affect_timer_names_str, speed, fade_in, sustain, fade_out, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local affect_timer_names = nil

	if affect_timer_names_str ~= "" then
		affect_timer_names = string.split(affect_timer_names_str, ";")
	end

	local effect_desc = {
		timer = timer_name,
		affect_timer = affect_timer_names,
		speed = speed,
		fade_in = fade_in,
		sustain = sustain,
		fade_out = fade_out
	}

	managers.time_speed:play_effect(effect_id, effect_desc)
end

-- Lines: 3225 to 3231
function UnitNetworkHandler:stop_timespeed_effect(effect_id, fade_out_duration, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.time_speed:stop_effect(effect_id, fade_out_duration)
end

-- Lines: 3235 to 3249
function UnitNetworkHandler:sync_upgrade(upgrade_category, upgrade_name, upgrade_level, sender)
	local peer = self._verify_sender(sender)

	if not peer then
		print("[UnitNetworkHandler:sync_upgrade] missing peer", upgrade_category, upgrade_name, upgrade_level, sender:ip_at_index(0))

		return
	end

	local unit = peer:unit()

	if not unit then
		print("[UnitNetworkHandler:sync_upgrade] missing unit", upgrade_category, upgrade_name, upgrade_level, sender:ip_at_index(0))

		return
	end

	unit:base():set_upgrade_value(upgrade_category, upgrade_name, upgrade_level)
end

-- Lines: 3256 to 3270
function UnitNetworkHandler:sync_temporary_upgrade_owned(upgrade_category, upgrade_name, upgrade_level, index, sender)
	local peer = self._verify_sender(sender)

	if not peer then
		print("[UnitNetworkHandler:sync_temporary_upgrade_owned] missing peer", upgrade_category, upgrade_name, upgrade_level, index, sender:ip_at_index(0))

		return
	end

	local unit = peer:unit()

	if not unit then
		print("[UnitNetworkHandler:sync_temporary_upgrade_owned] missing unit", upgrade_category, upgrade_name, upgrade_level, index, sender:ip_at_index(0))

		return
	end

	unit:base():set_temporary_upgrade_owned(upgrade_category, upgrade_name, upgrade_level, index)
end

-- Lines: 3274 to 3288
function UnitNetworkHandler:sync_temporary_upgrade_activated(upgrade_index, sender)
	local peer = self._verify_sender(sender)

	if not peer then
		print("[UnitNetworkHandler:sync_temporary_upgrade_activated] missing peer", upgrade_index, time, sender:ip_at_index(0))

		return
	end

	local unit = peer:unit()

	if not unit then
		print("[UnitNetworkHandler:sync_temporary_upgrade_activated] missing unit", upgrade_index, time, sender:ip_at_index(0))

		return
	end

	unit:base():activate_temporary_upgrade(upgrade_index)
end

-- Lines: 3292 to 3316
function UnitNetworkHandler:suppression(unit, ratio, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	local sup_tweak = unit:base():char_tweak().suppression

	if not sup_tweak then
		debug_pause_unit(unit, "[UnitNetworkHandler:suppression] husk missing suppression settings", unit)

		return
	end

	local amount_max = (sup_tweak.brown_point or sup_tweak.react_point)[2]
	local amount, panic_chance = nil

	if ratio == 16 then
		amount = "max"
		panic_chance = -1
	else
		amount = ratio == 15 and "max" or amount_max > 0 and (amount_max * ratio) / 15 or "max"
	end

	unit:character_damage():build_suppression(amount, panic_chance)
end

-- Lines: 3320 to 3326
function UnitNetworkHandler:suppressed_state(unit, state, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end

	unit:movement():on_suppressed(state)
end

-- Lines: 3330 to 3338
function UnitNetworkHandler:camera_yaw_pitch(cam_unit, yaw_255, pitch_255)
	if not alive(cam_unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local yaw = (360 * yaw_255) / 255 - 180
	local pitch = (180 * pitch_255) / 255 - 90

	cam_unit:base():apply_rotations(yaw, pitch)
end

-- Lines: 3342 to 3352
function UnitNetworkHandler:loot_link(loot_unit, parent_unit, sender)
	if not alive(loot_unit) or not alive(parent_unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if loot_unit == parent_unit then
		loot_unit:carry_data():unlink()
	else
		loot_unit:carry_data():link_to(parent_unit)
	end
end

-- Lines: 3356 to 3366
function UnitNetworkHandler:remove_unit(unit, sender)
	if not alive(unit) then
		return
	end

	if unit:id() ~= -1 then
		Network:detach_unit(unit)
	end

	unit:set_slot(0)
end

-- Lines: 3370 to 3376
function UnitNetworkHandler:sync_gui_net_event(unit, event_id, value, sender)
	if not alive(unit) or not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:digital_gui():sync_gui_net_event(event_id, value)
end

-- Lines: 3380 to 3386
function UnitNetworkHandler:sync_proximity_activation(unit, proximity_name, range_data_string, sender)
	if not alive(unit) or not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	unit:damage():sync_proximity_activation(proximity_name, range_data_string)
end

-- Lines: 3388 to 3408
function UnitNetworkHandler:sync_inflict_body_damage(body, unit, normal, position, direction, damage, velocity, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(body) then
		return
	end

	if not body:extension() then
		print("[UnitNetworkHandler:sync_inflict_body_damage] body has no extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage then
		print("[UnitNetworkHandler:sync_inflict_body_damage] body has no damage extension", body:name(), body:unit():name())

		return
	end

	if not body:extension().damage.damage_fire then
		print("[UnitNetworkHandler:sync_inflict_body_damage] body has no damage damage_bullet function", body:name(), body:unit():name())

		return
	end

	body:extension().damage:damage_fire(unit, normal, position, direction, damage, velocity)
end

-- Lines: 3413 to 3428
function UnitNetworkHandler:sync_team_relation(team_index_1, team_index_2, relation_code)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local team_id_1 = tweak_data.levels:get_team_names_indexed()[team_index_1]
	local team_id_2 = tweak_data.levels:get_team_names_indexed()[team_index_2]
	local relation = relation_code == 1 and "neutral" or relation_code == 2 and "friend" or "foe"

	if not team_id_1 or not team_id_2 or relation_code < 1 or relation_code > 3 then
		debug_pause("[UnitNetworkHandler:sync_team_relation] invalid params", team_index_1, team_index_2, relation_code, Global.level_data.level_id)

		return
	end

	managers.groupai:state():set_team_relation(team_id_1, team_id_2, relation, nil)
end

-- Lines: 3432 to 3444
function UnitNetworkHandler:sync_char_team(unit, team_index, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not self._verify_character(unit) then
		return
	end

	local team_id = tweak_data.levels:get_team_names_indexed()[team_index]
	local team_data = managers.groupai:state():team_data(team_id)

	unit:movement():set_team(team_data)
end

-- Lines: 3448 to 3450
function UnitNetworkHandler:sync_drill_upgrades(unit, autorepair_level_1, autorepair_level_2, drill_speed_level, silent, reduced_alert)
	unit:base():set_skill_upgrades(Drill.create_upgrades(autorepair_level_1, autorepair_level_2, drill_speed_level, silent, reduced_alert))
end

-- Lines: 3454 to 3470
function UnitNetworkHandler:sync_vehicle_driving(action, unit, player)
	Application:debug("[DRIVING_NET] sync_vehicle_driving " .. action)

	if not alive(unit) then
		return
	end

	local ext = unit:npc_vehicle_driving()
	ext = ext or unit:vehicle_driving()

	if action == "start" then
		ext:sync_start(player)
	elseif action == "stop" then
		ext:sync_stop()
	end
end

-- Lines: 3474 to 3479
function UnitNetworkHandler:sync_vehicle_set_input(unit, accelerate, steer, brake, handbrake, gear_up, gear_down, forced_gear)
	if not alive(unit) then
		return
	end

	unit:vehicle_driving():sync_set_input(accelerate, steer, brake, handbrake, gear_up, gear_down, forced_gear)
end

-- Lines: 3482 to 3487
function UnitNetworkHandler:sync_vehicle_state(unit, position, rotation, velocity)
	if not alive(unit) then
		return
	end

	unit:vehicle_driving():sync_state(position, rotation, velocity)
end

-- Lines: 3490 to 3496
function UnitNetworkHandler:sync_enter_vehicle_host(vehicle, seat_name, peer_id, player)
	Application:debug("[DRIVING_NET] sync_enter_vehicle_host", seat_name)

	if not alive(vehicle) then
		return
	end

	managers.player:server_enter_vehicle(vehicle, peer_id, player, seat_name)
end

-- Lines: 3498 to 3505
function UnitNetworkHandler:sync_vehicle_player(action, vehicle, peer_id, player, seat_name)
	Application:debug("[DRIVING_NET] sync_vehicle_player " .. action)

	if action == "enter" then
		managers.player:sync_enter_vehicle(vehicle, peer_id, player, seat_name)
	elseif action == "exit" then
		managers.player:sync_exit_vehicle(peer_id, player)
	end
end

-- Lines: 3507 to 3513
function UnitNetworkHandler:sync_vehicle_data(vehicle, state_name, occupant_driver, occupant_left, occupant_back_left, occupant_back_right, is_trunk_open)
	Application:debug("[DRIVING_NET] sync_vehicles_data")

	if not alive(vehicle) then
		return
	end

	managers.vehicle:sync_vehicle_data(vehicle, state_name, occupant_driver, occupant_left, occupant_back_left, occupant_back_right, is_trunk_open)
end

-- Lines: 3515 to 3521
function UnitNetworkHandler:sync_npc_vehicle_data(vehicle, state_name, target_unit)
	Application:debug("[DRIVING_NET] sync_npc_vehicle_data", vehicle, state_name)

	if not alive(vehicle) then
		return
	end

	managers.vehicle:sync_npc_vehicle_data(vehicle, state_name, target_unit)
end

-- Lines: 3524 to 3530
function UnitNetworkHandler:sync_vehicle_loot(vehicle, carry_id1, multiplier1, carry_id2, multiplier2, carry_id3, multiplier3)
	Application:debug("[DRIVING_NET] sync_vehicle_loot")

	if not alive(vehicle) then
		return
	end

	managers.vehicle:sync_vehicle_loot(vehicle, carry_id1, multiplier1, carry_id2, multiplier2, carry_id3, multiplier3)
end

-- Lines: 3532 to 3549
function UnitNetworkHandler:sync_ai_vehicle_action(action, vehicle, data, unit)
	Application:debug("[DRIVING_NET] sync_ai_vehicle_action: ", action, data)

	if not alive(vehicle) then
		return
	end

	if action == "health" then
		vehicle:character_damage():sync_vehicle_health(data)
	elseif action == "revive" then
		vehicle:character_damage():sync_vehicle_revive(data)
	elseif action == "state" then
		vehicle:vehicle_driving():sync_vehicle_state(data)
	else
		if not alive(unit) then
			return
		end

		vehicle:vehicle_driving():sync_ai_vehicle_action(action, data, unit)
	end
end

-- Lines: 3551 to 3557
function UnitNetworkHandler:server_store_loot_in_vehicle(vehicle, loot_bag)
	Application:debug("[DRIVING_NET] server_store_loot_in_vehicle")

	if not alive(vehicle) or not alive(loot_bag) then
		return
	end

	vehicle:vehicle_driving():server_store_loot_in_vehicle(loot_bag)
end

-- Lines: 3559 to 3565
function UnitNetworkHandler:sync_vehicle_change_stance(shooting_unit, stance)
	Application:debug("[DRIVING_NET] sync_vehicle_change_stance")

	if not alive(shooting_unit) then
		return
	end

	shooting_unit:movement():sync_vehicle_change_stance(stance)
end

-- Lines: 3567 to 3573
function UnitNetworkHandler:sync_store_loot_in_vehicle(vehicle, loot_bag, carry_id, multiplier)
	Application:debug("[DRIVING_NET] sync_store_loot_in_vehicle")

	if not alive(vehicle) or not alive(loot_bag) then
		return
	end

	vehicle:vehicle_driving():sync_store_loot_in_vehicle(loot_bag, carry_id, multiplier)
end

-- Lines: 3575 to 3578
function UnitNetworkHandler:server_give_vehicle_loot_to_player(vehicle, peer_id)
	Application:debug("[DRIVING_NET] server_give_vehicle_loot_to_player")
	vehicle:vehicle_driving():server_give_vehicle_loot_to_player(peer_id)
end

-- Lines: 3580 to 3583
function UnitNetworkHandler:sync_give_vehicle_loot_to_player(vehicle, carry_id, multiplier, peer_id)
	Application:debug("[DRIVING_NET] sync_give_vehicle_loot_to_player")
	vehicle:vehicle_driving():sync_give_vehicle_loot_to_player(carry_id, multiplier, peer_id)
end

-- Lines: 3585 to 3588
function UnitNetworkHandler:sync_vehicle_interact_trunk(vehicle, peer_id)
	Application:debug("[DRIVING_NET] sync_vehicle_interact_trunk")
	vehicle:vehicle_driving():_interact_trunk(vehicle)
end

-- Lines: 3592 to 3603
function UnitNetworkHandler:sync_damage_reduction_buff(damage_reduction)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not damage_reduction then
		debug_pause("[UnitNetworkHandler:sync_damage_reduction_buff] invalid params", damage_reduction)

		return
	end

	managers.groupai:state():set_phalanx_damage_reduction_buff(damage_reduction)
end

-- Lines: 3607 to 3613
function UnitNetworkHandler:sync_assault_endless(enabled)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	managers.groupai:state():set_assault_endless(enabled)
end

-- Lines: 3617 to 3625
function UnitNetworkHandler:action_jump(unit, pos, jump_vec, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:movement():sync_action_jump(pos, jump_vec)
end

-- Lines: 3627 to 3635
function UnitNetworkHandler:action_jump_middle(unit, pos, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:movement():sync_action_jump_middle(pos)
end

-- Lines: 3637 to 3645
function UnitNetworkHandler:action_land(unit, pos, sender)
	if not self._verify_character_and_sender(unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:movement():sync_action_land(pos)
end

-- Lines: 3647 to 3658
function UnitNetworkHandler:sync_player_swansong(unit, active, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end

	if alive(unit) and unit:character_damage() then
		unit:character_damage().swansong = active

		managers.network:session():send_to_peers_except(peer:id(), "sync_swansong_hud", unit, peer:id())
		self:sync_swansong_hud(unit, peer:id())
	end
end

-- Lines: 3660 to 3664
function UnitNetworkHandler:special_eq_response(unit, sender)
	if unit:interaction().apply_item_pickup then
		unit:interaction():apply_item_pickup()
	end
end

-- Lines: 3666 to 3684
function UnitNetworkHandler:sync_swansong_hud(unit, peer_id)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local panel_id = nil

	for i, panel in ipairs(managers.hud._teammate_panels) do
		if panel._peer_id == peer_id then
			panel_id = i

			break
		end
	end

	if panel_id then
		managers.hud:set_teammate_condition(panel_id, "mugshot_swansong", managers.localization:text("debug_mugshot_downed"))
	else
		Application:error(string.format("Panel not found for peer: %d", peer_id))
	end
end

-- Lines: 3686 to 3704
function UnitNetworkHandler:sync_swansong_timer(unit, current, total, revives, peer_id)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local panel_id = nil

	for i, panel in ipairs(managers.hud._teammate_panels) do
		if panel._peer_id == peer_id then
			panel_id = i

			break
		end
	end

	if panel_id then
		managers.hud:set_teammate_custom_radial(panel_id, {
			current = current,
			total = total,
			revives = revives
		})
	else
		Application:error(string.format("Panel not found for peer: %d", peer_id))
	end
end

-- Lines: 3709 to 3716
function UnitNetworkHandler:sync_fall_position(unit, pos, rot)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if alive(unit) then
		unit:movement():sync_fall_position(pos, rot)
	end
end

-- Lines: 3721 to 3723
function UnitNetworkHandler:sync_spawn_extra_ammo(unit)
	managers.player:spawn_extra_ammo(unit)
end

-- Lines: 3728 to 3736
function UnitNetworkHandler:sync_stored_pos(unit, sync, pos, rot)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if alive(unit) then
		unit:base():sync_stored_pos(sync, pos, rot)
	end
end

-- Lines: 3739 to 3747
function UnitNetworkHandler:sync_team_ai_stopped(unit, stopped)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if alive(unit) then
		unit:movement():set_should_stay(stopped)
	end
end

-- Lines: 3751 to 3759
function UnitNetworkHandler:sync_damage_achievements(unit, weapon_unit, attacker_unit, distance, damage, head_shot, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if alive(unit) and unit:character_damage() then
		unit:character_damage():client_check_damage_achievements(weapon_unit, attacker_unit, distance, damage, head_shot)
	end
end

-- Lines: 3764 to 3777
function UnitNetworkHandler:sync_medic_heal(unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if alive(unit) and unit:movement() then
		local action_data = {
			body_part = 3,
			type = "heal",
			client_interrupt = Network:is_client()
		}

		unit:movement():action_request(action_data)
	end
end

-- Lines: 3784 to 3790
function UnitNetworkHandler:sync_explosion_to_client(unit, position, normal, damage, range, curve_pow, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.explosion:give_local_player_dmg(position, range, damage)
	managers.explosion:explode_on_client(position, normal, unit, damage, range, curve_pow)
end

-- Lines: 3792 to 3834
function UnitNetworkHandler:sync_friendly_fire_damage(peer_id, unit, damage, variant, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if managers.network:session():local_peer():id() == peer_id then
		local player_unit = managers.player:player_unit()

		if alive(player_unit) and alive(unit) then
			local attack_info = {
				ignore_suppression = true,
				range = 1000,
				attacker_unit = unit,
				damage = damage,
				variant = variant,
				col_ray = {position = unit:position()},
				push_vel = Vector3()
			}

			if variant == "bullet" or variant == "projectile" then
				player_unit:character_damage():damage_bullet(attack_info)
			elseif variant == "melee" then
				player_unit:character_damage():damage_melee(attack_info)
			elseif variant == "fire" then
				player_unit:character_damage():damage_fire(attack_info)
			end
		end
	end

	managers.job:set_memory("trophy_flawless", true, false)
end

-- Lines: 3840 to 3847
function UnitNetworkHandler:sync_flashbang_event(unit, event_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if alive(unit) then
		unit:base():on_network_event(event_id)
	end
end

-- Lines: 3851 to 3874
function UnitNetworkHandler:sync_ability_hud(end_time, time_total, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	local panel_id = nil

	for i, panel in ipairs(managers.hud._teammate_panels) do
		if panel._peer_id == peer:id() then
			panel_id = i

			break
		end
	end

	if panel_id then
		local current_time = managers.game_play_central:get_heist_timer()

		managers.hud:activate_teammate_ability_radial(panel_id, end_time - current_time, time_total)
	else
		Application:error("HUD panel not found from peer id!")
	end
end

-- Lines: 3877 to 3891
function UnitNetworkHandler:sync_underbarrel_switch(selection_index, underbarrel_id, is_on, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	local unit = managers.criminals:character_unit_by_peer_id(peer:id())

	if not unit then
		return
	end

	unit:inventory():set_weapon_underbarrel(selection_index, underbarrel_id, is_on)
end

-- Lines: 3895 to 3903
function UnitNetworkHandler:sync_ai_throw_bag(unit, carry_unit, target_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if alive(unit) and alive(carry_unit) then
		unit:movement():sync_throw_bag(carry_unit, target_unit)
	end
end

-- Lines: 3905 to 3920
function UnitNetworkHandler:request_carried_bag_unit(ai_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	if alive(ai_unit) then
		local carry_unit = ai_unit:movement()._carry_unit

		if carry_unit then
			managers.network:session():send_to_peer(peer, "sync_carried_bag_unit", ai_unit, carry_unit)
		end
	end
end

-- Lines: 3922 to 3931
function UnitNetworkHandler:sync_carried_bag_unit(ai_unit, carry_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if alive(ai_unit) and alive(carry_unit) then
		ai_unit:movement():set_carrying_bag(carry_unit)
		carry_unit:carry_data():link_to(ai_unit)
	end
end

-- Lines: 3936 to 3946
function UnitNetworkHandler:sync_unit_spawn(parent_unit, spawn_unit, align_obj_name, unit_id, parent_extension_name)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(parent_unit) or not alive(spawn_unit) then
		return
	end

	parent_unit[parent_extension_name](parent_unit):spawn_unit(unit_id, align_obj_name, spawn_unit)
end

-- Lines: 3950 to 3960
function UnitNetworkHandler:sync_unit_surrendered(unit, surrendered)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(unit) or not unit:brain() or not unit:brain().sync_surrender then
		return
	end

	unit:brain():sync_surrender(surrendered)
end

-- Lines: 3964 to 3974
function UnitNetworkHandler:sync_unit_converted(unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(unit) and unit:brain() and unit:brain().sync_converted then
		return
	end

	unit:brain():sync_converted()
end

-- Lines: 3978 to 3988
function UnitNetworkHandler:sync_link_spawned_unit(parent_unit, unit_id, joint_table, parent_extension_name)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(parent_unit) then
		return
	end

	parent_unit[parent_extension_name](parent_unit):_link_joints(unit_id, joint_table)
end

-- Lines: 3992 to 4002
function UnitNetworkHandler:run_spawn_unit_sequence(parent_unit, parent_extension_name, unit_id, sequence_name)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(parent_unit) then
		return
	end

	parent_unit[parent_extension_name](parent_unit):_spawn_run_sequence(unit_id, sequence_name)
end

-- Lines: 4006 to 4016
function UnitNetworkHandler:run_local_push_child_unit(parent_unit, parent_extension_name, unit_id, mass, pow, vec3_a, vec3_b)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(parent_unit) then
		return
	end

	parent_unit[parent_extension_name](parent_unit):local_push_child_unit(unit_id, mass, pow, vec3_a, vec3_b)
end

-- Lines: 4020 to 4035
function UnitNetworkHandler:sync_special_character_material(character_unit, material_name)
	if not alive(character_unit) then
		return
	end

	local mtr_ids = Idstring(material_name)

	if DB:has(Idstring("material_config"), mtr_ids) then
		character_unit:set_material_config(mtr_ids, true)

		if character_unit:armor_skin() then
			character_unit:armor_skin():_apply_cosmetics()
		end
	end
end

-- Lines: 4040 to 4048
function UnitNetworkHandler:sync_enemy_buff(enemy_unit, buff_category, buff_total, sender)
	if not alive(enemy_unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	enemy_unit:base():_sync_buff_total(buff_category, buff_total)
end

-- Lines: 4050 to 4055
function UnitNetworkHandler:sync_tear_gas_grenade_properties(grenade, radius, damage, duration)
	grenade:base():set_properties({
		radius = radius,
		damage = damage * 0.1
	})
end

-- Lines: 4057 to 4059
function UnitNetworkHandler:sync_tear_gas_grenade_detonate(grenade)
	grenade:base():detonate()
end

-- Lines: 4065 to 4075
function UnitNetworkHandler:sync_spawn_smoke_screen(unit, dodge_bonus)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(unit) then
		return
	end

	managers.player:_sync_activate_smoke_screen(unit, dodge_bonus)
end

-- Lines: 4080 to 4088
function UnitNetworkHandler:sync_melee_start(unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:movement():sync_melee_start()
end

-- Lines: 4090 to 4098
function UnitNetworkHandler:sync_melee_discharge(unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:movement():sync_melee_discharge()
end

-- Lines: 4102 to 4114
function UnitNetworkHandler:sync_interaction_anim(unit, is_start, tweak_data, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		return
	end

	if is_start then
		unit:movement():sync_interaction_anim_start(tweak_data)
	else
		unit:movement():sync_interaction_anim_end()
	end
end

-- Lines: 4118 to 4126
function UnitNetworkHandler:sync_shotgun_push(unit, hit_pos, dir, distance, attacker, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		return
	end

	managers.game_play_central:_do_shotgun_push(unit, hit_pos, dir, distance, attacker, sender)
end

-- Lines: 4131 to 4139
function UnitNetworkHandler:sync_carry_set_position_and_throw(unit, destination, direction, force, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:carry_data():set_position_and_throw(destination, direction, force)
end

-- Lines: 4211 to 4220
function UnitNetworkHandler:action_teleport(unit, position, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(unit) then
		return
	end

	unit:movement():sync_action_teleport(position)
end

-- Lines: 4241 to 4249
function UnitNetworkHandler:sync_tag_team(tagged, owner, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	if not alive(tagged) or not alive(owner) then
		return
	end

	managers.player:sync_tag_team(tagged, owner)
end

-- Lines: 4251 to 4256
function UnitNetworkHandler:end_tag_team(tagged, owner, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	managers.player:end_tag_team(tagged, owner)
end

-- Lines: 4260 to 4270
function UnitNetworkHandler:sync_delayed_damage_hud(delayed_damage, sender)
	local peer = self._verify_sender(sender)

	if not peer or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local teammate_panel = managers.hud:get_teammate_panel_by_peer(peer)

	if teammate_panel then
		teammate_panel:set_delayed_damage(delayed_damage)
	end
end

-- Lines: 4273 to 4283
function UnitNetworkHandler:sync_damage_absorption_hud(absorption_amount, sender)
	local peer = self._verify_sender(sender)

	if not peer or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local teammate_panel = managers.hud:get_teammate_panel_by_peer(peer)

	if teammate_panel then
		teammate_panel:set_absorb_active(absorption_amount)
	end
end

