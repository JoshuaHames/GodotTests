extends CharacterBody3D

@export_group("Camera Settings")
@export_range(10, 110, 1.0) var base_fov: float = 80
@export_range(1, 20, 1) var sprint_fov_mod_max: float = 5
@export_range(10, 110, 1.0) var zoom_fov: float = 40
@export_group("Head Bob")
@export var head_bob_freq := 2.0
@export var head_bob_amp := 0.08
var head_bob_time = 0.0
var sprint_fov_mod = 0.0
var cam_lerp = 0.0

@export_group("Basic Controls")
@export_range(1, 35, 1) var speed: float = 5
@export_range(1, 2, 0.1) var sprint_speed_mod_max: float = 1.2
@export_range(0.1, 1.0, 0.01) var crouch_speed_mod: float = 0.35
@export_range(0.1, 1.0, 0.01) var crawl_speed_mod: float = 0.2
@export_range(0.1, 3.0, 0.1) var air_control_mod_min: float = 0.16
@export_range(10, 400, 1) var acceleration: float = 50
@export_range(0.1, 3.0, 0.1) var jump_height: float = 1

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var air_control_mod = 1.0

var gravity_mod = 1.0
var sprint_speed_mod = 1.0
var speed_mod = 1.0

var mouse_sensativity = 0.7

#Consider putting movement states into an enum?
var is_sprinting = false
var is_moving = false
var is_jumping = false
var is_pouncing = false
var is_mouse_captured = false

var crouch_lerp = 0.0
var is_crouching = false
var is_crawling = false

var standing_cam_pos = Vector3(0, 0.7, 0)
var crouching_cam_pos = Vector3(0, 0.13, 0)
var is_crawling_cam_pos = Vector3(0, -0.3, 0)

var look_direction: Vector2

var walk_velocity: Vector3
var jump_velocity: Vector3
var gravity_velocity: Vector3

@onready var camera: Camera3D = $"Head/maincam"
@onready var head: Node3D = $"Head"
@onready var standing_hitbox: CollisionShape3D = $"Standing Hitbox"
@onready var crouching_hitbox: CollisionShape3D = $"Crouching Hitbox"
@onready var is_crawling_hitbox: CollisionShape3D = $"Crawling Hitbox"
@onready var crawl_cast_head: ShapeCast3D = $"Crawl Cast Head"
@onready var crawl_cast_feet: ShapeCast3D = $"Crawl Cast Feet"
@onready var stand_room_cast: ShapeCast3D = $"Stand Height Cast"
@onready var crouch_room_cast: ShapeCast3D = $"Crouch Height Cast"

#Pounce Ability
var is_pounce_ready = false
var pounce_timer: float = 0.0
@export var pounce_window: float = 1.0

@export_range(0.05, 0.5, 0.1) var pounce_leniency: float = 0.10
@export_range(0.05, 10, 0.1) var max_horizontal_pounce_power: float = 3
@export_range(0.05, 10, 0.1) var max_vertical_pounce_power: float = 5
@export_range(0.05, 1.0, 0.01) var pounce_charge_rate: float = 0.05
var horizontal_pounce_power = 1.0
var vertical_pounce_power = 1.0
var pounce_leniency_timer: float = 0.0

#Custom Signals
var last_fov = 0.0
signal fov_updated(fov: float)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Input Timer setups
	capture_mouse()
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_direction = event.relative * 0.001;
		if is_mouse_captured: _rotate_camera()
	pass

func _rotate_camera(sensativityMod: float = 1.0) -> void:
	self.rotation.y -= look_direction.x * mouse_sensativity * sensativityMod
	camera.rotation.x = clamp(camera.rotation.x - look_direction.y * mouse_sensativity * sensativityMod , -1.5, 1.5)
	pass

func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_mouse_captured = true
	pass

func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_mouse_captured = false
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 1. Camera Zoom
	var target_fov = zoom_fov if Input.is_action_pressed("cam_zoom") else base_fov
	camera.fov = lerp(camera.fov, target_fov + sprint_fov_mod, 8 * delta)
	
	#Emit the fov updated signal for shaders
	if(camera.fov != last_fov): 
		fov_updated.emit((camera.fov - zoom_fov) / (base_fov - zoom_fov))
	last_fov = camera.fov
	
	var target_lerp = 0.0
	if is_crouching: target_lerp = 0.5
	if is_crawling: target_lerp = 1.0
	
	var cam_move_speed = 6
	if is_crawling: cam_move_speed = 3
	if is_crouching: cam_move_speed = 5
	
	
	crouch_lerp = move_toward(crouch_lerp, target_lerp, cam_move_speed * delta)
	head.position.y = lerp(standing_cam_pos.y, is_crawling_cam_pos.y, crouch_lerp) 
	
