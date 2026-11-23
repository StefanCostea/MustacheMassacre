extends RefCounted

const BOUNDS := Rect2(-42,-43,84,64)
const HUB := Vector3(0,0,8)
const PLACES := {
	"garage": [Vector3(0,0,8), "Grooming Garage", Color("d9b880")],
	"badlands": [Vector3(-27,0,4), "The Crispy Badlands", Color("e8a459")],
	"grease": [Vector3(26,0,5), "Grease City", Color("65cbbe")],
	"funland": [Vector3(-22,0,-26), "Funland Forever", Color("ed8199")],
	"palace": [Vector3(23,0,-29), "The Grand Grooming", Color("c9b2ff")],
}
const POSTS := {
	"tower": [Vector3(-27,0,5), "Water tower", "Break up the repair crew", "badlands"],
	"sheriff": [Vector3(-31,0,-5), "Sheriff’s crossing", "Challenge El Frigorífico", "badlands"],
	"kitchen": [Vector3(27,0,1), "The Fry Line", "Beat the Head Fry Cook", "grease"],
	"freight": [Vector3(20,0,9), "Wax freight", "Escort the wax truck", "grease"],
	"wheel": [Vector3(-22,0,-24), "Midway powerhouse", "Restart the Ferris wheel", "funland"],
	"throne": [Vector3(23,0,-26), "The royal cistern", "Challenge His Royal Flushness", "palace"],
}
const SWITCHES := {
	"latch": [Vector3(-30,0,3), "Tower gate"],
	"steam": [Vector3(24,0,-1), "Steam release"],
	"breaker": [Vector3(-26,0,-29), "Wheel breaker"],
	"valve": [Vector3(20,0,-30), "Flush valve"],
}
const BRIDGES := {"freight": 12., "wheel": -6.}

static func district(pos: Vector3) -> String:
	for key in PLACES:
		var center: Vector3 = PLACES[key][0]
		var radius := 10. if key=="garage" else 14.
		if Vector2(pos.x-center.x,pos.z-center.z).length() < radius:return key
	return "road"
