class_name Mat
## Procedural PBR material library (client only). No surface textures were supplied, so albedo variation,
## normal and roughness detail are generated once at startup from noise and cached; every material is
## triplanar so code-built geometry needs no UV unwrapping. Palette follows the supplied Synty sample art
## (warm tan/khaki desert-industrial, olive drab, worn painted steel).

static var _tex := {}
static var _cache := {}

# ------------------------------------------------------------------ texture generation
static func _noise(seed: int, freq: float, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH, octaves := 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	return n

static func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Grayscale detail map remapped into [lo, 1] (multiplied with the material tint).
static func _detail(key: String, seed: int, freq: float, lo: float, grime := 0.0) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var size := 128
	freq *= 2.0   # same feature size at half resolution
	var a := _noise(seed, freq).get_seamless_image(size, size)
	var g := _noise(seed + 7, freq * 0.18, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3).get_seamless_image(size, size) if grime > 0.0 else null
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := a.get_pixel(x, y).r
			if g:
				v = v * (1.0 - grime) + (1.0 - grime * clampf((g.get_pixel(x, y).r - 0.45) * 2.5, 0.0, 1.0)) * grime
			var c := lerpf(lo, 1.0, v)
			img.set_pixel(x, y, Color(c, c, c))
	_tex[key] = _finish(img)
	return _tex[key]

static func _normal(key: String, seed: int, freq: float, strength: float) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var img := _noise(seed, freq * 2.0, FastNoiseLite.TYPE_PERLIN, 5).get_seamless_image(128, 128)
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(strength)
	_tex[key] = _finish(img)
	return _tex[key]

## Vertical ribs for corrugated sheet metal (normal map).
static func _corrugation() -> Texture2D:
	if _tex.has("corr"):
		return _tex["corr"]
	var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
	for x in 64:
		var d := cos(float(x) / 64.0 * TAU * 4.0)
		var n := Vector3(d * 0.75, 0, 1).normalized()
		for y in 8:
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, 0.5, n.z * 0.5 + 0.5))
	_tex["corr"] = _finish(img)
	return _tex["corr"]

## Wood planks: streaked grain with plank seams.
static func _wood() -> Texture2D:
	if _tex.has("wood"):
		return _tex["wood"]
	var n := _noise(31, 0.05)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var grain := 0.5 + 0.5 * sin(float(y) * 0.9 + n.get_noise_2d(x * 0.15, y * 2.0) * 6.0)
			var seam := 0.55 if y % 32 < 2 else 1.0
			var v := lerpf(0.7, 1.0, grain) * seam
			img.set_pixel(x, y, Color(v, v, v))
	_tex["wood"] = _finish(img)
	return _tex["wood"]

