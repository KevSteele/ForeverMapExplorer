--[[
WoW Forever Map Explorer - the minimap button, the world map button, and the map panel.
GPL-3.0-or-later.

- The minimap button: a left click opens and closes the progress window.
- The world map button: a left click opens and closes the progress window,
  a right click shows and hides the fog on the map.
- The map panel shows the progress of the map that you look at:
  a zone, a continent, or Azeroth.
- The coordinates line on the world map shows your position and the
  position of the cursor.
]]

local _, ns = ...

local ICON = "Interface\\Icons\\INV_Misc_Map02"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local PANEL_WIDTH = 260

local mapButton, panel, minimapButton, coords

-- A round button in the style of the minimap buttons. Questie and the fishing addon
-- use the same parts, so the buttons look like a set.
local function RoundButton(parent, name)
	local b = CreateFrame("Button", name, parent)
	b:SetSize(32, 32)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(25, 25)
	bg:SetPoint("TOPLEFT", 2, -4)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(ICON)
	b.icon:SetSize(22, 22)
	b.icon:SetPoint("TOPLEFT", 6, -5)
	if b.icon.AddMaskTexture and b.CreateMaskTexture then
		local mask = b:CreateMaskTexture()
		mask:SetAllPoints(b.icon)
		mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		b.icon:AddMaskTexture(mask)
	end
	local border = b:CreateTexture(nil, "OVERLAY", nil, 1)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(54, 54)
	border:SetPoint("TOPLEFT")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

------------------------------------------------------------------------
-- The map panel
------------------------------------------------------------------------

-- The progress of the map that the world map shows. Nil for a map with no data.
local function MapProgress(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	if not info then return nil end
	local types = Enum.UIMapType
	if info.mapType == types.Zone then
		local done, total = ns.ZoneProgress(mapID)
		if done then
			return info.name, done, total, "areas"
		end
	elseif info.mapType == types.Continent then
		for _, c in ipairs((ns.Collect())) do
			if c.mapID == mapID then
				return c.name, c.done, c.total, ("%d of %d zones complete"):format(c.zonesDone, c.zoneCount)
			end
		end
	elseif info.mapType == types.World then
		local _, world = ns.Collect()
		if world.total > 0 then
			return world.name, world.done, world.total, ("%d of %d zones complete"):format(world.zonesDone, world.zoneCount)
		end
	end
	return nil
end

local function RefreshPanel()
	if not panel then return end
	if not ns.db.mapPanel or not WorldMapFrame:IsShown() then
		panel:Hide()
		return
	end
	local name, done, total, note = MapProgress(WorldMapFrame:GetMapID())
	if not name then
		panel:Hide()
		return
	end
	ns.FillPlate(panel, name, done, total)
	panel.note:SetText(note == "areas" and "" or note)
	panel:Show()
end

local function SafeRefreshPanel()
	local ok, err = pcall(RefreshPanel)
	if not ok then
		if panel then panel:Hide() end
		if ns.db.debug then ns.Print("panel error: " .. tostring(err)) end
	end
end

ns.RefreshPanel = SafeRefreshPanel

local function UpdateMapButton()
	if not mapButton then return end
	local on = ns.db.enabled and true or false
	mapButton.icon:SetDesaturated(not on)
	mapButton:SetAlpha(on and 1 or 0.6)
end
ns.UpdateMapButton = UpdateMapButton

-- The positions of the box on the map. The default is the bottom centre:
-- the top centre has the zone name of the game, and the corners have the
-- buttons and panels of the game and of other addons.
local POSITIONS = {
	bottom = { "BOTTOM", 0, 10 }, top = { "TOP", 0, -8 },
	topleft = { "TOPLEFT", 8, -8 }, topright = { "TOPRIGHT", -8, -8 },
	bottomleft = { "BOTTOMLEFT", 8, 10 }, bottomright = { "BOTTOMRIGHT", -8, 10 },
}

-- The coordinates line is in the bottom left corner of the map. If the box
-- is there, the line goes to the bottom right corner.
local function PlaceCoords()
	if not coords then return end
	local right = (ns.db.panelAt == "bottomleft")
	coords:ClearAllPoints()
	coords:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", coords.host, right and "BOTTOMRIGHT" or "BOTTOMLEFT",
		right and -8 or 8, 10)
	coords.text:ClearAllPoints()
	coords.text:SetPoint(right and "RIGHT" or "LEFT", coords, right and "RIGHT" or "LEFT", right and -6 or 6, 0)
