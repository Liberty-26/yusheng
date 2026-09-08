extends "res://scripts/china_district.gd"
const WALK_SPEED := 5.175
const SPRINT_SPEED := 9.2
const DEHYDRATED_SPEED := 2.5
var orbit=preload('res://scripts/exploration_camera.gd').new()
var occlusion=preload('res://scripts/occlusion_fader.gd').new()
var player: CharacterBody3D
var hud: Label
var prompt: Label
var bag={'水':0,'食物':0,'药品':0}
var containers: Array=[]
var elapsed:=0.0
var stamina:=100.0
var thirst:=100.0
var finished:=false
var notice:='到社区卫生服务站取药，返回便利店交付。'
var search_time:=0.0
var search_target=null
var route_move:=Vector3.ZERO
var route_speed_multiplier:=1.0
var home: Vector3
var spawn: Vector3

func _ready():
	super._ready()
	set_process_unhandled_input(false)
	player=CharacterBody3D.new()
	player.name='Survivor'; player.collision_layer=4; player.collision_mask=1
	add_child(player)
	var task=city_data.task
	spawn=task_position(task.home_building,task.spawn_local)
	home=task_position(task.home_building,task.home_local)
	player.position=spawn
	var collision=CollisionShape3D.new()
	var shape=CapsuleShape3D.new(); shape.radius=0.4; shape.height=1.75
	collision.shape=shape; collision.position.y=0.875; player.add_child(collision)
	var body=MeshInstance3D.new()
	var capsule=CapsuleMesh.new(); capsule.radius=0.4; capsule.height=1.75
	body.mesh=capsule; body.material_override=palette.warm; body.position.y=0.875; player.add_child(body)
	add_container('便利店水箱',task_position(task.home_building,task.water_local),'水',2)
	add_container('便利店食品箱',task_position(task.home_building,task.food_local),'食物',2)
	add_container('卫生站药柜',task_position(task.medicine_building,task.medicine_local),'药品',1)
	var layer=CanvasLayer.new(); add_child(layer)
	var panel=ColorRect.new(); panel.position=Vector2(12,10); panel.size=Vector2(720,108)
	panel.color=Color(0.06,0.1,0.12,0.9); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(panel)
	hud=Label.new(); hud.position=Vector2(22,16); hud.add_theme_font_size_override('font_size',15); layer.add_child(hud)
	prompt=Label.new(); prompt.position=Vector2(22,126); prompt.add_theme_font_size_override('font_size',17); layer.add_child(prompt)
	add_child(orbit); orbit.setup(camera)
	add_child(occlusion); occlusion.setup(self,player,camera)
	if '--city-test' in OS.get_cmdline_user_args(): call_deferred('verify_city')

func task_position(id,local):
	return city_buildings[id].node.position+Vector3(local[0],1,local[1])

func add_container(title,pos,item,amount):
	var mesh=part(self,'SearchContainer',pos+Vector3(0,0.5,0),Vector3(0.8,1,0.8),'red' if item=='药品' else 'blue',true)
	mesh.set_meta('interaction_point','loot_'+item)
	containers.append({'label':title,'mesh':mesh,'item':item,'amount':amount,'point':pos})

func bag_total(): return bag['水']+bag['食物']+bag['药品']

func reachable(point: Vector3,reach:=3.0) -> bool:
	if player.position.distance_to(Vector3(point.x,1,point.z))>reach: return false
	var ray=PhysicsRayQueryParameters3D.create(player.position+Vector3(0,1.2,0),Vector3(point.x,2.2,point.z),1)
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.position.distance_to(Vector3(point.x,2.2,point.z))<0.8

func nearest():
	var best=null; var distance=INF
	for e in entries:
		var length=player.position.distance_to(e.centre)
		if length<distance and reachable(e.centre): best=e; distance=length
	for c in containers:
		var length=player.position.distance_to(c.point)
		if c.amount>0 and length<distance and reachable(c.point): best=c; distance=length
	return best

func entry_prompt(e):
	match e.state:
		'locked': return e.label+'：上锁，请寻找另一入口'
		'blocked': return e.label+'：堵塞，请寻找另一入口'
		'damaged': return e.label+'：损坏，可通行、无法关闭'
	return 'E '+('关闭 ' if e.open else '打开 ')+e.label

