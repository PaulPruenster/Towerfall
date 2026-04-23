class_name AIRouteLink
extends Node


enum TraversalType {
	WALK,
	JUMP,
	DROP,
	WALL_JUMP,
	PAD,
	GATE,
}

const JUMP_PENALTY: float = 40.0
const DROP_PENALTY: float = 28.0
const WALL_JUMP_PENALTY: float = 70.0
const PAD_PENALTY: float = 54.0
const GATE_PENALTY: float = 24.0

@export_node_path("Marker2D") var target_point_path: NodePath
@export_enum("Walk:0", "Jump:1", "Drop:2", "Wall Jump:3", "Pad:4", "Gate:5") var traversal_type: int = TraversalType.WALK
@export_range(8.0, 96.0, 1.0) var activation_distance: float = 28.0
@export_range(0.0, 400.0, 1.0) var extra_cost: float = 0.0
@export_enum("Auto:0", "Left:-1", "Right:1") var wall_contact_direction: int = 0
@export_node_path("Node2D") var helper_node_path: NodePath

func get_target_point() -> Node2D:
	return get_node_or_null(target_point_path) as Node2D

func get_helper_node() -> Node2D:
	return get_node_or_null(helper_node_path) as Node2D

func is_available() -> bool:
	var target_point: Node2D = get_target_point()
	if target_point == null:
		return false

	if traversal_type == TraversalType.GATE:
		var helper_node := get_helper_node()
		if helper_node != null and helper_node.has_method("is_gate_enabled"):
			return bool(helper_node.call("is_gate_enabled"))

	return true

func get_link_cost(origin_position: Vector2) -> float:
	var target_point: Node2D = get_target_point()
	if target_point == null:
		return INF

	var target_position: Vector2 = target_point.global_position
	var distance: float = origin_position.distance_to(target_position)
	distance += extra_cost

	match traversal_type:
		TraversalType.JUMP:
			distance += JUMP_PENALTY
		TraversalType.DROP:
			distance += DROP_PENALTY
		TraversalType.WALL_JUMP:
			distance += WALL_JUMP_PENALTY
		TraversalType.PAD:
			distance += PAD_PENALTY
		TraversalType.GATE:
			distance += GATE_PENALTY

	return distance