end

function ns.PlacePanel(where)
	if where == "on" or where == "off" then
		ns.db.mapPanel = (where == "on")
		ns.Print("the box on the map is " .. where .. ".")
		if ns.RefreshPanel then ns.RefreshPanel() end
		return
	end
	if where then
		if not POSITIONS[where] then
			ns.Print("use: on, off, bottom, top, topleft, topright, bottomleft, bottomright.")
			return
		end
		ns.db.panelAt = where
		ns.Print("the box on the map is now at: " .. where .. ".")
	end
	PlaceCoords()
	if not panel then return end
	local at = POSITIONS[ns.db.panelAt or "bottom"] or POSITIONS.bottom
	panel:ClearAllPoints()
	panel:SetPoint(at[1], panel.host, at[1], at[2], at[3])
	-- The note line goes on the side of the box that is toward the map centre.
	panel.note:ClearAllPoints()
	if at[1]:find("BOTTOM") then
		panel.note:SetPoint("BOTTOM", panel, "TOP", 0, 2)
	else
		panel.note:SetPoint("TOP", panel, "BOTTOM", 0, -2)
	end
end

------------------------------------------------------------------------
-- The coordinates on the map
------------------------------------------------------------------------

local function Pair(x, y)
	return ("%.1f, %.1f"):format(x * 100, y * 100)
end

-- Your position on the map that the world map shows. Nil if you are not on
-- that map, or if the game gives no position (for example in a dungeon).
local function PlayerXY(mapID)
	if not mapID or not C_Map.GetPlayerMapPosition then return nil end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	if not x or not y or (x == 0 and y == 0) or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	return x, y
end

-- The position of the cursor on the map. Nil if the cursor is not on the map.
local function CursorXY()
	local canvas = WorldMapFrame.ScrollContainer
	if not canvas or not canvas.GetNormalizedCursorPosition or not canvas:IsMouseOver() then return nil end
	local x, y = canvas:GetNormalizedCursorPosition()
	if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	return x, y
end

local function CoordsText()
	local px, py = PlayerXY(WorldMapFrame:GetMapID())
	local cx, cy = CursorXY()
	local text = "You: " .. (px and Pair(px, py) or "--")
	if cx then text = text .. "    Cursor: " .. Pair(cx, cy) end
	return text
end

local function RefreshCoords()
	if not coords then return end
	if ns.db.coords == false then
		coords:Hide()
		return
	end
	coords:Show()
	local ok, text = pcall(CoordsText)
	if not ok then
		if ns.db.debug and not coords.failed then ns.Print("coordinates error: " .. tostring(text)) end
		coords.failed = true
		text = ""
	end
	if text ~= coords.last then
		coords.last = text
		coords.text:SetText(text)
		coords:SetWidth(math.max(40, coords.text:GetStringWidth() + 12))
		coords.bg:SetShown(text ~= "")
	end
end

function ns.SetCoords(arg)
	if arg == "on" or arg == "off" then
		ns.db.coords = (arg == "on")
	else
		ns.db.coords = (ns.db.coords == false)
	end
	ns.Print(ns.db.coords and "the coordinates show on the map." or "the coordinates are hidden.")
	RefreshCoords()
end

local function BuildCoords(host)
	coords = CreateFrame("Frame", "ForeverMapExplorerCoords", WorldMapFrame)
	coords:SetFrameStrata("HIGH")
	coords:SetSize(40, 18)
	coords:EnableMouse(false)
	coords.host = host
	coords.bg = coords:CreateTexture(nil, "BACKGROUND")
	coords.bg:SetAllPoints()
	coords.bg:SetColorTexture(0, 0, 0, 0.55)
	coords.text = coords:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	PlaceCoords()
	-- The frame is a child of the world map, thus the update runs only
	-- while the map shows. Ten updates each second are sufficient.
	-- The timer is a different frame, because the line can be hidden.
	local timer = CreateFrame("Frame", nil, WorldMapFrame)
	local wait = 0
	timer:SetScript("OnUpdate", function(_, elapsed)
		wait = wait + elapsed
		if wait < 0.1 then return end
		wait = 0
		RefreshCoords()
	end)
	RefreshCoords()
