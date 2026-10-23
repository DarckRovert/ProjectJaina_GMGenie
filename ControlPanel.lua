--[[
    ========================================================================
    Project Jaina - GM Genie & Staff Control Suite (ControlPanel.lua)
    Reino: Project Jaina | Motor: JainaCore WotLK 3.3.5a (Build 12340)
    ========================================================================
    Panel Integral de Control GM, Teletransporte de Grupo, Baluartes (.outpost),
    Galeón de los Desertores, Modificadores de Velocidad, Items y Utilidades.
    Integrado nativamente dentro de ProjectJaina_GMGenie.
]]

local ADDON_NAME = "ProjectJaina_GMGenie"
local VERSION    = "3.1.0-Sovereign"
local TEXTURE_DIR = "Interface\\AddOns\\ProjectJaina_GMGenie\\Textures\\"

-- ================================================================
-- PERSISTENCIA Y MIGRACIÓN AUTOMÁTICA
-- ================================================================
-- Migración transparente si existía WaniGM_DB previo en WTF
if not JainaGM_DB and WaniGM_DB then
    JainaGM_DB = WaniGM_DB
end
JainaGM_DB = JainaGM_DB or {}

local function DB(key, default)
    if JainaGM_DB[key] == nil then JainaGM_DB[key] = default end
    return JainaGM_DB[key]
end

DB("minimized",     false)
DB("teleWithGroup", false)
DB("x",             220)
DB("y",            -80)
DB("point",         "TOPLEFT")
DB("activeTab",     "general")
DB("states",        { gm=false, fly=false, visible=false, chat=false })

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
-- HELPERS CORE
-- ================================================================
local function Msg(txt)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[JainaGM]|r " .. txt)
end

local function RunCmd(cmd)
    if not cmd or cmd == "" then return end
    if GMGenie and GMGenie.sendCommand then
        GMGenie.sendCommand(cmd)
        return
    end
    local eb = ChatFrame1EditBox or LAST_ACTIVE_CHAT_EDIT_BOX
    if eb and ChatEdit_SendText then
        local prev = eb:GetText()
        eb:SetText(cmd)
        ChatEdit_SendText(eb)
        eb:SetText(prev or "")
    end
end

local function DoTele(dest)
    if not dest or dest == "" then return end
    RunCmd(JainaGM_DB.teleWithGroup and (".tele group " .. dest) or (".tele " .. dest))
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
        b:SetPoint("TOP", 0, -42); b:SetWidth(300); b:SetJustifyH("CENTER")
        ConfirmDialog.bodyTxt = b

        local yes = CreateFrame("Button", nil, ConfirmDialog, "UIPanelButtonTemplate")
        yes:SetWidth(95); yes:SetHeight(22); yes:SetPoint("BOTTOMLEFT", 18, 12)
        yes:SetText("|cffff4444Confirmar|r")
        yes:SetScript("OnClick", function()
            if ConfirmDialog._cb then ConfirmDialog._cb() end
            ConfirmDialog:Hide()
        end)

        local no = CreateFrame("Button", nil, ConfirmDialog, "UIPanelButtonTemplate")
        no:SetWidth(95); no:SetHeight(22); no:SetPoint("BOTTOMRIGHT", -18, 12)
        no:SetText("|cff00ff00Cancelar|r")
        no:SetScript("OnClick", function() ConfirmDialog:Hide() end)

        local warn = ConfirmDialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        warn:SetPoint("BOTTOM", 0, 38)
        warn:SetText("|cffff8800Esta acción puede ser IRREVERSIBLE|r")
    end
    ConfirmDialog.titleTxt:SetText("|cffff4444" .. title .. "|r")
    ConfirmDialog.bodyTxt:SetText(body)
    ConfirmDialog._cb = onYes
    ConfirmDialog:Show()
end

-- ================================================================
-- FRAME PRINCIPAL
-- ================================================================
local f = CreateFrame("Frame", "JainaGMFrame", UIParent)
f:SetWidth(260); f:SetHeight(560)
f:SetPoint(JainaGM_DB.point, UIParent, JainaGM_DB.point, JainaGM_DB.x, JainaGM_DB.y)
f:SetMovable(true); f:EnableMouse(true)
f:SetClampedToScreen(true); f:SetFrameStrata("HIGH")
f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 22, insets = { left = 5, right = 5, top = 5, bottom = 5 }
})
f:SetBackdropColor(0.04, 0.04, 0.07, 0.97)
f:SetBackdropBorderColor(1.0, 0.85, 0.35, 1.0)

