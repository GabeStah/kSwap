local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LQT = LibStub("LibQTip-1.0")
local dataobj = LDB:NewDataObject("kSwap", {
	type = "data source",
	text = "",
	icon = "Interface\\AddOns\\kSwap\\media\\gear-gold.tga",
})
local icon = LibStub("LibDBIcon-1.0")
local ceil = ceil
local floor = floor
local pairs = pairs
local ipairs = ipairs
local strlen = strlen
local table_sort = table.sort
local time = time
local path = "Interface\\AddOns\\kSwap\\media\\"

kSwap = LibStub("AceAddon-3.0"):NewAddon("kSwap", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
local self, kSwap = kSwap, kSwap
local tooltip
local defaults = {
	profile = {
		minimap = {
			hide = false,
		},
		swapEquipment = true
	},
	global = {},
}

local function GetOptions(uiType, uiName)
	local options = {
		type = "group",
		name = GetAddOnMetadata("kSwap", "Title"),
		args = {
			desc = {
				type = "description",
				order = 0,
				name = GetAddOnMetadata("kSwap", "Notes"),
			},
			minimap = {
				name = "Minimap Icon",
				desc = "Toggle minimap icon",
				type = "toggle",
				order = 10,
				get = function() return not self.db.profile.minimap.hide end,
				set = function()
					self.db.profile.minimap.hide = not self.db.profile.minimap.hide
					if self.db.profile.minimap.hide then
						icon:Hide("kSwap")
					else
						icon:Show("kSwap")
					end
				end,
			},
      swapEquipment = {
				name = "Swap Equiment Set",
				desc = "Determines if, in addition to swapping Specialization, Equipment Set should also be swapped.",
				type = "toggle",
				order = 10,
				get = function() return self.db.profile.swapEquipment end,
				set = function()
					self.db.profile.swapEquipment = not self.db.profile.swapEquipment
				end,
			},
		},
	}
	return options
end

local function Round(value, decimal)
  if (decimal) then
    return floor((value * 10^decimal) + 0.5) / (10^decimal)
  else
    return floor(value+0.5)
  end
end

-------------------------
-- custom libqtip cell
-------------------------
local myProvider, cellPrototype = LQT:CreateCellProvider()

function cellPrototype:InitializeCell()
	self.texture = self:CreateTexture()
	self.texture:SetAllPoints(self)
end

function cellPrototype:SetupCell(tooltip, value, justification, font, iconCoords, unitID,guild)
	local tex = self.texture
	tex:SetWidth(16)
	tex:SetHeight(16)
	
	if guild then
		_G.SetSmallGuildTabardTextures("player", tex,tex);
	elseif unitID then 
		_G.SetPortraitTexture(tex, unitID)
	else
		tex:SetTexture(value)
	end
	if iconCoords then
		tex:SetTexCoord(_G.unpack(iconCoords))
	end
	return tex:GetWidth(), tex:GetHeight() 
end

function cellPrototype:ReleaseCell()

end

function cellPrototype:getContentHeight()
	return 16
end

function kSwap:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("kSwapDB", defaults, true)
  self.EQUIPMENT_DATA = {}
  self.SPECIALIZATION_DATA = {}

	-- Minimap Icon
	icon:Register("kSwap", dataobj, self.db.profile.minimap)

	-- Options
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("kSwap", GetOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("kSwap", GetAddOnMetadata("kSwap", "Title"))
end

function kSwap:OnEnable()
	self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', 'UpdateData')
	self:RegisterEvent('PLAYER_ENTERING_WORLD', 'UpdateData')
end

function kSwap:ActivateSpecialization(spec)
  -- Cancel all timers.
  self:CancelAllTimers()
 	-- Exit if in combat.
	if InCombatLockdown() then
    print("kSwap: Must be out of combat to alter specialization or equipment.")
		return
	end
  -- If name string, then find index.
  local specIndex = spec
  if type(spec) == 'string' then
    for i, v in pairs(self.SPECIALIZATION_DATA) do
      if v.name == spec then
        specIndex = v.index
      end
    end
  end
  -- Check if specialization is active.
  if not self:IsSpecializationActive(spec) then
    SetSpecialization(specIndex)
    -- If not equipped, schedule timer to equip set.
    if self.db.profile.swapEquipment and not self:IsEquipmentActive(spec) then
      self:ScheduleTimer("EquipSet", 5.5, spec)
    end
  else
    -- If already specialized and equipment not active, equip immediately.
    if self.db.profile.swapEquipment and not self:IsEquipmentActive(spec) then
      UseEquipmentSet(spec)
    end  
  end
end

function kSwap:EquipSet(set)
  -- Equip set.
  UseEquipmentSet(set)
  self.verifySetEquippedCounter = 0
  -- Add verification of equip success.
  self:ScheduleRepeatingTimer("VerifySetEquipped", 5, set)
end

function kSwap:GetSpecializationNameIcon()
    local id, name, description, icon = GetSpecializationInfo(GetSpecialization())
    return name, icon
end

function kSwap:IsEquipmentActive(val)
  self:UpdateData()
  if type(val) == 'string' then
    for index, data in pairs(self.EQUIPMENT_DATA) do
      if data.name == val then
        return data.active
      end
    end
  elseif type(val) == 'number' then
    for index, data in pairs(self.EQUIPMENT_DATA) do
      if data.index == val then
        return data.active
      end
    end
  end
end

function kSwap:UpdateData()
  if self.db.profile.swapEquipment then
    self:UpdateEquipmentData()
  end
  self:UpdateSpecializationData()
  dataobj.text, dataobj.icon = self:GetSpecializationNameIcon()
end

function kSwap:IsSpecializationActive(val)
  self:UpdateData()
  if type(val) == 'string' then
    for index, data in pairs(self.SPECIALIZATION_DATA) do
      if data.name == val then
        return data.active
      end
    end
  elseif type(val) == 'number' then
    for index, data in pairs(self.SPECIALIZATION_DATA) do
      if data.index == val then
        return data.active
      end
    end
  end
end

function kSwap:UpdateEquipmentData()
  local numSets = GetNumEquipmentSets()
  self.EQUIPMENT_DATA = {}
  for setIndex = 1, numSets do
    local name, texture, setIndex, isEquipped, totalItems, equippedItems, inventoryItems, missingItems, ignoredSlots = GetEquipmentSetInfo(setIndex)
    tinsert(self.EQUIPMENT_DATA, {
      active = isEquipped,
      index = setIndex,
      name = name,
      texture = texture,
      setIndex = setIndex,
    })
  end
end

function kSwap:UpdateSpecializationData()
  -- Get specializations.
  local numSpecs = GetNumSpecializations()
  self.SPECIALIZATION_DATA = {}
  -- Loop through each
  for specIndex = 1, numSpecs do
    -- Get specialization info and add to tooltip.
    local id, name, description, icon, background, role, primaryStat = GetSpecializationInfo(specIndex)
    tinsert(self.SPECIALIZATION_DATA, {
      active = (specIndex == GetSpecialization()) and true or false,
      index = specIndex,
      name = name,
      description = description,
      icon = icon,
      role = role,
    })
  end
end

function kSwap:VerifySetEquipped(set)
  if not self.db.profile.swapEquipment then return end
  self.verifySetEquippedCounter = self.verifySetEquippedCounter + 1
  if self.verifySetEquippedCounter >= 6 or self:IsEquipmentActive(set) then
    self:CancelTimer("VerifySetEquipped")
  else
    -- Try to equip set.
    UseEquipmentSet(set)
  end
end

local function MouseHandler(event, func, button, ...)
	local name = func
	
	if type(func) == "function" then
		func(event, func,button, ...)
	else
		func:GetScript("OnClick")(func,button, ...)
	end
	
	LQT:Release(tooltip)
	tooltip = nil
end

-- LDB functions
function dataobj:OnEnter()
	-- Don't show if we're in combat.
	if InCombatLockdown() then
		return
	end
  
  -- Update
  kSwap:UpdateData()
  
  if tooltip then 
		LQT:Release(tooltip) 
	end

  tooltip = LQT:Acquire("kSwapTip",
    -- Columns
    kSwap.db.profile.swapEquipment and 4 or 3,
    -- Alignments
    "CENTER", "CENTER", "LEFT", "LEFT"
  )

	tooltip:Clear()

	local myFont
	if not kSwap_Tooltip_Font then
		myFont = CreateFont("kSwap_Tooltip_Font")
		local filename, size, flags = tooltip:GetFont():GetFont()
		myFont:SetFont(filename, size, flags)
		myFont:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	else
		myFont = kSwap_Tooltip_Font
	end
	tooltip:SetFont(myFont)

  local line = tooltip:AddLine()
  tooltip:SetCell(line, 1, "kSwap", nil, "LEFT", kSwap.db.profile.swapEquipment and 4 or 3)
  tooltip:AddSeparator()
  
  for i,data in pairs(kSwap.SPECIALIZATION_DATA) do
    local line = tooltip:AddLine()
    for column = 1, kSwap.db.profile.swapEquipment and 4 or 3 do
      addTooltipCells(tooltip, data, line, column)
    end
    tooltip:SetLineScript(line, "OnMouseUp", MouseHandler, function() kSwap:ActivateSpecialization(data.name) end)
  end

  tooltip:AddLine(" ")
  local line = tooltip:AddLine()
  tooltip:SetCell(line, 1, "|cffeda55fRight-Click|r for options.", nil, "LEFT", kSwap.db.profile.swapEquipment and 4 or 3)
  --tooltip:AddLine("|cffeda55fRight-Click|r for options.", 0.2, 1, 0.2)
  
  tooltip:SetAutoHideDelay(0.01, self)
	tooltip:SmartAnchorTo(self)
	tooltip:Show()
end

function addTooltipCells(tooltip, data, line, column)
  if column == 1 then
    tooltip:SetCell(line, column, data.active and path.."check.tga" or nil, myProvider)
  elseif column == 2 then
    if kSwap.db.profile.swapEquipment then
      tooltip:SetCell(line, column, kSwap:IsEquipmentActive(data.name) and path.."shield-blue.tga" or nil, myProvider)    
    else
      tooltip:SetCell(line, column, data.icon, myProvider)
    end
  elseif column == 3 then
    if kSwap.db.profile.swapEquipment then
      tooltip:SetCell(line, column, data.icon, myProvider)
    else
      tooltip:SetCell(line, column, data.name)
    end  
  elseif column == 4 then
    tooltip:SetCell(line, column, data.name)
  end
end

function dataobj:OnClick(button)
  if button == "RightButton" then
		InterfaceOptionsFrame_OpenToCategory(GetAddOnMetadata("kSwap", "Title"))
	end
end
