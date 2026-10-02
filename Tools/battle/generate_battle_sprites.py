"""Blender -b --python Tools/battle/generate_battle_sprites.py

Characters, portraits and effects. No rigs or external packages.
Subset: -- --only knight|archer|fx|portraits [--force].
"""
import bpy
import argparse
import sys
import hashlib
import importlib.util
import json
import math
import shutil
import time
from pathlib import Path
from mathutils import Vector

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Tools/generate_settlement_models.py"
RAW = Path("/tmp/duskara-battle")
CATALOG = ROOT / "Assets/Assets.xcassets"
ANIMATIONS = {"idle": 4, "walk": 8, "attack": 6, "death": 6}


def settlement():
    spec = importlib.util.spec_from_file_location("battle_settlement", SOURCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.COLORS.update(teamBlue=(0.36, 0.56, 0.86), teamRed=(0.78, 0.33, 0.28))
    return module


def setup():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE" if bpy.app.version >= (5, 0, 0) else "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 16
    scene.eevee.use_raytracing = False
    scene.render.film_transparent = True
    scene.render.use_motion_blur = False
    scene.eevee.use_volumetric_shadows = False
    scene.render.resolution_x = scene.render.resolution_y = 192
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.fps = 12
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (0.62, 0.60, 0.56, 1)
    background.inputs[1].default_value = 0.6
    bpy.ops.object.light_add(type="SUN")
    sun = bpy.context.object
    sun.data.energy = 3
    sun.data.angle = math.radians(8)
    sun.data.use_shadow = False
    azimuth, elevation = map(math.radians, (-35, 50))
    toward_light = Vector((-math.cos(elevation) * math.cos(azimuth),
                           math.cos(elevation) * math.sin(azimuth), math.sin(elevation)))
    sun.rotation_euler = (-toward_light).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.5
    up = Vector((0, 0.5, math.sqrt(3) / 2))
    center = up * (1.5 * (0.5 - 0.18))
    camera.location = center + Vector((0, -10 * math.sqrt(3) / 2, 5))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    return scene


def pivot(name, at, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = at
    return obj


def character(art, kind):
    root = pivot(kind, (0, 0, 0))
    torso = pivot("torso pivot", (0, 0, 0.46), root)
    def part(name, at, size, color, parent=torso, bevel=0.02):
        obj = art.box(name, at, size, color, bevel)
        obj.parent = parent
        return obj
    def rounded(name, at, size, color, parent=torso):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10 if name in ("upper arm", "gauntlet", "fist", "thigh", "shin") else 12,
                                            ring_count=6, radius=0.5, location=at)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(art.material(color))
        art.soften(obj, 0)
        obj.parent = parent
        return obj
    heavy = kind == "knight"
    armor = "stone" if heavy else "timber"
    rounded("breastplate", (0,0,0.23), (0.40,0.38,0.43) if heavy else (0.31,0.30,0.36), "slateRoof" if heavy else armor)
    rounded("hips", (0,0,0.01), (0.34,0.32,0.18), "darkTimber")
    part("cloth tabard", (0.01,-0.18 if heavy else -0.14,0.16), (0.29,0.045,0.28), "teamBlue", bevel=0.012)
    head = pivot("head pivot", (0,0,0.49 if heavy else 0.39), torso)
    helmet = rounded("helmet" if heavy else "hood", (0,0,0.045), (0.35,0.33,0.31) if heavy else (0.29,0.29,0.28), "stone" if heavy else "teamBlue", head)
    if heavy:
        for vertex in helmet.data.vertices:
            vertex.co.z = max(-0.095, vertex.co.z)
        part("visor slit", (0.155,0,0.042), (0.028,0.255,0.065), "darkTimber", head, 0)
        part("visor side slit", (0.055,-0.207,0.055), (0.21,0.025,0.035), "darkTimber", head, 0)
        part("visor nose", (0.177,0,0.015), (0.03,0.034,0.14), "stone", head, 0)
        part("helmet plume", (-0.06,0,0.205), (0.22,0.075,0.10), "teamBlue", head, 0.022)
    else:
        rounded("face", (0.095,-0.025,0.02), (0.18,0.20,0.20), "plaster", head)
        part("quiver", (-0.17,0.06,0.18), (0.12,0.12,0.32), "darkTimber")
    arms, elbows, legs, knees, boots = [], [], [], [], []
    for side in (-1,1):
        arm = pivot("shoulder pivot", (0,side*(0.23 if heavy else 0.18),0.34), torso)
        rounded("pauldron", (0,0,0), (0.21,0.21,0.18) if heavy else (0.15,0.15,0.13), armor, arm)
        rounded("upper arm", (0,0,-0.085), (0.15,0.15,0.20), armor, arm)
        elbow = pivot("elbow pivot", (0,0,-0.17), arm)
        rounded("gauntlet", (0,0,-0.075), (0.15,0.15,0.18), armor, elbow)
        rounded("fist", (0.01,0,-0.16), (0.14,0.14,0.13), "darkTimber", elbow)
        arms.append(arm)
        elbows.append(elbow)
        leg = pivot("hip pivot", (0,side*0.105,0.44), root)
        rounded("thigh", (0,0,-0.10), (0.17,0.18,0.24), "slateRoof", leg)
        knee = pivot("knee pivot", (0,0,-0.20), leg)
        rounded("shin", (0,0,-0.08), (0.145,0.15,0.20), armor, knee)
        boot = part("boot", (0.035,0,-0.185), (0.24,0.18,0.11), "darkTimber", knee, 0.018)
        legs.append(leg)
        knees.append(knee)
        boots.append(boot)
    if heavy:
        sword = pivot("sword pivot", (0.01,0,-0.16), elbows[1])
        sword.rotation_euler.y = 0.70
        part("blade", (0,0,0.245), (0.055,0.027,0.39), "stone", sword, 0.008)
        part("crossguard", (0,0,0.05), (0.19,0.05,0.045), "warmGold", sword, 0)
        part("sword grip", (0,0,-0.015), (0.04,0.04,0.10), "darkTimber", sword, 0)
        # A broad extruded kite with a rounded rim rather than a triangular sticker.
        outline = [(-0.16,0.19),(0.16,0.19),(0.17,-0.02),(0,-0.23),(-0.17,-0.02)]
        vertices = [(x,y,z) for y in (-0.038,0.038) for x,z in outline]
        faces = [tuple(range(4,-1,-1)),tuple(range(5,10))]
        faces += [(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
        mesh = bpy.data.meshes.new("kite")
        mesh.from_pydata(vertices,[],faces)
        shield = bpy.data.objects.new("kite shield",mesh)
        bpy.context.collection.objects.link(shield)
        shield.parent = elbows[0]
        shield.location = (0.035,-0.105,-0.06)
        mesh.materials.append(art.material("teamBlue"))
        art.soften(shield,0.016)
        part("shield boss", (0.035,-0.155,-0.035), (0.075,0.025,0.075), "warmGold", elbows[0],0)
    else:
        curve = bpy.data.curves.new("short bow", "CURVE")
        curve.dimensions = "3D"
        curve.bevel_depth = 0.018
        curve.bevel_resolution = 0
        spline = curve.splines.new("POLY")
        spline.points.add(8)
        for index, point in enumerate(spline.points):
            angle = -math.pi/2 + index/8*math.pi
            point.co = (0.14+0.10*math.cos(angle),-0.03,-0.10+0.23*math.sin(angle),1)
        bow = bpy.data.objects.new("bow",curve)
        bpy.context.collection.objects.link(bow)
        bow.parent = elbows[0]
        curve.materials.append(art.material("timber"))
        part("bow string", (0.14,-0.03,-0.10), (0.008,0.008,0.46), "strawRoof", elbows[0],0)
        part("drawn arrow", (0.20,-0.04,-0.10), (0.36,0.014,0.014), "timber", elbows[1],0)
    triangles = triangle_count()
    assert triangles <= 3000, (kind,triangles)
    print(f"{kind.upper()} triangles={triangles}",flush=True)
    return root,torso,arms,legs,triangles,elbows,knees,boots


def triangle_count():
    total = 0
    for obj in bpy.context.scene.objects:
        if obj.type in ("MESH", "CURVE"):
            mesh = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            mesh.calc_loop_triangles()
            total += len(mesh.loop_triangles)
            obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    return total


def animate(rig, kind, animation, count, team):
    root,torso,arms,legs,_,elbows,knees,boots = rig
    moving = (root,torso,*arms,*legs,*elbows,*knees,*boots)
    for obj in moving: obj.animation_data_clear()
    for frame in range(count):
        phase = frame/count*math.tau
        root.location.z = 0
        root.location.x = 0
        root.rotation_euler = (0,0,math.pi if team == "red" else 0)
        torso.location.z = 0.46
        for obj in (*arms,*legs,*knees): obj.rotation_euler = (0,0,0)
        arms[1].rotation_euler.y = -0.55 if kind == "knight" else 0
        for elbow in elbows: elbow.rotation_euler = (0,0.25,0)
        for boot in boots: boot.rotation_euler.y = 0
        if animation == "walk":
            for index in range(2):
                swing = math.sin(phase+index*math.pi)
                legs[index].rotation_euler.y = -swing*0.30
                knees[index].rotation_euler.y = 0.06 + max(0,-swing)*0.48
                boots[index].rotation_euler.y = -legs[index].rotation_euler.y-knees[index].rotation_euler.y
                arms[index].rotation_euler.y = swing*0.15 - (0.55 if kind == "knight" and index == 1 else 0)
                elbows[index].rotation_euler.y = 0.25-swing*0.08
            torso.location.z += 0.009*math.cos(2*phase)
        elif animation == "idle":
            torso.location.z += 0.006*math.sin(phase)
            elbows[1].rotation_euler.y += 0.025*math.sin(phase)
        elif animation == "attack":
            if kind == "knight":
                arms[1].rotation_euler.y = [0,-0.45,-0.90,0.95,0.45,0][frame]
                elbows[1].rotation_euler.y = [0.25,0.40,0.65,0.10,0.15,0.25][frame]
            else:
                arms[0].rotation_euler.y = -0.60
                elbows[1].rotation_euler.y = [0.25,0.5,0.9,-0.25,0,0.25][frame]
        else:
            root.rotation_euler.y = -[0,0.35,0.85,1.35,1.48,1.48][frame]
            root.location.x = [0,0.09,0.24,0.60,0.60,0.60][frame] * (1 if team == "blue" else -1)
            torso.location.z -= [0,0.02,0.06,0.10,0.10,0.10][frame]
            arms[1].rotation_euler.y = -0.35
        bpy.context.view_layer.update()
        # Keep the lowest boot's projected ground contact at the fixed foot anchor.
        up = Vector((0,0.5,math.sqrt(3)/2))
        lowest = min(up.dot(boot.matrix_world @ v.co) for boot in boots for v in boot.data.vertices)
        root.location.z -= lowest/up.z
        for obj in moving:
            obj.keyframe_insert("rotation_euler",frame=frame)
            obj.keyframe_insert("location",frame=frame)


def imageset(folder, name, source, scale="2x"):
    target = folder / f"{name}.imageset"
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target / f"{name}.png")
    (target / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": scale}],
        "info": {"author": "xcode", "version": 1}}))
    (folder / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}))