local header = CreateFrame("Frame", "JainaGMHeader", f)
header:SetHeight(24); header:SetPoint("TOPLEFT", 6, -6); header:SetPoint("TOPRIGHT", -6, -6)
header:EnableMouse(true); header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() f.isMoving = true; f:StartMoving() end)
header:SetScript("OnDragStop",  function()
    f:StopMovingOrSizing(); f.isMoving = false
    local pt, _, _, x, y = f:GetPoint()
    JainaGM_DB.point = pt; JainaGM_DB.x = x; JainaGM_DB.y = y
end)

local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("LEFT", 6, 0)
title:SetText("|TInterface\\Icons\\INV_Crown_02:16:16:0:0|t |cff00ccffJainaGM|r |cffffd100v" .. VERSION .. "|r")

local minBtn = CreateFrame("Button", "JainaGMMinBtn", header, "UIPanelButtonTemplate")
minBtn:SetSize(22, 18); minBtn:SetPoint("RIGHT", -22, 0)
minBtn:SetFrameLevel(header:GetFrameLevel() + 10); minBtn:RegisterForClicks("AnyUp"); minBtn:SetText("-")

local closeBtn = CreateFrame("Button", "JainaGMCloseBtn", header, "UIPanelButtonTemplate")
closeBtn:SetSize(18, 18); closeBtn:SetPoint("RIGHT", -2, 0)
closeBtn:SetFrameLevel(header:GetFrameLevel() + 10); closeBtn:RegisterForClicks("AnyUp"); closeBtn:SetText("x")
closeBtn:SetScript("OnClick", function() f:Hide() end)

-- ================================================================
-- ARTE LATERAL (Jaina + Sylvanas con parpadeo ocular)
-- ================================================================
local jainaFrame = CreateFrame("Frame", "JainaGM_Jaina", f)
jainaFrame:SetSize(257, 500); jainaFrame:SetPoint("TOPRIGHT", f, "TOPLEFT", 24, 12); jainaFrame:EnableMouse(false)
local jainaTex = jainaFrame:CreateTexture(nil, "BACKGROUND"); jainaTex:SetAllPoints()
jainaTex:SetTexture(TEXTURE_DIR .. "jaina.tga")
jainaTex:SetTexCoord(0, 494/512, 0, 960/1024)

local sylvFrame = CreateFrame("Frame", "JainaGM_Sylvanas", f)
sylvFrame:SetSize(232, 500); sylvFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", -22, 12); sylvFrame:EnableMouse(false)
local sylvTex = sylvFrame:CreateTexture(nil, "BACKGROUND"); sylvTex:SetAllPoints()
sylvTex:SetTexture(TEXTURE_DIR .. "sylvanas.tga")
sylvTex:SetTexCoord(0, 446/512, 0, 960/1024)

local jBT, jBD, jBl = math.random(30, 60)/10, 0, false
local sBT, sBD, sBl = math.random(35, 75)/10, 0, false
local function UpdateBlink(dt)
    if jBl then
        jBD = jBD - dt
        if jBD <= 0 then
            jBl = false; jainaTex:SetTexture(TEXTURE_DIR .. "jaina.tga"); jBT = math.random(30, 65)/10
        end
    else
        jBT = jBT - dt
        if jBT <= 0 then
            jBl = true; jBD = 0.16; jainaTex:SetTexture(TEXTURE_DIR .. "jainablink.tga")
        end
    end

    if sBl then
        sBD = sBD - dt
        if sBD <= 0 then
            sBl = false; sylvTex:SetTexture(TEXTURE_DIR .. "sylvanas.tga"); sBT = math.random(35, 75)/10
        end
    else
        sBT = sBT - dt
        if sBT <= 0 then
            sBl = true; sBD = 0.16; sylvTex:SetTexture(TEXTURE_DIR .. "sylvanasblink.tga")
        end
    end
end

-- ================================================================
-- CONTENIDO Y CONTROL DE COLAPSO
-- ================================================================
local content = CreateFrame("Frame", "JainaGMContent", f)
content:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -28); content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)

local isHP, hE = false, 0
local function UpdateLayout(min)
    isHP = false
    jBl = false; jainaTex:SetTexture(TEXTURE_DIR .. "jaina.tga")
    sBl = false; sylvTex:SetTexture(TEXTURE_DIR .. "sylvanas.tga")
    if min then
        content:Hide(); f:SetHeight(34); minBtn:SetText("+"); JainaGM_DB.minimized = true
    else
        content:Show(); f:SetHeight(560); minBtn:SetText("-"); JainaGM_DB.minimized = false
    end
end

