--[[
WoW Forever Map Explorer - the minimap button, the world map button, and the map panel.
GPL-3.0-or-later.

- The minimap button opens and closes the progress window.
- The world map button shows and hides the map panel.
- The map panel shows the progress of the map that you look at:
  a zone, a continent, or Azeroth.
]]

local _, ns = ...

local ICON = "Interface\\Icons\\INV_Misc_Map02"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local PANEL_WIDTH = 260

local mapButton, panel, minimapButton

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

local function UpdateMapButton()
	if not mapButton then return end
	local on = ns.db.mapPanel and true or false
	mapButton.icon:SetDesaturated(not on)
	mapButton:SetAlpha(on and 1 or 0.6)
end

-- The positions of the box on the map. The default is the bottom centre:
-- the top centre has the zone name of the game, and the corners have the
-- buttons and panels of the game and of other addons.
local POSITIONS = {
	bottom = { "BOTTOM", 0, 10 }, top = { "TOP", 0, -8 },
	topleft = { "TOPLEFT", 8, -8 }, topright = { "TOPRIGHT", -8, -8 },
	bottomleft = { "BOTTOMLEFT", 8, 10 }, bottomright = { "BOTTOMRIGHT", -8, 10 },
}

function ns.PlacePanel(where)
	if where then
		if not POSITIONS[where] then
			ns.Print("positions: bottom, top, topleft, topright, bottomleft, bottomright.")
			return
		end
		ns.db.panelAt = where
		ns.Print("the box on the map is now at: " .. where .. ".")
	end
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

local function BuildMapParts()
	if mapButton or not WorldMapFrame then return end
	local host = (WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer()) or WorldMapFrame

	-- The button: in the top right corner, one button height below the fishing button.
	mapButton = RoundButton(WorldMapFrame, "ForeverMapExplorerMapButton")
	mapButton:SetFrameStrata("HIGH")
	mapButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -2 - 32)
	mapButton:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			ns.ToggleProgress()
			return
		end
		ns.db.mapPanel = not ns.db.mapPanel
		UpdateMapButton()
		SafeRefreshPanel()
		if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
	end)
	mapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Map Explorer", 1, 1, 1)
		GameTooltip:AddLine(ns.db.mapPanel and "The progress panel shows. Left-click to hide it."
			or "The progress panel is hidden. Left-click to show it.", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right-click: open the progress window.", 0.8, 0.8, 0.8)
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
	minimapButton:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			ns.db.enabled = not ns.db.enabled
			ns.Print(ns.db.enabled and "the fog on the map is on." or "the fog on the map is off.")
			ns.RefreshFog()
		else
			ns.ToggleProgress()
		end
	end)
	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Map Explorer", 1, 1, 1)
		GameTooltip:AddLine("Left-click: open or close the progress window.", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right-click: set the fog on the map to on or off.", 0.8, 0.8, 0.8)
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
