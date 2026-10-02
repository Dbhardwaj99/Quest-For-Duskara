"""Blender -b --python Tools/battle/generate_fortress.py -- [--force]."""
import sys
from pathlib import Path
sys.dont_write_bytecode = True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import generate_battle_sprites as sprites
import generate_battlefields as fields
import bpy
import numpy as np
import argparse
import json
import math
import time
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view


def wall(art, end=False):
    art.box('clay wall',(0,0,.65),(.65,1.6,1.3),'fortifiedClay',.08)
    art.box('stone footing',(0,0,.10),(.78,1.68,.20),'stone',.04)
    for y in (-.6,0,.6): art.box('merlon',(0,y,1.43),(.65,.31,.3),'stone',.045)
    if end: art.box('end column',(0,-.62,.90),(.8,.40,1.8),'fortifiedClay',.06)


def gate(art, state):
    for y in (-.58,.58):
        art.box('gate pier',(0,y,.83),(.80,.32,1.66),'fortifiedClay',.06)
        art.box('pier crown',(0,y,1.7),(.92,.44,.20),'stone',.035)
    art.box('gate lintel',(0,0,1.53),(.8,1.4,.30),'stone',.05)
    if state != 'broken':
        for i in range(6):
            y=(i-2.5)*.17
            plank=art.box('gate timber',(-.30,y,.71),(.13,.15,1.42),'darkTimber',.02)
            if state=='breaking' and i%2==0:
                plank.rotation_euler.x=.35*(1 if i%3 else -1)
                plank.location.z-=.03
        for z in (.35,1.1): art.box('iron brace',(-.39,0,z),(.06,1.04,.075),'slateRoof',.012)
        if state in ('cracked','breaking'):
            for i in range(3): art.box('split timber',(-.43,-.20+i*.09,.55+i*.21),(.025,.025,.24),'stone',0,(.25 if i%2 else -.3,0,0))
    else:
        for i in range(4): art.box('fallen plank',(-.50+(i%2)*.30,(i-1.5)*.22,.06),(.90,.15,.12),'darkTimber',.02,(0,0,i*.23))

    # Turn the entrance toward the broadcast camera so its damage reads clearly.
    for obj in bpy.context.scene.objects:
        if obj.type=='MESH':
            x,y=obj.location.x,obj.location.y
            obj.location.x,obj.location.y=-y,x
            obj.rotation_euler.z+=math.pi/2


def tower(art):
    art.box('tower base',(0,0,.12),(1.1,1,.24),'stone',.07)
    art.box('tower',(0,0,1.15),(.9,.85,2.3),'fortifiedClay',.08)
    art.box('firing slit',(0,-.445,1.55),(.16,.035,.35),'darkTimber',.005)
    art.box('upper ledge',(0,0,2.35),(1.05,1,.22),'stone',.05)
    for x,y in [(-.38,-.34),(-.38,.34),(.38,-.34),(.38,.34)]:
        art.box('tower merlon',(x,y,2.65),(.30,.30,.4),'stone',.04)


def banner(art, team):
    art.box('banner pole',(0,0,1.15),(.07,.07,2.3),'timber',.014)
    art.box('team cloth',(.27,0,1.89),(.54,.045,.42),'teamBlue' if team=='blue' else 'teamRed',.025)
    art.box('banner crest',(.27,-.029,1.88),(.13,.018,.18),'warmGold',.016)


def main():
    started=time.monotonic()
    parser=argparse.ArgumentParser(); parser.add_argument('--force',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    folder=sprites.CATALOG/'BattleFortress.spriteatlas'
    raw,manifest,digest,good=fields.job_cache('fortress',folder,args.force,[__file__,fields.__file__,sprites.__file__,sprites.SOURCE])
    data_folder=sprites.CATALOG/'BattleFortressData'
    if good and (data_folder/'BattleFortressLayout.dataset/layout.json').exists(): print('CACHED fortress',flush=True); return
    art=sprites.settlement()
    jobs={f'settlement_{name}':create for name,create in art.MODELS.items()}
    jobs.update({'fort_wall':lambda:wall(art),'fort_endcap':lambda:wall(art,True),'fort_tower':lambda:tower(art)})
    for state in ('intact','cracked','breaking','broken'): jobs[f'fort_gate_{state}']=lambda state=state:gate(art,state)
    for team in ('blue','red'): jobs[f'fort_banner_{team}']=lambda team=team:banner(art,team)
    metadata={}
    for name,create in jobs.items():
        scene=sprites.setup()
        scene.render.resolution_x=scene.render.resolution_y=512
        scene.camera.data.ortho_scale=4
        # Keep the identical pitch, with enough room for the tallest settlement piece.
        center=fields.UP*1.45
        scene.camera.location=center+Vector((0,-8.660254,5))
        scene.camera.rotation_euler=(center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        create(); scene.view_layers.update()
        triangles=sprites.triangle_count()
        assert triangles<=20000, (name,triangles)
        source=raw/f'{name}-full.png'; sprites.render(scene,source)
        pixels=fields.load_pixels(source)
        ys,xs=np.where(pixels[:,:,3]>.01)
        assert len(xs)>0,name
        left,right=max(0,int(xs.min())-2),min(512,int(xs.max())+3)
        bottom,top=max(0,int(ys.min())-2),min(512,int(ys.max())+3)
        assert left>0 and right<512 and bottom>0 and top<512, (name,left,right,bottom,top)
        point=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
        cropped=pixels[bottom:top,left:right]
        path=raw/f'{name}.png'; fields.save_pixels(cropped,path); fields.ship(folder,name,path)
        meshes=[o for o in scene.objects if o.type=='MESH']
        vertices=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
        metadata[name]={'width':right-left,'height':top-bottom,'anchorX':(point.x*512-left)/(right-left),'anchorY':(point.y*512-bottom)/(top-bottom),'footprintWidth':max(v.x for v in vertices)-min(v.x for v in vertices),'footprintDepth':max(v.y for v in vertices)-min(v.y for v in vertices)}
        if name=='fort_tower':
            slit=world_to_camera_view(scene,scene.camera,Vector((0,-.46,1.55)))
            metadata[name]['slitX']=(slit.x-point.x)*256
            metadata[name]['slitY']=(slit.y-point.y)*256
    fields.data_asset(data_folder,'BattleFortressLayout',metadata)
    files=[str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file()]
    elapsed=time.monotonic()-started
    manifest.write_text(json.dumps({'hash':digest,'files':files,'seconds':elapsed,'pieces':len(jobs)}))
    print(f'FORTRESS: {len(jobs)} pieces; {elapsed:.2f}s; {sum((folder/p).stat().st_size for p in files)/1024**2:.2f}MB',flush=True)


if __name__=='__main__': main()
