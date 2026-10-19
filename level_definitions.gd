extends RefCounted
# Level data is authoritative; arena presentation and fighter loadouts consume it.
# Add biomes and encounter generators here, rather than embedding new levels in duo.gd.
static func get_level(number: int) -> Dictionary:
	var index: int = maxi(1, number)
	if index == 1:
		return {
			"number": 1,
			"name": "Grassland",
			"biome": "grassland",
			"seed": 1001,
			"arena_half_extent": 50.0,
			"enemy_count": 1,
			"enemy_distance": 9.0,
			"player_spells": [] as Array[String],
			"enemy_spells": [] as Array[String],
			"enemy_ai": true
		}
	# Placeholder deterministic generator contract for later level designs.
	# Future level progression can supply biome, enemy count, seed and rules.
	return {
		"number": index,
		"name": "Grassland %d" % index,
		"biome": "grassland",
		"seed": 1000 + index,
		"arena_half_extent": 50.0,
		"enemy_count": 1,
		"enemy_distance": 9.0,
		"player_spells": [] as Array[String],
		"enemy_spells": [] as Array[String],
		"enemy_ai": true
	}
