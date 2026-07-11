import bpy
import math
import os
import json
import zipfile
from mathutils import Vector, Matrix

ROOT = "/Users/aaa/Desktop/Quest For Duskara"
OUT = os.path.join(ROOT, "assets")
SRC = os.path.join(OUT, "source")
QA = os.path.join(OUT, "qa")
for path in (OUT, SRC, QA):
    os.makedirs(path, exist_ok=True)

FPS, END = 24, 240
TAU = math.tau
MAT = {}

COLORS = {
    "plaster": "F2ECDD", "cream": "EFE3C8", "roof_terracotta": "D08069",
    "roof_highlight": "E39A82", "dusty_red": "C4746A", "straw": "E3CE93",
    "timber_mid": "8F7358", "timber_dark": "63513F", "door_wood": "6E5140",
    "sage": "93AF74", "sand": "F0DDA4", "stone_plinth": "A99F8A",
    "smoke_stone": "939CA1", "slate": "75858E", "muted_teal": "A8C6BF",
    "arcane_teal": "6BA4AC", "window_glow": "FFCF84", "warm_gold": "E0BC77",
    "field_dirt": "8F7658", "fortified_clay": "B97B69", "crop_gold": "E0BF70"
}


def rgba(hex_value):
    h = hex_value.lstrip("#")
    return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4)) + (1,)


def material(name):
    if name in MAT:
        return MAT[name]
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgba(COLORS[name])
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(COLORS[name])
    bsdf.inputs["Roughness"].default_value = 0.88
    bsdf.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.22
    if name == "window_glow":
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = rgba(COLORS[name])
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 0.5
    MAT[name] = m
    return m


def clear_scene():
    global MAT
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights, bpy.data.actions):
        for block in list(datablocks):
            datablocks.remove(block)
    for library in list(bpy.data.libraries):
        bpy.data.libraries.remove(library)
    MAT = {}
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end, scene.render.fps = 1, END, FPS
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.055, 0.07, 0.085)
    return scene


def empty(name, parent=None, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.05
    obj.location = loc
    if parent:
        obj.parent = parent
    return obj


def mesh_obj(name, verts, faces, mat, parent=None):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(mat))
    if parent:
        obj.parent = parent
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def bevel(obj, width=0.008, segments=2):
    mod = obj.modifiers.new("soft_hand_sanded_edges", "BEVEL")
    mod.width, mod.segments = width, segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except RuntimeError:
        pass
    obj.select_set(False)
    return obj


def rounded_box(name, loc, scale, mat, parent=None, radius=0.018, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(mat))
    if parent:
        obj.parent = parent
    return bevel(obj, min(radius, min(scale) * 0.22), 3)


