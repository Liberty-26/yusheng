extends Node
## Orthographic orbit; input and walking share the rendered yaw, not the target yaw.
const DEFAULT_YAW := PI/4.0
const PITCH := deg_to_rad(43.0)
const MIN_PITCH := deg_to_rad(25.0)
const MAX_PITCH := deg_to_rad(75.0)
var pitch := PITCH
var target_pitch := PITCH
const DEFAULT_ZOOM := 43.0
const MIN_ZOOM := 18.0
const MAX_ZOOM := 200.0
const DRAG_SENSITIVITY := 0.006
var view: Camera3D
var yaw := DEFAULT_YAW
var target_yaw := DEFAULT_YAW
var zoom := DEFAULT_ZOOM
var target_zoom := DEFAULT_ZOOM
var orbiting := false

func setup(camera: Camera3D):
	view=camera
	view.size=zoom

func handle_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			orbiting=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:
			target_zoom=clampf(target_zoom*0.86,MIN_ZOOM,MAX_ZOOM)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom=clampf(target_zoom/0.86,MIN_ZOOM,MAX_ZOOM)
	if event is InputEventMouseMotion and orbiting:
		target_yaw-=event.relative.x*DRAG_SENSITIVITY
		target_pitch=clampf(target_pitch+event.relative.y*0.004,MIN_PITCH,MAX_PITCH)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_HOME:
		# Restore using the shortest arc even after several full rotations.
		target_yaw=yaw+wrapf(DEFAULT_YAW-yaw,-PI,PI)
		target_zoom=DEFAULT_ZOOM
		target_pitch=PITCH

func tick(delta: float, focus: Vector3):
	var weight=1.0-exp(-12.0*delta)
	yaw=lerpf(yaw,target_yaw,weight)
	pitch=lerpf(pitch,target_pitch,weight)
	# Low pitch cannot zoom so far out that the ground footprint becomes unbounded.
	zoom=lerpf(zoom,minf(target_zoom,260.0*sin(pitch)),weight)
	apply(focus)

func apply(focus: Vector3):
	if view==null: return
	view.size=zoom
	view.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*320.0
	view.look_at(focus)

func ground_direction() -> Vector3:
	var input=Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y+=1
	if Input.is_physical_key_pressed(KEY_S): input.y-=1
	if Input.is_physical_key_pressed(KEY_D): input.x+=1
	if Input.is_physical_key_pressed(KEY_A): input.x-=1
	return Vector3(cos(yaw),0,-sin(yaw))*input.x+Vector3(-sin(yaw),0,-cos(yaw))*input.y

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		orbiting=false
