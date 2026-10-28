--[[
    ========================================================================
    Project Jaina - GM Genie & Staff Control Suite (ControlPanel.lua)
    Reino: Project Jaina | Motor: JainaCore WotLK 3.3.5a (Build 12340)
    ========================================================================
    Panel Integral de Control GM, Teletransporte de Grupo, Baluartes (.outpost),
    Galeón de los Desertores, Desbloqueo de ICC, Modo Inmortal de Banda,
    Gestión de 30 Bots por Rol (WaniBOTS), Buscador de 9,299 Objetos y Utilidades.
    Arquitectura unificada: FranFranco (Wanitos) & DarckRovert (Project Jaina).
]]

local ADDON_NAME = "ProjectJaina_GMGenie"
local VERSION    = "3.2.0-Sovereign"
local TEXTURE_DIR = "Interface\\AddOns\\ProjectJaina_GMGenie\\Textures\\"

-- ================================================================
-- PERSISTENCIA Y MIGRACIÓN TRANSPARENTE
-- ================================================================
if not JainaGM_DB and WaniGM_DB then
    JainaGM_DB = WaniGM_DB
end
JainaGM_DB = JainaGM_DB or {}
WaniGM_DB  = JainaGM_DB -- Sincronización bidireccional

local function DB(key, default)
    if JainaGM_DB[key] == nil then JainaGM_DB[key] = default end
    return JainaGM_DB[key]
end

DB("minimized",        false)
DB("teleWithGroup",    false)
DB("currentTab",       1)
DB("resetAllRaid",     true)
DB("immortalAllRaid",  true)
DB("immortalActive",   false)
DB("x",                220)
DB("y",               -80)
DB("point",            "TOPLEFT")
DB("states",           { gm = false, fly = false, visible = false, chat = false })

local DEFAULT_CUSTOM_TELES = {
    "baluarte1","baluarte2","baluarte3","baluarte4","baluarte5","baluarte6",
    "barcos","barcos2","dalaran","fueradeicc","galeon","galeon_escala","gordo1","icecrown",
    "ironforge","libra","orgrimmar","profesor","reina","ruby",
    "stormwind","theramore","thunder","tuetano","undercity"
}
if type(JainaGM_DB.customTeles) ~= "table" or #JainaGM_DB.customTeles == 0 then
    JainaGM_DB.customTeles = {}
    for _, name in ipairs(DEFAULT_CUSTOM_TELES) do
        table.insert(JainaGM_DB.customTeles, name)
    end
end

-- ================================================================
-- COLA SEGURA Y TEMPORIZADA ANTI-FLOOD DE COMANDOS
-- ================================================================
local cmdQueue = {}
local cmdElapsed = 0
local cmdWorker = CreateFrame("Frame")
cmdWorker:SetScript("OnUpdate", function(self, elapsed)
    if #cmdQueue == 0 then return end
    cmdElapsed = cmdElapsed + elapsed
    if cmdElapsed >= 0.04 then
        cmdElapsed = 0
        local cmd = table.remove(cmdQueue, 1)
        if cmd and cmd ~= "" then
            local inGroup = (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0)
            local editBox = ChatFrameEditBox or (ChatFrame1 and ChatFrame1.editBox) or (LAST_ACTIVE_CHAT_EDIT_BOX)

            if cmd:sub(1, 1) == "." or cmd:sub(1, 1) == "#" then
                if editBox then
                    local prevText = editBox:GetText()
                    local prevType = editBox:GetAttribute("chatType")
                    local prevTarget = editBox:GetAttribute("channelTarget")
                    local isDead = UnitIsDeadOrGhost("player")

                    if isDead then
                        -- En estado muerto WoW bloquea SAY. Usamos RAID/PARTY o WHISPER a uno mismo
                        if inGroup then
                            editBox:SetAttribute("chatType", GetNumRaidMembers() > 0 and "RAID" or "PARTY")
                        else
                            editBox:SetAttribute("chatType", "WHISPER")
                            editBox:SetAttribute("channelTarget", UnitName("player"))
                        end
                    else
                        editBox:SetAttribute("chatType", "SAY")
                    end

                    editBox:SetText(cmd)
                    ChatEdit_SendText(editBox)

                    if (prevType == "PARTY" or prevType == "RAID") and not inGroup then
                        editBox:SetAttribute("chatType", "SAY")
                    elseif prevType then
                        editBox:SetAttribute("chatType", prevType)
                    end
                    if prevTarget then
                        editBox:SetAttribute("channelTarget", prevTarget)
                    end
                    editBox:SetText(prevText or "")
                else
                    SendChatMessage(cmd, "SAY")
                end
            else
                local skip = false
                if (cmd:sub(1, 4) == "/ra " or cmd:sub(1, 3) == "/p ") and not inGroup then
                    skip = true
                end
                if not skip and editBox then
                    local prev = editBox:GetText()
                    editBox:SetText(cmd)
                    ChatEdit_SendText(editBox)
                    editBox:SetText(prev or "")
                end
            end
        end
    end
end)

local function RunCmd(cmd)
    if not cmd or cmd == "" then return end
    table.insert(cmdQueue, cmd)
end

local function Msg(txt)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[JainaGM]|r " .. txt)
end

local function DoTeleport(dest)
    if not dest or dest == "" then return end
    local inGroup = (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0)
    if JainaGM_DB.teleWithGroup and inGroup then
        RunCmd(".tele group " .. dest)
        RunCmd(".groupsummon")
    else
        RunCmd(".tele " .. dest)
    end
end

-- ================================================================
-- DIALOGO DE CONFIRMACIÓN MODAL REUTILIZABLE
-- ================================================================
local ConfirmDialog = nil
local function ShowConfirm(title, body, onYes)
    if not ConfirmDialog then
        ConfirmDialog = CreateFrame("Frame", "JainaGMConfirmDialog", UIParent)
        ConfirmDialog:SetWidth(330); ConfirmDialog:SetHeight(135)
        ConfirmDialog:SetPoint("CENTER")
        ConfirmDialog:SetFrameStrata("TOOLTIP")
        ConfirmDialog:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true, tileSize = 32, edgeSize = 22,
            insets = { left = 7, right = 7, top = 7, bottom = 7 }
        })
        ConfirmDialog:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
        ConfirmDialog:SetBackdropBorderColor(1.0, 0.2, 0.2, 1.0)
        ConfirmDialog:EnableMouse(true)

        local t = ConfirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", 0, -14); t:SetWidth(300); t:SetJustifyH("CENTER")
        ConfirmDialog.titleTxt = t

        local b = ConfirmDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b:SetPoint("TOP", 0, -40); b:SetWidth(290); b:SetJustifyH("CENTER")
        ConfirmDialog.bodyTxt = b

        local bYes = CreateFrame("Button", nil, ConfirmDialog, "UIPanelButtonTemplate")
        bYes:SetSize(110, 24); bYes:SetPoint("BOTTOMLEFT", 30, 16); bYes:SetText("|cffff4444Confirmar|r")
        ConfirmDialog.bYes = bYes

        local bNo = CreateFrame("Button", nil, ConfirmDialog, "UIPanelButtonTemplate")
        bNo:SetSize(110, 24); bNo:SetPoint("BOTTOMRIGHT", -30, 16); bNo:SetText("Cancelar")
        bNo:SetScript("OnClick", function() ConfirmDialog:Hide() end)
    end
    ConfirmDialog.titleTxt:SetText(title or "Confirmación Requerida")
    ConfirmDialog.bodyTxt:SetText(body or "¿Deseas ejecutar esta acción de GM?")
    ConfirmDialog.bYes:SetScript("OnClick", function()
        ConfirmDialog:Hide()
        if onYes then onYes() end
    end)
    ConfirmDialog:Show()
end

-- ================================================================
-- FRAME PRINCIPAL Y ARTE LATERAL ANIMADO (JAINA & SYLVANAS)
-- ================================================================
local f = CreateFrame("Frame", "JainaGMFrame", UIParent)
f:SetWidth(260)
f:SetHeight(555)
f:SetPoint(JainaGM_DB.point or "TOPLEFT", UIParent, JainaGM_DB.point or "TOPLEFT", JainaGM_DB.x or 220, JainaGM_DB.y or -80)
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:SetFrameStrata("HIGH")

f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 22,
    insets = { left = 5, right = 5, top = 5, bottom = 5 }
})
f:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
f:SetBackdropBorderColor(1.0, 0.85, 0.35, 1.0)

-- Header para arrastrar
local header = CreateFrame("Frame", "JainaGMHeader", f)
header:SetHeight(24)
header:SetPoint("TOPLEFT", 6, -6)
header:SetPoint("TOPRIGHT", -6, -6)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function()
    f.isMoving = true
    f:StartMoving()
end)
header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    f.isMoving = false
    local point, _, _, x, y = f:GetPoint()
    JainaGM_DB.point = point
    JainaGM_DB.x = x
    JainaGM_DB.y = y
end)

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("LEFT", header, "LEFT", 6, 0)
title:SetText("|TInterface\\Icons\\INV_Crown_02:16:16:0:0|t |cff00ccffJainaGM|r |cffffffffDeluxe|r")

local minBtn = CreateFrame("Button", "JainaGMMinBtn", header, "UIPanelButtonTemplate")
minBtn:SetWidth(22); minBtn:SetHeight(18)
minBtn:SetPoint("RIGHT", header, "RIGHT", -22, 0)
minBtn:SetFrameLevel(header:GetFrameLevel() + 10)
minBtn:RegisterForClicks("AnyUp")
minBtn:SetText("-")

local closeBtn = CreateFrame("Button", "JainaGMCloseBtn", header, "UIPanelButtonTemplate")
closeBtn:SetWidth(18); closeBtn:SetHeight(18)
closeBtn:SetPoint("RIGHT", header, "RIGHT", -2, 0)
closeBtn:SetFrameLevel(header:GetFrameLevel() + 10)
closeBtn:RegisterForClicks("AnyUp")
closeBtn:SetText("x")
closeBtn:SetScript("OnClick", function() f:Hide() end)

