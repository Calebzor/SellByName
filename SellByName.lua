-----------------------------------------------------------------------------------------------
-- SellByName
-- Set up a list of items to be sold by name. by Caleb - calebzor@gmail.com
-- /sbn
-----------------------------------------------------------------------------------------------

--[[
	TODO:
	
]]--

local sVersion = "9.0.1.7"

require "GameLib"
require "Tooltip"
require "ChatSystemLib"

-----------------------------------------------------------------------------------------------
-- Upvalues
-----------------------------------------------------------------------------------------------
local GameLib = GameLib
local Tooltip = Tooltip
local Apollo = Apollo
local ipairs = ipairs
local unpack = unpack
local SellItemToVendorById = SellItemToVendorById
local ChatSystemLib = ChatSystemLib

-----------------------------------------------------------------------------------------------
-- Package loading
-----------------------------------------------------------------------------------------------
local addon = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("SellByName", false)
local GeminiConfig = Apollo.GetPackage("Gemini:Config-1.0").tPackage
--local GeminiCmd = Apollo.GetPackage("Gemini:ConfigCmd-1.0").tPackage
local L = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:GetLocale("SellByName", true)

-----------------------------------------------------------------------------------------------
-- Locals and defaults
-----------------------------------------------------------------------------------------------
local defaults = {
	profile = {
		bAllowSell = true,
		tSellList = {},
		tIgnored = {},
		tPos = {},
	},
}

