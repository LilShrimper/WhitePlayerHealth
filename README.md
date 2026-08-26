# WhitePlayerHealth

A minimal, flat white player health bar for World of Warcraft. No borders,
no fancy textures — just a clean bar you can drop above your character and
forget about.

## Features

- Ultra-minimal flat bar (white by default) with a thin black border
- Shows automatically while in combat, hides otherwise
- Shield/absorb overlay (blue by default), fill direction configurable
- Bar and shield colors fully customizable via a color picker, with a
  one-click reset back to the white/blue defaults
- Drag to move, drag the corner handle to resize
- Quick-edit panel for typing exact width/height while in edit mode
- Settings panel (`Esc > Options > AddOns > WhitePlayerHealth`) for size,
  position locking, the edit-mode center guide line, shield fill direction,
  and bar/shield colors
- Position, size, and preferences saved per-character

## Usage

| Command | Effect |
| --- | --- |
| `/wph` | Toggle edit mode (movable, resizable, opens the quick-edit panel) |
| `/wph unlock` | Unlock the bar without entering full edit mode |
| `/wph lock` | Lock the bar |
| `/wph reset` | Reset position to default |
| `/wph width <n>` | Set bar width in pixels |
| `/wph height <n>` | Set bar height in pixels |
| `/wph config` | Open the settings panel |

## Installation

Copy the `WhitePlayerHealth` folder (containing `WhitePlayerHealth.lua` and
`WhitePlayerHealth.toc`) into your `World of Warcraft/_retail_/Interface/AddOns`
directory.
