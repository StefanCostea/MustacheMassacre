extends CanvasLayer

class Paint extends Control:
	var hud
	func _draw() -> void:
		if hud:hud.paint(self)

const INK := Color("211e19")
const CREAM := Color("f3dfb5")
const MUTED := Color("b9aa8b")
const GOLD := Color("eab865")
var game
var canvas: Paint
var host: Control
var title_font: Font
var body_font: Font
var panel_style: StyleBoxFlat
var toast_title: String = ""
var toast_subtitle: String = ""
var toast_color: Color = GOLD
var toast_timer: float = 0.0
var damage_flash: float = 0.0
var panel_kind: String = ""

func setup(director) -> void:
	game=director;process_mode=Node.PROCESS_MODE_ALWAYS;layer=10
	# Resolve fonts on the main thread after import. Preloading them while the
	# editor scans scripts races the threaded font importer on a clean checkout.
	title_font=load("res://assets/fonts/WesternSerif.ttf")
	body_font=load("res://assets/fonts/Interface.ttf")
	canvas=Paint.new();canvas.hud=self;canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(canvas)
	host=Control.new();host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(host)
	panel_style=_style(Color(.10,.09,.075,.89),Color(.55,.40,.22,.7),1,6)

func _style(background: Color, border: Color, width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=background;s.border_color=border
	s.set_border_width_all(width);s.set_corner_radius_all(radius)
	s.content_margin_left=24;s.content_margin_right=24;s.content_margin_top=20;s.content_margin_bottom=20
	return s

func _process(delta: float) -> void:
	toast_timer=maxf(0,toast_timer-delta);damage_flash=maxf(0,damage_flash-delta)
	canvas.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game.county and game.county.map_open and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		game.county.mark_job(event.position,get_viewport().get_visible_rect().size)
		get_viewport().set_input_as_handled()
		return
	if game.county and game.county.map_open and (event.is_action_pressed("county_map") or event.is_action_pressed("pause")):
		game.county.map_open=false
		Input.mouse_mode=Input.MOUSE_MODE_CONFINED_HIDDEN
		game.player.input_lock=.18
		get_tree().paused=false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and get_tree().paused:
		if panel_kind=="pause":toggle_pause()
		elif panel_kind in ["loadout","garage"]:leave_loadout()
		get_viewport().set_input_as_handled()

func text(c: Control, value: String, pos: Vector2, size: int, color: Color = CREAM, title: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	c.draw_string_outline(title_font if title else body_font,pos,value,align,width,size,2,Color(.06,.045,.03,color.a*.8))
	c.draw_string(title_font if title else body_font,pos,value,align,width,size,color)

func paint(c: Control) -> void:
	if not is_instance_valid(game.player) or panel_kind in ["loadout","garage"]:return
	var p=game.player
	var screen:=get_viewport().get_visible_rect().size
	var w:=screen.x;var h:=screen.y
	var cut:float=maxf(p.form.camera_weight,p.lance.camera_weight)
	if cut>.52 and panel_kind.is_empty():
		var bar: float=screen.y*.064*cut
		c.draw_rect(Rect2(0,0,w,bar),INK)
		c.draw_rect(Rect2(0,h-bar,w,bar),INK)
		text(c,"SAGUARO LANCE" if p.lance.running else "HIGH NOON",Vector2(0,h-bar*.31),22,GOLD,true,HORIZONTAL_ALIGNMENT_CENTER,w)
		return
	var displayed := get_viewport().get_camera_3d()
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.dummy or enemy.kind=="boss":continue
		var world:Vector3=enemy.global_position+Vector3.UP*1.85
		if displayed.is_position_behind(world):continue
		var pos:Vector2=displayed.unproject_position(world)
		if enemy.health<enemy.max_health:
			c.draw_rect(Rect2(pos-Vector2(23,0),Vector2(46,5)),Color(.10,.08,.065,.80))
			c.draw_rect(Rect2(pos-Vector2(22,-1),Vector2(44*maxf(0,enemy.health)/enemy.max_health,3)),Color("d29b71"))
		if not Rect2(40,160,w-80,h-370).has_point(pos) and game.is_fighting():
			var direction:Vector2=(pos-screen*.5).normalized()
			var edge:Vector2=pos.clamp(Vector2(40,160),Vector2(w-40,h-210))
			c.draw_colored_polygon(PackedVector2Array([edge+direction*8,edge-direction*6+direction.orthogonal()*5,edge-direction*6-direction.orthogonal()*5]),CombatEffects.DANGER)
	if damage_flash>0:c.draw_rect(Rect2(Vector2.ZERO,screen),Color(.65,.08,.12,damage_flash*.40))
	c.draw_style_box(panel_style,Rect2(28,26,320,133))
	text(c,"GENERAL COO" if p.is_coo else "DON ESPINO",Vector2(49,58),23,CREAM,true)
	text(c,"BREADCRUMB COMMAND" if p.is_coo else "THE FURIOUS GUNSLINGER",Vector2(49,78),10,MUTED)
	c.draw_rect(Rect2(49,94,244,10),Color("42382c"))
	c.draw_rect(Rect2(49,94,244*maxf(0,p.health)/100,10),Color("b86650") if p.health<30 else Color("a9b579"))
	text(c,str(ceili(p.health)),Vector2(302,105),16,CREAM)
	if p.is_coo:
		var heat:float=p.coo.heat
		c.draw_rect(Rect2(49,124,169,15),Color("43392f"))
		if p.coo.vent_left>0:
			var max_time:float=p.coo.VENT
			var cursor:float=49.+169.*(1.-p.coo.vent_left/max_time)
			c.draw_rect(Rect2(49.+169.*(1.-.68/max_time),124,169.*.30/max_time,15),Color("84af79"))
			c.draw_line(Vector2(cursor,121),Vector2(cursor,142),CREAM,3)
		else:
			c.draw_rect(Rect2(49,124,169*heat,15),Color("dc7745") if heat>.72 else GOLD)
	for i in range(0 if p.is_coo else 6):
		var x:=50+i*29
		if p.form.running or p.lance.running:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x,143),Vector2(x+5,121),Vector2(x+10,143)]),GOLD)
			continue
		var color:=GOLD if i<p.ammo else Color("4a4032")
		c.draw_rect(Rect2(x,124,12,18),color)
		c.draw_circle(Vector2(x+6,124),6,color)
		c.draw_line(Vector2(x-1,143),Vector2(x+13,143),color,2)
	text(c,("TAP R IN GREEN" if p.coo.vent_left>0 else "HEAT %d%%"%int(p.coo.heat*100)) if p.is_coo else "LANCE" if p.lance.running else "THORN ARM" if p.form.running else "CRITICAL" if p.empowered else "SIX-SHOOTER",Vector2(237,139),11,GOLD if p.empowered else MUTED)
	text(c,"MUSTACHE MASSACRE",Vector2(w-410,49),20,CREAM,true,HORIZONTAL_ALIGNMENT_RIGHT,380)
	text(c,"COUNTY BOUNTIES  ·  %d / 6"%game.county.completed.size() if game.county else ("GREASE CITY  /  DRIVE-THRU DISTRICT" if game.route.stage else "LAST CALL  /  THE CRISPY BADLANDS"),Vector2(w-410,70),11,GOLD,false,HORIZONTAL_ALIGNMENT_RIGHT,380)
	text(c,"%02d:%02d"%[int(game.run_time)/60,int(game.run_time)%60],Vector2(w-180,106),26,CREAM,true,HORIZONTAL_ALIGNMENT_RIGHT,150)
	text(c,"M   MAP     G   USE     ESC   PAUSE" if game.county else "ESC  PAUSE",Vector2(w-285,131),11,MUTED,false,HORIZONTAL_ALIGNMENT_RIGHT,255)
	var wave_name:="THE STREET IS QUIET" if game.wave==0 else ("THE SHOWDOWN" if game.wave==4 else "WAVE %02d"%game.wave)
	if game.route.stage:wave_name=game.route.title()
	if game.county:
		c.draw_style_box(panel_style,Rect2(w*.5-300,17,600,67))
		var place:Array=game.county.Layout.PLACES.get(game.county.region,[Vector3.ZERO,"County Road"])
		wave_name=str(place[1]).to_upper()
	text(c,wave_name,Vector2(w*.5-180,49),20,GOLD,true,HORIZONTAL_ALIGNMENT_CENTER,360)
	if game.county:
		text(c,game.county.hint,Vector2(w*.5-350,75),14,CREAM,false,HORIZONTAL_ALIGNMENT_CENTER,700)
	elif game.is_fighting():text(c,"%d OUTLAWS LEFT  ·  %d TAKEN DOWN"%[game.live_count()+game.spawn_queue.size(),game.kills],Vector2(w*.5-210,72),11,MUTED,false,HORIZONTAL_ALIGNMENT_CENTER,420)
	if is_instance_valid(game.boss) and not game.boss.dead:
		c.draw_style_box(panel_style,Rect2(w*.5-270,91,540,52))
		text(c,game.county.boss_title() if game.county else "EL FRIGORÍFICO",Vector2(w*.5-240,111),12,CREAM,true)
		c.draw_rect(Rect2(w*.5-240,122,480,7),Color("49302c"))
		c.draw_rect(Rect2(w*.5-240,122,480*maxf(0,game.boss.health)/game.boss.max_health,7),Color("d0757c"))
	var center:=w*.5
	_ability(c,Rect2(center-310,h-129,160,78),"Q","RICOCHET",p.q_cooldown,game.config.ricochet_cooldown,p.ricochet_armed)
	_ability(c,Rect2(center-140,h-129,160,78),"E","EGG DROP" if p.is_coo else "SLAPSTACHE" if p.field_skill=="slap" else "TUMBLEWEED",p.e_cooldown,game.config.vortex_cooldown,false)
	_ability(c,Rect2(center+30,h-129,240,78),"F","COO-BOMBING" if p.is_coo else CombatConfig.SPECIALS[p.equipped_special].name.to_upper(),0 if p.stache>=100 else 1,1,p.frenzy_left>0 or p.lance.running)
	c.draw_style_box(panel_style,Rect2(center-310,h-181,580,42))
	text(c,"STACHE",Vector2(center-296,h-155),11,GOLD,true)
	c.draw_rect(Rect2(center-224,h-166,420,9),Color("493d2c"))
	var meter:float=(1-p.lance.age/p.SaguaroLance.DURATION) if p.lance.running else (p.frenzy_left/6.0 if p.frenzy_left>0 else p.stache/100.0)
	c.draw_rect(Rect2(center-224,h-166,420*meter,9),GOLD)
	text(c,"LANCE" if p.lance.running else "FRENZY" if p.frenzy_left>0 else "%d%%"%int(p.stache),Vector2(center+209,h-155),10,GOLD)
	if p.stache>=100:c.draw_rect(Rect2(center-226,h-168,424,13),Color(1,.8,.3,.45+.3*sin(Time.get_ticks_msec()*.006)),false,2)
	if p.reload_elapsed>=0:
		var rect:=Rect2(center-180,h-236,360,35)
		c.draw_style_box(panel_style,rect)
		c.draw_rect(Rect2(rect.position+Vector2(13,13),Vector2(334,9)),Color("66523a"))
		var start:float=game.config.perfect_start/game.config.reload_seconds
		var end:float=game.config.perfect_end/game.config.reload_seconds
		c.draw_rect(Rect2(rect.position+Vector2(13+334*start,13),Vector2(334*(end-start),9)),Color("accb7e"))
		var x:float=rect.position.x+13+334*p.reload_elapsed/game.config.reload_seconds
		c.draw_line(Vector2(x,rect.position.y+6),Vector2(x,rect.position.y+29),CREAM,3)
		text(c,"R  ·  HIT THE GREEN WINDOW",Vector2(center-180,h-242),11,CREAM,false,HORIZONTAL_ALIGNMENT_CENTER,360)
	text(c,"AUTOPLAY    ESC PAUSE" if game.automation else "LMB ROTARY    RMB BURST    SPACE HOP    R VENT" if p.is_coo else "WASD MOVE    LMB SHOOT    RMB FAN    SPACE DASH    R RELOAD",Vector2(30,h-28),12,MUTED)
	text(c,"%d KILLS"%game.kills,Vector2(w-190,h-29),16,CREAM,true,HORIZONTAL_ALIGNMENT_RIGHT,160)
	if p.upgrades.size()>0:
		var names:PackedStringArray=[]
		for key in p.upgrades:names.append(CombatConfig.UPGRADES[key].name)
		text(c," + ".join(names),Vector2(30,h-54),10,GOLD)
	if toast_timer>0:
		var y:=169.0 if not is_instance_valid(game.boss) else 166.0
		var alpha:=minf(1,toast_timer)
		c.draw_style_box(panel_style,Rect2(center-360,y-7,720,65))
		text(c,toast_title,Vector2(center-400,y+20),28,Color(toast_color,alpha),true,HORIZONTAL_ALIGNMENT_CENTER,800)
		text(c,toast_subtitle,Vector2(center-400,y+45),12,Color(CREAM,alpha),false,HORIZONTAL_ALIGNMENT_CENTER,800)
	if panel_kind.is_empty() and not p.dead:
		var mouse:=displayed.unproject_position(p.aim_point) if game.automation else get_viewport().get_mouse_position()
		var color:=GOLD if p.ricochet_armed else CREAM
		c.draw_arc(mouse,7,0,TAU,24,Color(INK,.8),3)
		for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:c.draw_line(mouse+d*10,mouse+d*16,color,2)
		c.draw_circle(mouse,1.5,color)

	if game.county and panel_kind.is_empty():
		if game.county.map_open:game.county.paint_map(c,self,screen)
		else:game.county.paint_bearing(c,self,screen)

