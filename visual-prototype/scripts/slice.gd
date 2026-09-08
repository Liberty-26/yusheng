extends "res://scripts/district.gd"

var player: CharacterBody3D
var hud: Label
var prompt: Label
var bag = {"水": 0, "食物": 0, "药品": 0}
var containers: Array = []
var doors: Array = []
var elapsed := 0.0
var stamina := 100.0
var thirst := 100.0
var finished := false
var notice := "离开便利店，到诊所找到药品，然后带回收银台。"
var route_move := Vector3.ZERO
var search_time := 0.0
var search_target = null
var home = Vector3(-28,1,-19.5)

func _ready():
	super._ready()
	set_process(false)
	set_process_unhandled_input(false)
	# Selection volumes stay on a separate layer; visible walls own walking collision.
	for id in ['ConvenienceStore','Clinic','TwoStoreyHouse','AbandonedHouse','Warehouse']:
		get_node(id+'/SelectionVolume').collision_layer = 2
	make_collision(self)
	for id in ['ConvenienceStore','Clinic']:
		var mesh = get_node(id+'/Floor1/NearWalls/Door')
		doors.append({"mesh":mesh,"open":false,"label":"便利店前门" if id=='ConvenienceStore' else "诊所前门"})
	var back = store.get_node('Floor1/Rooms/Storage/BackDoorMarker')
	add_solid(back)
	doors.append({"mesh":back,"open":false,"label":"便利店后门"})
	player = CharacterBody3D.new()
	player.name = 'Survivor'
	player.collision_layer = 4
	player.collision_mask = 1
	add_child(player)
	player.position = Vector3(-39,1,-21)
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	player.add_child(shape)
	var body = MeshInstance3D.new()
	var visual = CapsuleMesh.new()
	visual.radius = 0.48
	visual.height = 1.8
	body.mesh = visual
	body.material_override = palette['warm']
	body.position.y = 0.9
	player.add_child(body)
	add_container("便利店水箱",Vector3(-27,1,-38),"水",2)
	add_container("便利店食品箱",Vector3(-46,1,-38),"食物",2)
	add_container("诊所药柜",Vector3(-78,1,32),"药品",1)
	var ui = CanvasLayer.new()
	add_child(ui)
	var panel = ColorRect.new()
	panel.color = Color(0.07,0.10,0.12,0.91)
	panel.position = Vector2(20,20)
	panel.size = Vector2(770,180)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	hud = Label.new()
	hud.position = Vector2(36,28)
	hud.add_theme_font_size_override('font_size',20)
	ui.add_child(hud)
	prompt = Label.new()
	prompt.position = Vector2(36,214)
	prompt.add_theme_font_size_override('font_size',22)
	ui.add_child(prompt)
	camera.size = 43
	set_store(1)
	set_physics_process(true)
	if '--route-test' in OS.get_cmdline_user_args():
		call_deferred('verify_route')
	if '--slice-capture' in OS.get_cmdline_user_args():
		call_deferred('capture_slice')
	if '--slice-test' in OS.get_cmdline_user_args():
		call_deferred('verify_slice')

func add_solid(mesh: MeshInstance3D):
	if mesh.has_node('WalkBody'): return
	var solid = StaticBody3D.new()
	solid.name = 'WalkBody'
	mesh.add_child(solid)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = mesh.mesh.size
	collision.shape = shape
	solid.add_child(collision)

func make_collision(node: Node):
	for child in node.get_children():
		make_collision(child)
	if node is MeshInstance3D and node.mesh is BoxMesh:
		var n = str(node.name)
		# Flat first-floor movement: roofs, floor slabs and tiny decorative pieces do not block.
		var structural = n.begins_with('Wall') or n.begins_with('FrontLeft') or n.begins_with('FrontRight') or n.begins_with('BackWall') or n=='Door' or n=='Partition' or n=='Checkout' or n.begins_with('ShelfBase') or n=='Body' or n.begins_with('RoadBarrier') or n.begins_with('BrokenBoundary')
		if structural and not 'Floor2' in str(node.get_path()): add_solid(node)

func add_container(title: String, pos: Vector3, item: String, amount: int):
	var mesh = box(self,'SearchContainer',pos+Vector3(0,0.65,0),Vector3(1.6,1.3,1.3),'blue' if item=='水' else ('red' if item=='药品' else 'wood'))
	add_solid(mesh)
	containers.append({"label":title,"mesh":mesh,"item":item,"amount":amount})

