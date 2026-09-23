"""Generate the small, reusable USDZ settlement pieces with Blender.

Run: Blender -b --python Tools/generate_settlement_models.py
The scene is deliberately made from bevelled geometry and named material groups:
RealityKit recolors those groups through the current WorldPalette.
"""

import bpy
import math
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = Path("/tmp/duskara-settlement-models")
OUT.mkdir(exist_ok=True)

COLORS = {
    "plaster": (0.93, 0.87, 0.75),
    "terracotta": (0.79, 0.45, 0.36),
    "roofClay": (0.79, 0.45, 0.36),
    "terracottaDark": (0.64, 0.34, 0.27),
    "roofHighlight": (0.88, 0.56, 0.45),
    "timber": (0.56, 0.42, 0.29),
    "darkTimber": (0.38, 0.29, 0.21),
    "doorWood": (0.44, 0.31, 0.22),
    "stone": (0.70, 0.66, 0.58),
    "warmWindow": (1.00, 0.80, 0.47),
    "strawRoof": (0.86, 0.73, 0.48),
    "roofStraw": (0.86, 0.73, 0.48),
    "strawShadow": (0.70, 0.58, 0.37),
    "slateRoof": (0.44, 0.50, 0.54),
    "roofSlate": (0.44, 0.50, 0.54),
    "warmGold": (0.88, 0.72, 0.42),
    "cropGreen": (0.55, 0.67, 0.38),
    "fortifiedClay": (0.72, 0.48, 0.41),
    "labStone": (0.62, 0.74, 0.70),
    "smokeStone": (0.56, 0.58, 0.60),
    "bannerRed": (0.78, 0.38, 0.32),
    "cropGold": (0.88, 0.75, 0.44),
}


def material(name):
    if name not in bpy.data.materials:
        mat = bpy.data.materials.new(name)
        rgb = COLORS[name]
        mat.diffuse_color = (*rgb, 1)
        mat.use_nodes = True
        mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*rgb, 1)
        mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.88
    return bpy.data.materials[name]


def soften(obj, bevel):
    if bevel:
        mod = obj.modifiers.new("soft sculpted edge", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for face in obj.data.polygons:
        face.use_smooth = True
    mod = obj.modifiers.new("clay normals", "WEIGHTED_NORMAL")
    mod.weight = 50
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def box(name, at, size, color, bevel=0.05, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    if rotation:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(color))
    soften(obj, min(bevel, min(size) * 0.25))
    return obj


def roof(width, depth, eave, rise, color="terracotta"):
    # A single thick, gently arched clay sheet mirrors the current game's
    # molded roofs. Fine tile stripes made the first pass look like a kit set.
    steps = 16
    vertices = []
    for under in (False, True):
        for side in (-1, 1):
            for index in range(steps + 1):
                u = index / steps * 2 - 1
                x = u * width / 2
                z = eave + rise * (1 - abs(u) ** 1.55) - (0.085 if under else 0)
                vertices.append((x, side * depth / 2, z))
    faces = []
    row = steps + 1
    for under in (False, True):
        base = (2 if under else 0) * row
        for index in range(steps):
            a, b = base + index, base + index + 1
            c, d = base + row + index, base + row + index + 1
            faces.append((a, b, d, c) if not under else (c, d, b, a))
    for side in range(2):
        front = side * row
        back = (side + 2) * row
        for index in range(steps):
            faces.append((front + index, back + index, back + index + 1, front + index + 1))
    for index in (0, steps):
        faces.append((index, row + index, 3 * row + index, 2 * row + index))
    mesh = bpy.data.meshes.new("molded_roof")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    roof_color = {"terracotta": "roofClay", "strawRoof": "roofStraw", "slateRoof": "roofSlate"}[color]
    obj = bpy.data.objects.new(roof_color, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(roof_color))
    soften(obj, 0.024)
    box("roof_lip", (0, -depth / 2 - 0.014, eave - 0.045),
        (width * 0.95, 0.038, 0.033),
        "terracottaDark" if color == "terracotta" else "strawShadow" if color == "strawRoof" else "smokeStone", 0.014)
    return obj


def round_column(name, at, radius, height, color, vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=height, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material(color))
    soften(obj, min(0.035, radius * 0.22, height * 0.15))
    return obj


def cone(name, at, radius, height, color):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=radius, radius2=0.025,
                                    depth=height, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material(color))
    soften(obj, 0.024)
    return obj


