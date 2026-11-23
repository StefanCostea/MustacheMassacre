"""Bake the gunslinger performance on a private copy of the natural candidate scene."""
import json
from math import radians, sin, tau, sqrt
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
HANDOFF = ROOT / 'desgin/character_models/refined/don_espino_motion_study'
ASSET = ROOT / 'game/assets/characters/don_espino_motion_study/don_espino_study.glb'
scene = bpy.context.scene
rig = scene.objects['Natural_Mixamo_Rig']
gun = scene.objects['Natural_Separate_Revolver']
skin = scene.objects['Natural_Skin']
animation = rig.animation_data
original = {t.name: t.strips[0].action for t in animation.nla_tracks}
for track in animation.nla_tracks:
    track.mute = True


def bind(action):
    animation.action = action
    animation.action_slot = action.slots[0]


def sample(action, frame):
    bind(action)
    scene.frame_set(frame)
    return {p.name: rig.matrix_world @ p.matrix for p in rig.pose.bones}


def bone(name):
    return 'mixamorig:' + name


def angle(axis, degrees):
    return Quaternion(Vector(axis), radians(degrees))


def pitch(degrees):
    return angle((1, 0, 0), degrees)


def roll(degrees):
    return angle((0, 1, 0), degrees)


def yaw(degrees):
    return angle((0, 0, 1), degrees)


def curve(f, points):
    """Ease through artist-timed extremes, with explicit holds where needed."""
    for (a, start), (b, end) in zip(points, points[1:]):
        if f <= b:
            t = max(0, (f - a) / (b - a))
            return start + (end - start) * t*t*(3 - 2*t)
    return points[-1][1]


# The baked project revolver retains separate islands for the fluted cylinder,
# both end plates and all chamber faces. The axle stays in the frame.
ready_source = sample(original['idle'], 1)
gun_at_bind = gun.matrix_world.copy()
cylinder_center = Vector((0, -.1205, .1505))
mesh = gun.data
assert len(mesh.vertices) == 6519, 'Inspect the prop islands before using another mesh'
cylinder_ids = set(range(0, 2740)) | set(range(2936, 3240)) | set(range(5321, 5677))
assert all(all(i in cylinder_ids for i in face.vertices) or
           all(i not in cylinder_ids for i in face.vertices) for face in mesh.polygons)
bpy.ops.object.select_all(action='DESELECT')
gun.select_set(True)
bpy.context.view_layer.objects.active = gun
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='DESELECT')
bpy.ops.object.mode_set(mode='OBJECT')
for index in cylinder_ids:
    mesh.vertices[index].select = True
before = set(scene.objects)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.separate(type='SELECTED')
bpy.ops.object.mode_set(mode='OBJECT')
cylinder, = set(scene.objects) - before
cylinder.name = 'Revolver_Cylinder'

# Place a rigid control in the current gun basis; the rig's bind pose differs
# from its sampled ready pose. Map the control back through the weapon parent.
weapon = rig.data.bones['weapon.R']
world_to_rest = weapon.matrix_local @ ready_source['weapon.R'].inverted()
center_world = gun_at_bind @ cylinder_center
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
control = rig.data.edit_bones.new('weapon_cylinder')
control.parent = rig.data.edit_bones['weapon.R']
control.head = world_to_rest @ center_world
control.tail = world_to_rest @ (gun_at_bind @ (cylinder_center + Vector((0, -.1, 0))))
bpy.ops.object.mode_set(mode='OBJECT')
scene.frame_set(1)
cylinder.parent = rig
cylinder.parent_type = 'BONE'
cylinder.parent_bone = 'weapon_cylinder'
bpy.context.view_layer.update()
cylinder.matrix_world = gun_at_bind
bpy.context.view_layer.update()

