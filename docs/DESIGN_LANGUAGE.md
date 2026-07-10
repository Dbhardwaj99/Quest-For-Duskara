# Design Language

> **Vision:**
> Create a world that feels like a handcrafted miniature rather than a realistic simulation. Every object should look intentionally designed, with soft forms, calm colors, and subtle animation. The world should evoke the feeling of placing painted wooden buildings on a living ocean.

---

# Inspiration

Primary inspiration:

- Townscaper
- Bad North
- Miniature architectural models
- Handcrafted wooden toys
- Mediterranean coastal villages

The goal is **not** realism.

Instead, the world should feel:

- Calm
- Playful
- Cozy
- Timeless
- Procedural, yet handcrafted

---

# Core Principles

## 1. Geometry over Textures

Geometry creates detail.

Avoid detailed textures entirely.

Instead of adding visual complexity through texture maps:

- Bevel edges
- Round corners
- Extrude windows
- Model roof trims
- Model balconies
- Model stairs

Meshes should provide visual richness.

---

## 2. Rounded Everything

Nothing should feel perfectly sharp.

Every asset should have:

- Soft corners
- Rounded edges
- Slight bevels
- Thick proportions

Avoid paper-thin geometry.

Buildings should feel almost sculpted.

---

## 3. Flat Materials

Materials should be extremely simple.

Use:

- Solid colors
- Matte surfaces
- Very subtle roughness variation

Avoid:

- Brick textures
- Wood textures
- Metal scratches
- Dirt
- Weathering

Lighting should create depth instead of textures.

---

## 4. Pastel Color Palette

Use muted, slightly desaturated colors.

Examples:

- Warm white
- Sand
- Terracotta
- Dusty red
- Sage green
- Muted teal
- Pale yellow
- Ocean blue
- Deep navy

No highly saturated colors.

The world should remain visually relaxing.

---

## 5. Soft Lighting

Lighting should resemble an overcast afternoon.

Characteristics:

- Soft shadows
- Gentle ambient lighting
- Warm sunlight
- Low contrast
- Minimal bloom

The lighting should support readability rather than realism.

---

## 6. Secondary Motion

Nothing should appear completely static.

Every interaction should include subtle motion.

Examples:

- Buildings slightly settle after placement
- Flags gently sway
- Water continuously moves
- Birds glide slowly
- Trees subtly sway
- Boats gently bob

Movement should be calm and restrained.

---

# Ocean Design

The ocean is a living surface rather than a realistic fluid simulation.

It should communicate life through small, elegant motion.

---

## Ocean Mesh

The ocean consists of one continuous plane.

It is not composed of individual water tiles.

The mesh should remain lightweight.

---

## Wave Simulation

Use layered Gerstner waves.

Recommended layers:

- Large waves
- Medium waves
- Tiny ripples

All amplitudes should remain intentionally small.

The water should never appear rough.

It should gently breathe.

---

## Water Shader

The shader is responsible for almost all visual richness.

It should include:

- Animated normals
- Small vertex displacement
- Fresnel effect
- Reflection
- Depth coloring

Avoid excessive distortion.

---

## Water Color

Blend between multiple colors.

Deep water:

- Dark blue

Shallow water:

- Lighter blue

Near structures:

- Slight turquoise tint

The transitions should be smooth.

---

## Shore Foam

Generate permanent shoreline foam wherever land meets water.

Foam should:

- Be soft
- Slowly animate
- Fade naturally
- Never appear noisy or chaotic

Foam should be subtle rather than dramatic.

---

## Ripples

Ripples are one of the defining visual features.

Every interaction with the world should create expanding circular ripples.

Examples:

- Building placement
- Building removal
- Boat movement
- Object impacts

Ripple characteristics:

- Circular
- Thin white ring
- Smooth expansion
- Constant speed
- Gradual fade

Ripples should be shader-driven rather than particle-based.

---

# Animation Principles

Every animation should use easing.

Avoid linear movement.

Objects should:

- Stretch
- Settle
- Ease into place

Animations should feel physical without becoming exaggerated.

---

# Buildings

Buildings should feel handcrafted.

Characteristics:

- Thick walls
- Rounded roofs
- Chunky proportions
- Large windows
- Soft silhouettes

Avoid unnecessary geometric detail.

The silhouette matters more than the fine detail.

---

# Environment

The world should feel peaceful.

Avoid clutter.

Use repetition with variation.

Natural elements should include:

- Calm ocean
- Small islands
- Simple vegetation
- Birds
- Boats
- Clouds

Every element should support the miniature aesthetic.

---

# Camera

The camera should reinforce the feeling of looking at a handcrafted model.

Guidelines:

- Slight downward angle
- Gentle perspective
- Slow movement
- Smooth interpolation
- Minimal camera shake

The player should feel like they are observing a tabletop world.

---

# Performance Philosophy

Favor visual consistency over technical complexity.

Whenever possible:

- Fake expensive effects
- Use shaders instead of simulations
- Use geometry instead of textures
- Keep meshes lightweight
- Keep materials simple

The player should perceive richness without paying the cost of realism.

---

# Visual Identity

The intended visual identity is:

> A handcrafted miniature world floating on a calm, living ocean, where every structure feels sculpted, every interaction creates gentle motion, and every visual element prioritizes warmth, simplicity, and timeless stylization over realism.

---

# Implementation Map

Where each pillar lives in code:

| Pillar | Implementation |
|---|---|
| Pastel palette | `World3DTheme.swift` — the `c()` pastel pass every palette color flows through |
| Soft lighting | `World3DRenderer.configureView()` — softened shadowed sun + cool fill light |
| Living ocean | `World3DOcean.swift` (ring mesh, ripple driver) + `OceanShaders.metal` (waves, depth color, fresnel, foam, ripples) |
| Settle animation | `World3DRenderer.playSettleAnimation(on:)` on placement |
| Interaction ripples | `World3DRenderer.render()` → `World3DOcean.ripple(at:)` on any tile content change |
| Secondary motion | `addAmbientDrift`/`addDriftAnimation` (banners, boats, smoke, sheep), `addBirds` orbits |
| Geometry over textures | `World3DRenderResources` rounded-box/sphere/cone primitives; no texture maps |
