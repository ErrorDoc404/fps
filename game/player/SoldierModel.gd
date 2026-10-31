class_name SoldierModel
extends Node3D
## Third-person character presentation (client only; no character models were supplied).
## Low-poly operators in the style of the supplied Synty portraits: camo uniform, plate carrier with pouches,
## helmet/headgear, knee pads, gloves, backpack and a real WeaponModel in the hands. Faction and role give
## distinct silhouettes: Task Force operators (arid camo, tan kit, class patch) vs Dominion units (urban black,
## red armbands, skull insignia) — rifleman, heavy (bulky armour + visor), spotter (hood + gas mask), officer (beret + coat).
## Procedural poses: stand / crouch / prone / downed / dead, walk cycle, aim pitch, firing kick.

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arms: Node3D
var _thigh_l: Node3D
var _thigh_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D
var _gun: Node3D
var _phase := 0.0
var _kick := 0.0
var _lie := 0.0

## kind: "assault" | "medic" | "recon" | "support" (Task Force)  or  "infantry" | "heavy" | "spotter" | "command" (Dominion)
func build_kind(kind: String, weapon_id: String, scale_f := 1.0) -> void:
	scale = Vector3.ONE * scale_f
	var dominion := kind in ["infantry", "heavy", "spotter", "command"]
	var uniform: Material = Mat.camo("dominion" if dominion else "tf")
	if kind == "spotter":
		uniform = Mat.camo("recon")
	var vest_c := Color(0.13, 0.13, 0.14) if dominion else Color(0.56, 0.5, 0.36)
	if kind == "recon":
		vest_c = Color(0.36, 0.38, 0.26)
	var vest := Mat.fabric(vest_c)
	var pouch := Mat.fabric(vest_c.darkened(0.15))
	var skin := Mat.skin(Color(0.74, 0.57, 0.45) if hash(kind) % 2 == 0 else Color(0.55, 0.4, 0.3))
	var glove := Mat.fabric(Color(0.15, 0.14, 0.12))
	var boot := Mat.rubber(Color(0.2, 0.16, 0.12) if not dominion else Color(0.07, 0.07, 0.07))

	_hips = Node3D.new(); _hips.position.y = 0.95; add_child(_hips)
	Geo.part(_hips, Vector3(0.36, 0.18, 0.22), Vector3(0, 0.0, 0), uniform, Vector3.ZERO, 0.05)          # pelvis
	Geo.part(_hips, Vector3(0.4, 0.06, 0.25), Vector3(0, 0.08, 0), Mat.fabric(Color(0.12, 0.12, 0.1)), Vector3.ZERO, 0.02)  # belt
	Geo.part(_hips, Vector3(0.08, 0.14, 0.12), Vector3(0.22, -0.02, 0.02), pouch, Vector3.ZERO, 0.02)     # holster / dump pouch
	_thigh_l = _leg(-0.1, uniform, boot, kind)
	_thigh_r = _leg(0.1, uniform, boot, kind)
	_shin_l = _thigh_l.get_child(_thigh_l.get_child_count() - 1)
	_shin_r = _thigh_r.get_child(_thigh_r.get_child_count() - 1)

	_torso = Node3D.new(); _torso.position.y = 0.08; _hips.add_child(_torso)
	Geo.part(_torso, Vector3(0.42, 0.5, 0.24), Vector3(0, 0.3, 0), uniform, Vector3.ZERO, 0.07)           # shirt
	if kind == "command":
		Geo.part(_torso, Vector3(0.46, 0.62, 0.27), Vector3(0, 0.22, 0), Mat.fabric(Color(0.24, 0.25, 0.22)), Vector3.ZERO, 0.06)  # officer coat
		for i in 3:
			Geo.part(_torso, Vector3(0.025, 0.025, 0.01), Vector3(0.05, 0.42 - i * 0.12, -0.14), Mat.metal(Color(0.75, 0.62, 0.3), 0.3), Vector3.ZERO, 0.005)
		Geo.part(_torso, Vector3(0.12, 0.04, 0.02), Vector3(-0.1, 0.46, -0.14), Mat.painted(Color(0.6, 0.12, 0.1)), Vector3.ZERO, 0.0)
	else:
		var heavy := kind == "heavy"
		var plate := Vector3(0.48, 0.42, 0.32) if not heavy else Vector3(0.56, 0.5, 0.38)
		Geo.part(_torso, plate, Vector3(0, 0.32, 0), vest if not heavy else Mat.painted(Color(0.2, 0.21, 0.22), 0.7), Vector3.ZERO, 0.05)
		if heavy:   # shoulder / collar armour
			for s in [-1, 1]:
				Geo.part(_torso, Vector3(0.16, 0.1, 0.26), Vector3(s * 0.3, 0.5, 0), Mat.painted(Color(0.18, 0.19, 0.2), 0.7), Vector3(0, 0, s * 20), 0.04)
			Geo.part(_torso, Vector3(0.36, 0.1, 0.32), Vector3(0, 0.58, 0), Mat.painted(Color(0.18, 0.19, 0.2), 0.7), Vector3.ZERO, 0.04)
			Geo.part(_torso, Vector3(0.3, 0.2, 0.06), Vector3(0, 0.0, -0.17), Mat.painted(Color(0.2, 0.21, 0.22), 0.7), Vector3.ZERO, 0.03)  # groin plate
		for i in 3:   # magazine pouches across the front
			Geo.part(_torso, Vector3(0.1, 0.13, 0.06), Vector3(-0.13 + i * 0.13, 0.22, -plate.z * 0.5 - 0.03), pouch, Vector3.ZERO, 0.02)
		Geo.part(_torso, Vector3(0.12, 0.08, 0.05), Vector3(0.12, 0.42, -plate.z * 0.5 - 0.025), pouch, Vector3.ZERO, 0.015)  # admin pouch
		Geo.part(_torso, Vector3(0.04, 0.16, 0.04), Vector3(-0.17, 0.46, -plate.z * 0.5 - 0.02), Mat.polymer(), Vector3.ZERO, 0.01)  # radio
		Geo.tube(_torso, 0.006, 0.18, Vector3(-0.17, 0.62, -plate.z * 0.5 - 0.02), Mat.polymer(), Vector3.ZERO, 4)                  # antenna
	# backpack / radio pack
	var pack := Vector3(0.34, 0.4, 0.16) if kind in ["support", "medic", "spotter"] else Vector3(0.3, 0.3, 0.12)
	if kind != "command":
		Geo.part(_torso, pack, Vector3(0, 0.34, 0.2 + pack.z * 0.5 - 0.06), Mat.fabric(vest_c.darkened(0.1)), Vector3.ZERO, 0.05)
		Geo.part(_torso, Vector3(pack.x * 0.8, 0.1, 0.06), Vector3(0, 0.2, 0.2 + pack.z - 0.04), pouch, Vector3.ZERO, 0.02)
		if kind == "support":
			Geo.part(_torso, Vector3(0.3, 0.12, 0.12), Vector3(0, 0.6, 0.24), Mat.painted(Color(0.3, 0.34, 0.24)), Vector3.ZERO, 0.02)  # ammo can
	# insignia
	if dominion:
		_patch(_torso, UiKit.BADGE_DOMINION, Vector3(0, 0.36, -0.2), 0.14, Color(0.85, 0.82, 0.75), 0.0)
	# neck + head
	Geo.part(_torso, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.6, 0), skin, Vector3.ZERO, 0.03)
	_head = Node3D.new(); _head.position.y = 0.66; _torso.add_child(_head)
	Geo.part(_head, Vector3(0.19, 0.23, 0.21), Vector3(0, 0.11, 0), skin, Vector3.ZERO, 0.05)
	Geo.part(_head, Vector3(0.06, 0.05, 0.04), Vector3(0, 0.08, -0.115), skin, Vector3.ZERO, 0.015)          # nose
	_headgear(kind, dominion, vest_c)
	# arms + weapon
	_arms = Node3D.new(); _arms.position = Vector3(0, 0.5, 0); _torso.add_child(_arms)
	_gun = WeaponModel.build(GameData.weapon(weapon_id))
	_gun.position = Vector3(0.1, -0.08, -0.32)
	_arms.add_child(_gun)
	var sleeve: Material = uniform if kind != "command" else Mat.fabric(Color(0.24, 0.25, 0.22))
	var grip: Vector3 = _gun.position + Vector3(0, -0.05, 0.02)
	var lh: Vector3 = _gun.position + (_gun.get_node("LeftHand").position if _gun.has_node("LeftHand") else Vector3(0, 0, -0.3))
	_arm(Vector3(0.24, 0.0, 0.0), grip, sleeve, glove, kind == "heavy")
	_arm(Vector3(-0.24, 0.0, 0.0), lh + Vector3(-0.02, -0.03, 0), sleeve, glove, kind == "heavy")
	if not dominion:
		_patch(_arms, _class_patch(kind), Vector3(-0.29, -0.06, 0.02), 0.08, Color.WHITE, -90.0)
	Geo.no_shadow(_gun)

