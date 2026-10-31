# Quest for Duskara: brand kit prompts

Generate each asset **on its own, in a fresh chat or image session**, in the
order below. Attach the files listed under **Attach** to every prompt. Assets
made later use earlier ones as references, so keep them consistent.

Earlier work in this folder: `quest-for-duskara-logo-prompt.md`,
`quest-for-duskara-app-icon-prompt.md`, and their PNGs. This kit replaces
them with a fuller, more polished set.

**Never let the image model draw the title text on banners.** Generate the
art with no text, then place the finished title logo (asset 2) on top in
Figma, Pixelmator, or Photoshop. Lettering from image models drifts between
sizes and looks amateur. The only asset where the model draws text is the
title logo itself, and you regenerate that until the spelling is perfect.

---

## 0. Shared style block (paste at the top of every prompt)

```
STYLE — QUEST FOR DUSKARA BRAND
Game: a calm single-player island strategy game for macOS. You build a small
island town, train knights and archers, sail between 15 islands, and capture
Duskara's stronghold before dusk falls on the archipelago.

Visual DNA (from the game itself): low-poly "soft clay" 3D. Chunky, bevelled,
rounded primitives with matte, slightly hand-pressed surfaces, like premium
polymer clay or soft vinyl toys. Cream plaster walls, terracotta and coral
roofs, straw roofs, slate roofs, olive-green island tiles, pale aqua shallows
over a deep teal sea, and a warm orange setting sun.

Polish level (reference: the indie icon designer at appicons.store): ONE bold,
instantly readable hero subject. Big simple silhouette. Chunky, toy-like
volumes. Soft studio lighting with a gentle top-left key light, a crisp
specular highlight on curved edges, a subtle rim light, and soft contact
shadows. Rich but controlled saturation. Clean, flat, or very softly graded
backgrounds. Zero clutter, zero noise, no tiny details that vanish at small
sizes. Feels hand-made by one careful designer, not stock or generic AI art.

Palette (stay inside it):
  plaster cream   #EDDEBF   ink parchment  #F2E8D1
  terracotta      #C9735C   coral highlight #E08F73   banner red #C76152
  sunset orange   #F0A64F   accent orange  #D17A3D   warm gold  #E6B35C
  island olive    #8CAD66   crop green     #8CAB61   moss       #526E42
  shallow aqua    #8FC4C8   sea            #5F8F9C   deep sea   #2A5262
  deep teal bg    #1B4A5E   slate roof     #70808A   timber     #8F6B4A
  dark panel      #29211A   (outlines and dark text only)

Avoid: dark/gothic fantasy, grimdark, realistic humans, photorealism,
metallic chrome, lens flare, heavy grain, busy filigree, neon, purple,
generic "mobile game" gloss explosions, watermarks, signatures, UI elements,
borders, device mockups, and any text unless the prompt asks for it.
```

**Attach to every prompt:** `Assets/Brand/quest-for-duskara-app-icon-1024.png`
(the current tower/island/sun emblem) and one or two game screenshots, such as
`Screenshots/v0.02/village.jpg` and `Screenshots/v0.02/world-map.jpg`. Once
asset 1 exists, attach it too.

---

## 1. Hero emblem (master mark, no text)

The one image that every other asset builds on.

```
[STYLE BLOCK]

Create the master emblem for Quest for Duskara: an enhanced, professional
version of the attached tower-on-island emblem.

Subject: one small rounded olive island tile with a soft cream shoreline rim,
floating in pale aqua shallows. On it stands a single chunky cream plaster
watchtower with a coral-terracotta conical roof, a little terracotta pennant
flag, an arched doorway, two cream stone steps, and one warm-lit window
(#FFCC78 glow). Two or three round moss-green bushes. Behind the tower, a
large warm orange setting sun, half-hidden by the island, gives the "dusk"
idea. Optional: one tiny cream-sailed boat at the island's edge, only if it
stays readable.

Enhance compared with the reference: stronger silhouette, cleaner shapes,
richer clay material with crisp highlights on bevels, a softer and more
premium light, and more confident proportions (tower slightly taller and
bolder). Keep the same charm and the same 3/4 top-down camera angle.

Output: 2048×2048 px, subject centered, filling about 70% of the canvas,
on a TRANSPARENT background (or a perfectly flat #FF00FF background that I
will key out). No text, no frame, no shadow plate under the whole image.
```

