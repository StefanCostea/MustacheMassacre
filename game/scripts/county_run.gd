extends Node

const Layout=preload("res://scripts/county_layout.gd")
const RegionalEnemy=preload("res://scripts/county_enemy.gd")
const ROSTERS := {
	"tower":["fridge","repair","skillet","chili"], "sheriff":["boss","pigeon"],
	"kitchen":["cook","mustard","chili"], "freight":["mustard","fridge"],
	"wheel":["dodgem","puppet","puppet","dodgem"], "throne":["flushness","brush","brush"],
}
const PATROLS := {"badlands":"chili","grease":"mustard","funland":"puppet","palace":"brush"}
const COLORS := {"road":"ffe1ae","garage":"ffe1ae","badlands":"ffcf96","grease":"b8e2d9","funland":"ecc1d9","palace":"e7e2ff"}
var game:GameDirector
var world
var region:="road"
var active:=""
var completed:Dictionary={}
var patrols_seen:Dictionary={}
var patrol:EnemyActor
var group:Array[EnemyActor]=[]
var leader:EnemyActor
var cycle:=0.
var puff_time:=0.
var hazard_lane:=0
var last_stage:=-1
var switch_cooldown:=0.
var escort_index:=0
var escort_ambush:=false
var flood_diverted:=false
var map_open:=false
var tracked:=""
var nearby:=""
var hint:=""
var ambience:AudioStreamPlayer
var melody:AudioStream
var sound_region:=""
var encounter_age:=0.

func setup(director:GameDirector,terrain) -> void:
	game=director
	world=terrain
	world.powered="wheel" in Preferences.county_shortcuts
	for key in world.switches:world.switches[key].activated.connect(operate.bind(key))
	ambience=AudioStreamPlayer.new()
	ambience.bus="Music"
	add_child(ambience)
	if Sound.music:
		melody=Sound.music.stream
		Sound.music.stop()
	change_region(Layout.district(game.player.position))
	update_hint()

func stop_audio(return_to_title:bool) -> void:
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream=null
	if return_to_title and is_instance_valid(Sound.music) and melody:Sound.music.play()
	melody=null

func clamp_point(pos:Vector3) -> Vector3:
	pos.x=clampf(pos.x,-41.4,41.4)
	pos.z=clampf(pos.z,-42.4,20.4)
	return pos

func in_danger() -> bool:
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and game.player.position.distance_squared_to(enemy.position)<144.:return true
	return false

func change_region(id:String) -> void:
	region=id
	world.set_sky(id,Color(COLORS[id]))
	var sound_id:=id if id in ["grease","funland","palace"] else "badlands"
	if Sound.music and sound_id!=sound_region:
		sound_region=sound_id
		var clip:AudioStreamWAV=melody if sound_id=="badlands" else load("res://assets/county/%s.wav"%sound_id)
		clip.loop_mode=AudioStreamWAV.LOOP_FORWARD
		clip.loop_end=roundi(clip.get_length()*clip.mix_rate)
		ambience.stream=clip
		ambience.play()
	if id in Layout.PLACES:
		var info:Array=Layout.PLACES[id]
		game.ui.toast(info[1].to_upper(),"M  ·  County map",info[2])
	if is_instance_valid(patrol) and not patrol.dead:
		retire(patrol)
	patrol=null
	if not active.is_empty() or not id in PATROLS or patrols_seen.has(id):return
	var at:Vector3=Layout.PLACES[id][0]+Vector3(5.5,0,4.)
	patrol=spawn(PATROLS[id],at)
	patrols_seen[id]=true

func spawn(id:String,at:Vector3) -> EnemyActor:
	if id not in RegionalEnemy.PROFILES:return game.spawn_enemy(id,at)
	var enemy:=RegionalEnemy.new()
	game.actors.add_child(enemy)
	enemy.configure(game,id,at)
	game.enemies.append(enemy)
	return enemy

