Pixel Parallax Backgrounds Lite
===============================

4 seamless pixel art parallax backgrounds for platformers, runners,
metroidvanias, shmups and menus: 1 scenes x 4 times of day (dawn, day,
sunset, night), 28 separate layers, 2 animated overlays and 1 matching
ground tilesets. Every scene keeps the same layout at every time of day, so
you can cross-fade them into a real day / night cycle.

WHAT'S INSIDE
  Scenes: Forest
  4 backgrounds (1 scenes x 4 times of day), 28 layers, each scene
    5 to 9 layers, plus a merged flat version of every background
  2 animated overlays, 16 frames each, seamless loop: snow, fireflies
  1 ground tilesets (16 x 16), one per scene, 16 tiles each
  1 ready Godot 4 scenes with a day / night cycle, 2 Unity scripts

FOLDERS
  willosuna_parallax/x1/   original pixel size (layers are 640 x 180, the view
                           is 320 x 180: 16:9, scales to 1280 x 720 and 1920 x
                           1080 at whole numbers)
  willosuna_parallax/x4/   the same files at 4x, ready to drop in
    backgrounds/<scene>/<time>/layers/NN_<name>.png   back (00) to front
    backgrounds/<scene>/<time>/<scene>_<time>_flat.png all layers merged
    overlays/<name>/frame_NN.png and overlays/<name>_sheet.png (4 x 4 grid)
    tiles/<scene>_tileset.png  16 x 16 tiles in a 4 x 4 grid
  willosuna_parallax/godot/    ready Godot 4 scenes + day / night script
  willosuna_parallax/unity/    ParallaxLayer.cs and DayNightBlend.cs
  willosuna_parallax/manifest.json   every layer with its scroll scale,
                           autoscroll speed and draw order; every overlay and
                           tileset with its grid
  project.godot            open this folder in Godot 4.3+ to see the demo

SEAMLESS
  Every layer repeats horizontally with no seam: place copies every 640 px
  (x1) or 2560 px (x4). Overlays repeat in both directions.

PARALLAX SPEEDS
  manifest.json gives scroll_scale for each layer, from 0.0 (sky, fixed) to
  1.0 (foreground, moves with the camera). Clouds, fog, smoke and nebula also
  have a slow autoscroll so the sky drifts even when the camera stops.

GODOT 4 (4.3 or newer)
  Open the unzipped folder as a project and press Play: arrow keys scroll,
  up / down change the time of day. To use it in your game, copy the
  willosuna_parallax folder into the root of your project (res://) and
  instance any scene from willosuna_parallax/godot/scenes/. The root node has
  time_of_day, cycle and cycle_seconds in the Inspector. Each time of day is
  a CanvasGroup of Parallax2D nodes, so the cross-fade is clean.
  Keep Project Settings > Rendering > Textures > Default Texture Filter on
  Nearest (the scenes also set it).

UNITY
  Texture import: Filter Mode Point, Compression None, Pixels Per Unit 16 (or
  your own grid). Add each layer as a SpriteRenderer, back to front, and add
  ParallaxLayer.cs with the scroll_scale from manifest.json; it makes the
  copies it needs for an endless loop. For a day / night cycle put the four
  time-of-day sets under four parents and add DayNightBlend.cs.

GAMEMAKER, CONSTRUCT, DEFOLD, PHASER, LOVE2D...
  Use one background layer per PNG with horizontal tiling on and the
  scroll_scale from manifest.json as the parallax factor.

TILESETS
  Grid order (4 x 4): top_left, top, top_right, platform_left / left, center,
  right, platform_middle / bottom_left, bottom, bottom_right, platform_right /
  4 decorations (grass, rock, flower, bush). Top, center and bottom tiles
  repeat without seams.

HOW IT WAS MADE
  Every pixel is drawn by original code: periodic noise for seamless
  ridges, per-face mountain shading, Bayer dithering only in the gradients,
  closed palettes per time of day. No generative AI, no third-party art.

THE FULL PACK
  Pixel Parallax Backgrounds has 64 backgrounds: 16 scenes x 4 times of
  day, 9 animated overlays, 16 tilesets and 16 Godot scenes.
  https://willosuna.itch.io/pixel-parallax-backgrounds

LICENSE
  Free for commercial use, royalty free, no attribution required. Reselling or
  redistributing the image files as an asset pack is not permitted. Full
  terms in LICENSE.txt