header:HookScript("OnEnter", function()
    if JainaGM_DB.minimized and not isHP and not f.isMoving then
        isHP = true; content:Show(); f:SetHeight(560)
    end
end)

f:SetScript("OnUpdate", function(self, dt)
    UpdateBlink(dt)
    if not isHP or f.isMoving then return end
    hE = hE + dt
    if hE > 0.08 then
        hE = 0
        local over = MouseIsOver(f) or (DropDownList1 and DropDownList1:IsShown() and MouseIsOver(DropDownList1))
        if not over then
            isHP = false; content:Hide(); f:SetHeight(34); minBtn:SetText("+")
            if DropDownList1 and DropDownList1:IsShown() then CloseDropDownMenus() end
        end
    end
end)

minBtn:SetScript("OnClick", function()
    if isHP then
        isHP = false; JainaGM_DB.minimized = false; minBtn:SetText("-")
    else
        UpdateLayout(not JainaGM_DB.minimized)
    end
end)

-- ================================================================
-- FACTORY DE COMPONENTES UI
-- ================================================================
local function Hdr(parent, icon, text, y)
    local s = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    s:SetText("|TInterface\\Icons\\" .. icon .. ":14:14:0:0|t  |cffffd100" .. text .. "|r")
    local line = parent:CreateTexture(nil, "BACKGROUND"); line:SetHeight(1)
    line:SetPoint("TOPLEFT", 8, y - 14); line:SetPoint("TOPRIGHT", -8, y - 14)
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(1, 0.84, 0.25, 0.35)
    return s
end