Save as `duskara-emblem-2048.png`.

---

## 2. Title logo (wordmark lockup)

The "Clash of Clans" style title. Make **three versions, each in its own
session**, all attaching asset 1.

### 2a. Primary stacked title logo

```
[STYLE BLOCK]

Create the official title logo for "QUEST FOR DUSKARA".

Layout: the attached emblem sits centered on top and slightly overlaps the
wordmark. Below it, small "QUEST FOR" sits above a large, dominant "DUSKARA".

Lettering: a custom chunky slab-serif display face, condensed and sturdy,
with a hand-carved, adventurous feel. The letters are dimensional like the
clay emblem: parchment-cream faces (#F2E8D1 to #EDDEBF gradient) with a
soft rounded bevel, a short warm-terracotta extrusion (#A35745) to the
bottom, and a clean dark-brown outer outline (#29211A) of even thickness.
A subtle warm sunset glow on the top edge of the letters. "QUEST FOR" uses
the same face, smaller, in warm gold (#E6B35C) with the same outline. Tight,
even letter spacing. A very slight upward arc on "DUSKARA" is fine. Keep it
highly legible.

Text (spell exactly, once each, all caps): "QUEST FOR" and "DUSKARA".

Output: 3000×2000 px, TRANSPARENT background (or flat #FF00FF to key out),
generous padding on all sides, nothing cropped. No plaque, banner ribbon,
shield, swords, or extra ornaments behind the text.
```

### 2b. Horizontal title logo

```
[STYLE BLOCK]
Use the attached title logo as the exact design reference: same lettering,
colors, outline, extrusion, and emblem. Recompose it as a single horizontal
line: the emblem on the left, then "QUEST FOR" stacked small above "DUSKARA"
to its right. 4000×1200 px, transparent background, generous padding.
Do not redesign the letters.
```

### 2c. Flat one-color wordmark

```
Use the attached title logo as the exact reference. Redraw ONLY the lettering
"QUEST FOR / DUSKARA" (no emblem) as flat solid vector-style shapes in one
color, #F2E8D1, with no bevel, extrusion, outline, or gradient. Perfectly flat
#1B4A5E background. 3000×1200 px. This is for small sizes, watermarks,
embossing, and single-color printing.
```

Afterwards: key out the background, trim, and export the PNGs at 100% and
50%. Vectorize 2c (Figma's "Vectorize", Illustrator Image Trace, or
vectorizer.ai) to get an SVG for the website.

---

## 3. macOS app icon

### Apple's rules (macOS 26 Tahoe, which this game targets)

- **Full-bleed, square, 1024×1024 px, fully opaque, with NO alpha channel.**
  Don't draw the rounded square, drop shadow, or transparent margin that
  icons used from Big Sur to Sequoia. macOS 26 applies the squircle mask and
  shadow itself. An icon that keeps its own transparent margin gets put
  inside a grey "jail" plate.
- Keep the important parts inside the **central ~800×800 px**. The corners
  get masked off, and Liquid Glass adds edge highlights there.
- No text, no photos, no fine lines. It has to read at **16×16 px** in
  Finder list view and 32×32 px in the Dock's "recent" area.
- Provide **Default (light)**, **Dark**, and **Tinted** appearances. The
  asset catalog already has slots for all three.
- Optional but best: build it in **Icon Composer** (Xcode 26 → Open Developer
  Tool → Icon Composer) from separate layers so Liquid Glass can give it real
  depth. Prompt 3d makes those layers.

### 3a. Default icon

```
[STYLE BLOCK]

Create a macOS app icon from the attached emblem, in the appicons.store
style: one bold, centered, chunky hero object.

Subject: the cream tower with the coral roof and flag, on its olive island,
with the orange sun behind it. Zoom in more than the emblem does: the tower
and island fill the center, and the subject's bounding box takes up about
65–70% of the canvas, kept inside the central 78% safe circle. Simplify: no
more than 2 bushes and no stones, so the shape reads at 16 px. Make the
tower's silhouette extra bold.

Background: FULL-BLEED, edge to edge, perfectly square canvas, completely
opaque. A smooth radial gradient from deep teal #1B4A5E (edges) to a slightly
lighter #2A5E70 behind the subject, with a very soft warm sunset bloom
(#F0A64F at 15% opacity) behind the sun.

Output: exactly 1024×1024 px. Do NOT draw rounded corners, a squircle
shape, a border, a drop shadow around the icon, transparent margins, a
gloss sheen, a device frame, or any text.
```

