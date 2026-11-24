-- Oni Vision Pins 1.0 (local helper, 2026-11-15)
-- World pins / distance markers are hidden and only show while Oni Vision (V) is active,
-- then for as long as Oni Vision's own item icons stay (game value, 12 s unless a mod changes it).
-- Loot / interact prompts are never touched.
--
-- How (all found in game, 2026-11-15):
--   * Pins = HUD layout GUI020006. It has 20 copies of its pin panel (PNL_Position .. PNL_Position_19,
--     app.GUI020006._IconTbl). Each copy has a far part (_PanelFarParent = PNL_Icon: pin, distance,
--     arrow) and a near part (_PanelNearParent = PNL_Interact: loot prompt). Only the far parts are hidden.
--     (The old hide_world_pins.lua hid only the first copy, which is why it did nothing.)
--   * Hidden with via.gui.PlayObject.ForceInvisible, a flag the game never touches, so the game's own
--     Visible logic is left alone.
--   * Oni Vision state = app.cPlayerOniEyeActivationSupporter: _StartDelayTimer runs for 0.17 s after the
--     press, then _Phase = 2 (ACTIVE) for spread (0.75 s) + vanish (2 s). Item icons last
--     _Param._DetectIconDispTime (12 s). Oni Vision Toggle keeps _Phase at 2, so pins stay with it.
-- Menu: Insert -> Script Generated UI -> Oni Vision Pins. Settings: data/oni_vision_pins.json

local VERSION = "1.0"
local CONFIG_FILE = "oni_vision_pins.json"
local PIN_GUI = "GUI020006"

local cfg = { enabled = true, match_icon_time = true, seconds = 12.0 }
do
    local ok, saved = pcall(json.load_file, CONFIG_FILE)
    if ok and type(saved) == "table" then
        if type(saved.enabled) == "boolean" then cfg.enabled = saved.enabled end
        if type(saved.match_icon_time) == "boolean" then cfg.match_icon_time = saved.match_icon_time end
        if type(saved.seconds) == "number" then cfg.seconds = math.max(0, math.min(120, saved.seconds)) end
    end
end
local function save() pcall(json.dump_file, CONFIG_FILE, cfg) end

local pin_gui_typeof = nil
pcall(function() pin_gui_typeof = sdk.typeof("app.GUI020006") end)

local st = {
    oni_active = false,   -- Oni Vision running right now (start delay or phase ACTIVE)
    started_at = nil,     -- os.clock() when the phase went ACTIVE
    show = false,         -- pins should be visible
    keep = 12.0,          -- seconds pins stay after the start (game value or slider)
    icon_time = nil,      -- game's item icon time (for the UI)
    err = nil,
    frame = 0,
}

local function get_supporter()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    if not pm then return nil end
    local info = pm:call("getControllingPlayerInfo")
    if not info then return nil end
    local ent = info:get_field("<CharacterEntity>k__BackingField")
    if not ent then return nil end
    return ent:call("get_OniEyeActivationSupporter")
end

local function update_state()
    st.frame = st.frame + 1
    local sup = get_supporter()
    local now = os.clock()
    local active = false
    if sup then
        local phase = sup:get_field("_Phase") or 0
        local delay = sup:get_field("_StartDelayTimer")
        local in_delay = delay ~= nil and delay:call("get_Enabled") == true
        active = phase ~= 0 or in_delay
        local p = sup:get_field("_Param")
        local normal_len = 3.0
        if p then
            local icon = p:get_field("_DetectIconDispTime")
            local spread = p:get_field("_SpreadSecond") or 0
            local vanish = p:get_field("_VanishSecond") or 0
            if type(icon) == "number" then st.icon_time = icon + spread end
            normal_len = spread + vanish
        end
        if phase ~= 0 and not st.phase_was_on then st.started_at = now end
        if phase == 0 and st.phase_was_on and st.started_at and now - st.started_at > normal_len + 1.0 then
            -- it was held on (Oni Vision Toggle) and has now been switched off: pins go with it
            st.started_at = nil
        end
        st.phase_was_on = phase ~= 0
    else
        st.phase_was_on = false
    end
    st.oni_active = active
    st.keep = (cfg.match_icon_time and st.icon_time) or cfg.seconds
    st.show = active or (st.started_at ~= nil and now - st.started_at < st.keep)
end

re.on_pre_application_entry("UpdateBehavior", function()
    local ok, err = pcall(update_state)
    if not ok then st.err = tostring(err) end
end)

-- per GUI020006 instance: { comp, applied = true/false (ForceInvisible state we set) }
local guis = {}

local function set_far_hidden(comp, hidden)
    local tbl = comp:get_field("_IconTbl")
    if not tbl then return false end
    local n = tbl:call("get_Length") or 0
    for i = 0, n - 1 do
        local icon = tbl:call("Get", i)
        local far = icon and icon:get_field("_PanelFarParent")
        if far then far:call("set_ForceInvisible", hidden) end
    end
    return n > 0
end

local function apply(go)
    local key = go:get_address()
    local entry = guis[key]
    if entry == nil then
        local comp = pin_gui_typeof and go:call("getComponent(System.Type)", pin_gui_typeof)
        if not comp then return end
        entry = { comp = comp, applied = nil }
        guis[key] = entry
    end
    local want_hidden = cfg.enabled and not st.show
    -- apply on change, and re-apply every ~2 s in case the game rebuilt a pin slot
    if entry.applied ~= want_hidden or (want_hidden and st.frame - (entry.at or 0) > 120) then
        if set_far_hidden(entry.comp, want_hidden) then entry.applied = want_hidden; entry.at = st.frame end
    end
end

re.on_pre_gui_draw_element(function(element, context)
    local ok, go = pcall(function() return element:call("get_GameObject") end)
    if not ok or go == nil then return true end
    local ok2, name = pcall(function() return go:call("get_Name") end)
    if not ok2 or name ~= PIN_GUI then return true end
    local ok3, err = pcall(apply, go)
    if not ok3 then st.err = tostring(err); guis = {} end
    return true
end)

local function restore_all()
    for _, entry in pairs(guis) do pcall(set_far_hidden, entry.comp, false) end
    guis = {}
end

re.on_script_reset(restore_all)

re.on_draw_ui(function()
    if not imgui.tree_node("Oni Vision Pins") then return end
    local changed, v = imgui.checkbox("World pins only while Oni Vision is active", cfg.enabled)
    if changed then cfg.enabled = v; save() end
    local label = "Keep them as long as the Oni Vision item icons"
    if st.icon_time then label = label .. string.format(" (%.1f s)", st.icon_time) end
    changed, v = imgui.checkbox(label, cfg.match_icon_time)
    if changed then cfg.match_icon_time = v; save() end
    if not cfg.match_icon_time then
        local c2, s = imgui.slider_float("Seconds after pressing V", cfg.seconds, 0.0, 60.0, "%.1f s")
        if c2 then cfg.seconds = s; save() end
    end
    imgui.text(string.format("Oni Vision: %s   pins: %s", st.oni_active and "active" or "off",
        (not cfg.enabled or st.show) and "shown" or "hidden"))
    if st.err then imgui.text("Last error: " .. st.err) end
    imgui.text("Version " .. VERSION .. "  (HUD Controller: leave 'Hide' for World Markers unticked)")
    imgui.tree_pop()
end)

save() -- writes the settings file on first run
pcall(log.info, "[OniVisionPins] " .. VERSION .. " loaded")
