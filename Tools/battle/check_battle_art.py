"""Validate packaged battlefield tiles/fortress anchors and stitch previews (Pillow)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2] / 'Assets/Assets.xcassets'
scratch = Path('/tmp/duskara-battle')
previews = []
for theme in ('village','desert','mountains','forest'):
    folder = root / f'Battlefield{theme.title()}'
    layout = json.loads((folder/f'Battlefield{theme.title()}Layout.dataset/layout.json').read_text())
    assert layout['laneYs'][0] > layout['laneYs'][1] > layout['laneYs'][2]
    assert layout['gateX']-layout['shoreX'] == 24*64
    preview = Image.new('RGB', (layout['width']//2, layout['height']//2))
    for layer in ('far','ground','front'):
        for tile in (t for t in layout['tiles'] if t['layer']==layer):
            imageset = folder / f"{tile['name']}.imageset"
            info = json.loads((imageset/'Contents.json').read_text())['images'][0]
            with Image.open(imageset/info['filename']) as image:
                assert image.width<=2048
                size = (tile['width']//2,tile['height']//2)
                image = image.resize(size, Image.Resampling.LANCZOS)
                pos = (tile['x']//2,preview.height-tile['y']//2-size[1])
                preview.paste(image, pos, image if image.mode=='RGBA' else None)
    preview.save(scratch/f'{theme}-battlefield-preview.png')
    ImageDraw.Draw(preview).text((20,20),theme.title(),fill=(250,240,220))
    previews.append(preview.resize((1120,256)))
    print(f'PASS {theme}: {len(layout["tiles"])} tiles, lanes {layout["laneYs"]}')
sheet = Image.new('RGB',(1120,1024))
for i,preview in enumerate(previews): sheet.paste(preview,(0,i*256))
sheet.save(scratch/'battlefields-contact.png')
fort = root/'BattleFortress.spriteatlas'
if fort.exists():
    metadata = json.loads((root/'BattleFortressData/BattleFortressLayout.dataset/layout.json').read_text())
    for name, info in metadata.items():
        with Image.open(fort/f'{name}.imageset/{name}.png') as image:
            assert image.mode=='RGBA' and image.size == (info['width'],info['height'])
            assert 0<=info['anchorX']<=1 and 0<=info['anchorY']<=1
    print(f'PASS fortress: {len(metadata)} anchored pieces')