func reachable(pos: Vector3, reach := 3.2) -> bool:
	if player.position.distance_to(Vector3(pos.x,1,pos.z)) > reach: return false
	var start = player.position+Vector3(0,1.5,0)
	var end = Vector3(pos.x,2.5,pos.z)
	var ray = PhysicsRayQueryParameters3D.create(start,end,1)
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.position.distance_to(end)<1.1

func nearest():
	for d in doors:
		if reachable(d.mesh.global_position): return d
	for c in containers:
		if c.amount>0 and reachable(c.mesh.global_position): return c
	return null

func toggle_door(d):
	d.open = not d.open
	d.mesh.visible = not d.open
	d.mesh.get_node('WalkBody').collision_layer = 0 if d.open else 1
	notice = d.label + ('已打开' if d.open else '已关闭')

func take(c):
	if c.amount<=0 or not reachable(c.mesh.global_position): return
	var total = bag['水']+bag['食物']+bag['药品']
	if total>=6:
		notice = '背包已满（6 格）。先喝水或吃东西腾出空间。'
		return
	bag[c.item] += 1
	c.amount -= 1
	notice = '获得 '+c.item+' ×1'
	if c.amount==0: c.mesh.material_override = palette['dark']

func _physics_process(delta):
	if player==null: return
	if not finished:
		elapsed += delta
		thirst = maxf(0,thirst-delta*0.08)
	var direction = Vector3.ZERO
	if not finished:
		if Input.is_physical_key_pressed(KEY_W): direction+=Vector3(-1,0,-1)
		if Input.is_physical_key_pressed(KEY_S): direction+=Vector3(1,0,1)
		if Input.is_physical_key_pressed(KEY_A): direction+=Vector3(-1,0,1)
		if Input.is_physical_key_pressed(KEY_D): direction+=Vector3(1,0,-1)
	if route_move!=Vector3.ZERO: direction=route_move
	var sprint = Input.is_physical_key_pressed(KEY_SHIFT) and stamina>1 and direction.length()>0 and thirst>0
	stamina = clampf(stamina+delta*(-15 if sprint else 9),0,100)
	player.velocity = direction.normalized()*(8 if sprint else (2.5 if thirst==0 else 4.5))
	player.move_and_slide()
	player.position.y=1
	player.position.x=clampf(player.position.x,-88,88)
	player.position.z=clampf(player.position.z,-88,88)
	focus=player.position+Vector3(0,1,0)
	update_camera()
	var p=player.position
	set_store(1 if absf(p.x+39)<21 and absf(p.z+29)<17 else 0)
	var inside_clinic = absf(p.x+72)<15 and absf(p.z-38)<16
	get_node('Clinic/Roof').visible=not inside_clinic
	get_node('Clinic/Floor1/NearWalls').visible=not inside_clinic
	var target = nearest()
	if not finished and Input.is_physical_key_pressed(KEY_E) and target!=null and target.has('item') and direction==Vector3.ZERO:
		if search_target!=target: search_time=0; search_target=target
		search_time += delta
		if search_time>=2:
			take(target)
			search_time=0
	else:
		search_time=0
		search_target=null
	var task = '去诊所搜药 → 返回便利店收银台'
	if bag['药品']>0: task='已找到药品 → 返回便利店收银台，按 E 交付'
	var destination = home if bag['药品']>0 else Vector3(-72,1,53)
	var screen_direction = camera.unproject_position(destination)-get_viewport().get_visible_rect().size/2
	var bearing = ('右' if screen_direction.x>0 else '左')+('下' if screen_direction.y>0 else '上')
	if not finished: task += '  |  目标：'+bearing+'方 %dm'%int(player.position.distance_to(destination))
	if finished: task='完成：药品已带回安全点。按 R 重新试玩。'
	hud.text='灰烬街区 / 首个搜刮循环\n'+task+'\n背包 %d/6  水 %d瓶 · 食物 %d份 · 药品 %d盒  |  用时 %02d:%02d\n体力 %d  水分 %d  |  WASD 移动 · Shift 跑 · E 交互/按住搜刮\nQ 喝水 · F 吃东西 · 滚轮缩放 · R 重开' % [bag['水']+bag['食物']+bag['药品'],bag['水'],bag['食物'],bag['药品'],int(elapsed)/60,int(elapsed)%60,int(stamina),int(thirst)]
	prompt.text=notice
	if not finished and target!=null:
		prompt.text=('E '+('关门：' if target.open else '开门：')+target.label) if target.has('open') else ('按住 E 搜索 '+target.label+'  %.1f / 2 秒'%search_time)
	if not finished and reachable(home,4.5): prompt.text='E 在收银台交付药品' if bag['药品']>0 else '安全点：先去诊所找到药品'