func _ability(c: Control, rect: Rect2, key: String, name: String, left: float, total: float, active: bool) -> void:
	c.draw_style_box(panel_style,rect)
	var color:=GOLD if left<=0 or active else MUTED.darkened(.3)
	c.draw_rect(Rect2(rect.position+Vector2(13,13),Vector2(25,25)),color,false,1.5)
	text(c,key,rect.position+Vector2(20,32),15,color,true)
	text(c,name,rect.position+Vector2(48,29),11,color,true)
	var state := "READY"
	if active:
		state = "FRENZY" if key=="F" else "ARMED"
		if key=="F" and game.player.lance.running:state=game.player.lance.phase_name()
	elif left>0:
		state = "CHARGE STACHE" if key=="F" else "%.1fs"%left
	text(c,state,rect.position+Vector2(48,48),10,color)
	c.draw_rect(Rect2(rect.position+Vector2(13,63),Vector2(rect.size.x-26,3)),Color("4b4031"))
	c.draw_rect(Rect2(rect.position+Vector2(13,63),Vector2((rect.size.x-26)*(1-clampf(left/total,0,1)),3)),color)

func toast(title: String, subtitle: String, color: Color = GOLD) -> void:
	toast_title=title;toast_subtitle=subtitle;toast_color=color;toast_timer=3.0

