class_name AIRoutePoint
extends Marker2D


func get_route_links() -> Array[Node]:
	var links: Array[Node] = []
	for child in get_children():
		if child.get_script() == preload("res://scripts/gameplay/ai_route_link.gd"):
			links.append(child)
	return links

func get_link_to(target_point: Node2D):
	for link in get_route_links():
		if link.get_target_point() == target_point:
			return link
	return null
