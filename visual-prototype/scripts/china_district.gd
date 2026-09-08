extends "res://scripts/district.gd"
## The original main.tscn remains a historical art study. The playable scene uses this kit.
var city_data: Dictionary
var city_buildings: Dictionary = {}
var entries: Array = []
var solids: Array = []
var room_points: Dictionary = {}

func build_map():
	city_data=JSON.parse_string(FileAccess.get_file_as_string('res://data/china_block.json'))
	build_roads()
	for spec in city_data.buildings:
		create_city_building(spec)
	store=city_buildings.B01.node
	house=city_buildings.B05.node
	street_furniture()

func weathering():
	pass

func part(parent: Node3D, title: String, pos: Vector3, size: Vector3, material: String, collision := false, fade := false) -> MeshInstance3D:
	var mesh=box(parent,title,pos,size,material)
	mesh.set_meta('occluder',fade)
	if collision: add_walk_body(mesh,size)
	return mesh

func add_walk_body(mesh: Node3D, size: Vector3) -> StaticBody3D:
	var body=StaticBody3D.new()
	body.name='WalkBody'
	body.collision_layer=1
	body.collision_mask=0
	mesh.add_child(body)
	var col=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=size
	col.shape=shape
	body.add_child(col)
	solids.append({'body':body,'size':size})
	return body

func build_roads():
	var r=group(self,'RoadNetwork')
	part(r,'EarthSlice',Vector3(0,-1.8,0),Vector3(240,4,220),'base')
	part(r,'Ground',Vector3(0,0.28,0),Vector3(240,0.2,220),'dirt')
	var road=city_data.roads
	for info in [[road.main_z,15.0],[road.secondary_z,10.0]]:
		var z=float(info[0]); var width=float(info[1])
		part(r,'Carriageway',Vector3(0,0.46,z),Vector3(240,0.12,width),'road')
		for side in [-1,1]:
			part(r,'CycleLane',Vector3(0,0.48,z+side*(width/2+1.7)),Vector3(240,0.12,3),'green')
			part(r,'PedestrianSidewalk',Vector3(0,0.65,z+side*(width/2+5.2)),Vector3(240,0.5,4),'walk')
		for x in range(-114,118,12):
			if absf(x-road.east_x)<10: continue
			part(r,'FadedCentreLine',Vector3(x,0.54,z),Vector3(5,0.025,0.18),'line')
		for x in [-87,85]:
			for mark in range(9):
				part(r,'ZebraCrossing',Vector3(x,0.55,z-width/2+mark*width/9),Vector3(3.4,0.04,width/16),'white')
			for offset in [-3,3]:
				part(r,'StopLine',Vector3(x+offset,0.56,z),Vector3(0.22,0.03,width),'white')
			for side in [-1,1]:
				var ramp=part(r,'KerbRamp',Vector3(x,0.64,z+side*(width/2+3.5)),Vector3(3.8,0.12,1.8),'cream')
				ramp.rotation.x=side*0.12
	part(r,'EastLocalRoad',Vector3(road.east_x,0.47,-6),Vector3(9,0.14,212),'road')
	for x in [road.east_x-7,road.east_x+7]:
		part(r,'EastSidewalk',Vector3(x,0.65,-6),Vector3(4,0.5,212),'walk')
	for z in [road.alley_z,road.court_z,-36,-75]:
		part(r,'ServiceLane',Vector3(-6,0.5,z),Vector3(190,0.18,6),'road')
		for side in [-1,1]:
			part(r,'CourtFootpath',Vector3(-6,0.64,z+side*4.2),Vector3(190,0.35,2),'walk')
	part(r,'CourtSpine',Vector3(road.court_spine_x,0.5,-31),Vector3(6,0.18,94),'road')
	part(r,'SharedCourtyard',Vector3(-27,0.6,-53),Vector3(27,0.3,27),'walk')
	# Connect shopfronts and service entrances to the real street network.
	for spec in city_data.buildings:
		var p=Vector3(spec.position[0],0.68,spec.position[1])
		part(r,'EntryApron',p+Vector3(0,0, spec.size[1]/2+2),Vector3(5,0.2,5),'walk')
		part(r,'RearApron',p-Vector3(0,0,spec.size[1]/2+2),Vector3(5,0.2,5),'walk')
	# A low neighbourhood boundary with two wide, actual openings.
	var f=group(self,'NeighbourhoodBoundary')
	for span in [[-110,-76],[-68,16],[28,86]]:
		var mid=(span[0]+span[1])/2.0
		part(f,'Boundary',Vector3(mid,1.4,22),Vector3(span[1]-span[0],1.6,0.4),'walk',true,true)
	for x in [-75,-69,17,27]:
		part(f,'GatePillar',Vector3(x,2,22),Vector3(0.6,3,0.6),'cream',true,true)
	label(f,'青禾小区',Vector3(-72,3.6,22.3),34)
	label(f,'消防通道  请勿占用',Vector3(22,3.6,22.3),25)

