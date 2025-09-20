# res://scripts/GameManager.gd
extends Node

@export var required_parts: Dictionary = {
	"Battery": 4,
	"Electronic_Component": 2,
	"Satelite": 1
}

var collected_parts: Dictionary = {}

signal parts_updated(part_name: String, collected: int, required: int)
signal overall_updated(total_collected: int, total_required: int)
signal all_parts_collected()

func _ready() -> void:
	# init zeros
	collected_parts.clear()
	for key in required_parts.keys():
		collected_parts[key] = 0
	# emit initial overall so HUD can read it immediately
	_emit_overall()

func collect_part(part_name: String) -> void:
	if not required_parts.has(part_name):
		print("GameManager: collected non-required part: ", part_name)
		return
	collected_parts[part_name] = min(int(collected_parts.get(part_name, 0)) + 1, int(required_parts[part_name]))
	emit_signal("parts_updated", part_name, collected_parts[part_name], required_parts[part_name])
	_emit_overall()
	_check_victory()

func _emit_overall() -> void:
	var total_collected := 0
	var total_required := 0
	for k in required_parts.keys():
		total_collected += int(collected_parts.get(k, 0))
		total_required += int(required_parts[k])
	emit_signal("overall_updated", total_collected, total_required)

func _check_victory() -> void:
	for k in required_parts.keys():
		if int(collected_parts.get(k, 0)) < int(required_parts[k]):
			return
	emit_signal("all_parts_collected")
