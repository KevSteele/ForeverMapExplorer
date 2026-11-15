# WoW Forever Map Explorer

Map Explorer shows the areas that you did not discover on the world map, with a dark tint.
The edge of the tint is the edge of the area. The addon has no other feature.

You must still go into an area to discover it. The game gives the discovery experience as usual.

## Commands

| Command | Function |
|---|---|
| `/fme on` and `/fme off` | Shows or hides the tint. |
| `/fme dim <0-100>` | Sets the tint. 0 is full colour. 100 is black. The default is 60. |
| `/fme mode shade` | Shows only the shape of the area as a flat dark shade. The art stays hidden. This is the default. |
| `/fme mode art` | Shows the art of the area, made darker. |
| `/explore` or `/fme progress` | Opens the discovery progress window. |
| `/fme minimap` | Shows or hides the minimap button. |
| `/fme status` | Prints the map, the art number, and the number of tiles in use. |
| `/fme debug` | Prints errors to the chat. |

## The buttons

- The minimap button: a left click opens the progress window. A right click sets the fog to on or off. Drag it to move it.
- The world map button: a left click shows or hides the progress panel on the map. A right click opens the progress window.
- The progress panel shows the progress of the map that you look at: a zone, a continent, or Azeroth.

## The progress window

The layout follows the Legacy Challenges view of the game.
The left side lists Azeroth and the continents. The right side shows plates.
Click a continent to show its zones. Click a zone to show its areas, with a check mark for each discovered area.
Use the "Map" button of a plate, or a right click on the plate, to open the map.

The window shows the discovered areas for each zone, for each continent, and for Azeroth.
The numbers are for the character that you play now. The game supplies them, and nothing is saved.
Point at a zone to see the areas that you did not discover. Click a zone to open its map.
Cities and maps with no area data are not in the list.

## Data and licence

The file `Data_Forever.lua` comes from Veilmap by xElementzx:
https://github.com/xElementzx/Veilmap. Its licence is GPL-3.0-or-later.
It is an unchanged copy. The author made it from the data tables of WoW build 1.60.1.69913.

Thus this addon also has the licence GPL-3.0-or-later. It is for private use.
If you publish it, include the full text of the licence.

After a game patch that adds or changes maps, get a new copy of the data file.