func close_panel() -> void:
	for child in host.get_children():child.queue_free()
	panel_kind=""
	# Keep absolute aiming coordinates while preventing an invisible cursor from
	# escaping the window and taking the crosshair outside its drawable area.
	Input.mouse_mode=Input.MOUSE_MODE_CONFINED_HIDDEN

func _overlay() -> void:
	close_panel();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var dim:=ColorRect.new();dim.color=Color(.025,.022,.019,.76);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.add_child(dim)

func _label(value: String, size: int = 18, title: bool = false, color: Color = CREAM) -> Label:
	var label:=Label.new();label.text=value;label.add_theme_font_override("font",title_font if title else body_font)
	label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	return label

func _button(value: String, callable: Callable, primary: bool = false) -> Button:
	var button:=Button.new();button.text=value;button.custom_minimum_size=Vector2(0,52)
	button.add_theme_font_override("font",title_font);button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color",INK if primary else CREAM)
	button.add_theme_color_override("font_pressed_color",CREAM)
	button.add_theme_stylebox_override("normal",_style(GOLD if primary else Color("2c281f"),GOLD,1,4))
	button.add_theme_stylebox_override("hover",_style(Color("f2cd8a") if primary else Color("51422e"),CREAM,2,4))
	button.add_theme_stylebox_override("pressed",_style(Color("8f6a36"),GOLD,1,4))
	button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),CREAM,2,4))
	button.pressed.connect(func():Sound.play("ui",-8);callable.call())
	return button

