extends Node3D

var palette = {}
var camera: Camera3D
var focus = Vector3.ZERO
var store: Node3D
var house: Node3D
var store_mode = 0
var house_mode = 0
var dragging = false
var rng = RandomNumberGenerator.new()

func mat(key: String, color: String) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.94
	palette[key] = m
	return m

func group(parent: Node3D, title: String, pos = Vector3.ZERO) -> Node3D:
	var n = Node3D.new()
	n.name = title
	parent.add_child(n)
	n.position = pos
	return n

func box(parent: Node3D, title: String, pos: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = title
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = palette[material]
	parent.add_child(n)
	n.position = pos
	return n

func rod(parent: Node3D, pos: Vector3, radius: float, height: float, material: String) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	n.mesh = mesh
	n.material_override = palette[material]
	parent.add_child(n)
	n.position = pos
	return n

func label(parent: Node3D, words: String, pos: Vector3, size: int = 70):
	var n = Label3D.new()
	n.text = words
	n.font_size = size
	n.pixel_size = 0.018
	n.modulate = Color('#ddd7bd')
	n.outline_size = 0
	parent.add_child(n)
	n.position = pos

func _ready():
	rng.seed = 82026
	mat('base','#414d51'); mat('road','#424a4c'); mat('walk','#92958b')
	mat('dirt','#55584f'); mat('grass','#555f48'); mat('leaf','#465849')
	mat('cream','#b3ae94'); mat('blue','#647e87'); mat('green','#748476')
	mat('red','#995f50'); mat('rust','#916849'); mat('dark','#303d40')
	mat('roof','#566365'); mat('white','#d3cfb7'); mat('wood','#927c58')
	mat('glass','#405c63'); mat('warm','#d4a15c'); mat('line','#afa88a')
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color('#28353d')
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color('#9db5c7')
	env.environment.ambient_light_energy = 0.38
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-28,0)
	sun.light_color = Color('#eee2c7')
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 350
	add_child(sun)
	build_map()
	weathering()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 224
	camera.far = 650
	add_child(camera)
	update_camera()
	if '--capture' in OS.get_cmdline_user_args():
		capture_suite()

func update_camera():
	camera.position = focus + Vector3(130,170,130)
	camera.look_at(focus)

func build_map():
	var ground = group(self,'Terrain')
	box(ground,'CutEarth',Vector3(0,-2.3,0),Vector3(180,4,180),'base')
	box(ground,'Soil',Vector3(0,-0.2,0),Vector3(180,0.6,180),'dirt')
	box(ground,'MainStreet',Vector3(0,0.15,5),Vector3(180,0.25,21),'road')
	for z in [-8,18]:
		box(ground,'Sidewalk',Vector3(0,0.4,z),Vector3(180,0.7,5),'walk')
	for x in [-12,52]:
		box(ground,'Alley',Vector3(x,0.1,0),Vector3(9,0.3,180),'road')
	for x in range(-84,90,12):
		box(ground,'FadedRoadMark',Vector3(x,0.3,5),Vector3(5,0.04,0.28),'line')
	for i in range(40):
		var crack = box(ground,'AsphaltFracture',Vector3(rng.randf_range(-86,86),0.31,rng.randf_range(-3,13)),Vector3(rng.randf_range(0.8,3),0.025,0.09),'dark')
		crack.rotation.y = rng.randf_range(-2,2)
	store = building('ConvenienceStore',Vector3(-39,0,-29),Vector2(34,24),1,'green','FIELD / SUPPLY')
	furnish_store(store)
	var clinic = building('Clinic',Vector3(-72,0,38),Vector2(24,25),1,'cream','CLINIC')
	box(clinic,'MedicalCrossH',Vector3(0,7,12.85),Vector3(4,0.8,0.2),'red')
	box(clinic,'MedicalCrossV',Vector3(0,7,12.9),Vector3(0.8,4,0.2),'red')
	house = building('TwoStoreyHouse',Vector3(15,0,39),Vector2(28,25),2,'blue','')
	furnish_house(house)
	building('AbandonedHouse',Vector3(72,0,42),Vector2(24,23),1,'cream','')
	building('Warehouse',Vector3(14,0,-56),Vector2(36,30),1,'red','DEPOT 04')
	gas_station()
	parking()
	camp()
	for x in [-80,-53,-23,22,63,84]:
		for z in [-9,19]:
			rod(self,Vector3(x,4.7,z),0.16,9,'dark')
			box(self,'StreetLightArm',Vector3(x+1.3,9,z),Vector3(2.8,0.2,0.2),'dark')
			box(self,'StreetLight',Vector3(x+2.4,8.9,z),Vector3(1.2,0.3,0.7),'cream')
	for i in range(95):
		var x = rng.randf_range(-86,86)
		var z = rng.randf_range(-86,86)
		if abs(z-5)<16 or abs(x+12)<7 or abs(x-52)<7: continue
		if z < -13 and z > -74 and x < 36: continue
		if z>23 and z<56: continue
		var shrub = group(self,'SparseVegetation',Vector3(x,0.5,z))
		for j in range(3):
			var tuft=box(shrub,'Grass',Vector3(j*0.35,0.35,0),Vector3(0.14,rng.randf_range(0.4,1.1),0.5),'grass')
			tuft.rotation.z = rng.randf_range(-0.3,0.3)
	for p in [Vector3(-82,0,-65),Vector3(38,0,67),Vector3(82,0,69),Vector3(-45,0,65)]:
		tree(p)
	for p in [Vector3(-63,0,4),Vector3(37,0,8),Vector3(-8,0,57)]:
		car(self,p,'rust')
	for i in range(7):
		box(self,'BrokenBoundary',Vector3(-83+i*4,1.1,70),Vector3(3.6,2.2 if i%3 else 0.8,0.6),'walk')
	for x in [62,68,74,80]:
		box(self,'RoadBarrier',Vector3(x,0.95,-2),Vector3(3.4,1.8,0.8),'cream')
		box(self,'BarrierRustStripe',Vector3(x,1.1,-1.55),Vector3(1.1,0.65,0.05),'red')