-- Contenedor de contenido expandible
local content = CreateFrame("Frame", "JainaGMContent", f)
content:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -28)
content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)

-- Arte lateral de Jaina y Sylvanas
local JAINA_TEX_OPEN  = TEXTURE_DIR .. "jaina.tga"
local JAINA_TEX_BLINK = TEXTURE_DIR .. "jainablink.tga"
local SYLV_TEX_OPEN   = TEXTURE_DIR .. "sylvanas.tga"
local SYLV_TEX_BLINK  = TEXTURE_DIR .. "sylvanasblink.tga"

local jainaFrame = CreateFrame("Frame", "JainaGM_Jaina", content)
jainaFrame:SetWidth(257); jainaFrame:SetHeight(500)
jainaFrame:SetPoint("TOPRIGHT", f, "TOPLEFT", 24, 12)
jainaFrame:EnableMouse(false)

local jainaTex = jainaFrame:CreateTexture(nil, "BACKGROUND")
jainaTex:SetAllPoints(jainaFrame)
jainaTex:SetTexture(JAINA_TEX_OPEN)
jainaTex:SetTexCoord(0, 494/512, 0, 960/1024)

local sylvFrame = CreateFrame("Frame", "JainaGM_Sylvanas", content)
sylvFrame:SetWidth(232); sylvFrame:SetHeight(500)
sylvFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", -22, 12)
sylvFrame:EnableMouse(false)

local sylvTex = sylvFrame:CreateTexture(nil, "BACKGROUND")
sylvTex:SetAllPoints(sylvFrame)
sylvTex:SetTexture(SYLV_TEX_OPEN)
sylvTex:SetTexCoord(0, 446/512, 0, 960/1024)

-- Motor de parpadeo realista
local jainaBlinkTimer = math.random(30, 60) / 10
local jainaBlinkDuration = 0
local jainaIsBlinking = false

local sylvBlinkTimer = math.random(35, 75) / 10
local sylvBlinkDuration = 0
local sylvIsBlinking = false

local function UpdateBlink(elapsed)
    if not content:IsShown() then return end
    if jainaIsBlinking then
        jainaBlinkDuration = jainaBlinkDuration - elapsed
        if jainaBlinkDuration <= 0 then
            jainaIsBlinking = false
            jainaTex:SetTexture(JAINA_TEX_OPEN)
            jainaBlinkTimer = math.random(30, 65) / 10
        end
    else
        jainaBlinkTimer = jainaBlinkTimer - elapsed
        if jainaBlinkTimer <= 0 then
            jainaIsBlinking = true
            jainaBlinkDuration = 0.16
            jainaTex:SetTexture(JAINA_TEX_BLINK)
        end
    end

    if sylvIsBlinking then
        sylvBlinkDuration = sylvBlinkDuration - elapsed
        if sylvBlinkDuration <= 0 then
            sylvIsBlinking = false
            sylvTex:SetTexture(SYLV_TEX_OPEN)
            sylvBlinkTimer = math.random(35, 75) / 10
        end
    else
        sylvBlinkTimer = sylvBlinkTimer - elapsed
        if sylvBlinkTimer <= 0 then
            sylvIsBlinking = true
            sylvBlinkDuration = 0.16
            sylvTex:SetTexture(SYLV_TEX_BLINK)
        end
    end
end

-- Colapso y auto-hover
local isHoverPeek = false
local hoverElapsed = 0

local function UpdateLayout(minimized)
    isHoverPeek = false
    jainaIsBlinking = false
    jainaTex:SetTexture(JAINA_TEX_OPEN)
    sylvIsBlinking = false
    sylvTex:SetTexture(SYLV_TEX_OPEN)
    if minimized then
        content:Hide()
        f:SetHeight(34)
        minBtn:SetText("+")
        JainaGM_DB.minimized = true
    else
        content:Show()
        f:SetHeight(555)
        minBtn:SetText("-")
        JainaGM_DB.minimized = false
    end
end

local function TryHoverExpand()
    if JainaGM_DB.minimized and not isHoverPeek and not f.isMoving then
        isHoverPeek = true
        content:Show()
        f:SetHeight(555)
    end
end

header:HookScript("OnEnter", TryHoverExpand)
f:HookScript("OnEnter", TryHoverExpand)

f:SetScript("OnUpdate", function(self, elapsed)
    UpdateBlink(elapsed)
    if not isHoverPeek or f.isMoving then return end
    hoverElapsed = hoverElapsed + elapsed
    if hoverElapsed > 0.08 then
        hoverElapsed = 0
        local isOver = MouseIsOver(f) or (DropDownList1 and DropDownList1:IsShown() and MouseIsOver(DropDownList1))
        if not isOver then
            isHoverPeek = false
            content:Hide()
            f:SetHeight(34)
            minBtn:SetText("+")
            if DropDownList1 and DropDownList1:IsShown() then
                CloseDropDownMenus()
            end
        end
    end
end)

minBtn:SetScript("OnClick", function()
    if isHoverPeek then
        isHoverPeek = false
        JainaGM_DB.minimized = false
        minBtn:SetText("-")
    else
        UpdateLayout(not JainaGM_DB.minimized)
    end
end)

-- Helpers de UI
local function CreateSectionHeader(parent, icon, text, yOffset)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    lbl:SetText("|TInterface\\Icons\\" .. icon .. ":14:14:0:0|t  |cffffd100" .. text .. "|r")
    return lbl
end

local function MakeButton(parent, text, w, h, x, y, onClick, tooltip)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(w); btn:SetHeight(h)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetText(text)
    btn:RegisterForClicks("AnyUp")
    btn:SetScript("OnClick", onClick)
    if tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return btn
end

-- ================================================================
-- SECCIÓN FIJA SUPERIOR: ESTADOS GM
-- ================================================================
CreateSectionHeader(content, "Spell_Holy_DivineIntervention", "ESTADOS GM", -4)

local btnGM, btnFly, btnVis, btnChat
local function UpdateToggleStyles()
    btnGM:SetText(JainaGM_DB.states.gm and "|cff00ff00GM: ON|r" or "|cffff4444GM: OFF|r")
    btnFly:SetText(JainaGM_DB.states.fly and "|cff00ff00Vuelo: ON|r" or "|cffff4444Vuelo: OFF|r")
    btnVis:SetText(JainaGM_DB.states.visible and "|cff00ff00Invis: ON|r" or "|cffff4444Invis: OFF|r")
    btnChat:SetText(JainaGM_DB.states.chat and "|cff00ff00Chat: ON|r" or "|cffff4444Chat: OFF|r")
end

btnGM = MakeButton(content, "GM", 118, 22, 6, -20, function()
    JainaGM_DB.states.gm = not JainaGM_DB.states.gm
    RunCmd(JainaGM_DB.states.gm and ".gm on" or ".gm off")
    UpdateToggleStyles()
end, "Alterna Modo Dios / GM (.gm on/off)")

btnFly = MakeButton(content, "Vuelo", 118, 22, 126, -20, function()
    JainaGM_DB.states.fly = not JainaGM_DB.states.fly
    RunCmd(JainaGM_DB.states.fly and ".gm fly on" or ".gm fly off")
    UpdateToggleStyles()
end, "Alterna Vuelo Libre (.gm fly on/off)")

btnVis = MakeButton(content, "Invis", 118, 22, 6, -44, function()
    JainaGM_DB.states.visible = not JainaGM_DB.states.visible
    RunCmd(JainaGM_DB.states.visible and ".gm visible on" or ".gm visible off")
    UpdateToggleStyles()
end, "Alterna Invisibilidad total (.gm visible on/off)")

btnChat = MakeButton(content, "Chat", 118, 22, 126, -44, function()
    JainaGM_DB.states.chat = not JainaGM_DB.states.chat
    RunCmd(JainaGM_DB.states.chat and ".gm chat on" or ".gm chat off")
    UpdateToggleStyles()
end, "Alterna distintivo de GM en Chat (.gm chat on/off)")

-- ================================================================
-- CONTENEDORES DE LAS 5 PESTAÑAS
-- ================================================================
local tab1 = CreateFrame("Frame", "JainaGMTab1Content", content)
tab1:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -104)
tab1:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

local tab2 = CreateFrame("Frame", "JainaGMTab2Content", content)
tab2:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -104)
tab2:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

local tab3 = CreateFrame("Frame", "JainaGMTab3Content", content)
tab3:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -104)
tab3:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

local tab4 = CreateFrame("Frame", "JainaGMTab4Content", content)
tab4:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -104)
tab4:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

local tab5 = CreateFrame("Frame", "JainaGMTab5Content", content)
tab5:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -104)
tab5:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

-- ================================================================
-- NAVEGACIÓN Y SELECTOR DE PESTAÑAS (< y > SCROLL)
-- ================================================================
local function CreateTabButton(id, title)
    local btn = CreateFrame("Button", "JainaGMTabBtn" .. id, content)
    btn:SetID(id)
    btn:SetWidth(64); btn:SetHeight(25)
    btn.rawTitle = title

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetTexCoord(0, 114 / 128, 0, 25 / 32)
    btn.bg = bg

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("CENTER", btn, "CENTER", 0, -1)
    btn.text = txt

    return btn
end

local tabBtn1 = CreateTabButton(1, "GM & Tele")
local tabBtn2 = CreateTabButton(2, "Ítems")
local tabBtn3 = CreateTabButton(3, "Raidear")
local tabBtn4 = CreateTabButton(4, "WaniBOTS")
local tabBtn5 = CreateTabButton(5, "Mundo & GM")

local allTabs = { tabBtn1, tabBtn2, tabBtn3, tabBtn4, tabBtn5 }
local slotX = { 26, 92, 158 }
local tabOffset = 0
if JainaGM_DB.currentTab and JainaGM_DB.currentTab > 3 then
    tabOffset = JainaGM_DB.currentTab - 3
    if tabOffset > 2 then tabOffset = 2 end
end

local tabScrollLeft = CreateFrame("Button", "JainaGMTabScrollLeft", content, "UIPanelButtonTemplate")
tabScrollLeft:SetWidth(18); tabScrollLeft:SetHeight(25)
tabScrollLeft:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -70)
tabScrollLeft:SetText("<")
tabScrollLeft:RegisterForClicks("AnyUp")