func retire(enemy:EnemyActor) -> void:
	if is_instance_valid(enemy):
		game.enemies.erase(enemy)
		enemy.collision_layer=0
		enemy.set_physics_process(false)
		enemy.queue_free()

func tick(delta:float) -> void:
	if not game.is_fighting():return
	var at:=game.player.position
	var here:=Layout.district(at)
	if here!=region:change_region(here)
	switch_cooldown=maxf(0,switch_cooldown-delta)
	if not active.is_empty():
		encounter_age+=delta
		var anchor:Vector3=world.truck.position if active=="freight" else Layout.POSTS[active][0]
		if anchor.distance_to(at)>20.:
			abandon()
		else:
			match active:
				"kitchen":tick_kitchen(delta)
				"freight":tick_freight(delta)
				"throne":tick_palace(delta)
			if active not in ["","freight","wheel"] and group_clear():finish_contract()
	update_hint()

func group_clear() -> bool:
	for enemy in group:
		if is_instance_valid(enemy) and not enemy.dead:return false
	return true

func begin(id:String) -> void:
	if active!="" or id in completed or id not in Layout.POSTS:return
	active=id
	cycle=0.
	last_stage=-1
	hazard_lane=0
	escort_index=0
	escort_ambush=false
	encounter_age=0.
	switch_cooldown=0.
	flood_diverted=false
	group.clear()
	var at:Vector3=Layout.POSTS[id][0]
	var offsets:=[Vector3(2.9,0,-2.4),Vector3(-3.4,0,-2.8),Vector3(4.7,0,.7),Vector3(-3.2,0,2.8)]
	for i in ROSTERS[id].size():
		var point:Vector3=at+offsets[i]
		if not world.point_clear(point):point=at+Vector3(i-1,0,3.6)
		group.append(spawn(ROSTERS[id][i],point))
	leader=group[0]
	if id=="tower":leader.health=leader.max_health*.62
	if id in ["sheriff","throne","kitchen"]:game.boss=leader
	Sound.play("warning",-8,.85)
	game.ui.toast(Layout.POSTS[id][1].to_upper(),Layout.POSTS[id][2],CombatEffects.GOLD)

func boss_title() -> String:
	match active:
		"throne":return "HIS ROYAL FLUSHNESS"
		"kitchen":return "HEAD FRY COOK"
	return "EL FRIGORÍFICO"

func update_hint() -> void:
	nearby=""
	var nearest:=2.65
	var p:=game.player.position
	if active!="":
		for key in Layout.SWITCHES:
			if {"latch":"tower","steam":"kitchen","breaker":"wheel","valve":"throne"}[key]!=active:continue
			var dist:=p.distance_to(Layout.SWITCHES[key][0])
			if dist<nearest:
				nearby=key
				hint="G  ·  "+str(Layout.SWITCHES[key][1])
				return
		match active:
			"tower":hint="Break the repair crew. Shoot the gate latch to drop the rail."
			"sheriff":hint="Dodge the ice stripe. Fire when the freezer door opens."
			"kitchen":hint="Dodge the glowing grates. Release steam at the red wheel."
			"freight":hint="Walk beside the wax truck. Clear its ambush at the fork."
			"wheel":hint="Shoot the wheel breaker." if group_clear() else "Bait the bumper cars into the ticket crew."
			"throne":hint="Use the flush valve while the cistern is filling."
		return
	if p.distance_to(Vector3(0,0,4.4))<2.1:
		nearby="workshop"
		hint="G  ·  Visit the Grooming Garage"
		return
	if p.distance_to(Layout.HUB)<2.55 and completed.size()>0:
		nearby="home"
		hint="G  ·  Finish this county run"
		return
	for key in Layout.POSTS:
		var d:=p.distance_to(Layout.POSTS[key][0])
		if d<nearest:
			hint="Bounty collected" if key in completed else "G  ·  "+str(Layout.POSTS[key][2])
			nearby="" if key in completed else key
			nearest=d
	if nearest<2.65:return
	hint="M  ·  County map"
	if region in Layout.PLACES and region!="garage":
		for key in Layout.POSTS:
			if Layout.POSTS[key][3]==region and key not in completed:
				hint="Find the gold marker at "+str(Layout.POSTS[key][1])
				break
	elif region=="garage":hint="West to the water tower  •  East to the diner  •  M for map"