bones = list(rig.data.bones)
rest = {b.name: rig.matrix_world @ b.matrix_local for b in bones}
children = {b.name: [b.name] + [c.name for c in b.children_recursive] for b in bones}
parents = {b.name: b.parent.name if b.parent else None for b in bones}
rest_local = {k: (rest[v] if v else rig.matrix_world).inverted() @ rest[k] for k,v in parents.items()}
ready_source = sample(original['idle'], 1)
grip_orientation = ready_source[bone('RightHand')].to_quaternion()
wrist_to_cylinder = center_world - ready_source[bone('RightHand')].translation
rest_cylinder_from_weapon = rest['weapon.R'].inverted() @ rest['weapon_cylinder']


def transform(pose, name, delta):
    for child in children[name]:
        pose[child] = delta @ pose[child]


def rotate(pose, name, relative):
    pivot = Matrix.Translation(pose[name].translation)
    transform(pose, name, pivot @ relative.to_matrix().to_4x4() @ pivot.inverted())


def orient(pose, name, absolute):
    rotate(pose, name, absolute @ pose[name].to_quaternion().inverted())


def limb(pose, upper, lower, end, target, pole):
    shoulder, elbow, wrist = (pose[n].translation for n in (upper, lower, end))
    a, b = (elbow-shoulder).length, (wrist-elbow).length
    direction = (target-shoulder).normalized()
    distance = max(abs(a-b)+.001, min(a+b-.001, (target-shoulder).length))
    pole = (pole - direction * pole.dot(direction)).normalized()
    along = (a*a + distance*distance - b*b) / (2*distance)
    desired = shoulder + direction*along + pole*sqrt(max(0, a*a-along*along))
    rotate(pose, upper, (elbow-shoulder).rotation_difference(desired-shoulder))
    elbow, wrist = pose[lower].translation, pose[end].translation
    rotate(pose, lower, (wrist-elbow).rotation_difference(shoulder+direction*distance-elbow))


def fingers(pose, side, close):
    for b in bones:
        if not b.name.startswith(bone(side+'Hand')) or b.name == bone(side+'Hand'):
            continue
        parent = parents[b.name]
        relative = ready_source[parent].inverted() @ ready_source[b.name]
        desired = rest_local[b.name].to_quaternion().slerp(relative.to_quaternion(), close)
        orient(pose, b.name, pose[parent].to_quaternion() @ desired)