func building(id: String, pos: Vector3, footprint: Vector2, floors: int, color: String, sign_text: String) -> Node3D:
	var b = group(self,id,pos)
	b.set_meta('building_id',id)
	b.set_meta('asset_pipeline','Replace modules with GLB; preserve floor and cutaway groups')
	var w = footprint.x
	var d = footprint.y
	for f in range(floors):
		var level = group(b,'Floor'+str(f+1),Vector3(0,f*7.2,0))
		level.set_meta('floor_id',str(f+1))
		if id=='TwoStoreyHouse' and f==1:
			box(level,'FloorSlabMain',Vector3(-3,0.65,0),Vector3(w-6,0.6,d),'cream')
			box(level,'StairLandingBack',Vector3(11,0.65,-10),Vector3(6,0.6,5),'cream')
			box(level,'StairLandingFront',Vector3(11,0.65,10),Vector3(6,0.6,5),'cream')
		else:
			box(level,'FloorSlab',Vector3(0,0.65,0),Vector3(w,0.6,d),'cream')
		var far = group(level,'FarWalls')
		if id=='ConvenienceStore':
			box(far,'BackWallLeft',Vector3(-3.25,3.9,-d/2),Vector3(27.5,6.4,0.45),color)
			box(far,'BackWallRight',Vector3(15.25,3.9,-d/2),Vector3(3.5,6.4,0.45),color)
			box(far,'BackDoorLintel',Vector3(12,6.1,-d/2),Vector3(3,2,0.45),color)
		else:
			box(far,'WallBack',Vector3(0,3.9,-d/2),Vector3(w,6.4,0.45),color)
		box(far,'WallLeft',Vector3(-w/2,3.9,0),Vector3(0.45,6.4,d),color)
		var near = group(level,'NearWalls')
		# Actual front entrance gap; lintel maintains facade silhouette.
		box(near,'FrontLeft',Vector3(-w/4-1,3.9,d/2),Vector3(w/2-2,6.4,0.45),color)
		box(near,'FrontRight',Vector3(w/4+1,3.9,d/2),Vector3(w/2-2,6.4,0.45),color)
		box(near,'DoorLintel',Vector3(0,6.4,d/2),Vector3(4,1.3,0.45),color)
		box(near,'WallRight',Vector3(w/2,3.9,0),Vector3(0.45,6.4,d),color)
		for x in [-w*0.32,w*0.32]:
			box(near,'WindowFrame',Vector3(x,4.3,d/2+0.3),Vector3(w*0.23,2.9,0.25),'white')
			box(near,'WindowGlass',Vector3(x,4.3,d/2+0.46),Vector3(w*0.23-0.3,2.55,0.1),'glass')
			box(near,'WindowMullion',Vector3(x,4.3,d/2+0.55),Vector3(0.16,2.7,0.1),'dark')
		box(near,'Door' if f==0 else 'UpperWindow',Vector3(0,2.5,d/2+0.1),Vector3(3.7,3.8,0.2),'dark' if f==0 else 'glass')
		var room = group(level,'Rooms')
		room.set_meta('room_id','main')
		var points=group(level,'InteractionPoints')
		group(points,'FrontDoor',Vector3(0,1,d/2+1)).set_meta('interaction_point','front_door')
		group(points,'BackDoor',Vector3(12 if id=='ConvenienceStore' else 0,1,-d/2-1)).set_meta('interaction_point','back_door')
	var roof=group(b,'Roof')
	box(roof,'RoofSlab',Vector3(0,floors*7.2+0.5,0),Vector3(w+1,0.7,d+1),'roof')
	for x in [-w/2,w/2]:
		box(roof,'Parapet',Vector3(x,floors*7.2+1.1,0),Vector3(0.5,1.2,d),'walk')
	for z in [-d/2,d/2]:
		box(roof,'Parapet',Vector3(0,floors*7.2+1.1,z),Vector3(w,1.2,0.5),'walk')
	box(roof,'VentilationUnit',Vector3(-w*0.23,floors*7.2+1.5,-3),Vector3(4,2.2,3),'cream')
	for i in range(5):
		box(roof,'VentSlat',Vector3(-w*0.23-1.5+i*0.7,floors*7.2+2.62,-3),Vector3(0.18,0.05,2.6),'dark')
	if sign_text!='':
		box(b.get_node('Floor1/NearWalls'),'Fascia',Vector3(0,6.3,d/2+0.7),Vector3(w+0.3,1.6,0.5),'green' if id=='ConvenienceStore' else 'dark')
		label(b.get_node('Floor1/NearWalls'),sign_text,Vector3(0,6.25,d/2+1.0),65)
	var hit=StaticBody3D.new()
	hit.name='SelectionVolume'
	b.add_child(hit)
	var col=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=Vector3(w,floors*7.2,d)
	col.shape=shape
	hit.add_child(col)
	col.position.y=floors*3.6
	return b