func _center_panel(width: float, height: float) -> VBoxContainer:
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",_style(Color("211e19"),Color("8d6b3f"),2,8))
	panel.anchor_left=.5;panel.anchor_right=.5;panel.anchor_top=.5;panel.anchor_bottom=.5
	panel.offset_left=-width/2;panel.offset_right=width/2;panel.offset_top=-height/2;panel.offset_bottom=height/2
	host.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",18);panel.add_child(box)
	return box

func show_arrival() -> void:
	close_panel();panel_kind="arrival";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",_style(Color(.12,.10,.075,.96),Color("ad8452"),1,8))
	panel.anchor_left=1;panel.anchor_right=1;panel.anchor_top=.5;panel.anchor_bottom=.5
	panel.offset_left=-490;panel.offset_right=-45;panel.offset_top=-399;panel.offset_bottom=399;host.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",11);panel.add_child(box)
	box.add_child(_label("MUSTACHE COUNTY",12,false,GOLD))
	box.add_child(_label("LAST CALL",46,true))
	box.add_child(_label("Guns. Guts. Glorious facial hair.",14,false,MUTED))
	box.add_child(HSeparator.new())
	box.add_child(_label("Try the practice target, then choose a route.",15))
	box.add_child(_label("LMB  Rotary     RMB  Burst     R  Vent\nSPACE  Aerial hop     Q  Ricochet     E  Egg drop\nF  Carpet Coo-bombing at full Stache" if game.player.is_coo else "WASD  Move     LMB  Shoot     RMB  Fan\nSPACE  Dash     R  Active reload\nQ  Ricochet     E  %s\nF  %s at full Stache"%[CombatConfig.FIELD_SKILLS[game.player.field_skill],CombatConfig.SPECIALS[game.player.equipped_special].name],15,false,MUTED))
	box.add_child(_button("GROOMING GARAGE",show_garage))
	box.add_child(_button("WATCH BOTH SPECIALS",game.watch_specials))
	box.add_child(_button("CHARACTERS & LOADOUT",show_loadout))
	if not game.playtest.active:
		var explore:=_button("EXPLORE THE COUNTY",game.start_county,true)
		box.add_child(explore)
		explore.grab_focus()
	var start:=_button("RING THE BELL",game.start_run,game.playtest.active)
	box.add_child(start)
	if game.playtest.active:start.grab_focus()
	box.add_child(_label("Explore four regions, or ring the bell for the arena run.",12,false,GOLD))