func _input(event):
	if player==null: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.size=clampf(camera.size*0.9,25,80)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.size=clampf(camera.size/0.9,25,80)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_R: get_tree().reload_current_scene()
		if finished: return
		if event.keycode==KEY_Q and bag['水']>0:
			bag['水']-=1; thirst=minf(100,thirst+45); notice='喝了一瓶水。'
		if event.keycode==KEY_F and bag['食物']>0:
			bag['食物']-=1; stamina=100; notice='吃了一份食物，恢复体力。'
		if event.keycode==KEY_E:
			if bag['药品']>0 and reachable(home,4.5):
				bag['药品']-=1; finished=true; notice='药品已经存入安全点。基础循环完成。'; return
			var target=nearest()
			if target!=null and target.has('open'): toggle_door(target)

func verify_slice():
	await get_tree().physics_frame
	assert(player!=null and containers.size()==3 and doors.size()==3)
	var origin=player.position
	player.position=Vector3(-39,1,-18)
	player.velocity=Vector3(0,0,4.5)
	for i in range(30):
		player.velocity=Vector3(0,0,4.5); player.move_and_slide()
		await get_tree().physics_frame
	assert(player.position.z < -17.2, 'Closed door must block movement')
	toggle_door(doors[0])
	for i in range(60):
		player.velocity=Vector3(0,0,4.5); player.move_and_slide()
		await get_tree().physics_frame
	assert(player.position.z > -16.5, 'Open doorway must permit passage')
	player.position=Vector3(-72,1,49)
	assert(not reachable(Vector3(-78,1,32)), 'Cannot loot remotely')
	player.position=Vector3(-78,1,34)
	assert(reachable(containers[2].mesh.global_position))
	take(containers[2])
	assert(bag['药品']==1 and containers[2].amount==0)
	player.position=home+Vector3(0,0,1)
	await get_tree().physics_frame
	assert(reachable(home,4.5), 'Delivery point is reachable')
	var key=InputEventKey.new()
	key.keycode=KEY_E; key.physical_keycode=KEY_E; key.pressed=true
	_input(key)
	assert(finished and bag['药品']==0, 'Delivery consumes medicine and finishes run')
	finished=false
	player.position=origin
	bag['药品']=0; containers[2].amount=1; containers[2].mesh.material_override=palette['red']
	toggle_door(doors[0])
	elapsed=0
	print('SLICE_VERIFIED: closed door blocks, open door permits, remote loot rejected, medicine transfer conserved, E delivery completes run')
	if '--test-quit' in OS.get_cmdline_user_args(): get_tree().quit()

func capture_slice():
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png('res://screenshots/07-playable-start.png')
	print('SLICE_CAPTURED')

func walk_to(destination: Vector3):
	var frames=0
	while player.position.distance_to(destination)>0.3 and frames<3000:
		route_move=(destination-player.position).normalized()
		await get_tree().physics_frame
		frames+=1
	route_move=Vector3.ZERO
	assert(frames<3000, 'Route blocked at '+str(player.position)+' toward '+str(destination))

func press_interact(held_frames := 1):
	var e=InputEventKey.new()
	e.keycode=KEY_E; e.physical_keycode=KEY_E; e.pressed=true
	Input.parse_input_event(e)
	for i in range(held_frames): await get_tree().physics_frame
	e=InputEventKey.new()
	e.keycode=KEY_E; e.physical_keycode=KEY_E; e.pressed=false
	Input.parse_input_event(e)
	await get_tree().physics_frame

func verify_route():
	await get_tree().physics_frame
	await walk_to(Vector3(-39,1,-19))
	await press_interact()
	assert(doors[0].open)
	for point in [Vector3(-39,1,21),Vector3(-56,1,21),Vector3(-56,1,55),Vector3(-72,1,55),Vector3(-72,1,53)]:
		await walk_to(point)
	await press_interact()
	assert(doors[1].open)
	await walk_to(Vector3(-72,1,45))
	await walk_to(Vector3(-78,1,34))
	await press_interact(125)
	assert(bag['药品']==1, 'Hold E must actually transfer medicine')
	for point in [Vector3(-72,1,45),Vector3(-72,1,55),Vector3(-56,1,55),Vector3(-56,1,21),Vector3(-39,1,21),Vector3(-39,1,-20),Vector3(-28,1,-19.5)]:
		await walk_to(point)
	await press_interact()
	assert(finished and bag['药品']==0, 'Whole walking route must end in delivery')
	print('ROUTE_VERIFIED: walked from store through both doors to clinic, held E to search, walked home, E delivered. Simulated seconds: ',elapsed)
	get_tree().quit()