func furnish_store(b):
	var r=b.get_node('Floor1/Rooms')
	var sales=group(r,'SalesArea'); sales.set_meta('room_id','sales')
	for x in [-10,-3,4]:
		for z in [-3,3]:
			box(sales,'ShelfBase',Vector3(x,1.1,z),Vector3(2,0.3,5),'dark')
			for y in [1.4,2.4,3.4]:
				box(sales,'Shelf',Vector3(x,y,z),Vector3(2,0.15,5),'wood')
				for k in range(3):
					box(sales,'StockBlock',Vector3(x,y+0.3,z-1.5+k*1.5),Vector3(1.3,0.5,0.8),'cream' if k%2 else 'green')
	box(sales,'Checkout',Vector3(11,1.7,7),Vector3(7,1.8,2.3),'green')
	box(sales,'Register',Vector3(11,2.9,7),Vector3(1,0.7,0.8),'dark')
	var storage=group(r,'Storage'); storage.set_meta('room_id','storage')
	box(storage,'Partition',Vector3(-3,2.4,-7),Vector3(25,3,0.25),'cream')
	for x in [-12,-7,1]:
		box(storage,'Crate',Vector3(x,1.6,-9.5),Vector3(2.4,1.5,2),'wood')
	box(storage,'BackDoorMarker',Vector3(12,2.5,-11.7),Vector3(3,3.5,0.1),'blue')
	warm_light(b,Vector3(8,5,5))