def window(x, y, z, width=0.16, height=0.18):
    box("window_reveal", (x, y - 0.008, z), (width + 0.065, 0.045, height + 0.065), "stone", 0.037)
    box("window_glow", (x, y - 0.039, z), (width, 0.025, height), "warmWindow", 0.035)
    box("window_sill", (x, y - 0.066, z - height / 2 - 0.045),
        (width + 0.14, 0.10, 0.055), "plaster", 0.024)


def door(x, y, height=0.32, width=0.19):
    box("door_reveal", (x, y - 0.008, height / 2 + 0.05),
        (width + 0.10, 0.045, height + 0.09), "stone", 0.06)
    box("door", (x, y - 0.041, height / 2 + 0.05),
        (width, 0.035, height), "doorWood", 0.055)
    box("door_step", (x, y - 0.14, 0.035),
        (width + 0.20, 0.23, 0.07), "stone", 0.032)
    round_column("door_knob", (x + width * 0.31, y - 0.072, height / 2 + 0.04),
                 0.018, 0.028, "warmGold", 12)


def chimney(x, y, top):
    round_column("clay_chimney", (x, y, top - 0.12), 0.085, 0.34, "smokeStone")
    round_column("chimney_cap", (x, y, top + 0.075), 0.12, 0.05, "stone")


def flower_pot(x, y, size=1):
    round_column("flower_pot", (x, y, 0.09 * size), 0.07 * size, 0.15 * size, "terracotta", 16)
    round_column("flower_stems", (x, y, 0.18 * size), 0.035 * size, 0.10 * size, "cropGreen", 12)
    cone("flower_head", (x, y, 0.26 * size), 0.04 * size, 0.05 * size, "warmGold")


def cottage_a():
    box("stone_foundation", (0, 0, 0.07), (1.02, 0.82, 0.14), "stone", 0.10)
    box("plaster", (0, 0.03, 0.47), (0.88, 0.68, 0.67), "plaster", 0.11)
    roof(1.10, 0.88, 0.78, 0.30)
    door(0.17, -0.32)
    window(-0.22, -0.33, 0.53)
    chimney(0.30, 0.17, 1.05)
    flower_pot(-0.36, -0.47, 0.70)
    box("front_beam", (-0.43, -0.33, 0.48), (0.06, 0.07, 0.62), "timber", 0.026)


def cottage_b():
    box("stone_foundation", (0, 0, 0.06), (0.94, 0.86, 0.12), "stone", 0.10)
    box("plaster", (-0.06, 0, 0.44), (0.76, 0.72, 0.66), "plaster", 0.12)
    roof(0.94, 0.86, 0.77, 0.29, "strawRoof")
    door(-0.19, -0.36)
    window(0.13, -0.36, 0.51, 0.13, 0.16)
    round_column("plaster_turret", (0.35, 0.22, 0.42), 0.19, 0.72, "plaster")
    cone("terracotta_turret_roof", (0.35, 0.22, 0.93), 0.26, 0.38, "roofClay")
    round_column("roof_finial", (0.35, 0.22, 1.15), 0.035, 0.07, "warmGold", 12)
    flower_pot(0.23, -0.48, 0.62)


