extends RefCounted
var g
var records: Array = []

func frames(count: int):
	for i in range(count): await g.get_tree().process_frame

func wait_seconds(seconds: float):
	await g.get_tree().create_timer(seconds).timeout

func key(code: int, pressed: bool):
	var event=InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event)

func mouse(button: int, pressed: bool):
	var event=InputEventMouseButton.new()
	event.button_index=button; event.pressed=pressed
	Input.parse_input_event(event)

func drag(degrees: float):
	var event=InputEventMouseMotion.new()
	event.relative=Vector2(-deg_to_rad(degrees)/0.006,0)
	Input.parse_input_event(event)

func wheel(button: int, count: int):
	for i in range(count):
		mouse(button,true)
		mouse(button,false)

func actual_yaw() -> float:
	var offset=g.camera.position-(g.player.position+Vector3.UP)
	return atan2(offset.x,offset.z)

func assert_pitch():
	var offset=g.camera.position-(g.player.position+Vector3.UP)
	var pitch=atan2(offset.y,Vector2(offset.x,offset.z).length())
	assert(absf(rad_to_deg(pitch)-43.0)<0.05,'Rendered pitch remains 43 degrees')
	assert(g.camera.position.y>g.player.position.y)

func capture(title: String):
	await RenderingServer.frame_post_draw
	var file='res://screenshots/camera/'+title+'.png'
	assert(g.get_viewport().get_texture().get_image().save_png(file)==OK)
	records.append({'image':title+'.png','rendered_yaw_degrees':rad_to_deg(actual_yaw()),'orthographic_size':g.camera.size,'faded_surfaces':faded_count()})

func faded_count() -> int:
	var count=0
	for surface in g.occlusion.surfaces:
		if surface.mesh.is_visible_in_tree() and surface.mesh.material_override!=surface.original and surface.mesh.material_override.albedo_color.a<0.5: count+=1
	return count