local tabScrollRight = CreateFrame("Button", "JainaGMTabScrollRight", content, "UIPanelButtonTemplate")
tabScrollRight:SetWidth(18); tabScrollRight:SetHeight(25)
tabScrollRight:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -70)
tabScrollRight:SetText(">")
tabScrollRight:RegisterForClicks("AnyUp")

local function UpdateTabLayout()
    for id = 1, #allTabs do
        local slot = id - tabOffset
        local btn = allTabs[id]
        if slot >= 1 and slot <= 3 then
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", content, "TOPLEFT", slotX[slot], -70)
            btn:SetWidth(64); btn:SetHeight(25)
            btn:Show()
        else
            btn:Hide()
        end
    end
    tabScrollLeft:SetAlpha(tabOffset > 0 and 1.0 or 0.35)
    tabScrollRight:SetAlpha(tabOffset < (#allTabs - 3) and 1.0 or 0.35)
end

tabScrollLeft:SetScript("OnClick", function()
    if tabOffset > 0 then
        tabOffset = tabOffset - 1
        UpdateTabLayout()
    end
end)
tabScrollLeft:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Desplazar pestañas a la izquierda")
    GameTooltip:Show()
end)
tabScrollLeft:SetScript("OnLeave", function() GameTooltip:Hide() end)

tabScrollRight:SetScript("OnClick", function()
    if tabOffset < (#allTabs - 3) then
        tabOffset = tabOffset + 1
        UpdateTabLayout()
    end
end)
tabScrollRight:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Desplazar pestañas a la derecha")
    GameTooltip:Show()
end)
tabScrollRight:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function UpdateTabVisual(btn, isSelected)
    btn.isSelected = isSelected
    if isSelected then
        btn.bg:SetTexture(TEXTURE_DIR .. "tab_active.tga")
        btn.text:SetText("|cffffd100" .. btn.rawTitle .. "|r")
    else
        btn.bg:SetTexture(TEXTURE_DIR .. "tab_inactive.tga")
        btn.text:SetText("|cff888888" .. btn.rawTitle .. "|r")
    end
    btn.bg:SetTexCoord(0, 114 / 128, 0, 25 / 32)
end

local RefreshBotCheckboxes
local UpdateGuildOnlineCache
local function SelectTab(tabIndex)
    JainaGM_DB.currentTab = tabIndex
    tab1:Hide(); tab2:Hide(); tab3:Hide(); tab4:Hide(); tab5:Hide()
    for i, btn in ipairs(allTabs) do
        UpdateTabVisual(btn, i == tabIndex)
    end

    if tabIndex > (tabOffset + 3) then
        tabOffset = tabIndex - 3
        UpdateTabLayout()
    elseif tabIndex <= tabOffset then
        tabOffset = tabIndex - 1
        UpdateTabLayout()
    end

    if tabIndex == 1 then
        tab1:Show()
    elseif tabIndex == 2 then
        tab2:Show()
    elseif tabIndex == 3 then
        tab3:Show()
    elseif tabIndex == 4 then
        tab4:Show()
        if RefreshBotCheckboxes then RefreshBotCheckboxes() end
    elseif tabIndex == 5 then
        tab5:Show()
    end
end

for _, btn in ipairs(allTabs) do
    btn:SetScript("OnClick", function(self)
        SelectTab(self:GetID())
    end)
    btn:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self.bg:SetTexture(TEXTURE_DIR .. "tab_hover.tga")
            self.bg:SetTexCoord(0, 114 / 128, 0, 25 / 32)
            self.text:SetText("|cffcccccc" .. self.rawTitle .. "|r")
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.isSelected then
            self.bg:SetTexture(TEXTURE_DIR .. "tab_inactive.tga")
            self.bg:SetTexCoord(0, 114 / 128, 0, 25 / 32)
            self.text:SetText("|cff888888" .. self.rawTitle .. "|r")
        end
    end)
end

UpdateTabLayout()

-- ================================================================
-- PESTAÑA 1: GM, VELOCIDAD & TELETRANSPORTES
-- ================================================================
CreateSectionHeader(tab1, "Trade_Engineering", "UTILIDADES DE SUPERVIVENCIA", 0)

MakeButton(tab1, "Reparar", 76, 22, 6, -16, function()
    RunCmd(".repairitems")
end, "Repara todo tu equipamiento (.repairitems)")

MakeButton(tab1, "Reset CDs", 82, 22, 85, -16, function()
    RunCmd(".cooldown")
end, "Elimina tiempos de reutilización de hechizos (.cooldown)")

MakeButton(tab1, "Revivir", 76, 22, 170, -16, function()
    RunCmd(".revive")
end, "Revive y cura completamente al personaje (.revive)")

CreateSectionHeader(tab1, "Ability_Rogue_Sprint", "VELOCIDAD DE MOVIMIENTO", -42)

MakeButton(tab1, "1x", 76, 20, 6, -58, function() RunCmd(".modify speed 1") end, "Velocidad normal (1x)")
MakeButton(tab1, "2.5x", 82, 20, 85, -58, function() RunCmd(".modify speed 2.5") end, "Velocidad rápida (2.5x)")
MakeButton(tab1, "5x", 76, 20, 170, -58, function() RunCmd(".modify speed 5") end, "Velocidad hiper (5x)")
MakeButton(tab1, "10x (Ultra)", 118, 20, 6, -80, function() RunCmd(".modify speed 10") end, "Velocidad ultra rápida (10x)")
MakeButton(tab1, "20x (Flash)", 118, 20, 126, -80, function() RunCmd(".modify speed 20") end, "Velocidad máxima extrema (20x)")

CreateSectionHeader(tab1, "Spell_Arcane_PortalDalaran", "CONTROL DE OBJETIVO", -104)

MakeButton(tab1, "Ir al Objetivo", 118, 22, 6, -120, function()
    RunCmd(".appear")
end, "Te teletransporta hacia tu objetivo seleccionado (.appear)")

MakeButton(tab1, "Traer Objetivo", 118, 22, 126, -120, function()
    RunCmd(".summon")
end, "Trae a tu objetivo seleccionado hacia tu posición (.summon)")

CreateSectionHeader(tab1, "Spell_Arcane_TeleportDalaran", "TELETRANSPORTE RÁPIDO", -146)

local groupCheck = CreateFrame("CheckButton", "JainaGMGroupCheck", tab1, "UICheckButtonTemplate")
groupCheck:SetPoint("TOPLEFT", tab1, "TOPLEFT", 6, -162)
groupCheck:SetWidth(20); groupCheck:SetHeight(20)
local checkText = _G[groupCheck:GetName() .. "Text"]
if checkText then
    checkText:SetText("|cff00ffccTransportar con grupo / raid|r")
    checkText:SetFontObject("GameFontHighlightSmall")
end
groupCheck:SetChecked(JainaGM_DB.teleWithGroup == true)
groupCheck:SetScript("OnClick", function(self)
    JainaGM_DB.teleWithGroup = self:GetChecked() and true or false
end)

local mainTeleports = {
    { name = "Dalaran",    cmd = "dalaran" },
    { name = "ICC",        cmd = "icecrown" },
    { name = "Ventormenta",cmd = "stormwind" },
    { name = "Forjaz",     cmd = "ironforge" },
    { name = "Orgrimmar",  cmd = "orgrimmar" },
    { name = "Cima Trueno",cmd = "thunder" },
    { name = "Entrañas",   cmd = "undercity" },
    { name = "Sagr. Rubí", cmd = "ruby" }
}

local teleY = -186
for i, tele in ipairs(mainTeleports) do
    local col = ((i - 1) % 2)
    local row = math.floor((i - 1) / 2)
    local posX = 6 + (col * 120)
    local posY = teleY - (row * 22)
    MakeButton(tab1, tele.name, 118, 20, posX, posY, function()
        DoTeleport(tele.cmd)
    end, "Teletransporte a " .. tele.name .. (JainaGM_DB.teleWithGroup and " (con grupo)" or " (solo)"))
end

CreateSectionHeader(tab1, "INV_Misc_Map02", "PUNTOS PERSONALIZADOS & BALUARTES", -278)

local selectedCustomTele = nil
local dropdown = CreateFrame("Frame", "JainaGMTeleDropdown", tab1, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", tab1, "TOPLEFT", -10, -294)
UIDropDownMenu_SetWidth(dropdown, 150)

local function Dropdown_OnClick(self)
    selectedCustomTele = self.value
    UIDropDownMenu_SetSelectedValue(dropdown, self.value)
    UIDropDownMenu_SetText(dropdown, self.value)
end

local function Dropdown_Initialize(self, level)
    level = level or 1
    local list = JainaGM_DB.customTeles or {}
    for _, teleName in ipairs(list) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = teleName
        info.value = teleName
        info.checked = (selectedCustomTele == teleName)
        info.func = Dropdown_OnClick
        UIDropDownMenu_AddButton(info, level)
    end
end

local function RefreshDropdown()
    UIDropDownMenu_Initialize(dropdown, Dropdown_Initialize)
    if selectedCustomTele and selectedCustomTele ~= "" then
        UIDropDownMenu_SetSelectedValue(dropdown, selectedCustomTele)
        UIDropDownMenu_SetText(dropdown, selectedCustomTele)
    else
        local first = JainaGM_DB.customTeles and JainaGM_DB.customTeles[1]
        if first then
            selectedCustomTele = first
            UIDropDownMenu_SetSelectedValue(dropdown, first)
            UIDropDownMenu_SetText(dropdown, first)
        else
            UIDropDownMenu_SetText(dropdown, "Elegir destino...")
        end
    end
end

dropdown:EnableMouse(true)
dropdown:SetScript("OnMouseDown", function()
    ToggleDropDownMenu(1, nil, dropdown)
end)

MakeButton(tab1, "IR", 62, 24, 180, -294, function()
    if selectedCustomTele and selectedCustomTele ~= "" then
        DoTeleport(selectedCustomTele)
    else
        Msg("Selecciona un destino del menú primero.")
    end
end, "Teletransportarse al punto seleccionado (con o sin grupo)")

local editBox = CreateFrame("EditBox", "JainaGMEditTele", tab1, "InputBoxTemplate")
editBox:SetWidth(110); editBox:SetHeight(20)
editBox:SetPoint("TOPLEFT", tab1, "TOPLEFT", 12, -330)
editBox:SetAutoFocus(false)
editBox:SetFontObject("GameFontHighlightSmall")
editBox:SetText("")

local editHint = tab1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
editHint:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 2)
editHint:SetText("Nombre del punto:")

