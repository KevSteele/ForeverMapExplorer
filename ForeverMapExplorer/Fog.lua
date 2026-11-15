--[[
WoW Forever Map Explorer - the fog. It shows the areas that you did not discover on the world map, with a dark tint.
GPL-3.0-or-later.

The area data (Data_Forever.lua, global VeilmapFogData) comes from Veilmap by xElementzx,
https://github.com/xElementzx/Veilmap, GPL-3.0-or-later. This file is new code.

How it works:
- The game gives the art of the areas that you discovered (GetExploredMapTextures).
- The data table has the art of all areas of a map.
- This addon draws the art of each area that is in the table but not in the list of the game.
- It draws the art with a dark colour, so the edge of the tint is the edge of the area.
]]

local _, ns = ...

local DEFAULTS = { enabled = true, dim = 60, mode = "shade", mapPanel = true, minimapAngle = 200 }
local db = DEFAULTS

local frame      -- the parent of all tint textures, on the map canvas
local pool = {}  -- all textures that this addon made
local used = 0   -- the number of textures in use

local function Print(msg) -- also ns.Print, below
	print("|cff88aaffMap Explorer:|r " .. msg)
end

-- The smallest power of two that is not less than n, from 16. This is the size of a tile file.
local function FileSize(n)
	local size = 16
	while size < n do
		size = size * 2
	end
	return size
end

local function Canvas()
	local container = WorldMapFrame and WorldMapFrame.ScrollContainer
	return container and container.Child
end

local function HideAll()
	for i = 1, used do
		pool[i]:Hide()
	end
	used = 0
end

local function Acquire()
	used = used + 1
	local tex = pool[used]
	if not tex then
		tex = frame:CreateTexture(nil, "ARTWORK")
		pool[used] = tex
	end
	return tex
end

-- Draw one area. The layout of the tiles is the same as the layout that the game uses.
local function DrawArea(entry, tileW, tileH, shade)
	local width, height, offsetX, offsetY, files = entry[1], entry[2], entry[3], entry[4], entry[6]
	local wide = math.ceil(width / tileW)
	local tall = math.ceil(height / tileH)
	local index = 0
	for fileID in files:gmatch("%d+") do
		index = index + 1
		local row = math.floor((index - 1) / wide) + 1
		local col = (index - 1) % wide + 1
		if row > tall then
			break
		end
		local pixelW, fileW = tileW, tileW
		if col == wide then
			pixelW = width % tileW
			if pixelW == 0 then pixelW = tileW end
			fileW = FileSize(pixelW)
		end
		local pixelH, fileH = tileH, tileH
		if row == tall then
			pixelH = height % tileH
			if pixelH == 0 then pixelH = tileH end
			fileH = FileSize(pixelH)
		end
		local tex = Acquire()
		tex:ClearAllPoints()
		tex:SetSize(pixelW, pixelH)
		tex:SetTexCoord(0, pixelW / fileW, 0, pixelH / fileH)
		tex:SetPoint("TOPLEFT", frame, "TOPLEFT", offsetX + tileW * (col - 1), -(offsetY + tileH * (row - 1)))
		tex:SetTexture(tonumber(fileID))
		if db.mode == "art" then
			-- The art of the area, made darker.
			tex:SetVertexColor(shade, shade, shade * 1.15, 1)
		else
			-- Only the shape of the area, as a flat dark shade. The art stays hidden,
			-- so the map below looks the same as the game shows it.
			tex:SetVertexColor(0, 0, 0, 1 - shade)
		end
		tex:Show()
	end
end

