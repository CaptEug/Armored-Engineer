class_name EditorVisualPolicy
extends RefCounted

enum PlacementState {
	BLOCKED,
	MISSING_MATERIALS,
	READY,
}

const PREVIEW_READY := Color(0.25, 1.0, 0.35, 0.65)
const PREVIEW_MISSING := Color(1.0, 0.72, 0.12, 0.65)
const PREVIEW_BLOCKED := Color(1.0, 0.18, 0.18, 0.65)


class RemovalEffect extends Node2D:
	const STRIPE_ATLAS := preload("res://assets/icons/icons_small.png")
	const STRIPE_REGION := Rect2(240, 80, 16, 16)

	var _tiles: Array[Sprite2D] = []
	var _centers: Array[Vector2] = []
	var _stripe_texture: AtlasTexture

	func _init() -> void:
		z_index = 1000
		_stripe_texture = AtlasTexture.new()
		_stripe_texture.atlas = STRIPE_ATLAS
		_stripe_texture.region = STRIPE_REGION
		hide()

	func attach_to(host: Node2D, relative_z_index: int = 1000) -> void:
		z_index = relative_z_index
		if not is_instance_valid(host) or get_parent() == host:
			return
		if get_parent() != null:
			get_parent().remove_child(self)
		host.add_child(self)
		position = Vector2.ZERO
		rotation = 0.0
		scale = Vector2.ONE

	func show_centers(centers: Array[Vector2]) -> void:
		if centers.is_empty():
			clear()
			return
		if centers == _centers:
			show()
			return
		_centers = centers.duplicate()
		while _tiles.size() < centers.size():
			var tile := Sprite2D.new()
			tile.texture = _stripe_texture
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(tile)
			_tiles.append(tile)
		for index in range(_tiles.size()):
			var tile := _tiles[index]
			tile.visible = index < centers.size()
			if tile.visible:
				tile.position = centers[index]
		show()

	func clear() -> void:
		_centers.clear()
		hide()


static func apply_preview_color(item: CanvasItem, state: int) -> void:
	if not is_instance_valid(item):
		return
	match state:
		PlacementState.READY:
			item.modulate = PREVIEW_READY
		PlacementState.MISSING_MATERIALS:
			item.modulate = PREVIEW_MISSING
		_:
			item.modulate = PREVIEW_BLOCKED


static func apply_alpha(
	item: CanvasItem,
	alpha: float,
	entries: Array[Dictionary]
) -> void:
	if not is_instance_valid(item):
		return
	for entry: Dictionary in entries:
		if entry.get("item") == item:
			return
	entries.append({"item": item, "modulate": item.modulate})
	var transparent := item.modulate
	transparent.a = clampf(alpha, 0.0, 1.0)
	item.modulate = transparent


static func restore_alpha(entries: Array[Dictionary]) -> void:
	for entry: Dictionary in entries:
		var item: Variant = entry.get("item")
		if is_instance_valid(item) and item is CanvasItem:
			(item as CanvasItem).modulate = entry.get("modulate", Color.WHITE)
	entries.clear()
