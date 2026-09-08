extends Node
## Dedicated detection layer. Never mutate walking collision or interactive materials.
const DETECTION_LAYER := 8
const FADED_ALPHA := 0.22
var world: Node3D
var actor: Node3D
var view: Camera3D
var surfaces: Array = []
var body_to_index: Dictionary = {}
var last_blocked: Dictionary = {}

func setup(root: Node3D, player: Node3D, camera: Camera3D):
	world=root; actor=player; view=camera
	collect(root)

func collect(node: Node):
	# Snapshot first: adding sensor children must not enter the traversal again.
	for child in node.get_children(): collect(child)
	if not node is MeshInstance3D: return
	var mesh=node as MeshInstance3D
	var path=str(mesh.get_path())
	var title=str(mesh.name)
	if not mesh.material_override is StandardMaterial3D: return
	var architecture='/Roof/' in path or '/FarWalls/' in path or '/NearWalls/' in path or '/Floor2/' in path
	var large_prop=title in ['Canopy','Cabin','Body','Partition','Shelf','ShelfBase'] or mesh.mesh is SphereMesh
	if not architecture and not large_prop: return
	if title in ['Door','UpperWindow','DoorLeaf','DoorHandle'] or 'Door' in title: return
	var bounds=mesh.mesh.get_aabb()
	if bounds.size.length()<1.5: return
	var sensor=StaticBody3D.new()
	sensor.name='OcclusionSensor'
	sensor.collision_layer=DETECTION_LAYER
	sensor.collision_mask=0
	mesh.add_child(sensor)
	var collision=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=bounds.size
	collision.shape=shape
	collision.position=bounds.get_center()
	sensor.add_child(collision)
	var original=mesh.material_override
	var faded=original.duplicate() as StandardMaterial3D
	faded.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	body_to_index[sensor.get_instance_id()]=surfaces.size()
	surfaces.append({'mesh':mesh,'original':original,'faded':faded,'alpha':1.0,'hold':0.0,'shadow':mesh.cast_shadow})

func tick(delta: float):
	if not is_instance_valid(actor): return
	var blocked: Dictionary = {}
	# Parallel orthographic rays cover the body silhouette, not just its centre.
	var right=view.global_basis.x
	for offset in [Vector3(0,0.25,0),Vector3(0,1,0),Vector3(0,1.75,0),right*0.55+Vector3.UP,right*(-0.55)+Vector3.UP]:
		var end=actor.global_position+offset
		var start=view.project_ray_origin(view.unproject_position(end))
		var excluded: Array[RID] = []
		for depth in range(16):
			var query=PhysicsRayQueryParameters3D.create(start,end,DETECTION_LAYER,excluded)
			query.hit_from_inside=true
			var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): break
			excluded.append(hit.rid)
			var index=body_to_index.get(hit.collider.get_instance_id(),-1)
			if index>=0 and surfaces[index].mesh.is_visible_in_tree(): blocked[index]=true
	last_blocked=blocked
	for index in range(surfaces.size()):
		var entry=surfaces[index]
		entry.hold=0.12 if blocked.has(index) else maxf(0,entry.hold-delta)
		var target=FADED_ALPHA if entry.hold>0 else 1.0
		entry.alpha=move_toward(entry.alpha,target,delta*4.0)
		if entry.alpha>=0.999:
			# Restore the exact original resource, including its original shadow mode.
			entry.mesh.material_override=entry.original
			entry.mesh.cast_shadow=entry.shadow
		else:
			var color=entry.original.albedo_color
			color.a=entry.alpha
			entry.faded.albedo_color=color
			entry.mesh.material_override=entry.faded
			entry.mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _exit_tree():
	for entry in surfaces:
		if is_instance_valid(entry.mesh):
			entry.mesh.material_override=entry.original
			entry.mesh.cast_shadow=entry.shadow
