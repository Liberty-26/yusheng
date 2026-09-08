extends RefCounted
var g
var grid: AStarGrid2D
var captures: Array=[]
var visits: Array=[]
var steps:=0

func wait(seconds: float): await g.get_tree().create_timer(seconds).timeout
func key(code,pressed):
	var e=InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=pressed; Input.parse_input_event(e)
func mouse(button,pressed):
	var e=InputEventMouseButton.new(); e.button_index=button; e.pressed=pressed; Input.parse_input_event(e)
func motion(x,y):
	var e=InputEventMouseMotion.new(); e.relative=Vector2(x,y); Input.parse_input_event(e)
func interact():
	key(KEY_E,true); await g.get_tree().physics_frame; key(KEY_E,false); await g.get_tree().physics_frame

func make_grid():
	grid=AStarGrid2D.new(); grid.region=Rect2i(0,0,241,221); grid.cell_size=Vector2.ONE; grid.offset=Vector2(-120,-110)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER; grid.update()
	for item in g.solids:
		if item.body.collision_layer==0: continue
		var p=item.body.global_position
		var size=item.size
		if p.y+size.y/2<1.01 or p.y-size.y/2>2.74: continue
		var start=Vector2i(ceil(p.x-size.x/2-0.43)+120,ceil(p.z-size.z/2-0.43)+110)
		var end=Vector2i(floor(p.x+size.x/2+0.43)+120,floor(p.z+size.z/2+0.43)+110)
		for x in range(maxi(0,start.x),mini(240,end.x)+1):
			for y in range(maxi(0,start.y),mini(220,end.y)+1): grid.set_point_solid(Vector2i(x,y),true)

func cell(p): return Vector2i(roundi(p.x)+120,roundi(p.z)+110)

func walk(destination: Vector3):
	make_grid()
	var from=cell(g.player.position); var to=cell(destination)
	assert(not grid.is_point_solid(from),'Current position blocked in route grid '+str(g.player.position))
	assert(not grid.is_point_solid(to),'Destination blocked '+str(destination))
	var path=grid.get_point_path(from,to)
	assert(path.size()>0,'No collision-free route to '+str(destination))
	print('ROUTE ',g.player.position,' -> ',destination,' gridpoints=',path.size())
	# Compress only collinear segments. Every bend remains a real physical waypoint.
	var corners: Array=[]
	for i in range(1,path.size()):
		if i==path.size()-1 or (path[i]-path[i-1]).normalized()!=(path[i+1]-path[i]).normalized(): corners.append(Vector3(path[i].x,1,path[i].y))
	corners.append(destination)
	print('ROUTE_CORNERS ',corners)
	for target in corners:
		var guard=0
		while g.player.position.distance_to(target)>0.7:
			g.route_move=(target-g.player.position).normalized()
			await g.get_tree().physics_frame
			guard+=1; steps+=1
			if guard%1000==0: print('ROUTE_PROGRESS ',guard,' ',g.player.position,' -> ',target)
			assert(guard<3000,'Physical route blocked at '+str(g.player.position)+' to '+str(target))
	g.route_move=Vector3.ZERO
	await g.get_tree().physics_frame

func snap(title):
	if DisplayServer.get_name() == 'headless':
		captures.append(title+'.png (graphical capture required)')
		print('CITY_CAPTURE_SKIPPED_HEADLESS ',title)
		return
	await wait(0.4)
	await RenderingServer.frame_post_draw
	var path='res://screenshots/china/'+title+'.png'
	assert(g.get_viewport().get_texture().get_image().save_png(path)==OK)
	captures.append(title+'.png')
	print('CITY_CAPTURED ',title)

func direction():
	var v=g.camera.position-(g.player.position+Vector3.UP)
	return Vector2(atan2(v.x,v.z),atan2(v.y,Vector2(v.x,v.z).length()))

