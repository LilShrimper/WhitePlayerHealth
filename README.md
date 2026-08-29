# WhitePlayerHealth

A minimal, flat player health bar for World of Warcraft — white by default,
with no portrait, no frame art and no gradients. Just a clean bar you can
drop above your character and forget about.

## Features

- Ultra-minimal flat bar, outlined with a thin black border so it stays
  readable against any background
- Shows automatically while in combat, hides otherwise
- Shield/absorb overlay (blue by default), filling from either direction
- Bar and shield colors set with a color picker and previewed live in the
  settings panel, with one-click restore back to white and blue
- Drag to move and drag the corner handle to resize while in edit mode,
  with optional snapping to the exact center of the screen
- Quick-edit panel for typing exact width and height values
- Restore the default position and size from either panel, with a
  confirmation prompt
- Gets out of the way in combat: both panels close when a fight starts,
  and neither will open mid-fight
- Settings panel at `Esc > Options > AddOns > WhitePlayerHealth`, covering
  size, the edit-mode center guide, shield fill direction and colors
  (moving and resizing is done with `/wph`, not from the panel)
- Settings are saved account-wide and shared by all characters

## Usage

| Command | Effect |
| --- | --- |
| `/wph` | Toggle edit mode (movable, resizable, opens the quick-edit panel) |
| `/wph lock` | Lock the bar and close edit mode |
| `/wph reset` | Restore the default position and size |
| `/wph width #` | Set bar width in pixels |
| `/wph height #` | Set bar height in pixels |
| `/wph config` | Open the settings panel |

`/wph lock` always locks regardless of the current state, so it works as an
escape hatch if the bar ends up somewhere awkward to click.

### In combat

Edit mode and the settings panel both close when combat starts. Asking for
either one mid-fight queues the request instead of refusing it outright, and
it opens as soon as you leave combat.

## Installation

Copy the entire `WhitePlayerHealth` folder into
`World of Warcraft/_retail_/Interface/AddOns`, then restart the game or run
`/reload`. All files in the folder are required.

## Compatibility

Built for World of Warcraft: Midnight (interface `120100`). It relies on the
current Settings API and on color and resize functions added in recent
versions, so it will not run on older clients.