func create_city_building(spec: Dictionary):
	var b=group(self,spec.id,Vector3(spec.position[0],0,spec.position[1]))
	b.set_meta('building_id',spec.id)
	b.set_meta('display_name',spec.name)
	b.set_meta('building_kind',spec.kind)
	var w=float(spec.size[0]); var d=float(spec.size[1]); var count=int(spec.floors)
	var floor_node=group(b,'Floor1')
	floor_node.set_meta('floor_id','1')
	part(floor_node,'FloorSlab',Vector3(0,0.85,0),Vector3(w,0.3,d),'cream')
	var walls=group(floor_node,'Walls')
	for side in [-1,1]:
		# Both real entrance gaps are 2.6 m; no decorative fake doors.
		for half in [-1,1]:
			part(walls,'FacadeSegment',Vector3(half*(w/4+0.65),2.7,side*d/2),Vector3(w/2-1.3,3.6,0.35),spec.color,true,true)
		part(walls,'EntryLintel',Vector3(0,4.05,side*d/2),Vector3(2.6,0.9,0.35),spec.color,false,true)
		part(walls,'SideWall',Vector3(side*w/2,2.7,0),Vector3(0.35,3.6,d),spec.color,true,true)
		add_entry(b,floor_node,spec,'front' if side==1 else 'rear',Vector3(0,2.2,side*d/2),Vector3(0,0,side))
	window_band(walls,w,d,2.8)
	var upper=group(b,'UpperExterior')
	for level in range(1,count):
		var shell=group(upper,'Floor'+str(level+1),Vector3(0,level*3.4,0))
		shell.set_meta('floor_id',str(level+1)); shell.set_meta('accessible',false)
		for side in [-1,1]:
			part(shell,'UpperFacade',Vector3(0,2.7,side*d/2),Vector3(w,3.4,0.32),spec.color,false,true)
			part(shell,'UpperSide',Vector3(side*w/2,2.7,0),Vector3(0.32,3.4,d),spec.color,false,true)
		part(shell,'FloorBand',Vector3(0,0.98,0),Vector3(w+0.3,0.2,d+0.3),'walk',false,true)
		window_band(shell,w,d,2.7)
	var roof=group(b,'Roof')
	part(roof,'FlatRoof',Vector3(0,count*3.4+1.1,0),Vector3(w+0.3,0.35,d+0.3),'roof',false,true)
	for side in [-1,1]:
		part(roof,'Parapet',Vector3(0,count*3.4+1.5,side*d/2),Vector3(w,0.7,0.25),'walk',false,true)
		part(roof,'SideParapet',Vector3(side*w/2,count*3.4+1.5,0),Vector3(0.25,0.7,d),'walk',false,true)
	part(roof,'WaterTank',Vector3(-w/4,count*3.4+2.1,-d/4),Vector3(2,1.8,2),'blue',false,true)
	var signs=group(floor_node,'Signs')
	part(signs,'ShopFascia',Vector3(0,4.1,d/2+0.3),Vector3(minf(w,20),0.9,0.2),'green' if spec.kind!='clinic' else 'red')
	label(signs,spec.name,Vector3(0,4.08,d/2+0.45),30)
	var rear_sign=Label3D.new()
	rear_sign.text='后门 / '+spec.name
	rear_sign.font_size=24; rear_sign.pixel_size=0.014; rear_sign.outline_size=0
	floor_node.add_child(rear_sign); rear_sign.position=Vector3(0,3.7,-d/2-0.3); rear_sign.rotation.y=PI
	city_buildings[spec.id]={'node':b,'spec':spec,'roof':roof,'upper':upper,'inside':false}
	furnish(b,floor_node,spec)