func show_loadout() -> void:
	if game.state!=GameDirector.RunState.ARRIVAL:return
	_overlay()
	panel_kind="loadout"
	get_tree().paused=true
	var box:=_center_panel(1100,940)
	box.add_theme_constant_override("separation",16)
	var crew:=HBoxContainer.new()
	box.add_child(crew)
	for id:String in ["espino","coo"]:
		var button:=_button("Don Espino" if id=="espino" else "General Coo",func():select_hero(id))
		button.name="pilot_"+id
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.disabled=game.player.is_coo==(id=="coo")
		crew.add_child(button)
	if game.player.is_coo:
		show_coo_loadout(box)
		return
	box.add_child(_label("Equip your specials",40,true))
	box.add_child(_label("F  ·  Ultimate at full Stache. Kills, close dodges and perfect reloads build charge.",18,false,MUTED))
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	box.add_child(row)
	var group:=ButtonGroup.new()
	var selected:Button
	for key: String in CombatConfig.SPECIALS:
		var card:=special_card(key,group)
		row.add_child(card)
		if card.button_pressed:selected=card
	box.add_child(_label("E  ·  Field ability",20,true))
	var skills:=HBoxContainer.new()
	box.add_child(skills)
	var field_group:=ButtonGroup.new()
	for id: String in CombatConfig.FIELD_SKILLS:
		var label:String=CombatConfig.FIELD_SKILLS[id]
		var button:=_button(label,func():
			Preferences.field_skill=id
			game.player.field_skill=id
			Preferences.save())
		button.name=id
		button.toggle_mode=true
		button.button_group=field_group
		button.button_pressed=game.player.field_skill==id
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		skills.add_child(button)
	box.add_child(_label("Tumbleweed gathers a crowd. Slapstache erupts at your aim and bats one outlaw into another.",16,false,MUTED))
	var back:=_button("BACK TO MAIN MENU",leave_loadout)
	box.add_child(back)
	selected.grab_focus()