### 3b. Dark icon

```
Use the attached default icon as the exact reference. Same subject, pose,
size, and position. Change only the lighting and background to night/dusk:
background is a near-black teal radial gradient (#0E2630 at the edges,
#173A47 at the center). The sun becomes a lower, deeper orange (#D17A3D)
with a soft glow. The tower's window glows warm (#FFCC78). The clay
materials get slightly darker and more saturated. 1024×1024, full-bleed,
opaque, no rounded corners, no text.
```

### 3c. Tinted icon

```
Use the attached default icon as the exact reference. Same composition.
Render it as a GRAYSCALE luminance image: the subject in light-to-mid greys
with clear value separation between the roof, walls, island, and sun, on a
flat pure-black background (#000000). macOS tints this image with the user's
accent color. 1024×1024, opaque, no rounded corners, no text.
```

### 3d. Icon Composer layers (optional, best quality)

Generate each layer separately from the 3a result. Ask for each layer, then
the next:

```
Use the attached icon as the exact reference. Output ONLY the [LAYER] on a
TRANSPARENT background at 1024×1024, in exactly the same position and scale
as in the reference, with nothing else:
  Layer 1 "background": the full-bleed teal gradient only (opaque, no subject).
  Layer 2 "sun": only the orange sun disc.
  Layer 3 "island": only the island, shoreline rim, and aqua shallows.
  Layer 4 "tower": only the tower, roof, flag, and bushes.
Flat colors and soft shading only; no baked drop shadows, because Icon
Composer adds its own.
```

Put the layers into Icon Composer back to front, set the per-layer glass and
shadow there, and export `AppIcon.icon` into the project.

### 3e. Verify and fix the icon PNGs (run on every icon file)

The current icons in `AppIcon.appiconset` **have an alpha channel**. Check
each new file:

```bash
sips -g hasAlpha -g pixelWidth -g pixelHeight icon.png
```

You want `hasAlpha: no`, `1024`, `1024`. To remove alpha without losing
quality (macOS `sips` round-trips the image through BMP):

```bash
sips -s format bmp icon.png --out /tmp/icon.bmp && sips -s format png /tmp/icon.bmp --out icon.png
```

Then drop the three files into `Assets/Assets.xcassets/AppIcon.appiconset`
(Default, Dark, Tinted). Build the app and check the icon in the Dock, in
Finder (list and icon views), and in Launchpad with light, dark, and tinted
appearances.

---

## 4. Master key art (the banner source)

One wide, text-free scene. Every banner below is recomposed from it.

```
[STYLE BLOCK]

Create the key art for Quest for Duskara: a wide, cinematic, text-free
diorama of the archipelago at dusk.

Scene: a deep teal sea with pale aqua shallows around three or four soft-clay
islands at different distances. Foreground right: the player's cozy island
town (cream plaster cottages, terracotta and straw roofs, a pier, farm
fields, the tower from the emblem) with warm-lit windows. Midground: two
small ships with cream sails heading across the water, and a short line of
tiny chunky knights (blue-steel helmets, cream tabards) and archers on the
pier. Far left on the horizon: Duskara's stronghold, a larger fortress
island with slate roofs and red banners, silhouetted against a huge, low
orange setting sun. The sky goes from warm gold at the horizon to soft teal
at the top. Gentle long shadows.

Same 3/4 elevated camera and toy-diorama soft-clay look as the game. Calm,
inviting, adventurous: the moment before the campaign begins.

Composition: keep the CENTER-LEFT upper third fairly empty (calm sky) so
the title logo can sit there. Keep the important subjects away from the
outer 10% edges.

Output: 3840×2160 px (16:9). No text, no UI, no logo, no border.
```

Save as `duskara-keyart-3840x2160.png`.

---

## 5. Banners, by size

For each size, start a new session, attach the **key art (4)**, and use this
template:

```
[STYLE BLOCK]
Use the attached key art as the exact reference for style, palette, lighting,
and subjects. Recompose (don't stretch or crop awkwardly) the scene for a
[W]×[H] px canvas. [COMPOSITION NOTE]. No text, no logo. Keep everything
important inside the safe area: [SAFE AREA].
```