func window_band(parent,w,d,y):
	for side in [-1,1]:
		for x in [-w*0.32,w*0.32]:
			part(parent,'WindowFrame',Vector3(x,y,side*(d/2+0.2)),Vector3(2.2,1.6,0.12),'white',false,true)
			part(parent,'WindowGlass',Vector3(x,y,side*(d/2+0.28)),Vector3(1.95,1.35,0.08),'glass',false,true)
		for z in [-d*0.28,d*0.28]:
			part(parent,'SideWindowFrame',Vector3(side*(w/2+0.2),y,z),Vector3(0.12,1.6,2.2),'white',false,true)
			part(parent,'SideWindowGlass',Vector3(side*(w/2+0.28),y,z),Vector3(0.08,1.35,1.95),'glass',false,true)
		part(parent,'AirConditioner',Vector3(side*(w/2+0.45),y-0.9,-d*0.1),Vector3(0.6,0.55,1),'cream',false,true)

func add_entry(b,floor_node,spec,side,pos,normal):
	var state=spec[side]
	var anchor=group(floor_node,'Entry_'+side,pos)
	anchor.set_meta('entry_id',spec.id+'_'+side)
	anchor.set_meta('door_state',state)
	anchor.set_meta('interaction_point','door')
	var collider=add_walk_body(anchor,Vector3(2.5,2.6,0.22))
	var hinge=group(anchor,'Hinge',Vector3(-1.25,0,0))
	var leaf=part(hinge,'DoorLeaf',Vector3(1.25,0,0),Vector3(2.5,2.6,0.18),'blue')
	part(hinge,'Handle',Vector3(2.2,0,normal.z*0.18),Vector3(0.13,0.45,0.16),'warm')
	for x in [-1.37,1.37]:
		part(anchor,'DoorJamb',Vector3(x,0,0),Vector3(0.16,2.8,0.35),'wood')
	part(anchor,'Threshold',Vector3(0,-1.22,0),Vector3(2.6,0.08,0.65),'warm')
	var status=Label3D.new()
	status.font_size=22; status.pixel_size=0.012; status.outline_size=0
	anchor.add_child(status); status.position=Vector3(0,1.65,normal.z*0.25)
	if normal.z<0: status.rotation.y=PI
	var words={'normal':'正常 · E 开关','locked':'上锁 · 请走另一入口','blocked':'堵塞 · 请走另一入口','damaged':'损坏 · 可通行 / 无法关闭'}
	status.text=words[state]
	if state=='locked':
		part(anchor,'LockBar',Vector3(0,0,normal.z*0.22),Vector3(2.1,0.14,0.14),'rust')
		part(anchor,'Padlock',Vector3(0,-0.2,normal.z*0.24),Vector3(0.35,0.45,0.2),'warm')
	if state=='blocked':
		part(anchor,'Blockade',Vector3(0,-0.5,normal.z*0.55),Vector3(2.3,1.35,0.7),'wood',true)
	if state=='damaged':
		collider.collision_layer=0
		hinge.rotation.y=normal.z*PI/2
		leaf.rotation.z=0.1
	entries.append({'id':spec.id+'_'+side,'building_id':spec.id,'state':state,'open':state=='damaged','anchor':anchor,'body':collider,'hinge':hinge,'leaf':leaf,'normal':normal,'label':spec.name+('正门' if side=='front' else '后门'),'outside':b.position+Vector3(pos.x,1,pos.z)+normal*2.1,'inside':b.position+Vector3(pos.x,1,pos.z)-normal*2.1,'centre':b.position+Vector3(pos.x,1,pos.z)})

