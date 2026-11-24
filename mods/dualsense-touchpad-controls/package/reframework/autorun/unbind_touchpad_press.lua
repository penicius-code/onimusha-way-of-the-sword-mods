-- Unbind the touchpad PRESS from the game's own pad input (it cannot tell left from right half).
-- v3: clears via.hid.GamePadButton.CCenter on the via.hid GamePad device itself (Button / ButtonDown /
-- ButtonUp / ButtonRepeat) before the game's pad update reads it, plus on every ace.cPadInfo afterwards.
-- The ds5_swipe helper reads the DS5 over HID directly, so its right-half press -> V and the swipes still work.
local BUTTON = 16384 -- via.hid.GamePadButton.CLeft: what this game reads for the DS5 touchpad press (seen in game 2026-11-14)
local CRIGHT = 32768 -- right-half press reads as CRight (same as Options): hidden only while the helper holds F24
local MARKER_VK = 0x87 -- F24
local function blocked()
    local ok, down = pcall(reframework.is_key_down, reframework, MARKER_VK)
    if ok and down then return BUTTON | CRIGHT end
    return BUTTON
end

local enabled, errors, cleared = true, 0, 0
local last_dev, dev_name, last_err = 0, "?", ""
local gamepad_t = sdk.find_type_definition("via.hid.GamePad")
local device_t = sdk.find_type_definition("via.hid.GamePadDevice")

local function devices()
    local list = {}
    local pad = sdk.get_native_singleton("via.hid.GamePad")
    if not pad then return list end
    local ok, dev = pcall(sdk.call_native_func, pad, gamepad_t, "get_Device")
    if ok and dev then list[#list + 1] = dev end
    local ok2, merged = pcall(sdk.call_native_func, pad, gamepad_t, "get_MergedDevice")
    if ok2 and merged and merged ~= dev then list[#list + 1] = merged end
    return list
end

local props = {"Button", "ButtonDown", "ButtonUp", "ButtonRepeat"}
local function scrub_devices()
    if not enabled then return end
    for _, dev in ipairs(devices()) do
        local ok, err = pcall(function()
            local b = dev:call("get_Button") or 0
            last_dev = last_dev | b   -- every button bit seen since script load
            local name = dev:get_type_definition():get_full_name()
            dev_name = name
            local bits = blocked()
            for _, p in ipairs(props) do
                local v = dev:call("get_" .. p)
                if v and (v & bits) ~= 0 then
                    dev:call("set_" .. p, v & ~bits)
                    if p == "ButtonDown" then cleared = cleared + 1 end
                end
            end
        end)
        if not ok then errors = errors + 1; last_err = tostring(err) end
    end
end

-- ace side, as a second line of defence
local pad_info_t = sdk.find_type_definition("ace.cPadInfo")
local clear_key
for _, m in ipairs(pad_info_t:get_methods()) do
    if m:get_name() == "clearKey" and m:get_num_params() == 1 then clear_key = m end
end
local function scrub_info(info)
    if enabled and info then
        pcall(clear_key.call, clear_key, info, BUTTON)
        if blocked() ~= BUTTON then pcall(clear_key.call, clear_key, info, CRIGHT) end
    end
end

sdk.hook(pad_info_t:get_method("updateInputFromDevice"), function(args)
    scrub_devices()
    thread.get_hook_storage()["this"] = sdk.to_managed_object(args[2])
end, function(retval)
    scrub_info(thread.get_hook_storage()["this"])
    return retval
end)
local mgr_t = sdk.find_type_definition("ace.PadManager")
sdk.hook(mgr_t:get_method("update"), function() scrub_devices() end, function(retval)
    local mgr = sdk.get_managed_singleton("ace.PadManager")
    if mgr then scrub_info(mgr:call("get_MainPad")) end
    return retval
end)
re.on_pre_application_entry("UpdateHID", scrub_devices)
re.on_application_entry("UpdateHID", scrub_devices)
re.on_pre_application_entry("UpdateBehavior", scrub_devices)

re.on_draw_ui(function()
    if imgui.tree_node("Unbind Touchpad Press") then
        local changed, value = imgui.checkbox("Game ignores touchpad press (left = CLeft always, right = CRight while helper holds F24)", enabled)
        if changed then enabled = value end
        imgui.text(string.format("Presses cleared: %d   errors: %d   all device buttons seen: %d", cleared, errors, last_dev))
        if imgui.button("Reset seen buttons") then last_dev = 0 end
        imgui.text("Device: " .. dev_name .. "   devices found: " .. #devices())
        if last_err ~= "" then imgui.text("Last error: " .. last_err) end
        imgui.tree_pop()
    end
end)