func _physics_process(delta: float) -> void:
	if pounce_leniency_timer > 0:
		pounce_leniency_timer -= delta
	if pounce_timer > 0:
		pounce_timer -= delta
	
	if(Input.is_action_just_pressed("crouch") and not is_crawling):
		crouching_hitbox.disabled = false
		standing_hitbox.disabled = true
	
	if(Input.is_action_just_released("crouch") and not is_crawling):
		if(pounce_timer <= 0.0):
			is_pounce_ready = true 
			pounce_timer = pounce_window
		if pounce_leniency_timer > 0:
			is_pouncing = true
	
	if(not crouch_room_cast.is_colliding() and is_crawling):
		start_crouching()
	
	if Input.is_action_pressed("crouch"):
		if not is_crawling and check_can_crawl(): 
			start_is_crawling()
		elif not is_crawling and not is_crouching:
			start_crouching()
			
		if is_crouching:
			is_pounce_ready = false
			pounce_timer = 0
			charge_pounce(1)
	elif not Input.is_action_pressed("crouch"):
		charge_pounce(-1.5)
		if(not stand_room_cast.is_colliding()):
			if(is_crouching):
				start_standing()
			
		if Input.is_action_pressed("sprint") and is_moving and not is_crouching:
			sprint_fov_mod = move_toward(sprint_fov_mod, sprint_fov_mod_max, delta * 100)
			is_sprinting = true
			sprint_speed_mod = sprint_speed_mod_max
		else:
			sprint_fov_mod = move_toward(sprint_fov_mod, 0.0, delta * 100)
			is_sprinting = false
			sprint_speed_mod = 1.0
			
	
	if Input.is_action_just_pressed("jump"):
		if(is_pounce_ready): 
			is_pouncing = true
		else:
			is_jumping = true
			if is_crouching and is_on_floor():
				pounce_leniency_timer = pounce_leniency
	
	velocity = _walk(delta) + _jump(delta) + _gravity(delta)
	
	move_and_slide()
	
	head_bob_time += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = headbob(head_bob_time)
	pass

func start_is_crawling():
	is_crawling = true
	is_crouching = false
	crouching_hitbox.disabled = true
	standing_hitbox.disabled = true
	is_crawling_hitbox.disabled = false

func start_crouching():
	is_crawling = false
	is_crouching = true
	crouching_hitbox.disabled = false
	standing_hitbox.disabled = true
	is_crawling_hitbox.disabled = true
	
func start_standing():
	is_crawling = false
	is_crouching = false
	crouching_hitbox.disabled = true
	standing_hitbox.disabled = false
	is_crawling_hitbox.disabled = true
	
func charge_pounce(direction):
	if(direction > 0):
		if horizontal_pounce_power < max_horizontal_pounce_power: horizontal_pounce_power += pounce_charge_rate * direction
		if vertical_pounce_power < max_vertical_pounce_power: vertical_pounce_power += pounce_charge_rate * direction
	elif (direction < 0):
		if horizontal_pounce_power > 1.0: horizontal_pounce_power += pounce_charge_rate * direction
		else: horizontal_pounce_power = 1.0
		if vertical_pounce_power > 1.0: vertical_pounce_power += pounce_charge_rate * direction
		else:vertical_pounce_power = 1.0

func check_can_crawl():
	return (is_crouching and crawl_cast_head.is_colliding() and not crawl_cast_feet.is_colliding())

func headbob(bob_time):
	var head_bob_pos = Vector3.ZERO
	head_bob_pos.y = sin(bob_time * head_bob_freq) * head_bob_amp
	head_bob_pos.x = sin(bob_time * head_bob_freq / 2) * head_bob_amp
	return head_bob_pos

func _walk(delta: float) -> Vector3:
	var move_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward_vector = camera.global_transform.basis * Vector3(move_direction.x, 0, move_direction.y)
	var walk_direction = Vector3(forward_vector.x, 0, forward_vector.z).normalized()
	if is_crawling: 
		speed_mod = crawl_speed_mod
	elif is_crouching:
		speed_mod = crouch_speed_mod
	else:
		speed_mod = 1.0
		
	if is_on_floor():
		air_control_mod = 1.0
	else:
		air_control_mod = air_control_mod_min
		
	walk_velocity = walk_velocity.move_toward(walk_direction * (speed * speed_mod) * sprint_speed_mod * move_direction.length(), (acceleration * air_control_mod) * delta)
		
	if forward_vector.length() > 0: 
		is_moving = true
	else:
		is_moving = false
	return walk_velocity

func _gravity(delta: float) -> Vector3:
	gravity_velocity = Vector3.ZERO if is_on_floor() else gravity_velocity.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta * gravity_mod)
	return gravity_velocity
	
func _jump(delta: float) -> Vector3:
	if is_jumping:
		if is_on_floor(): 
			jump_velocity = Vector3(0, sqrt(4 * jump_height * gravity), 0)
			is_jumping = false
			return jump_velocity
	if is_pouncing:
		if is_on_floor() or pounce_leniency_timer > 0.0:
			jump_velocity = _pounce()
			gravity_velocity = Vector3.ZERO
			is_pouncing = false
			is_pounce_ready = false
			pounce_leniency_timer = 0.0
			return jump_velocity
			
	jump_velocity = Vector3.ZERO if is_on_floor() or is_on_ceiling_only() else jump_velocity.move_toward(Vector3.ZERO, gravity * delta)
	return jump_velocity

func _pounce() -> Vector3:
	var lookDir = camera.get_global_transform().basis.z.normalized()
	var scaledLookDir = Vector3(lookDir.x * -horizontal_pounce_power, lookDir.y * -vertical_pounce_power, lookDir.z* -horizontal_pounce_power)
	var jumpVector = Vector3(0, sqrt(4 * jump_height * gravity), 0)
	var pounceVector = scaledLookDir + jumpVector
	
	return pounceVector
