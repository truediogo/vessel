extends Node3D

# Main scene orchestrator for Project VESSEL Phase 0 Gameplay Vertical Slice.
# Now starts with a Character Creation screen, then transitions to gameplay.

var world_builder: WorldBuilder
var player: PlayerController
var hud: GameHUD
var enemies_container: Node3D
var loot_container: Node3D
var vfx_container: Node3D
var sun_light: DirectionalLight3D
var world_env: WorldEnvironment

var _in_boss_zone := false

# Character creation
var _creation_screen: CharacterCreation
var _game_started := false

func _ready() -> void:
	# Show character creation screen first
	_creation_screen = CharacterCreation.new()
	add_child(_creation_screen)
	_creation_screen.creation_finished.connect(_on_creation_finished)

func _on_creation_finished(appearance: Dictionary) -> void:
	# Remove creation screen
	_creation_screen.queue_free()
	_creation_screen = null
	_game_started = true

	# Build the game world
	_setup_lighting_and_sky()

	world_builder = WorldBuilder.new()
	add_child(world_builder)
	world_builder.build_world()

	enemies_container = Node3D.new()
	add_child(enemies_container)

	loot_container = Node3D.new()
	add_child(loot_container)

	vfx_container = Node3D.new()
	add_child(vfx_container)

	player = PlayerController.new()
	player.enemies_container = enemies_container
	player.vfx_container = vfx_container
	player.appearance = appearance
	add_child(player)

	_spawn_wild_enemies()

	hud = GameHUD.new()
	add_child(hud)
	hud.setup(player)

	# Connect gameplay signals
	player.stats_changed.connect(hud.refresh_stats)
	player.zone_changed.connect(_on_zone_changed)
	player.interact_forge_requested.connect(hud.toggle_forge_panel)
	player.toast_message.connect(hud.show_toast)
	player.dropped_loot_created.connect(_on_player_dropped_loot)

	hud.forge_upgrade_requested.connect(_on_forge_upgrade)
	hud.sandbox_bump_requested.connect(_on_sandbox_bump)
	hud.cycle_vessel_body_requested.connect(_on_cycle_vessel_body)

func _on_cycle_vessel_body() -> void:
	var order := ["warrior", "hunter", "mage"]
	var idx := (order.find(player.rig.archetype) + 1) % order.size()
	player.rig.load_archetype(order[idx])
	hud.show_toast("Vessel form: " + order[idx].capitalize(), Color(0.75, 0.92, 1.0))

func _setup_lighting_and_sky() -> void:
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-42.0, 36.0, 0.0)
	sun_light.light_color = Color(1.0, 0.95, 0.85)
	sun_light.light_energy = 1.05
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 105.0
	add_child(sun_light)

	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.58, 0.88)
	sky_mat.sky_horizon_color = Color(0.84, 0.86, 0.80)
	sky_mat.ground_bottom_color = Color(0.28, 0.42, 0.22)
	sky_mat.ground_horizon_color = Color(0.68, 0.74, 0.60)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.64, 0.66, 0.76)
	env.ambient_light_energy = 0.58
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.78)
	env.fog_density = 0.0030
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	add_child(world_env)

func _spawn_wild_enemies() -> void:
	# Wild Meadow Stalkers north of the 7.2m-Wide Viaduct Bridge
	_add_enemy(WildEnemy.Kind.BOAR, Vector3(-6.8, 0, -17.5))
	_add_enemy(WildEnemy.Kind.BOAR, Vector3(7.2, 0, -18.5))
	_add_enemy(WildEnemy.Kind.BOAR, Vector3(-2.0, 0, -22.5))

	# Armored Ruin Vanguards guarding the approach to the Ancient Colosseum
	_add_enemy(WildEnemy.Kind.KOBOLD, Vector3(-8.2, 0, -28.5))
	_add_enemy(WildEnemy.Kind.KOBOLD, Vector3(8.2, 0, -29.5))

	# Towering Labyrinth Crimson Lord in the Ancient Colosseum Piazza
	_add_enemy(WildEnemy.Kind.BOSS, Vector3(0.0, 0, -42.0))

func _add_enemy(kind: WildEnemy.Kind, pos: Vector3) -> void:
	var e := WildEnemy.new()
	e.kind = kind
	e.home_position = pos
	e.player_ref = player
	e.defeated.connect(_on_enemy_defeated)
	enemies_container.add_child(e)

func _on_enemy_defeated(enemy: WildEnemy, pos: Vector3, reward: Dictionary) -> void:
	var pouch := LootPouch.new()
	pouch.setup(pos, reward, false)
	pouch.collected.connect(_on_loot_collected)
	loot_container.add_child(pouch)
	if enemy.kind == WildEnemy.Kind.BOSS:
		hud.show_plaza_broadcast("★ LABYRINTH HORNED LORD DEFEATED! Collect the Boss Shards & return to the Plaza! ★", Color(1.0, 0.82, 0.34))

func _on_player_dropped_loot(pos: Vector3, dropped: Dictionary) -> void:
	var pouch := LootPouch.new()
	pouch.setup(pos, dropped, true)
	pouch.collected.connect(_on_loot_collected)
	loot_container.add_child(pouch)