func interact() -> void:
	if not game.is_fighting() or map_open:return
	update_hint()
	if nearby=="workshop":game.ui.show_garage()
	elif nearby=="home":game.finish_run(true)
	elif nearby in Layout.SWITCHES:operate(nearby)
	elif nearby in Layout.POSTS:begin(nearby)

func operate(key:String) -> void:
	if not game.is_fighting() or switch_cooldown>0:return
	if key=="latch" and active=="tower" and world.gate.visible:
		world.open_tower_gate()
		blast_group(Layout.SWITCHES[key][0],5.4,33,"falling_gate")
	elif key=="steam" and active=="kitchen":
		# Steam is piped below all three grates. The cook can be lured onto them.
		for v in world.vents:blast_group(v.position,3.5,37.,"steam")
		switch_cooldown=4.
	elif key=="breaker" and active=="wheel":
		if not group_clear():
			game.ui.toast("BREAKER GUARDED","Take out the ticket crew first.",CombatEffects.DANGER)
			return
		world.powered=true
		finish_contract()
	elif key=="valve" and active=="throne" and last_stage in [1,2] and not flood_diverted:
		flood_diverted=true
		world.water.hide()
		if is_instance_valid(leader) and not leader.dead:
			game.effects.tracer(Layout.SWITCHES[key][0]+Vector3.UP,leader.aim_center(),Color.SKY_BLUE,.22)
			leader.receive_hit(85,false,game.new_context("backflush"))
	else:return
	Sound.play("perfect",-6)
	game.effects.burst(Layout.SWITCHES[key][0]+Vector3.UP,CombatEffects.GOLD,10)

func blast_group(at:Vector3,radius:float,damage:float,source:String) -> void:
	game.effects.ring(at+Vector3.UP*.1,.4,Color("ffbd72"),.45,radius/.4-1,false)
	for enemy in group:
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(at)<radius:
			enemy.receive_hit(damage,false,game.new_context(source))

func tick_kitchen(delta:float) -> void:
	cycle+=delta
	var stage:=0 if cycle<2. else (1 if cycle<3.15 else 2)
	if stage!=last_stage:
		last_stage=stage
		world.vents[hazard_lane].material_override=world.brass if stage==1 else (MeshKit.material(Color("ff692d"),.46,.12,.8) if stage==2 else world.metal)
		if stage==1:
			var grate:Node3D=world.vents[hazard_lane]
			game.effects.warning_line(grate.position+Vector3.LEFT*4,grate.position+Vector3.RIGHT*4,1.15,.20)
	if stage==2:
		puff_time-=delta
		if puff_time<=0:
			puff_time=.22
			var nozzle:Vector3=world.vents[hazard_lane].position+Vector3(game.rng.randf_range(-3.6,3.6),.1,0)
			game.effects.burst(nozzle,Color("fbbb83"),5,.65)
		var tile:Vector3=world.vents[hazard_lane].position
		var pos:=game.player.position
		if absf(pos.x-tile.x)<4.1 and absf(pos.z-tile.z)<.62 and pos.y<.45:game.player.receive_hit(10)
	if cycle>4.:
		world.vents[hazard_lane].material_override=world.metal
		hazard_lane=(hazard_lane+1)%3
		cycle=0.

