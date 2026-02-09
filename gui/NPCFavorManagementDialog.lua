-- =========================================================
-- FS25 NPC Favor Mod - Favor Management Dialog
-- =========================================================
-- Displays active favors with ability to view details, cancel,
-- navigate to NPC, and manually complete (testing).
-- Issue #9 implementation
-- =========================================================

NPCFavorManagementDialog = {}
local NPCFavorManagementDialog_mt = Class(NPCFavorManagementDialog, MessageDialog)

NPCFavorManagementDialog.MAX_FAVORS = 10  -- Max visible favors

function NPCFavorManagementDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or NPCFavorManagementDialog_mt)
    self.npcSystem = nil
    self.favorIndices = {}  -- Maps row number to favor index
    return self
end

function NPCFavorManagementDialog:onCreate()
    local ok, err = pcall(function()
        NPCFavorManagementDialog:superClass().onCreate(self)
    end)
    if not ok then
        print("[NPC Favor] NPCFavorManagementDialog:onCreate() error: " .. tostring(err))
    end
end

function NPCFavorManagementDialog:setNPCSystem(npcSystem)
    self.npcSystem = npcSystem
end

function NPCFavorManagementDialog:onOpen()
    local ok, err = pcall(function()
        NPCFavorManagementDialog:superClass().onOpen(self)
    end)
    if not ok then
        print("[NPC Favor] NPCFavorManagementDialog:onOpen() error: " .. tostring(err))
        return
    end
    self:updateDisplay()
end