def performance(clip, frame, end, source=None):
    phase = tau * frame / end
    breath = sin(phase) if clip == 'idle' else 0.
    move = source is not None
    step = sin(phase) if move else 0.
    pose = {n:m.copy() for n,m in (source or rest).items()}
    if move:
        # Retain original mocap hips, knees and boot contacts, but allow the
        # chest to counter the pelvis so the sight line stays readable.
        chest = bone('Spine2')
        neutral = rest[chest].to_quaternion()
        orient(pose, chest, neutral.slerp(pose[chest].to_quaternion(), .25))
    else:
        transform(pose, bone('Hips'), Matrix.Translation((-.024, .018, -.046)))
        rotate(pose, bone('Hips'), yaw(-7))
        for sign, side in [(-1,'Right'), (1,'Left')]:
            foot = bone(side+'Foot')
            target = rest[foot].translation + Vector((sign*.060, -sign*.080, .005))
            limb(pose, bone(side+'UpLeg'), bone(side+'Leg'), foot, target, Vector((sign*.28,-1,0)))
            orient(pose, foot, yaw(sign*4) @ rest[foot].to_quaternion())
    kick = drag = gather = spin = close = 0.
    if clip == 'shoot':
        kick = curve(frame, [(0,0),(1,1),(2,.89),(4,.20),(5,-.105),(7,0)])
        drag = curve(frame, [(0,0),(1,.18),(2,1),(3,.82),(5,-.22),(7,0)])
    if clip == 'reload':
        gather = curve(frame, [(0,0),(3,-.10),(10,.94),(13,1),(23,1),(28,.86),(33,-.055),(36,0)])
        spin = curve(frame, [(0,0),(10,0),(14,.32),(21,.92),(25,1),(36,1)])
        close = curve(frame, [(0,0),(7,0),(11,1),(24,1),(27,0),(36,0)])

    chest = bone('Spine2')
    orient(pose, chest, (yaw(7 + 5*gather) @ roll(-3 - 2*drag) @ pitch(2+breath*.65-5*drag)
                         @ rest[chest].to_quaternion()).slerp(pose[chest].to_quaternion(), .20 if move else 0))
    head = bone('Head')
    orient(pose, head, yaw(-3-12*gather) @ pitch(-2+5*gather-2*drag) @ roll(2.5+1.3*drag) @ rest[head].to_quaternion())
    for side, sign in [('L',1),('R',-1)]:
        for i,part in enumerate(('root','mid','tip')):
            name = f'stache_{part}.{side}'
            delay = (sin(phase-.55*i) if move or clip=='idle' else 0)
            flick = curve(frame, [(0,0),(9,0),(12,-7),(15,16),(20,-5),(25,0)]) if clip=='reload' and side=='R' else 0
            rotate(pose, name, pitch(delay*(.6+.35*i) + drag*(3+i) + flick*(.45+.18*i)))

    # A low, one-handed draw leaves daylight around the face. The first
    # shot frame is already aimed so gameplay never waits for an anticipation.
    right = Vector((-.485, -.493, 1.35 + .009*breath + .018*step))
    if move:
        right.z += pose[bone('Hips')].translation.z - .99
    right += Vector((-.028*kick,.115*kick,.10*kick))
    gun_rotation = yaw(16*gather) @ roll(-24*gather) @ pitch(4 - 32*kick - 31*gather)
    left = Vector((.49,-.21,1.105 + breath*.008 - step*.035))
    left += Vector((.035*drag,.018*drag,.025*drag))
    if clip == 'reload':
        # Bring the cylinder to the working curl; the rigid grip follows the
        # hand throughout. The curl flick lags the wrist and starts the spin.
        contact = pose['stache_tip.R'].translation + Vector((-.024,-.048,-.015))
        open_offset = gun_rotation @ Vector((-.105*close,0,0))
        right = right.lerp(contact - gun_rotation @ wrist_to_cylinder - open_offset, gather)
        left += Vector((.055,-.14,.21))*gather
    for side, hand_target, pole in [('Right',right,Vector((-.8,.4,-.7))),
                                    ('Left',left,Vector((.9,.38,-.3)))]:
        arm, fore, hand = [bone(side+s) for s in ('Arm','ForeArm','Hand')]
        limb(pose, arm, fore, hand, hand_target, pole)
        if side == 'Right':
            orient(pose, hand, gun_rotation @ grip_orientation)
        else:
            orient(pose, hand, yaw(-40-8*gather) @ roll(24+6*gather) @ rest[hand].to_quaternion())
        fingers(pose, side, 1. if side == 'Right' else .47 + .15*gather)
    # Restore the rigid weapon offset after the wrist and finger adjustments.
    wrist = bone('RightHand')
    pose['weapon.R'] = pose[wrist] @ ready_source[wrist].inverted() @ ready_source['weapon.R']
    cyl = 'weapon_cylinder'
    pose[cyl] = pose['weapon.R'] @ rest_cylinder_from_weapon
    pose[cyl].translation += gun_rotation @ Vector((-.105*close,0,0))
    if spin:
        rotate(pose, cyl, angle(gun_rotation @ Vector((0,-1,0)), 720*spin))
    return pose


# Poses are in the character's Blender world axes, with -Y facing the target.
# Preserve velocity through intermediate keys. At an impact or a turn the two
# adjacent slopes disagree, so the tangent is zero.
def fall_curve(frame, keys):
    def tangent(i):
        if i == 0 or i == len(keys) - 1:
            return 0.
        f0, v0 = keys[i-1]
        f1, v1 = keys[i]
        f2, v2 = keys[i+1]
        back = (v1-v0) / (f1-f0)
        forward = (v2-v1) / (f2-f1)
        return 2*back*forward/(back+forward) if back*forward > 0 else 0.

    for i, ((a, start), (b, end)) in enumerate(zip(keys, keys[1:])):
        if frame <= b:
            t = max(0., (frame-a)/(b-a))
            u = 1-t
            return (u*u*(1+2*t)*start + t*t*(3-2*t)*end
                    + u*t*(b-a)*(u*tangent(i) - t*tangent(i+1)))
    return keys[-1][1]