func _on_loot_collected(_pouch: LootPouch, contents: Dictionary) -> void:
	player.add_loot(contents)
	var parts: Array[String] = []
	if int(contents.get("gold", 0)) > 0:
		parts.append("+%dg" % int(contents["gold"]))
	if int(contents.get("ore", 0)) > 0:
		parts.append("+%d Ore" % int(contents["ore"]))
	if int(contents.get("shards", 0)) > 0:
		parts.append("+%d Shards" % int(contents["shards"]))
	hud.show_toast("Looted: " + ", ".join(parts), Color(1.0, 0.90, 0.45))

func _on_zone_changed(zone_name: String, is_safe: bool) -> void:
	hud.set_zone(zone_name, is_safe)
	_in_boss_zone = (zone_name.find("BOSS") != -1)

func _process(delta: float) -> void:
	if not _game_started:
		return

	# Pickup nearby loot pouches smoothly
	for child in loot_container.get_children():
		if child is LootPouch:
			child.try_pickup(player.global_position)

	# Subtle sunlit -> dramatic boss-ruins lighting shift
	var target_col := Color(0.95, 0.68, 0.56) if _in_boss_zone else Color(1.0, 0.96, 0.86)
	var target_amb := Color(0.46, 0.38, 0.58) if _in_boss_zone else Color(0.68, 0.74, 0.88)
	sun_light.light_color = sun_light.light_color.lerp(target_col, delta * 2.2)
	world_env.environment.ambient_light_color = world_env.environment.ambient_light_color.lerp(target_amb, delta * 2.2)

func _on_forge_upgrade(slot: String) -> void:
	var current_lv := player.sword_level if slot == "sword" else player.armor_level
	var recipe := GearTiers.get_upgrade_recipe(current_lv)
	if not recipe["can_upgrade"]:
		hud.set_forge_result("Already at Masterwork +15!", Color(1.0, 0.86, 0.36))
		return

	var total_gold := player.banked_gold + player.run_gold
	var total_ore := player.banked_ore + player.run_ore
	var total_shards := player.banked_shards + player.run_shards

	if total_gold < int(recipe["gold"]) or total_ore < int(recipe["ore"]) or total_shards < int(recipe["shards"]):
		hud.set_forge_result("Not enough materials! Hunt Boars, Kobolds, or the Boss north of town (or use Free Test).", Color(1.0, 0.50, 0.42))
		return

	# Spend from banked first
	_spend_currency("gold", int(recipe["gold"]))
	_spend_currency("ore", int(recipe["ore"]))
	_spend_currency("shards", int(recipe["shards"]))

	var success := randf() <= float(recipe["chance"])
	if success:
		var next_lv := current_lv + 1
		if slot == "sword":
			player.set_gear_levels(player.armor_level, next_lv)
		else:
			player.set_gear_levels(next_lv, player.sword_level)
		var info := GearTiers.get_tier_info(next_lv)
		world_builder.trigger_forge_burst(info["badge_color"])
		player.add_camera_shake(0.22)
		hud.set_forge_result("FORGE SUCCESS! %s reached +%d (%s)!" % [slot.capitalize(), next_lv, info["name"]], info["badge_color"])
		if next_lv in [7, 10, 13, 15]:
			hud.show_plaza_broadcast("★ PLAZA ANNOUNCEMENT: A Vessel forged %s +%d (%s)! ★" % [slot.capitalize(), next_lv, info["name"]], info["badge_color"])
	else:
		var drop := int(recipe["fail_drop"])
		var new_lv := maxi(0, current_lv - drop)
		if slot == "sword":
			player.set_gear_levels(player.armor_level, new_lv)
		else:
			player.set_gear_levels(new_lv, player.sword_level)
		world_builder.trigger_forge_burst(Color(0.95, 0.32, 0.24))
		player.add_camera_shake(0.26)
		var note := "Dropped to +%d (item never destroyed!)." % new_lv if drop > 0 else "Materials consumed, level held!"
		hud.set_forge_result("Forge crackled! " + note, Color(1.0, 0.52, 0.36))

	hud.refresh_stats()

func _spend_currency(kind: String, amount: int) -> void:
	match kind:
		"gold":
			var take := mini(player.banked_gold, amount)
			player.banked_gold -= take
			player.run_gold -= (amount - take)
		"ore":
			var take := mini(player.banked_ore, amount)
			player.banked_ore -= take
			player.run_ore -= (amount - take)
		"shards":
			var take := mini(player.banked_shards, amount)
			player.banked_shards -= take
			player.run_shards -= (amount - take)

func _on_sandbox_bump(mode: String, val: int) -> void:
	if mode == "both":
		player.set_gear_levels(player.armor_level + val, player.sword_level + val)
	elif mode == "set7":
		player.set_gear_levels(7, 7)
	elif mode == "set13":
		player.set_gear_levels(13, 13)
	elif mode == "reset":
		player.set_gear_levels(0, 0)
	var info := GearTiers.get_tier_info(player.armor_level)
	world_builder.trigger_forge_burst(info["badge_color"])
	hud.set_forge_result("Previewing +%d (%s) on your Vessel!" % [player.armor_level, info["name"]], info["badge_color"])
	hud.refresh_stats()
