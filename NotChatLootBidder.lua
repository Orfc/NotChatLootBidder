local NotChatLootBidder = NotChatLootBidder_Frame
local gfind = string.gmatch or string.gfind
local addonName = "NotChatLootBidder"
local addonTitle = GetAddOnMetadata(addonName, "Title")
local addonNotes = GetAddOnMetadata(addonName, "Notes")
local addonVersion = GetAddOnMetadata(addonName, "Version")
local addonAuthor = GetAddOnMetadata(addonName, "Author")
local me = UnitName("player")
local myClass, myCLASS = UnitClass("player")
local myRace, _ = UnitRace("player")
local chatPrefix = "<BID> "
local frameId = 0
local maxFrames = 8
local needFrames = {}
local itemRegex = "|c.-|H.-|h|r"
local useable = {
  ["Priest"] = { "One-Handed Maces", "Staves", "Daggers", "Wands", "Bows" },
  ["Mage"] = { "One-Handed Swords", "Staves", "Daggers", "Wands" },
  ["Warlock"] = { "One-Handed Swords", "Staves", "Daggers", "Wands" },
  ["Rogue"] = { "Leather", "Daggers", "One-Handed Swords", "One-Handed Maces", "One-Handed Axes", "Fist Weapons", "Bows", "Crossbows", "Guns", "Thrown", "Arrow", "Bullet" },
  ["Druid"] = { "Leather", "One-Handed Maces", "Two-Handed Maces", "Polearms", "Staves", "Daggers", "Fist Weapons", "Idols" },
  ["Hunter"] = { "Leather", "Mail",  "One-Handed Axes", "Two-Handed Axes", "One-Handed Swords", "Two-Handed Swords", "Polearms", "Staves", "Daggers", "Fist Weapons", "Bows", "Crossbows", "Guns", "Arrow", "Bullet" },
  ["Shaman"] = { "Leather", "Mail", "One-Handed Axes", "Two-Handed Axes", "One-Handed Maces", "Two-Handed Maces", "Staves", "Daggers", "Fist Weapons", "Shields", "Totems" },
  ["Warrior"] = { "Leather", "Mail", "Plate", "One-Handed Axes", "Two-Handed Axes", "One-Handed Swords", "Two-Handed Swords", "One-Handed Maces", "Two-Handed Maces", "Polearms", "Staves", "Daggers", "Fist Weapons", "Shields", "Bows", "Crossbows", "Guns", "Thrown", "Arrow", "Bullet" },
  ["Paladin"] = { "Leather", "Mail", "Plate", "One-Handed Axes", "Two-Handed Axes", "One-Handed Swords", "Two-Handed Swords", "One-Handed Maces", "Two-Handed Maces", "Polearms", "Shields", "Librams" },
  ["All"] = { "Trade Goods", "Junk", "Bag", "Miscellaneous", "Quest", "Consumable", "Cloth" }
}
-- convert useable arrays into sets
for k, v in pairs(useable) do
  local v2k = {}
  for _, v2 in pairs(v) do v2k[v2] = true end
  useable[k] = v2k
end
local noHealing = { ["Hunter"]=true, ["Warrior"]=true, ["Rogue"]=true, ["Mage"]=true, ["Warlock"]=true }
local noDamageOrHealing = { ["Hunter"]=true, ["Warrior"]=true, ["Rogue"]=true }
local noSpells = { ["Warrior"]=true, ["Rogue"]=true }
local noMelee = { ["Mage"]=true, ["Warlock"]=true, ["Priest"]=true }

local highestBids = {} -- Track highest bid per item

-- Add this near the top with other local variables
local strfind = string.find
local strmatch = string.match or function(s, pattern)
    local start, finish, matches = strfind(s, pattern)
    if not start then return nil end
    if matches then return matches end
    return string.sub(s, start, finish)
end

local function IsTableEmpty(table)
  local next = next
  return next(table) == nil
end

local function LoadVariables()
  NotChatLootBidder_Store = NotChatLootBidder_Store or {}
  NotChatLootBidder_Store.Version = addonVersion
  NotChatLootBidder_Store.IgnoredItems = NotChatLootBidder_Store.IgnoredItems or {}
  NotChatLootBidder_Store.AutoIgnore = NotChatLootBidder_Store.AutoIgnore == true
  NotChatLootBidder_Store.Debug = NotChatLootBidder_Store.Debug == true
  NotChatLootBidder_Store.UIScale = NotChatLootBidder_Store.UIScale or 1
end