def fall_vector(frame, keys):
    return Vector([fall_curve(frame, [(f, v[axis]) for f, v in keys]) for axis in range(3)])


def fall_contact_points(ready):
    # Sample the actual soles, curled fingers and prop in the revised ready
    # pose. Keep heel and palm height correct as their orientation changes.
    graph = bpy.context.evaluated_depsgraph_get()

    def vertices(obj):
        evaluated = obj.evaluated_get(graph)
        data = evaluated.data
        points = np.empty(len(data.vertices)*3, dtype=np.float32)
        data.vertices.foreach_get('co', points)
        world = np.array(evaluated.matrix_world)
        return points.reshape(-1,3) @ world[:3,:3].T + world[:3,3]

    points = vertices(skin)
    groups = [skin.vertex_groups[max(v.groups, key=lambda g:g.weight).group].name for v in skin.data.vertices]
    clouds = {}
    for side in ('Right','Left'):
        for part in ('Foot','Hand'):
            name = bone(side+part)
            indices = [i for i,group in enumerate(groups) if group in children[name]]
            region = points[indices]
            if name == bone('RightHand'):
                region = np.vstack((region, vertices(gun), vertices(cylinder)))
            clouds[name] = region - np.array(ready[name].translation)
    return clouds


def contact_height(cloud, rotation):
    # Support point along world down for the rotated mesh.
    row = np.array(rotation.to_matrix()[2])
    return .005 - np.einsum('ij,j->i', cloud, row).min()