def townhouse():
    box("stone_foundation", (0, 0, 0.08), (1.08, 0.93, 0.16), "stone", 0.11)
    box("plaster", (0, 0.04, 0.72), (0.92, 0.78, 1.18), "plaster", 0.13)
    roof(1.13, 0.95, 1.32, 0.36)
    door(0, -0.36, 0.41, 0.23)
    for x in (-0.29, 0.29):
        window(x, -0.36, 0.75, 0.14, 0.18)
        window(x, -0.36, 1.09, 0.14, 0.18)
    box("balcony", (0, -0.51, 0.90), (0.80, 0.25, 0.075), "stone", 0.045)
    for x in (-0.35, 0, 0.35):
        round_column("balcony_rail", (x, -0.61, 1.03), 0.025, 0.23, "plaster", 12)
    chimney(0.28, 0.23, 1.69)
    flower_pot(-0.49, -0.46, 0.65)


def barn():
    box("stone_foundation", (0, 0, 0.07), (1.16, 0.90, 0.14), "stone", 0.11)
    box("timber_barn", (0, 0.02, 0.53), (1.01, 0.77, 0.82), "timber", 0.12)
    roof(1.24, 0.95, 0.94, 0.40, "strawRoof")
    door(0, -0.39, 0.57, 0.40)
    round_column("loft_window", (0, -0.406, 0.84), 0.10, 0.04, "warmWindow", 16)
    for x in (-0.42, 0.42):
        round_column("timber_post", (x, -0.39, 0.48), 0.045, 0.73, "darkTimber", 12)
    for x in (-0.30, 0.26):
        box("hay_bale", (x, -0.58, 0.13), (0.26, 0.23, 0.20), "strawRoof", 0.07)


def farmstead():
    box("stone_foundation", (0, 0, 0.07), (1.16, 0.82, 0.14), "stone", 0.11)
    box("plaster", (-0.08, 0.03, 0.41), (0.88, 0.65, 0.62), "plaster", 0.12)
    roof(1.04, 0.85, 0.73, 0.30, "strawRoof")
    door(-0.25, -0.30, 0.31, 0.18)
    window(0.08, -0.30, 0.49, 0.13, 0.14)
    round_column("grain_silo", (0.42, 0.18, 0.39), 0.20, 0.66, "plaster")
    cone("grain_silo_roof", (0.42, 0.18, 0.82), 0.26, 0.29, "roofStraw")
    for x in (-0.40, -0.25):
        box("harvest_sack", (x, -0.48, 0.12), (0.16, 0.21, 0.18), "strawRoof", 0.07)


def granary():
    for x in (-0.27, 0.27):
        for y in (-0.25, 0.25):
            round_column("stone_post", (x, y, 0.23), 0.07, 0.44, "stone", 12)
    round_column("timber_floor", (0, 0, 0.47), 0.49, 0.10, "timber")
    round_column("plaster_store", (0, 0, 0.82), 0.40, 0.63, "plaster", 24)
    cone("strawRoof", (0, 0, 1.26), 0.50, 0.36, "roofStraw")
    box("doorWood_hatch", (0, -0.41, 0.75), (0.18, 0.05, 0.28), "doorWood", 0.06)
    box("timber_ladder", (0.31, -0.44, 0.30), (0.055, 0.07, 0.51), "timber", 0.02,
        (0.17, 0, 0))
    for x in (-0.30, 0.27):
        box("grain_sack", (x, -0.54, 0.11), (0.24, 0.22, 0.18), "strawRoof", 0.07)


def shed():
    box("stone_foundation", (0, 0, 0.05), (0.80, 0.67, 0.10), "stone", 0.08)
    box("plaster", (0, 0.02, 0.33), (0.69, 0.56, 0.49), "plaster", 0.10)
    roof(0.87, 0.72, 0.57, 0.23, "strawRoof")
    door(0.09, -0.28, 0.27, 0.17)
    box("timber_store", (-0.26, -0.38, 0.12), (0.17, 0.21, 0.23), "timber", 0.045)
    window(-0.20, -0.28, 0.43, 0.10, 0.12)
    round_column("clay_post", (-0.32, -0.28, 0.34), 0.035, 0.48, "stone", 12)


