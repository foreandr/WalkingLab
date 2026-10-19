extends Label
# Drag an equipped ring outside the inventory panel to drop it in the world.
var owner_fighter: Node
var spell_id: String = ""
var drag_started: bool = false
func _get_drag_data(_at_position: Vector2) -> Variant:
 if owner_fighter == null or not spell_id in owner_fighter.equipped_spells: return null
 var preview := Label.new()
 preview.text = text
 preview.add_theme_font_size_override("font_size",18)
 drag_started = true
 set_drag_preview(preview)
 return {"spell":spell_id}

func _notification(what: int) -> void:
 if what != NOTIFICATION_DRAG_END or not drag_started: return
 drag_started = false
 if owner_fighter == null or gui_is_drag_successful(): return
 var parent_panel: Control = owner_fighter.ring_inventory_panel
 if parent_panel == null or not parent_panel.visible: return
 var mouse: Vector2 = get_viewport().get_mouse_position()
 if Rect2(parent_panel.global_position,parent_panel.size).has_point(mouse): return
 var scene: Node = get_tree().current_scene
 if scene != null and scene.has_method("drop_inventory_ring"):
  scene.drop_inventory_ring(spell_id)
