extends CharacterBody3D

@export_group("Camera Settings")
@export_range(10, 110, 1.0) var baseFOV: float = 80
@export_range(1, 20, 1) var sprintFOVModMax: float = 5
@export_range(10, 110, 1.0) var zoomFOV: float = 40
@export_group("Head Bob")
@export var headbobFreq := 2.0
@export var headbobAmp := 0.08
var headbobTime = 0.0
var sprintFOVMod = 0.0
var camLerp = 0.0

@export_group("Basic Controls")
@export_range(1, 35, 1) var speed: float = 5
@export_range(1, 2, 0.1) var sprintSpeedModMax: float = 1.2
@export_range(0.1, 1.0, 0.01) var crouchSpeedModMin: float = 0.35
@export_range(0.1, 3.0, 0.1) var airControlModMin: float = 0.16
@export_range(10, 400, 1) var acceleration: float = 50
@export_range(0.1, 3.0, 0.1) var jumpHeight: float = 1

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var airControlMod = 1.0

var gravityMod = 1.0
var sprintSpeedMod = 1.0
var speedMod = 1.0

var mouseSensativity = 0.7

var sprinting = false
var walking = false
var jumping = false
var pouncing = false
var mouseCaptured = false

var crouchLerp = 0.0
var crouched = false

var standingCamPos = Vector3(0, 0.7, 0)
var crouchingCamPos = Vector3(0, 0.13, 0)

var lookDirection: Vector2

var walkVelocity: Vector3
var jumpVelocity: Vector3
var gravityVelocity: Vector3

@onready var camera: Camera3D = $Head/maincam
@onready var head: Node3D = $Head
@onready var standingHitbox: CollisionShape3D = $"Standing Hitbox"
@onready var crouchingHitbox: CollisionShape3D = $"Crouching Hitbox"
@onready var headRay: RayCast3D = $HeadRay

#Pounce Ability
var pounceReady = false
var pounceTimer: float = 0.0
@export var pounceWindow: float = 1.0

@export_range(0.05, 0.5, 0.1) var pounceLeniency: float = 0.10
@export_range(0.05, 10, 0.1) var maxHorizontalPouncePower: float = 3
@export_range(0.05, 10, 0.1) var maxVerticalPouncePower: float = 5
@export_range(0.05, 1.0, 0.01) var pounceChargerate: float = 0.05
var horizontalPouncePower = 1.0
var verticalPouncePower = 1.0
var pounceLeniencyTimer: float = 0.0

#Custom Signals
var lastFOV = 0.0
signal fov_updated(fov: float)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Input Timer setups
	CaptureMouse()
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		lookDirection = event.relative * 0.001;
		if mouseCaptured: _rotate_camera()
	pass

func _rotate_camera(sensativityMod: float = 1.0) -> void:
	self.rotation.y -= lookDirection.x * mouseSensativity * sensativityMod
	camera.rotation.x = clamp(camera.rotation.x - lookDirection.y * mouseSensativity * sensativityMod , -1.5, 1.5)
	pass

func CaptureMouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouseCaptured = true
	pass

func ReleaseMouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouseCaptured = false
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 1. Camera Zoom
	var target_fov = zoomFOV if Input.is_action_pressed("cam_zoom") else baseFOV
	camera.fov = lerp(camera.fov, target_fov + sprintFOVMod, 8 * delta)
	
	#Emit the fov updated signal for shaders
	if(camera.fov != lastFOV): 
		fov_updated.emit((camera.fov - zoomFOV) / (baseFOV - zoomFOV))
	lastFOV = camera.fov
	
	var target_lerp = 1.0 if crouched else 0.0
	crouchLerp = move_toward(crouchLerp, target_lerp, 10 * delta)
	head.position.y = lerp(standingCamPos.y, crouchingCamPos.y, crouchLerp)
	