func furnish_house(b):
	for f in [1,2]:
		var r=b.get_node('Floor'+str(f)+'/Rooms')
		var a=group(r,'LivingRoom' if f==1 else 'Bedroom'); a.set_meta('room_id',a.name)
		box(a,'Rug',Vector3(-5,0.99,3),Vector3(9,0.05,7),'red')
		if f==1:
			box(a,'SofaSeat',Vector3(-8,1.5,2),Vector3(3,1.1,7),'green')
			box(a,'SofaBack',Vector3(-9.3,2.3,2),Vector3(0.7,1.8,7),'green')
			box(a,'Table',Vector3(-3.5,1.6,2),Vector3(3,1.3,4),'wood')
		else:
			box(a,'BedBase',Vector3(-7,1.4,2),Vector3(5,1,7),'wood')
			box(a,'Mattress',Vector3(-7,2,2),Vector3(4.8,0.6,6.7),'cream')
			box(a,'Blanket',Vector3(-7,2.35,3),Vector3(4.85,0.1,4.5),'blue')
			box(a,'Pillow',Vector3(-7,2.5,-0.5),Vector3(3,0.3,1.3),'white')
		var k=group(r,'Kitchen' if f==1 else 'Corridor'); k.set_meta('room_id',k.name)
		box(k,'Partition',Vector3(1,2.4,-3),Vector3(0.25,3,16),'cream')
		if f==1:
			box(k,'KitchenCounter',Vector3(6,1.6,-10),Vector3(9,1.6,3),'white')
			box(k,'Sink',Vector3(5,2.44,-10),Vector3(2,0.1,1.6),'glass')
		if f==1:
			for i in range(12):
				box(k,'Stair',Vector3(9,1+(i+1)*0.3,-6+i*1.15),Vector3(3.5,(i+1)*0.6,1.15),'wood')
		else:
			for z in [-7,0,7]:
				box(k,'StairwellRailingPost',Vector3(7,1.7,z),Vector3(0.13,1.5,0.13),'dark')
			box(k,'StairwellHandrail',Vector3(7,2.45,0),Vector3(0.15,0.15,14),'wood')
	warm_light(b,Vector3(-3,5,0))

func warm_light(parent,pos):
	var light=OmniLight3D.new()
	parent.add_child(light)
	light.position=pos
	light.light_color=Color('#ffbe79')
	light.light_energy=1.5
	light.omni_range=15

func car(parent,pos,color):
	var c=group(parent,'AbandonedVehicle',pos)
	box(c,'Body',Vector3(0,1.1,0),Vector3(3.2,1.2,6.5),color)
	box(c,'Cabin',Vector3(0,2,0),Vector3(2.8,1.2,3.3),'glass')
	box(c,'Roof',Vector3(0,2.65,0),Vector3(2.9,0.15,3.4),color)
	for x in [-1.6,1.6]:
		for z in [-2,2]:
			box(c,'Tire',Vector3(x,0.6,z),Vector3(0.45,1.1,1.1),'dark')

func gas_station():
	var g=group(self,'GasStation',Vector3(72,0,-44))
	box(g,'Forecourt',Vector3(0,0.2,0),Vector3(29,0.5,41),'walk')
	for x in [-9,9]:
		for z in [-8,8]:
			box(g,'CanopyColumn',Vector3(x,4.5,z),Vector3(0.55,9,0.55),'dark')
	box(g,'Canopy',Vector3(0,9.2,0),Vector3(27,1.1,25),'cream')
	box(g,'RedFascia',Vector3(0,9.1,12.6),Vector3(27,0.65,0.15),'red')
	label(g,'FUEL',Vector3(0,9.2,12.75),60)
	for x in [-7,7]:
		box(g,'PumpIsland',Vector3(x,0.6,0),Vector3(4,0.7,9),'cream')
		for z in [-2.5,2.5]:
			box(g,'FuelPump',Vector3(x,2,z),Vector3(1.7,2.5,1.3),'red')
			box(g,'PumpDisplay',Vector3(x,2.6,z+0.7),Vector3(1.2,0.6,0.1),'dark')

func parking():
	var p=group(self,'ParkingLot',Vector3(-48,0,40))
	box(p,'Asphalt',Vector3(0,0.1,0),Vector3(20,0.3,31),'road')
	for z in [-12,-6,0,6,12]:
		box(p,'ParkingStripe',Vector3(0,0.28,z),Vector3(14,0.04,0.18),'line')
	car(p,Vector3(-3,0,-9),'blue')
	car(p,Vector3(3,0,3),'cream')

func camp():
	var c=group(self,'FutureCampClearing',Vector3(-42,0,-67))
	box(c,'Clearing',Vector3(0,0.15,0),Vector3(37,0.3,22),'grass')
	for x in [-15,-10,-5]:
		box(c,'SupplyCrate',Vector3(x,1,-6),Vector3(3,2,3),'wood')
	rod(c,Vector3(11,2,-5),2.1,3.8,'blue')
	for x in [-17,17]:
		rod(c,Vector3(x,3,5),0.13,6,'dark')
		box(c,'Lantern',Vector3(x,5.5,5),Vector3(0.6,0.8,0.6),'warm')
		warm_light(c,Vector3(x,5,5))