## Camouflage pattern (4 colours from a palette) for uniforms.
static func _camo(key: String, palette: Array, seed: int) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var n1 := _noise(seed, 0.035, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var n2 := _noise(seed + 3, 0.06, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var a := n1.get_noise_2d(x, y)
			var b := n2.get_noise_2d(x, y)
			var idx := 0
			if a > 0.18: idx = 1
			if b > 0.25: idx = 2
			if a < -0.3 and b < 0.0: idx = 3
			img.set_pixel(x, y, palette[idx])
	_tex[key] = _finish(img)
	return _tex[key]

## Generates every procedural texture up front (during the deployment loading screen) so nothing is
## created on first use mid-mission (e.g. when a weapon or character model appears).
static func prewarm() -> void:
	concrete(); ground(); asphalt(); painted(Color.WHITE); metal(); rust(); corrugated(Color.WHITE); wood()
	fabric(Color.WHITE); polymer(); gunmetal(); rubber(); skin()
	for k in ["tf", "dominion", "recon"]:
		camo(k)

# ------------------------------------------------------------------ material builders
static func _base(key: String, tint: Color, rough: float, metal: float, detail: Texture2D, normal: Texture2D, scale: float, normal_scale := 1.0) -> StandardMaterial3D:
	var k := "%s|%s|%.2f|%.2f|%.2f" % [key, tint.to_html(), rough, metal, scale]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.4
	if detail:
		m.albedo_texture = detail
	if normal:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = normal_scale
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[k] = m
	return m

static func concrete(tint := Color(0.66, 0.63, 0.58)) -> StandardMaterial3D:
	return _base("concrete", tint, 0.93, 0.0, _detail("d_concrete", 11, 0.06, 0.84, 0.25), _normal("n_concrete", 12, 0.09, 2.0), 0.35)

static func ground(tint := Color(0.56, 0.48, 0.38)) -> StandardMaterial3D:
	return _base("ground", tint, 0.97, 0.0, _detail("d_ground", 21, 0.035, 0.6, 0.55), _normal("n_ground", 22, 0.05, 5.0), 0.12)

static func asphalt(tint := Color(0.25, 0.25, 0.26)) -> StandardMaterial3D:
	return _base("asphalt", tint, 0.95, 0.0, _detail("d_asphalt", 41, 0.25, 0.65, 0.4), _normal("n_asphalt", 42, 0.3, 2.0), 0.25)

static func painted(tint: Color, rough := 0.62) -> StandardMaterial3D:
	return _base("painted", tint, rough, 0.15, _detail("d_paint", 51, 0.03, 0.78, 0.45), _normal("n_paint", 52, 0.12, 1.0), 0.3, 0.5)

static func metal(tint := Color(0.5, 0.52, 0.54), rough := 0.42) -> StandardMaterial3D:
	return _base("metal", tint, rough, 0.75, _detail("d_metal", 61, 0.12, 0.82, 0.25), _normal("n_metal", 62, 0.4, 0.6), 0.6, 0.4)

static func rust(tint := Color(0.48, 0.3, 0.2)) -> StandardMaterial3D:
	return _base("rust", tint, 0.88, 0.3, _detail("d_rust", 71, 0.05, 0.55, 0.6), _normal("n_rust", 72, 0.08, 3.0), 0.4)

static func corrugated(tint: Color) -> StandardMaterial3D:
	var k := "corr|" + tint.to_html()
	if _cache.has(k):
		return _cache[k]
	var m := painted(tint, 0.6).duplicate()
	m.normal_texture = _corrugation()
	m.normal_scale = 1.4
	m.uv1_scale = Vector3(0.8, 0.8, 0.8)
	m.albedo_texture = _detail("d_corr", 81, 0.025, 0.7, 0.6)
	_cache[k] = m
	return m

static func wood(tint := Color(0.62, 0.47, 0.3)) -> StandardMaterial3D:
	return _base("wood", tint, 0.85, 0.0, _wood(), _normal("n_wood", 91, 0.2, 1.5), 1.2, 0.6)

static func fabric(tint: Color) -> StandardMaterial3D:
	return _base("fabric", tint, 0.95, 0.0, _detail("d_fabric", 101, 0.5, 0.78, 0.3), _normal("n_fabric", 102, 0.8, 1.0), 2.0, 0.5)

static func polymer(tint := Color(0.13, 0.13, 0.13)) -> StandardMaterial3D:
	return _base("polymer", tint, 0.68, 0.0, _detail("d_poly", 111, 0.4, 0.88, 0.0), _normal("n_poly", 112, 0.6, 0.5), 3.0, 0.3)

static func gunmetal(tint := Color(0.2, 0.21, 0.22)) -> StandardMaterial3D:
	return _base("gunmetal", tint, 0.38, 0.8, _detail("d_metal", 61, 0.12, 0.82, 0.25), _normal("n_metal", 62, 0.4, 0.6), 3.0, 0.3)

static func rubber(tint := Color(0.08, 0.08, 0.08)) -> StandardMaterial3D:
	return _base("rubber", tint, 0.95, 0.0, null, _normal("n_fabric", 102, 0.8, 1.0), 2.0, 0.4)

static func skin(tint := Color(0.74, 0.57, 0.45)) -> StandardMaterial3D:
	return _base("skin", tint, 0.75, 0.0, null, null, 1.0)

static func camo(kind: String) -> StandardMaterial3D:
	var palettes := {
		"tf": [Color(0.58, 0.52, 0.4), Color(0.45, 0.42, 0.3), Color(0.38, 0.3, 0.22), Color(0.66, 0.6, 0.47)],      # Task Force: arid multi-tone
		"dominion": [Color(0.2, 0.21, 0.22), Color(0.28, 0.29, 0.3), Color(0.13, 0.13, 0.14), Color(0.36, 0.36, 0.36)],  # Dominion: urban grey/black
		"recon": [Color(0.32, 0.35, 0.22), Color(0.24, 0.27, 0.16), Color(0.4, 0.38, 0.26), Color(0.18, 0.2, 0.12)],
	}
	var k := "camo|" + kind
	if _cache.has(k):
		return _cache[k]
	var m := _base("camo_" + kind, Color.WHITE, 0.95, 0.0, _camo("t_camo_" + kind, palettes.get(kind, palettes["tf"]), hash(kind) % 1000),
		_normal("n_fabric", 102, 0.8, 1.0), 2.2, 0.5).duplicate()
	_cache[k] = m
	return m

## Tiled material from a supplied Synty texture (Warehouse pack corrugated iron / brick / dirt, Military road),
## triplanar so code-built surfaces need no UVs. `scale` = texture repeats per metre.
static func tiled(albedo_rel: String, normal_rel: String, scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var k := "tiled|%s|%s|%.3f|%s" % [albedo_rel, normal_rel, scale, tint.to_html()]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	var at := Poly.ROOT + albedo_rel
	m.albedo_texture = load(at) if ResourceLoader.exists(at) else null
	m.albedo_color = tint
	if normal_rel != "" and ResourceLoader.exists(Poly.ROOT + normal_rel):
		m.normal_enabled = true
		m.normal_texture = load(Poly.ROOT + normal_rel)
	m.roughness = 0.88
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 6.0
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[k] = m
	return m

static func glass(tint := Color(0.35, 0.5, 0.55, 0.35)) -> StandardMaterial3D:
	var k := "glass|" + tint.to_html()
	if not _cache.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.3
		_cache[k] = m
	return _cache[k]

static func emissive(color: Color, energy := 2.5) -> StandardMaterial3D:
	var k := "emi|%s|%.1f" % [color.to_html(), energy]
	if not _cache.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		_cache[k] = m
	return _cache[k]

## Material that shows a supplied Synty sprite (signage, screens, insignia), alpha-blended, unshaded optional.
static func sprite(rel: String, tint := Color.WHITE, unshaded := false) -> StandardMaterial3D:
	var k := "spr|%s|%s|%s" % [rel, tint.to_html(), unshaded]
	if not _cache.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = UiKit.tex(rel)
		m.albedo_color = tint
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if not unshaded else BaseMaterial3D.TRANSPARENCY_ALPHA
		m.alpha_scissor_threshold = 0.3
		m.roughness = 0.8
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cache[k] = m
	return _cache[k]