end

local function BuildMapParts()
	if mapButton or not WorldMapFrame then return end
	local host = (WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer()) or WorldMapFrame

	-- The button: in the top right corner, one button height below the fishing button.
	mapButton = RoundButton(WorldMapFrame, "ForeverMapExplorerMapButton")
	mapButton:SetFrameStrata("HIGH")
	mapButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -2 - 32)
	mapButton:SetScript("OnClick", function(self, button)
		if button ~= "RightButton" then
			ns.ToggleProgress()
			return
		end
		ns.db.enabled = not ns.db.enabled
		ns.RefreshFog()
		UpdateMapButton()
		if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
	end)
	mapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Map Explorer", 1, 1, 1)
		GameTooltip:AddLine("Left-click: open or close the progress window.", 0.8, 0.8, 0.8)
		GameTooltip:AddLine(ns.db.enabled and "Right-click: hide the fog on the map."
			or "Right-click: show the fog on the map.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)

	-- The panel: one plate on the map.
	panel = ns.NewPlate(WorldMapFrame)
	panel:SetFrameStrata("HIGH")
	panel:SetWidth(PANEL_WIDTH)
	panel:EnableMouse(false)
	panel.note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	panel.host = host
	ns.PlacePanel()
	panel:Hide()

	pcall(BuildCoords, host)

	WorldMapFrame:HookScript("OnShow", SafeRefreshPanel)
	hooksecurefunc(WorldMapFrame, "OnMapChanged", SafeRefreshPanel)
	UpdateMapButton()
end

------------------------------------------------------------------------
-- The minimap button
------------------------------------------------------------------------

local function PlaceMinimapButton()
	local angle = math.rad(ns.db.minimapAngle or 200)
	local radius = (Minimap:GetWidth() / 2) + 8
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function BuildMinimapButton()
	if minimapButton or not Minimap then return end
	minimapButton = RoundButton(Minimap, "ForeverMapExplorerMinimapButton")
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetFrameLevel(8)
	minimapButton:RegisterForDrag("LeftButton")
	-- Drag the button to move it around the minimap.
	minimapButton:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			PlaceMinimapButton()
		end)
	end)
	minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	minimapButton:RegisterForClicks("LeftButtonUp")
	minimapButton:SetScript("OnClick", function()
		ns.ToggleProgress()
	end)
	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Map Explorer", 1, 1, 1)
		GameTooltip:AddLine("Left-click: open or close the progress window.", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Drag: move this button.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	PlaceMinimapButton()
	minimapButton:SetShown(ns.db.minimap ~= false)
end

function ns.ToggleMinimapButton()
	ns.db.minimap = ns.db.minimap == false
	if minimapButton then minimapButton:SetShown(ns.db.minimap) end
	ns.Print(ns.db.minimap and "the minimap button shows." or "the minimap button is hidden. Type /fme minimap to show it.")
end

-- Fog.lua calls this at login, after the settings are ready.
function ns.OnLogin()
	-- Before version 0.3.1 the map button could hide the box. No button does
	-- that now, so show the box again one time. "/fme box off" hides it.
	if not ns.db.boxReset then
		ns.db.mapPanel = true
		ns.db.boxReset = true
	end
	pcall(BuildMinimapButton)
	pcall(BuildMapParts)
	-- The first look sets the base. A later discovery can then give a zone its date.
	pcall(function() ns.NoteCompletions((ns.Collect()), false) end)
	local events = CreateFrame("Frame")
	events:RegisterEvent("MAP_EXPLORATION_UPDATED")
	events:SetScript("OnEvent", function()
		pcall(function() ns.NoteCompletions((ns.Collect()), true) end)
		SafeRefreshPanel()
	end)
end