def render(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def cached(job, names, folder, force=False, params=None):
    raw = RAW / job
    raw.mkdir(parents=True, exist_ok=True)
    manifest = raw / ".manifest.json"
    digest = hashlib.sha256(Path(__file__).read_bytes() + SOURCE.read_bytes()
                            + json.dumps([names, params], sort_keys=True).encode()).hexdigest()
    good = (not force and manifest.exists() and json.loads(manifest.read_text())["hash"] == digest
            and all((folder / f"{n}.imageset/{n}.png").exists() for n in names))
    return raw, manifest, digest, good


def unit_job(art, kind, force, portrait=False):
    names = ([f"{kind}_{team}_portrait" for team in ("blue", "red")] if portrait else
             [f"{kind}_{team}_{anim}_{f:02}" for team in ("blue", "red") for anim,n in ANIMATIONS.items() for f in range(n)])
    folder = CATALOG / ("BattlePortraits" if portrait else f"Battle{kind.title()}.spriteatlas")
    job = kind + ("-portraits" if portrait else "")
    raw, manifest, digest, good = cached(job, names, folder, force)
    if good:
        print(f"CACHED {job}", flush=True)
        return
    scene = setup()
    rig = character(art, kind)
    team_mat = art.material("teamBlue")
    for team, rgb in (("blue", art.COLORS["teamBlue"]), ("red", art.COLORS["teamRed"])):
        team_mat.diffuse_color = (*rgb, 1)
        team_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*rgb, 1)
        if portrait:
            animate(rig, kind, "idle", 4, "blue")
            scene.frame_set(0)
            scene.render.resolution_x = scene.render.resolution_y = 256
            center = Vector((0, 0, 0.82))
            scene.camera.location = center + Vector((5, -7, 4.95))
            scene.camera.rotation_euler = (center - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
            scene.camera.data.ortho_scale = 0.90
            name = f"{kind}_{team}_portrait"
            render(scene, raw / f"{name}.png")
            imageset(folder, name, raw / f"{name}.png")
            continue
        for anim, count in ANIMATIONS.items():
            animate(rig, kind, anim, count, team)
            for frame in range(count):
                scene.frame_set(frame)
                name = f"{kind}_{team}_{anim}_{frame:02}"
                render(scene, raw / f"{name}.png")
                imageset(folder, name, raw / f"{name}.png")
    manifest.write_text(json.dumps({"hash": digest, "triangles": rig[4], "frames": len(names)}))
    # Reset the shared team material before building the next unit.
    team_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*art.COLORS["teamBlue"], 1)


