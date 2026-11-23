class_name CombatConfig
extends Resource

@export var player_health: float = 100.0
@export var movement_speed: float = 5.8
@export var shot_damage: float = 20.0
@export var shot_interval: float = 0.24
@export var reload_seconds: float = 1.2
@export var perfect_start: float = 0.65
@export var perfect_end: float = 0.85
@export var dash_seconds: float = 0.18
@export var dash_speed: float = 16.0
@export var dash_cooldown: float = 1.0
@export var ricochet_cooldown: float = 8.0
@export var vortex_cooldown: float = 12.0
@export var vortex_duration: float = 3.5
@export var vortex_radius: float = 3.0
@export var frenzy_duration: float = 6.0
@export var max_enemies: int = 35
@export var max_projectiles: int = 256
@export var max_chain_events: int = 32
@export var critical_multiplier: float = 1.6
@export var hair_trigger_multiplier: float = 1.25
@export var frenzy_fire_multiplier: float = 1.3
@export var explosive_every: int = 5
@export var explosive_damage: float = 28
@export var explosive_radius: float = 1.8
@export var vortex_cast_range: float = 7
@export var magnetic_radius: float = 3.8
@export var magnetic_bonus_seconds: float = 1.0

const SPECIALS := {
	"high_noon": {"name":"High Noon", "description":"Grow golden moustache wings. Fly low and fire six marked spikes, then steer and shoot from the air."},
	"saguaro_lance": {"name":"Saguaro Lance", "description":"Fuse both arms into a giant cactus launcher. Sweep a sustained beam of thorns through enemies in a line."}
}

const UPGRADES := {
	"bounce":{"name":"EXTRA BOUNCE","tag":"BALLISTICS","description":"Every revolver round ricochets once.\nRicochet Rodeo gains one extra target.","icon":"↗"},
	"prickly":{"name":"PRICKLY SITUATION","tag":"CRITICAL REACTION","description":"Critical kills burst into eight needles.\nNeedles inherit one ricochet with Extra Bounce.","icon":"✳"},
	"explosive":{"name":"EXPLOSIVE PERSONALITY","tag":"AMMUNITION","description":"Every fifth revolver shot explodes.\nNearby enemies take 28 blast damage.","icon":"✹"},
	"trigger":{"name":"HAIR TRIGGER","tag":"GUNSLINGER","description":"Fire the six-shooter 25% faster.\nThe moustache approves.","icon":"»"},
	"magnet":{"name":"MAGNETIC TUMBLEWEED","tag":"CROWD CONTROL","description":"Tumbleweed pulls across a wider radius\nand lasts one extra second.","icon":"◎"},
	"quickdraw":{"name":"QUICK DRAW","tag":"PRECISION","description":"The first shot after each dash is critical.\nCritical shots deal 60% more damage.","icon":"ϟ"},
	"fling":{"name":"FREIGHT TUMBLEWEED","tag":"CROWD CONTROL","description":"Your vortex hurls a captured outlaw into a neighbour. Both take collision damage.","icon":"↗"},
	"last_word":{"name":"THE LAST WORD","tag":"GUNSLINGER","description":"The final chamber of a hammer fan is always critical.","icon":"✶"},
	"riposte":{"name":"CLOSE SHAVE","tag":"PRECISION","description":"Narrowly dodge an attack to prime your next shot for a critical hit.","icon":"ϟ"},
	"pinball":{"name":"PINBALL CYLINDER","tag":"BALLISTICS","description":"Add a bounce to every shot. Ricochets retain 95% of their damage.","icon":"↗"},
	"aftershock":{"name":"SECOND HELPING","tag":"WORKSHOP","description":"Your Slapstache strikes twice. Your vortex erupts when it expires.","icon":"◎"},
	"needle_powder":{"name":"POWDERED PRICKLES","tag":"WORKSHOP","description":"Every third needle from Prickly Situation explodes on impact.","icon":"✹"}
}

const FIELD_SKILLS := {"tumbleweed":"Tumbleweed Vortex", "slap":"Slapstache"}
const WORKSHOP := {"aftershock":24, "needle_powder":30}