def fall_pose(frame, ready, clouds):
    pose = {n:m.copy() for n,m in ready.items()}
    if frame == 0:
        return pose
    hips = bone('Hips')
    # The belt drops while the boots still carry his weight. After the hip
    # contact the chest continues on its own arc, then rebounds a little.
    offset = fall_vector(frame, [
        (0,(0,0,0)), (2,(.022,.027,.01)), (6,(.077,.060,-.055)),
        (10,(.15,.115,-.21)), (14,(.26,.19,-.43)), (17,(.335,.235,-.675)),
        (20,(.37,.263,-.64)), (24,(.39,.275,-.665)), (29,(.39,.275,-.665))])
    transform(pose, hips, Matrix.Translation(offset))
    axis = Vector((-.47,.883,0)).normalized()
    pelvis = fall_curve(frame, [(0,0),(2,4),(6,13),(10,24),(14,41),(17,56),(21,72),(24,66),(27,67)])
    chest = fall_curve(frame, [(0,0),(2,13),(5,9),(10,13),(14,25),(17,43),(19,57),(22,83),(24,76),(27,80)])
    head = fall_curve(frame, [(0,0),(2,20),(5,8),(10,4),(14,18),(17,35),(20,53),(22,74),(24,68),(27,76)])
    twist = fall_curve(frame, [(0,0),(3,-9),(9,2),(17,-22),(22,-48),(27,-51)])
    rotate(pose, hips, angle(axis, pelvis) @ yaw(twist*.55))
    for part, tilt, yaw_angle in [('Spine',pelvis*.7+chest*.3,twist*.75),
                                  ('Spine1',pelvis*.35+chest*.65,twist*.9),
                                  ('Spine2',chest,twist), ('Neck',(chest+head)*.5,twist*.55),
                                  ('Head',head,twist*.35)]:
        name = bone(part)
        orient(pose, name, angle(axis,tilt) @ yaw(yaw_angle) @ ready[name].to_quaternion())

    def solve(side, chain, target, pole):
        top, mid, tip = [bone(side+n) for n in chain]
        start_pole = (ready[mid].translation-ready[top].translation)
        ref = (ready[tip].translation-ready[top].translation).normalized()
        start_pole = (start_pole - ref*start_pole.dot(ref)).normalized()
        weight = fall_curve(frame, [(0,0),(7,1)])
        limb(pose, top, mid, tip, target, start_pole.lerp(Vector(pole), weight))

    for side in ('Right','Left'):
        foot = bone(side+'Foot')
        if side == 'Left':
            # The lead boot holds through the buckle, then the heel skids out.
            delta = [(0,(0,0,0)),(13,(0,0,0)),(18,(.014,-.09,0)),
                     (22,(.028,-.23,.035)),(26,(.035,-.30,-.028))]
            toe = [(0,0),(12,0),(17,-6),(22,-33),(26,-24)]
            knee = (.08,-.95,.6)
        else:
            # A short failed recovery step; only the trailing boot kicks up
            # when the shoulders hit the floor.
            delta = [(0,(0,0,0)),(3,(0,0,0)),(6,(-.035,.08,.10)),
                     (9,(-.08,.15,0)),(15,(-.08,.15,0)),(19,(-.10,.09,.06)),
                     (22,(-.19,-.10,.29)),(26,(-.20,-.16,0)),(28,(-.20,-.16,0))]
            toe = [(0,0),(6,10),(9,0),(16,0),(22,-44),(26,-54),(28,-40)]
            knee = (-.38,-.8,.53)
        rotation = pitch(fall_curve(frame,toe))
        travel = fall_vector(frame,delta)
        target = ready[foot].translation + travel
        target.z = contact_height(clouds[foot], rotation) + max(0., travel.z)
        solve(side, ('UpLeg','Leg','Foot'), target, knee)
        orient(pose, foot, rotation @ ready[foot].to_quaternion())

    for side in ('Right','Left'):
        arm, hand = bone(side+'Arm'), bone(side+'Hand')
        start = ready[hand].translation-ready[arm].translation
        if side == 'Right':
            path = [(0,start),(2,(-.16,-.39,.09)),(6,(-.26,-.29,.20)),
                    (11,(-.35,-.24,.10)),(17,(-.40,-.21,.18)),(21,(-.48,-.18,.09)),
                    (25,(-.27,-.15,-.32)),(28,(-.22,-.12,-.36))]
            pole = (-.65,.52,-.43)
            handgun = fall_vector(frame, [(0,(0,0,0)),(2,(-28,4,-9)),(6,(-45,0,-23)),
                                   (12,(-23,10,-39)),(18,(-33,22,-61)),(22,(-12,36,-72)),
                                   (25,(6,76,-84)),(28,(2,73,-82))])
            orientation = yaw(handgun.z) @ pitch(handgun.x) @ roll(handgun.y)
        else:
            path = [(0,start),(3,(.22,-.28,-.30)),(7,(.41,-.10,-.08)),
                    (12,(.46,.10,-.26)),(17,(.36,.22,-.41)),(20,(.40,.17,-.28)),
                    (24,(.45,.16,-.17)),(27,(.44,.14,-.18))]
            pole = (.65,-.45,.35)
            reach = fall_curve(frame, [(0,0),(7,.42),(16,1)])
            fingers_out = (ready[bone('LeftHandMiddle2')].translation-ready[hand].translation).normalized()
            across = ready[bone('LeftHandIndex1')].translation-ready[bone('LeftHandRing1')].translation
            normal = fingers_out.cross(across).normalized()
            palm = Matrix((fingers_out,normal.cross(fingers_out),normal)).transposed()
            # Land with the back of the hand up and the thumb toward the toes.
            out = Vector((.86,.50,-.06)).normalized()
            across = out.cross(Vector((0,0,1))).normalized()
            planted = Matrix((out,across,out.cross(across))).transposed()
            orientation = Quaternion().slerp((planted @ palm.inverted()).to_quaternion(), reach)
        target = pose[arm].translation + fall_vector(frame,path)
        floor = contact_height(clouds[hand], orientation)
        if side == 'Right':
            settle = fall_curve(frame, [(0,0),(20,0),(26,1)])
            target.z += (floor-target.z)*settle
        else:
            # Keep a little clearance between baked frames on the fast shoulder drop.
            floor += fall_curve(frame, [(0,0),(16,0),(17,.008),(22,.008),(24,0)])
            brace = fall_curve(frame, [(0,0),(12,0),(17,1)])
            target.z += (floor-target.z)*brace
        target.z = max(target.z, floor)
        solve(side, ('Arm','ForeArm','Hand'), target, pole)
        orient(pose, hand, orientation @ ready[hand].to_quaternion())

    # The head stops first. The curl tips carry on for two more frames.
    for side, sign in [('L',1),('R',-1)]:
        for i, part in enumerate(('root','mid','tip')):
            delayed = max(0, frame-i)
            loose = fall_curve(delayed, [(0,0),(3,-8),(6,4),(10,0),(17,-5),
                                         (21,-13),(23,12),(25,-4),(27,0)])
            rotate(pose, f'stache_{part}.{side}', angle(axis,loose*(.45+i*.15)) @ roll(sign*loose*.12))
    return pose


