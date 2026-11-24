-- IA Meditation Smoke Fix 1.0 (local compatibility patch for Immersive Animations, 2026-11-16)
-- Immersive Animations' meditation borrows the Oni Vision look while it refills health / blue gauge:
-- eye glow (AwakeEye material rates) + the game's ONI_EYES_IDLE smoke effect (VfxId_10_PlayerCommon
-- 21697, Art/VFX/EffectEditor/Player/pl_cm/19_pl_cm_904.efx). Sometimes it loses track of a smoke effect
-- it started, so the glow goes off but the smoke stays on Musashi's eyes for good.
-- (Found in game 2026-11-16: two leftover ONI_EYES_IDLE effects on the player, not finished, which
-- killAll + updateFinishAndKill removed at once. Test run: IA made ONE ONI_EYES_IDLE request, yet 3
-- unfinished ONI_EYES_IDLE containers were left when the refill ended - IA only stops the container the
-- request returns. Confirmed working in game the same night.)
--
-- This script does not change Immersive Animations. It sweeps leftover ONI_EYES_IDLE effects off the
-- player at these moments:
--   * meditation / inspection ends (IA's _G.onimusha_immersive_animation_sitting goes false): 0.3 s and 2 s later
--   * still seated, but the recovery is over (IA switched the eye glow back off): 0.5 s later
--   * once after loading, and with the menu button
-- Never while the game's own Oni Vision runs (phase not 0) or in Oni mode, and never the game's own
-- Oni Vision eye effect container.
-- Menu: Insert -> Script Generated UI -> IA Meditation Smoke Fix. Settings: data/ia_meditation_smoke_fix.json

local VERSION = "1.0"
local CONFIG_FILE = "ia_meditation_smoke_fix.json"
local ONI_EYES_IDLE = 21697 -- app.VfxId_10_PlayerCommon.ID_Fixed.ONI_EYES_IDLE

local cfg = { enabled = true }
do
    local ok, saved = pcall(json.load_file, CONFIG_FILE)
    if ok and type(saved) == "table" and type(saved.enabled) == "boolean" then cfg.enabled = saved.enabled end
end
local function save() pcall(json.dump_file, CONFIG_FILE, cfg) end

local st = {
    was_sitting = false,
    glow_seen = false, low_since = nil, swept_low = false,
    due = {},            -- os.clock() times of pending sweeps
    load_sweep = true,   -- one sweep once the player exists
    sweeps = 0, removed = 0, last = "-", err = nil,
}

local ep_type, holder_type, scene_td
pcall(function()
    ep_type = sdk.typeof("via.effect.EffectPlayer")
    holder_type = sdk.typeof("via.effect.script.EffectInfoHolder")
    scene_td = sdk.find_type_definition("via.SceneManager")
end)

local function player()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    local info = pm and pm:call("getControllingPlayerInfo")
    local ent = info and info:get_field("<CharacterEntity>k__BackingField")
    if not ent then return nil end
    local sup = ent:call("get_OniEyeActivationSupporter")
    local chara = sup and sup:get_field("_OwnerCharacter")
    local go = chara and chara:call("get_GameObject")
    return ent, sup, go
end

-- true while the game itself is showing Oni eyes (Oni Vision running / held, Oni mode)
local function game_uses_eyes(ent, sup)
    if sup:get_field("_Phase") ~= 0 then return true end
    local delay = sup:get_field("_StartDelayTimer")
    if delay and delay:call("get_Enabled") == true then return true end
    local oni = ent:get_field("<OniSupporter>k__BackingField")
    if oni and oni:call("get_IsOniModeOn") == true then return true end
    return false
end

local function sweep(reason)
    local ent, sup, pgo = player()
    if not (pgo and ep_type and holder_type and scene_td) then return false end
    if game_uses_eyes(ent, sup) then return false end
    local game_c = sup:get_field("_EyeActivationEffectContainer")
    local game_addr = game_c and game_c:get_address() or 0
    local pgo_addr = pgo:get_address()
    local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), scene_td, "get_CurrentScene")
    local arr = scene and scene:call("findComponents(System.Type)", ep_type)
    if not arr then return false end
    local done, removed = {}, 0
    for i = 0, (arr:call("get_Length") or 0) - 1 do
        local ep = arr:call("Get", i)
        local go = ep and ep:call("get_GameObject")
        local h = go and go:call("getComponent(System.Type)", holder_type)
        local creator = h and h:call("get_creator")
        if creator and creator:get_address() == pgo_addr then
            local el = h:call("get_epvDataElement")
            if el and el:get_field("ID") == ONI_EYES_IDLE then
                local c = h:call("get_container")
                local addr = c and c:get_address()
                if addr and addr ~= game_addr and not done[addr] and c:call("get_isFinished") == false then
                    done[addr] = true
                    pcall(function() c:call("killAll") end)
                    pcall(function() c:call("updateFinishAndKill") end)
                    removed = removed + 1
                end
            end
        end
    end
    st.sweeps = st.sweeps + 1
    st.removed = st.removed + removed
    if removed > 0 then
        st.last = string.format("%s: removed %d", reason, removed)
        pcall(log.info, "[IAMeditationSmokeFix] " .. st.last)
    end
    return true
end

local function eye_rate(ent)
    local gs = ent:call("get_GameObjectSupporter")
    local r = gs and gs:call("get_AwakeEye_EyesRate")
    return type(r) == "number" and r or 0
end

local function tick()
    if not cfg.enabled then st.due = {}; return end
    local now = os.clock()
    local sitting = _G.onimusha_immersive_animation_sitting == true

    if st.load_sweep and not sitting then
        if sweep("after loading") then st.load_sweep = false end
    end

    if sitting then
        if not st.was_sitting then st.glow_seen = false; st.low_since = nil; st.swept_low = false end
        local ent = player()
        if ent then
            -- IA keeps the eye glow at 1.0 while it refills; when it switches the glow back off the
            -- recovery is over and its smoke should be gone too
            if eye_rate(ent) >= 0.99 then
                st.glow_seen = true; st.low_since = nil; st.swept_low = false
            elseif st.glow_seen and not st.swept_low then
                st.low_since = st.low_since or now
                if now - st.low_since > 0.5 then
                    sweep("recovery finished")
                    st.swept_low = true
                end
            end
        end
    elseif st.was_sitting then
        st.due = { now + 0.3, now + 2.0 }
    end
    st.was_sitting = sitting

    for i = #st.due, 1, -1 do
        if now >= st.due[i] and not sitting then
            table.remove(st.due, i)
            sweep("meditation ended")
        end
    end
end

re.on_pre_application_entry("UpdateBehavior", function()
    local ok, err = pcall(tick)
    if not ok then st.err = tostring(err) end
end)

re.on_draw_ui(function()
    if not imgui.tree_node("IA Meditation Smoke Fix") then return end
    local changed, v = imgui.checkbox("Remove leftover Oni eye smoke after Immersive Animations' meditation", cfg.enabled)
    if changed then cfg.enabled = v; save() end
    if imgui.button("Remove leftover eye smoke now") then
        local ok, res = pcall(sweep, "menu button")
        if not ok then st.err = tostring(res)
        elseif res == false then st.last = "menu button: not now (Oni Vision / Oni mode active)" end
    end
    imgui.text(string.format("sweeps %d   smoke effects removed %d   last: %s", st.sweeps, st.removed, st.last))
    if st.err then imgui.text("Last error: " .. st.err) end
    imgui.text("Version " .. VERSION)
    imgui.tree_pop()
end)

save() -- writes the settings file on first run
pcall(log.info, "[IAMeditationSmokeFix] " .. VERSION .. " loaded")