func tree(pos):
	rod(self,pos+Vector3(0,2.5,0),0.4,5,'wood')
	for offset in [Vector3(0,6,0),Vector3(2,5,0),Vector3(-1,5,1)]:
		var n=MeshInstance3D.new()
		var mesh=SphereMesh.new()
		mesh.radius=2.7; mesh.height=4.8; mesh.radial_segments=7; mesh.rings=3
		n.mesh=mesh; n.material_override=palette['leaf']; add_child(n); n.position=pos+offset

func set_store(mode: int):
	store_mode=mode%2
	store.get_node('Roof').visible=store_mode==0
	store.get_node('Floor1/NearWalls').visible=store_mode==0

func set_house(mode: int):
	house_mode=mode%3
	house.get_node('Roof').visible=house_mode==0
	house.get_node('Floor1').visible=house_mode!=2
	house.get_node('Floor2').visible=house_mode!=1
	house.get_node('Floor1/NearWalls').visible=house_mode==0
	house.get_node('Floor2/NearWalls').visible=house_mode==0

func _process(delta):
	if camera==null: return
	var direction=Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction+=Vector3(-1,0,-1)
	if Input.is_physical_key_pressed(KEY_S): direction+=Vector3(1,0,1)
	if Input.is_physical_key_pressed(KEY_A): direction+=Vector3(-1,0,1)
	if Input.is_physical_key_pressed(KEY_D): direction+=Vector3(1,0,-1)
	focus+=direction.normalized()*camera.size*delta*0.45
	focus.x=clampf(focus.x,-100,100); focus.z=clampf(focus.z,-100,100)
	update_camera()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C: set_store(store_mode+1)
			KEY_H: set_house(house_mode+1)
			KEY_1: set_house(0)
			KEY_2: set_house(1)
			KEY_3: set_house(2)
			KEY_F1: focus=Vector3.ZERO; camera.size=224
			KEY_F2: focus=store.position+Vector3(0,2,0); camera.size=54
			KEY_F3: focus=house.position+Vector3(0,5,0); camera.size=55
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]: dragging=event.pressed
		if event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.size=clampf(camera.size*0.9,30,250)
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.size=clampf(camera.size/0.9,30,250)
			if event.button_index==MOUSE_BUTTON_LEFT:
				var start=camera.project_ray_origin(event.position)
				var query=PhysicsRayQueryParameters3D.create(start,start+camera.project_ray_normal(event.position)*600)
				var hit=get_world_3d().direct_space_state.intersect_ray(query)
				if hit:
					if hit.collider.get_parent()==store: set_store(store_mode+1)
					if hit.collider.get_parent()==house: set_house(house_mode+1)
	if event is InputEventMouseMotion and dragging:
		var scale_factor=camera.size/get_viewport().get_visible_rect().size.y
		focus+=Vector3(-1,0,1)*event.relative.x*scale_factor*0.71
		focus+=Vector3(-1,0,-1)*event.relative.y*scale_factor*0.95

func capture_suite():
	await get_tree().create_timer(2).timeout
	await verify_controls()
	export_buildings()
	var views=[['01-district',Vector3.ZERO,224,0,0],['02-store-exterior',store.position+Vector3(0,2,0),54,0,0],['03-store-interior',store.position+Vector3(0,2,0),54,1,0],['04-house-exterior',house.position+Vector3(0,5,0),55,0,0],['05-house-floor1',house.position+Vector3(0,2,0),48,0,1],['06-house-floor2',house.position+Vector3(0,9,0),48,0,2]]
	for v in views:
		focus=v[1]; camera.size=v[2]; set_store(v[3]); set_house(v[4]); update_camera()
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png('res://screenshots/'+v[0]+'.png')
		print('CAPTURED '+v[0])
	set_store(0); set_house(0); focus=Vector3.ZERO; camera.size=224; update_camera()
	print('CAPTURE_SUITE_COMPLETE')

