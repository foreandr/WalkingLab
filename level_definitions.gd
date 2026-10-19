extends RefCounted
# Level data is authoritative; arena presentation and fighter loadouts consume it.
# Add biomes and encounter generators here, rather than embedding new levels in duo.gd.
static func get_level(number: int) -> Dictionary:
	var index: int = maxi(1, number)
	if index == 1:
		return {
			"number": 1,
			"name": "Grassland + Dirtland",
			"biome": "flat_dirt",
			"seed": 1001,
			"arena_half_extent": 250.0,
			"enemy_count": 11,
			"enemy_distance": 9.0,
			"battle_royale_drop": true,
			"drop_height": 52.0,
			"player_spells": ["flight"],
			"enemy_spells": [],
			"enemy_ai": true,
			"buildings": []
		}
	# Placeholder deterministic generator contract for later level designs.
	# Future level progression can supply biome, enemy count, seed and rules.
	return {
		"number": index,
		"name": "Grassland + Dirtland %d" % index,
		"biome": "flat_dirt",
		"seed": 1000 + index,
		"arena_half_extent": 250.0,
		"enemy_count": 0,
		"enemy_distance": 9.0,
		"player_spells": [],
		"enemy_spells": [],
		"enemy_ai": true
	}
