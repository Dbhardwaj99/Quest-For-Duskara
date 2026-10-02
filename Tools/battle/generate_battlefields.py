"""Blender -b --python Tools/battle/generate_battlefields.py -- [--only forest] [--force]."""
import sys
from pathlib import Path
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_battle_sprites as sprites
import bpy
import numpy as np
import argparse
import colorsys
import hashlib
import json
import math
import re
import shutil
import time
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

THEMES = ('village', 'desert', 'mountains', 'forest')
WIDTH, HEIGHT = 4480, 1024
UP = Vector((0, 0.5, math.sqrt(3)/2))


def job_cache(name, folder, force, sources):
    raw = sprites.RAW / name
    raw.mkdir(parents=True, exist_ok=True)
    manifest = raw / '.manifest.json'
    digest = hashlib.sha256(b''.join(Path(p).read_bytes() for p in sources) + name.encode()).hexdigest()
    old = json.loads(manifest.read_text()) if manifest.exists() else {}
    good = not force and old.get('hash') == digest and all((folder/p).exists() for p in old.get('files', []))
    return raw, manifest, digest, good


def save_pixels(pixels, path, jpeg=False):
    height, width, _ = pixels.shape
    image = bpy.data.images.new(path.stem, width=width, height=height, alpha=not jpeg)
    image.pixels.foreach_set(np.ascontiguousarray(pixels).ravel())
    settings = bpy.context.scene.render.image_settings
    settings.file_format = 'JPEG' if jpeg else 'PNG'
    settings.color_mode = 'RGB' if jpeg else 'RGBA'
    settings.quality = 85
    image.save_render(str(path))
    bpy.data.images.remove(image)


def load_pixels(path):
    image = bpy.data.images.load(str(path), check_existing=False)
    width, height = image.size
    pixels = np.empty(width*height*4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)


