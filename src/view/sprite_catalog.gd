extends RefCounted
## 素材表（数据驱动）：用途键 → 贴图。缺素材返回 null，表现层回退色块。
## 来源：Kenney Tower Defense (top-down) Pack，CC0（见 LICENSE-kenney.txt）。

const MAP := {
						"mon:goblin": "res://assets/sprites/mon_goblin.png",
	"mon:wolf": "res://assets/sprites/mon_wolf.png",
	"mon:orc": "res://assets/sprites/mon_orc.png",
	"mon:shaman": "res://assets/sprites/mon_shaman.png",
	"mon:golem": "res://assets/sprites/mon_golem.png",
	"mon:ogre_lord": "res://assets/sprites/mon_ogre_lord.png",
	"hero": "res://assets/sprites/turret.png",
	"path": "res://assets/sprites/path.png",
	"fx:spark": "res://assets/sprites/fx_spark.png",
}

static var _cache := {}

static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if MAP.has(key):
		var img := Image.load_from_file(MAP[key].replace("res://", "res://"))
		if img == null:
			img = Image.load_from_file(MAP[key])
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