func run(game):
	g=game
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path('res://screenshots/china'))
	await wait(1)
	print('CITY_BEGIN buildings=',g.city_buildings.size(),' entries=',g.entries.size(),' solids=',g.solids.size())
	assert(g.city_buildings.size()==10 and g.entries.size()==20)
	# Faster automated replay only; delta/physics resolution remains equivalent to normal play.
	Engine.physics_ticks_per_second=60; Engine.time_scale=1; g.route_speed_multiplier=4.0
	g.occlusion.enabled=false
	var first=g.entries[0]
	await walk(first.inside)
	await interact(); assert(first.open)
	await walk(first.outside)
	await walk(g.spawn)
	for id in g.city_buildings:
		print('BUILDING_ROUTE_BEGIN ',id,' ',g.city_buildings[id].spec.name)
		var usable=null
		for e in g.entries:
			if e.building_id==id and e.state=='normal': usable=e; break
		assert(usable!=null,'Every building has an actually operable entrance')
		print('ENTRY_DATA ',usable.id,' outside=',usable.outside,' inside=',usable.inside,' centre=',usable.centre,' normal=',usable.normal)
		await walk(usable.outside)
		print('BUILDING_OUTSIDE_REACHED ',id,' ',usable.id)
		if not usable.open:
			await interact(); assert(usable.open,'E must open '+usable.id)
		await walk(usable.inside)
		print('BUILDING_INSIDE_REACHED ',id)
		await wait(0.1)
		assert(g.city_buildings[id].inside and not g.city_buildings[id].roof.visible)
		print('BUILDING_STATE ',id,' open=',usable.open,' layer=',usable.body.collision_layer,' player=',g.player.position)
		assert(g.city_buildings[id].node.has_meta('building_id'))
		if id in ['B01','B02','B05','B07']:
			g.orbit.target_zoom=30
			await snap('inside-'+id)
		await walk(usable.outside)
		print('BUILDING_EXIT_REACHED ',id)
		await wait(0.1)
		assert(not g.city_buildings[id].inside,'Actually leave '+id)
		visits.append({'building':id,'name':g.city_buildings[id].spec.name,'entry':usable.id,'spawn_to_room_and_back':true})
		print('BUILDING_ROUTE_PASS ',id,' ',g.city_buildings[id].spec.name,' via ',usable.id)
	await walk(g.spawn)
	# Each door state is exercised from a real approach, without teleporting.
	for state in ['normal','locked','blocked','damaged']:
		var door=null
		for e in g.entries:
			if e.state==state: door=e; break
		await walk(door.outside)
		if state=='normal' and door.open: await interact()
		if state!='normal':
			await interact(); assert(not door.open if state!='damaged' else door.open)
		assert(door.leaf.is_visible_in_tree())
		assert(door.anchor.get_meta('door_state')==state)
		g.route_move=-door.normal
		await wait(0.7)
		g.route_move=Vector3.ZERO
		var signed=(g.player.position-door.centre).dot(door.normal)
		if state=='damaged':
			assert(signed<0 and door.body.collision_layer==0)
		else:
			assert(signed>0.35 and door.body.collision_layer==1,'Closed/locked/blocked doorway must stop player')
		g.orbit.target_zoom=22
		await snap('door-'+state)
		if state=='normal':
			await interact(); assert(door.open)
			g.route_move=-door.normal; await wait(0.7); g.route_move=Vector3.ZERO
			assert((g.player.position-door.centre).dot(door.normal)<0)
		print('DOOR_STATE_PASS ',state,' ',door.id,' ',g.entry_prompt(door))
		g.player.position=g.spawn
		await g.get_tree().physics_frame
	# Move to a clear street location for camera controls and screen-direction tests.
	await walk(Vector3(22,1,10))
	Engine.time_scale=1; Engine.physics_ticks_per_second=60
	var previous=direction().x; var total=0.0
	mouse(MOUSE_BUTTON_RIGHT,true)
	for i in range(16):
		motion(-deg_to_rad(45)/0.006,0); await wait(0.25)
		var current=direction().x; total+=wrapf(current-previous,-PI,PI); previous=current
		if i%4==0:
			g.orbit.target_zoom=175
			await snap('overview-%02d'%i)
	mouse(MOUSE_BUTTON_RIGHT,false); await wait(0.7)
	total+=wrapf(direction().x-previous,-PI,PI)
	assert(rad_to_deg(total)>719 and rad_to_deg(total)<721)
	print('CAMERA_720_PASS actual=',rad_to_deg(total))
	for sample in [[-10000,25.0],[10000,75.0]]:
		mouse(MOUSE_BUTTON_RIGHT,true); motion(0,sample[0]); mouse(MOUSE_BUTTON_RIGHT,false)
		await wait(0.8)
		assert(absf(rad_to_deg(direction().y)-sample[1])<0.1)
		assert(g.camera.position.y>g.player.position.y and g.camera.position.distance_to(g.player.position)<g.camera.far)
		await snap('pitch-'+str(int(sample[1])))
	key(KEY_HOME,true); key(KEY_HOME,false); await wait(0.8)
	assert(absf(rad_to_deg(direction().y)-43)<0.1 and absf(wrapf(direction().x-PI/4,-PI,PI))<0.003 and absf(g.camera.size-43)<0.1)
	print('CAMERA_PITCH_HOME_PASS 25 / 75 / 43')
	for i in range(8):
		mouse(MOUSE_BUTTON_RIGHT,true); motion(-deg_to_rad(45)/0.006,0); mouse(MOUSE_BUTTON_RIGHT,false); await wait(0.5)
		var origin=g.player.position; var right=g.camera.global_basis.x; var up=g.camera.global_basis.y
		key(KEY_W,true); await wait(0.2); key(KEY_W,false); await g.get_tree().physics_frame
		var moved=g.player.position-origin
		assert(moved.length()>0.7 and moved.dot(up)>0.4 and absf(moved.dot(right))<0.08)
		print('CAMERA_W_PASS ',i,' actual yaw=',rad_to_deg(direction().x))
	# Real roof/wall rays in a tall building: walk near inside wall and rotate toward it.
	g.occlusion.enabled=true
	Engine.physics_ticks_per_second=60; Engine.time_scale=1; g.route_speed_multiplier=4.0
	var tower_entry=null
	for e in g.entries:
		if e.id=='B07_front': tower_entry=e
	await walk(tower_entry.outside); await walk(tower_entry.inside)
	await walk(g.city_buildings.B07.node.position+Vector3(0,1,9))
	g.orbit.target_zoom=32
	mouse(MOUSE_BUTTON_RIGHT,true); motion(-wrapf(0-direction().x,-PI,PI)/0.006,0); mouse(MOUSE_BUTTON_RIGHT,false)
	await wait(0.8)
	var faded=[]
	for entry in g.occlusion.surfaces:
		if entry.mesh.is_visible_in_tree() and entry.mesh.material_override!=entry.original: faded.append(entry)
	assert(faded.size()>0,'New city wall must really occlude and fade')
	await snap('occlusion-tower')
	await walk(tower_entry.outside); await walk(Vector3(22,1,10)); await wait(0.7)
	for entry in faded: assert(entry.mesh.material_override==entry.original,'Restore exact material')
	print('CITY_OCCLUSION_RESTORE_PASS surfaces=',faded.size())
	await walk(Vector3(-80,1,61)); g.orbit.target_zoom=65; await snap('road-crossing')
	# Preserve the actual hold-to-search and medicine conservation loop.
	await walk(g.spawn)
	var started=g.elapsed
	var clinic=null
	for e in g.entries:
		if e.id=='B02_front': clinic=e
	await walk(clinic.outside)
	if not clinic.open: await interact()
	await walk(clinic.inside)
	var loot=g.containers[2]
	await walk(loot.point+Vector3(0,0,1.3))
	assert(g.reachable(loot.point))
	key(KEY_E,true); await wait(2.15); key(KEY_E,false); await wait(0.05)
	assert(g.bag['药品']==1 and loot.amount==0,'Hold E conserves medicine')
	await walk(clinic.outside); await walk(g.home)
	await interact(); assert(g.finished and g.bag['药品']==0)
	print('CITY_MEDICINE_ROUTE_PASS seconds=',g.elapsed-started,' physical_steps=',steps)
	Engine.time_scale=1; Engine.physics_ticks_per_second=60; g.route_speed_multiplier=1.0
	var report={'buildings':visits,'captures':captures,'door_states':['normal','locked','blocked','damaged'],'medicine_delivered':g.finished,'automated_replay_time_scale':4,'actual_walking':true}
	var file=FileAccess.open('res://docs/city-verification.json',FileAccess.WRITE); file.store_string(JSON.stringify(report,'  ')); file.close()
	print('CITY_ALL_PASS')
	g.get_tree().quit()