def ship(folder, name, path, scale='2x'):
    imageset = folder / f'{name}.imageset'
    imageset.mkdir(parents=True, exist_ok=True)
    filename = name + path.suffix
    shutil.copy2(path, imageset / filename)
    (imageset/'Contents.json').write_text(json.dumps({'images': [{'filename': filename, 'idiom': 'universal', 'scale': scale}], 'info': {'author': 'xcode', 'version': 1}}))
    (folder/'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}))


def data_asset(folder, name, data):
    target = folder / f'{name}.dataset'
    target.mkdir(parents=True, exist_ok=True)
    (target/'layout.json').write_text(json.dumps(data, indent=2))
    (target/'Contents.json').write_text(json.dumps({'data': [{'filename': 'layout.json', 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}}))


def palette(theme):
    source = (sprites.ROOT/'Views/3D/WorldPalette.swift').read_text()
    base = source.split('static var village:')[0]
    pairs = dict(re.findall(r'var (\w+) = c\(([^)]+)\)', base))
    if theme != 'village':
        block = source.split(f'static var {theme}:')[1].split('return p')[0]
        pairs.update(dict(re.findall(r'p\.(\w+) = c\(([^)]+)\)', block)))
    result = {}
    for name, values in pairs.items():
        rgb = tuple(float(x.strip()) for x in values.split(',')[:3])
        h, s, v = colorsys.rgb_to_hsv(*rgb)
        result[name] = colorsys.hsv_to_rgb(h, min(1,s*.76*1.45), min(1,max(0,.5+(v*1.06-.5)*1.45)))
    return result


def blob(art, name, at, size, color):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=.5, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(art.material(color))
    art.soften(obj, 0)
    return obj


def tree(art, theme, x, y, scale=1):
    art.box('trunk', (x,y,.55*scale), (.18*scale,.18*scale,1.1*scale), 'timber', 0)
    if theme in ('mountains','desert'):
        if theme == 'mountains':
            for z, radius in [(1,.55),(1.45,.43),(1.85,.31)]:
                bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=radius*scale, radius2=.03, depth=.85*scale, location=(x,y,z*scale))
                bpy.context.object.data.materials.append(art.material('forestDeep'))
                art.soften(bpy.context.object,0)
        else:
            for i in range(5):
                angle = i*math.tau/5
                leaf = blob(art,'palm frond',(x+math.cos(angle)*.35*scale,y+math.sin(angle)*.35*scale,1.25*scale),(1.15*scale,.22*scale,.13*scale),'frond')
                leaf.rotation_euler.z = angle
    else:
        for dx,dy,z,s in [(-.25,0,1.35,.9),(.25,.1,1.55,1),(0,-.2,1.8,.8)]:
            blob(art,'clay canopy',(x+dx*scale,y+dy*scale,z*scale),(s*scale,s*.8*scale,s*scale),'forestDeep' if dy else 'grassLight')


def build(theme):
    scene = sprites.setup()
    scene.render.resolution_x, scene.render.resolution_y = WIDTH, HEIGHT
    scene.camera.data.ortho_scale = 35
    center = Vector((17.5,0,0)) + UP*1.5
    scene.camera.location = center + Vector((0,-10*math.sqrt(3)/2,5))
    scene.camera.rotation_euler = (center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    art = sprites.settlement()
    colors = palette(theme)
    # Local materials reuse the town's colour curve without touching the exporter.
    linear = {name: tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb) for name,rgb in colors.items()}
    art.COLORS.update(linear)
    for name,rgb in linear.items():
        if name in bpy.data.materials:
            mat = bpy.data.materials[name]
            mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*rgb,1)
    layers = {}
    def collect(layer, action):
        before = set(scene.objects)
        action()
        layers[layer] = set(scene.objects)-before
    def far():
        # A tall emission plane provides a sky gradient independent of ambient lighting.
        sky = art.box('sky',(17.5,30,-13),(60,.1,30),'sky',0)
        mat = bpy.data.materials.new('sky gradient'); mat.use_nodes = True
        nodes = mat.node_tree.nodes; nodes.clear()
        output = nodes.new('ShaderNodeOutputMaterial')
        emission = nodes.new('ShaderNodeEmission')
        coord = nodes.new('ShaderNodeTexCoord'); separate = nodes.new('ShaderNodeSeparateXYZ'); ramp = nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = (*linear['cloud'],1)
        ramp.color_ramp.elements[1].color = (*linear['sky'],1)
        links = mat.node_tree.links
        for a,b in [(coord.outputs['Generated'],separate.inputs[0]),(separate.outputs['Z'],ramp.inputs[0]),(ramp.outputs[0],emission.inputs[0]),(emission.outputs[0],output.inputs[0])]: links.new(a,b)
        sky.data.materials.clear(); sky.data.materials.append(mat)
        art.box('distant sea',(-5,3,-.08),(12,14,.1),'waterOpen',0)
        art.box('distant meadow',(20,4.8,-.06),(38,4,.1),'tileGround',0)
        for i in range(11):
            blob(art,'distant hills',(i*4-2,7+(i%3)*.2,-.8),(7,4,2.4 if theme=='mountains' else 1.3),'terrainMountain' if theme=='mountains' else 'forestMoss')
        for i in range(13): tree(art,theme,4+i*2.5,6.2+(i%3)*.3, .65+(i%3)*.12)
    def ground():
        art.box('field',(19.5,0,-.09),(31,14,.18),'tileGround',.08)
        art.box('sand',(2.4,0,-.05),(3.2,14,.12),'earth',.06)
        art.box('sea',(-5,0,-.08),(12,14,.1),'waterOpen',.03)
        for x in (.82,.91,.99): art.box('soft surf',(x,0,-.01),(.14,14,.02),'cloud',.01)
        for y in (0,1.6,3.2):
            art.box('soft dirt edge',(16,y,.006),(24,.68,.018),'fieldDirt',.008)
            art.box('lane',(16,y,.019),(24,.50,.018),'walkedDirt',.008)
        # Same rounded hull, mast and cream rectangular sail as makeBoat().
        for x,y in [(1.4,-1),(2.2,4.2)]:
            art.box('landing hull',(x,y,.16),(.48,1.14,.18),'doorWood',.06,(0,0,-.25))
            art.box('mast',(x,y,.60),(.07,.07,.9),'timber',.018)
            art.box('cream sail',(x+.03,y+.22,.70),(.04,.45,.60),'plaster',.025)
        for i in range(12):
            x=5+i*2.1
            blob(art,'edge stones',(x,-2.2,.13),(.40,.30,.26),'warmStone')
            if theme != 'desert':
                art.box('fence post',(x,4.65,.27),(.12,.12,.54),'timber',0)
                art.box('fence rail',(x+.45,4.65,.36),(1,.07,.07),'timber',0)
            else: blob(art,'dune',(x,4.7,.12),(2.4,1.2,.32),'rootSoil')
    def front():
        for i in range(9):
            x=3+i*3.1
            blob(art,'foreground stone',(x,-3,.12),(.6,.4,.3),'warmStone')
            if theme != 'desert':
                for dx in (-.18,.08,.22):
                    bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=.055,radius2=0,depth=.24,location=(x+dx,-2.8,.12))
                    bpy.context.object.data.materials.append(art.material('grassLight'))
    collect('far',far); collect('ground',ground); collect('front',front)
    triangles = sprites.triangle_count()
    assert triangles <= 20000, triangles
    return scene,layers,triangles


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--only',choices=THEMES); parser.add_argument('--force',action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for theme in ([args.only] if args.only else THEMES):
        started = time.monotonic()
        folder = sprites.CATALOG / f'Battlefield{theme.title()}'
        raw,manifest,digest,good = job_cache('battlefield-'+theme,folder,args.force,[__file__,sprites.__file__,sprites.SOURCE,sprites.ROOT/'Views/3D/WorldPalette.swift'])
        if good: print(f'CACHED {theme}',flush=True); continue
        scene,layers,triangles = build(theme)
        lane_y = [world_to_camera_view(scene,scene.camera,Vector((4,y,0))).y*HEIGHT/2 for y in (3.2,1.6,0)]
        layout = {'width':WIDTH,'height':HEIGHT,'shoreX':4*64,'gateX':28*64,'laneYs':lane_y,'tiles':[]}
        for layer,objects in layers.items():
            for members in layers.values():
                for obj in members: obj.hide_render = obj not in objects
            scene.render.resolution_percentage = 50 if layer=='far' else 100
            scene.render.film_transparent = layer=='front'
            scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
            path = raw/f'{layer}.png'; sprites.render(scene,path)
            pixels = load_pixels(path)
            # The opaque ground occupies the lower field; the sky/hills remain a separate layer.
            if layer=='ground': pixels = pixels[:int(HEIGHT*.64),:]
            for index,x in enumerate(range(0,pixels.shape[1],2048)):
                tile = pixels[:,x:x+2048,:]
                name=f'battlefield_{theme}_{layer}_{index}'
                tile_path=raw/(name+('.png' if layer=='front' else '.jpg'))
                save_pixels(tile,tile_path,layer!='front'); ship(folder,name,tile_path,'1x' if layer=='far' else '2x')
                factor = 2 if layer=='far' else 1
                layout['tiles'].append({'name':name,'layer':layer,'x':x*factor,'y':0,'width':tile.shape[1]*factor,'height':tile.shape[0]*factor,'parallax':{'far':.4,'ground':1,'front':1.15}[layer]})
        data_asset(folder,f'Battlefield{theme.title()}Layout',layout)
        files=[str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file()]
        elapsed=time.monotonic()-started
        manifest.write_text(json.dumps({'hash':digest,'files':files,'triangles':triangles,'seconds':elapsed}))
        print(f'{theme}: {triangles} triangles; {elapsed:.2f}s; {sum((folder/p).stat().st_size for p in files)/1024**2:.2f}MB',flush=True)


if __name__=='__main__': main()
