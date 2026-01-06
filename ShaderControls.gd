extends MeshInstance3D

var shader_material: ShaderMaterial

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	shader_material = self.get_active_material(0)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	pass


func _on_player_fov_updated(fov: float) -> void:
	var adjustedFOV = 1.0 * (1.6 + fov)
	shader_material.set_shader_parameter("vinMod", adjustedFOV)
	pass # Replace with function body.
