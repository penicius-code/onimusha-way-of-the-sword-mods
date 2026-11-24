-- Exposure Flash Fix 1.0 (local helper, 2026-11-15)
-- DLSS 5 (OptiScaler DLSS-NR) takes its white point from the game's exposure. After fast travel or
-- leaving the menu the game resets that exposure (~0.002 -> ~560) and DLSS-NR shows a white flash
-- for ~1.5 s. This blocks the reset (ace.PostEffect.cExposureController.clearHistogram, the only
-- path seen firing in game), so the exposure simply carries on. Not needed without DLSS 5.
-- Switching it off takes effect at the next fast travel / menu exit (watch "let through").
-- Older multi-hook builds (0.1, 0.2) are not included.
-- Menu: Insert -> Script Generated UI -> Exposure Flash Fix. Settings: data/exposure_flash_fix.json

local CONFIG_FILE = "exposure_flash_fix.json"
local cfg = { enabled = true }

local ok, saved = pcall(json.load_file, CONFIG_FILE)
if ok and type(saved) == "table" and type(saved.enabled) == "boolean" then cfg.enabled = saved.enabled end

local blocked, passed, status = 0, 0, "not installed"

local td = sdk.find_type_definition("ace.PostEffect.cExposureController")
local m = td and td:get_method("clearHistogram")
if m and pcall(sdk.hook, m, function(args)
    if cfg.enabled then
        blocked = blocked + 1
        return sdk.PreHookResult.SKIP_ORIGINAL
    end
    passed = passed + 1
end, function(retval) return retval end) then
    status = "active"
end
pcall(log.info, "[ExposureFlashFix] 1.0 hook " .. status .. ", blocking " .. tostring(cfg.enabled))

re.on_draw_ui(function()
    if not imgui.tree_node("Exposure Flash Fix") then return end
    local changed
    changed, cfg.enabled = imgui.checkbox("Block the exposure reset (DLSS 5 white flash)", cfg.enabled)
    if changed then pcall(json.dump_file, CONFIG_FILE, cfg) end
    imgui.text(string.format("Hook %s   resets blocked: %d   let through: %d", status, blocked, passed))
    imgui.tree_pop()
end)