func select_hero(id: String) -> void:
	if game.state!=GameDirector.RunState.ARRIVAL:return
	Preferences.hero_id=id
	Preferences.save()
	game.player.equip_hero(id)
	show_loadout()

func show_coo_loadout(box: VBoxContainer) -> void:
	box.add_child(_label("General Coo",37,true))
	var portrait:=TextureRect.new()
	portrait.texture=load("res://assets/ui/loadout/general_coo.webp")
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size.y=395
	box.add_child(portrait)
	box.add_child(_label("BREADCRUMB COMMAND",14,false,GOLD))
	box.add_child(_label("Hold fire to spin up. Vent before overheating. Tap R again midway for a critical round.",17))
	box.add_child(_label("SPACE  ·  Aerial hop      Q  ·  Ricochet burst      E  ·  Egg drop",17))
	box.add_child(_label("F  ·  Carpet Coo-bombing. Steer the squadron’s egg drops with your aim.",17))
	var back:=_button("BACK TO THE COUNTY" if game.county else "BACK TO MAIN MENU",leave_loadout,true)
	box.add_child(back)
	back.grab_focus()

func special_card(key: String, group: ButtonGroup) -> Button:
	var spec:Dictionary=CombatConfig.SPECIALS[key]
	var card:=Button.new()
	card.name=key
	card.accessibility_name=spec.name
	card.accessibility_description=spec.description
	card.toggle_mode=true
	card.button_group=group
	card.button_pressed=key==game.player.equipped_special
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.custom_minimum_size=Vector2(0,426)
	card.add_theme_stylebox_override("normal",_style(Color("2e281f"),Color("806b4e"),1,4))
	card.add_theme_stylebox_override("hover",_style(Color("383026"),CREAM,2,4))
	card.add_theme_stylebox_override("pressed",_style(Color("3d3324"),GOLD,3,4))
	card.add_theme_stylebox_override("hover_pressed",card.get_theme_stylebox("pressed"))
	var focus:=StyleBoxFlat.new()
	focus.draw_center=false
	focus.border_color=CREAM
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(4)
	card.add_theme_stylebox_override("focus",focus)
	var body:=VBoxContainer.new()
	card.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left=14;body.offset_right=-14;body.offset_top=14;body.offset_bottom=-14
	body.add_theme_constant_override("separation",12)
	body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var art:=TextureRect.new()
	art.texture=load("res://assets/ui/loadout/%s.webp"%key)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size.y=213
	body.add_child(art)
	var title:=_label(spec.name,32,true)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	body.add_child(title)
	var desc:=_label(spec.description,18)
	desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	desc.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(desc)
	var status:=_label("EQUIPPED" if card.button_pressed else "EQUIP",15,true,GOLD)
	body.add_child(status)
	for child in body.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.toggled.connect(func(enabled: bool):
		status.text="EQUIPPED" if enabled else "EQUIP"
		if enabled:
			game.player.equipped_special=key
			Preferences.special=key
			Preferences.save()
			Sound.play("ui",-6))
	return card

func leave_loadout() -> void:
	if panel_kind not in ["loadout","garage"]:return
	get_tree().paused=false
	game.player.input_lock=.25
	if game.county:close_panel()
	else:show_arrival()

func show_garage() -> void:
	if not game.county and game.state!=GameDirector.RunState.ARRIVAL:return
	_overlay()
	panel_kind="garage"
	get_tree().paused=true
	var box:=_center_panel(1080,760)
	box.add_child(_label("The Grooming Garage",39,true))
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	box.add_child(row)
	var portrait:=TextureRect.new()
	portrait.texture=load("res://assets/ui/garage/barber.webp")
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size=Vector2(375,465)
	row.add_child(portrait)
	var shelf:=VBoxContainer.new()
	shelf.add_theme_constant_override("separation",12)
	shelf.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(shelf)
	shelf.add_child(_label("%d MOUSTACHE WAX"%Preferences.wax,23,true,GOLD))
	var help:=_label("County jobs pay 6 or 12 wax. Workshop unlocks join the upgrade pool." if game.county else "Clear a wave for 6 wax. At the end of a run, earn 1 per 6 kills and a 12-wax bounty for the sheriff.",17,false,MUTED)
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	shelf.add_child(help)
	for key: String in CombatConfig.WORKSHOP:
		var spec:Dictionary=CombatConfig.UPGRADES[key]
		var cost:int=CombatConfig.WORKSHOP[key]
		shelf.add_child(HSeparator.new())
		shelf.add_child(_label(spec.name,21,true))
		var desc:=_label(spec.description,16)
		desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		shelf.add_child(desc)
		var owned:=key in Preferences.workshop
		var buy:=_button("IN UPGRADE POOL" if owned else "UNLOCK  ·  %d WAX"%cost,func():
			if Preferences.buy_upgrade(key):show_garage())
		buy.name=key
		buy.disabled=owned or Preferences.wax<cost
		shelf.add_child(buy)
	var back:=_button("BACK TO THE COUNTY" if game.county else "BACK TO MAIN MENU",leave_loadout,true)
	box.add_child(back)
	back.grab_focus()