def workshop():
    box("stone_foundation", (0, 0, 0.08), (1.14, 0.94, 0.16), "stone", 0.12)
    box("labStone", (0, 0.03, 0.49), (1.00, 0.77, 0.70), "labStone", 0.13)
    roof(1.20, 0.96, 0.87, 0.34, "slateRoof")
    door(-0.18, -0.37, 0.39, 0.20)
    window(0.23, -0.37, 0.52, 0.15, 0.19)
    chimney(0.35, 0.20, 1.22)
    box("workbench", (0.35, -0.58, 0.18), (0.44, 0.24, 0.09), "timber", 0.045)
    box("crate", (0.50, -0.49, 0.13), (0.19, 0.19, 0.20), "timber", 0.045)


def forge():
    box("stone_foundation", (0, 0, 0.07), (0.96, 0.80, 0.14), "stone", 0.11)
    box("smokeStone", (-0.09, 0.03, 0.41), (0.72, 0.66, 0.58), "smokeStone", 0.11)
    roof(0.95, 0.79, 0.71, 0.25, "slateRoof")
    round_column("kiln", (0.33, 0.14, 0.64), 0.18, 1.04, "smokeStone")
    round_column("kiln_cap", (0.33, 0.14, 1.18), 0.22, 0.08, "stone")
    box("furnace_reveal", (0.30, -0.36, 0.32), (0.29, 0.06, 0.36), "stone", 0.08)
    box("furnace_glow", (0.30, -0.40, 0.30), (0.19, 0.025, 0.22), "warmGold", 0.055)
    box("anvil", (-0.28, -0.51, 0.22), (0.31, 0.20, 0.12), "smokeStone", 0.05)
    box("anvil_base", (-0.28, -0.51, 0.10), (0.15, 0.15, 0.20), "timber", 0.03)
    door(-0.18, -0.32, 0.28, 0.16)


def foundry():
    box("stone_foundation", (0, 0, 0.08), (1.20, 0.93, 0.16), "stone", 0.12)
    box("labStone", (-0.12, 0.03, 0.55), (0.91, 0.74, 0.82), "labStone", 0.13)
    roof(1.12, 0.94, 0.95, 0.36, "slateRoof")
    door(-0.19, -0.37, 0.45, 0.25)
    window(0.18, -0.37, 0.60, 0.13, 0.18)
    for y, h in ((-0.18, 1.38), (0.20, 1.55)):
        round_column("smoke_stack", (0.42, y, h * 0.56), 0.11, h * 0.86, "smokeStone")
        round_column("smoke_stack_cap", (0.42, y, h), 0.15, 0.07, "stone")
    box("furnace_reveal", (0.41, -0.38, 0.39), (0.28, 0.07, 0.43), "stone", 0.08)
    box("furnace_glow", (0.41, -0.43, 0.34), (0.18, 0.025, 0.27), "warmGold", 0.06)
    box("ore_cart", (-0.48, -0.51, 0.19), (0.26, 0.28, 0.22), "timber", 0.07)


def barracks_hut():
    box("stone_foundation", (0, 0, 0.07), (1.04, 0.86, 0.14), "stone", 0.11)
    box("fortifiedClay", (-0.07, 0, 0.46), (0.83, 0.70, 0.68), "fortifiedClay", 0.12)
    roof(1.06, 0.86, 0.81, 0.31, "slateRoof")
    door(0.12, -0.35, 0.36, 0.19)
    window(-0.23, -0.35, 0.52, 0.11, 0.15)
    round_column("watch_turret", (0.39, 0.23, 0.52), 0.18, 0.94, "plaster")
    cone("turret_roof", (0.39, 0.23, 1.12), 0.24, 0.34, "roofClay")
    round_column("banner_pole", (-0.46, -0.36, 1.05), 0.023, 0.65, "darkTimber", 12)
    box("banner", (-0.34, -0.37, 1.21), (0.23, 0.025, 0.19), "bannerRed", 0.025)


