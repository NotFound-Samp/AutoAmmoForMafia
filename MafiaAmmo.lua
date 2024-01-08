local imgui = require 'mimgui'
local MonetLua = require 'MoonMonet'
local keys = require 'vkeys'
local sampev = require 'lib.samp.events'
local weapon = require 'game.weapons'
local inicfg = require 'inicfg'
local addons = require "ADDONS"
local ffi = require 'ffi'
local bit = require 'bit'

local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local putAmmoActive = false
local GlobalDialogId = 65565

local directIni = string.gsub(thisScript().filename, '.lua', '.ini')
local ini = inicfg.load({
    main = {
        selected = 'Default',
        key = 74,
        key_active = true,
        count = 1,
        command = 'maff',
        delay = 1000,
        color = 869033727
    },
    equipment = {
        armor = true,
        bomb = false,
        wiretapping = false,
        palmmute = false,
        C4 = false
    },
}, directIni)
inicfg.save(ini, directIni)


function join_argb(a, r, g, b)
    local argb = b  -- b
    argb = bit.bor(argb, bit.lshift(g, 8))  -- g
    argb = bit.bor(argb, bit.lshift(r, 16)) -- r
    argb = bit.bor(argb, bit.lshift(a, 24)) -- a
    return argb
end
        
function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end
        
function argb_to_rgba(argb)
    local a, r, g, b = explode_argb(argb)
    return join_argb(r, g, b, a)
end

function ARGBtoRGB(color)
    return bit.band(color, 0xFFFFFF)
end

function ColorAccentsAdapter(color)
    local a, r, g, b = explode_argb(color)

    local ret = {a = a, r = r, g = g, b = b}

    function ret:apply_alpha(alpha)
        self.a = alpha
        return self
    end

    function ret:as_u32()
        return join_argb(self.a, self.b, self.g, self.r)
    end

    function ret:as_vec4()
        return imgui.ImVec4(self.r / 255, self.g / 255, self.b / 255, self.a / 255)
    end

    function ret:as_argb()
        return join_argb(self.a, self.r, self.g, self.b)
    end

    function ret:as_rgba()
        return join_argb(self.r, self.g, self.b, self.a)
    end

    function ret:as_chat()
        return string.format("%06X", ARGBtoRGB(join_argb(self.a, self.r, self.g, self.b)))
    end
 
    return ret
end

local renderWindow = {
    main = imgui.new.bool(false),
    config = imgui.new.bool(false),
    addName = imgui.new.char[256](),
    confParameters = {
        command = imgui.new.char[256](ini.main.command),
        activeCheatCode = imgui.new.bool(ini.main.key_active),
        count = imgui.new.int(ini.main.count-1),
        list = imgui.new['const char*'][3]({'1', '2', '3'}),
        key = ini.main.key,
        setKey = false,
        delay = imgui.new.int(ini.main.delay),
        color = imgui.new.float[4](ColorAccentsAdapter(ini.main.color).r/255, ColorAccentsAdapter(ini.main.color).g/255, ColorAccentsAdapter(ini.main.color).b/255, ColorAccentsAdapter(ini.main.color).a/255)
    }
}