func _physics_process(delta: float) -> void:
	if pounceLeniencyTimer > 0:
		pounceLeniencyTimer -= delta
	if pounceTimer > 0:
		pounceTimer -= delta
	
	if(Input.is_action_just_pressed("crouch")):
		crouchingHitbox.disabled = false
		standingHitbox.disabled = true
	
	if(Input.is_action_just_released("crouch")):
		if(pounceTimer <= 0.0):
			pounceReady = true 
			pounceTimer = pounceWindow
		if pounceLeniencyTimer > 0:
			pouncing = true
	
	if Input.is_action_pressed("crouch"):
		crouched = true
		pounceReady = false
		pounceTimer = 0
		
		if(horizontalPouncePower < maxHorizontalPouncePower): horizontalPouncePower += pounceChargerate
		if(verticalPouncePower < maxVerticalPouncePower): verticalPouncePower += pounceChargerate
	else:
		if(not headRay.is_colliding()):
			if(horizontalPouncePower > 1.0): horizontalPouncePower -= pounceChargerate
			if(verticalPouncePower > 1.0): verticalPouncePower -= pounceChargerate
			crouched = false
			if(standingHitbox.disabled):
				crouchingHitbox.disabled = true
				standingHitbox.disabled = false
			
		if Input.is_action_pressed("sprint") and walking and not crouched:
			sprintFOVMod = move_toward(sprintFOVMod, sprintFOVModMax, delta * 100)
			sprinting = true
			sprintSpeedMod = sprintSpeedModMax
		else:
			sprintFOVMod = move_toward(sprintFOVMod, 0.0, delta * 100)
			sprinting = false
			sprintSpeedMod = 1.0
	
	if Input.is_action_just_pressed("jump"):
		if(pounceReady): 
			pouncing = true
		else:
			jumping = true
			if crouched and is_on_floor():
				pounceLeniencyTimer = pounceLeniency
	
	velocity = _walk(delta) + _jump(delta) + _gravity(delta)
	move_and_slide()
	
	headbobTime += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = headbob(headbobTime)
	pass

func headbob(bobTime):
	var headbobPos = Vector3.ZERO
	headbobPos.y = sin(bobTime * headbobFreq) * headbobAmp
	headbobPos.x = sin(bobTime * headbobFreq / 2) * headbobAmp
	return headbobPos

func _walk(delta: float) -> Vector3:
	var moveDirection = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forwardVector = camera.global_transform.basis * Vector3(moveDirection.x, 0, moveDirection.y)
	var walkDirection = Vector3(forwardVector.x, 0, forwardVector.z).normalized()
	
	if crouched:
		speedMod = crouchSpeedModMin
	else:
		speedMod = 1.0
		
	if is_on_floor():
		airControlMod = 1.0
	else:
		airControlMod = airControlModMin
		
	walkVelocity = walkVelocity.move_toward(walkDirection * (speed * speedMod) * sprintSpeedMod * moveDirection.length(), (acceleration * airControlMod) * delta)
		
	if forwardVector.length() > 0: 
		walking = true
	else:
		walking = false
	return walkVelocity

func _gravity(delta: float) -> Vector3:
	gravityVelocity = Vector3.ZERO if is_on_floor() else gravityVelocity.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta * gravityMod)
	return gravityVelocity
	
func _jump(delta: float) -> Vector3:
	if jumping:
		if is_on_floor(): 
			jumpVelocity = Vector3(0, sqrt(4 * jumpHeight * gravity), 0)
			jumping = false
			return jumpVelocity
	if pouncing:
		if is_on_floor() or pounceLeniencyTimer > 0.0:
			jumpVelocity = _pounce()
			gravityVelocity = Vector3.ZERO
			pouncing = false
			pounceReady = false
			pounceLeniencyTimer = 0.0
			return jumpVelocity
			
	jumpVelocity = Vector3.ZERO if is_on_floor() or is_on_ceiling_only() else jumpVelocity.move_toward(Vector3.ZERO, gravity * delta)
	return jumpVelocity

func _pounce() -> Vector3:
	var lookDir = camera.get_global_transform().basis.z.normalized()
	var scaledLookDir = Vector3(lookDir.x * -horizontalPouncePower, lookDir.y * -verticalPouncePower, lookDir.z* -horizontalPouncePower)
	var jumpVector = Vector3(0, sqrt(4 * jumpHeight * gravity), 0)
	var pounceVector = scaledLookDir + jumpVector
	
	return pounceVector
