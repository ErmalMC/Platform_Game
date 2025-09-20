extends Node3D

@export var part_name: String = ""        # leave blank to auto-detect from node name
@export var collect_distance: float = 3
@export var pickup_tween_time: float = 0.18
@export var pickup_sound: AudioStream = null

var player: Node = null
var audio_player: AudioStreamPlayer3D = null
var collected: bool = false

func _ready() -> void:
	player = _find_player()
	if has_node("AudioStreamPlayer3D"):
		audio_player = $AudioStreamPlayer3D

	# auto-detect part_name from node name if not set
	if part_name == "" or part_name.strip_edges() == "":
		part_name = _guess_part_name_from_node_name(name)

func _process(_delta: float) -> void:
	if collected or not player:
		return
	var dist = global_transform.origin.distance_to(player.global_transform.origin)
	if dist <= collect_distance:
		collected = true
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.collect_part(part_name)

		# optional sound
		if audio_player and pickup_sound:
			audio_player.stream = pickup_sound
			audio_player.play()

		# animate and free
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector3.ZERO, pickup_tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.play()
		await tw.finished
		queue_free()

func _guess_part_name_from_node_name(n: String) -> String:
	var lower = n.to_lower()
	if lower.find("battery") != -1:
		return "Battery"
	if lower.find("electronic") != -1 or lower.find("chip") != -1:
		return "Electronic_Component"
	if lower.find("satelit") != -1 or lower.find("satellite") != -1:
		return "Satelite"
	# fallback: remove trailing digits (Battery2 -> Battery)
	var cleaned := n.strip_edges()
	while cleaned.length() > 0:
		var last = cleaned.substr(cleaned.length() - 1, 1)
		if "0123456789".find(last) != -1:
			cleaned = cleaned.substr(0, cleaned.length() - 1)
		else:
			break
	cleaned = cleaned.strip_edges()
	return cleaned if cleaned != "" else "UnknownPart"

func _find_player() -> Node:
	var root = get_tree().get_root()
	var node = root.get_node_or_null("Main/Player")
	if node:
		return node
	node = root.get_node_or_null("Player")
	if node:
		return node
	for n in root.get_children():
		if n is CharacterBody3D:
			return n
	return null
