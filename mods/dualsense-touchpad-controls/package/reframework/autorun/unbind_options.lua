-- Unbind Options (DS5) / Menu (Xbox) from the game's own pad input.
-- The button is cleared from ace.cPadInfo right after it reads the device each frame, so the game
-- (map, menus) never sees it. Mods that read via.hid directly (Immersive Animations, ds5_swipe helper) still do.
-- The ds5_swipe helper turns Options into the V key.
local CRIGHT = 32768 -- via.hid.GamePadButton.CRight (Options / Menu)

local pad_info = sdk.find_type_definition("ace.cPadInfo")
local update = pad_info and pad_info:get_method("updateInputFromDevice")
local clear_key
if pad_info then
    for _, m in ipairs(pad_info:get_methods()) do
        if m:get_name() == "clearKey" and m:get_num_params() == 1 then clear_key = m end
    end
end

local enabled, hooked, errors = true, false, 0
if update and clear_key then
    sdk.hook(update, function(args)
        thread.get_hook_storage()["this"] = sdk.to_managed_object(args[2])
    end, function(retval)
        local this = enabled and thread.get_hook_storage()["this"]
        if this then
            local ok = pcall(clear_key.call, clear_key, this, CRIGHT)
            if not ok then errors = errors + 1 end
        end
        return retval
    end)
    hooked = true
end

re.on_draw_ui(function()
    if imgui.tree_node("Unbind Options") then
        local changed, value = imgui.checkbox("Game ignores Options (helper sends V)", enabled)
        if changed then enabled = value end
        imgui.text(hooked and ("Hooked. Errors: " .. errors) or "Not hooked: ace.cPadInfo methods not found")
        imgui.tree_pop()
    end
end)
