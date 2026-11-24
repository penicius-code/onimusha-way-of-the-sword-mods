-- Offline smoke test for exposure_flash_fix.lua 1.0: fakes the REFramework Lua API.
-- Run:  lua run_exposure_flash_fix_test.lua <path to exposure_flash_fix.lua>
local script_path = arg[1] or error("pass the script path")
local hook, ui_cb, saved, logs, texts = nil, nil, { enabled = true, debug = false, block_tonemapping = true }, {}, {}
local SKIP = "SKIP"
sdk = {
  PreHookResult = { SKIP_ORIGINAL = SKIP },
  find_type_definition = function(t)
    if t ~= "ace.PostEffect.cExposureController" then return nil end
    return { get_method = function(_, n) if n == "clearHistogram" then return {} end end }
  end,
  hook = function(_, pre) hook = pre end,
}
json = { load_file = function() return saved end, dump_file = function(_, t) saved = { enabled = t.enabled } end }
log = { info = function(s) logs[#logs + 1] = s end }
re = { on_draw_ui = function(f) ui_cb = f end }
local click = false
imgui = { tree_node = function() return true end, tree_pop = function() end,
  text = function(s) texts[#texts + 1] = s end,
  checkbox = function(_, v) if click then click = false; return true, not v end return false, v end }
local function ok(c, m) if not c then error("FAIL: " .. m) end print("ok  " .. m) end

dofile(script_path)
ok(logs[1] == "[ExposureFlashFix] 1.0 hook active, blocking true", "installed: " .. logs[1])
ok(hook({}) == SKIP, "reset blocked while enabled")
click = true; ui_cb()
ok(saved.enabled == false, "unticking saves enabled=false")
ok(hook({}) == nil, "reset let through while disabled")
ui_cb(); ok(texts[#texts]:find("blocked: 1   let through: 1"), "UI counters: " .. texts[#texts])
click = true; ui_cb(); ok(hook({}) == SKIP, "ticking again blocks again")
print("ALL OK")