function NPCFavorManagementDialog:updateDisplay()
    local sys = self.npcSystem
    if not sys or not sys.favorSystem then
        if self.titleText then 
            self.titleText:setText("Favor System Not Available") 
        end
        return
    end

    -- Reset favor mapping
    self.favorIndices = {}

    -- Title
    if self.titleText then
        local activeFavors = sys.favorSystem.activeFavors or {}
        self.titleText:setText(string.format(
            g_i18n:getText("npc_favor_management_title") or "Active Favors (%d)", 
            #activeFavors
        ))
    end

    -- Subtitle
    if self.subtitleText then
        local gameTime = sys:getCurrentGameTime()
        local hour = math.floor(gameTime / 60) % 24
        local min = math.floor(gameTime) % 60
        self.subtitleText:setText(string.format("Game Time: %02d:%02d  |  Manage your active favors", 
            hour, min))
    end

    -- Clear all favor rows
    for i = 1, self.MAX_FAVORS do
        self:clearFavorRow(i)
    end

    -- Fill rows from active favors
    local activeFavors = sys.favorSystem.activeFavors or {}
    for i = 1, math.min(#activeFavors, self.MAX_FAVORS) do
        self:fillFavorRow(i, activeFavors[i], sys)
    end

    -- Footer
    if self.footerText then
        local totalFavors = #activeFavors
        if totalFavors > self.MAX_FAVORS then
            self.footerText:setText(string.format(
                "Showing %d of %d favors  |  Cancel reduces relationship by 10", 
                self.MAX_FAVORS, totalFavors))
        else
            self.footerText:setText("Cancel favor to reduce relationship by 10  |  Complete to finish manually")
        end
    end
end

--- Clear a favor row's elements
function NPCFavorManagementDialog:clearFavorRow(rowNum)
    local prefix = "favor" .. rowNum
    
    -- Hide background
    local bg = self[prefix .. "bg"]
    if bg then bg:setVisible(false) end
    
    -- Clear and hide text fields
    local fields = {"npc", "desc", "time", "reward"}
    for _, field in ipairs(fields) do
        local elem = self[prefix .. field]
        if elem then
            elem:setText("")
            elem:setVisible(false)
        end
    end
    
    -- Hide buttons
    local buttons = {"view", "cancel", "goto", "complete"}
    for _, btn in ipairs(buttons) do
        local elem = self[prefix .. btn]
        if elem then elem:setVisible(false) end
    end
end

--- Fill a favor row with data
function NPCFavorManagementDialog:fillFavorRow(rowNum, favor, sys)
    local prefix = "favor" .. rowNum
    
    -- Store favor reference
    self.favorIndices[rowNum] = favor
    
    -- Show background
    local bg = self[prefix .. "bg"]
    if bg then bg:setVisible(true) end
    
    -- Get NPC for this favor
    local npc = sys:getNPCById(favor.npcId)
    local npcName = npc and npc.name or "Unknown NPC"
    local relationship = npc and npc.relationship or 0
    
    -- NPC Name + Relationship
    local npcElem = self[prefix .. "npc"]
    if npcElem then
        npcElem:setText(string.format("%s (Rel: %d)", npcName, relationship))
        npcElem:setVisible(true)
        -- Color by relationship
        local r, g, b = self:getRelationshipColor(relationship)
        npcElem:setTextColor(r, g, b, 1)
    end
    
    -- Favor Description
    local descElem = self[prefix .. "desc"]
    if descElem then
        local desc = favor.description or favor.type or "Unknown favor"
        descElem:setText(desc:sub(1, 80))
        descElem:setVisible(true)
        descElem:setTextColor(0.9, 0.9, 0.9, 1)
    end
    
    -- Time Remaining
    local timeElem = self[prefix .. "time"]
    if timeElem then
        local timeText = self:getTimeRemainingText(favor, sys)
        timeElem:setText(timeText)
        timeElem:setVisible(true)
        
        -- Color based on urgency
        local urgency = self:getTimeUrgency(favor, sys)
        if urgency > 0.7 then
            timeElem:setTextColor(0.9, 0.3, 0.3, 1)  -- Red - urgent
        elseif urgency > 0.4 then
            timeElem:setTextColor(0.9, 0.7, 0.3, 1)  -- Yellow - moderate
        else
            timeElem:setTextColor(0.5, 0.85, 0.5, 1)  -- Green - plenty of time
        end
    end
    
    -- Reward
    local rewardElem = self[prefix .. "reward"]
    if rewardElem then
        local reward = favor.reward or 0
        rewardElem:setText(string.format("Reward: $%d", reward))
        rewardElem:setVisible(true)
        rewardElem:setTextColor(0.3, 0.9, 0.3, 1)
    end
    
    -- Show buttons
    local buttons = {"view", "cancel", "goto", "complete"}
    for _, btn in ipairs(buttons) do
        local elem = self[prefix .. btn]
        if elem then elem:setVisible(true) end
    end
end

--- Get time remaining text for a favor
function NPCFavorManagementDialog:getTimeRemainingText(favor, sys)
    if not favor.expiryTime then
        return "No time limit"
    end
    
    local currentTime = sys:getCurrentGameTime()
    local remaining = favor.expiryTime - currentTime
    
    if remaining < 0 then
        return "EXPIRED"
    elseif remaining < 60 then
        return string.format("%.0f minutes left", remaining)
    else
        local hours = math.floor(remaining / 60)
        local mins = math.floor(remaining % 60)
        return string.format("%dh %dm left", hours, mins)
    end
end

--- Get time urgency (0-1, where 1 is most urgent)
function NPCFavorManagementDialog:getTimeUrgency(favor, sys)
    if not favor.expiryTime or not favor.startTime then
        return 0
    end
    
    local currentTime = sys:getCurrentGameTime()
    local elapsed = currentTime - favor.startTime
    local total = favor.expiryTime - favor.startTime
    
    if total <= 0 then return 1 end
    
    return elapsed / total
end

--- Get relationship color
function NPCFavorManagementDialog:getRelationshipColor(value)
    if value < 15 then
        return 0.9, 0.3, 0.3
    elseif value < 30 then
        return 0.9, 0.55, 0.25
    elseif value < 50 then
        return 0.85, 0.85, 0.4
    elseif value < 70 then
        return 0.5, 0.85, 0.5
    elseif value < 85 then
        return 0.3, 0.75, 0.9
    else
        return 0.5, 0.6, 1
    end
end

-- Generate onClick handlers for View, Cancel, Goto, Complete for each favor
for i = 1, NPCFavorManagementDialog.MAX_FAVORS do
    -- View Details
    NPCFavorManagementDialog["onClickFavor" .. i .. "View"] = function(self)
        local favor = self.favorIndices[i]
        if not favor then return end
        
        local npc = self.npcSystem:getNPCById(favor.npcId)
        local npcName = npc and npc.name or "Unknown"
        
        local details = string.format(
            "=== Favor Details ===\nNPC: %s\nType: %s\nDescription: %s\nReward: $%d\nStatus: %s\n",
            npcName,
            favor.type or "Unknown",
            favor.description or "No description",
            favor.reward or 0,
            favor.status or "active"
        )
        
        print("[NPC Favor] " .. details)
        g_gui:showInfoDialog({
            text = details,
            dialogType = DialogElement.TYPE_INFO
        })
    end
    
    -- Cancel Favor
    NPCFavorManagementDialog["onClickFavor" .. i .. "Cancel"] = function(self)
        local favor = self.favorIndices[i]
        if not favor then return end
        
        local npc = self.npcSystem:getNPCById(favor.npcId)
        local npcName = npc and npc.name or "Unknown"
        
        -- Show confirmation dialog
        g_gui:showYesNoDialog({
            text = string.format("Cancel favor from %s? This will reduce relationship by 10.", npcName),
            callback = function(yes)
                if yes and self.npcSystem and self.npcSystem.favorSystem then
                    -- Cancel the favor
                    self.npcSystem.favorSystem:cancelFavor(favor.id)
                    
                    -- Reduce relationship
                    if npc then
                        self.npcSystem.relationshipManager:modifyRelationship(npc.id, -10, "favor_cancelled")
                    end
                    
                    -- Refresh display
                    self:updateDisplay()
                    
                    print(string.format("[NPC Favor] Canceled favor from %s", npcName))
                end
            end
        })
    end
    
    -- Go To NPC
    NPCFavorManagementDialog["onClickFavor" .. i .. "Goto"] = function(self)
        local favor = self.favorIndices[i]
        if not favor then return end
        
        local npc = self.npcSystem:getNPCById(favor.npcId)
        if not npc or not npc.position then
            print("[NPC Favor] Cannot teleport - NPC not found")
            return
        end
        
        -- Close dialog first
        self:close()
        
        -- Use same teleport logic as npcGoto
        local angle = math.random() * math.pi * 2
        local distance = 3
        local x = npc.position.x + math.cos(angle) * distance
        local y = npc.position.y
        local z = npc.position.z + math.sin(angle) * distance
        
        -- Snap to terrain
        if g_currentMission and g_currentMission.terrainRootNode then
            local ok, h = pcall(getTerrainHeightAtWorldPos,
                g_currentMission.terrainRootNode, x, 0, z)
            if ok and h then
                y = h + 0.05
            end
        end
        
        -- Calculate rotation to face NPC
        local dx = npc.position.x - x
        local dz = npc.position.z - z
        local rotY = math.atan2(dx, dz)
        
        -- Teleport
        local teleported = false
        if g_localPlayer and g_localPlayer.rootNode and g_localPlayer.rootNode ~= 0 then
            pcall(function()
                setWorldTranslation(g_localPlayer.rootNode, x, y, z)
                setWorldRotation(g_localPlayer.rootNode, 0, rotY, 0)
                teleported = true
            end)
        end
        if not teleported and g_currentMission and g_currentMission.player then
            local player = g_currentMission.player
            if player.rootNode and player.rootNode ~= 0 then
                pcall(function()
                    setWorldTranslation(player.rootNode, x, y, z)
                    setWorldRotation(player.rootNode, 0, rotY, 0)
                    teleported = true
                end)
            end
        end
        
        if teleported then
            print(string.format("[NPC Favor] Teleported to %s", npc.name))
            -- Notify system for UI stabilization
            if self.npcSystem then
                self.npcSystem.lastTeleportTime = self.npcSystem:getCurrentGameTime()
            end
        end
    end
    
    -- Complete Favor (manual/testing)
    NPCFavorManagementDialog["onClickFavor" .. i .. "Complete"] = function(self)
        local favor = self.favorIndices[i]
        if not favor then return end
        
        local npc = self.npcSystem:getNPCById(favor.npcId)
        local npcName = npc and npc.name or "Unknown"
        
        -- Show confirmation
        g_gui:showYesNoDialog({
            text = string.format("Manually complete favor from %s? (Testing/Debug)", npcName),
            callback = function(yes)
                if yes and self.npcSystem and self.npcSystem.favorSystem then
                    -- Complete the favor
                    self.npcSystem.favorSystem:completeFavor(favor.id)
                    
                    -- Award money
                    if g_currentMission and g_currentMission.player then
                        g_currentMission:addMoney(favor.reward or 0, g_currentMission.player.farmId, 
                            MoneyType.OTHER, true)
                    end
                    
                    -- Improve relationship
                    if npc then
                        self.npcSystem.relationshipManager:modifyRelationship(npc.id, 15, "favor_completed")
                    end
                    
                    -- Refresh display
                    self:updateDisplay()
                    
                    print(string.format("[NPC Favor] Completed favor from %s", npcName))
                end
            end
        })
    end
end

function NPCFavorManagementDialog:onClickRefresh()
    self:updateDisplay()
end

function NPCFavorManagementDialog:onClickClose()
    self:close()
end

function NPCFavorManagementDialog:onClose()
    NPCFavorManagementDialog:superClass().onClose(self)
end

print("[NPC Favor] NPCFavorManagementDialog loaded")