def sphere(name, loc, scale, mat, parent=None, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=max(8, segments // 2), location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(mat))
    if parent:
        obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def cylinder(name, loc, radius, depth, mat, parent=None, vertices=16, rot=(0, 0, 0), r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=r2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material(mat))
    if parent:
        obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = True
    return bevel(obj, min(0.008, radius * 0.16), 2)


def cone(name, loc, radius1, radius2, depth, mat, parent=None, vertices=20, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material(mat))
    if parent:
        obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = True
    return bevel(obj, min(0.008, radius1 * 0.12), 2)


def curve_tube(name, points, radius, mat, parent=None, cyclic=False, resolution=2):
    data = bpy.data.curves.new(name + "_curve", "CURVE")
    data.dimensions = "3D"
    data.resolution_u = resolution
    data.bevel_depth = radius
    data.bevel_resolution = 3
    spline = data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, co in zip(spline.bezier_points, points):
        bp.co = co
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(mat))
    if parent:
        obj.parent = parent
    return obj


def rounded_perimeter(w, d, radius, segments=6):
    pts = []
    for cx, cy, a0 in ((w/2-radius, d/2-radius, 0), (-w/2+radius, d/2-radius, 90),
                       (-w/2+radius, -d/2+radius, 180), (w/2-radius, -d/2+radius, 270)):
        for i in range(segments):
            a = math.radians(a0 + i * 90 / segments)
            pts.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    return pts


def sculpted_body(name, loc, size, mat, parent=None, lean=(0.0, 0.0), pillow=0.018, radius=0.09):
    w, d, h = size
    rings = 6
    base = rounded_perimeter(w, d, min(radius, w * .22, d * .22), 7)
    verts = []
    for iz in range(rings):
        t = iz / (rings - 1)
        taper = 1.0 - 0.035 * t
        bulge = 1.0 + pillow * math.sin(math.pi * t)
        ox, oy = lean[0] * t, lean[1] * t
        for x, y in base:
            verts.append((loc[0] + x * taper * bulge + ox, loc[1] + y * taper * bulge + oy, loc[2] + h * t))
    n = len(base)
    faces = []
    faces.append(tuple(range(n-1, -1, -1)))
    faces.append(tuple((rings-1)*n + i for i in range(n)))
    for iz in range(rings-1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((iz*n+i, iz*n+j, (iz+1)*n+j, (iz+1)*n+i))
    return bevel(mesh_obj(name, verts, faces, mat, parent), 0.008, 2)


def arch_points(width, height, steps=12, inset=0):
    w = width - 2 * inset
    r = w / 2
    spring = height - r - inset
    pts = [(-w/2, inset), (-w/2, spring)]
    for i in range(steps + 1):
        a = math.pi - math.pi * i / steps
        pts.append((r * math.cos(a), spring + r * math.sin(a)))
    pts.append((w/2, inset))
    return pts


def arch_frame(name, loc, width, height, depth, thick, mat, parent=None):
    outer, inner = arch_points(width, height, 14, 0), arch_points(width, height, 14, thick)
    verts = []
    for y in (-depth/2, depth/2):
        verts += [(loc[0]+x, loc[1]+y, loc[2]+z) for x, z in outer]
        verts += [(loc[0]+x, loc[1]+y, loc[2]+z) for x, z in inner]
    n = len(outer)
    faces = []
    for layer in (0, 2*n):
        for i in range(n-1):
            faces.append((layer+i, layer+i+1, layer+n+i+1, layer+n+i))
    for i in range(n-1):
        faces.append((i, 2*n+i, 2*n+i+1, i+1))
        faces.append((n+i, n+i+1, 3*n+i+1, 3*n+i))
    faces += [(0, n, 3*n, 2*n), (n-1, 2*n-1, 4*n-1, 3*n-1)]
    return bevel(mesh_obj(name, verts, faces, mat, parent), 0.004, 2)


def arch_fill(name, loc, width, height, depth, mat, parent=None):
    p = arch_points(width, height, 14, 0)
    verts = []
    for y in (-depth/2, depth/2):
        verts += [(loc[0]+x, loc[1]+y, loc[2]+z) for x, z in p]
    n = len(p)
    faces = [tuple(range(n)), tuple(range(2*n-1, n-1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n+j, n+i))
    return bevel(mesh_obj(name, verts, faces, mat, parent), 0.003, 2)


def family_window(name, center, size, facing, body_group, props_group, shutters=False, flowers=False):
    w, h = size
    x, y, z = center
    if facing == "front":
        pane = arch_fill(name+"_glow", (x, y+0.018, z-h/2), w*.72, h*.78, .012, "window_glow", body_group)
        arch_frame(name+"_frame", (x, y, z-h/2), w, h, .045, .025, "timber_dark", body_group)
        rounded_box(name+"_sill", (x, y-.025, z-h*.48), (w*1.08, .055, .035), "timber_dark", body_group, .012)
        if shutters:
            for s in (-1, 1):
                rounded_box(name+f"_shutter_{s}", (x+s*w*.57, y+.005, z), (w*.28, .025, h*.72), "dusty_red", props_group, .009, (0, 0, s*.08))
        if flowers:
            rounded_box(name+"_flower_box", (x, y-.07, z-h*.42), (w*.8, .09, .055), "timber_dark", props_group, .014)
            for i, c in enumerate((-0.05, 0, .05)):
                stem = cylinder(name+f"_flower_stem_{i}", (x+c, y-.08, z-h*.31), .008, .075, "sage", props_group, 10)
                head = sphere(name+f"_flower_head_{i}", (x+c, y-.08, z-h*.26), (.018, .018, .016), "dusty_red", props_group, 12)
                animate_component(head, "rotation_euler", 1, 0, math.radians(1.5), i*1.3)
    return pane


def sag_roof(name, center, width, depth, base_z, height, mat, parent=None, sag=.025, thickness=.035, nx=8, ny=8):
    verts, faces = [], []
    for shell in (0, 1):
        for ix in range(nx+1):
            x = -width/2 + width*ix/nx
            ridge_drop = .018 * (abs(x)/(width/2))**2
            for iy in range(ny+1):
                y = -depth/2 + depth*iy/ny
                q = abs(2*y/depth)
                z = base_z + height*(1-q) - sag*math.sin(math.pi*q) - ridge_drop - shell*thickness
                verts.append((center[0]+x, center[1]+y, z))
    stride = (nx+1)*(ny+1)
    for shell in (0, 1):
        off = shell*stride
        for ix in range(nx):
            for iy in range(ny):
                a = off + ix*(ny+1)+iy
                quad = (a, a+ny+1, a+ny+2, a+1)
                faces.append(quad if shell == 0 else tuple(reversed(quad)))
    perimeter = []
    for iy in range(ny+1): perimeter.append(iy)
    for ix in range(1, nx+1): perimeter.append(ix*(ny+1)+ny)
    for iy in range(ny-1, -1, -1): perimeter.append(nx*(ny+1)+iy)
    for ix in range(nx-1, 0, -1): perimeter.append(ix*(ny+1))
    for a, b in zip(perimeter, perimeter[1:]+perimeter[:1]):
        faces.append((a, b, stride+b, stride+a))
    obj = mesh_obj(name, verts, faces, mat, parent)
    curve_tube(name+"_ridge", [(center[0]-width*.48, center[1], base_z+height-.018), (center[0], center[1], base_z+height+.004), (center[0]+width*.48, center[1], base_z+height-.018)], .026, mat, parent)
    for side in (-1, 1):
        curve_tube(name+f"_fascia_{side}", [(center[0]-width/2, center[1]+side*depth/2, base_z-.018), (center[0], center[1]+side*depth/2, base_z-.025), (center[0]+width/2, center[1]+side*depth/2, base_z-.018)], .018, mat, parent)
    return obj


def mono_roof(name, center, width, depth, z_back, rise, mat, parent=None):
    verts = []
    nx, ny, t = 8, 6, .035
    for shell in (0, 1):
        for ix in range(nx+1):
            x = -width/2 + width*ix/nx
            for iy in range(ny+1):
                y = -depth/2 + depth*iy/ny
                q = (y/depth)+.5
                z = z_back + rise*q - .018*math.sin(math.pi*q) - .012*(abs(x)/(width/2))**2 - shell*t
                verts.append((center[0]+x, center[1]+y, z))
    stride=(nx+1)*(ny+1); faces=[]
    for s in (0,1):
        off=s*stride
        for ix in range(nx):
            for iy in range(ny):
                a=off+ix*(ny+1)+iy; q=(a,a+ny+1,a+ny+2,a+1)
                faces.append(q if s==0 else tuple(reversed(q)))
    per=list(range(ny+1))+[i*(ny+1)+ny for i in range(1,nx+1)]+[nx*(ny+1)+i for i in range(ny-1,-1,-1)]+[i*(ny+1) for i in range(nx-1,0,-1)]
    for a,b in zip(per,per[1:]+per[:1]): faces.append((a,b,stride+b,stride+a))
    return mesh_obj(name, verts, faces, mat, parent)


def barrel_roof(name, center, width, depth, base_z, rise, mat, parent=None):
    nx, ny, t = 8, 12, .035
    verts, faces = [], []
    for shell in (0,1):
        for ix in range(nx+1):
            x=-width/2+width*ix/nx
            for iy in range(ny+1):
                y=-depth/2+depth*iy/ny
                q=2*y/depth
                z=base_z + rise*math.sqrt(max(0,1-q*q)) - .012*(abs(x)/(width/2))**2 - shell*t
                verts.append((center[0]+x, center[1]+y, z))
    stride=(nx+1)*(ny+1)
    for s in (0,1):
        off=s*stride
        for ix in range(nx):
            for iy in range(ny):
                a=off+ix*(ny+1)+iy; q=(a,a+ny+1,a+ny+2,a+1)
                faces.append(q if s==0 else tuple(reversed(q)))
    per=list(range(ny+1))+[i*(ny+1)+ny for i in range(1,nx+1)]+[nx*(ny+1)+i for i in range(ny-1,-1,-1)]+[i*(ny+1) for i in range(nx-1,0,-1)]
    for a,b in zip(per,per[1:]+per[:1]): faces.append((a,b,stride+b,stride+a))
    obj=mesh_obj(name,verts,faces,mat,parent)
    curve_tube(name+"_crown",[(center[0]-width*.47,center[1],base_z+rise-.01),(center[0],center[1],base_z+rise+.008),(center[0]+width*.47,center[1],base_z+rise-.01)],.022,mat,parent)
    return obj


def chimney(name, loc, height, mat, parent=None, lean=(.015, .0)):
    x,y,z=loc
    obj=sculpted_body(name,(x,y,z),(.09,.085,height),mat,parent,lean=lean,pillow=.01,radius=.025)
    rounded_box(name+"_cap",(x+lean[0],y+lean[1],z+height+.012),(.12,.11,.035),mat,parent,.012)
    return obj


def barrel(name, loc, mat, parent=None, scale=1):
    x,y,z=loc
    obj=cone(name,(x,y,z+.065*scale),.055*scale,.048*scale,.13*scale,mat,parent,16)
    for dz in (.025,.105):
        cylinder(name+f"_hoop_{dz}",(x,y,z+dz*scale),.057*scale,.012*scale,"timber_dark",parent,16)
    return obj


def crate(name, loc, mat, parent=None, scale=1):
    return rounded_box(name,(loc[0],loc[1],loc[2]+.045*scale),(.10*scale,.09*scale,.09*scale),mat,parent,.012)


def lantern(name, loc, parent=None):
    cage=empty(name,parent,loc)
    sphere(name+"_glow",(0,0,0),(.026,.026,.036),"window_glow",cage,12)
    for x in (-.035,.035):
        for y in (-.025,.025):
            cylinder(name+f"_bar_{x}_{y}",(x,y,0),.005,.085,"warm_gold",cage,8)
    rounded_box(name+"_cap",(0,0,.047),(.09,.07,.02),"warm_gold",cage,.008)
    return cage


def smoke(name, loc, parent, phase=0, mat="smoke_stone"):
    puff=empty(name,parent,loc)
    sphere(name+"_cloud",(0,0,0),(.045,.038,.04),mat,puff,12)
    animate_component(puff,"location",2,loc[2],.07,phase)
    animate_component(puff,"scale",0,1,.18,phase)
    animate_component(puff,"scale",1,1,.14,phase)
    return puff


def animate_component(obj, path, index, base, amp, phase=0, cycles=1):
    for f in range(1, END+1, 30):
        t=(f-1)/(END-1)
        value=base+amp*math.sin(TAU*cycles*t+phase)
        getattr(obj,path)[index]=value
        obj.keyframe_insert(data_path=path,index=index,frame=f)
    getattr(obj,path)[index]=base+amp*math.sin(phase)
    obj.keyframe_insert(data_path=path,index=index,frame=END)


def full_rotation(obj, axis=1):
    for f, v in ((1,0),(61,math.pi/2),(121,math.pi),(181,3*math.pi/2),(240,TAU)):
        obj.rotation_euler[axis]=v
        obj.keyframe_insert(data_path="rotation_euler",index=axis,frame=f)


def parent_keep(obj, parent):
    world=obj.matrix_world.copy(); obj.parent=parent; obj.matrix_world=world


def make_groups(kind):
    root=empty(kind)
    return root, empty("body",root), empty("roof",root), empty("props",root)


def build_house():
    root,body,roof,props=make_groups("house")
    sculpted_body("stone_plinth",(-.04,.03,0),(.88,.74,.075),"stone_plinth",body,pillow=.025,radius=.12)
    sculpted_body("tall_plaster",(-.15,.08,.075),(.50,.48,.48),"plaster",body,lean=(.008,-.006),pillow=.025,radius=.09)
    sculpted_body("cream_annex",(.23,.10,.075),(.36,.40,.32),"cream",body,lean=(-.007,.005),pillow=.028,radius=.08)
    sag_roof("tall_roof",(-.15,.08,0),.64,.66,.535,.19,"roof_terracotta",roof)
    sag_roof("annex_roof",(.23,.10,0),.48,.56,.39,.15,"dusty_red",roof)
    arch_fill("main_door",(-.17,-.173,.105),.17,.26,.025,"timber_dark",body)
    arch_frame("main_door_arch",(-.17,-.19,.105),.23,.31,.055,.028,"dusty_red",body)
    for i in range(2): rounded_box(f"worn_step_{i}",(-.17,-.28-i*.045,.08-i*.02),(.28+i*.06,.12,.045),"stone_plinth",body,.018)
    family_window("front_window",(.08,-.18,.36),(.18,.20),"front",body,props,True,True)
    family_window("annex_window",(.29,-.115,.24),(.14,.16),"front",body,props)
    # exterior stair curls up the annex side
    for i in range(6):
        rounded_box(f"side_stair_{i}",(.43,.25-i*.045,.11+i*.045),(.18,.10,.055),"stone_plinth",body,.015,rot=(0,0,.025*i))
    arch_fill("upper_door",(.40,.065,.35),.12,.18,.018,"timber_dark",body)
    arch_frame("upper_door_arch",(.40,.05,.35),.17,.22,.045,.022,"plaster",body)
    rounded_box("balcony_slab",(-.06,-.265,.40),(.34,.15,.045),"stone_plinth",body,.015)
    for x in (-.15,-.06,.03): cylinder(f"baluster_{x}",(x,-.33,.46),.018,.12,"timber_dark",props,10)
    curve_tube("balcony_rail",[(-.18,-.33,.52),(-.05,-.335,.53),(.07,-.33,.52)],.014,"timber_dark",props)
    for x,c in ((-.02,"cream"),(.08,"dusty_red")):
        cloth=rounded_box(f"laundry_{c}",(x,-.35,.47),(.075,.018,.09),c,props,.008,rot=(0,0,.06))
        animate_component(cloth,"rotation_euler",1,0,math.radians(4),.8 if c=="cream" else 2.1)
    chimney("house_chimney",(-.28,.20,.57),.21,"stone_plinth",roof,lean=(.018,-.01))
    smoke("smoke_1",(-.262,.19,.80),props,0,"stone_plinth")
    smoke("smoke_2",(-.25,.19,.86),props,2.1,"stone_plinth")
    cylinder("garden_pot",(.29,-.28,.12),.055,.10,"roof_terracotta",props,14,r2=.045)
    sphere("potted_plant",(.29,-.28,.20),(.07,.06,.06),"sage",props,14)
    for i in range(4):
        rounded_box(f"garden_wall_{i}",(-.42+i*.1,.32+.015*math.sin(i),.11),(.11,.10,.10),"stone_plinth",props,.025,rot=(0,0,.03*i))
    barrel("house_barrel",(.34,.34,.075),"timber_dark",props,.85); crate("house_crate",(.22,.36,.075),"timber_dark",props,.8)
    lamp=lantern("door_lantern",(.02,-.25,.32),props); animate_component(lamp,"rotation_euler",1,0,math.radians(3),.4)
    return root


def boat_mesh(name, loc, mat, parent):
    stations=9; sides=10; verts=[]
    for i in range(stations):
        t=i/(stations-1); y=(t-.5)*.52; fullness=math.sin(math.pi*t)**.55
        sheer=.055+(.07*(abs(t-.5)*2)**1.6)
        for j in range(sides):
            a=math.pi + math.pi*j/(sides-1)
            x=.13*fullness*math.cos(a)
            z=sheer+.10*math.sin(a)
            verts.append((loc[0]+x,loc[1]+y,loc[2]+z))
    faces=[]
    for i in range(stations-1):
        for j in range(sides-1):
            a=i*sides+j; faces.append((a,a+sides,a+sides+1,a+1))
    faces += [tuple(range(sides-1,-1,-1)),tuple((stations-1)*sides+j for j in range(sides))]
    obj=mesh_obj(name,verts,faces,mat,parent)
    curve_tube(name+"_gunwale_l",[(loc[0]-.12*math.sin(math.pi*i/8)**.55,loc[1]+(i/8-.5)*.52,loc[2]+.055+.07*(abs(i/8-.5)*2)**1.6) for i in range(9)],.012,"timber_dark",parent)
    curve_tube(name+"_gunwale_r",[(loc[0]+.12*math.sin(math.pi*i/8)**.55,loc[1]+(i/8-.5)*.52,loc[2]+.055+.07*(abs(i/8-.5)*2)**1.6) for i in range(9)],.012,"timber_dark",parent)
    return obj


def build_pier():
    root,body,roof,props=make_groups("pier")
    # Lazy S plan, individual domed planks
    centers=[]
    for i in range(11):
        t=i/10; y=.42-t*1.05; x=.10*math.sin((t-.15)*math.pi*1.2); centers.append((x,y))
        w=.33+.12*max(0,(t-.72)/.28)
        rounded_box(f"plank_{i}",(x,y,.045+.008*math.sin(i*1.7)),(w,.115,.075),"timber_mid" if i%2==0 else "door_wood",body,.02,rot=(.01*math.sin(i),.01*math.cos(i),.055*math.cos(t*math.pi)))
    # rounded landing fan
    for i in range(4): rounded_box(f"landing_{i}",(.07+(i-1.5)*.13,-.69,.055+.006*math.sin(i)),(.14,.42,.08),"timber_mid" if i%2 else "door_wood",body,.025,rot=(0,0,.025*(i-1.5)))
    for i,(x,y) in enumerate(centers[1::2]):
        for s in (-1,1):
            pile=cone(f"pile_{i}_{s}",(x+s*.19,y,-.025),.038,.028,.27,"timber_dark",body,14,rot=(.02*s,.025*math.sin(i),.035*s))
    # hut
    sculpted_body("fisher_hut",(-.05,-.66,.09),(.34,.29,.28),"cream",body,lean=(.008,.004),pillow=.03,radius=.07)
    mono_roof("hut_straw_roof",(-.05,-.66,0),.46,.42,.39,.11,"straw",roof)
    family_window("hut_window",(-.05,-.82,.27),(.12,.15),"front",body,props)
    chimney("hut_stovepipe",(-.16,-.60,.39),.14,"smoke_stone",roof,lean=(.012,0))
    smoke("hut_smoke",(-.145,-.60,.54),props,1.2)
    # boat as animated assembly
    boat=empty("boat",props,(.34,-.50,.0)); boat_mesh("boat_hull",(0,0,.0),"door_wood",boat)
    rounded_box("boat_bench",(0,0,.12),(.20,.055,.025),"timber_dark",boat,.008)
    cylinder("boat_mast",(0,-.05,.23),.012,.27,"timber_dark",boat,10)
    animate_component(boat,"location",2,0,.012,.3)
    animate_component(boat,"rotation_euler",1,0,math.radians(2),.3)
    rope=curve_tube("mooring_rope",[(.15,-.64,.13),(.23,-.60,.09),(.34,-.50,.10)],.009,"timber_dark",props)
    parent_keep(rope,boat)
    for i in range(3):
        fish=sphere(f"drying_fish_{i}",(-.20+i*.09,-.86,.42),(.035,.014,.065),"dusty_red",props,12)
        animate_component(fish,"rotation_euler",1,0,math.radians(3),i*1.5)
    for x in (-.25,.02): cylinder(f"dry_post_{x}",(x,-.86,.32),.014,.34,"timber_dark",props,10)
    curve_tube("dry_line",[(-.25,-.86,.48),(-.12,-.87,.46),(.02,-.86,.48)],.006,"timber_dark",props)
    for i in range(2):
        cylinder(f"trap_{i}",(-.30+i*.13,-.58,.12),.065,.10,"timber_dark",props,12)
    barrel("pier_barrel",(.23,-.78,.09),"timber_mid",props,.7); crate("pier_crate",(.30,-.70,.09),"door_wood",props,.7)
    lamp=lantern("last_pile_lantern",(-.25,-.42,.30),props); animate_component(lamp,"rotation_euler",1,0,math.radians(4),1.0)
    return root


def build_farm():
    root,body,roof,props=make_groups("farm")
    # domed terrace
    sphere("field_terrace",(-.08,.08,-.13),(.47,.43,.25),"field_dirt",body,24)
    curve_tube("retaining_edge",[(-.46,-.22,.06),(-.25,-.36,.04),(.05,-.39,.05),(.32,-.28,.06),(.39,-.05,.07)],.035,"stone_plinth",body)
    for i in range(6):
        y=.28-i*.10
        pts=[]
        for j in range(7):
            x=-.39+j*.105; z=.08+.055*(1-(x/.43)**2)+.025*math.cos((y-.02)*4)
            pts.append((x,y+.018*math.sin(j*.9+i),z))
        row=curve_tube(f"crop_row_{i}",pts,.026,"crop_gold" if i%2==0 else "sage",body)
        animate_component(row,"rotation_euler",0,0,math.radians(1.5),i*.65)
        for j in range(1,7,2): sphere(f"tuft_{i}_{j}",pts[j],(.032,.025,.05),"crop_gold" if i%2==0 else "sage",row,12)
    # barn
    sculpted_body("barn",(.22,.25,.065),(.38,.34,.29),"timber_mid",body,lean=(-.006,.008),pillow=.025,radius=.07)
    sag_roof("barn_swoop",(.22,.25,0),.50,.52,.35,.17,"straw",roof,sag=.035)
    arch_fill("barn_door",(.22,.065,.075),.17,.24,.025,"timber_dark",body)
    arch_frame("barn_arch",(.22,.05,.075),.23,.28,.05,.026,"straw",body)
    # windmill tower and wheel
    tower=cone("windmill_tower",(-.33,.26,.43),.13,.09,.74,"plaster",body,24,rot=(0,.02,-.01))
    cone("windmill_cap",(-.33,.26,.86),.15,.018,.18,"straw",roof,24)
    wheel=empty("wheel",props,(-.33,.145,.74))
    cylinder("wheel_hub",(0,0,0),.045,.06,"timber_dark",wheel,16,rot=(math.pi/2,0,0))
    for a in range(4):
        ang=a*math.pi/2
        blade=rounded_box(f"mill_blade_{a}",(.16*math.cos(ang),0,.16*math.sin(ang)),(.28,.035,.075),"timber_dark",wheel,.012,rot=(0,ang,0))
        # paddle tip
        rounded_box(f"mill_paddle_{a}",(.29*math.cos(ang),0,.29*math.sin(ang)),(.15,.04,.11),"straw",wheel,.015,rot=(0,ang,0))
    full_rotation(wheel,1)
    # fence
    for i in range(6):
        x=-.43+i*.16; cylinder(f"fence_post_{i}",(x,-.36+.025*math.sin(i),.15),.018,.23,"timber_dark",props,10,rot=(0,.025*math.sin(i),0))
    curve_tube("fence_rail",[(-.43,-.36,.20),(-.15,-.34,.21),(.15,-.38,.19),(.38,-.34,.21)],.015,"timber_dark",props)
    # scarecrow
    scare=empty("scarecrow",props,(.37,-.18,.11)); cylinder("scare_body",(0,0,.14),.025,.28,"timber_dark",scare,10)
    arm=rounded_box("scarecrow_arms",(0,0,.24),(.25,.04,.04),"dusty_red",scare,.012); animate_component(arm,"rotation_euler",1,0,math.radians(2),.7)
    sphere("scarecrow_head",(0,0,.34),(.045,.04,.05),"straw",scare,12); cone("straw_hat",(0,0,.40),.09,.035,.06,"straw",scare,16)
    # sheep
    for i,(x,y) in enumerate(((-.12,-.20),(.10,-.25))):
        sheep=empty(f"sheep_{i}",props,(x,y,.12)); sphere(f"sheep_body_{i}",(0,0,.04),(.08,.055,.06),"plaster",sheep,14); sphere(f"sheep_head_{i}",(0,-.065,.035),(.035,.032,.04),"timber_dark",sheep,12)
        animate_component(sheep,"location",0,x,.03,i*2.1); animate_component(sheep,"rotation_euler",0,0,math.radians(3),i*1.7)
    # cart and sacks
    rounded_box("hand_cart",(.27,.40,.12),(.20,.12,.06),"timber_mid",props,.018,rot=(0,0,.18))
    for s in (-1,1): cylinder(f"cart_wheel_{s}",(.18+s*.08,.34,.11),.055,.025,"timber_dark",props,16,rot=(math.pi/2,0,0))
    for i in range(3): sphere(f"grain_sack_{i}",(.32+i*.045,.34,.14+i*.025),(.045,.055,.065),"straw",props,12)
    for z in (.09,.14,.19): cylinder(f"beehive_{z}",(-.40,-.08,z),.065-(z-.09)*.18,.045,"straw",props,16)
    return root


def build_factory():
    root,body,roof,props=make_groups("factory")
    sculpted_body("factory_plinth",(-.02,.03,0),(.88,.72,.09),"stone_plinth",body,pillow=.02,radius=.13)
    sculpted_body("workshop_hall",(-.10,.03,.08),(.60,.56,.46),"muted_teal",body,lean=(.008,-.006),pillow=.026,radius=.10)
    barrel_roof("vault_roof",(-.10,.03,0),.72,.74,.54,.20,"slate",roof)
    # kiln tower
    cone("kiln_tower",(.29,.16,.32),.19,.15,.50,"smoke_stone",body,24,rot=(.01,-.02,0))
    cylinder("kiln_crown",(.29,.16,.58),.19,.07,"warm_gold",body,24)
    chimney("kiln_stack",(.29,.16,.60),.25,"smoke_stone",roof,lean=(.018,-.008))
    for i,p in enumerate((0,2.1,4.2)): smoke(f"kiln_smoke_{i}",(.308,.152,.87+i*.025),props,p)
    # rose window on front
    cylinder("rose_glow",(-.10,-.267,.39),.12,.018,"window_glow",body,24,rot=(math.pi/2,0,0))
    bpy.ops.mesh.primitive_torus_add(major_radius=.12,minor_radius=.025,major_segments=24,minor_segments=8,location=(-.10,-.285,.39),rotation=(math.pi/2,0,0))
    rose=bpy.context.object; rose.name="rose_window_frame"; rose.data.materials.append(material("warm_gold")); rose.parent=body
    for a in range(0,360,45):
        rad=math.radians(a); rounded_box(f"rose_spoke_{a}",(-.10+.055*math.cos(rad),-.305,.39+.055*math.sin(rad)),(.12,.025,.018),"warm_gold",body,.006,rot=(0,rad,0))
    arch_fill("factory_double_door",(-.10,-.275,.09),.25,.31,.025,"timber_dark",body)
    arch_frame("factory_door_arch",(-.10,-.292,.09),.33,.36,.05,.035,"warm_gold",body)
    for x in (-.16,-.04): rounded_box(f"door_strap_{x}",(x,-.325,.20),(.02,.02,.20),"warm_gold",body,.006)
    family_window("side_window",(-.38,-.16,.31),(.14,.16),"front",body,props)
    # pipes and glass bulb
    curve_tube("arcane_pipe",[(.16,-.27,.18),(.24,-.28,.18),(.24,-.28,.42),(.16,-.28,.50)],.025,"arcane_teal",props)
    bulb=empty("glass_bulb",props,(.16,-.28,.55)); sphere("bulb_glow",(0,0,0),(.065,.05,.075),"window_glow",bulb,16); animate_component(bulb,"scale",0,1,.05,0); animate_component(bulb,"scale",2,1,.05,0)
    kettle=sphere("condenser_kettle",(.05,.03,.76),(.09,.08,.07),"warm_gold",roof,16)
    spiral=curve_tube("spiral_condenser",[(.05,.03,.80),(.12,.04,.82),(.14,.04,.77),(.08,.04,.74),(.02,.04,.77),(.08,.04,.80)],.012,"arcane_teal",props)
    animate_component(spiral,"rotation_euler",0,0,math.radians(1),.5)
    # workbench, awning, anvil, quench
    rounded_box("workbench",(-.38,.26,.15),(.25,.12,.08),"timber_dark",props,.015)
    mono_roof("workbench_awning",(-.38,.18,0),.32,.24,.39,.08,"warm_gold",props)
    rounded_box("anvil",(-.38,.24,.23),(.12,.055,.045),"smoke_stone",props,.014)
    barrel("quench_barrel",(.18,-.34,.09),"timber_mid",props,.8); cylinder("quench_water",(.18,-.34,.145),.045,.006,"arcane_teal",props,16)
    for i in range(3): rounded_box(f"glowing_ingot_{i}",(.30+i*.055,-.30,.12),(.045,.10,.025),"window_glow",props,.008,rot=(0,0,.08*i))
    ingots=empty("ingot_glow",props); animate_component(ingots,"scale",0,1,.02,1.1); animate_component(ingots,"scale",2,1,.02,1.1)
    for i in range(4): cylinder(f"woodpile_{i}",(-.35+i*.06,.36,.11),.025,.18,"timber_dark",props,10,rot=(0,math.pi/2,.05*i))
    lamp=lantern("factory_lantern",(.11,-.32,.35),props); animate_component(lamp,"rotation_euler",1,0,math.radians(3),1.3)
    return root


def flag_mesh(name, loc, length, height, mat, parent):
    nx=4; t=.012; verts=[]
    for y in (-t/2,t/2):
        for ix in range(nx+1):
            x=length*ix/nx; curl=.018*math.sin(math.pi*ix/nx)
            verts += [(loc[0]+x,loc[1]+y+curl,loc[2]+height/2),(loc[0]+x,loc[1]+y+curl,loc[2]-height/2*(1-.18*ix/nx))]
    n=(nx+1)*2; faces=[]
    for side in (0,1):
        off=side*n
        for i in range(nx): faces.append((off+2*i,off+2*i+2,off+2*i+3,off+2*i+1))
    for i in range(nx):
        a=2*i; faces += [(a,a+2,n+a+2,n+a),(a+1,n+a+1,n+a+3,a+3)]
    faces += [(0,n,n+1,1),(2*nx,2*nx+1,n+2*nx+1,n+2*nx)]
    return bevel(mesh_obj(name,verts,faces,mat,parent),.004,2)


def build_barracks():
    root,body,roof,props=make_groups("barracks")
    sculpted_body("barracks_plinth",(0,.02,0),(.88,.76,.09),"stone_plinth",body,pillow=.02,radius=.14)
    sculpted_body("rounded_keep",(-.05,.04,.08),(.62,.58,.56),"fortified_clay",body,lean=(.012,-.006),pillow=.02,radius=.13)
    # modeled string course
    curve_tube("string_course",[(-.35,-.24,.36),(.25,-.24,.36),(.27,.28,.36),(-.35,.30,.36),(-.35,-.24,.36)],.025,"roof_highlight",body,cyclic=True)
    sag_roof("keep_roof",(-.05,.04,0),.82,.84,.65,.22,"slate",roof,sag=.026)
    curve_tube("terracotta_ridge",[(-.42,.04,.85),(-.05,.04,.88),(.32,.04,.85)],.03,"roof_highlight",roof)
    # watchtower
    cone("watchtower",(.25,.23,.55),.18,.145,.72,"fortified_clay",body,24,rot=(.01,-.02,.015))
    cylinder("tower_corbel",(.25,.23,.89),.19,.09,"roof_highlight",body,24)
    cone("tower_cap",(.25,.23,1.02),.22,.025,.24,"slate",roof,24,rot=(0,.018,0))
    sphere("drooping_tip",(.255,.23,1.15),(.025,.025,.04),"roof_highlight",roof,12)
    # slit glow
    rounded_box("tower_slit_glow",(.25,.045,.72),(.05,.018,.16),"window_glow",body,.018)
    animate_component(bpy.data.objects["tower_slit_glow"],"scale",0,1,.025,.2)
    # gate and terrace
    arch_fill("keep_gate",(-.10,-.268,.09),.24,.33,.03,"timber_dark",body)
    arch_frame("keep_gate_arch",(-.10,-.29,.09),.33,.39,.06,.035,"stone_plinth",body)
    for i in range(3): rounded_box(f"portcullis_v_{i}",(-.17+i*.07,-.325,.22),(.018,.022,.22),"warm_gold",body,.006)
    for z in (.16,.23,.30): rounded_box(f"portcullis_h_{z}",(-.10,-.327,z),(.20,.022,.018),"warm_gold",body,.006)
    for i in range(2): rounded_box(f"gate_step_{i}",(-.10,-.36-i*.055,.08-i*.022),(.34+i*.07,.13,.05),"stone_plinth",body,.018)
    rounded_box("merlon_terrace",(-.10,-.30,.47),(.50,.18,.07),"stone_plinth",body,.025)
    for i in range(5): rounded_box(f"merlon_{i}",(-.30+i*.10,-.35,.56),(.075,.10,.14),"fortified_clay",body,.028)
    # shields
    for x in (-.28,.08):
        cylinder(f"shield_{x}",(x,-.335,.27),.075,.025,"dusty_red",props,20,rot=(math.pi/2,0,0)); sphere(f"shield_boss_{x}",(x,-.355,.27),(.024,.016,.024),"warm_gold",props,12)
    # banner poles and two-segment flags
    for idx,x in enumerate((-.28,.25)):
        cylinder(f"banner_pole_{idx}",(x,-.25,.77),.012,.62,"timber_dark",props,10)
        hinge=empty(f"pennant_{idx}",props,(x,-.25,1.03))
        seg1=flag_mesh(f"pennant_{idx}_segment_1",(0,0,0),.15,.12,"dusty_red",hinge)
        hinge2=empty(f"pennant_{idx}_tip",hinge,(.15,0,0)); seg2=flag_mesh(f"pennant_{idx}_segment_2",(0,0,0),.14,.10,"dusty_red",hinge2)
        animate_component(hinge,"rotation_euler",1,0,math.radians(3),idx*.8)
        animate_component(hinge2,"rotation_euler",1,0,math.radians(6),1.2+idx*.8)
    # spear rack + target + fire
    rounded_box("spear_rack",(.34,-.20,.18),(.10,.08,.28),"timber_dark",props,.014)
    for i in range(3):
        cylinder(f"spear_{i}",(.30+i*.04,-.24,.30),.008,.38,"timber_dark",props,8,rot=(0,.04*(i-1),0)); cone(f"spear_tip_{i}",(.30+i*.04,-.24,.50),.018,.003,.05,"warm_gold",props,8)
    cylinder("archery_target",(.34,.36,.20),.11,.06,"straw",props,24,rot=(math.pi/2,0,0)); cylinder("target_ring",(.34,.325,.20),.06,.012,"dusty_red",props,20,rot=(math.pi/2,0,0))
    fire=empty("fire_flame",props,(-.35,.30,.12))
    for a in range(7):
        ang=TAU*a/7; sphere(f"fire_stone_{a}",(.08*math.cos(ang),.08*math.sin(ang),0),(.035,.03,.025),"stone_plinth",fire,10)
    cone("flame",(0,0,.06),.055,.012,.14,"window_glow",fire,14)
    animate_component(fire,"scale",2,1,.065,.4); animate_component(fire,"rotation_euler",0,0,math.radians(2),1.1)
    return root


BUILDERS={"house":build_house,"pier":build_pier,"farm":build_farm,"factory":build_factory,"barracks":build_barracks}


def apply_mesh_transforms(root):
    for obj in root.children_recursive:
        obj.matrix_parent_inverse=Matrix.Identity(4)
        if obj.type=="MESH":
            bpy.context.view_layer.objects.active=obj; obj.select_set(True)
            bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
            obj.select_set(False)


def select_hierarchy(root):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in root.children_recursive: obj.select_set(True)
    bpy.context.view_layer.objects.active=root


def triangle_count(root):
    deps=bpy.context.evaluated_depsgraph_get(); total=0
    for obj in root.children_recursive:
        if obj.type=="MESH":
            ev=obj.evaluated_get(deps); mesh=ev.to_mesh(); mesh.calc_loop_triangles(); total+=len(mesh.loop_triangles); ev.to_mesh_clear()
        elif obj.type=="CURVE":
            ev=obj.evaluated_get(deps); mesh=ev.to_mesh(); mesh.calc_loop_triangles(); total+=len(mesh.loop_triangles); ev.to_mesh_clear()
    return total


def setup_camera(name, root, silhouette=False):
    scene=bpy.context.scene
    bpy.ops.object.camera_add(location=(1.45,-2.25,1.55))
    cam=bpy.context.object; cam.name="qa_camera"; cam.data.lens=52; scene.camera=cam
    direction=Vector((0,0,.38))-cam.location; cam.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.light_add(type="AREA",location=(-1.8,-2.0,3.0)); key=bpy.context.object; key.data.energy=650; key.data.shape="DISK"; key.data.size=3.0
    key.rotation_euler=(math.radians(28),0,math.radians(-35))
    bpy.ops.object.light_add(type="AREA",location=(2.0,.8,1.8)); fill=bpy.context.object; fill.data.energy=320; fill.data.size=2.5
    fill.rotation_euler=(math.radians(-50),0,math.radians(145))
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=.65,depth=.035,location=(0,0,-.025))
    tile=bpy.context.object; tile.name="qa_tile"; tile.data.materials.append(material("sand"))
    scene.render.resolution_x=256 if silhouette else 512; scene.render.resolution_y=256 if silhouette else 512; scene.render.resolution_percentage=100
    if silhouette:
        black=bpy.data.materials.new("silhouette_black"); black.diffuse_color=(.01,.012,.014,1)
        black.use_nodes=True; black.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.01,.012,.014,1)
        for obj in root.children_recursive:
            if obj.type in {"MESH","CURVE"}:
                obj.data.materials.clear(); obj.data.materials.append(black)
        tile.data.materials.clear(); tile.data.materials.append(material("plaster"))
        scene.world.color=(.93,.92,.88)
    return cam


def export_asset(kind):
    scene=clear_scene(); root=BUILDERS[kind](); apply_mesh_transforms(root); scene.frame_set(1)
    source=os.path.join(SRC,f"building_{kind}.blend")
    usdz=os.path.join(OUT,f"building_{kind}.usdz")
    bpy.ops.wm.save_as_mainfile(filepath=source,compress=True)
    select_hierarchy(root)
    bpy.ops.wm.usd_export(filepath=usdz,selected_objects_only=True,export_animation=True,export_materials=True,
        convert_orientation=True,export_global_forward_selection="NEGATIVE_Z",export_global_up_selection="Y",
        generate_preview_surface=True,usdz_downscale_size="KEEP",root_prim_path="",
        export_lights=False,export_cameras=False)
    tris=triangle_count(root); mats=sorted({m.name for o in root.children_recursive if hasattr(o.data,"materials") for m in o.data.materials if m})
    with zipfile.ZipFile(usdz) as package:
        texture_count=sum(name.startswith("textures/") for name in package.namelist())
    report={"building":kind,"triangles":tris,"materials":mats,"material_count":len(mats),"frames":[1,END],"fps":FPS,
            "footprint_rule":"1m tile; pier extends forward","usd_up_axis":"Y","textures":texture_count}
    with open(os.path.join(QA,f"{kind}_report.json"),"w") as f: json.dump(report,f,indent=2)
    setup_camera(kind,root,False); scene.render.filepath=os.path.join(QA,f"{kind}_preview.png"); bpy.ops.render.render(write_still=True)
    setup_camera(kind,root,True); bpy.context.scene.render.filepath=os.path.join(QA,f"{kind}_silhouette.png"); bpy.ops.render.render(write_still=True)
    return report


def gallery():
    clear_scene(); scene=bpy.context.scene
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(QA,"_gallery_work.blend"),compress=True)
    for idx,kind in enumerate(BUILDERS):
        path=os.path.join(SRC,f"building_{kind}.blend")
        before=set(bpy.data.objects)
        with bpy.data.libraries.load(path,link=False) as (src,dst): dst.objects=src.objects
        imported=[o for o in bpy.data.objects if o not in before]
        for obj in imported:
            if not obj.users_collection:
                bpy.context.collection.objects.link(obj)
        roots=[o for o in imported if o.name==kind]
        if roots: roots[0].location.x=(idx-2)*1.12
    bpy.ops.object.camera_add(location=(0,-6.7,3.55)); cam=bpy.context.object; cam.data.lens=58; scene.camera=cam
    cam.rotation_euler=(Vector((0,0,.36))-cam.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.light_add(type="AREA",location=(-3,-4,6)); bpy.context.object.data.energy=1500; bpy.context.object.data.size=5
    bpy.ops.object.light_add(type="AREA",location=(4,1,3)); bpy.context.object.data.energy=700; bpy.context.object.data.size=4
    bpy.ops.mesh.primitive_cube_add(location=(0,.04,-.09)); ground=bpy.context.object; ground.scale=(3.2,.75,.09); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); bevel(ground,.12,4); ground.data.materials.append(material("sand"))
    scene.render.resolution_x=1400; scene.render.resolution_y=480; scene.render.resolution_percentage=100; scene.render.filepath=os.path.join(QA,"village_lineup.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC,"village_lineup.blend"),compress=True)


def main():
    reports=[]
    for kind in BUILDERS: reports.append(export_asset(kind))
    gallery()
    with open(os.path.join(QA,"summary.json"),"w") as f: json.dump(reports,f,indent=2)
    print("VILLAGE_ASSETS_COMPLETE",reports)


if globals().get("VILLAGE_GALLERY_ONLY"):
    gallery()
else:
    main()