func run(game):
	g=game
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path('res://screenshots/camera'))
	await wait_seconds(0.5)
	var collision_state={}
	for node in g.find_children('WalkBody','StaticBody3D',true,false):
		collision_state[node.get_path()]={'layer':node.collision_layer,'mask':node.collision_mask,'transform':node.global_transform}
	# Two full revolutions from actual mouse motion events, with rendered poses recorded.
	mouse(MOUSE_BUTTON_RIGHT,true)
	var previous=actual_yaw()
	var accumulated=0.0
	for i in range(16):
		drag(45.0)
		await wait_seconds(0.25)
		var angle=actual_yaw()
		accumulated+=wrapf(angle-previous,-PI,PI)
		previous=angle
		assert_pitch()
		await capture('orbit-%02d'%i)
	mouse(MOUSE_BUTTON_RIGHT,false)
	await wait_seconds(0.7)
	accumulated+=wrapf(actual_yaw()-previous,-PI,PI)
	assert(rad_to_deg(accumulated)>719.0 and rad_to_deg(accumulated)<721.0)
	print('CAMERA_ROTATION_VERIFIED actual revolutions degrees=',rad_to_deg(accumulated))
	# Zoom via real wheel events; compare rendered projection, not only target size.
	wheel(MOUSE_BUTTON_WHEEL_UP,30)
	await wait_seconds(0.8)
	assert(g.camera.size<18.1)
	var near_span=g.camera.unproject_position(g.player.position+Vector3(5,0,0)).distance_to(g.camera.unproject_position(g.player.position))
	await capture('zoom-near')
	wheel(MOUSE_BUTTON_WHEEL_DOWN,50)
	await wait_seconds(0.9)
	assert(g.camera.size>199.9)
	var far_span=g.camera.unproject_position(g.player.position+Vector3(5,0,0)).distance_to(g.camera.unproject_position(g.player.position))
	assert(near_span/far_span>10.9)
	await capture('zoom-district')
	key(KEY_HOME,true); key(KEY_HOME,false)
	await wait_seconds(0.9)
	assert(absf(g.camera.size-43.0)<0.1)
	assert(absf(wrapf(actual_yaw()-PI/4,-PI,PI))<0.002)
	assert_pitch()
	print('CAMERA_ZOOM_HOME_VERIFIED projected scale ratio=',near_span/far_span)
	# W must travel up-screen at eight different camera headings. No route override.
	g.player.position=Vector3(0,1,5)
	for i in range(8):
		mouse(MOUSE_BUTTON_RIGHT,true); drag(45); mouse(MOUSE_BUTTON_RIGHT,false)
		await wait_seconds(0.5)
		var right=g.camera.global_basis.x
		var up=g.camera.global_basis.y
		var origin=g.player.position
		key(KEY_W,true)
		await g.get_tree().create_timer(0.25).timeout
		key(KEY_W,false)
		await frames(2)
		var movement=g.player.position-origin
		assert(movement.length()>0.8 and movement.dot(up)>0.6 and absf(movement.dot(right))<0.07,'W travels screen-up at heading '+str(i))
		print('CAMERA_MOVEMENT_VERIFIED heading=',rad_to_deg(actual_yaw()),' displacement=',movement)
	# Stationary arbitrary angle stays put after releasing drag; vertical motion ignored.
	mouse(MOUSE_BUTTON_RIGHT,true); drag(17.3); mouse(MOUSE_BUTTON_RIGHT,false)
	await wait_seconds(0.7)
	var fixed=actual_yaw()
	await wait_seconds(0.3)
	assert(absf(wrapf(actual_yaw()-fixed,-PI,PI))<0.001)
	assert_pitch()
	# All eight WASD combinations also move correctly at a non-cardinal heading.
	for sample in [[[KEY_W],Vector2(0,1)],[[KEY_W,KEY_D],Vector2(1,1)],[[KEY_D],Vector2(1,0)],[[KEY_S,KEY_D],Vector2(1,-1)],[[KEY_S],Vector2(0,-1)],[[KEY_S,KEY_A],Vector2(-1,-1)],[[KEY_A],Vector2(-1,0)],[[KEY_W,KEY_A],Vector2(-1,1)]]:
		var origin=g.player.position
		var right=g.camera.global_basis.x
		var up=g.camera.global_basis.y
		for code in sample[0]: key(code,true)
		await wait_seconds(0.2)
		for code in sample[0]: key(code,false)
		await frames(2)
		var displacement=g.player.position-origin
		var projected=Vector2(displacement.dot(right),displacement.dot(up)/sin(deg_to_rad(43.0)))
		assert(projected.length()>0.7 and projected.normalized().dot(sample[1].normalized())>0.99)
	print('CAMERA_EIGHT_WASD_COMBINATIONS_VERIFIED at arbitrary angle')
	# Actual building occlusion at both sides of the store and behind the clinic wall.
	for test in [
		['store-exterior',Vector3(-39,1,-46.5),0.0],
		['store-interior',Vector3(-53,1,-38),225.0],
		['clinic-wall',Vector3(-80,1,28),225.0]]:
		g.player.position=test[1]
		mouse(MOUSE_BUTTON_RIGHT,true)
		drag(rad_to_deg(wrapf(deg_to_rad(test[2])-actual_yaw(),-PI,PI)))
		mouse(MOUSE_BUTTON_RIGHT,false)
		wheel(MOUSE_BUTTON_WHEEL_UP,30)
		wheel(MOUSE_BUTTON_WHEEL_DOWN,6)
		await wait_seconds(0.9)
		assert(faded_count()>0,'Must actually fade intervening geometry: '+test[0])
		var architecture_faded=false
		for surface in g.occlusion.surfaces:
			if surface.mesh.is_visible_in_tree() and surface.mesh.material_override!=surface.original:
				var mesh_path=str(surface.mesh.get_path())
				if '/Roof/' in mesh_path or '/FarWalls/' in mesh_path: architecture_faded=true
		assert(architecture_faded,'Building surface must fade, not just a prop')
		for door in g.doors:
			assert(door.leaf.is_visible_in_tree() and door.leaf.material_override.albedo_color.a==1)
		await capture(test[0])
		var faded=[]
		for entry in g.occlusion.surfaces:
			if entry.mesh.material_override!=entry.original: faded.append(entry)
		# Move into open ground so all previous occluders leave the camera-to-player rays.
		g.player.position=Vector3(0,1,5)
		await wait_seconds(0.8)
		for entry in faded:
			assert(entry.mesh.material_override==entry.original,'Exact material restoration: '+str(entry.mesh.get_path()))
		print('OCCLUSION_RESTORE_VERIFIED ',test[0],' count=',faded.size())
	# No camera operation may change any walking collider.
	for path in collision_state:
		var node=g.get_node(path)
		assert(node.collision_layer==collision_state[path].layer and node.collision_mask==collision_state[path].mask and node.global_transform==collision_state[path].transform)
	for entry in g.occlusion.surfaces:
		assert(entry.mesh.material_override==entry.original,'No permanently transparent surfaces')
	var file=FileAccess.open('res://screenshots/camera/sequence.json',FileAccess.WRITE)
	file.store_string(JSON.stringify(records,'  ')); file.close()
	print('CAMERA_COLLISION_AND_MATERIALS_VERIFIED count=',collision_state.size())
	key(KEY_HOME,true); key(KEY_HOME,false)
	g.player.position=Vector3(-39,1,-21)
	await wait_seconds(0.8)
	# Reuse physical door and complete walking-route regression after camera tests.
	await g.verify_polish()