Then place the title logo (2a or 2b) in Figma at the logo spot noted below.

| # | Use | Size (px) | Composition note | Safe area / logo spot |
|---|-----|-----------|------------------|-----------------------|
| 5.1 | GitHub social preview (repo Settings → Social preview) | 1280×640 | Town on the right, sun and stronghold on the left | 40 px margin; horizontal logo (2b) on the left half |
| 5.2 | README header banner | 1600×500 | Very wide and shallow: the sea, three islands, and the sun in the center | Center 1000×360; stacked logo centered |
| 5.3 | Website Open Graph / link-share image | 1200×630 | Like 5.1, a bit tighter | Center 1100×560; horizontal logo |
| 5.4 | Website hero background | 2880×1200 | Sky-heavy, subjects in the lower 45% | Logo upper center; also export a 1440×600 copy |
| 5.5 | Discord server banner | 960×540 | Town and sun in the center | Discord covers the bottom-left with the server name, so keep it clear; small logo top-right |
| 5.6 | Discord invite splash | 1920×1080 | Same as the key art, with a darker vignette at the edges | No logo; Discord overlays the invite card in the center |
| 5.7 | X / Twitter header | 1500×500 | Panoramic, sun right of center | The avatar covers the bottom-left 400×200, so keep it clear |
| 5.8 | YouTube channel art | 2560×1440 | Full scene | Logo only inside the center 1546×423 |
| 5.9 | itch.io cover | 630×500 | Close crop on the town and the tower | Logo across the bottom third |
| 5.10 | Steam header capsule | 920×430 | Town plus the sun | Logo must fill about 1/3 of the width |
| 5.11 | Steam main capsule | 1232×706 | Full scene | Logo left or centered |
| 5.12 | Steam small capsule | 462×174 | Mostly logo over a simple sky/sea | Logo fills most of it |
| 5.13 | Steam vertical library capsule | 600×900 | Tall: tower and sun on top, sea and ships below | Stacked logo in the upper third |
| 5.14 | Steam library hero | 3840×1240 | Wide scene, **no logo** | Center 860×380 holds the main subjects |
| 5.15 | Phone/desktop wallpaper (community gift) | 2560×1600 and 1290×2796 | Full scene | Small logo, bottom center |

Skip the Steam rows (5.10–5.14) until there's a Steam page.

---

## 6. Small marks

### 6.1 Discord server icon, avatar, and favicon

```
[STYLE BLOCK]
Use the attached app icon (3a) as the exact reference. Recompose it for a
CIRCULAR crop: the tower, island, and sun centered inside the central 80%
circle, over the same full-bleed teal gradient. 1024×1024, opaque, no text.
```

Export 512×512 (Discord, GitHub org, social avatars). For the website, export
favicon sizes 32×32, 180×180 (`apple-touch-icon`), and 512×512. Check the
32 px version on its own; if the tower isn't readable, ask for "tower and
sun only, no island details".

### 6.2 Discord custom emoji (optional, 128×128, transparent)

One prompt per emoji, attaching asset 1:

```
[STYLE BLOCK]
A single [SUBJECT] as a chunky soft-clay game icon in the attached emblem's
style, centered, filling 85% of a 512×512 TRANSPARENT canvas, with a thin
dark-brown outline (#29211A) so it reads on both light and dark Discord
themes. No text.
```

Subjects: a gold coin stack, a wheat sheaf (food), a glowing blue gear
(skill), a knight's helmet, an archer's bow, the tower, a sailing ship, a
red banner flag, and a sun setting into the sea ("dusk"). Downscale to
128×128.

---

## 7. Where the files go

Everything in `Assets/` is bundled into the app, so the kit lives in
`brand-assets/` and only the app icon goes in `Assets/AppIcon.icon`.

```
brand-assets/
  emblem/      duskara-emblem-2048.png
  logo/        title-stacked.png, title-horizontal.png, wordmark-flat.svg
  icon/        icon-default.png, icon-dark.png, icon-tinted.png
  keyart/      duskara-keyart-3840x2160.png
  banners/     <use>-<W>x<H>.png   (e.g. github-social-1280x640.png)
  social/      avatar-512.png, favicon-32.png, apple-touch-icon-180.png
```

Before committing, compress large PNGs (`pngquant` or ImageOptim) so the
repo and the Pages site stay small. The key art and Steam hero can be JPGs
at 85–90% quality.
