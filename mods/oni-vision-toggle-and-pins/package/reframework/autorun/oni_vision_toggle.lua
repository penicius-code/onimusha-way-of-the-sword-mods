-- Oni Vision Toggle 1.1 (local helper, 2026-11-15)
-- 1.1: switching off is quick (wave, glow and icons fade in off_fade s, default 0.3) instead of the
--      game's 2 s wave fade-out.
-- Press V (Oni Vision): it activates as usual and then STAYS ON. Press V again to switch it off.
-- Optional: re-scan automatically after walking N metres (plays the normal pulse wave + sound),
-- so things you walk up to get revealed too. Off by default.
--
-- How (all found in game, 2026-11-15, app.cPlayerOniEyeActivationSupporter):
--   press -> isUseEyeActivation() true -> nortifyStartActivationDelay (0.17 s) -> nortifyStartActivation
--   -> readyActive: _Phase = 2, wave spreads 0.75 s (_OniActivationSpreadTimer), fades 2 s
--   (_OniActivationVanishTimer) -> finishActive: _Phase = 0.
--   Found objects glow via app.mcGimmickSonarActive (_SonarActiveTimer, 6 s); found items get an icon
--   (SonarDetectorInfo.Counter, 12 s = _Param._DetectIconDispTime).
--   Holding = keep the vanish timer at 0, icon counters full and glow timers at 1 s (fully lit).
--   isUseEyeActivation() is polled every frame and only returns true on a usable press: while held,
--   a true result = "switch off" and is swallowed (returns false), so no new pulse/animation starts.
--   nortifyStartActivation() on its own = a full silent-press pulse (wave, sound, new detection).
-- Menu: Insert -> Script Generated UI -> Oni Vision Toggle. Settings: data/oni_vision_toggle.json

local VERSION = "1.1"
local CONFIG_FILE = "oni_vision_toggle.json"
local GLOW_HOLD = 1.0      -- glow timer value kept while on (glow is fully lit from ~0.5 s)
local SWALLOW = 0.6        -- seconds after a toggle in which further presses are ignored
local MKB, ONI_KEY = 1, 43 -- ace.InputDef.DEVICE MKB, app.PlayerKeyType MKB_ONI_EYE_SONER

local cfg = { enabled = true, rescan_m = 0, off_fade = 0.3, debug = false }
do
    local ok, saved = pcall(json.load_file, CONFIG_FILE)
    if ok and type(saved) == "table" then
        if type(saved.enabled) == "boolean" then cfg.enabled = saved.enabled end
        if type(saved.rescan_m) == "number" then cfg.rescan_m = math.max(0, math.min(60, math.floor(saved.rescan_m))) end
        if type(saved.off_fade) == "number" then cfg.off_fade = math.max(0, math.min(2, saved.off_fade)) end
        if type(saved.debug) == "boolean" then cfg.debug = saved.debug end
    end
end
local function save() pcall(json.dump_file, CONFIG_FILE, cfg) end

local st = {
    on = false,
    on_at = -10, off_at = -10,
    glows = {},       -- address -> mcGimmickSonarActive (ref held)
    glow_count = 0,
    rescans = 0, toggles_off = 0, swallowed = 0,
    err = nil, hooks = 0,
}

local function dbg(msg)
    if cfg.debug then pcall(log.info, "[OniVisionToggle] " .. msg) end
end

local function get_supporter()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    if not pm then return nil end
    local info = pm:call("getControllingPlayerInfo")
    if not info then return nil end
    local ent = info:get_field("<CharacterEntity>k__BackingField")
    if not ent then return nil end
    return ent:call("get_OniEyeActivationSupporter")
end

local function drop_glows()
    for _, g in pairs(st.glows) do pcall(g.release, g) end
    st.glows = {}
    st.glow_count = 0
end

local function icon_time(sup)
    local p = sup:get_field("_Param")
    local t = p and p:get_field("_DetectIconDispTime")
    return type(t) == "number" and t or 12.0
end