local ktQualityCodeToBorderStrings = {
	[Item.CodeEnumItemQuality.Inferior]  = "BK3:UI_BK3_ItemQualityGrey",
	[Item.CodeEnumItemQuality.Average]   = "BK3:UI_BK3_ItemQualityWhite",
	[Item.CodeEnumItemQuality.Good]      = "BK3:UI_BK3_ItemQualityGreen",
	[Item.CodeEnumItemQuality.Excellent] = "BK3:UI_BK3_ItemQualityBlue",
	[Item.CodeEnumItemQuality.Superb]    = "BK3:UI_BK3_ItemQualityPurple",
	[Item.CodeEnumItemQuality.Legendary] = "BK3:UI_BK3_ItemQualityOrange",
	[Item.CodeEnumItemQuality.Artifact]  = "BK3:UI_BK3_ItemQualityMagenta"
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function addon:OnInitialize()

	self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)

	self.myOptionsTable = {
		type = "group",
		get = function(info) return self.db.profile[info[#info]] end,
		set = function(info, v) self.db.profile[info[#info]] = v end,
		args = {
			bAllowSell = {
				order = 1,
				name = "Allow automatic selling",
				type = "toggle",
				width = "full",
			},
			addItem = {
				order = 4,
				name = "Add item to the list by name:",
				type = "input",
				width = "full",
				usage = "Something must be written here",
				set = function(info, v) self.db.profile[info[#info]] = v self:AddItem(v:lower()) end,
				pattern = "%w+",
			},
			itemToRemove = {
				order = 90,
				name = "Item to remove from the list:",
				desc = "Select an item from the dropdown window to be removed from the list.",
				type = "select",
				values = self.db.profile.tSellList,
				get = function() end,
				set = function(info, v) self.db.profile[info[#info]] = v self:RemoveItem(v:lower()) end,
				width = "full",
			},
			openWindowDesc = {
				order = 95,
				name = "Open window to add items from inventory to the list",
				type = "description",
			},
			openAddItemWindow = {
				order = 100,
				name = "Open window",
				type = "execute",
				width = "full",
				handler = self,
				func = "OpenWindow",
			},
			itemToUnIgnore = {
				order = 120,
				name = "Item to unignore from the ignore list",
				desc = "Select an item from the dropdown window to be removed from the ignore list of the inventory window.",
				type = "select",
				values = self.db.profile.tIgnored,
				get = function() end,
				set = function(info, v) self.db.profile[info[#info]] = v self:RemoveIgnore(v:lower()) end,
				width = "full",
			},

			GeminiConfigScrollingFrameBottomWidgetFix = {
				order = 99999,
				name = "",
				type = "description",
			},
		},
	}
end

function addon:OnEnable()
	GeminiConfig:RegisterOptionsTable("SellByName", self.myOptionsTable)

	Apollo.RegisterSlashCommand("sbn", "OpenMenu", self)
	Apollo.RegisterSlashCommand("SellByName", "OpenMenu", self)
	Apollo.RegisterSlashCommand("sellbyname", "OpenMenu", self)

	-- Event thrown by opening the a Vendor window
	Apollo.RegisterEventHandler("InvokeVendorWindow",   "OnInvokeVendorWindow", self)
	Apollo.RegisterEventHandler("LootedItem", "OnLootedItem", self)

	self.wSellByNameItemWindow = Apollo.LoadForm("SellByName.xml", "SellByNameItemWindow", nil, self)
	if self.db.profile.tPos.SellByNameItemWindow then
		self.wSellByNameItemWindow:SetAnchorOffsets(unpack(self.db.profile.tPos.SellByNameItemWindow))
	end

	-- self:OpenMenu()
end

function addon:OpenMenu()
	Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("SellByName")
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function addon:AddItem(sItemName)
	if sItemName and not self.db.profile.tSellList[sItemName] then
		self.db.profile.tSellList[sItemName] = sItemName
	end
end

function addon:RemoveItem(sItemName)
	if sItemName and self.db.profile.tSellList[sItemName] then
		self.db.profile.tSellList[sItemName] = nil
	end
end

function addon:RemoveIgnore(sItemName)
	if sItemName and self.db.profile.tIgnored[sItemName] then
		self.db.profile.tIgnored[sItemName] = nil
	end
	if self.wSellByNameItemWindow:IsShown() then
		self:RedrawList()
	end
end

function addon:IsSellable(item)
	return self.db.profile.tSellList[item:GetName():lower()]
end

function addon:IsIgnored(item)
	return self.db.profile.tIgnored[item:GetName():lower()]
end

function addon:AddItemToIgnore(sItemName)
	if sItemName and not self.db.profile.tIgnored[sItemName] then
		self.db.profile.tIgnored[sItemName] = sItemName
	end
end

function addon:SellItems()
	local tInventoryItems = GameLib.GetPlayerUnit():GetInventoryItems()
	local nItemCount = 0
	for _, v in ipairs(tInventoryItems) do
		if self:IsSellable(v.itemInBag) then
			nItemCount = nItemCount + v.itemInBag:GetStackCount()
			SellItemToVendorById(v.itemInBag:GetInventoryId(), v.itemInBag:GetStackCount())
		end
	end
	if nItemCount > 0 then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, ("SellByName sold: %d items."):format(nItemCount))
	end
end

function addon:DestroyList()
	local wList = self.wSellByNameItemWindow:FindChild("ItemList")
	wList:DestroyChildren()
end

function addon:RedrawList()
	self:DestroyList()
	local wList = self.wSellByNameItemWindow:FindChild("ItemList")
	local tInventoryItems = GameLib.GetPlayerUnit():GetInventoryItems()
	for _, v in ipairs(tInventoryItems) do
		if not self:IsSellable(v.itemInBag) and not self:IsIgnored(v.itemInBag) then
			local tItem = v.itemInBag
			local wItem = Apollo.LoadForm("SellByName.xml", "Item", wList, self)
			wItem:SetData(tItem)

			local wTextContainer = wItem:FindChild("TextContainer")
			wTextContainer:FindChild("Name"):SetText(tItem:GetName())
			wTextContainer:FindChild("Type"):SetText(tItem:GetItemTypeName())

			local wIcon = wItem:FindChild("Icon")
			wIcon:SetSprite(tItem:GetIcon())

			local tDetailedInfo = tItem:GetDetailedInfo()
			if tDetailedInfo and tDetailedInfo.tPrimary and tDetailedInfo.tPrimary.tBind then
				wIcon:FindChild("BoE"):Show(tDetailedInfo.tPrimary.tBind.bOnEquip and not tDetailedInfo.tPrimary.tBind.bSoulbound)
			end

			local nStackCount = tItem:GetStackCount()
			if nStackCount > 1 then
				wIcon:FindChild("Count"):SetText(nStackCount)
			end
			wItem:FindChild("QualityBorder"):SetSprite(ktQualityCodeToBorderStrings[tItem:GetItemQuality()])


			local uSellPrice = tItem:GetSellPrice()
			if uSellPrice ~= nil then
				wItem:FindChild("SellValueCashWindow"):SetAmount(uSellPrice, 1)
			end

			local wIgnore = wItem:FindChild("IgnoreButton")
			wIgnore:SetData(tItem:GetName():lower())

			local wAdd = wItem:FindChild("AddButton")
			wAdd:SetData(tItem:GetName():lower())
		end
	end
	wList:ArrangeChildrenVert()
end
-----------------------------------------------------------------------------------------------
-- Event handlers and windows
-----------------------------------------------------------------------------------------------

function addon:GenerateItemTooltip(wHandler, wControl)
	if wHandler ~= wControl then return end
	local wnd = wControl
	wnd:SetTooltipDoc(nil)
	wnd:SetTooltipDocSecondary(nil)

	local tItem = wnd:GetData()

	local tTooltipOpts = {}
	tTooltipOpts.bPrimary = true
	tTooltipOpts.itemModData = tItem.itemModData
	tTooltipOpts.strMaker = tItem.strMaker
	tTooltipOpts.arGlyphIds = tItem.arGlyphIds
	tTooltipOpts.tGlyphData = tItem.itemGlyphData
	tTooltipOpts.itemCompare = tItem:GetEquippedItemForItemType()

	if Tooltip and Tooltip.GetItemTooltipForm then
		Tooltip.GetItemTooltipForm(self, wnd, tItem, tTooltipOpts, tItem.nStackSize)
		return tTooltipOpts
	end
end

function addon:OnSellByNameItemWindowMoveOrResize(wHandler, wControl)
	if wHandler ~= wControl then return end
	local l,t,r,b = wControl:GetAnchorOffsets()
	if not self.db.profile.tPos.SellByNameItemWindow then
		self.db.profile.tPos.SellByNameItemWindow = {}
	end
	self.db.profile.tPos.SellByNameItemWindow = {l,t,r,b}
end

function addon:AddItemFromInventory(wHandler, wControl, eMouseButton)
	self:AddItem(wControl:GetData())
	self:RedrawList()
end

function addon:IgnoreItem(wHandler, wControl, eMouseButton)
	self:AddItemToIgnore(wControl:GetData())
	self:RedrawList()
end

function addon:OnClose()
	self.wSellByNameItemWindow:Show(false)
end

function addon:OpenWindow()
	self.wSellByNameItemWindow:Show(true)
	self:RedrawList()
end

function addon:OnInvokeVendorWindow(unitArg)
	if not self.db.profile.bAllowSell then return end

	self:SellItems()
end

function addon:OnLootedItem()
	if self.wSellByNameItemWindow:IsShown() then
		self:RedrawList()
	end
end