def fx_job(art, force):
    names = ["arrow", "blob_shadow"] + [f"dust_{i:02}" for i in range(4)] + [f"hit_{i:02}" for i in range(3)]
    folder = CATALOG / "BattleFX.spriteatlas"
    raw, manifest, digest, good = cached("fx", names, folder, force)
    if good:
        print("CACHED fx", flush=True)
        return
    for name in names:
        scene = setup()
        scene.camera.location -= Vector((0, 0.24, math.sqrt(3) * 0.24))
        if name == "blob_shadow":
            image = bpy.data.images.new(name, width=128, height=48, alpha=True)
            pixels = []
            for y in range(48):
                for x in range(128):
                    radius = ((x-63.5)/61)**2 + ((y-23.5)/22)**2
                    pixels.extend((0.12, 0.09, 0.07, 0.30 * max(0, 1-radius)**2))
            image.pixels = pixels
            image.filepath_raw = str(raw / f"{name}.png")
            image.file_format = "PNG"
            image.save()
        else:
            if name == "arrow":
                scene.render.resolution_x, scene.render.resolution_y = 64, 16
                scene.camera.data.ortho_scale = 0.5
                art.box("shaft", (0,0,0), (0.42,0.02,0.02), "timber", 0.006)
                art.box("tip", (0.21,0,0), (0.07,0.03,0.04), "stone", 0.008)
                art.box("fletching", (-0.17,0,0), (0.08,0.025,0.045), "strawRoof", 0.01)
            elif name.startswith("dust"):
                scene.render.resolution_x = scene.render.resolution_y = 96
                scene.camera.data.ortho_scale = 0.75
                frame = int(name[-2:])
                for i in range(3):
                    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.09+frame*0.025,
                                                        location=((i-1)*0.12,0,0.02+frame*0.035))
                    sphere = bpy.context.object
                    sphere.scale.z = 0.7
                    sphere.data.materials.append(art.material("stone"))
                    art.soften(sphere, 0)
            else:
                scene.render.resolution_x = scene.render.resolution_y = 64
                scene.camera.data.ortho_scale = 0.5
                frame = int(name[-2:])
                for i in range(3):
                    art.box("spark", (0,0,0), (0.20-frame*0.045,0.025,0.025), "warmGold", 0.006,
                            (0, i*math.pi/3, 0))
            render(scene, raw / f"{name}.png")
        imageset(folder, name, raw / f"{name}.png")
    manifest.write_text(json.dumps({"hash": digest, "frames": len(names)}))


def main():
    started = time.monotonic()
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=("knight", "archer", "fx", "portraits"))
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    art = settlement()
    for kind in ("knight", "archer"):
        if args.only is None or args.only == kind: unit_job(art, kind, args.force)
        if args.only is None or args.only == "portraits": unit_job(art, kind, args.force, portrait=True)
    if args.only is None or args.only == "fx": fx_job(art, args.force)
    print(f"COMPLETE {time.monotonic()-started:.2f}s", flush=True)


if __name__ == "__main__":
    main()