func room(parent,title,id):
	var n=group(parent,title)
	n.set_meta('room_id',id)
	return n

func furnish(b,floor_node,spec):
	var rooms=group(floor_node,'Rooms')
	var w=float(spec.size[0]); var d=float(spec.size[1])
	var main=room(rooms,'MainRoom',spec.id+'_main')
	var back=room(rooms,'ServiceRoom',spec.id+'_service')
	# Central 3.6m passage is open end-to-end. Side partitions define real rooms.
	for side in [-1,1]:
		part(back,'Partition',Vector3(side*(w/4+0.9),2.1,-d*0.15),Vector3(w/2-1.8,2.4,0.2),'cream',true,true)
	room_points[spec.id]=b.position+Vector3(0,1,0)
	match spec.kind:
		'store':
			for x in [-4,4]:
				part(main,'ShelfBody',Vector3(x,1.7,0),Vector3(1.2,1.6,3),'wood',true,true)
				for y in [1.4,2.0,2.6]:
					part(main,'ShelfStock',Vector3(x,y,0),Vector3(1.15,0.2,2.7),'green')
			part(main,'Checkout',Vector3(w/2-2,1.5,4),Vector3(2.3,1.2,2),'green',true,true)
			part(back,'StorageBoxes',Vector3(-w/2+2,1.4,-d/2+2),Vector3(2,1,2),'wood',true)
		'clinic':
			part(main,'Reception',Vector3(w/2-3,1.5,5),Vector3(4,1.2,1.3),'white',true,true)
			part(main,'ExamBed',Vector3(-w/2+3,1.4,1),Vector3(2,1,3),'blue',true)
			part(back,'MedicineCabinet',Vector3(-w/2+1,2,-d/2+2),Vector3(1,2.2,2),'white',true,true)
			label(back,'药房',Vector3(-w/4,3,-d*0.15+0.2),25)
			part(main,'ClinicCrossH',Vector3(w/2-1,2.9,1),Vector3(0.1,0.3,1.4),'red')
			part(main,'ClinicCrossV',Vector3(w/2-1,2.9,1),Vector3(0.1,1.4,0.3),'red')
		'hardware':
			part(main,'Workbench',Vector3(-w/2+2,1.5,1),Vector3(2,1.2,4),'wood',true,true)
			for i in range(3): part(back,'StockCrate',Vector3(3+i,1.4,-d/2+2),Vector3(0.8,1,2),'rust',true)
		'cafe':
			for x in [-4,4]:
				part(main,'DiningTable',Vector3(x,1.4,3),Vector3(2,0.9,2),'wood',true)
				for z in [1.5,4.5]: part(main,'Chair',Vector3(x,1.25,z),Vector3(0.8,0.6,0.8),'green',true)
			part(back,'KitchenRange',Vector3(-w/2+2,1.5,-d/2+2),Vector3(3,1.2,1.5),'white',true)
		'residential','tower':
			var flat=room(rooms,'GroundFloorFlat',spec.id+'_flat')
			part(flat,'Sofa',Vector3(-w/2+3,1.4,2),Vector3(2,1,3),'green',true)
			part(flat,'Table',Vector3(-w/2+6,1.4,2),Vector3(1.5,1,2),'wood',true)
			part(back,'Bed',Vector3(-w/2+3,1.3,-d/2+3),Vector3(2,0.8,3),'blue',true)
			part(back,'Kitchen',Vector3(-w/2+6,1.5,-d/2+1.5),Vector3(3,1.2,1),'white',true)
		'community':
			part(main,'ActivityTable',Vector3(-5,1.4,2),Vector3(4,0.9,2),'wood',true)
			part(main,'OfficeDesk',Vector3(5,1.5,3),Vector3(3,1.2,1.6),'cream',true)
			part(back,'Tools',Vector3(-5,1.8,-d/2+2),Vector3(3,1.8,1),'green',true)
		'market':
			for x in [-5,5]:
				part(main,'ProduceStall',Vector3(x,1.4,1),Vector3(2.5,1,4),'wood',true)
				part(main,'VegetableBlocks',Vector3(x,2,1),Vector3(2.3,0.25,3.8),'leaf')
			part(back,'ColdRoom',Vector3(-w/2+2,2,-d/2+2),Vector3(2.5,2.2,2.5),'white',true,true)
		'depot':
			for x in [-5,5]: part(main,'ParcelRack',Vector3(x,1.9,2),Vector3(2,2,4),'wood',true,true)
			part(back,'SortingTable',Vector3(-4,1.4,-d/2+3),Vector3(4,0.9,2),'cream',true)
	if spec.floors>1:
		var stairs=room(rooms,'StairLanding',spec.id+'_stairs')
		var x=w/2-2
		part(stairs,'GroundLanding',Vector3(x,0.95,-d/2+5),Vector3(3,0.1,3),'walk')
		for i in range(4):
			part(stairs,'ClosedStair',Vector3(x,1.1+i*0.18,-d/2+2.5-i*0.45),Vector3(2.5,0.4+i*0.36,0.5),'walk',true)
		part(stairs,'UpperFloorBarricade',Vector3(x,2.1,-d/2+3),Vector3(2.8,2.4,0.2),'rust',true)
		label(stairs,'上层封闭\n本版仅开放首层',Vector3(x,3.1,-d/2+3.2),22)
	warm_light(floor_node,Vector3(0,3.3,0))