func toggle_door(e):
	if e.state!='normal': notice=entry_prompt(e); return
	e.open=not e.open
	e.hinge.rotation.y=e.normal.z*PI/2 if e.open else 0.0
	e.body.collision_layer=0 if e.open else 1
	e.anchor.set_meta('is_open',e.open)
	notice=e.label+('已打开' if e.open else '已关闭')

func take(c):
	if c.amount<=0 or not reachable(c.point) or bag_total()>=6: return
	bag[c.item]+=1; c.amount-=1; notice='获得 '+c.item+' ×1'
	if c.amount==0: c.mesh.material_override=palette.dark

func _physics_process(delta):
	if player==null: return
	if not finished: elapsed+=delta; thirst=maxf(0,thirst-delta*0.08)
	var direction=Vector3.ZERO if finished else orbit.ground_direction()
	if route_move!=Vector3.ZERO: direction=route_move
	var sprint=Input.is_physical_key_pressed(KEY_SHIFT) and stamina>1 and direction.length()>0 and thirst>0
	stamina=clampf(stamina+delta*(-15 if sprint else 9),0,100)
	player.velocity=direction.normalized()*(SPRINT_SPEED if sprint else (DEHYDRATED_SPEED if thirst==0 else WALK_SPEED))*route_speed_multiplier
	player.move_and_slide(); player.position.y=1
	player.position.x=clampf(player.position.x,-118,118); player.position.z=clampf(player.position.z,-108,108)
	for data in city_buildings.values():
		var relative=player.position-data.node.position
		data.inside=absf(relative.x)<data.spec.size[0]/2+0.2 and absf(relative.z)<data.spec.size[1]/2+0.2
		data.roof.visible=not data.inside; data.upper.visible=not data.inside
	occlusion.tick(delta)
	var target=nearest()
	if not finished and Input.is_physical_key_pressed(KEY_E) and target!=null and target.has('item') and direction==Vector3.ZERO and bag_total()<6:
		if search_target!=target: search_time=0; search_target=target
		search_time+=delta
		if search_time>=2: take(target); search_time=0
	else: search_time=0; search_target=null
	var task='卫生站取药 → 便利店交付' if bag['药品']==0 else '带药返回便利店，靠近收银台按 E'
	if finished: task='药品已交付，基础循环完成 · R 重开'
	hud.text='余生 · 青禾街区  |  '+task+'\n背包 %d/6  水 %d · 食物 %d · 药品 %d  |  %02d:%02d  体力 %d · 水分 %d\nWASD 移动 · Shift 跑 · E 门/按住搜刮 · Q 喝水 · F 吃东西\n右键拖动：水平旋转 / 上下俯仰 · 滚轮缩放 · Home 复位 · R 重开'%[bag_total(),bag['水'],bag['食物'],bag['药品'],int(elapsed)/60,int(elapsed)%60,int(stamina),int(thirst)]
	prompt.text=notice
	if not finished and target!=null:
		prompt.text=entry_prompt(target) if target.has('state') else ('按住 E 搜索 '+target.label+' %.1f / 2 秒'%search_time)
		if target.has('item') and bag_total()>=6: prompt.text='背包已满：Q 喝水或 F 吃东西后再搜刮'
	if not finished and reachable(home,2.2) and bag['药品']>0: prompt.text='E 在收银台交付药品'

func _process(delta):
	if player!=null: orbit.tick(delta,player.position+Vector3.UP)

func update_camera():
	if orbit.view==null: super.update_camera()

func _input(event):
	if player==null: return
	orbit.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_R: get_tree().reload_current_scene()
		if finished: return
		if event.keycode==KEY_Q and bag['水']>0: bag['水']-=1; thirst=minf(100,thirst+45)
		if event.keycode==KEY_F and bag['食物']>0: bag['食物']-=1; stamina=100
		if event.keycode==KEY_E:
			if bag['药品']>0 and reachable(home,2.2):
				bag['药品']-=1; finished=true; notice='药品已交付。'; return
			var target=nearest()
			if target!=null and target.has('state'): toggle_door(target)

func verify_city():
	await preload('res://scripts/city_verification.gd').new().run(self)