func tick_freight(delta:float) -> void:
	var route: Array[Vector3]=[Vector3(14,0,10.6),Vector3(7,0,10.6),Vector3(2.5,0,9)]
	if not escort_ambush and escort_index==1:
		escort_ambush=true
		group.append(spawn("mustard",Vector3(9,0,13.5)))
		game.ui.toast("FREIGHT AMBUSH","Clear the road for the driver.",CombatEffects.DANGER)
	if escort_ambush and not group_clear():return
	if game.player.position.distance_to(world.truck.position)>5.:return
	var next:Vector3=route[escort_index]
	var heading:Vector3=world.truck.position.direction_to(next)
	world.truck.rotation.y=lerp_angle(world.truck.rotation.y,atan2(heading.x,heading.z),minf(1.,delta*5.))
	world.truck.position=world.truck.position.move_toward(next,delta*2.2)
	if world.truck.position.is_equal_approx(next):
		escort_index+=1
		if escort_index==route.size():finish_contract()

func tick_palace(delta:float) -> void:
	if not is_instance_valid(leader) or leader.dead:
		world.water.hide()
		return
	if leader.health>leader.max_health*.72:return
	cycle+=delta
	var stage:=0 if cycle<2.4 else (1 if cycle<4.3 else 2)
	if stage!=last_stage:
		last_stage=stage
		if stage==1:
			flood_diverted=false
			game.ui.toast("CISTERN FILLING","Turn or shoot the red flush valve.",Color.SKY_BLUE)
			game.effects.warning_line(Vector3(16,.1,-28),Vector3(30,.1,-28),1.9,.12)
		world.water.visible=stage==2 and not flood_diverted
	if stage==2 and not flood_diverted:
		var pos:=game.player.position
		if absf(pos.x-23)<6.5 and absf(pos.z+28)<5 and pos.y<.45:
			game.player.knockback=Vector3(0,0,3.8)
			game.player.receive_hit(8)
	if cycle>6.2:cycle=0.

func reset_contract() -> void:
	game.boss=null
	world.water.hide()
	for v in world.vents:v.material_override=world.metal
	if is_instance_valid(game.freezer_lane):game.freezer_lane.queue_free()
	group.clear()
	leader=null
	active=""

func abandon() -> void:
	for enemy in group:retire(enemy)
	if active=="freight":
		world.truck.position=Vector3(21,0,10.6)
		world.truck.rotation.y=-PI/2
	reset_contract()
	game.ui.toast("BACK ON THE ROAD","Return to the marker to retry the job.",Color.WHEAT)

func finish_contract() -> void:
	var id:=active
	if id=="" or id in completed:return
	completed[id]=true
	if tracked==id:tracked=""
	reset_contract()
	if id in Layout.BRIDGES:
		world.open_bridge(id)
		if not id in Preferences.county_shortcuts:
			Preferences.county_shortcuts.append(id)
			if not Preferences.save():
				Preferences.county_shortcuts.erase(id)
				game.ui.toast("GARAGE SAVE UNAVAILABLE","Crossing open for this visit.",CombatEffects.DANGER)
	var pay:=12 if id in ["sheriff","throne","freight"] else 6
	game.award_wax(pay)
	game.player.health=minf(100,game.player.health+20.)
	game.ui.toast("BOUNTY COLLECTED","%s  ·  +%d wax"%[Layout.POSTS[id][1],pay],CombatEffects.GOLD)
	if id in ["tower","kitchen","wheel"]:game.show_upgrades()

func map_rect(screen:Vector2) -> Rect2:
	var width:=minf(screen.x*.79,(screen.y-175.)/.64)
	var size:=Vector2(width,width*.64)
	return Rect2((screen-size)*.5,size)

func map_point(pos:Vector3,rect:Rect2) -> Vector2:
	return rect.position+(Vector2(pos.x,pos.z)-Layout.BOUNDS.position)/Layout.BOUNDS.size*rect.size

func mark_job(click:Vector2,screen:Vector2) -> void:
	var rect:=map_rect(screen)
	var nearest:=38.
	var selected:=""
	for id in Layout.POSTS:
		if id in completed:continue
		var dist:=map_point(Layout.POSTS[id][0],rect).distance_to(click)
		if dist<nearest:
			nearest=dist
			selected=id
	if selected!="":
		tracked="" if tracked==selected else selected
		Sound.play("ui",-9)

