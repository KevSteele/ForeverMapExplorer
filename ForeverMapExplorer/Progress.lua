--[[
WoW Forever Map Explorer - the discovery progress window.
GPL-3.0-or-later.

It shows how many areas you discovered: for Azeroth, for each continent, and for each zone.
The layout follows the Legacy Challenges view of the game.
The numbers come from the game, for the character that you play now. Nothing is saved.
]]

local _, ns = ...

local WORLD_MAP = 947                      -- Azeroth
local FALLBACK_CONTINENTS = { 1414, 1415 } -- Kalimdor, Eastern Kingdoms
local ROW_HEIGHT, WIDTH, INDENT = 46, 380, 18

local PARCHMENT = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal"
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"

local window, content

-- The number of discovered areas and the number of all areas of a zone.
-- The third result is the list of the areas that are not discovered.
-- The fourth result is the list of all areas, each with a flag.
function ns.ZoneProgress(mapID)
	local artID = C_Map.GetMapArtID(mapID)
	local areas = artID and VeilmapFogData and VeilmapFogData[artID]
	if not areas or #areas == 0 then
		return nil
	end
	local seen = {}
	local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID)
	if explored then
		for _, info in ipairs(explored) do
			seen[info.offsetX .. ":" .. info.offsetY .. ":" .. info.textureWidth .. ":" .. info.textureHeight] = true
		end
	end
	local done, missing, all = 0, {}, {}
	for _, entry in ipairs(areas) do
		local found = seen[entry[3] .. ":" .. entry[4] .. ":" .. entry[1] .. ":" .. entry[2]] or false
		if found then
			done = done + 1
		else
			missing[#missing + 1] = entry
		end
		all[#all + 1] = { entry = entry, done = found }
	end
	return done, #areas, missing, all
end

-- All continents with their zones and the progress, and the totals for Azeroth.
function ns.Collect()
	local continents = {}
	local list = C_Map.GetMapChildrenInfo(WORLD_MAP, Enum.UIMapType.Continent, true)
	if not list or #list == 0 then
		list = {}
		for _, mapID in ipairs(FALLBACK_CONTINENTS) do
			local info = C_Map.GetMapInfo(mapID)
			if info then list[#list + 1] = info end
		end
	end
	local used = {}
	local world = { name = "Azeroth", done = 0, total = 0, zonesDone = 0, zoneCount = 0 }
	for _, continent in ipairs(list) do
		local c = { name = continent.name, mapID = continent.mapID, done = 0, total = 0, zonesDone = 0, zones = {} }
		for _, zone in ipairs(C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone, true) or {}) do
			if not used[zone.mapID] then
				local done, total, missing, all = ns.ZoneProgress(zone.mapID)
				if done then
					used[zone.mapID] = true
					c.zones[#c.zones + 1] = { name = zone.name, mapID = zone.mapID, done = done, total = total, missing = missing, all = all }
					c.done, c.total = c.done + done, c.total + total
					if done == total then c.zonesDone = c.zonesDone + 1 end
				end
			end
		end
		table.sort(c.zones, function(a, b) return a.name < b.name end)
		c.zoneCount = #c.zones
		if c.zoneCount > 0 then
			continents[#continents + 1] = c
			world.done, world.total = world.done + c.done, world.total + c.total
			world.zonesDone, world.zoneCount = world.zonesDone + c.zonesDone, world.zoneCount + c.zoneCount
		end
	end
	table.sort(continents, function(a, b) return a.name < b.name end)
	return continents, world
end

-- The dates of completion, for each character. The game does not give this date,
-- so the addon keeps it from the moment that it sees a zone become complete.
local function Dates()
	local db = ns.db
	if not db then return nil end
	local name = UnitName and UnitName("player") or "?"
	local realm = GetRealmName and GetRealmName() or "?"
	if type(name) ~= "string" or type(realm) ~= "string" then return nil end
	db.dates = db.dates or {}
	local key = name .. "-" .. realm
	db.dates[key] = db.dates[key] or {}
	return db.dates[key]
end

function ns.CompletionDate(mapID)
	local dates = Dates()
	local value = dates and dates[mapID]
	return type(value) == "string" and value or ""
end

-- Call this after a discovery. A zone that is complete now, and was not
-- complete at the last look, gets the date of today.
local known -- map ID -> true if complete at the last look
function ns.NoteCompletions(continents, isDiscovery)
	local dates = Dates()
	if not dates then return end
	local first = not known
	known = known or {}
	for _, c in ipairs(continents) do
		for _, zone in ipairs(c.zones) do
			local complete = zone.total > 0 and zone.done == zone.total
			if complete and not known[zone.mapID] and not first and isDiscovery and not dates[zone.mapID] then
				dates[zone.mapID] = date("%m/%d/%y")
			end
			known[zone.mapID] = complete or nil
		end
	end
end

function ns.Percent(done, total)
	return total > 0 and math.floor(done / total * 100) or 0
end

function ns.NewFrame(kind, parent, name)
	local ok, frame = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
	if not ok or not frame then
		frame = CreateFrame(kind, name, parent)
	end
	return frame
end

function ns.Backdrop(frame, edge, size)
	if frame.SetBackdrop then
		frame:SetBackdrop({ edgeFile = edge, edgeSize = size })
	end
end

function ns.NewBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(BAR)
	bar:SetStatusBarColor(0, 0.6, 0.1)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(bar)
	bg:SetColorTexture(0, 0, 0, 0.55)
	bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.text:SetPoint("CENTER")
	return bar
end

function ns.SetBar(bar, done, total)
	bar:SetMinMaxValues(0, math.max(total, 1))
	bar:SetValue(done)
	bar.text:SetText(done .. " / " .. total)
end

-- A plate in the style of an achievement: a border, a parchment, a name, a percent, and a bar.
-- The same plate is used for a continent and for a zone.
function ns.NewPlate(parent)
	local row = ns.NewFrame("Button", parent)
	row:SetHeight(56)
	ns.Backdrop(row, "Interface\\Tooltips\\UI-Tooltip-Border", 12)

	local base = row:CreateTexture(nil, "BACKGROUND", nil, -1)
	base:SetPoint("TOPLEFT", 3, -3)
	base:SetPoint("BOTTOMRIGHT", -3, 3)
	base:SetColorTexture(0.16, 0.10, 0.05, 1) -- shows if the parchment file is absent
	row.plate = row:CreateTexture(nil, "BACKGROUND", nil, 0)
	row.plate:SetAllPoints(base)
	row.plate:SetTexture(PARCHMENT)
	row.plate:SetTexCoord(0, 1, 0, 0.5)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("TOPLEFT", 16, -11)
	row.percent = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.percent:SetPoint("TOPRIGHT", -16, -12)
	row.check = row:CreateTexture(nil, "OVERLAY")
	row.check:SetSize(16, 16)
	row.check:SetPoint("RIGHT", row.percent, "LEFT", -4, 0)
	row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

	row.bar = ns.NewBar(row)
	row.bar:SetPoint("BOTTOMLEFT", 17, 13)
	row.bar:SetPoint("BOTTOMRIGHT", -17, 13)
	row.bar:SetHeight(12)
	local edge = ns.NewFrame("Frame", row.bar)
	edge:SetPoint("TOPLEFT", -3, 3)
	edge:SetPoint("BOTTOMRIGHT", 3, -3)
	ns.Backdrop(edge, "Interface\\Tooltips\\UI-Tooltip-Border", 8)
	if edge.SetBackdropBorderColor then edge:SetBackdropBorderColor(0.6, 0.5, 0.35) end
	return row
end

-- Fill a plate. `bright` is true for a continent and for a complete zone.
function ns.FillPlate(row, name, done, total, bright, gold)
	local complete = total > 0 and done == total
	row.name:SetText(name)
	row.percent:SetText(ns.Percent(done, total) .. "%")
	row.check:SetShown(complete)
	ns.SetBar(row.bar, done, total)
	-- The look of a plate of the Legacy Challenges view: the bright parchment
	-- if complete, a dark brown plate if not, and a copper border.
	if complete then row.plate:SetVertexColor(1, 1, 1) else row.plate:SetVertexColor(0.17, 0.13, 0.10) end
	row.name:SetTextColor(1, 1, 1)
	row.percent:SetTextColor(1, 0.82, 0)
	row.bar:SetStatusBarColor(0, 0.6, 0.1)
	if row.SetBackdropBorderColor then row:SetBackdropBorderColor(0.85, 0.55, 0.30) end
end

function ns.OpenMap(mapID)
	if not mapID or InCombatLockdown() then return end
	pcall(function()
		if not WorldMapFrame:IsShown() then ToggleWorldMap() end
		WorldMapFrame:SetMapID(mapID)
	end)
end

------------------------------------------------------------------------
-- The window, in the layout of the Legacy Challenges view of the game:
-- a progress bar at the top, a list of categories on the left (Azeroth and
-- the continents), and plates on the right. A zone plate opens to show its
-- areas in two columns, with a check mark for each area that you discovered.
------------------------------------------------------------------------

local ART = "Interface\\AchievementFrame\\"
local LEFT_WIDTH, PLATE_WIDTH, PLATE_HEIGHT, PILL_HEIGHT = 190, 470, 86, 26
local COPPER = { 0.85, 0.55, 0.30 }
local GREY = { 0.45, 0.38, 0.30 }
local YELLOW = { 1.0, 0.82, 0.0 }

local selected = "world" -- "world" or the map ID of a continent
local expanded = {}      -- zone map ID -> true if the areas show
local categories, plates = {}, {}
local Refresh

local function AreaName(entry)
	local id = entry[5] and entry[5][1]
	return (id and C_Map.GetAreaInfo(id)) or "?"
end

local function NewCategory(parent)
	-- The container is drawn here, not with the art of the game. Thus the text
	-- and the container always have the same position.
	local b = ns.NewFrame("Button", parent)
	b:SetSize(LEFT_WIDTH, 24)
	ns.Backdrop(b, "Interface\\Tooltips\\UI-Tooltip-Border", 10)
	b.fill = b:CreateTexture(nil, "BACKGROUND")
	b.fill:SetPoint("TOPLEFT", 2, -2)
	b.fill:SetPoint("BOTTOMRIGHT", -2, 2)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(b.fill)
	hl:SetColorTexture(1, 0.82, 0, 0.12)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
	b.text:SetPoint("RIGHT", b, "RIGHT", -44, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetJustifyV("MIDDLE")
	b.text:SetWordWrap(false)
	b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.count:SetPoint("RIGHT", b, "RIGHT", -10, 0)
	b.count:SetJustifyV("MIDDLE")
	b:SetScript("OnClick", function(self)
		selected = self.key
		Refresh()
	end)
	return b
end

-- One area of a zone: a dark pill with the name and, if discovered, a check mark.
local function NewPill(plate)
	local pill = ns.NewFrame("Frame", plate)
	pill:SetHeight(PILL_HEIGHT - 4)
	ns.Backdrop(pill, "Interface\\Tooltips\\UI-Tooltip-Border", 8)
	pill.bg = pill:CreateTexture(nil, "BACKGROUND")
	pill.bg:SetPoint("TOPLEFT", 2, -2)
	pill.bg:SetPoint("BOTTOMRIGHT", -2, 2)
	pill.name = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pill.name:SetPoint("LEFT", 8, 0)
	pill.name:SetPoint("RIGHT", -24, 0)
	pill.name:SetJustifyH("LEFT")
	pill.name:SetWordWrap(false)
	pill.check = pill:CreateTexture(nil, "OVERLAY")
	pill.check:SetSize(14, 14)
	pill.check:SetPoint("RIGHT", -6, 0)
	pill.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
	return pill
end

local function PlateOnClick(self, button)
	local item = self.item
	if not item then return end
	if item.zones then
		-- A continent: show its zones.
		selected = item.mapID
	elseif button == "RightButton" then
		ns.OpenMap(item.mapID)
		return
	else
		expanded[item.mapID] = not expanded[item.mapID] or nil
	end
	Refresh()
end

local function NewBigPlate()
	local p = ns.NewFrame("Button", content)
	p:SetWidth(PLATE_WIDTH)
	ns.Backdrop(p, "Interface\\Tooltips\\UI-Tooltip-Border", 16)
	p:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local base = p:CreateTexture(nil, "BACKGROUND", nil, -1)
	base:SetPoint("TOPLEFT", 4, -4)
	base:SetPoint("BOTTOMRIGHT", -4, 4)
	base:SetColorTexture(0.16, 0.10, 0.05, 1) -- shows if the parchment file is absent
	p.paper = p:CreateTexture(nil, "BACKGROUND", nil, 0)
	p.paper:SetAllPoints(base)

	p.iconFrame = p:CreateTexture(nil, "ARTWORK", nil, 1)
	p.iconFrame:SetTexture(ART .. "UI-Achievement-IconFrame")
	p.iconFrame:SetTexCoord(0, 0.5625, 0, 0.5625)
	p.iconFrame:SetSize(60, 60)
	p.iconFrame:SetPoint("TOPLEFT", 10, -10)
	p.icon = p:CreateTexture(nil, "ARTWORK", nil, 0)
	p.icon:SetTexture("Interface\\Icons\\INV_Misc_Map02")
	p.icon:SetSize(42, 42)
	p.icon:SetPoint("CENTER", p.iconFrame, "CENTER", 0, 1)

	p.title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	p.title:SetPoint("TOPLEFT", 80, -14)
	-- The plus or minus sign: a red box with a gold sign. The sign is drawn from
	-- two bars, so it is exactly in the centre of the box.
	p.sign = ns.NewFrame("Frame", p)
	p.sign:SetSize(16, 16)
	p.sign:SetPoint("TOPLEFT", 80, -38)
	ns.Backdrop(p.sign, "Interface\\Tooltips\\UI-Tooltip-Border", 8)
	if p.sign.SetBackdropBorderColor then p.sign:SetBackdropBorderColor(0.9, 0.7, 0.4) end
	local red = p.sign:CreateTexture(nil, "BACKGROUND")
	red:SetPoint("TOPLEFT", 2, -2)
	red:SetPoint("BOTTOMRIGHT", -2, 2)
	red:SetColorTexture(0.6, 0.05, 0.05, 1)
	local across = p.sign:CreateTexture(nil, "OVERLAY")
	across:SetSize(8, 2)
	across:SetPoint("CENTER")
	across:SetColorTexture(1, 0.82, 0, 1)
	p.sign.down = p.sign:CreateTexture(nil, "OVERLAY")
	p.sign.down:SetSize(2, 8)
	p.sign.down:SetPoint("CENTER")
	p.sign.down:SetColorTexture(1, 0.82, 0, 1)
	-- The game moves each texture to the nearest screen pixel. With bars this
	-- thin, that made each sign look different. Without the snap, all signs
	-- have the same proportions.
	for _, bar in ipairs({ across, p.sign.down, red }) do
		if bar.SetSnapToPixelGrid then bar:SetSnapToPixelGrid(false) end
		if bar.SetTexelSnappingBias then bar:SetTexelSnappingBias(0) end
	end
	p.desc = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.desc:SetPoint("TOPLEFT", 102, -40)
	p.corner = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	p.corner:SetPoint("TOPRIGHT", -28, -10)
	p.check = p:CreateTexture(nil, "OVERLAY")
	p.check:SetSize(16, 16)
	p.check:SetPoint("TOPRIGHT", -8, -7)
	p.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

	p.bar = ns.NewBar(p)
	p.bar:SetPoint("TOPLEFT", 80, -60)
	p.bar:SetSize(300, 12)
	-- A thin border around the bar.
	local edge = ns.NewFrame("Frame", p.bar)
	edge:SetPoint("TOPLEFT", -3, 3)
	edge:SetPoint("BOTTOMRIGHT", 3, -3)
	ns.Backdrop(edge, "Interface\\Tooltips\\UI-Tooltip-Border", 8)
	if edge.SetBackdropBorderColor then edge:SetBackdropBorderColor(0.6, 0.5, 0.35) end

	p.map = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	p.map:SetSize(54, 20)
	p.map:SetPoint("TOPRIGHT", -12, -54)
	p.map:SetText("Map")
	p.map:SetScript("OnClick", function(self)
		local item = self:GetParent().item
		if item then ns.OpenMap(item.mapID) end
	end)

	p.pills = {}
	p:SetScript("OnClick", PlateOnClick)
	return p
end

local function FillBigPlate(p, item)
	local isZone = not item.zones
	local complete = item.total > 0 and item.done == item.total
	local isOpen = isZone and expanded[item.mapID]
	p.item = item
	p.title:SetText((isZone and "Explore " or "") .. item.name)
	-- A complete zone: the bright parchment. An incomplete zone: the same
	-- parchment made dark brown, as the game view shows it.
	p.paper:SetTexture(ART .. "UI-Achievement-Parchment-Horizontal")
	p.paper:SetTexCoord(0, 1, 0, 0.5)
	if complete then p.paper:SetVertexColor(1, 1, 1) else p.paper:SetVertexColor(0.17, 0.13, 0.10) end
	p.icon:SetDesaturated(not complete)
	p.check:SetShown(complete)
	-- The corner, as the game view: nothing for an incomplete zone, and the
	-- date with a check mark for a complete zone. The date is known only if
	-- the addon saw the moment of completion.
	p.corner:SetText(complete and isZone and ns.CompletionDate(item.mapID) or "")
	ns.SetBar(p.bar, item.done, item.total)
	if isZone then
		p.sign.down:SetShown(not isOpen) -- a minus sign has no bar that goes down
		p.sign:Show()
		p.desc:SetText(("%d of %d areas discovered"):format(item.done, item.total))
		p.bar:SetStatusBarColor(0, 0.6, 0.1)
	else
		p.sign:Hide()
		p.desc:SetText(("%d of %d zones complete. Click to show the zones."):format(item.zonesDone, item.zoneCount))
		p.bar:SetStatusBarColor(0.9, 0.7, 0.1)
	end
	if complete then p.title:SetTextColor(1, 1, 1) else p.title:SetTextColor(0.8, 0.8, 0.8) end
	if p.SetBackdropBorderColor then
		local c = isOpen and YELLOW or COPPER
		p:SetBackdropBorderColor(c[1], c[2], c[3])
	end

	-- The areas, in two columns: the first half on the left, the second half on the right.
	for _, pill in ipairs(p.pills) do pill:Hide() end
	local height = PLATE_HEIGHT
	if isOpen then
		local n = #item.all
		local perColumn = math.ceil(n / 2)
		local pillWidth = (PLATE_WIDTH - 44) / 2
		for i, area in ipairs(item.all) do
			local pill = p.pills[i]
			if not pill then pill = NewPill(p); p.pills[i] = pill end
			-- Row by row, as the game view: left, right, then the next line.
			local column = (i - 1) % 2
			local line = math.floor((i - 1) / 2) + 1
			pill:ClearAllPoints()
			pill:SetWidth(pillWidth)
			pill:SetPoint("TOPLEFT", p, "TOPLEFT", 16 + column * (pillWidth + 12), -(PLATE_HEIGHT - 2) - (line - 1) * PILL_HEIGHT)
			pill.name:SetText(AreaName(area.entry))
			pill.check:SetShown(area.done)
			if area.done then pill.name:SetTextColor(1, 1, 1) else pill.name:SetTextColor(0.55, 0.5, 0.45) end
			-- Brown pills on the bright parchment, dark pills on the dark plate.
			if complete then
				pill.bg:SetColorTexture(0.36, 0.21, 0.11, 0.9)
				if pill.SetBackdropBorderColor then pill:SetBackdropBorderColor(0.55, 0.38, 0.22) end
			else
				pill.bg:SetColorTexture(0.09, 0.06, 0.04, 0.9)
				if pill.SetBackdropBorderColor then pill:SetBackdropBorderColor(0.35, 0.27, 0.18) end
			end
			pill:Show()
		end
		height = PLATE_HEIGHT + perColumn * PILL_HEIGHT + 10
	end
	p:SetHeight(height)
	return height
end

Refresh = function()
	local continents, world = ns.Collect()
	ns.SetBar(window.bar, world.done, world.total)
	window.bar.text:SetText(("Areas discovered %d / %d"):format(world.done, world.total))
	window.shield:SetText(world.zonesDone)

	-- The left side: Azeroth, then the continents.
	local list = { { key = "world", name = "Azeroth", done = world.done, total = world.total } }
	local current
	for _, c in ipairs(continents) do
		list[#list + 1] = { key = c.mapID, name = c.name, done = c.done, total = c.total, indent = true }
		if c.mapID == selected then current = c end
	end
	if not current then selected = "world" end
	for _, b in ipairs(categories) do b:Hide() end
	for i, entry in ipairs(list) do
		local b = categories[i]
		if not b then b = NewCategory(window.left); categories[i] = b end
		b.key = entry.key
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", window.left, "TOPLEFT", entry.indent and 10 or 0, -(i - 1) * 27)
		b:SetWidth(LEFT_WIDTH - (entry.indent and 10 or 0))
		b.text:SetText(entry.name)
		b.count:SetText(ns.Percent(entry.done, entry.total) .. "%")
		local isSelected = entry.key == selected
		b.selected = isSelected
		if isSelected then
			-- Gold, as the selected category of the game view.
			b.fill:SetColorTexture(0.50, 0.38, 0.04, 1)
			b.text:SetTextColor(1, 1, 1)
			if b.SetBackdropBorderColor then b:SetBackdropBorderColor(1, 0.82, 0) end
		else
			b.fill:SetColorTexture(0.13, 0.08, 0.04, 1)
			b.text:SetTextColor(1, 0.82, 0)
			if b.SetBackdropBorderColor then b:SetBackdropBorderColor(0.45, 0.33, 0.15) end
		end
		b:Show()
	end

	-- The right side: the continents for Azeroth, or the zones of one continent.
	local items = current and current.zones or continents
	for _, p in ipairs(plates) do p:Hide() end
	local y = 0
	for i, item in ipairs(items) do
		local p = plates[i]
		if not p then p = NewBigPlate(); plates[i] = p end
		p:ClearAllPoints()
		p:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		y = y + FillBigPlate(p, item) + 6
		p:Show()
	end
	content:SetHeight(math.max(y, 1))
end

local function SafeRefresh()
	if window and window:IsShown() then
		local ok, err = pcall(Refresh)
		if not ok and ns.db and ns.db.debug then
			ns.Print("progress error: " .. tostring(err))
		end
	end
end

local function Build()
	window = ns.NewFrame("Frame", UIParent, "ForeverMapExplorerFrame")
	window:SetSize(LEFT_WIDTH + PLATE_WIDTH + 90, 548)
	window:SetPoint("CENTER")
	window:SetFrameStrata("HIGH")
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	ns.Backdrop(window, "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", 28)
	local bg = window:CreateTexture(nil, "BACKGROUND", nil, -2)
	bg:SetPoint("TOPLEFT", 8, -8)
	bg:SetPoint("BOTTOMRIGHT", -8, 8)
	bg:SetColorTexture(0.09, 0.06, 0.04, 1)

	local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Map Explorer")

	-- The bar at the top, with the number of complete zones in front of it.
	window.bar = ns.NewBar(window)
	window.bar:SetPoint("TOP", 20, -38)
	window.bar:SetSize(520, 16)
	local edge = ns.NewFrame("Frame", window.bar)
	edge:SetPoint("TOPLEFT", -4, 4)
	edge:SetPoint("BOTTOMRIGHT", 4, -4)
	ns.Backdrop(edge, "Interface\\Tooltips\\UI-Tooltip-Border", 10)
	if edge.SetBackdropBorderColor then edge:SetBackdropBorderColor(0.7, 0.6, 0.4) end
	-- The shield of the game, with the number of complete zones on it.
	local shield = window:CreateTexture(nil, "ARTWORK")
	shield:SetTexture(ART .. "UI-Achievement-Shields")
	shield:SetTexCoord(0, 0.5, 0, 0.5)
	shield:SetSize(44, 44)
	shield:SetPoint("RIGHT", window.bar, "LEFT", -4, -2)
	window.shield = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.shield:SetPoint("CENTER", shield, "CENTER", 0, 3)
	local shieldTip = CreateFrame("Frame", nil, window)
	shieldTip:SetAllPoints(shield)
	shieldTip:EnableMouse(true)
	shieldTip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Complete zones")
		GameTooltip:AddLine("The number of zones where you discovered all areas.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	shieldTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- A dark strip behind the title and the bar, as the header of the game view.
	local header = window:CreateTexture(nil, "BACKGROUND", nil, -1)
	header:SetPoint("TOPLEFT", 8, -8)
	header:SetPoint("TOPRIGHT", -8, -8)
	header:SetHeight(56)
	header:SetColorTexture(0.04, 0.025, 0.015, 1)

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	-- Two sunk panels with a border: the categories on the left, the plates on the right.
	local function Inset(left, right)
		local inset = ns.NewFrame("Frame", window)
		inset:SetPoint("TOPLEFT", left, -68)
		inset:SetPoint("BOTTOMRIGHT", window, right and "BOTTOMRIGHT" or "BOTTOMLEFT", right or (LEFT_WIDTH + 30), 12)
		ns.Backdrop(inset, "Interface\\Tooltips\\UI-Tooltip-Border", 14)
		if inset.SetBackdropBorderColor then inset:SetBackdropBorderColor(0.6, 0.45, 0.25) end
		local fill = inset:CreateTexture(nil, "BACKGROUND")
		fill:SetPoint("TOPLEFT", 3, -3)
		fill:SetPoint("BOTTOMRIGHT", -3, 3)
		fill:SetColorTexture(0.05, 0.03, 0.02, 1)
		return inset
	end
	Inset(12)
	local rightInset = Inset(LEFT_WIDTH + 32, -12)

	window.left = CreateFrame("Frame", nil, window)
	window.left:SetPoint("TOPLEFT", 21, -78)
	window.left:SetSize(LEFT_WIDTH, 440)

	-- The thin scroll bar of the new game interface, if this client has it.
	-- If not, the old wide scroll bar with a dark track.
	local thin, scroll = pcall(CreateFrame, "ScrollFrame", "ForeverMapExplorerScroll", window, "ScrollFrameTemplate")
	if not thin or not scroll then
		thin = false
		scroll = CreateFrame("ScrollFrame", "ForeverMapExplorerScroll", window, "UIPanelScrollFrameTemplate")
	end
	scroll:SetPoint("TOPLEFT", LEFT_WIDTH + 40, -76)
	scroll:SetPoint("BOTTOMRIGHT", thin and -36 or -42, 20)
	-- The lists must be above the panels.
	window.left:SetFrameLevel(rightInset:GetFrameLevel() + 1)
	scroll:SetFrameLevel(rightInset:GetFrameLevel() + 1)
	-- A dark track behind the scroll bar.
	local track = rightInset:CreateTexture(nil, "BORDER")
	track:SetPoint("TOPRIGHT", -5, -5)
	track:SetPoint("BOTTOMRIGHT", -5, 5)
	track:SetWidth(22)
	track:SetColorTexture(0, 0, 0, 0.6)
	track:SetShown(not thin)
	-- The mouse wheel moves the list by one plate.
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local limit = self:GetVerticalScrollRange() or 0
		local to = (self:GetVerticalScroll() or 0) - delta * (PLATE_HEIGHT + 6)
		self:SetVerticalScroll(math.max(0, math.min(limit, to)))
	end)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(PLATE_WIDTH, 1)
	scroll:SetScrollChild(content)

	window:SetScript("OnShow", SafeRefresh)
	window:Hide()
	if UISpecialFrames then
		UISpecialFrames[#UISpecialFrames + 1] = "ForeverMapExplorerFrame" -- the Escape key closes it
	end

	local events = CreateFrame("Frame")
	events:RegisterEvent("MAP_EXPLORATION_UPDATED")
	events:SetScript("OnEvent", SafeRefresh)
end

function ns.ToggleProgress()
	if not window then
		local ok, err = pcall(Build)
		if not ok then
			ns.Print("the progress window failed: " .. tostring(err))
			window = nil
			return
		end
	end
	if window:IsShown() then window:Hide() else window:Show() end
end

SLASH_MAPFOGPROGRESS1 = "/explore"
SlashCmdList.MAPFOGPROGRESS = ns.ToggleProgress
