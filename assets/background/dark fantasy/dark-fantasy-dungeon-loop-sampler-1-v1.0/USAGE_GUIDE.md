# Usage Guide

## Basic horizontal loop

Place two copies of the same background directly beside one another. Move both at the same speed. When one copy moves completely outside the camera, reposition it after the other copy. The right edge and next left edge are designed to join continuously.

## Texture-repeat workflow

Engines that support repeating textures may use one image on a horizontally repeating material or texture region. Confirm that the importer does not clamp the horizontal axis.

## Size choice

- 1600 × 900: recommended runtime source
- 1920 × 1080: convenience upscale for Full-HD canvases
- 1280 × 720: common mid-size runtime export
- 960 × 540: lightweight export and rapid prototype size

## Camera and sprite placement

The lower floor area is intentionally clearer than the architectural background. Place characters above the visible floor line and keep important UI away from the brightest torch, moonlight, fungus, or magma accents.

## Engine notes

- Unity: use a repeating texture material or two side-by-side SpriteRenderers; test texture wrap, compression, filtering, and camera pixels-per-unit in the actual project.
- Godot: use a repeating texture workflow or two side-by-side Sprite2D/TextureRect nodes; test import compression and filtering in the actual project.
- RPG Maker and visual-novel engines: the scenes may be used as battle or dialogue backdrops, but horizontal scrolling may require engine-specific scripting or plugins.

No engine-specific package or importer is included. The supplied files are engine-agnostic PNG assets.

## Accessibility and readability

Test foreground character contrast. Add a subtle local outline, shadow, or grading layer in the game if dark characters disappear against the background.
