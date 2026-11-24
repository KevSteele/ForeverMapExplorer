# WoW Forever Map Explorer

**Summary (for the short field):**
See the areas that you did not discover on the world map, and follow your discovery progress for each zone and continent.

---

**Description (for the project page):**

## What it does

Map Explorer helps you to discover each area of each zone in WoW Forever. It does three things and nothing more.

**1. Fog on the world map.** Each area that you did not discover shows as a dark shape on the map. The edge of the shape is the edge of the area, so you see where to go. You must still go there: the game gives the discovery and its experience as usual.

**2. A progress window.** It has the layout of the Legacy Challenges view of the game.

- The left side lists Azeroth and the continents, each with its percent.
- The right side shows one plate for each zone, with the count of areas and a bar.
- Click a zone to see all its areas, with a check mark for each area that you discovered.
- The "Map" button of a plate opens the world map on that zone.

**3. A progress box on the map.** It shows the progress of the map that you look at: a zone, a continent, or Azeroth.

## Buttons

| Button | Left click | Right click |
|---|---|---|
| Minimap button | Opens or closes the progress window | Nothing |
| World map button | Opens or closes the progress window | Shows or hides the fog and the progress box |

## Commands

| Command | Function |
|---|---|
| `/explore` | Opens or closes the progress window. |
| `/fme on` and `/fme off` | Shows or hides the fog and the progress box. |
| `/fme dim <0-100>` | Sets how dark the fog is. |
| `/fme mode art` and `/fme mode shade` | Shows the art of the area, or only its shape. |
| `/fme box <position>` | Moves the box on the map: `bottom`, `top`, `topleft`, `topright`, `bottomleft`, `bottomright`. |
| `/fme box off` and `/fme box on` | Hides or shows only the box on the map. |
| `/fme coords` (`on`, `off`) | Hides or shows the coordinates on the world map. |
| `/fme minimap` | Hides or shows the minimap button. |

## Good to know

- The progress is for the character that you play. The numbers come from the game.
- The addon has no map scale, no coordinates, and no icons. It does not change the map frame.
- Cities are not in the list.
- The addon counts the areas of the map art. For some zones, this count can be different from the list of the Legacy Challenges view.
- A zone that you complete while the addon runs gets the date of that day. The addon cannot know the date of an earlier completion.

## Credit and licence

The area data comes from [Veilmap](https://www.curseforge.com/wow/addons/veilmap) by xElementzx, licence GPL-3.0-or-later. Thus this addon has the same licence. The package contains the full source and the licence text.

## Feedback

Tell me about errors in the comments. Include the zone and what you see.