func street_furniture():
	var p=group(self,'StreetFurniture')
	for x in [-106,-58,-25,25,65,111]:
		for z in [61,89,-98,-79]:
			rod(p,Vector3(x,3.4,z),0.1,5.7,'dark')
			part(p,'Lamp',Vector3(x,6.3,z),Vector3(1,0.18,0.4),'cream')
	for x in [-108,-95,-30,33,79]:
		tree(Vector3(x,0,91))
	for pos in [Vector3(-30,0,-58),Vector3(-18,0,-47),Vector3(34,0,-64),Vector3(-97,0,-20)]: tree(pos)
	# Stop bay downstream of the west crossing, outside the running/bicycle lanes.
	var bus=group(p,'BusStop',Vector3(-51,0,90))
	for x in [-4,4]: part(bus,'Post',Vector3(x,2,0),Vector3(0.12,3,0.12),'dark')
	part(bus,'Canopy',Vector3(0,3.6,0),Vector3(10,0.2,2.4),'green',false,true)
	part(bus,'Bench',Vector3(0,1.2,0),Vector3(6,0.5,0.6),'wood',true)
	label(bus,'青禾路站',Vector3(0,3.1,0.2),26)
	for x in [-108,-103,-98,32,37,42]:
		part(p,'CycleRail',Vector3(x,1.25,65),Vector3(3,1,0.12),'dark')
	for x in [-49,-44,-39,-34]:
		part(p,'ParkingLine',Vector3(x,0.75,-30),Vector3(0.12,0.03,4),'line')
	car(p,Vector3(-46,0.4,-30),'rust')
	# Collision for the reused abandoned-car visual, explicitly registered.
	for c in p.get_children():
		if c.name.to_lower().begins_with('abandonedvehicle'):
			add_walk_body(c.get_node('Body'),Vector3(3.2,1.2,6.5))
	for i in range(4):
		part(p,'RecyclingBin',Vector3(-23+i*1.4,1.3,-70),Vector3(1,1.4,1),'blue' if i%2 else 'green',true)
	label(p,'垃圾分类',Vector3(-21,2.7,-70),24)
	# Simple painted lane arrows point along the major road.
	for x in [-65,-10,45]:
		part(p,'ArrowStem',Vector3(x,0.57,72),Vector3(3,0.025,0.2),'line')
		for sign in [-1,1]:
			var arrow=part(p,'ArrowHead',Vector3(x+1,0.57,72+sign*0.4),Vector3(1.2,0.025,0.16),'line')
			arrow.rotation.y=sign*0.7