local function AddCustomPoint(name, notify)
    if not name or name == "" then return end
    name = string.lower(strtrim(name))
    if name == "" then return end
    if type(JainaGM_DB.customTeles) ~= "table" then JainaGM_DB.customTeles = {} end
    local exists = false
    for _, t in ipairs(JainaGM_DB.customTeles) do
        if t == name then exists = true break end
    end
    if not exists then
        table.insert(JainaGM_DB.customTeles, name)
        table.sort(JainaGM_DB.customTeles)
    end
    selectedCustomTele = name
    RefreshDropdown()
    if notify then
        Msg("Punto añadido al menú: |cffffd100" .. name .. "|r")
    end
end

MakeButton(tab1, "Guardar", 58, 20, 126, -330, function()
    local text = strtrim(editBox:GetText())
    if text ~= "" then
        RunCmd(".tele add " .. text)
        AddCustomPoint(text, true)
        editBox:SetText("")
        editBox:ClearFocus()
    else
        Msg("Escribe el nombre del punto a guardar.")
    end
end, "Guarda tu posición actual en el servidor y la añade a la lista (.tele add)")

MakeButton(tab1, "Borrar", 54, 20, 188, -330, function()
    if selectedCustomTele and selectedCustomTele ~= "" then
        local toRemove = selectedCustomTele
        RunCmd(".tele del " .. toRemove)
        for i, t in ipairs(JainaGM_DB.customTeles) do
            if t == toRemove then
                table.remove(JainaGM_DB.customTeles, i)
                break
            end
        end
        selectedCustomTele = JainaGM_DB.customTeles[1] or ""
        RefreshDropdown()
        Msg("Punto eliminado del servidor: |cffff4444" .. toRemove .. "|r")
    end
end, "Elimina el punto seleccionado de la lista y del servidor (.tele del)")

-- ================================================================
-- PESTAÑA 2: BUSCADOR DE OBJETOS & PROGRESIÓN (9,299 ITEMS)
-- ================================================================
CreateSectionHeader(tab2, "INV_Misc_Bag_08", "BUSCADOR DE OBJETOS", 0)

local DoSearch
local searchBox = CreateFrame("EditBox", "JainaGMSearchBox", tab2, "InputBoxTemplate")
searchBox:SetWidth(130); searchBox:SetHeight(20)
searchBox:SetPoint("TOPLEFT", tab2, "TOPLEFT", 10, -20)
searchBox:SetAutoFocus(false)
searchBox:SetFontObject("GameFontHighlightSmall")
searchBox:SetText("")

local searchBtn = MakeButton(tab2, "Buscar", 52, 22, 146, -19, function()
    if DoSearch then DoSearch() end
end, "Busca el objeto por nombre o ID")

searchBox:SetScript("OnEnterPressed", function()
    if DoSearch then DoSearch() end
end)

local qtyBox = CreateFrame("EditBox", "JainaGMQtyBox", tab2, "InputBoxTemplate")
qtyBox:SetWidth(28); qtyBox:SetHeight(20)
qtyBox:SetPoint("LEFT", searchBtn, "RIGHT", 10, 0)
qtyBox:SetAutoFocus(false)
qtyBox:SetFontObject("GameFontHighlightSmall")
qtyBox:SetNumeric(true); qtyBox:SetMaxLetters(3)
qtyBox:SetText("1")

local qtyLabel = tab2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
qtyLabel:SetPoint("BOTTOM", qtyBox, "TOP", 0, 2)
qtyLabel:SetText("|cffffd100Cant:|r")

local itemResults = {}

local function Normalize(s)
    if not s then return "" end
    s = string.lower(s)
    local reps = {
        ["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u",
        ["Á"]="a", ["É"]="e", ["Í"]="i", ["Ó"]="o", ["Ú"]="u"
    }
    for k, v in pairs(reps) do
        s = string.gsub(s, k, v)
    end
    return s
end

local TRANSLATIONS = {
    ["escarcha"] = "frost",       ["triunfo"] = "triumph",
    ["conquista"] = "conquest",   ["valor"] = "valor",
    ["heroico"] = "heroic",       ["heroica"] = "heroic",
    ["agonia"] = "shadowmourne",  ["filacteria"] = "phylactery",
    ["testamento"] = "deathbringer", ["glorenzelg"] = "glorenzelg",
    ["abaco"] = "abacus",         ["colmillo"] = "fang",
    ["rubi"] = "ruby",            ["ambar"] = "amber",
    ["circonia"] = "zircon",      ["ametrino"] = "ametrino",
    ["diamante"] = "diamond",     ["pocion"] = "potion",
    ["frasco"] = "flask",         ["festin"] = "feast",
    ["bolsa"] = "bag",            ["tela"] = "cloth",
    ["panno"] = "cloth",          ["saronita"] = "saronite",
    ["titanio"] = "titanium"
}

-- Filtro silencioso para .lookup item
local isListeningLookup = false
local function LookupChatFilter(self, event, msg, ...)
    if not isListeningLookup then return false end
    local id, name = strmatch(msg, "(%d+)%s*[-:]%s*(.+)")
    if not id then
        id = strmatch(msg, "item:(%d+)")
        name = msg
    end
    if not id then
        id, name = strmatch(msg, "[Ii]tem%s*(%d+)%s*:%s*(.+)")
    end

    if id then
        local numId = tonumber(id)
        if numId and numId > 0 then
            local cleanName = strmatch(name, "%[([^%]]+)%]") or name
            cleanName = strtrim(cleanName)
            local exists = false
            for _, res in ipairs(itemResults) do
                if res.id == numId then exists = true break end
            end
            if not exists then
                local realName, _, rarity, _, _, iType = GetItemInfo(numId)
                if iType and (iType == "Misión" or iType == "Quest" or iType == "Receta" or iType == "Recipe") then
                    return true
                end
                local cat = "gear"
                if iType == "Gema" or iType == "Gem" then cat = "gem"
                elseif iType == "Consumible" or iType == "Consumable" then cat = "cons"
                elseif iType == "Recipiente" or iType == "Container" or iType == "Bolsa" then cat = "bag"
                elseif iType == "Miscelánea" or iType == "Miscellaneous" or iType == "Moneda" then cat = "badge"
                end
                table.insert(itemResults, {
                    id = numId,
                    name = realName or cleanName,
                    rarity = rarity or 4,
                    cat = cat
                })
            end
            return true
        end
    end
    if strmatch(msg, "Items found") or strmatch(msg, "No items found") or strmatch(msg, "lookup item") then
        return true
    end
    return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", LookupChatFilter)

-- ScrollFrame de Resultados de Items (alto 260 para dejar espacio a progresión abajo)
local scrollFrame = CreateFrame("ScrollFrame", "JainaGMItemScroll", tab2, "FauxScrollFrameTemplate")
scrollFrame:SetWidth(214); scrollFrame:SetHeight(260)
scrollFrame:SetPoint("TOPLEFT", tab2, "TOPLEFT", 6, -50)

local scrollBar = _G["JainaGMItemScrollScrollBar"]
if scrollBar then
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 1, -16)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 16)
    scrollBar:SetFrameLevel(50)
end

local emptyHint = tab2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
emptyHint:SetPoint("TOP", scrollFrame, "TOP", 0, -20)
emptyHint:SetWidth(214); emptyHint:SetJustifyH("CENTER")
local HINT_DEFAULT_TEXT = "|cffffd100¿Cómo buscar y equipar?|r\n\n" ..
    "|cffffffff1.|r Escribe el nombre del objeto o ID.\n" ..
    "|cffffffff2.|r Pulsa |cffffd100Buscar|r o tecla |cffffd100Enter|r.\n" ..
    "|cffffffff3.|r Pulsa |cff00ff00[+]|r para meterlo a tus bolsas.\n\n" ..
    "|cff888888• Clic normal: Ficha oficial\n" ..
    "• Shift + Clic: Pega enlace en chat\n" ..
    "• Ctrl + Clic: Abre el probador 3D|r"
emptyHint:SetText(HINT_DEFAULT_TEXT)

local ITEM_ROW_HEIGHT = 32
local MAX_ROWS = 8
local itemButtons = {}

local function UpdateScrollList()
    local total = #itemResults
    FauxScrollFrame_Update(scrollFrame, total, MAX_ROWS, ITEM_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    if total == 0 then
        emptyHint:Show()
    else
        emptyHint:Hide()
    end

    for i = 1, MAX_ROWS do
        local btn = itemButtons[i]
        local idx = offset + i
        if idx <= total then
            local data = itemResults[idx]
            local id = data.id
            btn.itemId = id

            local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(id)
            btn.itemLink = link

            if texture then
                btn.icon:SetTexture(texture)
            else
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            local q = quality or data.rarity or 4
            local r, g, b = GetItemQualityColor(q)
            local displayName = name or data.name or ("Item " .. id)
            btn.nameText:SetText(displayName)
            btn.nameText:SetTextColor(r, g, b)
            btn.idText:SetText("ID: " .. id)
            btn:Show()
        else
            btn:Hide()
        end
    end
end

scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ITEM_ROW_HEIGHT, UpdateScrollList)
end)

scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local sb = _G["JainaGMItemScrollScrollBar"]
    if sb and sb:IsShown() then
        local minVal, maxVal = sb:GetMinMaxValues()
        if maxVal > minVal then
            local newVal = sb:GetValue() - (delta * ITEM_ROW_HEIGHT * 2)
            if newVal < minVal then newVal = minVal end
            if newVal > maxVal then newVal = maxVal end
            sb:SetValue(newVal)
        end
    end