local function for_each_icon(sup, fn)
    local list = sup:get_field("_SonarDetectIconList")
    if not list then return end
    local n = list:call("get_Count") or 0
    for i = 0, n - 1 do
        local e = list:call("get_Item", i)
        if e then fn(e) end
    end
end

-- move an ace.cTimer to "fade seconds before the end" (never backwards)
local function skip_to_end(t, fade)
    if not t then return end
    local lim = t:call("get_Limit")
    if type(lim) == "number" and t:call("get_Timer") < lim - fade then t:call("set_Timer", math.max(0, lim - fade)) end
end

local function turn_off(reason)
    if not st.on then return end
    st.on = false
    st.off_at = os.clock()
    local fade = cfg.off_fade
    local sup = get_supporter()
    if sup then
        -- the wave: its vanish timer would otherwise run the full 2 s
        pcall(function()
            if sup:get_field("_OniActivationSpreadTimer"):call("get_IsTimeOut") then
                skip_to_end(sup:get_field("_OniActivationVanishTimer"), fade)
            end
        end)
        pcall(for_each_icon, sup, function(e)
            local c = e:get_field("Counter")
            if type(c) == "number" and c > fade then e:set_field("Counter", fade) end
        end)
    end
    for _, g in pairs(st.glows) do
        pcall(function()
            local t = g:get_field("_SonarActiveTimer")
            if t and t:call("get_Enabled") then skip_to_end(t, fade) end
        end)
    end
    drop_glows()
    dbg("off (" .. reason .. ")")
end

-- hooks --------------------------------------------------------------------------------------------
local sup_t = sdk.find_type_definition("app.cPlayerOniEyeActivationSupporter")
local glow_t = sdk.find_type_definition("app.mcGimmickSonarActive")

local function hook(td, name, pre, post)
    local m = td and td:get_method(name)
    if not m then return end
    if pcall(sdk.hook, m, pre or function() end, post or function(r) return r end) then st.hooks = st.hooks + 1 end
end

-- the press: polled every frame, true only on a usable Oni Vision press
hook(sup_t, "isUseEyeActivation", nil, function(retval)
    if not cfg.enabled then return retval end
    if (sdk.to_int64(retval) & 1) ~= 1 then return retval end
    local now = os.clock()
    if st.on then
        st.toggles_off = st.toggles_off + 1
        turn_off("V pressed")
        return sdk.to_ptr(0)
    end
    if now - st.off_at < SWALLOW then
        st.swallowed = st.swallowed + 1
        return sdk.to_ptr(0)
    end
    return retval
end)

-- the pulse really starts (also our own re-scans)
hook(sup_t, "nortifyStartActivation", nil, function(retval)
    if cfg.enabled then
        if not st.on then dbg("on") end
        st.on = true
        st.on_at = os.clock()
    end
    return retval
end)

-- an object starts glowing: remember it so its glow can be held
hook(glow_t, "activate", function(args)
    if not (cfg.enabled and st.on) then return end
    local g = sdk.to_managed_object(args[2])
    if not g then return end
    local key = g:get_address()
    if st.glows[key] == nil and st.glow_count < 512 then
        pcall(g.add_ref, g)
        st.glows[key] = g
        st.glow_count = st.glow_count + 1
    end
end)

-- per frame ----------------------------------------------------------------------------------------
local mkb_key = nil
local function raw_press()
    local mgr = sdk.get_managed_singleton("app.GameInputManager")
    if not mgr then return false end
    if not mkb_key then
        local inp = mgr:call("getPlayerInput(ace.InputDef.DEVICE)", MKB)
        mkb_key = inp and inp:call("getKey(System.Int32)", ONI_KEY)
    end
    return mkb_key ~= nil and mkb_key:call("get_Success") == true