def armory():
    box("stone_foundation", (0, 0, 0.07), (0.96, 0.85, 0.14), "stone", 0.10)
    box("fortifiedClay", (0, 0, 0.45), (0.82, 0.69, 0.65), "fortifiedClay", 0.12)
    roof(1.05, 0.88, 0.79, 0.28, "slateRoof")
    door(0.12, -0.34, 0.35, 0.24)
    round_column("watch_post", (-0.40, 0.21, 0.50), 0.16, 0.91, "plaster")
    cone("watch_post_roof", (-0.40, 0.21, 1.07), 0.21, 0.31, "roofSlate")
    box("spear_rack", (-0.28, -0.48, 0.32), (0.32, 0.06, 0.07), "timber", 0.02)
    for x in (-0.37, -0.27, -0.17):
        round_column("spear", (x, -0.48, 0.43), 0.014, 0.53, "darkTimber", 10)
        cone("spear_tip", (x, -0.48, 0.72), 0.027, 0.08, "stone")


def watchtower():
    round_column("stone_base", (0, 0, 0.16), 0.42, 0.32, "stone")
    round_column("fortifiedClay", (0, 0, 0.96), 0.35, 1.33, "plaster")
    round_column("stone_gallery", (0, 0, 1.69), 0.48, 0.14, "stone")
    cone("slateRoof", (0, 0, 2.00), 0.52, 0.49, "roofSlate")
    door(0, -0.36, 0.35, 0.17)
    for z in (0.92, 1.38):
        box("arrow_slit", (0, -0.353, z), (0.06, 0.025, 0.19), "darkTimber", 0.018)
    for x in (-0.36, 0.36):
        round_column("gallery_post", (x, -0.35, 1.82), 0.029, 0.26, "stone", 12)
    round_column("banner_pole", (0.41, -0.36, 2.23), 0.026, 0.72, "darkTimber", 12)
    box("banner", (0.55, -0.36, 2.31), (0.26, 0.025, 0.25), "bannerRed", 0.025)


def jetty():
    # Local +Y is seaward in Blender; the renderer turns it to the chosen shore.
    for i in range(8):
        y = -0.40 + i * 0.17
        box("deck_plank", (0, y, 0.23 + (i % 3) * 0.006),
            (0.66 - (i % 2) * 0.035, 0.15, 0.07), "timber", 0.035)
    for y in (-0.30, 0.28, 0.82):
        for x in (-0.29, 0.29):
            round_column("dock_post", (x, y, 0.09), 0.054, 0.44, "darkTimber", 12)
            round_column("rope_cap", (x, y, 0.33), 0.073, 0.05, "stone", 12)
    box("cargo_crate", (-0.19, -0.28, 0.36), (0.27, 0.26, 0.25), "timber", 0.055)
    box("cargo_sack", (0.20, -0.27, 0.33), (0.22, 0.27, 0.18), "strawRoof", 0.08)


def boathouse():
    box("stone_foundation", (0, 0, 0.07), (1.02, 0.84, 0.14), "stone", 0.11)
    box("labStone", (0, 0.02, 0.43), (0.87, 0.68, 0.64), "labStone", 0.12)
    roof(1.10, 0.87, 0.77, 0.34, "slateRoof")
    box("boat_door_reveal", (0, -0.33, 0.36), (0.41, 0.06, 0.52), "stone", 0.12)
    box("boat_door", (0, -0.37, 0.33), (0.30, 0.035, 0.41), "doorWood", 0.10)
    window(-0.31, -0.33, 0.55, 0.09, 0.13)
    round_column("mast", (0.39, -0.41, 0.48), 0.024, 0.86, "timber", 12)
    box("sailcloth", (0.54, -0.41, 0.59), (0.29, 0.023, 0.30), "strawRoof", 0.07)
    box("mooring_crate", (-0.44, -0.48, 0.13), (0.18, 0.20, 0.20), "timber", 0.05)