end)

for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", "JainaGMItemRow" .. i, tab2)
    row:SetWidth(214); row:SetHeight(ITEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", tab2, "TOPLEFT", 6, -50 - ((i - 1) * ITEM_ROW_HEIGHT))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:Hide()

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(26); icon:SetHeight(26)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    row.icon = icon

    local border = row:CreateTexture(nil, "OVERLAY")
    border:SetWidth(28); border:SetHeight(28)
    border:SetPoint("CENTER", icon, "CENTER", 0, 0)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD"); border:SetAlpha(0.6)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -1)
    nameText:SetPoint("RIGHT", row, "RIGHT", -32, 0)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    local idText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    idText:SetPoint("BOTTOMLEFT", icon, "TOPRIGHT", 6, 2)
    row.idText = idText

    local addBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    addBtn:SetWidth(26); addBtn:SetHeight(22)
    addBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    addBtn:SetText("+")
    addBtn:RegisterForClicks("AnyUp")
    addBtn:SetScript("OnClick", function()
        local id = row.itemId
        if id and id > 0 then
            local count = tonumber(qtyBox:GetText()) or 1
            if count < 1 then count = 1 end
            RunCmd(".additem " .. id .. " " .. count)
            qtyBox:SetText("1")
            Msg("Añadido al inventario: " .. (row.itemLink or ("ID " .. id)) .. " x" .. count)
        end
    end)
    addBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local count = tonumber(qtyBox:GetText()) or 1
        GameTooltip:SetText("|cff00ff00[+ Añadir al Inventario]|r\nAñade " .. count .. " ud(s) directamente.")
        GameTooltip:Show()
    end)
    addBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row:SetScript("OnEnter", function(self)
        if self.itemId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemId)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row:SetScript("OnClick", function(self, button)
        if not self.itemId then return end
        local link = self.itemLink or ("item:" .. self.itemId)
        if IsShiftKeyDown() then
            if ChatFrameEditBox and ChatFrameEditBox:IsShown() then
                ChatFrameEditBox:Insert(link)
            else
                ChatEdit_InsertLink(link)
            end
        elseif IsControlKeyDown() then
            DressUpItemLink(link)
        else
            SetItemRef("item:" .. self.itemId, link, button)
        end
    end)

    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        local sf = _G["JainaGMItemScroll"]
        if sf and sf:GetScript("OnMouseWheel") then
            sf:GetScript("OnMouseWheel")(sf, delta)
        end
    end)

    itemButtons[i] = row
end

tab2:SetScript("OnShow", function()
    UpdateScrollList()
end)