local function Btn(parent, text, w, h, x, y, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text); b:RegisterForClicks("AnyUp"); b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1, 1, true)
            GameTooltip:AddLine(tip, 1, 0.84, 0, true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

local function TogBtn(parent, labelOn, labelOff, w, h, x, y, sKey, cmdOn, cmdOff, tOn, tOff)
    local b = Btn(parent, labelOff, w, h, x, y, nil, nil)
    local function Refresh()
        if JainaGM_DB.states[sKey] then b:SetText(labelOn) else b:SetText(labelOff) end
    end
    b:SetScript("OnClick", function()
        JainaGM_DB.states[sKey] = not JainaGM_DB.states[sKey]
        RunCmd(JainaGM_DB.states[sKey] and cmdOn or cmdOff); Refresh()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if JainaGM_DB.states[sKey] then
            GameTooltip:SetText("|cff00ff00ACTIVO|r", 1, 1, 1, 1, true)
            GameTooltip:AddLine(tOff or "Click para desactivar", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText("|cffff4444INACTIVO|r", 1, 1, 1, 1, true)
            GameTooltip:AddLine(tOn or "Click para activar", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Refresh(); return b, Refresh
end

-- ================================================================
-- SISTEMA DE 5 PESTAÑAS (TABS)
-- ================================================================
local tabNames  = {"general", "tele", "mundo", "items", "util"}
local tabLabels = {"General", "Tele", "Mundo", "Items", "Utils"}
local pages, tabs = {}, {}

for i, tname in ipairs(tabNames) do
    local pg = CreateFrame("Frame", "JainaGM_Page_" .. tname, content)
    pg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -22); pg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    if i > 1 then pg:Hide() end; pages[tname] = pg
    local tw = 48; local tx = 2 + (i - 1) * (tw + 1)
    local tb = CreateFrame("Button", "JainaGM_Tab_" .. i, content, "UIPanelButtonTemplate")
    tb:SetSize(tw, 18); tb:SetPoint("TOPLEFT", content, "TOPLEFT", tx, 0); tb:SetText(tabLabels[i])
    tabs[tname] = tb
end

local function SetTab(tname)
    JainaGM_DB.activeTab = tname
    for k, pg in pairs(pages) do
        if k == tname then pg:Show() else pg:Hide() end
    end
    for i, k in ipairs(tabNames) do
        if k == tname then
            tabs[k]:SetText("|cff00ff00*" .. tabLabels[i] .. "*|r")
        else
            tabs[k]:SetText(tabLabels[i])
        end
    end
end
for _, tname in ipairs(tabNames) do
    tabs[tname]:SetScript("OnClick", function() SetTab(tname) end)
end

-- ================================================================
-- TAB 1: GENERAL
-- ================================================================
local pg = pages["general"]
Hdr(pg, "Spell_Holy_DivineIntervention", "ESTADOS GM", -2)
local _, rGM   = TogBtn(pg, "|cff00ff00GM: ON|r",   "|cffff4444GM: OFF|r",   120, 24, 6,   -20, "gm",      ".gm on", ".gm off", "Activa modo GM (.gm on)", "Desactiva modo GM (.gm off)")
local _, rFly  = TogBtn(pg, "|cff00ff00Vuelo: ON|r", "|cffff4444Vuelo: OFF|r", 120, 24, 130, -20, "fly",     ".gm fly on", ".gm fly off", "Activa vuelo libre", "Desactiva vuelo")
local _, rVis  = TogBtn(pg, "|cff00ff00Invis: ON|r", "|cffff4444Invis: OFF|r", 120, 24, 6,   -46, "visible", ".gm visible on", ".gm visible off", "Activa invisibilidad", "Desactiva invisibilidad")
local _, rChat = TogBtn(pg, "|cff00ff00Chat: ON|r",  "|cffff4444Chat: OFF|r",  120, 24, 130, -46, "chat",    ".gm chat on", ".gm chat off", "Muestra icono GM en chat", "Oculta icono GM")

Hdr(pg, "Ability_Rogue_Sprint", "VELOCIDAD DE MOVIMIENTO", -76)
local spds = {{"1x", 1}, {"2x", 2}, {"3x", 3}, {"5x", 5}, {"8x", 8}, {"10x", 10}, {"15x", 15}, {"20x", 20}}
for i, sv in ipairs(spds) do
    local col = (i - 1) % 4; local row = math.floor((i - 1) / 4)
    Btn(pg, sv[1], 58, 20, 6 + col * 62, -92 - row * 22, function() RunCmd(".modify speed " .. sv[2]) end, "Velocidad " .. sv[1] .. " — .modify speed " .. sv[2])
end

Hdr(pg, "Spell_Arcane_PortalDalaran", "OBJETIVO", -146)
Btn(pg, "Ir al Objetivo",  120, 22, 6,   -162, function() RunCmd(".appear") end, "Teletransporte hacia tu objetivo (.appear)")
Btn(pg, "Traer Objetivo",  120, 22, 130, -162, function() RunCmd(".summon") end, "Convoca a tu objetivo hacia ti (.summon)")
Btn(pg, "Kickear Objetivo", 120, 22, 6,   -186, function()
    ShowConfirm("Kickear Objetivo", "Desconectará al jugador objetivo del servidor.", function() RunCmd(".kick") end)
end, "Desconecta al jugador objetivo\n|cffff4444Muestra confirmación antes de ejecutar|r")
Btn(pg, "Banear Objetivo",  120, 22, 130, -186, function()
    ShowConfirm("BANEAR Objetivo", "|cffff4444ACCIÓN PERMANENTE.|r\nBaneará al jugador objetivo definitivamente.", function() RunCmd(".ban character target 0 JainaGM") end)
end, "Banea permanentemente al jugador objetivo\n|cffff4444REQUIERE CONFIRMACIÓN|r")

Hdr(pg, "Spell_Holy_HolyBolt", "UTILIDADES RÁPIDAS", -216)
Btn(pg, "Reparar",   76, 22, 6,   -232, function() RunCmd(".repairitems") end, "Repara todo el equipo al 100% (.repairitems)")
Btn(pg, "Reset CDs", 76, 22, 84,  -232, function() RunCmd(".cooldown")    end, "Quita todos los cooldowns (.cooldown)")
Btn(pg, "Revivir",   76, 22, 162, -232, function() RunCmd(".revive")      end, "Revive y cura al personaje (.revive)")
Btn(pg, "GPS / Pos", 120, 22, 6,   -256, function() RunCmd(".gps")         end, "Muestra coordenadas exactas (.gps)")
Btn(pg, "Info Srvr", 120, 22, 130, -256, function() RunCmd(".server info")end, "Uptime y jugadores conectados (.server info)")

-- ================================================================
-- TAB 2: TELETRANSPORTE
-- ================================================================
local pt = pages["tele"]
Hdr(pt, "Spell_Arcane_TeleportDalaran", "TELETRANSPORTE RÁPIDO", -2)

local gc = CreateFrame("CheckButton", "JainaGMGrpChk", pt, "UICheckButtonTemplate")
gc:SetSize(20, 20); gc:SetPoint("TOPLEFT", 6, -20); gc:SetChecked(JainaGM_DB.teleWithGroup)
gc:SetScript("OnClick", function(s) JainaGM_DB.teleWithGroup = s:GetChecked() and true or false end)
local gct = _G["JainaGMGrpChkText"]
if gct then
    gct:SetText("|cff00ffccTeleportar con Grupo|r"); gct:SetFontObject("GameFontHighlightSmall")
end

local mainT = {
    {"Dalaran", "dalaran"}, {"Icecrown", "icecrown"}, {"Ventormenta", "stormwind"}, {"Forjaz", "ironforge"},
    {"Orgrimmar", "orgrimmar"}, {"Cima Trueno", "thunder"}, {"Entrañas", "undercity"}, {"Ruby Sagrado", "ruby"},
}
for i, t in ipairs(mainT) do
    local col = (i - 1) % 2; local row = math.floor((i - 1) / 2)
    Btn(pt, t[1], 122, 20, 6 + col * 128, -44 - row * 22, function() DoTele(t[2]) end, "Teletransporte a " .. t[1] .. " (.tele " .. t[2] .. ")\n|cff00ffccMarca el checkbox para llevar al grupo|r")
end

Hdr(pt, "INV_Misc_Map02", "PUNTOS PERSONALIZADOS (.tele)", -210)

local selTele = nil
local ddTele = CreateFrame("Frame", "JainaGMTeleDD", pt, "UIDropDownMenuTemplate")
ddTele:SetPoint("TOPLEFT", pt, "TOPLEFT", -10, -226); UIDropDownMenu_SetWidth(ddTele, 155)

local function DDInit(self, level)
    local list = JainaGM_DB.customTeles or {}
    for _, n in ipairs(list) do
        local info = UIDropDownMenu_CreateInfo(); info.text = n; info.value = n; info.checked = (selTele == n)
        info.func = function(s)
            selTele = s.value; UIDropDownMenu_SetSelectedValue(ddTele, s.value); UIDropDownMenu_SetText(ddTele, s.value)
        end
        UIDropDownMenu_AddButton(info, level or 1)
    end
end

local function RefreshDD()
    UIDropDownMenu_Initialize(ddTele, DDInit)
    local first = selTele or (JainaGM_DB.customTeles and JainaGM_DB.customTeles[1])
    if first then
        selTele = first; UIDropDownMenu_SetSelectedValue(ddTele, first); UIDropDownMenu_SetText(ddTele, first)
    else
        UIDropDownMenu_SetText(ddTele, "Elegir destino...")
    end
end

ddTele:EnableMouse(true); ddTele:SetScript("OnMouseDown", function() ToggleDropDownMenu(1, nil, ddTele) end)

Btn(pt, "|cff00ff00IR|r", 52, 24, 178, -226, function()
    if selTele and selTele ~= "" then DoTele(selTele) else Msg("Selecciona un destino del menú primero.") end
end, "Ir al punto seleccionado del menú")

local tEdit = CreateFrame("EditBox", "JainaGMTeleEdit", pt, "InputBoxTemplate")
tEdit:SetSize(110, 20); tEdit:SetPoint("TOPLEFT", 10, -264); tEdit:SetAutoFocus(false); tEdit:SetFontObject("GameFontHighlightSmall")
local tHint = pt:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
tHint:SetPoint("BOTTOMLEFT", tEdit, "TOPLEFT", 0, 2); tHint:SetText("Nombre del nuevo punto:")

Btn(pt, "+ Guardar Aquí", 82, 22, 124, -263, function()
    local n = strtrim(tEdit:GetText() or ""); if n == "" then Msg("Escribe un nombre primero."); return end; n = string.lower(n)
    RunCmd(".tele add " .. n)
    if type(JainaGM_DB.customTeles) ~= "table" then JainaGM_DB.customTeles = {} end
    local exists = false; for _, t in ipairs(JainaGM_DB.customTeles) do if t == n then exists = true break end end
    if not exists then table.insert(JainaGM_DB.customTeles, n); table.sort(JainaGM_DB.customTeles) end
    selTele = n; RefreshDD(); tEdit:SetText(""); Msg("Punto '" .. n .. "' guardado.")
end, "Guarda tu posición actual como punto de tele (.tele add <nombre>)")

Btn(pt, "|cffff8800Borrar|r", 58, 22, 196, -263, function()
    if not selTele or selTele == "" then Msg("Selecciona un punto primero."); return end
    ShowConfirm("Borrar Punto de Tele", "Eliminar: |cffffcc00" .. selTele .. "|r\n|cffff4444No se puede deshacer.|r", function()
        RunCmd(".tele del " .. selTele)
        local list = JainaGM_DB.customTeles or {}
        for i, t in ipairs(list) do if t == selTele then table.remove(list, i); break end end
        selTele = (JainaGM_DB.customTeles or {})[1] or nil; RefreshDD(); Msg("Punto eliminado.")
    end)
end, "Elimina el punto del servidor y del menú\n|cffff4444Muestra confirmación antes de borrar|r")

-- ================================================================
-- TAB 3: MUNDO & EVENTOS
-- ================================================================
local pm = pages["mundo"]
Hdr(pm, "Achievement_GuildPerk_MassResurrection", "BALUARTES DE HERMANDAD", -2)
Btn(pm, "Censo Enclaves", 120, 22, 6,   -18, function() RunCmd(".outpost list") end, "Estado de los 6 Baluartes (.outpost list)")
Btn(pm, "|cffff8800Reset Todos|r", 120, 22, 130, -18, function()
    ShowConfirm("Reset TODOS los Baluartes", "Reseteará los 6 enclaves a Neutral.\n¿Confirmas?", function() RunCmd(".outpost reset all") end)
end, "Resetea todos los enclaves a Neutral\n|cffff4444Requiere confirmación|r")

local opN = {"1.Faro Theramore", "2.Costas Azshara", "3.Páramos Poniente", "4.Cabaña Trabalomas", "5.Caleta Faldir", "6.Costa Feralas"}
for i = 1, 6 do
    local col = (i - 1) % 2; local row = math.floor((i - 1) / 2)
    Btn(pm, opN[i], 120, 20, 6 + col * 128, -44 - row * 22, function() RunCmd(".outpost tele " .. i) end, "Teletransporte al Baluarte #" .. i)
end

local lId = pm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); lId:SetPoint("TOPLEFT", 8, -132); lId:SetText("ID:")
local eId = CreateFrame("EditBox", "JainaGMOpId", pm, "InputBoxTemplate"); eId:SetSize(30, 18); eId:SetPoint("TOPLEFT", 30, -128)
eId:SetAutoFocus(false); eId:SetFontObject("GameFontHighlightSmall"); eId:SetText("1")
Btn(pm, "Reclamar (Mi Guild)", 120, 20, 64,  -128, function() RunCmd(".outpost claim " .. strtrim(eId:GetText() or "1")) end, "Asigna el enclave a tu hermandad (.outpost claim <id>)")
Btn(pm, "Reset",              50,  20, 188, -128, function() RunCmd(".outpost reset " .. strtrim(eId:GetText() or "1")) end, "Resetea el enclave especificado (.outpost reset <id>)")

Hdr(pm, "Ability_Vehicle_SiegeEngineCannon", "GALEÓN DE LOS DESERTORES", -156)
Btn(pm, "Estado Evento",    120, 22, 6,   -172, function() RunCmd(".galleon status")      end, "Fase del Galeón (.galleon status)")
Btn(pm, "Resetear Calma",   120, 22, 130, -172, function() RunCmd(".galleon reset")       end, "Regresa a fase Calma (.galleon reset)")
Btn(pm, "Forzar Alarma",    120, 22, 6,   -196, function() RunCmd(".galleon alert")       end, "Dispara sirena y fuego costero (.galleon alert)")
Btn(pm, "Probar Cañón",     120, 22, 130, -196, function() RunCmd(".galleon testcannon")  end, "Prueba artillería de cubierta")
Btn(pm, "Cubierta Galeón",  120, 20, 6,   -220, function() RunCmd(".galleon tele")        end, "Teleporte a cubierta del galeón")
Btn(pm, "Escala de Agua",   120, 20, 130, -220, function() RunCmd(".galleon ladder")      end, "Teleporte a escala de asalto")
Btn(pm, "Campamento Costa", 242, 20, 6,   -242, function() RunCmd(".go 4148.6 -2441.7 4.2 0") end, "Teleporte al campamento costero")

Hdr(pm, "Spell_Arcane_PortalDalaran", "LORE & NÚCLEO JAINA", -270)
Btn(pm, "Jaina Proudmoore", 120, 22, 6,   -286, function() RunCmd(".tele theramore") end, "Teleporte junto a Lady Jaina en Theramore")
Btn(pm, "Recargar Eluna",   120, 22, 130, -286, function() RunCmd(".reload ale")    end, "Recarga scripts Lua en caliente (.reload ale)")

-- ================================================================
-- TAB 4: ITEMS
-- ================================================================
local pi = pages["items"]
local wBox = CreateFrame("Frame", nil, pi)
wBox:SetPoint("TOPLEFT", 4, -4); wBox:SetPoint("TOPRIGHT", -4, -4); wBox:SetHeight(36)
wBox:SetBackdrop({
    bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=12, insets={left=3, right=3, top=3, bottom=3}
})
wBox:SetBackdropColor(0.4, 0, 0, 0.85); wBox:SetBackdropBorderColor(1, 0.3, 0.3, 1)
local wTxt = wBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); wTxt:SetAllPoints()
wTxt:SetJustifyH("CENTER"); wTxt:SetJustifyV("MIDDLE")
wTxt:SetText("|cffff8800ZONA ITEMS — Acciones críticas protegidas|r")

Hdr(pi, "INV_Misc_Bag_10", "DAR ITEMS (por ItemEntry)", -46)
local eID = CreateFrame("EditBox", "JainaGMItemID", pi, "InputBoxTemplate"); eID:SetSize(100, 20); eID:SetPoint("TOPLEFT", 8, -62)
eID:SetAutoFocus(false); eID:SetFontObject("GameFontHighlightSmall")
local hID = pi:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hID:SetPoint("BOTTOMLEFT", eID, "TOPLEFT", 0, 2); hID:SetText("Item ID (entry):")
local eCnt = CreateFrame("EditBox", "JainaGMItemCnt", pi, "InputBoxTemplate"); eCnt:SetSize(52, 20); eCnt:SetPoint("TOPLEFT", 112, -62)
eCnt:SetAutoFocus(false); eCnt:SetFontObject("GameFontHighlightSmall"); eCnt:SetText("1")
local hCnt = pi:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hCnt:SetPoint("BOTTOMLEFT", eCnt, "TOPLEFT", 0, 2); hCnt:SetText("Cant:")

Btn(pi, "|cff00ff00Dar a Mí|r", 78, 22, 166, -61, function()
    local id = strtrim(eID:GetText() or ""); local cnt = strtrim(eCnt:GetText() or "1")
    if id == "" then Msg("Escribe un Item ID primero."); return end
    RunCmd(".additem " .. id .. " " .. cnt); Msg("Item " .. id .. " x" .. cnt .. " agregado.")
end, "Agrega el item a tu propio inventario (.additem <id> <cant>)")

Btn(pi, "|cff00ccffMailbox GM|r", 242, 22, 6, -86, function() RunCmd(".misc mailbox") end, "Abre tu buzón de correo para recuperar items (.misc mailbox)")

Hdr(pi, "Trade_Alchemy", "MONEDAS Y PROGRESIÓN", -124)
Btn(pi, "Max Dinero",     120, 22, 6,   -140, function() RunCmd(".modify money 2147483647") end, "Establece dinero al máximo (.modify money)")
Btn(pi, "Reset Stats",    120, 22, 130, -140, function() RunCmd(".reset stats")           end, "Resetea stats base al nivel actual (.reset stats)")
Btn(pi, "Reset Talentos", 120, 22, 6,   -164, function()
    ShowConfirm("Reset Talentos", "Reseteará el árbol de talentos al completo.\nPodrás reasignarlos.", function() RunCmd(".reset talents") end)
end, "Resetea talentos\n|cffff4444Pide confirmación|r")
Btn(pi, "Reset Hechizos", 120, 22, 130, -164, function() RunCmd(".reset spells") end, "Aprende todos los hechizos de tu clase (.reset spells)")
Btn(pi, "Nivel 80",       120, 22, 6,   -188, function()
    ShowConfirm("Subir al Nivel 80", "Subirá instantáneamente al nivel 80 de WotLK.\n|cffff8800No se puede bajar de nivel.|r", function() RunCmd(".character level 80") end)
end, "Sube al nivel máximo 80\n|cffff4444Pide confirmación|r")
Btn(pi, "XP Toggle",      120, 22, 130, -188, function() RunCmd(".xp toggle") end, "Activa/desactiva la ganancia de XP (.xp toggle)")

-- ================================================================
-- TAB 5: UTILS
-- ================================================================
local pu = pages["util"]
Hdr(pu, "Spell_Arcane_PortalDalaran", "SERVIDOR", -2)
Btn(pu, "Info Servidor",  120, 22, 6,   -18, function() RunCmd(".server info") end, "Uptime, jugadores y versión (.server info)")
Btn(pu, "Recargar Eluna", 120, 22, 130, -18, function() RunCmd(".reload ale")    end, "Recarga scripts Lua en caliente (.reload ale)")
Btn(pu, "Save DB",        120, 22, 6,   -42, function() RunCmd(".server save")   end, "Fuerza guardado de personajes (.server save)")

Hdr(pu, "Spell_Holy_SummonChampion", "ASPECTO Y ESCALA", -68)
Btn(pu, "Morph Reset",   120, 22, 6,   -84,  function() RunCmd(".morph 0")            end, "Restaura aspecto original (.morph 0)")
Btn(pu, "Escala 1x",     120, 22, 130, -84,  function() RunCmd(".modify scale 1")    end, "Escala normal 1.0 (.modify scale 1)")
Btn(pu, "Escala 2x",     120, 22, 6,   -108, function() RunCmd(".modify scale 2")    end, "Escala grande 2.0 (.modify scale 2)")
Btn(pu, "Escala Mini",   120, 22, 130, -108, function() RunCmd(".modify scale 0.5")  end, "Escala mini 0.5 (.modify scale 0.5)")

Hdr(pu, "Ability_Warrior_Revenge", "PVP Y HONOR", -134)
Btn(pu, "PvP ON",     120, 22, 6,   -150, function() RunCmd(".pvpon")                   end, "Activa PvP forzado (.pvpon)")
Btn(pu, "PvP OFF",    120, 22, 130, -150, function() RunCmd(".pvpoff")                  end, "Desactiva PvP forzado (.pvpoff)")
Btn(pu, "Honor Max",  120, 22, 6,   -174, function() RunCmd(".modify honor 75000")      end, "Establece honor al máximo (.modify honor)")
Btn(pu, "Arena Pts",  120, 22, 130, -174, function() RunCmd(".modify arenapoints 5000") end, "Establece 5000 puntos de arena")

Hdr(pu, "INV_Misc_Book_09", "COMANDO LIBRE", -200)
local freeL = pu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
freeL:SetPoint("TOPLEFT", 8, -216); freeL:SetText("Comando GM (Enter para ejecutar):")
local freeE = CreateFrame("EditBox", "JainaGMFreeCmd", pu, "InputBoxTemplate")
freeE:SetSize(180, 20); freeE:SetPoint("TOPLEFT", 8, -228); freeE:SetAutoFocus(false); freeE:SetFontObject("GameFontHighlightSmall")
freeE:SetScript("OnEnterPressed", function(self)
    local cmd = strtrim(self:GetText() or "")
    if cmd ~= "" then RunCmd(cmd); Msg("Ejecutado: " .. cmd) end
    self:ClearFocus()
end)
Btn(pu, "|cff00ff00OK|r", 56, 22, 192, -227, function()
    local cmd = strtrim(freeE:GetText() or "")
    if cmd ~= "" then RunCmd(cmd); Msg("Ejecutado: " .. cmd) end
    freeE:ClearFocus()
end, "Ejecuta el comando escrito en el campo de texto")

-- ================================================================
-- AUTO-DETECCIÓN .tele add / .tele del
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
                selTele = name; RefreshDD()
            elseif sub == "del" then
                for i, t in ipairs(JainaGM_DB.customTeles or {}) do
                    if t == name then table.remove(JainaGM_DB.customTeles, i); break end
                end
                selTele = (JainaGM_DB.customTeles or {})[1] or nil; RefreshDD()
            end
        end
    end
end)