function json(filePath)
    local filePath = getWorkingDirectory()..'\\config\\'..(filePath:find('(.+).json') and filePath or filePath..'.json')
    local class = {}
    if not doesDirectoryExist(getWorkingDirectory()..'\\config') then
        createDirectory(getWorkingDirectory()..'\\config')
    end
    
    function class:Save(tbl)
        if tbl then
            local F = io.open(filePath, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true, 'ok'
        end
        return false, 'table = nil'
    end

    function class:Load(defaultTable)
        if not doesFileExist(filePath) then
            class:Save(defaultTable or {})
        end
        local F = io.open(filePath, 'r+')
        local TABLE = decodeJson(F:read() or {})
        F:close()
        for def_k, def_v in next, defaultTable do
            if TABLE[def_k] == nil then
                TABLE[def_k] = def_v
            end
        end
        return TABLE
    end

    return class
end

local selected = ini.main.selected
local CheatCodeCount = 0

local RGBA = join_argb(
    renderWindow.confParameters.color[3]*255,
    renderWindow.confParameters.color[0]*255,
    renderWindow.confParameters.color[1]*255,
    renderWindow.confParameters.color[2]*255
)

local JsGuns = json(string.gsub(thisScript().filename,'.lua','.json')):Load({
    ['Default'] = {
        ['23'] = 0,
        ['24'] = 0,
        ['25'] = 0,
        ['29'] = 0,
        ['30'] = 0,
        ['31'] = 0,
        ['33'] = 0,
        ['34'] = 0
    },
})

local ImGuns = {
    [23] = imgui.new.int(JsGuns[selected][tostring(23)]),
    [24] = imgui.new.int(JsGuns[selected][tostring(24)]),
    [25] = imgui.new.int(JsGuns[selected][tostring(25)]),
    [29] = imgui.new.int(JsGuns[selected][tostring(29)]),
    [30] = imgui.new.int(JsGuns[selected][tostring(30)]),
    [31] = imgui.new.int(JsGuns[selected][tostring(31)]),
    [33] = imgui.new.int(JsGuns[selected][tostring(33)]),
    [34] = imgui.new.int(JsGuns[selected][tostring(34)])
}
 
local equipment = {}
for i, val in pairs(ini.equipment) do
    equipment[i] = imgui.new.bool(val)
end
local post = {
    x = 0,
    y = 0
}

local posAmmo = {
    {2607, 1305, 1052}
}

local ammoList = {
    ['23'] = 1,
    ['24'] = 2,
    ['25'] = 3,
    ['29'] = 4,
    ['30'] = 5,
    ['31'] = 6,
    ['33'] = 7,
    ['34'] = 8,
    ['bomb'] = {9, false},
    ['C4'] = {11, false},
    ['palmmute'] = {13, false},
    ['wiretapping'] = {12, false},
    ['armor'] = {10, false}
}

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.DarkTheme((tonumber('0xFF'..ColorAccentsAdapter(RGBA):as_chat(), 16)), 1, true) -- (ColorAccentsAdapter(RGBA):as_chat())
end)
local newFrame = imgui.OnFrame(
    function() return renderWindow.main[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 320, 390
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Mafia Ammo Load',renderWindow.main, imgui.WindowFlags.NoResize)
        for i, value in pairs(ImGuns) do
            if imgui.InputInt(weapon.get_name(i), value) then
                if value[0] < 0 then 
                    value[0] = 0
                end
                JsGuns[selected][tostring(i)] = value[0]
                json(string.gsub(thisScript().filename,'.lua','.json')):Save(JsGuns)
            end
        end
        for name, state in pairs(equipment) do
            addons.ToggleButton(name..'##', state)
        end
        imgui.SetCursorPos(imgui.ImVec2(205, 345))
        if imgui.Button('Config', imgui.ImVec2(100, 25)) then
            renderWindow.config[0] = not renderWindow.config[0]
            lockPlayerControl(renderWindow.confParameters.setKey)
        end
        imgui.SetCursorPos(imgui.ImVec2(205, 315))
        if imgui.Button('Delete Preset', imgui.ImVec2(100, 25)) then
            JsGuns[selected] = nil
            for name, _ in pairs(JsGuns) do
                selected = name
                UpdateGuns(selected)
            end
            json(string.gsub(thisScript().filename,'.lua','.json')):Save(JsGuns)
        end
        local post = imgui.GetWindowPos()
        imgui.End()
        imgui.SetNextWindowPos(imgui.ImVec2(post.x - 170, post.y+40))
        imgui.SetNextWindowSize(imgui.ImVec2(150, sizeY-80))
        imgui.Begin('preset Window', renderWindow.main, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
        imgui.BeginChild('##', imgui.ImVec2(140, sizeY-120), false)
        for i, _ in pairs(JsGuns) do
            if imgui.Selectable(i, false, 0, imgui.ImVec2(140, 20)) then
                selected = i
                UpdateGuns(selected)
            end
        end
        imgui.EndChild()
        if imgui.Button('Add', imgui.ImVec2(140, 24)) then
            imgui.OpenPopup('##Add')
        end
        if imgui.BeginPopup('##Add') then
            imgui.PushItemWidth(100)
            imgui.InputText('Preset Name', renderWindow.addName, 256)
            imgui.PopItemWidth()
            imgui.SameLine()
            if imgui.Button('Add') then
                JsGuns[u8:decode(ffi.string(renderWindow.addName))] = {
                    ['24'] = 0,
                    ['25'] = 0,
                    ['29'] = 0,
                    ['30'] = 0,
                    ['31'] = 0,
                    ['33'] = 0, 
                    ['34'] = 0 
                }
                selected = u8:decode(ffi.string(renderWindow.addName))
                UpdateGuns(selected)
                json(string.gsub(thisScript().filename,'.lua','.json')):Save(JsGuns)
                imgui.CloseCurrentPopup()
            end
            imgui.EndPopup() 
        end 
        imgui.End() 
        imgui.SetNextWindowPos(imgui.ImVec2(post.x + 340, post.y+sizeY/4))
        imgui.SetNextWindowSize(imgui.ImVec2(160, sizeY-167))
        if renderWindow.config[0] then
            imgui.Begin('Config Window', renderWindow.config, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
            imgui.Text('Activated Command')
            imgui.PushItemWidth(100)
            imgui.InputText('##', renderWindow.confParameters.command, 256)
            if imgui.InputInt('Delay', renderWindow.confParameters.delay) then
                if renderWindow.confParameters.delay[0] < 0 then
                    renderWindow.confParameters.delay[0] = 0
                end
            end
            imgui.PopItemWidth()
            if imgui.ColorEdit4("Color", renderWindow.confParameters.color, imgui.ColorEditFlags.NoAlpha) then
                RGBA = join_argb(
                    renderWindow.confParameters.color[3]*255,
                    renderWindow.confParameters.color[0]*255,
                    renderWindow.confParameters.color[1]*255,
                    renderWindow.confParameters.color[2]*255
                )
                imgui.DarkTheme(tonumber('0xFF'..ColorAccentsAdapter(RGBA):as_chat(), 16), 1, true)
            end
            addons.ToggleButton('Use CheatCode', renderWindow.confParameters.activeCheatCode)
            if renderWindow.confParameters.activeCheatCode[0] then
                imgui.Text('CheatCode: '..string.rep(keys.id_to_name(ini.main.key), renderWindow.confParameters.count[0] + 1))
                imgui.PushItemWidth(50)
                if imgui.Combo('Tapping Count', renderWindow.confParameters.count, renderWindow.confParameters.list, 3) then
                    CheatCodeCount = 0
                end
                if imgui.Button(renderWindow.confParameters.setKey and 'Save Key CheatCode' or 'Change Key CheatCode') then
                    renderWindow.confParameters.setKey = not renderWindow.confParameters.setKey
                end
                if renderWindow.confParameters.setKey then
                    lockPlayerControl(renderWindow.confParameters.setKey)
                    for k, i in pairs(keys) do
                        if isKeyJustPressed(keys[k]) then
                            ini.main.key = keys[k]
                            activeKey = keys[k]
                            inicfg.save(ini, directIni)
                        end
                    end
                end
            end
            imgui.End() 
        end
    end
)


function sampev.onShowDialog(id, style, title, button1, button2, text)
    if id == 236 and title == '{FFCC00}Выберите оружие' then
        putAmmoActive = true
    else putAmmoActive = false
    end
end


function UpdateGuns(selected)
    for gun, value in pairs(JsGuns[selected]) do
        print(value)
        ImGuns[tonumber(gun)][0] = value
    end
end

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('test', function()
        local test = ColorAccentsAdapter(ini.main.color)
        for i, val in pairs(test) do
            print(i, val)
        end
    end)
    while true do
        wait(0)
        if not renderWindow.confParameters.setKey and wasKeyPressed(tonumber("0x"..fromDec(ini.main.key, 16)))  and not sampIsCursorActive() then
            CheatCodeCount = CheatCodeCount + 1
        end
        if CheatCodeCount == renderWindow.confParameters.count[0] + 1 then
            CheatCodeCount = 0
            mainWindow()
        end
        if putAmmoActive then
            for name, value in pairs(ImGuns) do
                if getAmmoInCharWeapon(PLAYER_PED, name) < value[0] then
                    sampSendDialogResponse(236, 1, ammoList[tostring(name)]-1, nil)
                    wait(renderWindow.confParameters.delay[0])
                end
            end      
            for name, value in pairs(equipment) do
                if value[0] and ammoList[name][2] then
                    sampSendDialogResponse(236, 1, ammoList[name][1]-1, nil)
                    ammoList[name][2] = false
                    wait(renderWindow.confParameters.delay[0])
                end
            end
        end
    end
end

function onScriptTerminate(s) 
	if s == thisScript() then 
        ini.main.key_active = renderWindow.confParameters.activeCheatCode[0]
        ini.main.count = renderWindow.confParameters.count[0]+1
        ini.main.command = string.gsub(u8:decode(ffi.string(renderWindow.confParameters.command)), '/', '')
        ini.equipment.armor = equipment.armor[0]
        ini.equipment.bomb = equipment.bomb[0]
        ini.equipment.wiretapping = equipment.wiretapping[0]
        ini.main.delay = renderWindow.confParameters.delay[0]
        local saveRGB = join_argb(
            renderWindow.confParameters.color[3]*255,
            renderWindow.confParameters.color[1]*255,
            renderWindow.confParameters.color[1]*255,
            renderWindow.confParameters.color[0]*255
        )
        ini.main.color = tonumber('0xFF'..ColorAccentsAdapter(RGBA):as_chat(), 16)
        inicfg.save(ini, directIni)
    end
end

function onWindowMessage(msg, wparam, lparam)
    if msg == 0x100 or msg == 0x101 then
        if wparam == keys.VK_ESCAPE and renderWindow.main[0] and not isPauseMenuActive() then
            consumeWindowMessage(true, false)
            if msg == 0x101 and not setKey then
                renderWindow.main[0] = false
                renderWindow.config[0] = false
                renderWindow.confParameters.setKey = false
                if isPlayerControlLocked() then
                    lockPlayerControl(renderWindow.confParameters.setKey) 
                end
            end
        end 
    end
end

function sampev.onCreate3DText(id, color, position, distance, testLOS, playerId, vehicleId, text)
    if text:find('/alcoprice') then
        GlobalDialogId = id
        ammoList['bomb'][2] = true
        ammoList['C4'][2] = true
        ammoList['palmmute'][2] = true
        ammoList['wiretapping'][2] = true
        ammoList['armor'][2] = true
    end
end

function sampev.onRemove3DTextLabel(idText)
    if GlobalDialogId == idText then
        putAmmoActive = false
    end
end

function mainWindow()
    renderWindow.main[0] = not renderWindow.main[0]
    lockPlayerControl(renderWindow.confParameters.setKey)
end

function sampev.onSendCommand(text)
    if #text ~= 0 then
        if text == '/'..string.gsub(u8:decode(ffi.string(renderWindow.confParameters.command)), '/', '') then
            mainWindow()
        end
    end
end

function fromDec(input, base)
    local hexstr = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local s = ''
    while input > 0 do
        local mod = math.fmod(input, base)
        s = string.sub(hexstr, mod + 1, mod + 1) .. s
        input = math.floor(input / base)
    end
    if s == '' then
        s = '0'
    end
    return s
end

function imgui.DarkTheme(color, chroma_multiplier, accurate_shades)
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local flags = imgui.Col
    local vec2, vec4 = imgui.ImVec2, imgui.ImVec4

    local function to_vec4(u32)
        local a = bit.band(bit.rshift(u32, 24), 0xFF) / 0xFF
        local r = bit.band(bit.rshift(u32, 16), 0xFF) / 0xFF
        local g = bit.band(bit.rshift(u32, 8), 0xFF) / 0xFF
        local b = bit.band(u32, 0xFF) / 0xFF
        return imgui.ImVec4(r, g, b, a)
     end

    --==[ STYLE ]==--
    style.WindowPadding = imgui.ImVec2(5, 5)
    style.FramePadding = imgui.ImVec2(5, 5)
    style.ItemSpacing = imgui.ImVec2(5, 5)
    style.ItemInnerSpacing = imgui.ImVec2(2, 2)
    style.TouchExtraPadding = imgui.ImVec2(0, 0)
    style.IndentSpacing = 0
    style.ScrollbarSize = 10
    style.GrabMinSize = 10

    --==[ BORDER ]==--
    style.WindowBorderSize = 1
    style.ChildBorderSize = 1
    style.PopupBorderSize = 1
    style.FrameBorderSize = 1
    style.TabBorderSize = 1

    --==[ ROUNDING ]==--
    style.WindowRounding = 5
    style.ChildRounding = 5
    style.FrameRounding = 5
    style.PopupRounding = 5
    style.ScrollbarRounding = 5
    style.GrabRounding = 5
    style.TabRounding = 5

    --==[ ALIGN ]==--
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    style.SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
    
    --==[ COLORS ]==--
    local palette = MonetLua.buildColors(color, chroma_multiplier, accurate_shades)
    
    colors[flags.Text] = to_vec4(palette.neutral1.color_50)
      -- colors[flags.TextDisabled] = ImVec4
    colors[flags.WindowBg] = to_vec4(palette.accent1.color_900)
    colors[flags.ChildBg] = to_vec4(palette.accent2.color_800)
    colors[flags.PopupBg] = to_vec4(palette.accent2.color_800)
    colors[flags.Border] = to_vec4(palette.neutral1.color_900)
    colors[flags.BorderShadow] = to_vec4(palette.neutral2.color_900)
    colors[flags.FrameBg] = to_vec4(palette.accent1.color_800)
    colors[flags.FrameBgHovered] = to_vec4(palette.accent1.color_700)
    colors[flags.FrameBgActive] = to_vec4(palette.accent1.color_600)
    colors[flags.TitleBg] = to_vec4(palette.accent1.color_500)
    colors[flags.TitleBgActive] = to_vec4(palette.accent1.color_800)
    -- colors[flags.TitleBgCollapsed] = ImVec4
    -- colors[flags.MenuBarBg] = ImVec4
    colors[flags.ScrollbarBg] = to_vec4(palette.accent1.color_800)
    colors[flags.ScrollbarGrab] = to_vec4(palette.accent2.color_600)
    colors[flags.ScrollbarGrabHovered] = to_vec4(palette.accent2.color_500)
    colors[flags.ScrollbarGrabActive] = to_vec4(palette.accent2.color_400)
    colors[flags.CheckMark] = to_vec4(palette.neutral1.color_50)
    colors[flags.SliderGrab] = to_vec4(palette.accent2.color_500)
    colors[flags.SliderGrabActive] = to_vec4(palette.accent2.color_400)
    colors[flags.Button] = to_vec4(palette.accent1.color_500)
    colors[flags.ButtonHovered] = to_vec4(palette.accent1.color_400)
    colors[flags.ButtonActive] = to_vec4(palette.accent1.color_300)
    colors[flags.Header] = to_vec4(palette.accent1.color_800)
    colors[flags.HeaderHovered] = to_vec4(palette.accent1.color_700)
    colors[flags.HeaderActive] = to_vec4(palette.accent1.color_600)
    colors[flags.Separator] = to_vec4(palette.accent2.color_200)
    colors[flags.SeparatorHovered] = to_vec4(palette.accent2.color_100)
    colors[flags.SeparatorActive] = to_vec4(palette.accent2.color_50)
    colors[flags.ResizeGrip] = to_vec4(palette.accent2.color_900)
    colors[flags.ResizeGripHovered] = to_vec4(palette.accent2.color_800)
    colors[flags.ResizeGripActive] = to_vec4(palette.accent2.color_700)
    colors[flags.Tab] = to_vec4(palette.accent1.color_700)
    colors[flags.TabHovered] = to_vec4(palette.accent1.color_600)
    colors[flags.TabActive] = to_vec4(palette.accent1.color_500)
    -- colors[flags.TabUnfocused] = ImVec4
    -- colors[flags.TabUnfocusedActive] = ImVec4
    colors[flags.PlotLines] = to_vec4(palette.accent3.color_300)
    colors[flags.PlotLinesHovered] = to_vec4(palette.accent3.color_50)
    colors[flags.PlotHistogram] = to_vec4(palette.accent3.color_300)
    colors[flags.PlotHistogramHovered] = to_vec4(palette.accent3.color_50)
    -- colors[flags.TextSelectedBg] = ImVec4
    colors[flags.DragDropTarget] = to_vec4(palette.accent3.color_700)
    -- colors[flags.NavHighlight] = ImVec4
    -- colors[flags.NavWindowingHighlight] = ImVec4
    -- colors[flags.NavWindowingDimBg] = ImVec4
    -- colors[flags.ModalWindowDimBg] = ImVec4
end

function GetNearestCoord(Array)
    local x, y, z = getCharCoordinates(playerPed)
    local distance = {}
    for k, v in pairs(Array) do
        distance[k] = {distance = math.floor(getDistanceBetweenCoords3d(v[1], v[2], v[3], x, y, z))}
    end
    table.sort(distance, function(a, b) return a.distance < b.distance end)
    for k, v in pairs(distance) do
        CoordDist = v.distance
        break
    end
    return CoordDist
end