locomotion = ['walk','run_forward','run_backward','strafe_left','strafe_right']
durations = {'idle':72, 'shoot':7, 'reload':36, 'death':29}
fall_start = performance('idle', 0, durations['idle'])
sampled = {}
for clip in locomotion:
    first, last = map(int, original[clip].frame_range)
    durations[clip] = last-first
    sampled[clip] = [sample(original[clip], f) for f in range(first,last+1)]

actions = original.copy()
for clip, end in durations.items():
    if clip == 'death':
        bind(actions['idle'])
        scene.frame_set(1)
        clouds = fall_contact_points(fall_start)
    action = bpy.data.actions.new('Gunslinger_'+clip)
    action.slots.new(id_type='OBJECT', name=rig.name)
    bind(action)
    prior = {}
    for frame in range(end+1):
        if clip == 'death':
            pose = fall_pose(frame, fall_start, clouds)
        else:
            pose = performance(clip, frame, end, sampled[clip][frame] if clip in sampled else None)
        for b in bones:
            name = b.name
            parent = parents[name]
            local = (pose[parent] if parent else rig.matrix_world).inverted() @ pose[name]
            location, rotation, scale = (rest_local[name].inverted() @ local).decompose()
            if name in prior:
                rotation.make_compatible(prior[name])
            prior[name] = rotation.copy()
            p = rig.pose.bones[name]
            p.rotation_mode = 'QUATERNION'
            p.location, p.rotation_quaternion, p.scale = location, rotation, scale
            for prop in ('location','rotation_quaternion','scale'):
                p.keyframe_insert(prop, frame=frame+1, group=name)
    actions[clip] = action

def carry_stride(frames, clip):
    # Use the foot separation of this particular take. The strafes keep a
    # staggered front foot and open/close sideways instead.
    component = 0 if clip.startswith('strafe') else 1
    spread = [(p[bone('LeftFoot')].translation - p[bone('RightFoot')].translation)[component]
              for p in frames[:-1]]
    midpoint = (max(spread)+min(spread))*.5
    half = max((max(spread)-min(spread))*.5, .001)
    normalized = [(value-midpoint)/half for value in spread]
    return [(-v if clip == 'strafe_right' else v) for v in normalized]


def palm_basis(along, thumb):
    along = along.normalized()
    normal = along.cross(thumb).normalized()
    return Matrix((along,normal.cross(along),normal)).transposed().to_quaternion()


left_hand = bone('LeftHand')
palm_rest = palm_basis(rest[bone('LeftHandMiddle1')].translation-rest[left_hand].translation,
                       rest[bone('LeftHandIndex1')].translation-rest[bone('LeftHandRing1')].translation)


