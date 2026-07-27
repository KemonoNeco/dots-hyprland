#!/usr/bin/env python3
# Turn the scss that generate_colors_material.py emits into the JSON matugen accepts as a
# color source (`matugen json <file>`), so matugen's templates (GTK, Hyprland, hyprlock,
# fuzzel, KDE) render from the exact same palette as the shell instead of generating their
# own from the wallpaper. Needed for palette tweaks matugen can't express itself, like the
# greyscale surfaces of --mono_accent.
import argparse
import json
import re

parser = argparse.ArgumentParser(description='Convert generated material scss to matugen JSON')
parser.add_argument('--dark', required=True, help='scss generated with --mode dark')
parser.add_argument('--light', required=True, help='scss generated with --mode light')
parser.add_argument('--mode', required=True, choices=['dark', 'light'], help='which mode is current')
parser.add_argument('--source-color', required=True, help='accent color the scheme was built from')
parser.add_argument('--image', default='', help='wallpaper path, for templates using {{image}}')
parser.add_argument('--out', required=True, help='where to write the JSON')
args = parser.parse_args()

COLOR_LINE = re.compile(r'^\$([A-Za-z0-9_]+):\s*(#[0-9A-Fa-f]{6});')

def read_scss(path: str) -> dict:
    # matugen names roles in snake_case; the scss uses camelCase.
    with open(path) as file:
        matches = (COLOR_LINE.match(line) for line in file)
        return {
            re.sub(r'(?<!^)(?=[A-Z])', '_', match.group(1)).lower(): match.group(2)
            for match in matches if match
        }

modes = {'dark': read_scss(args.dark), 'light': read_scss(args.light)}
for colors in modes.values():
    colors['source_color'] = args.source_color

colors = {
    role: {
        'dark': {'color': modes['dark'][role]},
        'light': {'color': modes['light'][role]},
        'default': {'color': modes[args.mode][role]},
    }
    for role in modes['dark'].keys() & modes['light'].keys()
}

with open(args.out, 'w') as file:
    json.dump({'colors': colors, 'image': args.image}, file)
