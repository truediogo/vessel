class_name GearTiers
extends RefCounted

# MU Online-inspired visual + stat progression for equipment levels +0 to +15.
# One base 3D mesh transforms cleanly via shader parameters and ember particles.

const MAX_LEVEL := 15

static func get_tier_info(level: int) -> Dictionary:
	var lv := clampi(level, 0, MAX_LEVEL)
	if lv <= 3:
		return {
			"name": "Iron Forged",
			"badge_color": Color(0.72, 0.73, 0.76),
			"tier_color": Color(0.34, 0.36, 0.40),
			"shadow_color": Color(0.20, 0.22, 0.28),
			"specular_color": Color(0.84, 0.87, 0.92),
			"rim_color": Color(0.75, 0.78, 0.85),
			"cloak_color": Color(0.45, 0.39, 0.31),
			"tier_blend": 0.10 + lv * 0.08,
			"sheen_strength": 0.25 + lv * 0.08,
			"rim_strength": 0.20 + lv * 0.05,
			"pulse_speed": 0.0,
			"pulse_strength": 0.0,
			"ember_amount": 0,
			"ember_color": Color(0.8, 0.85, 0.95),
		}
	elif lv <= 6:
		var t := float(lv - 4) / 2.0
		return {
			"name": "Tempered Steel",
			"badge_color": Color(0.86, 0.91, 0.98),
			"tier_color": Color(0.58, 0.65, 0.74).lerp(Color(0.66, 0.76, 0.88), t),
			"shadow_color": Color(0.28, 0.34, 0.46),
			"specular_color": Color(0.95, 0.98, 1.0),
			"rim_color": Color(0.82, 0.92, 1.0),
			"cloak_color": Color(0.32, 0.34, 0.40),
			"tier_blend": 0.65 + t * 0.15,
			"sheen_strength": 0.85 + t * 0.25,
			"rim_strength": 0.45 + t * 0.15,
			"pulse_speed": 1.4,
			"pulse_strength": 0.18 + t * 0.10,
			"ember_amount": 0,
			"ember_color": Color(0.85, 0.93, 1.0),
		}
	elif lv <= 9:
		var t := float(lv - 7) / 2.0
		return {
			"name": "Cobalt Sapphire",
			"badge_color": Color(0.42, 0.76, 1.0),
			"tier_color": Color(0.22, 0.48, 0.86).lerp(Color(0.28, 0.62, 0.98), t),
			"shadow_color": Color(0.11, 0.20, 0.44),
			"specular_color": Color(0.75, 0.95, 1.0),
			"rim_color": Color(0.45, 0.86, 1.0),
			"cloak_color": Color(0.22, 0.25, 0.34),
			"tier_blend": 0.88,
			"sheen_strength": 1.35 + t * 0.25,
			"rim_strength": 0.85 + t * 0.20,
			"pulse_speed": 2.4 + t * 0.4,
			"pulse_strength": 0.45 + t * 0.15,
			"ember_amount": 8 + (lv - 7) * 4,
			"ember_color": Color(0.55, 0.88, 1.0),
		}
	elif lv <= 12:
		var t := float(lv - 10) / 2.0
		return {
			"name": "Arcane Emerald",
			"badge_color": Color(0.36, 0.96, 0.72),
			"tier_color": Color(0.16, 0.68, 0.56).lerp(Color(0.24, 0.82, 0.64), t),
			"shadow_color": Color(0.08, 0.28, 0.28),
			"specular_color": Color(0.82, 1.0, 0.92),
			"rim_color": Color(0.42, 1.0, 0.78),
			"cloak_color": Color(0.16, 0.25, 0.27),
			"tier_blend": 0.92,
			"sheen_strength": 1.75 + t * 0.25,
			"rim_strength": 1.15 + t * 0.20,
			"pulse_speed": 3.2 + t * 0.4,
			"pulse_strength": 0.70 + t * 0.15,
			"ember_amount": 16 + (lv - 10) * 4,
			"ember_color": Color(0.48, 1.0, 0.80),
		}
	else:
		var t := float(lv - 13) / 2.0
		return {
			"name": "Crimson-Gold Masterwork",
			"badge_color": Color(1.0, 0.80, 0.28),
			"tier_color": Color(0.84, 0.30, 0.18).lerp(Color(0.96, 0.52, 0.18), t),
			"shadow_color": Color(0.38, 0.11, 0.12),
			"specular_color": Color(1.0, 0.92, 0.48),
			"rim_color": Color(1.0, 0.82, 0.26),
			"cloak_color": Color(0.28, 0.14, 0.20),
			"tier_blend": 0.95,
			"sheen_strength": 2.25 + t * 0.35,
			"rim_strength": 1.55 + t * 0.30,
			"pulse_speed": 4.2 + t * 0.5,
			"pulse_strength": 0.95 + t * 0.25,
			"ember_amount": 26 + (lv - 13) * 8,
			"ember_color": Color(1.0, 0.86, 0.36),
		}

static func get_upgrade_recipe(current_level: int) -> Dictionary:
	var lv := clampi(current_level, 0, MAX_LEVEL)
	if lv >= MAX_LEVEL:
		return {"can_upgrade": false, "ore": 0, "shards": 0, "gold": 0, "chance": 0.0, "fail_drop": 0}
	var ore := 2 + lv * 2
	var shards := 0 if lv < 6 else (1 + int((lv - 6) / 2))
	var gold := 25 + lv * 20
	var chance := 1.0
	var fail_drop := 0
	if lv >= 4 and lv <= 6:
		chance = 0.85 - (lv - 4) * 0.05
		fail_drop = 0
	elif lv >= 7 and lv <= 9:
		chance = 0.68 - (lv - 7) * 0.06
		fail_drop = 1
	elif lv >= 10 and lv <= 12:
		chance = 0.50 - (lv - 10) * 0.05
		fail_drop = 1
	elif lv >= 13:
		chance = 0.35 - (lv - 13) * 0.05
		fail_drop = 2
	return {
		"can_upgrade": true,
		"ore": ore,
		"shards": shards,
		"gold": gold,
		"chance": chance,
		"fail_drop": fail_drop,
	}

static func apply_to_gear_material(mat: ShaderMaterial, level: int, is_weapon: bool = false) -> void:
	var info := get_tier_info(level)
	var col: Color = info["tier_color"]
	if is_weapon and level >= 13:
		# Masterwork blades glow radiant gilded gold matching our concept art
		col = Color(0.98, 0.74, 0.22)
	mat.set_shader_parameter("tier_color", col)
	mat.set_shader_parameter("shadow_color", info["shadow_color"])
	mat.set_shader_parameter("specular_color", info["specular_color"])
	mat.set_shader_parameter("rim_color", info["rim_color"])
	mat.set_shader_parameter("tier_blend", info["tier_blend"])
	mat.set_shader_parameter("sheen_strength", info["sheen_strength"])
	mat.set_shader_parameter("rim_strength", info["rim_strength"])
	mat.set_shader_parameter("pulse_speed", info["pulse_speed"])
	mat.set_shader_parameter("pulse_strength", info["pulse_strength"])