def carry_side(pose, side, clip, stride, trailing, breath, accent, weight):
    if weight <= 0:
        return
    is_right = side == 'Right'
    sign = -1 if is_right else 1
    shoulder, arm, fore, hand = [bone(side+n) for n in ('Shoulder','Arm','ForeArm','Hand')]
    branch = children[shoulder]
    before = {n:pose[n].copy() for n in branch}
    # Wrist targets are relative to the moving shoulder. The elbow stays
    # behind the side seam and the arm shortens as it swings forward.
    speed = {'walk':.63,'run_forward':1.,'run_backward':.81,
             'strafe_left':.67,'strafe_right':.67}.get(clip,0.)
    side_step = clip.startswith('strafe')
    swing = stride*speed
    lag = trailing*speed
    rotate(pose, shoulder, yaw(-4.2*swing) @ roll(sign*(1.2*abs(swing)+.6*breath)))
    if is_right:
        travel = (.105 if side_step else .16)*swing
        reach = Vector((-.115-.020*abs(swing), -.125-.13*speed+travel,
                        -.53+.16*speed-.047*swing+.020*abs(swing)+.008*breath))
        pole = Vector((-.31,.88,-.40))
    else:
        travel = (.145 if side_step else .285)*swing
        reach = Vector((.13+.025*abs(swing)+(.055*lag if side_step else 0),
                        -.067-.074*speed-travel-.014*breath,
                        -.555+.14*speed+.078*max(0,swing)+.018*abs(swing)))
        pole = Vector((.29,.91,-.31))
    if clip == 'stache_frenzy':
        # Give the expanding curl daylight above the low hand.
        reach += Vector((sign*.07,.20,-.025))*accent
    elif clip == 'dash':
        reach += Vector((sign*.02,.07 if is_right else -.11,.08))*accent
    elif clip == 'hurt':
        reach += Vector((sign*.055,.08,.06 if is_right else .09))*accent
    limb(pose, arm, fore, hand, pose[arm].translation+reach, pole)
    if is_right:
        # Rotate the hand and the entire attached prop together. The path of
        # the bore is measured from the muzzle's forward axis at export.
        down = 49 - 12*speed + 13*lag + 2*breath
        down += {'stache_frenzy':18,'dash':12,'hurt':-11}.get(clip,0)*accent
        bearing = -3 + (8 if side_step else 4)*swing
        orient(pose, hand, yaw(bearing) @ roll(-4+4*lag) @ pitch(down) @ grip_orientation)
    else:
        forearm = (pose[hand].translation-pose[fore].translation).normalized()
        # Follow the forearm with a soft wrist. Keep the thumb forward and
        # the inside of the palm toward the thigh as the elbow passes the hip.
        along = (forearm*.73+Vector((-.08,-.16*lag,-.27))).normalized()
        palm = palm_basis(along, Vector((-.04,-1,.22)))
        orient(pose, hand, palm @ palm_rest.inverted() @ rest[hand].to_quaternion())
        for b in bones:
            if b.name == hand or not b.name.startswith(hand):
                continue
            parent = parents[b.name]
            closed = ready_source[parent].inverted() @ ready_source[b.name]
            digit = b.name.removeprefix(hand).rstrip('0123456789')
            curl = {'Thumb':.38,'Index':.48,'Middle':.62,'Ring':.73}[digit]
            curl += .085*lag + .025*breath
            local = rest_local[b.name].to_quaternion().slerp(closed.to_quaternion(),curl)
            orient(pose,b.name,pose[parent].to_quaternion() @ local)

    if weight < 1:
        # Blend local joints so wrist and prop stay connected when handing
        # over to the original reload contact and fall impact poses.
        after = {n:pose[n].copy() for n in branch}
        for n in branch:
            parent = parents[n]
            old_local = before.get(parent,pose[parent]).inverted() @ before[n]
            new_local = after.get(parent,pose[parent]).inverted() @ after[n]
            pose[n] = pose[parent] @ old_local.lerp(new_local,weight)


