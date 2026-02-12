-- =========================================================
-- FS25 NPC Favor Mod - Moveable Favor List HUD
-- =========================================================
-- Standalone HUD module for the active favors list.
-- Supports drag-to-move (F8 toggle) and scale setting.
-- Inspired by CoursePlay's CpHudMoveableElement pattern.
--
-- Position/scale are persisted via NPCSettings (XML save/load).
-- Drag state is runtime-only — never persisted.
-- =========================================================

NPCFavorHUD = {}
NPCFavorHUD_mt = Class(NPCFavorHUD)

-- =========================================================
-- Constructor
-- =========================================================

function NPCFavorHUD.new(npcSystem)
    local self = setmetatable({}, NPCFavorHUD_mt)

    self.npcSystem = npcSystem

    -- Position (normalized 0–1, top-left anchor of the HUD box)
    self.posX = 0.02
    self.posY = 0.7

    -- Scale multiplier applied to all dimensions and text
    self.scale = 1.0

    -- Edit/drag state (runtime only, never persisted)
    self.editMode = false
    self.dragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0

    -- Animation timer for pulsing edit-mode border
    self.animTimer = 0

    -- Color palette
    self.COLORS = {
        BG          = {0.10, 0.10, 0.10, 0.70},
        BORDER      = {0.30, 0.50, 0.90, 0.80},  -- Edit-mode pulsing border
        HEADER      = {1.00, 1.00, 1.00, 1.00},
        TEXT        = {1.00, 1.00, 1.00, 1.00},
        TEXT_DIM    = {0.80, 0.80, 0.80, 1.00},
        TIME_OK     = {0.30, 0.80, 0.30, 1.00},   -- Green: > 6h
        TIME_WARN   = {0.80, 0.80, 0.30, 1.00},   -- Yellow: 2-6h
        TIME_URGENT = {0.80, 0.30, 0.30, 1.00},    -- Red: < 2h
        BAR_BG      = {0.10, 0.10, 0.10, 0.80},
        HINT        = {0.70, 0.80, 1.00, 0.90},
    }

    -- Base dimensions (before scale)
    self.BASE_WIDTH = 0.25
    self.BASE_LINE_HEIGHT = 0.02
    self.BASE_HEADER_HEIGHT = 0.025
    self.BASE_PADDING = 0.01
    self.BASE_TEXT_SMALL = 0.014
    self.BASE_TEXT_MEDIUM = 0.016
    self.MAX_FAVORS = 5

    -- 1x1 pixel overlay for colored rectangles
    self.bgOverlay = nil
    if createImageOverlay then
        self.bgOverlay = createImageOverlay("dataS/menu/base/graph_pixel.dds")
    end

    return self
end

-- =========================================================
-- Settings Integration
-- =========================================================

function NPCFavorHUD:loadFromSettings(settings)
    if not settings then return end
    self.posX = settings.favorHudPosX or 0.02
    self.posY = settings.favorHudPosY or 0.7
    self.scale = settings.favorHudScale or 1.0
    self:clampPosition()
end

function NPCFavorHUD:saveToSettings(settings)
    if not settings then return end
    settings.favorHudPosX = self.posX
    settings.favorHudPosY = self.posY
    settings.favorHudScale = self.scale
end

-- =========================================================
-- Edit Mode (F8 toggle)
-- =========================================================

function NPCFavorHUD:toggleEditMode()
    if self.editMode then
        self:exitEditMode()
    else
        self:enterEditMode()
    end
end

function NPCFavorHUD:enterEditMode()
    self.editMode = true
    self.dragging = false

    -- Show mouse cursor
    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(true)
    end

    print("[NPC Favor] HUD edit mode enabled — drag the favor list to reposition")
end

function NPCFavorHUD:exitEditMode()
    self.editMode = false
    self.dragging = false

    -- Hide mouse cursor
    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(false)
    end

    -- Save position to settings
    self:saveToSettings(self.npcSystem.settings)

    print("[NPC Favor] HUD edit mode disabled — position saved")
end

-- =========================================================
-- Mouse Event (drag logic)
-- =========================================================

function NPCFavorHUD:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.editMode then return end

    -- Only handle left mouse button (button 1)
    if button ~= 1 then return end

    if isDown then
        -- Check if mouse is over the HUD
        local hudX, hudY, hudW, hudH = self:getHUDRect()
        if posX >= hudX and posX <= hudX + hudW and posY >= hudY and posY <= hudY + hudH then
            self.dragging = true
            self.dragOffsetX = posX - self.posX
            self.dragOffsetY = posY - self.posY
        end
    end

    if isUp and self.dragging then
        self.dragging = false
        self:clampPosition()
        self:saveToSettings(self.npcSystem.settings)
    end

    -- Move while dragging
    if self.dragging then
        self.posX = posX - self.dragOffsetX
        self.posY = posY - self.dragOffsetY
        self:clampPosition()
    end
