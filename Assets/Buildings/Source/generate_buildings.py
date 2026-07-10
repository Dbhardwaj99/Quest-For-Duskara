"""Generate Quest for Duskara's editable building sources and USD exports.

Run inside Blender. Every model is authored in one tile-sized unit, with Z up;
Blender's USD exporter records the coordinate system for RealityKit.
"""

from math import cos, radians, sin
from pathlib import Path

import bpy
from mathutils import Vector


BUILDINGS = Path(__file__).resolve().parent.parent
SOURCE = BUILDINGS / "Source"
MODELS = BUILDINGS / "Models"
PREVIEWS = BUILDINGS / "Previews"
for folder in (SOURCE, MODELS, PREVIEWS):
    folder.mkdir(parents=True, exist_ok=True)


COLORS = {
    "plaster": (0.93, 0.87, 0.75, 1),
    "terracotta": (0.79, 0.45, 0.36, 1),
    "terracotta_dark": (0.64, 0.34, 0.27, 1),
    "straw": (0.86, 0.73, 0.48, 1),
    "straw_dark": (0.70, 0.58, 0.37, 1),
    "timber": (0.38, 0.29, 0.21, 1),
    "wood": (0.64, 0.45, 0.32, 1),
    "cut_wood": (0.73, 0.56, 0.38, 1),
    "stone": (0.62, 0.58, 0.50, 1),
    "deep_stone": (0.48, 0.52, 0.55, 1),
    "smoke_stone": (0.56, 0.58, 0.60, 1),
    "lab_stone": (0.62, 0.74, 0.70, 1),
    "slate": (0.44, 0.50, 0.54, 1),
    "clay": (0.72, 0.48, 0.41, 1),
    "dirt": (0.50, 0.42, 0.30, 1),
    "walked_dirt": (0.58, 0.48, 0.36, 1),
    "crop_gold": (0.88, 0.75, 0.44, 1),
    "crop_green": (0.55, 0.67, 0.38, 1),
    "window": (1.00, 0.80, 0.47, 1),
    "arcane": (0.36, 0.62, 0.66, 1),
    "banner": (0.78, 0.38, 0.32, 1),
    "gold": (0.88, 0.72, 0.42, 1),
    "coal": (0.16, 0.17, 0.19, 1),
    "rope": (0.76, 0.64, 0.46, 1),
}


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            datablocks.remove(block)


def make_material(name, color, roughness=0.82, metallic=0.0, emission=0.0):
    linear = tuple(
        channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
        for channel in color[:3]
    ) + (color[3],)
    material = bpy.data.materials.new(name)
    material.diffuse_color = linear
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = linear
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if emission:
        emission_color = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        if emission_color:
            emission_color.default_value = linear
        emission_strength = shader.inputs.get("Emission Strength")
        if emission_strength:
            emission_strength.default_value = emission
    return material


def palette():
    return {
        name: make_material(
            name,
            color,
            roughness=0.42 if name in {"window", "arcane", "gold"} else 0.86,
            metallic=0.25 if name == "gold" else 0.0,
            emission=0.5 if name in {"window", "arcane"} else 0.0,
        )
        for name, color in COLORS.items()
    }


def finish(obj, name, material, bevel=0.0):
    obj.name = name
    obj.data.materials.append(material)
    if bevel:
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cube(name, location, size, material, rotation=(0, 0, 0), bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = Vector(size) / 2
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material, bevel)