local function Error(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff" .. chatPrefix .. "|cffff0000 "..message)
end

local function Message(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffbe5eff".. chatPrefix .."|r "..message)
end

local function Debug(message)
  if NotChatLootBidder_Store.Debug then Message(message) end
end

local function ShowHelp()
  Message("/bid  - Open the placement frame")
  Message("/bid [item-link] [item-link2]  - Open test bid frames")
  Message("/bid scale [50-150]  - Set the UI scale percentage")
  Message("/bid autoignore  - Toggle 'auto-ignore' mode to ignore items your class cannot use")
  Message("/bid ignore  - List all ignored items")
  Message("/bid ignore clear  - Clear the ignore list completely")
  Message("/bid ignore [item-link] [item-link2]  - Toggle 'Ignore' for loot windows of these item(s)")
  Message("/bid clear  - Clear all bid frames")
	Message("/bid info  - Show information about the add-on")
end

local function ShowInfo()
  Message("UI Scale is set to " .. NotChatLootBidder_Store.UIScale * 100 .. "%")
	Message(addonNotes .. " for bugs and suggestions")
	Message("Written by " .. addonAuthor)
end

local function NextFrameId()
  frameId = frameId + 1
  if frameId > maxFrames then frameId = 1 end
  return frameId
end

local function ResetFrameStack()
  local frameHeight = 0
  for _, frame in pairs(needFrames) do
    frame:SetPoint("TOP", NotChatLootBidder, "TOP", 0, frameHeight)
    frameHeight = frameHeight - 128
    frame:SetScale(NotChatLootBidder_Store.UIScale * UIParent:GetScale())
  end
end

local function ClearFrames(fadeTime, masterLooter)
  for _, f in pairs(needFrames) do
    local frame = f
    -- Don't let someone else hijack the frames
    if masterLooter == nil or frame.masterLooter == masterLooter then
      local fadeInfo = {};
      fadeInfo.mode = "OUT";
      fadeInfo.timeToFade = fadeTime;
      fadeInfo.startAlpha = 1;
      fadeInfo.endAlpha = 0;
      fadeInfo.finishedFunc = function() frame:Hide() end;
      UIFrameFade(frame, fadeInfo);
    end
  end
end

local function CreateBidFrame(bidFrameId)
  local bidFrameName = "BidFrame" .. bidFrameId
  local frame = CreateFrame("Frame", bidFrameName, NotChatLootBidder, "BidFrameTemplate")
  
  -- Add handler for DKP bid button
  getglobal(bidFrameName .. "BidButton"):SetScript("OnClick", function()
    local f = this:GetParent()
    local bidBox = getglobal(f:GetName() .. "Bid")
    local amt = bidBox:GetText()
    amt = tonumber(amt)
    if amt == nil then return end
    if amt < frame.minimumBid then return end
    
    -- Clear focus from bid input
    bidBox:ClearFocus()
    
    ChatThrottleLib:SendChatMessage("ALERT", addonName, f.itemLink .. " bid " .. amt, "WHISPER", nil, f.masterLooter)
  end)

  -- Modify MS/OS/TMOG/STOCK handlers to not require bid amount
  for _, t in {"MS", "OS", "TMOG", "STOCK"} do
    local tier = t
    getglobal(bidFrameName .. tier .."Button"):SetScript("OnClick", function()
      local f = this:GetParent()
      -- Clear focus from bid input
      local bidBox = getglobal(f:GetName() .. "Bid")
      bidBox:ClearFocus()
      
      ChatThrottleLib:SendChatMessage("ALERT", addonName, f.itemLink .. " " .. string.lower(tier), "WHISPER", nil, f.masterLooter)
    end)
  end

  frame:SetScript("OnHide", function()
    needFrames[bidFrameId] = nil
    frame:ClearAllPoints()
    ResetFrameStack()
  end)
  return frame
end

local function IsAlliance()
  return myRace == "Gnome" or myRace == "Dwarf" or myRace == "Human" or myRace == "Night Elf" or myRace == "High Elf"
end

local function FilterOutType(t)
  if noDamageOrHealing[myClass] and string.find(t, "Increases damage and healing") then
    return true
  end
  if noHealing[myClass] and string.find(t, "Increases healing") then
    return true
  end
  if noSpells[myClass] and (string.find(t, "mana per 5") or string.find(t, "with spells")) then
    return true
  end
  if noMelee[myClass] and (string.find(t, "Agility") or string.find(t, "Strength") or string.find(t, "get a critical strike by") or string.find(t, "Atack Power") or string.find(t, "chance to hit by")) then
    return true
  end
end

local function UseableItem(itemLinkInfo, itemSubType, itemName)
  -- Onyxia/Nefarian heads for Twow
  if itemName ~= nil and string.find(itemName, "(Alliance)") then
    return IsAlliance()
  elseif itemName ~= nil and string.find(itemName, "(Horde)") then
    return not IsAlliance()
  end
  if itemLinkInfo then -- some items like mounts may not have linkInfo provided by the client
    BidFrameInfoTooltip:ClearLines()
    BidFrameInfoTooltip:SetOwner(NotChatLootBidder, "NONE", 0, 0)
    BidFrameInfoTooltip:SetHyperlink(itemLinkInfo)
    BidFrameInfoTooltip:Show()
    for i=1, BidFrameInfoTooltip:NumLines() do
      local text = getglobal("BidFrameInfoTooltipTextLeft"..i):GetText()
      local _, _, match = string.find(text, "Classes: (.+)")
      -- If classes are set on the item, it is definitive
      if match then
        BidFrameInfoTooltip:Hide()
        return string.find(match, myClass)
      end
      if FilterOutType(text) then
        BidFrameInfoTooltip:Hide()
        return false
      end
    end
    BidFrameInfoTooltip:Hide()
  end
  if itemSubType == nil or itemSubType == "" or useable["All"][itemSubType] == true then
    return true
  end
  -- print("Checking item sub type: " .. itemSubType)
  return useable[myClass][itemSubType] == true
end

local function LoadBidFrame(item, masterLooter, minimumBid, mode)
  local _, _ , itemKey = string.find(item, "(item:%d+:%d+:%d+:%d+)")
  local itemName, itemLinkInfo, itemRarity, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemKey)
  if itemLinkInfo == nil then
    itemLinkInfo = itemKey
  end
  if NotChatLootBidder_Store.AutoIgnore and not UseableItem(itemLinkInfo, itemSubType, itemName) then
    Debug("Ignoring " .. itemName)
    return
  end
  local bidFrameId = NextFrameId()
  local frame = getglobal("BidFrame" .. bidFrameId) or CreateBidFrame(bidFrameId)
  if frame:IsVisible() then Error("More than " .. maxFrames .. " bid frames loaded.  Overwriting " .. frame.itemLink .. " (" .. bidFrameId .. ")") end
  frame.itemLink = item
  frame.itemLinkInfo = itemLinkInfo
  frame.masterLooter = masterLooter
  frame.minimumBid = minimumBid or 10  -- Set default here
  frame.mode = mode or "DKP"
  needFrames[bidFrameId] = frame
  
  -- Show/hide bid input and button based on mode
  local bidBox = getglobal(frame:GetName() .. "Bid")
  local bidButton = getglobal(frame:GetName() .. "BidButton")
  
  if frame.mode == "DKP" then
    bidBox:Show()
    bidButton:Show()
    -- Initialize highest bid tracking
    if not highestBids[item] then
      highestBids[item] = frame.minimumBid
    end
    -- Set initial bid amount
    bidBox:SetText(frame.minimumBid)
  else
    bidBox:Hide()
    bidButton:Hide()
  end

  getglobal(frame:GetName() .. "ItemIconItemName"):SetText(item)
  getglobal(frame:GetName() .. "ItemIcon"):SetNormalTexture(itemTexture or "Interface\\Icons\\Inv_misc_questionmark")
  getglobal(frame:GetName() .. "ItemIcon"):SetPushedTexture(itemTexture or "Interface\\Icons\\Inv_misc_questionmark")
  ResetFrameStack()
  UIFrameFadeIn(frame, .5, 0, 1)
end

local function GetItemLinks(str, start)
  local itemLinks = {}
  local _start, _end = nil, -1
  while true do
    _start, _end = string.find(str, itemRegex, _end + 1)
    if _start == nil then
      return itemLinks
    end
    table.insert(itemLinks, string.sub(str, _start, _end))
  end
end

local function ListIgnored(message)
  if IsTableEmpty(NotChatLootBidder_Store.IgnoredItems) then
    Message("No items are ignored")
    return
  end
  Message("The following items are ignored:")
  for item,_ in pairs(NotChatLootBidder_Store.IgnoredItems) do
    Message(item)
  end
end

local function ToggleIgnore(message)
  local ignoredItems = NotChatLootBidder_Store.IgnoredItems
  for _, item in GetItemLinks(message) do
    if ignoredItems[item] then
      ignoredItems[item] = nil
      Message(item .. " is no longer ignored")
    else
      ignoredItems[item] = true
      Message(item .. " is now ignored")
    end
  end
end

local function TogglePlacementFrame()
  local placementFrame = getglobal("NotChatLootBidder_FramePlacement")
  if placementFrame:IsVisible() then
    placementFrame:Hide()
  else
    placementFrame:SetScale(NotChatLootBidder_Store.UIScale * UIParent:GetScale())
    placementFrame:Show()
  end
end

local function InitSlashCommands()
	SLASH_NotChatLootBidder1 = "/bid"
	SlashCmdList[addonName] = function(message)
		local commandlist = { }
		local command
		for command in gfind(message, "[^ ]+") do
			table.insert(commandlist, command)
		end
    if commandlist[1] == nil then
      TogglePlacementFrame()
    elseif commandlist[1] == "help" then
			ShowHelp()
    elseif commandlist[1] == "info" then
			ShowInfo()
    elseif commandlist[1] == "clear" then
      ClearFrames(.2)
    elseif commandlist[1] == "autoignore" then
      NotChatLootBidder_Store.AutoIgnore = not NotChatLootBidder_Store.AutoIgnore
      Message("Auto-ignore mode is " .. (NotChatLootBidder_Store.AutoIgnore and "enabled" or "disabled"))
    elseif commandlist[1] == "ignore" then
      if commandlist[2] == "clear" then
        NotChatLootBidder_Store.IgnoredItems = {}
        Message("The ignore list has been cleared!")
      elseif commandlist[2] ~= nil then
        ToggleIgnore(message)
      else
        ListIgnored()
      end
    elseif commandlist[1] == "scale" then
      local scale = tonumber(commandlist[2] or "")
      if scale ~= nil and scale >= 50 and scale <= 150 then scale = scale / 100 end -- convert whole numbers into decimal %
      if scale == nil or scale > 1.5 or scale < .5 then
        Error("Invalid scale value.  Use a number between 50 and 150.")
      else
        NotChatLootBidder_Store.UIScale = scale
        NotChatLootBidder.UI_SCALE_CHANGED()
      end
    else
      for _, i in GetItemLinks(message) do
        if NotChatLootBidder_Store.IgnoredItems[i] == nil then
          LoadBidFrame(i, me)
        end
      end
    end
  end
end

function NotChatLootBidder.ADDON_LOADED(loadedAddonName)
  if loadedAddonName == addonName then
    LoadVariables()
    InitSlashCommands()
    DEFAULT_CHAT_FRAME:AddMessage("Loaded " .. addonTitle .. " by " .. addonAuthor .. " v." .. addonVersion)
    this:UnregisterEvent("ADDON_LOADED")
  end
end

function NotChatLootBidder.PARTY_MEMBERS_CHANGED()
  VersionUtil:PARTY_MEMBERS_CHANGED(addonName)
end

-- Add near the top with other debug functions
local function DebugBid(message, itemLink, bidType, bidAmount)
  if NotChatLootBidder_Store.Debug then
    Message("Bid received: " .. message)
    Message("Parsed: item=" .. (itemLink or "nil") .. " type=" .. (bidType or "nil") .. " amount=" .. (bidAmount or "nil"))
  end
end

function NotChatLootBidder.CHAT_MSG_ADDON(addonTag, stringMessage, channel, sender)
  if VersionUtil:CHAT_MSG_ADDON(addonName, function(ver)
    Message("New version " .. ver .. " of " .. addonTitle .. " is available! Upgrade now at " .. addonNotes)
  end) then return end

  if addonTag == addonName then
    local incomingMessage = VersionUtil:ParseMessage(stringMessage)
    if incomingMessage["items"] then
      local minimumBid = incomingMessage["minimumBid"] or 10 -- Changed default from 1 to 10
      local mode = incomingMessage["mode"] -- defaults to "DKP"
      for _, i in GetItemLinks(string.gsub(incomingMessage["items"], "~~~", ",")) do
        LoadBidFrame(i, sender, minimumBid, mode)
      end
    elseif incomingMessage["endSession"] then
      -- Clear highest bids when session ends
      highestBids = {}
      ClearFrames(2, sender)
    else
      -- Fix the pattern to match the actual message format
      local itemLink, bidType, bidAmount = strmatch(stringMessage, "(|c.-|h|r) (%a+) (%d+)")
      if itemLink and bidType == "bid" and bidAmount then
        DebugBid(stringMessage, itemLink, bidType, bidAmount)
        UpdateBidSuggestion(itemLink, bidAmount)
      end
    end
  end
end

function NotChatLootBidder.PLAYER_ENTERING_WORLD()
  VersionUtil:PLAYER_ENTERING_WORLD(addonName)
  if NotChatLootBidder_Store.Point and getn(NotChatLootBidder_Store.Point) == 4 then
    NotChatLootBidder:SetPoint(NotChatLootBidder_Store.Point[1], "UIParent", NotChatLootBidder_Store.Point[2], NotChatLootBidder_Store.Point[3], NotChatLootBidder_Store.Point[4])
  else
    TogglePlacementFrame()
  end
  this:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function NotChatLootBidder.PLAYER_LEAVING_WORLD()
  local point, _, relativePoint, xOfs, yOfs = NotChatLootBidder:GetPoint()
  NotChatLootBidder_Store.Point = {point, relativePoint, xOfs, yOfs}
end

function NotChatLootBidder.UI_SCALE_CHANGED()
  TogglePlacementFrame()
  TogglePlacementFrame()
  ResetFrameStack()
end

-- Add function to update bid suggestions
local function UpdateBidSuggestion(item, newBid)
  if tonumber(newBid) > (highestBids[item] or 0) then
    highestBids[item] = tonumber(newBid)
    -- Update all visible frames for this item
    for _, frame in pairs(needFrames) do
      if frame.itemLink == item then
        local bidBox = getglobal(frame:GetName() .. "Bid")
        bidBox:SetText(highestBids[item] + 10)
      end
    end
  end
end

-- Add this function to handle bid updates
local function UpdateBidSuggestion(item, newBid)
  if tonumber(newBid) > (highestBids[item] or 0) then
    highestBids[item] = tonumber(newBid)
    -- Update all visible frames for this item
    for _, frame in pairs(needFrames) do
      if frame.itemLink == item then
        local bidBox = getglobal(frame:GetName() .. "Bid")
        if bidBox:IsVisible() then  -- Only update if in DKP mode
          bidBox:SetText(RoundUpToTen(highestBids[item] + 10))
        end
      end
    end
  end
end

-- Modify the CHAT_MSG_WHISPER handler to catch bid messages
function NotChatLootBidder.CHAT_MSG_WHISPER()
  if event == "CHAT_MSG_WHISPER" then
    local message = arg1
    local itemLink, bidType, bidAmount = strmatch(message, "(|c.-|h|r) (%a+) (%d+)")
    if itemLink and bidType == "bid" and bidAmount then
      UpdateBidSuggestion(itemLink, bidAmount)
    end
  end
end

-- Also add CHAT_MSG_RAID, CHAT_MSG_RAID_LEADER, and CHAT_MSG_RAID_WARNING handlers
function NotChatLootBidder.CHAT_MSG_RAID()
  local message = arg1
  -- Match the format: "player bid X DKP for [item]"
  local bidder, bidAmount, itemLink = strmatch(message, "(.+) bid (%d+) DKP for (|c.-|h|r)")
  
  if bidder and bidAmount and itemLink then
    Debug("Caught bid: " .. bidder .. " bid " .. bidAmount .. " on " .. itemLink)
    UpdateBidSuggestion(itemLink, bidAmount)
  end
end

-- Add this helper function near the top with other local functions
local function RoundUpToTen(number)
  return math.ceil(number / 10) * 10
end

local function UpdateBidSuggestion(item, newBid)
  newBid = tonumber(newBid)
  if newBid and (not highestBids[item] or newBid > highestBids[item]) then
    Debug("New highest bid for " .. item .. ": " .. newBid)
    highestBids[item] = newBid
    
    -- Update all visible frames for this item
    for _, frame in pairs(needFrames) do
      if frame.itemLink == item then
        local bidBox = getglobal(frame:GetName() .. "Bid")
        if bidBox:IsVisible() then
          local suggestedBid = RoundUpToTen(highestBids[item] + 10)
          bidBox:SetText(suggestedBid)
          Debug("Updated bid box to " .. suggestedBid)
        end
      end
    end
  end
end

-- Also handle raid leader and raid warning messages
NotChatLootBidder.CHAT_MSG_RAID_LEADER = NotChatLootBidder.CHAT_MSG_RAID
NotChatLootBidder.CHAT_MSG_RAID_WARNING = NotChatLootBidder.CHAT_MSG_RAID

-- Register the new events in the XML