func weathering():
	var detail=group(self,'EnvironmentalStorytelling')
	# Large quiet ground patches establish lots without noisy textures.
	for p in [Vector3(-72,0.13,-52),Vector3(20,0.13,69),Vector3(71,0.13,67),Vector3(-72,0.13,66)]:
		box(detail,'WornEarth',p,Vector3(18,0.05,12),'grass')
	for id in ['ConvenienceStore','Clinic','TwoStoreyHouse','AbandonedHouse','Warehouse']:
		var b=get_node(id)
		var floor_node=b.get_node('Floor1/NearWalls')
		var depth=12.5
		if id=='ConvenienceStore': depth=12.0
		if id=='Warehouse': depth=15.0
		if id=='AbandonedHouse': depth=11.5
		for i in range(5):
			box(floor_node,'WeatheredPlaster',Vector3(-9+i*4,1.3,depth+0.26),Vector3(2.2,0.7,0.045),'base')
		if id=='AbandonedHouse':
			for x in [-7.5,7.5]:
				for y in [3.6,4.7]:
					var plank=box(floor_node,'BoardedWindow',Vector3(x,y,depth+0.7),Vector3(6,0.45,0.15),'wood')
					plank.rotation.z=0.14
			for i in range(9):
				var debris=box(detail,'FallenMasonry',b.position+Vector3(-10+i*2,0.5,16+sin(i)*2),Vector3(1.7,0.8,1.2),'walk')
				debris.rotation.y=i*0.7
			box(b.get_node('Roof'),'DarkRoofRepair',Vector3(5,7.99,2),Vector3(9,0.03,8),'dark')
	for x in range(-59,-22,4):
		rod(detail,Vector3(x,1.7,-81),0.12,3.4,'dark')
		for y in [1,2,3]:
			box(detail,'WireFence',Vector3(x+2,y,-81),Vector3(4,0.06,0.06),'dark')
	for p in [Vector3(-20,0,-18),Vector3(-81,0,23),Vector3(34,0,-39)]:
		box(detail,'WasteBin',p+Vector3(0,1,0),Vector3(2,2,1.5),'green')
		box(detail,'WasteBinLid',p+Vector3(0,2.1,0),Vector3(2.2,0.2,1.7),'dark')
	for i in range(15):
		var x=-80+i*11
		box(detail,'SidewalkJoint',Vector3(x,0.76,-8),Vector3(0.07,0.02,5),'base')
		box(detail,'SidewalkJoint',Vector3(x,0.76,18),Vector3(0.07,0.02,5),'base')

func key_input(code):
	var e=InputEventKey.new()
	e.keycode=code; e.physical_keycode=code; e.pressed=true
	get_viewport().push_input(e)
	await get_tree().process_frame
	var up=InputEventKey.new()
	up.keycode=code; up.physical_keycode=code; up.pressed=false
	get_viewport().push_input(up)

func verify_controls():
	await key_input(KEY_C)
	assert(store_mode==1 and not store.get_node('Roof').visible)
	await key_input(KEY_2)
	assert(house_mode==1 and not house.get_node('Floor2').visible)
	await key_input(KEY_3)
	assert(house_mode==2 and not house.get_node('Floor1').visible)
	await key_input(KEY_1)
	assert(house_mode==0 and house.get_node('Roof').visible)
	var before=camera.size
	var wheel=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true
	get_viewport().push_input(wheel)
	await get_tree().process_frame
	assert(camera.size<before)
	var drag=InputEventMouseButton.new()
	drag.button_index=MOUSE_BUTTON_RIGHT; drag.pressed=true
	get_viewport().push_input(drag)
	var origin=focus
	var move=InputEventMouseMotion.new()
	move.relative=Vector2(20,10)
	get_viewport().push_input(move)
	await get_tree().process_frame
	assert(focus.distance_to(origin)>0.1)
	var release=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_RIGHT; release.pressed=false
	get_viewport().push_input(release)
	focus=store.position; camera.size=54; update_camera(); set_store(0)
	await get_tree().physics_frame
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	click.position=camera.unproject_position(store.position+Vector3(0,4,0))
	get_viewport().push_input(click)
	await get_tree().process_frame
	assert(store_mode==1)
	print('VERIFIED keyboard cutaways, floor visibility, wheel zoom, drag pan, building click')

func assign_owner(node, root):
	for child in node.get_children():
		child.owner=root
		assign_owner(child,root)

func export_buildings():
	set_store(0); set_house(0)
	for id in ['ConvenienceStore','Clinic','TwoStoreyHouse','AbandonedHouse','Warehouse']:
		var source=get_node(id)
		assign_owner(source,source)
		var packed=PackedScene.new()
		packed.pack(source)
		ResourceSaver.save(packed,'res://scenes/buildings/'+id.to_snake_case()+'.tscn')