local function Refresh()
	if not frame then
		return
	end
	HideAll()
	if not db.enabled or not WorldMapFrame:IsShown() then
		return
	end
	local mapID = WorldMapFrame:GetMapID()
	if not mapID then
		return
	end
	local artID = C_Map.GetMapArtID(mapID)
	local areas = artID and VeilmapFogData and VeilmapFogData[artID]
	if not areas then
		return
	end

	-- The areas that the game shows. The position and the size identify an area.
	local seen = {}
	local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID)
	if explored then
		for _, info in ipairs(explored) do
			seen[info.offsetX .. ":" .. info.offsetY .. ":" .. info.textureWidth .. ":" .. info.textureHeight] = true
		end
	end

	local layers = C_Map.GetMapArtLayers(mapID)
	local layer = layers and layers[1]
	local tileW = layer and layer.tileWidth or 256
	local tileH = layer and layer.tileHeight or 256
	local shade = 1 - db.dim / 100

	for _, entry in ipairs(areas) do
		if not seen[entry[3] .. ":" .. entry[4] .. ":" .. entry[1] .. ":" .. entry[2]] then
			DrawArea(entry, tileW, tileH, shade)
		end
	end
end

-- An error in the map code of the game must not stop the map. Thus all calls go through pcall.
local function SafeRefresh()
	local ok, err = pcall(Refresh)
	if not ok then
		pcall(HideAll)
		if db.debug then
			Print("error: " .. tostring(err))
		end
	end
end

local function Setup()
	local canvas = Canvas()
	if frame or not canvas then
		return
	end
	frame = CreateFrame("Frame", "ForeverMapExplorerFogFrame", canvas)
	frame:SetAllPoints(canvas)
	frame:SetFrameLevel(canvas:GetFrameLevel() + 1)
	WorldMapFrame:HookScript("OnShow", SafeRefresh)
	hooksecurefunc(WorldMapFrame, "OnMapChanged", SafeRefresh)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MAP_EXPLORATION_UPDATED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		if type(ForeverMapExplorerDB) ~= "table" then
			ForeverMapExplorerDB = {}
		end
		for key, value in pairs(DEFAULTS) do
			if ForeverMapExplorerDB[key] == nil then
				ForeverMapExplorerDB[key] = value
			end
		end
		db = ForeverMapExplorerDB
		ns.db = db
		if ns.OnLogin then pcall(ns.OnLogin) end
		pcall(Setup)
	end
	SafeRefresh()
end)

ns.Print = Print
ns.db = db
ns.RefreshFog = function() SafeRefresh() end

SLASH_MAPFOG1 = "/fme"
SLASH_MAPFOG2 = "/mapfog"
SlashCmdList.MAPFOG = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "on" or cmd == "off" then
		db.enabled = (cmd == "on")
		Print(db.enabled and "on." or "off.")
	elseif cmd == "dim" and tonumber(arg) then
		db.dim = math.max(0, math.min(100, tonumber(arg)))
		Print("dim is " .. db.dim .. " percent.")
	elseif cmd == "mode" and (arg == "shade" or arg == "art") then
		db.mode = arg
		Print(arg == "shade" and "mode shade: a flat dark shape, the art stays hidden."
			or "mode art: the art of the area, made darker.")
	elseif cmd == "progress" then
		if ns.ToggleProgress then ns.ToggleProgress() end
		return
	elseif cmd == "minimap" then
		if ns.ToggleMinimapButton then ns.ToggleMinimapButton() end
		return
	elseif cmd == "debug" then
		db.debug = not db.debug
		Print("debug is " .. (db.debug and "on." or "off."))
	elseif cmd == "status" then
		local mapID = WorldMapFrame:GetMapID()
		local artID = mapID and C_Map.GetMapArtID(mapID)
		Print(("map %s, art %s, data %s, tiles in use %d."):format(tostring(mapID), tostring(artID),
			(artID and VeilmapFogData and VeilmapFogData[artID]) and "yes" or "no", used))
	else
		Print("/fme on | off | dim <0-100> | mode shade | mode art | progress | minimap | status | debug")
		Print("dim: 0 is no tint, 100 is black. The value now is " .. db.dim .. ". The mode now is " .. db.mode .. ".")
		return
	end
	SafeRefresh()
end