end

-- =========================================================
-- Geometry Helpers
-- =========================================================

--- Compute the HUD bounding rectangle.
-- @return x, y, width, height (normalized screen coords, bottom-left origin)
function NPCFavorHUD:getHUDRect()
    local s = self.scale
    local w = self.BASE_WIDTH * s
    local pad = self.BASE_PADDING * s

    -- Count visible favor lines
    local favorCount = 0
    if self.npcSystem and self.npcSystem.favorSystem then
        local favors = self.npcSystem.favorSystem:getActiveFavors()
        if favors then
            favorCount = math.min(#favors, self.MAX_FAVORS)
        end
    end

    -- Always show at least 1 line worth of height in edit mode (for the hint)
    if favorCount == 0 and self.editMode then
        favorCount = 1
    end

    local lineH = self.BASE_LINE_HEIGHT * s
    local headerH = self.BASE_HEADER_HEIGHT * s
    local h = headerH + favorCount * lineH + pad * 2

    -- Add overflow line if needed
    if self.npcSystem and self.npcSystem.favorSystem then
        local favors = self.npcSystem.favorSystem:getActiveFavors()
        if favors and #favors > self.MAX_FAVORS then
            h = h + lineH
        end
    end

    -- x, y is bottom-left corner of the rect
    local x = self.posX - pad
    local y = self.posY - h + pad

    return x, y, w + pad * 2, h
end

function NPCFavorHUD:clampPosition()
    local s = self.scale
    local w = self.BASE_WIDTH * s + self.BASE_PADDING * s * 2
    local h = self.BASE_HEADER_HEIGHT * s + self.BASE_LINE_HEIGHT * s + self.BASE_PADDING * s * 2

    -- Keep HUD within screen (0–1 range, with some margin)
    self.posX = math.max(0.01, math.min(1.0 - w + 0.01, self.posX))
    self.posY = math.max(h + 0.01, math.min(0.99, self.posY))
end

-- =========================================================
-- Update (per-frame logic)
-- =========================================================

function NPCFavorHUD:update(dt)
    self.animTimer = self.animTimer + dt

    -- Auto-exit edit mode if a GUI overlay opens
    if self.editMode then
        if g_gui and g_gui:getIsGuiVisible() then
            self:exitEditMode()
        end
    end
end

-- =========================================================
-- Draw (called every frame from NPCSystem:draw)
-- =========================================================

function NPCFavorHUD:draw()
    if not self.npcSystem.settings.showFavorList and not self.editMode then
        return
    end

    if not self.bgOverlay then
        return
    end

    local favors = {}
    if self.npcSystem.favorSystem then
        favors = self.npcSystem.favorSystem:getActiveFavors() or {}
    end

    -- Nothing to draw and not in edit mode
    if #favors == 0 and not self.editMode then
        return
    end

    local s = self.scale
    local pad = self.BASE_PADDING * s
    local lineH = self.BASE_LINE_HEIGHT * s
    local headerH = self.BASE_HEADER_HEIGHT * s
    local textSmall = self.BASE_TEXT_SMALL * s
    local textMedium = self.BASE_TEXT_MEDIUM * s
    local w = self.BASE_WIDTH * s

    -- Calculate visible favor count
    local visibleCount = math.min(#favors, self.MAX_FAVORS)
    if visibleCount == 0 and self.editMode then
        visibleCount = 1  -- placeholder row for drag hint
    end

    local hasOverflow = #favors > self.MAX_FAVORS
    local totalLines = visibleCount + (hasOverflow and 1 or 0)
    local bgH = headerH + totalLines * lineH + pad * 2

    -- Background
    local bgX = self.posX - pad
    local bgY = self.posY - bgH + pad
    setOverlayColor(self.bgOverlay, self.COLORS.BG[1], self.COLORS.BG[2], self.COLORS.BG[3], self.COLORS.BG[4])
    renderOverlay(self.bgOverlay, bgX, bgY, w + pad * 2, bgH)

    -- Edit mode: pulsing border
    if self.editMode then
        local pulse = 0.5 + 0.5 * math.sin(self.animTimer * 4)
        local borderAlpha = 0.4 + 0.4 * pulse
        local bw = 0.002  -- border width
        setOverlayColor(self.bgOverlay, self.COLORS.BORDER[1], self.COLORS.BORDER[2], self.COLORS.BORDER[3], borderAlpha)
        -- Top
        renderOverlay(self.bgOverlay, bgX, bgY + bgH - bw, w + pad * 2, bw)
        -- Bottom
        renderOverlay(self.bgOverlay, bgX, bgY, w + pad * 2, bw)
        -- Left
        renderOverlay(self.bgOverlay, bgX, bgY, bw, bgH)
        -- Right
        renderOverlay(self.bgOverlay, bgX + w + pad * 2 - bw, bgY, bw, bgH)
    end

    -- Header
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(self.COLORS.HEADER[1], self.COLORS.HEADER[2], self.COLORS.HEADER[3], self.COLORS.HEADER[4])
    renderText(self.posX, self.posY, textMedium, g_i18n:getText("npc_hud_active_favors") or "Active Favors:")
    setTextBold(false)

    -- Favor lines (or drag hint)
    if #favors == 0 and self.editMode then
        -- Show drag hint when no favors
        setTextColor(self.COLORS.HINT[1], self.COLORS.HINT[2], self.COLORS.HINT[3], self.COLORS.HINT[4])
        local hintText = g_i18n:getText("npc_hud_drag_hint") or "Drag to move"
        renderText(self.posX, self.posY - lineH, textSmall, hintText)
    else
        for i = 1, visibleCount do
            local favor = favors[i]
            local yPos = self.posY - (i * lineH)

            local timeRemaining = favor.timeRemaining or 0
            local hours = timeRemaining / (60 * 60 * 1000)

            -- Time text
            local timeText
            if hours < 1 then
                timeText = string.format("%.0fm", hours * 60)
            else
                timeText = string.format("%.1fh", hours)
            end

            -- NPC name (truncate if long)
            local npcName = favor.npcName or "NPC"
            if string.len(npcName) > 12 then
                npcName = string.sub(npcName, 1, 10) .. ".."
            end

            -- Favor text
            local desc = favor.description or ""
            local text = string.format("%s - %s [%s]",
                npcName,
                string.sub(desc, 1, 20) .. (string.len(desc) > 20 and ".." or ""),
                timeText)

            -- Time-based color
            local textColor = self.COLORS.TEXT
            if hours < 2 then
                textColor = self.COLORS.TIME_URGENT
            elseif hours < 6 then
                textColor = self.COLORS.TIME_WARN
            else
                textColor = self.COLORS.TIME_OK
            end

            setTextColor(textColor[1], textColor[2], textColor[3], textColor[4])

            -- Append progress percentage
            if favor.progress and favor.progress > 0 then
                text = text .. string.format(" (%d%%)", favor.progress)
            end

            renderText(self.posX, yPos, textSmall, text)

            -- Progress bar
            if favor.progress and favor.progress > 0 then
                local barWidth = 0.1 * s
                local barHeight = 0.005 * s
                local barY = yPos - 0.008 * s

                -- Background bar
                setOverlayColor(self.bgOverlay, self.COLORS.BAR_BG[1], self.COLORS.BAR_BG[2], self.COLORS.BAR_BG[3], self.COLORS.BAR_BG[4])
                renderOverlay(self.bgOverlay, self.posX, barY, barWidth, barHeight)

                -- Progress fill
                local progressWidth = barWidth * (favor.progress / 100)
                setOverlayColor(self.bgOverlay, textColor[1], textColor[2], textColor[3], 0.8)
                renderOverlay(self.bgOverlay, self.posX, barY, progressWidth, barHeight)
            end
        end
    end

    -- Overflow count
    if hasOverflow then
        local yPos = self.posY - ((visibleCount + 1) * lineH)
        setTextColor(self.COLORS.TEXT_DIM[1], self.COLORS.TEXT_DIM[2], self.COLORS.TEXT_DIM[3], self.COLORS.TEXT_DIM[4])
        renderText(self.posX, yPos, textSmall * 0.9,
            string.format(g_i18n:getText("npc_hud_and_more") or "...and %d more", #favors - self.MAX_FAVORS))
    end

    -- Reset text state
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

-- =========================================================
-- Cleanup
-- =========================================================

function NPCFavorHUD:delete()
    if self.editMode then
        -- Restore cursor state
        if g_inputBinding and g_inputBinding.setShowMouseCursor then
            g_inputBinding:setShowMouseCursor(false)
        end
        self.editMode = false
    end

    if self.bgOverlay then
        delete(self.bgOverlay)
        self.bgOverlay = nil
    end
end