DoSearch = function()
    local rawText = searchBox:GetText() or ""
    local text = strtrim(rawText)
    qtyBox:SetText("1")
    searchBox:ClearFocus()
    itemResults = {}

    if text == "" then
        UpdateScrollList()
        return
    end

    local queryNorm = Normalize(text)
    local transWord = TRANSLATIONS[queryNorm]

    -- 1. Búsqueda en catálogo local de 9,299 items
    local catalog = JainaGM_Catalog or WaniGM_Catalog or {}
    for _, item in ipairs(catalog) do
        local id = item[1] or item.id
        local name = item[2] or item.name
        local rarity = item[3] or item.rarity
        local cat = item[4] or item.cat

        local nameNorm = Normalize(name)
        local match = false
        if tostring(id) == text then
            match = true
        elseif string.find(nameNorm, queryNorm, 1, true) then
            match = true
        elseif transWord and string.find(nameNorm, transWord, 1, true) then
            match = true
        end

        if match then
            table.insert(itemResults, {
                id = id,
                name = name,
                rarity = rarity,
                cat = cat
            })
        end
    end

    -- 2. Si se buscó un ID numérico exacto no presente en catálogo local
    local numQuery = tonumber(text)
    if #itemResults == 0 and numQuery and numQuery > 0 then
        local name, _, rarity, _, _, iType = GetItemInfo(numQuery)
        local cat = "gear"
        if iType == "Gema" or iType == "Gem" then cat = "gem"
        elseif iType == "Consumible" or iType == "Consumable" then cat = "cons"
        elseif iType == "Recipiente" or iType == "Container" or iType == "Bolsa" then cat = "bag"
        end
        table.insert(itemResults, {
            id = numQuery,
            name = name or ("Item " .. numQuery),
            rarity = rarity or 4,
            cat = cat
        })
    end

    -- 3. Si no hay resultados locales y no es puramente numérico, consultar al servidor (.lookup item)
    if #itemResults == 0 and not numQuery then
        isListeningLookup = true
        local queryWord = transWord or text
        RunCmd(".lookup item " .. queryWord)
        C_Timer = C_Timer or {}
        local tFrame = CreateFrame("Frame")
        local tElapsed = 0
        tFrame:SetScript("OnUpdate", function(self, el)
            tElapsed = tElapsed + el
            if tElapsed > 1.2 then
                isListeningLookup = false
                UpdateScrollList()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    UpdateScrollList()
end

-- SECCIÓN INFERIOR PROGRESIÓN Y MONEDAS EN TAB 2
CreateSectionHeader(tab2, "Trade_Alchemy", "PROGRESIÓN Y MONEDAS RÁPIDAS", -316)

MakeButton(tab2, "Max Dinero", 118, 22, 6, -332, function()
    RunCmd(".modify money 2147483647")
    Msg("Dinero establecido al máximo.")
end, "Establece tu dinero al máximo oro permitido (.modify money)")

MakeButton(tab2, "Buzón GM", 118, 22, 126, -332, function()
    RunCmd(".misc mailbox")
end, "Abre un buzón de correo portátil en cualquier lugar (.misc mailbox)")

MakeButton(tab2, "Nivel 80", 118, 22, 6, -356, function()
    ShowConfirm("Subir al Nivel 80", "¿Estás seguro de subir inmediatamente al nivel 80 de WotLK?", function()
        RunCmd(".character level 80")
        Msg("Personaje subido a nivel 80.")
    end)
end, "Sube al personaje al nivel 80 (Requiere confirmación)")

MakeButton(tab2, "XP Toggle", 118, 22, 126, -356, function()
    RunCmd(".xp toggle")
end, "Activa o desactiva la ganancia de experiencia (.xp toggle)")

MakeButton(tab2, "Reset Stats", 118, 22, 6, -380, function()
    RunCmd(".reset stats")
end, "Recalcula y restablece las estadísticas base (.reset stats)")

MakeButton(tab2, "Reset Hechizos", 118, 22, 126, -380, function()
    RunCmd(".reset spells")
    Msg("Hechizos restablecidos y reaprendidos.")
end, "Reaprende todos los hechizos de tu clase (.reset spells)")

MakeButton(tab2, "Reset Talentos", 238, 22, 6, -404, function()
    ShowConfirm("Reset de Talentos", "¿Deseas restablecer todos los puntos de talentos de tu personaje?", function()
        RunCmd(".reset talents")
        Msg("Talentos restablecidos.")
    end)
end, "Restablece el árbol de talentos (Requiere confirmación)")

-- ================================================================
-- PESTAÑA 3: ASISTENCIA Y CONTROL DE BANDAS (RAIDEAR)
-- ================================================================
CreateSectionHeader(tab3, "Achievement_Dungeon_Icecrown_IcecrownCitadel", "DESBLOQUEO DE CIUDADELA CORONA DE HIELO", 0)

MakeButton(tab3, "Abrir Alas ICC", 118, 22, 6, -18, function()
    RunCmd(".gobject activate 150360")
    RunCmd(".gobject activate 150334")
    RunCmd(".gobject activate 150345")
    RunCmd(".gobject activate 150319")
    RunCmd(".gobject activate 150320")
    RunCmd(".gobject activate 150349")
    RunCmd(".gobject activate 150333")
    RunCmd(".gobject activate 150363")
    for b = 0, 13 do
        RunCmd(".instance setbossstate " .. b .. " 3")
    end
    Msg("¡Todas las puertas y alas de ICC han sido abiertas y bosses desbloqueados!")
end, "Abre todas las puertas de ICC y permite el acceso libre a cada ala")

MakeButton(tab3, "Abrir Lich King", 118, 22, 126, -18, function()
    RunCmd(".gobject activate 150363")
    RunCmd(".instance setbossstate 13 3")
    RunCmd(".respawn creature entry 36678")
    RunCmd(".reload creature_template 36678")
    Msg("¡Portal del Trono Helado y Rey Exánime activados!")
end, "Abre el portal al Trono Helado y fuerza el respawn del Rey Exánime")

MakeButton(tab3, "Desbloq. Putricidio", 118, 20, 6, -44, function()
    RunCmd(".gobject activate 150334")
    RunCmd(".gobject activate 150345")
    RunCmd(".instance setbossstate 4 3")
    RunCmd(".instance setbossstate 5 3")
    RunCmd(".instance setbossstate 6 3")
    Msg("¡Taller de la Peste y Profesor Putricidio desbloqueados!")
end, "Abre las puertas de la Peste y activa a Putricidio")

MakeButton(tab3, "Desbloq. Reina", 118, 20, 126, -44, function()
    RunCmd(".gobject activate 150319")
    RunCmd(".gobject activate 150320")
    RunCmd(".instance setbossstate 7 3")
    RunCmd(".instance setbossstate 8 3")
    RunCmd(".instance setbossstate 9 3")
    Msg("¡Sala Carmesí y Reina de Sangre Lana'thel desbloqueadas!")
end, "Abre las puertas de la Sala Carmesí y activa a Lana'thel")

MakeButton(tab3, "Desbloq. Sindragosa", 118, 20, 6, -68, function()
    RunCmd(".gobject activate 150349")
    RunCmd(".gobject activate 150333")
    RunCmd(".instance setbossstate 10 3")
    RunCmd(".instance setbossstate 11 3")
    Msg("¡Cámaras de Escarcha y Sindragosa desbloqueadas!")
end, "Abre las puertas de Escarcha y activa a Sindragosa")

MakeButton(tab3, "Teleport Profesor", 118, 20, 126, -68, function()
    RunCmd(".tele profesor")
end, "Te teletransporta directamente al laboratorio de Putricidio")

CreateSectionHeader(tab3, "Spell_Holy_Renew", "RESETEO DE ESTANCIAS", -94)

local unbindBtn = MakeButton(tab3, "Resetear Bloqueos de Mazmorra", 238, 24, 6, -112, function()
    RunCmd(".instance unbind all")
    Msg("¡Todos los registros y bloqueos de mazmorra han sido reseteados!")
end, "Elimina tus registros y bloqueos activos de todas las instancias (.instance unbind all)")

CreateSectionHeader(tab3, "Spell_Holy_PrayerOfFortitude", "MODO INMORTAL (PRÁCTICA)", -140)

local immortalRaidCheck = CreateFrame("CheckButton", "JainaGMImmortalRaidCheck", tab3, "UICheckButtonTemplate")
immortalRaidCheck:SetPoint("TOPLEFT", tab3, "TOPLEFT", 6, -158)
immortalRaidCheck:SetWidth(20); immortalRaidCheck:SetHeight(20)
local ircText = _G[immortalRaidCheck:GetName() .. "Text"]
if ircText then
    ircText:SetText("|cffffd100Aplicar a toda la Banda / Grupo|r")
    ircText:SetFontObject("GameFontHighlightSmall")
end
immortalRaidCheck:SetChecked(JainaGM_DB.immortalAllRaid == true)
immortalRaidCheck:SetScript("OnClick", function(self)
    JainaGM_DB.immortalAllRaid = self:GetChecked() and true or false
end)

local btnImmortal
local function UpdateImmortalButton()
    if JainaGM_DB.immortalActive then
        btnImmortal:SetText("|cff00ff00Inmortalidad: ACTIVA|r")
    else
        btnImmortal:SetText("|cffff4444Inmortalidad: DESACTIVADA|r")
    end
end

btnImmortal = MakeButton(tab3, "Inmortalidad", 238, 24, 6, -182, function()
    JainaGM_DB.immortalActive = not JainaGM_DB.immortalActive
    UpdateImmortalButton()
    if JainaGM_DB.immortalActive then
        Msg("Modo Inmortal |cff00ff00ACTIVADO|r. Se revivirá instantáneamente a los caídos.")
    else
        Msg("Modo Inmortal |cffff4444DESACTIVADO|r.")
    end
end, "Revive automáticamente al jugador o a la banda entera al morir")

local immortalWorker = CreateFrame("Frame")
local lastReviveTimes = {}
immortalWorker:SetScript("OnUpdate", function(self, elapsed)
    if not JainaGM_DB.immortalActive then return end
    local now = GetTime()

    if UnitIsDeadOrGhost("player") then
        if not lastReviveTimes["player"] or (now - lastReviveTimes["player"]) > 2.0 then
            lastReviveTimes["player"] = now
            RunCmd(".revive")
            if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
                RunCmd(".group revive")
            end
        end
    end

    if not JainaGM_DB.immortalAllRaid then return end

    local rCount = GetNumRaidMembers()
    local hasDead = false
    if rCount > 0 then
        for i = 1, rCount do
            if UnitIsDeadOrGhost("raid" .. i) then
                hasDead = true
                break
            end
        end
    else
        local pCount = GetNumPartyMembers()
        if pCount > 0 then
            for i = 1, pCount do
                if UnitIsDeadOrGhost("party" .. i) then
                    hasDead = true
                    break
                end
            end
        end
    end

    if hasDead then
        if not lastReviveTimes["group"] or (now - lastReviveTimes["group"]) > 2.0 then
            lastReviveTimes["group"] = now
            RunCmd(".group revive")
        end
    end
end)

CreateSectionHeader(tab3, "Ability_Creature_Cursed_03", "CONTROL DE COMBATE & WIPE", -214)

MakeButton(tab3, "Reset Boss / Wipe", 118, 24, 6, -232, function()
    RunCmd(".die")
    RunCmd(".group revive")
    RunCmd(".revive")
    RunCmd(".cooldown")
    Msg("¡Boss reseteado, banda revivida y CDs listos!")
end, "Mata al objetivo actual (.die), revive a todos (.group revive) y resetea CDs (.cooldown)")

MakeButton(tab3, "Revivir Banda", 118, 24, 126, -232, function()
    RunCmd(".group revive")
    RunCmd(".revive")
    RunCmd(".cooldown")
    Msg("¡Banda revivida (.group revive) y facultades listas!")
end, "Revive a todos los miembros de la banda y retira tiempos de reutilización (.group revive)")

local function SendBotRaidMsg(msg)
    local chatType = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
        SendChatMessage(msg, chatType)
    else
        Msg("No estás en grupo o banda.")
    end
end

MakeButton(tab3, "Pausar Bots", 118, 22, 6, -260, function()
    SendBotRaidMsg("pause")
    Msg("Orden enviada a la banda: |cffff4444pause|r (Bots detenidos)")
end, "Envía la orden 'pause' por chat de banda para detener a los bots")

MakeButton(tab3, "Reanudar Bots", 118, 22, 126, -260, function()
    SendBotRaidMsg("resume")
    Msg("Orden enviada a la banda: |cff00ff00resume|r (Bots reanudados)")
end, "Envía la orden 'resume' por chat de banda para reanudar el combate de los bots")

MakeButton(tab3, "Reset CDs", 118, 22, 6, -286, function()
    RunCmd(".cooldown")
end, "Elimina los tiempos de reutilización de hechizos (.cooldown)")

MakeButton(tab3, "Reparar Todo", 118, 22, 126, -286, function()
    RunCmd(".repairitems")
end, "Repara todo el equipamiento (.repairitems)")

-- ================================================================
-- PESTAÑA 4: GESTIÓN DE BOTS (30 BOTS POR ROL)
-- ================================================================
CreateSectionHeader(tab4, "Achievement_Reputation_01", "GESTIÓN DE WANIBOTS (30 ROLES)", 0)

local WANIBOTS_ROSTER = {
    {
        title = "TANQUES (4)",
        icon = "Ability_Defend",
        bots = {
            { name = "Zapalatan", class = "PALADIN", className = "Paladín", roleName = "Tanque", color = "f58cba" },
            { name = "Zbdktan", class = "DEATHKNIGHT", className = "Caballero Muerte", roleName = "Tanque", color = "c41f3b" },
            { name = "Zzdruitan", class = "DRUID", className = "Druida", roleName = "Tanque", color = "ff7d0a" },
            { name = "Zzguertan", class = "WARRIOR", className = "Guerrero", roleName = "Tanque", color = "c79c6e" },
        }
    },
    {
        title = "SANADORES (6)",
        icon = "Spell_Holy_FlashHeal",
        bots = {
            { name = "Zcpalasan", class = "PALADIN", className = "Paladín", roleName = "Sanador", color = "f58cba" },
            { name = "Zdsacesan", class = "PRIEST", className = "Sacerdote", roleName = "Sanador", color = "ffffff" },
            { name = "Zkchamsan", class = "SHAMAN", className = "Chamán", roleName = "Sanador", color = "0070de" },
            { name = "Zldruisan", class = "DRUID", className = "Druida", roleName = "Sanador", color = "ff7d0a" },
            { name = "Zssacesan", class = "PRIEST", className = "Sacerdote", roleName = "Sanador", color = "ffffff" },
            { name = "Zypalsan", class = "PALADIN", className = "Paladín", roleName = "Sanador", color = "f58cba" },
        }
    },
    {
        title = "ATACANTES / DPS (20)",
        icon = "Ability_DualWield",
        bots = {
            { name = "Zebrujdps", class = "WARLOCK", className = "Brujo", roleName = "DPS", color = "9482c9" },
            { name = "Zfdruidps", class = "DRUID", className = "Druida", roleName = "DPS", color = "ff7d0a" },
            { name = "Zgchamdps", class = "SHAMAN", className = "Chamán", roleName = "DPS", color = "0070de" },
            { name = "Zhcazadps", class = "HUNTER", className = "Cazador", roleName = "DPS", color = "abd473" },
            { name = "Zipicadps", class = "ROGUE", className = "Pícaro", roleName = "DPS", color = "fff569" },
            { name = "Zjpaladps", class = "PALADIN", className = "Paladín", roleName = "DPS", color = "f58cba" },
            { name = "Zmmagodps", class = "MAGE", className = "Mago", roleName = "DPS", color = "69ccf0" },
            { name = "Znsacedps", class = "PRIEST", className = "Sacerdote", roleName = "DPS", color = "ffffff" },
            { name = "Zodkdps", class = "DEATHKNIGHT", className = "Caballero Muerte", roleName = "DPS", color = "c41f3b" },
            { name = "Zpbrujdps", class = "WARLOCK", className = "Brujo", roleName = "DPS", color = "9482c9" },
            { name = "Zqguerdps", class = "WARRIOR", className = "Guerrero", roleName = "DPS", color = "c79c6e" },
            { name = "Zrcazadps", class = "HUNTER", className = "Cazador", roleName = "DPS", color = "abd473" },
            { name = "Ztpicadps", class = "ROGUE", className = "Pícaro", roleName = "DPS", color = "fff569" },
            { name = "Zumagodps", class = "MAGE", className = "Mago", roleName = "DPS", color = "69ccf0" },
            { name = "Zvchamdps", class = "SHAMAN", className = "Chamán", roleName = "DPS", color = "0070de" },
            { name = "Zwdkdps", class = "DEATHKNIGHT", className = "Caballero Muerte", roleName = "DPS", color = "c41f3b" },
            { name = "Zxguerdps", class = "WARRIOR", className = "Guerrero", roleName = "DPS", color = "c79c6e" },
            { name = "Zzchamdps", class = "SHAMAN", className = "Chamán", roleName = "DPS", color = "0070de" },
            { name = "Zzdruidps", class = "DRUID", className = "Druida", roleName = "DPS", color = "ff7d0a" },
            { name = "Zzpicadps", class = "ROGUE", className = "Pícaro", roleName = "DPS", color = "fff569" },
        }
    }
}

local function IsBotInGroup(name)
    local rCount = GetNumRaidMembers()
    if rCount > 0 then
        for i = 1, rCount do
            if UnitName("raid" .. i) == name then return true end
        end
        return false
    end
    local pCount = GetNumPartyMembers()
    if pCount > 0 then
        for i = 1, pCount do
            if UnitName("party" .. i) == name then return true end
        end
    end
    return false
end

local guildOnlineBots = {}
UpdateGuildOnlineCache = function()
    guildOnlineBots = {}
    if not IsInGuild() then return end
    local num = GetNumGuildMembers()
    for i = 1, num do
        local gName, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if online and gName then
            guildOnlineBots[gName] = true
        end
    end
end

local function IsBotBusyWithOther(name)
    if IsBotInGroup(name) then return false end
    return guildOnlineBots[name] == true
end

local pendingBots = {}
local botPollElapsed = 0

MakeButton(tab4, "+ Todos", 76, 22, 6, -18, function()
    RunCmd("/script ConvertToRaid()")
    local batch = {}
    for _, grp in ipairs(WANIBOTS_ROSTER) do
        for _, b in ipairs(grp.bots) do
            if not IsBotBusyWithOther(b.name) then
                table.insert(batch, b.name)
                pendingBots[b.name] = true
                if #batch == 10 then
                    RunCmd(".playerbots bot add " .. table.concat(batch, ","))
                    batch = {}
                end
            end
        end
    end
    if #batch > 0 then
        RunCmd(".playerbots bot add " .. table.concat(batch, ","))
    end
    for _, grp in ipairs(WANIBOTS_ROSTER) do
        for _, b in ipairs(grp.bots) do
            if not IsBotBusyWithOther(b.name) then
                RunCmd("/invite " .. b.name)
                RunCmd(".summon " .. b.name)
                RunCmd("/w " .. b.name .. " follow")
            end
        end
    end
    if RefreshBotCheckboxes then RefreshBotCheckboxes() end
    Msg("Convocando e invitando a todos los bots disponibles a la banda...")
end, "Invita e invoca a todos los bots disponibles convirtiendo el grupo a Banda")

MakeButton(tab4, "Invocar Aquí", 78, 22, 85, -18, function()
    local summoned = 0
    for _, grp in ipairs(WANIBOTS_ROSTER) do
        for _, b in ipairs(grp.bots) do
            if IsBotInGroup(b.name) then
                RunCmd(".summon " .. b.name)
                RunCmd("/w " .. b.name .. " follow")
                summoned = summoned + 1
            end
        end
    end
    if summoned > 0 then
        Msg("Reuniendo a " .. summoned .. " bots en tu posición actual.")
    else
        Msg("No hay bots en tu grupo/banda para invocar.")
    end
end, "Teletransporta a todos los bots de tu grupo actual a tu posición (.summon)")

MakeButton(tab4, "- Despedir", 76, 22, 166, -18, function()
    local botsToDismiss = {}
    for _, grp in ipairs(WANIBOTS_ROSTER) do
        for _, b in ipairs(grp.bots) do
            if IsBotInGroup(b.name) or pendingBots[b.name] == true then
                pendingBots[b.name] = false
                table.insert(botsToDismiss, b.name)
            end
        end
    end
    if #botsToDismiss == 0 then
        RunCmd("/script LeaveParty()")
        Msg("No tienes bots activos en tu grupo.")
        if RefreshBotCheckboxes then RefreshBotCheckboxes() end
        return
    end
    local batch = {}
    for i, name in ipairs(botsToDismiss) do
        table.insert(batch, name)
        if #batch == 10 or i == #botsToDismiss then
            RunCmd(".playerbots bot remove " .. table.concat(batch, ","))
            batch = {}
        end
    end
    for _, name in ipairs(botsToDismiss) do
        RunCmd(".kick " .. name)
    end
    RunCmd("/script LeaveParty()")
    if RefreshBotCheckboxes then RefreshBotCheckboxes() end
    Msg("Despidiendo " .. #botsToDismiss .. " bots de tu grupo...")
end, "Desloguea y retira a los bots de tu grupo sin afectar a otros compañeros")

local botScroll = CreateFrame("ScrollFrame", "JainaGMBotScrollFrame", tab4, "UIPanelScrollFrameTemplate")
botScroll:SetPoint("TOPLEFT", tab4, "TOPLEFT", 6, -44)
botScroll:SetPoint("BOTTOMRIGHT", tab4, "BOTTOMRIGHT", -26, 6)

local botChild = CreateFrame("Frame", "JainaGMBotScrollChild", botScroll)
botChild:SetWidth(214); botChild:SetHeight(520)
botScroll:SetScrollChild(botChild)

botScroll:EnableMouseWheel(true)
botScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = JainaGMBotScrollFrameScrollBar:GetValue()
    JainaGMBotScrollFrameScrollBar:SetValue(cur - (delta * 24))
end)

local botCheckboxes = {}
local curY = -2

for _, group in ipairs(WANIBOTS_ROSTER) do
    local headerText = botChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerText:SetPoint("TOPLEFT", botChild, "TOPLEFT", 4, curY)
    headerText:SetText("|TInterface\\Icons\\" .. group.icon .. ":13:13:0:0|t |cffffd100" .. group.title .. "|r")
    curY = curY - 18

    for i, bot in ipairs(group.bots) do
        local col = (i - 1) % 2
        local posX = col == 0 and 2 or 108
        local rowY = curY - (math.floor((i - 1) / 2) * 20)

        local cb = CreateFrame("CheckButton", "JainaGMBotCheck_" .. bot.name, botChild, "UICheckButtonTemplate")
        cb:SetWidth(18); cb:SetHeight(18)
        cb:SetPoint("TOPLEFT", botChild, "TOPLEFT", posX, rowY)
        cb.bot = bot

        local lbl = _G[cb:GetName() .. "Text"]
        if lbl then
            lbl:SetText("|cff" .. bot.color .. bot.name .. "|r")
            lbl:SetFontObject("GameFontHighlightSmall")
        end

        cb:SetScript("OnClick", function(self)
            local isBusy = IsBotBusyWithOther(bot.name)
            if isBusy then
                self:SetChecked(false)
                Msg("El bot |cffffd100" .. bot.name .. "|r ya está en uso por otro compañero.")
                return
            end

            local isChecked = self:GetChecked() and true or false
            pendingBots[bot.name] = isChecked
            if isChecked then
                RunCmd("/script ConvertToRaid()")
                RunCmd(".playerbots bot add " .. bot.name)
                RunCmd("/invite " .. bot.name)
                RunCmd(".summon " .. bot.name)
                RunCmd("/w " .. bot.name .. " follow")
                Msg("Invocando bot: |cff" .. bot.color .. bot.name .. "|r")
            else
                RunCmd(".playerbots bot remove " .. bot.name)
                RunCmd(".kick " .. bot.name)
                UninviteUnit(bot.name)
                Msg("Deslogueando bot: |cff" .. bot.color .. bot.name .. "|r")
            end
        end)

        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(bot.name, 1, 0.82, 0)
            GameTooltip:AddLine("Clase: " .. bot.className .. " (Nivel 80)", 1, 1, 1)
            GameTooltip:AddLine("Rol: " .. bot.roleName, 0.8, 0.8, 0.8)

            local actualInGroup = IsBotInGroup(bot.name)
            local isBusy = IsBotBusyWithOther(bot.name)
            if isBusy then
                GameTooltip:AddLine("|cffff4444[OCUPADO]|r: Activo con otro compañero en el mundo.", 1, 0.3, 0.3, true)
                GameTooltip:AddLine("Casilla bloqueada para evitar conflictos.", 0.7, 0.7, 0.7)
            elseif actualInGroup then
                GameTooltip:AddLine("|cff00ff00En tu grupo / banda|r (Clic para despedir)", 0.2, 1, 0.2)
            else
                GameTooltip:AddLine("|cff888888Desconectado / Disponible|r (Clic para invocar)", 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table.insert(botCheckboxes, cb)
    end

    local numRows = math.ceil(#group.bots / 2)
    curY = curY - (numRows * 20) - 10
end

botChild:SetHeight(math.abs(curY) + 20)

RefreshBotCheckboxes = function()
    for _, cb in ipairs(botCheckboxes) do
        local bName = cb.bot.name
        local actualInGroup = IsBotInGroup(bName)
        local isBusy = IsBotBusyWithOther(bName)
        local lbl = _G[cb:GetName() .. "Text"]

        if isBusy then
            cb:SetChecked(false)
            cb:Disable()
            if lbl then
                lbl:SetText("|cff666666" .. bName .. "|r |cffff8800[Uso]|r")
            end
        else
            cb:Enable()
            if lbl then
                lbl:SetText("|cff" .. cb.bot.color .. bName .. "|r")
            end
            if pendingBots[bName] ~= nil then
                if pendingBots[bName] == actualInGroup then
                    pendingBots[bName] = nil
                    cb:SetChecked(actualInGroup)
                else
                    cb:SetChecked(pendingBots[bName])
                end
            else
                cb:SetChecked(actualInGroup)
            end
        end
    end
end

tab4:SetScript("OnUpdate", function(self, elapsed)
    botPollElapsed = botPollElapsed + elapsed
    if botPollElapsed >= 3.0 then
        botPollElapsed = 0
        if IsInGuild() then
            GuildRoster()
        end
    end
end)

tab4:SetScript("OnShow", function()
    botPollElapsed = 2.5
    if IsInGuild() then
        GuildRoster()
    end
    if UpdateGuildOnlineCache then UpdateGuildOnlineCache() end
    if RefreshBotCheckboxes then RefreshBotCheckboxes() end
end)

-- ================================================================
-- PESTAÑA 5: MUNDO, BALUARTES, GALEÓN & SERVIDOR (PROJECT JAINA)
-- ================================================================
CreateSectionHeader(tab5, "Achievement_Zone_HillsbradFoothills", "BALUARTES Y GALEÓN (.outpost)", 0)

local outposts = {
    { name = "Baluarte 1 (Tarren)",   cmd = "outpost 1", tip = "Baluarte Molino Tarren" },
    { name = "Baluarte 2 (Costasur)", cmd = "outpost 2", tip = "Baluarte Costasur" },
    { name = "Baluarte 3 (Cruce)",    cmd = "outpost 3", tip = "Baluarte El Cruce" },
    { name = "Baluarte 4 (Refugio)",  cmd = "outpost 4", tip = "Baluarte Refugio de la Algazara" },
    { name = "Baluarte 5 (Botín)",    cmd = "outpost 5", tip = "Baluarte Bahía del Botín" },
    { name = "Baluarte 6 (Sagrario)", cmd = "outpost 6", tip = "Baluarte Sagrario del Sol" },
}

local outY = -18
for i, op in ipairs(outposts) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local posX = 6 + (col * 120)
    local posY = outY - (row * 22)
    MakeButton(tab5, op.name, 118, 20, posX, posY, function()
        RunCmd("." .. op.cmd)
    end, "Teletransporte a " .. op.tip .. " (." .. op.cmd .. ")")
end

MakeButton(tab5, "Galeón Desertores", 118, 20, 6, -84, function()
    DoTeleport("galeon")
end, "Teletransporte a la cubierta del Galeón de los Desertores (.tele galeon)")

MakeButton(tab5, "Galeón Escala", 118, 20, 126, -84, function()
    DoTeleport("galeon_escala")
end, "Teletransporte a la escala de embarque del Galeón (.tele galeon_escala)")

CreateSectionHeader(tab5, "Spell_Arcane_PortalDalaran", "SERVIDOR Y SCRIPTING LUA", -108)

MakeButton(tab5, "Info Servidor", 118, 22, 6, -126, function()
    RunCmd(".server info")
end, "Muestra información de uptime y jugadores (.server info)")

MakeButton(tab5, "Recargar Eluna", 118, 22, 126, -126, function()
    RunCmd(".reload ale")
    Msg("Scripts Eluna Lua recargados en caliente (.reload ale)")
end, "Recarga todos los scripts Lua del servidor en caliente (.reload ale)")

MakeButton(tab5, "Guardar DB", 118, 22, 6, -150, function()
    RunCmd(".server save")
    Msg("Guardado forzado de personajes ejecutado.")
end, "Fuerza el guardado de todos los personajes en MySQL (.server save)")

MakeButton(tab5, "Tickets GM", 118, 22, 126, -150, function()
    if GMGenie and GMGenie.Tickets and GMGenie.Tickets.Toggle then
        GMGenie.Tickets.Toggle()
    else
        RunCmd(".ticket on")
    end
end, "Abre la bandeja de tickets de asistencia de GMGenie")

CreateSectionHeader(tab5, "Spell_Holy_SummonChampion", "ASPECTO Y ESCALA", -176)

MakeButton(tab5, "Morph Reset", 118, 20, 6, -194, function()
    RunCmd(".morph 0")
end, "Restaura la apariencia original (.morph 0)")

MakeButton(tab5, "Escala 1x", 118, 20, 126, -194, function()
    RunCmd(".modify scale 1")
end, "Escala normal 1.0 (.modify scale 1)")

MakeButton(tab5, "Escala 2x", 118, 20, 6, -216, function()
    RunCmd(".modify scale 2")
end, "Escala gigante 2.0 (.modify scale 2)")

MakeButton(tab5, "Escala Mini", 118, 20, 126, -216, function()
    RunCmd(".modify scale 0.5")
end, "Escala mini 0.5 (.modify scale 0.5)")

CreateSectionHeader(tab5, "Ability_Warrior_Revenge", "PVP Y HONOR", -240)

MakeButton(tab5, "PvP ON", 118, 20, 6, -258, function() RunCmd(".pvpon") end, "Activa PvP forzado (.pvpon)")
MakeButton(tab5, "PvP OFF", 118, 20, 126, -258, function() RunCmd(".pvpoff") end, "Desactiva PvP forzado (.pvpoff)")
MakeButton(tab5, "Honor Max", 118, 20, 6, -280, function() RunCmd(".modify honor 75000") end, "Establece honor al máximo (.modify honor 75000)")
MakeButton(tab5, "Arena Pts", 118, 20, 126, -280, function() RunCmd(".modify arenapoints 5000") end, "Establece 5000 puntos de arena (.modify arenapoints 5000)")

CreateSectionHeader(tab5, "INV_Misc_Book_09", "TERMINAL DE COMANDO LIBRE GM", -306)

local freeE = CreateFrame("EditBox", "JainaGMFreeCmd", tab5, "InputBoxTemplate")
freeE:SetWidth(178); freeE:SetHeight(20)
freeE:SetPoint("TOPLEFT", tab5, "TOPLEFT", 10, -326)
freeE:SetAutoFocus(false)
freeE:SetFontObject("GameFontHighlightSmall")

local function ExecFreeCmd()
    local cmd = strtrim(freeE:GetText() or "")
    if cmd ~= "" then
        RunCmd(cmd)
        Msg("Ejecutado: " .. cmd)
        freeE:SetText("")
    end
    freeE:ClearFocus()
end

freeE:SetScript("OnEnterPressed", ExecFreeCmd)

MakeButton(tab5, "OK", 52, 22, 192, -325, ExecFreeCmd, "Ejecuta el comando escrito en el servidor")

-- ================================================================
-- AUTO-DETECCIÓN DE COMANDOS .tele add / .tele del POR CHAT
-- ================================================================
hooksecurefunc("ChatEdit_SendText", function(eb)
    if not eb then return end
    local msg = eb:GetText() or ""
    local cmd, sub, name = msg:match("^[%.%#](%a+)%s+(%a+)%s+(%S+)")
    if cmd and sub and name then
        cmd = cmd:lower(); sub = sub:lower(); name = name:lower()
        if cmd == "tele" or cmd == "teleport" then
            if sub == "add" then
                if type(JainaGM_DB.customTeles) ~= "table" then JainaGM_DB.customTeles = {} end
                local exists = false
                for _, t in ipairs(JainaGM_DB.customTeles) do if t == name then exists = true break end end
                if not exists then table.insert(JainaGM_DB.customTeles, name); table.sort(JainaGM_DB.customTeles) end
                selectedCustomTele = name; RefreshDropdown()
            elseif sub == "del" then
                for i, t in ipairs(JainaGM_DB.customTeles or {}) do
                    if t == name then table.remove(JainaGM_DB.customTeles, i); break end
                end
                selectedCustomTele = (JainaGM_DB.customTeles or {})[1] or nil; RefreshDropdown()
            end
        end
    end
end)

-- ================================================================
-- EVENTOS Y CARGA
-- ================================================================
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" then
        if JainaGM_DB.point and JainaGM_DB.x and JainaGM_DB.y then
            f:ClearAllPoints()
            f:SetPoint(JainaGM_DB.point, UIParent, JainaGM_DB.point, JainaGM_DB.x, JainaGM_DB.y)
        end
        groupCheck:SetChecked(JainaGM_DB.teleWithGroup == true)
        immortalRaidCheck:SetChecked(JainaGM_DB.immortalAllRaid == true)
        if type(JainaGM_DB.customTeles) ~= "table" or #JainaGM_DB.customTeles == 0 then
            JainaGM_DB.customTeles = {}
            for _, n in ipairs(DEFAULT_CUSTOM_TELES) do table.insert(JainaGM_DB.customTeles, n) end
        end
        RefreshDropdown()
        UpdateToggleStyles()
        UpdateImmortalButton()
        UpdateLayout(JainaGM_DB.minimized)
        SelectTab(JainaGM_DB.currentTab or 1)
    elseif event == "GET_ITEM_INFO_RECEIVED" and tab2:IsShown() then
        UpdateScrollList()
    elseif event == "GUILD_ROSTER_UPDATE" then
        if UpdateGuildOnlineCache then UpdateGuildOnlineCache() end
        if tab4 and tab4:IsShown() and RefreshBotCheckboxes then
            RefreshBotCheckboxes()
        end
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if tab4 and tab4:IsShown() and RefreshBotCheckboxes then
            RefreshBotCheckboxes()
        end
        local inGroup = (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0)
        if not inGroup then
            local eb = ChatFrameEditBox or (ChatFrame1 and ChatFrame1.editBox)
            if eb then
                local ct = eb:GetAttribute("chatType")
                if ct == "PARTY" or ct == "RAID" then
                    eb:SetAttribute("chatType", "SAY")
                end
            end
        end
    end
end)

-- ================================================================
-- EXPORTACIÓN AL NAMESPACE DE GMGENIE Y SLASH COMMANDS
-- ================================================================
GMGenie = GMGenie or {}
GMGenie.ControlPanel = {
    Toggle = function()
        if f:IsShown() then f:Hide() else f:Show(); UpdateLayout(false) end
    end,
    Show = function() f:Show(); UpdateLayout(false) end,
    Hide = function() f:Hide() end,
    Frame = f
}

_G["JainaGM_Toggle"] = GMGenie.ControlPanel.Toggle
_G["JainaGM_Frame"]  = f
_G["WaniGM_Toggle"]  = GMGenie.ControlPanel.Toggle
_G["WaniGM_Frame"]   = f

SLASH_JAINAGM1 = "/jainagm"
SLASH_JAINAGM2 = "/pjgm"
SLASH_JAINAGM3 = "/staff"
SLASH_JAINAGM4 = "/control"
SLASH_JAINAGM5 = "/wgm"
SLASH_JAINAGM6 = "/wanigm"
SLASH_JAINAGM7 = "/gm"
SLASH_JAINAGM8 = "/gmtools"

SlashCmdList["JAINAGM"] = GMGenie.ControlPanel.Toggle
SlashCmdList["WANIGM"]  = GMGenie.ControlPanel.Toggle

DEFAULT_CHAT_FRAME:AddMessage(
    "|cff00ccff[Project Jaina — GM Genie & WaniGM Deluxe Suite v" .. VERSION .. "]|r cargado. " ..
    "Usa |cffffcc00/jainagm|r, |cffffcc00/wanigm|r o |cffffcc00/staff|r para abrir el Panel de Control."
)