func toggle_pause() -> void:
	if panel_kind in ["playtest","playtest_finished"]:return
	if panel_kind=="pause":
		close_panel();get_tree().paused=false;game.player.input_lock=.20;Preferences.save()
		if game.state==GameDirector.RunState.ARRIVAL:show_arrival()
		return
	if game.state in [GameDirector.RunState.UPGRADE,GameDirector.RunState.DEAD,GameDirector.RunState.VICTORY]:return
	_overlay();panel_kind="pause";get_tree().paused=true
	var box:=_center_panel(570,650)
	box.add_child(_label("TAKE A BREATHER",30,true))
	box.add_child(_label("Even legends need a moment.",15,false,MUTED))
	box.add_child(_button("BACK TO THE COUNTY" if game.county else "BACK TO THE BADLANDS",toggle_pause,true))
	for entry in [["MASTER VOLUME",Preferences.volume,"volume"],["MUSIC",Preferences.music_volume,"music_volume"],["SCREEN SHAKE",Preferences.shake_strength,"shake_strength"]]:
		box.add_child(_label(entry[0],12,false,GOLD))
		var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=entry[1]
		var property:String=entry[2]
		slider.value_changed.connect(func(value):Preferences.set(property,value);Preferences.apply())
		box.add_child(slider)
	box.add_child(_label("Q  Ricochet   /   E  Egg Drop   /   F  Carpet Coo-Bombing\nHold LMB to spin up. Tap R in the green to vent." if game.player.is_coo else "Q  Ricochet   /   E  %s   /   F  %s\nRMB fans the remaining chambers. Time R for a critical cylinder."%[CombatConfig.FIELD_SKILLS[game.player.field_skill],CombatConfig.SPECIALS[game.player.equipped_special].name],13,false,MUTED))
	box.add_child(_button("RESTART RUN",game.restart))
	box.add_child(_button("QUIT",func():Preferences.save();game.quit_application()))

func show_upgrades(keys: Array[String]) -> void:
	_overlay();panel_kind="upgrade"
	var box:=_center_panel(1210,480)
	box.add_child(_label("MAKE IT PERSONAL",33,true))
	box.add_child(_label("Choose one upgrade. Your build lasts for this run.",15,false,MUTED))
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",20);box.add_child(row)
	for key in keys:
		var item:Dictionary=CombatConfig.UPGRADES[key]
		var button:=_button("",func():game.choose_upgrade(key))
		button.custom_minimum_size=Vector2(365,290);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(button)
		var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,22)
		margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(margin)
		var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_theme_constant_override("separation",26);margin.add_child(content)
		content.add_child(_label(item.tag,11,false,GOLD))
		var title:=_label(item.name,24,true);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(title)
		var copy:String=item.description
		if game.player.is_coo:
			copy={"last_word":"Rounds above 78% heat are critical.","aftershock":"Egg Drop releases a second egg.","trigger":"Your rotary cannon cycles 25% faster.","bounce":"Each rotary round ricochets once.","explosive":"Every fifth rotary round explodes."}.get(key,copy)
		var desc:=_label(copy,15,false,MUTED);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;content.add_child(desc)
		content.add_child(_label("TAKE THIS UPGRADE",12,false,GOLD))
		for child in content.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE

