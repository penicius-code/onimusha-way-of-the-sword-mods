-- Touchpad Oni Vision v4: keyboard V (sent by the ds5_swipe helper on a right-half touchpad press) also works
-- while walking with the stick.
-- Found 2026-11-14: V always reaches the game (app.PlayerKeyType 43 MKB_ONI_EYE_SONER goes Success in the merged
-- app.cPlayerGameInput, even while the stick moves), but the Oni Vision action only reads it while
-- app.GameInputManager LastInputDevice == MKB. The stick keeps that at PAD, so the press is ignored.
-- Fix: while V is down (or key 43 is on), set LastInputDevice to MKB right after the game computes it.
-- Movement is not affected (the merged input still carries the stick). Button prompts may flick for a frame.
local ONI_KEY = 43
local MKB = 1
local LOG_PATH = "TouchpadOniVision_log.txt"

local enabled, logging = true, false
local overrides, hook_calls, errors = 0, 0, 0
local last_err = ""
local frame, watch_until = 0, -1
local log_lines, last_line = {}, nil

local function key_down(vk)
    local ok, d = pcall(reframework.is_key_down, reframework, vk)
    return ok and d
end

local mkb_key = nil
local function oni_key_on(mgr)
    if not mkb_key then
        local inp = mgr:call("getPlayerInput(ace.InputDef.DEVICE)", MKB)
        mkb_key = inp and inp:call("getKey(System.Int32)", ONI_KEY)
    end
    return mkb_key and mkb_key:call("get_On")
end

local function wants_mkb(mgr)
    if key_down(0x56) then return true end
    local ok, on = pcall(oni_key_on, mgr)
    if not ok then mkb_key = nil; return false end
    return on
end

local function apply(mgr)
    if not enabled or not mgr then return end
    local ok, err = pcall(function()
        if wants_mkb(mgr) and mgr:get_field("_LastInputDevice") ~= MKB then
            mgr:set_field("_LastInputDevice", MKB)
            overrides = overrides + 1
            if logging then watch_until = frame + 10 end
        end
    end)
    if not ok then errors = errors + 1; last_err = tostring(err) end
end

local gim_t = sdk.find_type_definition("app.GameInputManager")
local update_last = gim_t and gim_t:get_method("updateLastInputDevice")
if update_last then
    sdk.hook(update_last, function(args) end, function(retval)
        hook_calls = hook_calls + 1
        apply(sdk.get_managed_singleton("app.GameInputManager"))
        return retval
    end)
end
-- second line of defence in case the hook is not called
re.on_pre_application_entry("UpdateBehavior", function()
    frame = frame + 1
    apply(sdk.get_managed_singleton("app.GameInputManager"))
end)

-- optional log (off by default)
re.on_application_entry("UpdateBehavior", function()
    if not logging or frame > watch_until then return end
    local mgr = sdk.get_managed_singleton("app.GameInputManager")
    if not mgr then return end
    local ok, line = pcall(function()
        local cur = mgr:call("getPlayerInput()")
        local k = cur:call("getKey(System.Int32)", ONI_KEY)
        return string.format("dev=%s oni(cur) S=%s O=%s", tostring(mgr:get_field("_LastInputDevice")),
            tostring(k:call("get_Success")), tostring(k:call("get_On")))
    end)
    line = ok and line or ("error " .. tostring(line))
    if line ~= last_line then
        last_line = line
        log_lines[#log_lines + 1] = "f" .. frame .. "  " .. line
        if #log_lines > 500 then table.remove(log_lines, 1) end
        pcall(fs.write, LOG_PATH, table.concat(log_lines, "\n"))
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Touchpad Oni Vision") then
        local c, v = imgui.checkbox("V / touchpad Oni Vision also works while moving the stick", enabled)
        if c then enabled = v end
        local c2, v2 = imgui.checkbox("Log (reframework/data/" .. LOG_PATH .. ")", logging)
        if c2 then logging = v2 end
        imgui.text(string.format("Overrides: %d   hook calls: %d   errors: %d   hooked: %s",
            overrides, hook_calls, errors, tostring(update_last ~= nil)))
        if last_err ~= "" then imgui.text("Last error: " .. last_err) end
        imgui.tree_pop()
    end
end)