def polish_carry(actions):
    # The approved reload and fall were posed over the previous ready pose.
    # Only their entrances (and the reload exit) transition to the new carry.
    inherited = ['dash','hurt','cast','stache_frenzy','ultimate']
    for clip in ['idle',*locomotion,'shoot','reload','death',*inherited]:
        action = actions[clip]
        if clip in inherited:
            action = action.copy()
            action.name = 'Gunslinger_'+clip
            actions[clip] = action
        first,last = map(int,action.frame_range)
        poses = [sample(action,f) for f in range(first,last+1)]
        strides = carry_stride(poses,clip) if clip in locomotion else []
        prior = {}
        for i,pose in enumerate(poses):
            f = first+i
            t = i/(last-first)
            right_weight = left_weight = 1.
            if clip == 'reload':
                right_weight = left_weight = curve(i,[(0,1),(7,0),(29,0),(36,1)])
            elif clip == 'death':
                right_weight = left_weight = curve(i,[(0,1),(5,0)])
            elif clip == 'cast':
                left_weight = 0.
            elif clip == 'ultimate':
                right_weight = left_weight = curve(t,[(0,1),(.20,0),(.78,0),(1,1)])
            elif clip == 'shoot':
                right_weight = 0.
                # The shooting overlay in Godot keeps the free arm in its gait.
                # Give the standalone clip a small counter-reaction.
                fore = bone('RightForeArm')
                hand = bone('RightHand')
                strike = curve(i,[(0,0),(1,0),(2,1),(3,.77),(5,.07),(6,-.07),(7,0)])
                shoulder = pose[bone('RightArm')].translation
                target = shoulder+Vector((-.105, -.525+.10*strike, -.055+.09*strike))
                limb(pose,bone('RightArm'),fore,hand,target,Vector((-.45,.5,-.82)))
                orient(pose,hand,pitch(-26*strike) @ grip_orientation)
            phase = sin(t*tau)
            index = i % len(strides) if strides else 0
            stride = strides[index] if strides else 0.
            trailing = .75*strides[(index-1)%len(strides)] + .25*stride if strides else 0.
            breath = phase if clip == 'idle' else 0.
            accent = sin(t*tau*.5)
            carry_side(pose,'Right',clip,stride,trailing,breath,accent,right_weight)
            carry_side(pose,'Left',clip,stride,trailing,breath,accent,left_weight)
            if clip=='shoot':
                rotate(pose,bone('LeftArm'),pitch(5*strike))
            for side,weight in [('Right',right_weight),('Left',left_weight)]:
                if weight == 0 and clip!='shoot':
                    continue
                for n in children[bone(side+'Shoulder')]:
                    p = rig.pose.bones[n]
                    local = pose[parents[n]].inverted() @ pose[n]
                    rotation = (rest_local[n].inverted() @ local).to_quaternion()
                    if n in prior:
                        rotation.make_compatible(prior[n])
                    prior[n] = rotation.copy()
                    p.rotation_quaternion = rotation
                    p.keyframe_insert('rotation_quaternion',frame=f,group=n)


polish_carry(actions)

for track in list(animation.nla_tracks):
    animation.nla_tracks.remove(track)
for name, action in actions.items():
    track = animation.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(action.frame_range[0]), action)
    track.mute = True
rig['natural_final_actions'] = json.dumps({k:a.name for k,a in actions.items()})
bind(actions['idle'])
scene.frame_start, scene.frame_end = 1, 73
scene.render.fps = 30
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in (rig, skin, gun, cylinder, scene.objects['Muzzle'], scene.objects['GunOrigin']):
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
ASSET.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(ASSET), export_format='GLB', use_selection=True,
    use_active_scene=True, export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
    export_cameras=False, export_lights=False)
HANDOFF.mkdir(parents=True, exist_ok=True)
bpy.data.libraries.write(str(HANDOFF/'DonEspino_motion_study.blend'), {scene}, compress=True, fake_user=True)
print('Saved motion study', len(actions), 'actions', len(bones), 'bones')