func show_results(won: bool) -> void:
	_overlay();panel_kind="results"
	if game.playtest.results_pending:
		show_playtest_form()
		return
	var box:=_center_panel(770,690)
	box.add_child(_label("MUSTACHE COUNTY" if game.county else ("GREASE CITY" if game.route.stage else "THE CRISPY BADLANDS"),12,false,GOLD))
	box.add_child(_label("THE STREET IS YOURS" if won else "ONE BAD HAIR DAY",33,true))
	box.add_child(_label(("%d of 6 bounties collected."%game.county.completed.size() if game.county else "The drive-thru is clear. Take the spoils." if game.route.stage else "The sheriff is finished. The moustache remains.") if won else "Dust yourself off. The moustache is still magnificent.",14,false,MUTED))
	box.add_child(HSeparator.new())
	box.add_child(_label("%02d:%02d  TIME       %d  KILLS       %d  BEST CHAIN"%[int(game.run_time)/60,int(game.run_time)%60,game.kills,game.highest_chain],19,true))
	var upgrades:=PackedStringArray()
	for key in game.player.upgrades:upgrades.append(CombatConfig.UPGRADES[key].name)
	box.add_child(_label(" + ".join(upgrades) if upgrades.size()>0 else "Every run starts with six bullets and a bad attitude.",12,false,GOLD))
	if not game.automation:
		box.add_child(_label("+%d MOUSTACHE WAX   ·   %d IN THE GARAGE"%[game.wax_earned,Preferences.wax],16,true,GOLD))
	if game.highest_chain>1:box.add_child(_label(game.best_play,15,false,MUTED))
	if won and not game.route.stage and not game.county:box.add_child(_button("TRAVEL TO GREASE CITY",show_routes,true))
	box.add_child(_button("ANOTHER ROUND",game.restart,true))
	box.add_child(_button("QUIT",func():Preferences.save();game.quit_application()))

func show_routes() -> void:
	if game.state!=GameDirector.RunState.VICTORY or game.route.stage:return
	_overlay()
	panel_kind="routes"
	var box:=_center_panel(850,530)
	box.add_child(_label("GREASE CITY",38,true))
	box.add_child(_label("Your loadout and upgrades travel with you.",18,false,MUTED))
	var safe:=_button("WAX FREIGHT   ·   12 WAX",func():game.route.enter("freight"),true)
	box.add_child(safe)
	box.add_child(_label("Break through the delivery crew and collect the freight bounty.",16))
	box.add_child(_button("THE FRY LINE   ·   BONUS UPGRADE",func():game.route.enter("fry_line")))
	box.add_child(_label("Defeat the armored Head Fry Cook. Dodge the hot grease.",16))
	box.add_child(_button("BACK TO RESULTS",func():show_results(true)))
	safe.grab_focus()

func show_playtest_form() -> void:
	_overlay()
	panel_kind="playtest"
	get_tree().paused=true
	var first:bool=game.playtest.data.runs.is_empty()
	var box:=_center_panel(900,640)
	box.add_child(_label("Run %d of 2 complete"%[1 if first else 2],34,true))
	box.add_child(_label("What do you think caused your biggest hit?",20))
	var cause:=LineEdit.new()
	cause.placeholder_text="Your observation, or “unsure”"
	cause.max_length=400
	box.add_child(cause)
	box.add_child(_label("What will you change on your next run?" if first else "Did the second build work as you expected?",20))
	var plan:=LineEdit.new()
	plan.max_length=400
	box.add_child(plan)
	var status:=_label("Feedback and choices are saved on this computer.",16,false,MUTED)
	box.add_child(status)
	var send:=_button("SAVE & CHOOSE SECOND LOADOUT" if first else "FINISH PLAYTEST",func():
		if not game.playtest.answer(cause.text,plan.text):
			status.text="Enter your observation and next choice, or write “unsure”."
			return
		if first:game.restart()
		else:
			_overlay()
			panel_kind="playtest_finished"
			var done:=_center_panel(850,370)
			done.add_child(_label("Two runs recorded",32,true))
			done.add_child(_label(ProjectSettings.globalize_path("user://playtests"),14,false,MUTED))
			done.add_child(_button("QUIT",game.quit_application,true))
	)
	box.add_child(send)
	cause.grab_focus()