-- ================================================================
-- EVENTOS Y CARGA
-- ================================================================
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" then
        if JainaGM_DB.point and JainaGM_DB.x and JainaGM_DB.y then
            f:ClearAllPoints(); f:SetPoint(JainaGM_DB.point, UIParent, JainaGM_DB.point, JainaGM_DB.x, JainaGM_DB.y)
        end
        gc:SetChecked(JainaGM_DB.teleWithGroup == true)
        if type(JainaGM_DB.customTeles) ~= "table" or #JainaGM_DB.customTeles == 0 then
            JainaGM_DB.customTeles = {}
            for _, n in ipairs(DEFAULT_CUSTOM_TELES) do table.insert(JainaGM_DB.customTeles, n) end
        end
        RefreshDD(); UpdateLayout(JainaGM_DB.minimized)
        rGM(); rFly(); rVis(); rChat()
        SetTab(JainaGM_DB.activeTab or "general")
    end
end)

-- ================================================================
-- EXPORTACIÓN AL NAMESPACE DE GMGENIE Y SLASH COMMANDS
-- ================================================================
GMGenie = GMGenie or {}
GMGenie.ControlPanel = {
    Toggle = function()
        if f:IsShown() then f:Hide() else f:Show() end
    end,
    Show = function() f:Show() end,
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
SlashCmdList["JAINAGM"] = GMGenie.ControlPanel.Toggle
SlashCmdList["WANIGM"]  = GMGenie.ControlPanel.Toggle

DEFAULT_CHAT_FRAME:AddMessage(
    "|cff00ccff[Project Jaina — GM Genie & Staff Suite v" .. VERSION .. "]|r cargado. " ..
    "Usa |cffffcc00/jainagm|r o |cffffcc00/staff|r para abrir el Panel de Control."
)