end

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function tick()
    if not st.on then return end
    if not cfg.enabled then turn_off("disabled"); return end
    local sup = get_supporter()
    if not sup then turn_off("no player"); return end
    local now = os.clock()

    -- second press while the game would not accept Oni Vision (busy, cooldown): keyboard fallback
    if now - st.on_at > SWALLOW and now - st.off_at > SWALLOW then
        local ok, pressed = pcall(raw_press)
        if not ok then mkb_key = nil end
        if ok and pressed then
            st.toggles_off = st.toggles_off + 1
            turn_off("V key")
            return
        end
    end

    local phase = sup:get_field("_Phase")
    if phase ~= 2 then
        turn_off("ended by the game (phase " .. tostring(phase) .. ")") -- warp, cutscene, death, reset
        return
    end

    -- hold the wave after it has spread
    local spread = sup:get_field("_OniActivationSpreadTimer")
    local spread_done = spread ~= nil and spread:call("get_IsTimeOut") == true
    if spread_done then
        local vanish = sup:get_field("_OniActivationVanishTimer")
        if vanish then vanish:call("set_Timer", 0.0) end
    end

    -- hold item icons
    local full = icon_time(sup)
    for_each_icon(sup, function(e) e:set_field("Counter", full) end)

    -- hold glows (drop destroyed ones)
    for key, g in pairs(st.glows) do
        local ok = pcall(function()
            if g:get_field("_IsDestroy") then error("destroyed") end
            local t = g:get_field("_SonarActiveTimer")
            if t and t:call("get_Enabled") and t:call("get_Timer") > GLOW_HOLD then t:call("set_Timer", GLOW_HOLD) end
        end)
        if not ok then
            pcall(g.release, g)
            st.glows[key] = nil
            st.glow_count = st.glow_count - 1
        end
    end

    -- optional re-scan after walking away from the last pulse
    if cfg.rescan_m > 0 and spread_done then
        local cool = sup:get_field("_CoolTimer")
        if cool == nil or cool:call("get_IsTimeOut") then
            local chara = sup:get_field("_OwnerCharacter")
            local tr = chara and chara:call("get_GameObject"):call("get_Transform")
            local pos = tr and tr:call("get_Position")
            local origin = sup:get_field("_ActivationStartPlayerPos")
            if pos and origin and distance(pos, origin) >= cfg.rescan_m then
                st.rescans = st.rescans + 1
                dbg("re-scan")
                sup:call("nortifyStartActivation")
            end
        end
    end
end

re.on_pre_application_entry("UpdateBehavior", function()
    local ok, err = pcall(tick)
    if not ok then st.err = tostring(err) end
end)

re.on_script_reset(function()
    turn_off("script reset")
    drop_glows()
end)

-- UI -----------------------------------------------------------------------------------------------
re.on_draw_ui(function()
    if not imgui.tree_node("Oni Vision Toggle") then return end
    local changed, v = imgui.checkbox("Oni Vision stays on until you press V again", cfg.enabled)
    if changed then
        cfg.enabled = v; save()
        if not v then turn_off("disabled") end
    end
    local c2, m = imgui.slider_int("Auto re-scan after walking (m), 0 = off", cfg.rescan_m, 0, 60)
    if c2 then cfg.rescan_m = m; save() end
    imgui.text("  (a re-scan plays the normal pulse wave + sound)")
    local c4, f = imgui.slider_float("Switch-off fade (s)", cfg.off_fade, 0.0, 2.0, "%.2f")
    if c4 then cfg.off_fade = f; save() end
    imgui.text("Oni Vision: " .. (st.on and "ON (held)" or "off"))
    if st.on and imgui.button("Switch off now") then turn_off("menu button") end
    local c3, d = imgui.checkbox("Debug log (re2_framework_log.txt)", cfg.debug)
    if c3 then cfg.debug = d; save() end
    imgui.text(string.format("hooks %d/3   glows held %d   re-scans %d   switched off %d   extra presses ignored %d",
        st.hooks, st.glow_count, st.rescans, st.toggles_off, st.swallowed))
    if st.err then imgui.text("Last error: " .. st.err) end
    imgui.text("Version " .. VERSION)
    imgui.tree_pop()
end)

save() -- writes the settings file on first run
pcall(log.info, "[OniVisionToggle] " .. VERSION .. " loaded, hooks " .. st.hooks .. "/3")