def harbor_store():
    box("stone_foundation", (0, 0, 0.07), (1.12, 0.86, 0.14), "stone", 0.11)
    box("labStone", (0, 0.03, 0.47), (0.98, 0.72, 0.70), "labStone", 0.12)
    roof(1.17, 0.91, 0.87, 0.31, "slateRoof")
    door(0, -0.35, 0.48, 0.32)
    window(-0.33, -0.35, 0.57, 0.12, 0.17)
    round_column("dock_bollard", (0.48, -0.48, 0.17), 0.08, 0.28, "timber", 12)
    for x in (-0.35, 0.31):
        box("cargo_sack", (x, -0.52, 0.12), (0.19, 0.22, 0.20), "strawRoof", 0.07)


def beacon():
    round_column("stone_foundation", (0, 0, 0.13), 0.43, 0.26, "stone")
    round_column("plaster_tower", (0, 0, 0.78), 0.32, 1.14, "plaster")
    round_column("lantern_gallery", (0, 0, 1.40), 0.43, 0.12, "stone")
    round_column("warmWindow_lantern", (0, 0, 1.61), 0.24, 0.35, "warmWindow")
    cone("beacon_roof", (0, 0, 1.97), 0.39, 0.41, "roofSlate")
    door(0, -0.33, 0.36, 0.19)
    for z in (0.78, 1.09):
        box("tower_window", (0, -0.33, z), (0.11, 0.025, 0.15), "warmWindow", 0.04)
    round_column("roof_finial", (0, 0, 2.21), 0.035, 0.09, "warmGold", 12)


def warehouse():
    box("stone_foundation", (0, 0, 0.07), (1.14, 0.88, 0.14), "stone", 0.11)
    box("labStone", (0, 0, 0.49), (1.01, 0.74, 0.72), "labStone", 0.13)
    roof(1.22, 0.91, 0.89, 0.34, "slateRoof")
    door(0, -0.37, 0.52, 0.39)
    for x in (-0.40, 0.40):
        box("crate", (x, -0.56, 0.14), (0.21, 0.22, 0.24), "timber", 0.06)
    window(0, -0.37, 0.79, 0.15, 0.13)


MODELS = {
    "cottage_a": cottage_a,
    "cottage_b": cottage_b,
    "townhouse": townhouse,
    "barn": barn,
    "farmstead": farmstead,
    "granary": granary,
    "shed": shed,
    "workshop": workshop,
    "forge": forge,
    "foundry": foundry,
    "barracks_hut": barracks_hut,
    "armory": armory,
    "watchtower": watchtower,
    "jetty": jetty,
    "boathouse": boathouse,
    "harbor_store": harbor_store,
    "beacon": beacon,
    "warehouse": warehouse,
}


def consolidate():
    # One mesh per material instead of one draw call per roof tile or window bar.
    for mat_name in COLORS:
        items = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.active_material and o.active_material.name == mat_name]
        if not items:
            continue
        if len(items) == 1:
            items[0].name = mat_name
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for item in items:
            item.select_set(True)
        bpy.context.view_layer.objects.active = items[0]
        bpy.ops.object.join()
        items[0].name = mat_name


for name, create in MODELS.items():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    create()
    consolidate()
    bpy.ops.wm.usd_export(
        filepath=str(OUT / f"settlement_{name}.usdc"),
        export_materials=True,
        generate_preview_surface=True,
        convert_orientation=True,
        export_global_up_selection="Y",
        convert_world_material=False,
        export_lights=False,
        export_cameras=False,
    )
    subprocess.run([
        "usdzip", "--checkCompliance", "--arkitAsset",
        str(OUT / f"settlement_{name}.usdc"),
        str(ROOT / "Assets" / f"settlement_{name}.usdz"),
    ], check=True)
    subprocess.run(["usdcat", "-l", str(ROOT / "Assets" / f"settlement_{name}.usdz")],
                   check=True, stdout=subprocess.DEVNULL)
    print(f"EXPORTED settlement_{name}")
