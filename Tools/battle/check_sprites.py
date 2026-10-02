"""Check sprite dimensions, clipping, anchors, and make contact sheets (Pillow)."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('--only', choices=('knight', 'archer'))
args = parser.parse_args()
root = Path(__file__).resolve().parents[2] / 'Assets/Assets.xcassets'
out = Path('/tmp/duskara-battle')
animations = {'idle': 4, 'walk': 8, 'attack': 6, 'death': 6}
for unit in ([args.only] if args.only else ['knight', 'archer']):
    atlas = root / f'Battle{unit.title()}.spriteatlas'
    assert len(list(atlas.glob('*.imageset'))) == 48
    for team in ('blue', 'red'):
        sheet = Image.new('RGB', (8*192, 4*220), (53,48,41))
        draw = ImageDraw.Draw(sheet)
        foot_rows = []
        for row, (animation, count) in enumerate(animations.items()):
            for frame in range(count):
                name = f'{unit}_{team}_{animation}_{frame:02}'
                folder = atlas / f'{name}.imageset'
                metadata = json.loads((folder/'Contents.json').read_text())
                assert metadata['images'][0]['scale'] == '2x'
                with Image.open(folder/f'{name}.png') as image:
                    assert image.size == (192,192) and image.mode == 'RGBA', name
                    bounds = image.getchannel('A').point(lambda v: 255 if v>=128 else 0).getbbox()
                    assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<192 and bounds[3]<192, (name,bounds)
                    if animation == 'walk': foot_rows.append(bounds[3]-1)
                    sheet.paste(image, (frame*192,row*220), image)
                draw.text((frame*192+55,row*220+198),f'{animation} {frame:02}',fill=(243,231,209))
        assert max(foot_rows)-min(foot_rows)<=4, foot_rows
        sheet.save(out/f'{unit}-{team}-contact.png')
        if unit == 'knight' and team == 'blue':
            sheet.crop((0,220,1536,440)).save(out/'knight-walk-redesign.png')
        print(f'PASS {unit} {team}: 24 frames; walk feet {min(foot_rows)}–{max(foot_rows)}')
    size = sum(p.stat().st_size for p in atlas.rglob('*.png'))
    print(f'{atlas.name}: {size/1024/1024:.2f} MB')