func _leg(x: float, uniform: Material, boot: Material, kind: String) -> Node3D:
	var thigh := Node3D.new()
	thigh.position = Vector3(x, -0.04, 0)
	_hips.add_child(thigh)
	Geo.part(thigh, Vector3(0.16, 0.44, 0.18), Vector3(0, -0.22, 0), uniform, Vector3.ZERO, 0.05)
	if kind != "command":
		Geo.part(thigh, Vector3(0.06, 0.12, 0.12), Vector3(x * 0.9, -0.22, 0), Mat.fabric(Color(0.2, 0.2, 0.18)), Vector3.ZERO, 0.02)  # cargo pocket
	var shin := Node3D.new()
	shin.position = Vector3(0, -0.44, 0)
	thigh.add_child(shin)
	Geo.part(shin, Vector3(0.14, 0.42, 0.16), Vector3(0, -0.21, 0.01), uniform, Vector3.ZERO, 0.045)
	Geo.part(shin, Vector3(0.13, 0.12, 0.06), Vector3(0, -0.02, -0.08), Mat.polymer(Color(0.12, 0.12, 0.12)), Vector3.ZERO, 0.025)  # knee pad
	Geo.part(shin, Vector3(0.15, 0.12, 0.27), Vector3(0, -0.44, -0.04), boot, Vector3.ZERO, 0.03)          # boot
	return thigh