func paint_bearing(c:Control,ui,screen:Vector2) -> void:
	if tracked=="" or tracked==active:return
	var target:Vector3=Layout.POSTS[tracked][0]
	var camera:=get_viewport().get_camera_3d()
	var dir:Vector2=(camera.unproject_position(target)-camera.unproject_position(game.player.position)).normalized()
	var pt:=Vector2(screen.x-289,screen.y-99)
	c.draw_style_box(ui.panel_style,Rect2(pt-Vector2(25,27),Vector2(286,57)))
	c.draw_colored_polygon(PackedVector2Array([pt+dir*12,pt-dir*8+dir.orthogonal()*6,pt-dir*8-dir.orthogonal()*6]),ui.GOLD)
	ui.text(c,"%s   %d m"%[Layout.POSTS[tracked][1],roundi(target.distance_to(game.player.position))],pt+Vector2(20,6),16,ui.CREAM)

func paint_map(c:Control,ui,screen:Vector2) -> void:
	var rect:=map_rect(screen)
	var map_size:=rect.size
	var origin:=rect.position
	var w:=map_size.x
	c.draw_rect(Rect2(Vector2.ZERO,screen),Color(.044,.037,.036,.84))
	c.draw_style_box(ui.panel_style,Rect2(origin-Vector2(24,57),map_size+Vector2(48,115)))
	ui.text(c,"COUNTY ROAD MAP",origin+Vector2(0,-20),26,ui.GOLD,true)
	ui.text(c,"NORTH  ↑       M   CLOSE",origin+Vector2(w-220,-22),15,ui.CREAM,false,HORIZONTAL_ALIGNMENT_RIGHT,220)
	c.draw_rect(Rect2(origin,map_size),Color("433d34"))
	var point:=func(p:Vector3) -> Vector2:
		return map_point(p,rect)
	var road:=Color("a18765")
	for coords:Array in [[-30,8,27,8],[-30,8,-30,-26],[27,8,27,-26],[-30,-26,27,-26]]:
		c.draw_line(point.call(Vector3(coords[0],0,coords[1])),point.call(Vector3(coords[2],0,coords[3])),road,5,true)
	c.draw_line(point.call(Vector3(-25,0,-10)),point.call(Vector3(23,0,-10)),Color("528889"),8,true)
	for key in Layout.BRIDGES:
		var x:float=Layout.BRIDGES[key]
		var open:bool=not world.bridges.has(key)
		c.draw_line(point.call(Vector3(x,0,8)),point.call(Vector3(x,0,-26)),road if open else Color("6a5b4b"),3,true)
		var crossing:Vector2=point.call(Vector3(x,0,-10))
		c.draw_circle(crossing,6,Color("a3d498") if open else Color("ec9b74"))
	for id in Layout.PLACES:
		var info:Array=Layout.PLACES[id]
		var location:Vector2=point.call(info[0])
		c.draw_circle(location,8,info[2])
		ui.text(c,info[1],location+Vector2(-150,-28),22,info[2],true,HORIZONTAL_ALIGNMENT_CENTER,300)
	for id in Layout.POSTS:
		var at:Vector2=point.call(Layout.POSTS[id][0])
		c.draw_arc(at,7,0,TAU,16,Color("85bf8f") if id in completed else Color("ebcc8f"),2,true)
		if id==tracked:c.draw_arc(at,13,0,TAU,24,ui.GOLD,3.,true)
		ui.text(c,Layout.POSTS[id][1],at+Vector2(12,19),16,ui.CREAM)
	var here:Vector2=point.call(game.player.position)
	c.draw_circle(here,7,Color.WHITE)
	c.draw_arc(here,11,0,TAU,24,Color.WHITE,1.4,true)
	ui.text(c,"Click a gold job ring to track it.       White dot   You       Green ring   Complete       Coral   Closed crossing",origin+Vector2(0,map_size.y+32),14,ui.CREAM)