def cylinder(name, location, radius, depth, material, vertices=12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    return finish(bpy.context.object, name, material, 0.004)


def sphere(name, location, radius, material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    return finish(bpy.context.object, name, material)


def gable_roof(name, location, width, depth, eave, ridge, material):
    x, y, z = location
    w, d = width / 2, depth / 2
    vertices = [
        (-w, -d, 0), (w, -d, 0), (-w, d, 0), (w, d, 0),
        (0, -d, ridge - eave), (0, d, ridge - eave),
    ]
    faces = [(0, 1, 4), (2, 5, 3), (0, 2, 3, 1), (0, 4, 5, 2), (1, 3, 5, 4)]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (x, y, z + eave)
    return finish(obj, name, material, 0.006)


def window(name, location, size, mats, rotation=(radians(90), 0, 0)):
    cube(name, location, (size[0], size[1], 0.018), mats["window"], rotation=rotation, bevel=0.003)
    cube(f"{name}_lintel", (location[0], location[1], location[2] + size[1] / 2), (size[0] + 0.025, 0.018, 0.018), mats["timber"], rotation=rotation, bevel=0.002)


def crate(name, location, mats, scale=1.0):
    cube(name, location, (0.10 * scale, 0.10 * scale, 0.09 * scale), mats["cut_wood"], rotation=(0, 0, radians(8)), bevel=0.006)
    cube(f"{name}_strap", (location[0], location[1] - 0.052 * scale, location[2]), (0.115 * scale, 0.012, 0.018), mats["timber"], bevel=0.002)


def barrel(name, location, mats, scale=1.0):
    cylinder(name, location, 0.045 * scale, 0.115 * scale, mats["wood"], vertices=12)
    for dz in (-0.04, 0.04):
        cylinder(f"{name}_band", (location[0], location[1], location[2] + dz * scale), 0.048 * scale, 0.010, mats["timber"], vertices=12)


def fence(start, count, horizontal, mats, prefix):
    for index in range(count):
        x = start[0] + (index * 0.12 if horizontal else 0)
        y = start[1] + (0 if horizontal else index * 0.12)
        cube(f"{prefix}_post_{index}", (x, y, 0.12), (0.025, 0.025, 0.16), mats["timber"], bevel=0.003)
    length = max(count - 1, 1) * 0.12
    center = (start[0] + length / 2, start[1], 0.14) if horizontal else (start[0], start[1] + length / 2, 0.14)
    size = (length + 0.03, 0.02, 0.025) if horizontal else (0.02, length + 0.03, 0.025)
    cube(f"{prefix}_rail", center, size, mats["wood"], bevel=0.003)


def build_house(m):
    cube("foundation", (-0.04, 0.00, 0.075), (0.49, 0.43, 0.06), m["stone"])
    cube("house_walls", (-0.04, 0.00, 0.27), (0.43, 0.38, 0.34), m["plaster"], bevel=0.015)
    gable_roof("terracotta_roof", (-0.055, 0.00, 0.44), 0.58, 0.50, 0.04, 0.18, m["terracotta"])
    cube("ridge_beam", (-0.055, 0.00, 0.625), (0.035, 0.54, 0.035), m["terracotta_dark"], bevel=0.004)
    for x in (-0.23, 0.15):
        cube(f"frame_vertical_{x}", (x, -0.198, 0.27), (0.025, 0.025, 0.31), m["timber"], bevel=0.003)
    cube("frame_crossbar", (-0.04, -0.198, 0.34), (0.40, 0.025, 0.025), m["timber"], bevel=0.003)
    cube("front_door", (0.045, -0.205, 0.19), (0.115, 0.025, 0.17), m["wood"], bevel=0.004)
    window("front_window", (-0.15, -0.205, 0.27), (0.11, 0.12), m)
    window("side_window", (-0.265, 0.04, 0.28), (0.09, 0.10), m, rotation=(radians(90), 0, radians(90)))
    cube("entry_step", (0.045, -0.26, 0.06), (0.17, 0.10, 0.035), m["stone"], bevel=0.005)
    cube("chimney", (0.13, 0.10, 0.60), (0.085, 0.085, 0.25), m["smoke_stone"], bevel=0.008)
    cube("chimney_cap", (0.13, 0.10, 0.735), (0.12, 0.11, 0.035), m["deep_stone"], bevel=0.004)
    cube("side_shed", (0.25, 0.10, 0.17), (0.20, 0.23, 0.22), m["wood"], bevel=0.012)
    cube("shed_roof", (0.25, 0.10, 0.30), (0.27, 0.28, 0.06), m["straw"], rotation=(0, radians(-7), 0), bevel=0.008)
    fence((-0.38, 0.29), 4, True, m, "house_fence")
    barrel("house_barrel", (-0.31, 0.22, 0.12), m)
    crate("house_crate", (0.31, 0.02, 0.10), m)


def build_farm(m):
    cube("field", (-0.10, 0.07, 0.075), (0.58, 0.48, 0.025), m["dirt"], bevel=0.02)
    for row in range(6):
        y = -0.16 + row * 0.075
        cube(f"crop_row_{row}", (-0.14, y, 0.10), (0.45, 0.025, 0.035), m["crop_gold" if row % 2 == 0 else "crop_green"], bevel=0.006)
        for plant in range(4):
            x = -0.31 + plant * 0.11
            cylinder(f"crop_{row}_{plant}", (x, y, 0.145), 0.012, 0.09, m["crop_gold" if row % 2 == 0 else "crop_green"], vertices=8)
    cube("barn_foundation", (0.25, 0.18, 0.075), (0.28, 0.25, 0.05), m["stone"])
    cube("barn", (0.25, 0.18, 0.22), (0.24, 0.21, 0.25), m["wood"], bevel=0.012)
    gable_roof("barn_roof", (0.25, 0.18, 0.32), 0.31, 0.27, 0.03, 0.13, m["straw"])
    cube("barn_door", (0.25, 0.062, 0.19), (0.12, 0.025, 0.14), m["timber"], bevel=0.004)
    for x in (0.14, 0.36):
        cube(f"barn_post_{x}", (x, 0.062, 0.22), (0.025, 0.025, 0.24), m["timber"], bevel=0.003)
    fence((-0.40, -0.30), 6, True, m, "farm_fence_front")
    fence((0.40, -0.28), 5, False, m, "farm_fence_side")
    cube("scarecrow_pole", (-0.35, 0.23, 0.18), (0.025, 0.025, 0.27), m["timber"], bevel=0.003)
    cube("scarecrow_arms", (-0.35, 0.23, 0.26), (0.20, 0.025, 0.025), m["timber"], rotation=(0, radians(8), 0), bevel=0.003)
    sphere("scarecrow_head", (-0.35, 0.23, 0.34), 0.045, m["straw"])
    cube("scarecrow_tunic", (-0.35, 0.225, 0.24), (0.10, 0.035, 0.09), m["banner"], bevel=0.004)
    cube("cart", (0.31, -0.05, 0.11), (0.20, 0.13, 0.07), m["wood"], rotation=(0, 0, radians(-6)), bevel=0.008)
    for x in (0.23, 0.39):
        cylinder(f"cart_wheel_{x}", (x, -0.12, 0.095), 0.045, 0.025, m["timber"], vertices=12, rotation=(radians(90), 0, 0))
    cube("hay_bale", (0.31, 0.35, 0.12), (0.16, 0.12, 0.12), m["straw"], bevel=0.025)
    cube("grain_sack", (0.06, -0.31, 0.10), (0.11, 0.09, 0.10), m["rope"], bevel=0.02)


def build_pier(m):
    cube("shore_patch", (0, 0.08, 0.035), (0.48, 0.56, 0.03), m["walked_dirt"], bevel=0.04)
    for index in range(7):
        y = 0.05 - index * 0.145
        cube(f"dock_plank_{index}", (0, y, 0.10), (0.28, 0.135, 0.035), m["cut_wood"], rotation=(0, 0, radians((-1) ** index * 1.2)), bevel=0.006)
    for index, y in enumerate((0.03, -0.35, -0.75)):
        depth = 0.34 if index < 2 else 0.54
        for x in (-0.125, 0.125):
            cylinder(f"dock_post_{index}_{x}", (x, y, 0.10 - depth / 2), 0.026, depth, m["timber"], vertices=10)
    cylinder("mooring_post", (0.125, -0.78, 0.19), 0.03, 0.20, m["timber"], vertices=10)
    cube("boat_hull", (-0.31, -0.68, 0.015), (0.19, 0.38, 0.08), m["wood"], rotation=(0, 0, radians(5)), bevel=0.03)
    cube("boat_inset", (-0.31, -0.68, 0.065), (0.14, 0.28, 0.035), m["coal"], rotation=(0, 0, radians(5)), bevel=0.02)
    cube("boat_seat", (-0.31, -0.68, 0.09), (0.17, 0.045, 0.025), m["cut_wood"], rotation=(0, 0, radians(5)), bevel=0.003)
    cylinder("oar", (-0.20, -0.66, 0.15), 0.012, 0.40, m["timber"], vertices=8, rotation=(radians(62), 0, radians(10)))
    crate("pier_crate", (0.29, 0.09, 0.10), m)
    barrel("pier_barrel", (-0.29, 0.12, 0.12), m)
    cylinder("lantern_post", (-0.13, -0.02, 0.23), 0.012, 0.26, m["timber"], vertices=8)
    cube("lantern", (-0.13, -0.02, 0.34), (0.055, 0.045, 0.07), m["window"], bevel=0.008)


def build_factory(m):
    cube("factory_foundation", (-0.04, 0.02, 0.095), (0.54, 0.47, 0.10), m["smoke_stone"], bevel=0.012)
    cube("workshop_hall", (-0.05, 0.02, 0.31), (0.44, 0.38, 0.36), m["lab_stone"], bevel=0.016)
    gable_roof("slate_roof", (-0.05, 0.02, 0.46), 0.56, 0.48, 0.04, 0.15, m["slate"])
    cube("gold_course", (-0.05, -0.18, 0.45), (0.47, 0.025, 0.035), m["gold"], bevel=0.003)
    cylinder("smokestack", (0.23, 0.12, 0.44), 0.075, 0.55, m["smoke_stone"], vertices=12)
    cylinder("stack_cap", (0.23, 0.12, 0.72), 0.095, 0.05, m["deep_stone"], vertices=12)
    sphere("vent_glow", (0.23, 0.12, 0.77), 0.045, m["arcane"])
    cube("front_door", (-0.04, -0.185, 0.20), (0.13, 0.025, 0.18), m["wood"], bevel=0.004)
    window("factory_window", (0.12, -0.185, 0.34), (0.10, 0.11), m)
    cylinder("side_pipe", (-0.29, 0.02, 0.34), 0.035, 0.40, m["arcane"], vertices=10, rotation=(radians(90), 0, 0))
    cylinder("side_flue", (-0.28, 0.24, 0.24), 0.045, 0.34, m["smoke_stone"], vertices=10)
    crate("factory_crate", (0.33, -0.22, 0.10), m)
    barrel("factory_barrel", (-0.32, 0.27, 0.12), m)
    for index in range(3):
        cube(f"ore_{index}", (0.30 + index * 0.035, 0.26 - index * 0.025, 0.075 + index * 0.012), (0.055, 0.045, 0.05), m["gold"], rotation=(radians(10), radians(index * 17), radians(index * 23)), bevel=0.008)


def build_barracks(m):
    cube("barracks_foundation", (-0.02, 0.00, 0.075), (0.62, 0.48, 0.06), m["deep_stone"], bevel=0.009)
    cube("barracks_hall", (-0.02, 0.00, 0.25), (0.56, 0.42, 0.32), m["clay"], bevel=0.014)
    gable_roof("barracks_roof", (-0.03, 0.00, 0.39), 0.68, 0.52, 0.04, 0.14, m["slate"])
    cube("roof_ridge", (-0.03, 0.00, 0.565), (0.035, 0.56, 0.035), m["gold"], bevel=0.004)
    for index, (x, y) in enumerate(((-0.31, -0.23), (0.27, -0.23), (-0.31, 0.23), (0.27, 0.23))):
        cube(f"corner_tower_{index}", (x, y, 0.29), (0.10, 0.10, 0.40), m["timber"], bevel=0.006)
        cube(f"tower_cap_{index}", (x, y, 0.51), (0.15, 0.15, 0.06), m["slate"], bevel=0.005)
    cube("barracks_door", (-0.10, -0.22, 0.21), (0.14, 0.025, 0.17), m["wood"], bevel=0.004)
    window("barracks_window", (0.13, -0.22, 0.28), (0.10, 0.11), m)
    for index, x in enumerate((-0.34, 0.30)):
        cylinder(f"banner_pole_{index}", (x, -0.27, 0.48), 0.014, 0.48, m["timber"], vertices=8)
        cube(f"banner_{index}", (x + (0.07 if index else -0.07), -0.27, 0.58), (0.14, 0.025, 0.14), m["banner"], bevel=0.003)
        sphere(f"banner_finial_{index}", (x, -0.27, 0.73), 0.035, m["gold"])
    cube("weapon_rack", (0.30, 0.28, 0.16), (0.22, 0.04, 0.04), m["timber"], bevel=0.003)
    for index in range(3):
        x = 0.23 + index * 0.07
        cylinder(f"spear_{index}", (x, 0.28, 0.27), 0.009, 0.30, m["wood"], vertices=8, rotation=(0, radians(-7 + index * 7), 0))
        cube(f"spear_tip_{index}", (x, 0.28, 0.43), (0.025, 0.018, 0.05), m["deep_stone"], bevel=0.002)
    cylinder("target_post", (-0.33, 0.24, 0.20), 0.015, 0.25, m["timber"], vertices=8)
    cylinder("training_target", (-0.33, 0.225, 0.34), 0.075, 0.035, m["banner"], vertices=16, rotation=(radians(90), 0, 0))
    cylinder("target_center", (-0.33, 0.205, 0.34), 0.035, 0.04, m["gold"], vertices=16, rotation=(radians(90), 0, 0))
    for index in range(6):
        angle = radians(index * 60)
        x = 0.30 + 0.06 * cos(angle)
        y = 0.08 + 0.06 * sin(angle)
        sphere(f"fire_ring_{index}", (x, y, 0.075), 0.028, m["stone"])
    sphere("fire", (0.30, 0.08, 0.12), 0.045, m["window"])


def setup_render(name, pier=False):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.055, 0.075, 0.10)

    bpy.ops.object.camera_add(location=(1.35, -1.80 if not pier else -2.25, 1.35))
    camera = bpy.context.object
    camera.name = "PreviewCamera"
    target = Vector((0, -0.08 if not pier else -0.28, 0.28))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 58
    scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(-1.2, -1.4, 2.3))
    key = bpy.context.object
    key.name = "KeyLight"
    key.data.energy = 90
    key.data.shape = "DISK"
    key.data.size = 3.0
    key.rotation_euler = ((Vector((0, 0, 0.25)) - key.location).to_track_quat("-Z", "Y").to_euler())
    bpy.ops.object.light_add(type="AREA", location=(1.5, 0.8, 1.5))
    bpy.context.object.data.energy = 45
    bpy.context.object.data.size = 2.0
    scene.render.filepath = str(PREVIEWS / f"{name}.png")


def export(name, builder):
    reset_scene()
    mats = palette()
    builder(mats)
    setup_render(name, pier=name == "pier")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"))
    kwargs = dict(
        filepath=str(MODELS / f"building_{name}.usdc"),
        export_animation=False,
        export_materials=True,
        export_cameras=False,
        export_lights=False,
        evaluation_mode="RENDER",
    )
    try:
        bpy.ops.wm.usd_export(**kwargs)
    except TypeError:
        bpy.ops.wm.usd_export(filepath=kwargs["filepath"])
    print(f"Exported {name}")


for building_name, builder in (
    ("house", build_house),
    ("farm", build_farm),
    ("pier", build_pier),
    ("factory", build_factory),
    ("barracks", build_barracks),
):
    export(building_name, builder)

print("QUEST_FOR_DUSKARA_BUILDINGS_COMPLETE")