func _arm(shoulder: Vector3, hand: Vector3, sleeve: Material, glove: Material, bulky: bool) -> void:
	var elbow := (shoulder + hand) * 0.5 + Vector3(0, -0.12, 0.06)
	_seg(shoulder, elbow, 0.065 if not bulky else 0.085, sleeve)
	_seg(elbow, hand, 0.055, sleeve)
	var g := Geo.part(_arms, Vector3(0.07, 0.08, 0.09), hand, glove, Vector3.ZERO, 0.02)
	if bulky:
		Geo.part(_arms, Vector3(0.15, 0.1, 0.16), shoulder + Vector3(0, 0.05, 0), Mat.painted(Color(0.18, 0.19, 0.2), 0.7), Vector3.ZERO, 0.04)

func _seg(a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var n := Node3D.new()
	_arms.add_child(n)
	n.position = (a + b) * 0.5
	if not (b - a).normalized().is_equal_approx(Vector3.UP) and not (b - a).normalized().is_equal_approx(Vector3.DOWN):
		n.basis = Basis.looking_at(b - a, Vector3.UP)
	Geo.part(n, Vector3(r * 2.0, r * 2.0, a.distance_to(b) + r), Vector3.ZERO, m, Vector3.ZERO, r * 0.4)

func _headgear(kind: String, dominion: bool, vest_c: Color) -> void:
	match kind:
		"command":
			Geo.part(_head, Vector3(0.23, 0.06, 0.24), Vector3(0.02, 0.24, 0.0), Mat.fabric(Color(0.5, 0.08, 0.07)), Vector3(0, 0, -10), 0.03)  # beret
			Geo.part(_head, Vector3(0.18, 0.035, 0.02), Vector3(0, 0.13, -0.11), Mat.polymer(Color(0.05, 0.05, 0.05)), Vector3.ZERO, 0.008)    # sunglasses
		"spotter":
			Geo.part(_head, Vector3(0.25, 0.27, 0.25), Vector3(0, 0.13, 0.02), Mat.fabric(Color(0.27, 0.3, 0.2)), Vector3.ZERO, 0.08)         # hood
			Geo.part(_head, Vector3(0.15, 0.12, 0.07), Vector3(0, 0.07, -0.12), Mat.rubber(Color(0.12, 0.12, 0.12)), Vector3.ZERO, 0.03)       # gas mask
			for s in [-1, 1]:
				Geo.tube(_head, 0.03, 0.02, Vector3(s * 0.045, 0.12, -0.15), Mat.glass(Color(0.2, 0.3, 0.3, 0.8)), Vector3(90, 0, 0), 10)
			Geo.tube(_head, 0.035, 0.05, Vector3(0, 0.03, -0.17), Mat.polymer(), Vector3(90, 0, 0), 10)                                       # filter
		"heavy":
			Geo.part(_head, Vector3(0.27, 0.27, 0.28), Vector3(0, 0.13, 0.0), Mat.painted(Color(0.17, 0.18, 0.19), 0.6), Vector3.ZERO, 0.08)
			Geo.part(_head, Vector3(0.22, 0.12, 0.03), Vector3(0, 0.1, -0.14), Mat.glass(Color(0.1, 0.12, 0.12, 0.85)), Vector3.ZERO, 0.02)    # visor
		_:
			var hel := Mat.painted(Color(0.14, 0.14, 0.15) if dominion else vest_c.lightened(0.05), 0.75)
			if dominion:
				Geo.part(_head, Vector3(0.2, 0.2, 0.22), Vector3(0, 0.1, 0.0), Mat.fabric(Color(0.08, 0.08, 0.08)), Vector3.ZERO, 0.05)   # balaclava
			Geo.part(_head, Vector3(0.27, 0.13, 0.28), Vector3(0, 0.25, 0.015), hel, Vector3.ZERO, 0.05)                                    # helmet shell
			Geo.part(_head, Vector3(0.28, 0.05, 0.2), Vector3(0, 0.2, 0.05), hel, Vector3.ZERO, 0.02)
			for s in [-1, 1]:
				Geo.part(_head, Vector3(0.04, 0.08, 0.08), Vector3(s * 0.12, 0.12, 0.0), Mat.polymer(Color(0.15, 0.15, 0.13)), Vector3.ZERO, 0.02)  # ear pro
			if kind == "recon":
				Geo.part(_head, Vector3(0.08, 0.06, 0.06), Vector3(0, 0.31, -0.12), Mat.polymer(), Vector3.ZERO, 0.01)                       # NVG mount
				for s in [-1, 1]:
					Geo.tube(_head, 0.022, 0.07, Vector3(s * 0.03, 0.28, -0.16), Mat.polymer(), Vector3(90, 0, 0), 8)
			elif not dominion:
				Geo.part(_head, Vector3(0.2, 0.05, 0.04), Vector3(0, 0.29, -0.12), Mat.polymer(Color(0.12, 0.12, 0.1)), Vector3.ZERO, 0.015)  # goggles on helmet
				Geo.part(_head, Vector3(0.17, 0.035, 0.03), Vector3(0, 0.29, -0.14), Mat.glass(Color(0.6, 0.45, 0.2, 0.7)), Vector3.ZERO, 0.01)
			else:
				Geo.part(_head, Vector3(0.16, 0.04, 0.02), Vector3(0, 0.13, -0.115), Mat.polymer(Color(0.05, 0.05, 0.05)), Vector3.ZERO, 0.008)

static func _class_patch(kind: String) -> String:
	match kind:
		"medic": return "Icons_Resources/ICON_SM_Chr_Patch_Medic_02_BattleRoyale.png"
		"recon": return "Badges/SPR_MilitaryCombat_Badge_Element_Target_01_Silver.png"
		"support": return "Badges/SPR_MilitaryCombat_Badge_Element_Crate_01_Silver.png"
	return "Badges/SPR_MilitaryCombat_Badge_Element_Rifles_01_Silver.png"

func _patch(parent: Node3D, rel: String, pos: Vector3, size: float, tint: Color, rot_y: float) -> void:
	var s := Sprite3D.new()
	s.texture = UiKit.tex(rel)
	if s.texture == null:
		return
	s.pixel_size = size / float(s.texture.get_width())
	s.modulate = tint
	s.position = pos
	s.rotation_degrees.y = rot_y + 180.0
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	parent.add_child(s)

## Swaps the carried weapon model (remote operators switching primary/secondary).
func set_weapon(weapon_id: String) -> void:
	var def := GameData.weapon(weapon_id)
	if def.is_empty() or _gun == null:
		return
	var pos := _gun.position
	var vis := _gun.visible
	_gun.queue_free()
	_gun = WeaponModel.build(def)
	_gun.position = pos
	_gun.visible = vis
	_arms.add_child(_gun)
	Geo.no_shadow(_gun)

func set_gun_visible(v: bool) -> void:
	_gun.visible = v

func kick() -> void:
	_kick = 1.0

## stance: 0 stand, 1 crouch, 2 prone; state: "alive" | "downed" | "dead"
func pose(dt: float, stance: int, aim_pitch: float, speed: float, state := "alive") -> void:
	_phase += dt * (2.0 + speed * 2.4)
	_kick = maxf(0.0, _kick - dt * 8.0)
	var moving := clampf(speed / 4.0, 0.0, 1.0)
	var swing: float = sin(_phase) * moving * 0.55
	var target_lie := 0.0
	var hip_y := 0.95
	var knee := 0.0
	if state == "dead" or state == "downed" or stance == 2:
		target_lie = 1.0
	elif stance == 1:
		hip_y = 0.62
		knee = 1.0
	_lie = move_toward(_lie, target_lie, dt * 3.0)
	_hips.position.y = lerpf(hip_y, 0.2, _lie) + absf(sin(_phase)) * moving * 0.03 * (1.0 - _lie)
	_hips.rotation.x = lerpf(0.0, -PI / 2.0, _lie)
	_hips.rotation.z = (0.6 * _lie) if state != "alive" else 0.0
	_thigh_l.rotation.x = swing - knee * 0.9
	_thigh_r.rotation.x = -swing - knee * 0.2
	_shin_l.rotation.x = maxf(0.0, -swing) * 0.9 + knee * 1.6
	_shin_r.rotation.x = maxf(0.0, swing) * 0.9 + knee * 0.9
	_torso.rotation.x = -knee * 0.2 - moving * 0.08
	var aim := 0.0 if state != "alive" else aim_pitch
	if _lie > 0.5 and state == "alive":
		aim = clampf(aim_pitch, -0.3, 0.6) + PI / 2.0
	_arms.rotation.x = aim + _kick * 0.12 - (0.0 if state == "alive" else 1.2)
	_head.rotation.x = clampf(aim_pitch, -0.6, 0.6) * (1.0 - _lie)
