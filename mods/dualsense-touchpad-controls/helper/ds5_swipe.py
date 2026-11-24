"""DS5 touchpad swipe -> keyboard keys (for Immersive Animations' Numpad 1 / Numpad 2 binds).

Reads the DualSense touchpad straight from its HID reports (USB or Bluetooth), so it works whatever
Steam Input is doing. No extra packages: Python standard library + Windows APIs only.

    swipe RIGHT -> Numpad 1 (draw / sheathe)    swipe LEFT -> Numpad 3 (meditation)
    swipe DOWN  -> Numpad 2 (cover cloak)       swipe UP   -> Numpad 4 (inspect sword)

Run:  pythonw ds5_swipe.py          (no window)   |   python ds5_swipe.py --debug   (prints touches)
Can be started at Windows logon (for example by a scheduled task). It sleeps (one process check every
5 s) until OnimushaWotS.exe runs, reads the pad only while the game is open, and only sends keys while the
game window is in front (--any-window drops both checks).
"""
import ctypes
import ctypes.wintypes as wt
import sys
import time

# ---- settings -------------------------------------------------------------------------------
SWIPES = {
    # direction -> virtual key (anywhere on the pad)
    "right": 0x61,   # VK_NUMPAD1  draw / sheathe
    "left": 0x63,    # VK_NUMPAD3  meditation
    "down": 0x62,    # VK_NUMPAD2  cover cloak
    "up": 0x64,      # VK_NUMPAD4  inspect sword
}
MARKER_VK = 0x87          # F24, held while the RIGHT half is pressed (the game reads that press as CRight = Options)
OPTIONS_VK = 0x56        # V (Oni Vision on keyboard)
# V is tapped when the right half is released. touchpad_oni_vision.lua makes the game accept it while the stick moves.
MIN_DX = 220             # touchpad units (pad is 1920 x 1080) a sideways swipe must travel
MIN_DY = 300              # ... and an up/down swipe
MAX_SLOPE = 0.6           # the other axis may move at most this fraction of the swipe's main axis
MAX_TIME = 0.7            # seconds from touch-down to lift; longer touches are not swipes
KEY_HOLD = 0.08           # seconds the key is held, so a once-per-frame poll cannot miss it
GAME_EXE = "onimushawots.exe"
DEBUG = "--debug" in sys.argv
ANY_WINDOW = "--any-window" in sys.argv

# ---- Windows plumbing -----------------------------------------------------------------------
setupapi = ctypes.WinDLL("setupapi", use_last_error=True)
hid = ctypes.WinDLL("hid")
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
u32 = ctypes.WinDLL("user32", use_last_error=True)


class GUID(ctypes.Structure):
    _fields_ = [("a", wt.DWORD), ("b", wt.WORD), ("c", wt.WORD), ("d", ctypes.c_ubyte * 8)]


class SP_DEVICE_INTERFACE_DATA(ctypes.Structure):
    _fields_ = [("cbSize", wt.DWORD), ("guid", GUID), ("flags", wt.DWORD), ("reserved", ctypes.c_void_p)]


class HIDD_ATTRIBUTES(ctypes.Structure):
    _fields_ = [("Size", wt.ULONG), ("VendorID", wt.USHORT), ("ProductID", wt.USHORT), ("Version", wt.USHORT)]


setupapi.SetupDiGetClassDevsW.restype = ctypes.c_void_p
setupapi.SetupDiGetClassDevsW.argtypes = [ctypes.POINTER(GUID), wt.LPCWSTR, wt.HWND, wt.DWORD]
setupapi.SetupDiEnumDeviceInterfaces.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(GUID), wt.DWORD,
                                                 ctypes.POINTER(SP_DEVICE_INTERFACE_DATA)]
setupapi.SetupDiGetDeviceInterfaceDetailW.argtypes = [ctypes.c_void_p, ctypes.POINTER(SP_DEVICE_INTERFACE_DATA),
                                                      ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD), ctypes.c_void_p]
setupapi.SetupDiDestroyDeviceInfoList.argtypes = [ctypes.c_void_p]
k32.CreateFileW.restype = wt.HANDLE
k32.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, ctypes.c_void_p, wt.DWORD, wt.DWORD, wt.HANDLE]
k32.ReadFile.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD), ctypes.c_void_p]
k32.CloseHandle.argtypes = [wt.HANDLE]
hid.HidD_GetAttributes.argtypes = [wt.HANDLE, ctypes.POINTER(HIDD_ATTRIBUTES)]
INVALID = wt.HANDLE(-1).value

SONY = 0x054C
DS5_PIDS = (0x0CE6, 0x0DF2)  # DualSense, DualSense Edge


def find_ds5():
    guid = GUID()
    hid.HidD_GetHidGuid(ctypes.byref(guid))
    info = setupapi.SetupDiGetClassDevsW(ctypes.byref(guid), None, None, 0x12)  # PRESENT | DEVICEINTERFACE
    paths, i = [], 0
    try:
        while True:
            data = SP_DEVICE_INTERFACE_DATA(cbSize=ctypes.sizeof(SP_DEVICE_INTERFACE_DATA))
            if not setupapi.SetupDiEnumDeviceInterfaces(info, None, ctypes.byref(guid), i, ctypes.byref(data)):
                break
            i += 1
            need = wt.DWORD()
            setupapi.SetupDiGetDeviceInterfaceDetailW(info, ctypes.byref(data), None, 0, ctypes.byref(need), None)
            buf = ctypes.create_string_buffer(need.value)
            ctypes.cast(buf, ctypes.POINTER(wt.DWORD))[0] = 8  # cbSize of the detail struct on x64
            if setupapi.SetupDiGetDeviceInterfaceDetailW(info, ctypes.byref(data), buf, need, None, None):
                paths.append(ctypes.wstring_at(ctypes.addressof(buf) + 4))
    finally:
        setupapi.SetupDiDestroyDeviceInfoList(info)
    for path in paths:
        h = k32.CreateFileW(path, 0x80000000, 3, None, 3, 0, None)  # GENERIC_READ, share read+write
        if h in (None, INVALID):
            continue
        attrs = HIDD_ATTRIBUTES(Size=ctypes.sizeof(HIDD_ATTRIBUTES))
        if hid.HidD_GetAttributes(h, ctypes.byref(attrs)) and attrs.VendorID == SONY and attrs.ProductID in DS5_PIDS:
            return h, path
        k32.CloseHandle(h)
    return None, None


def parse_touch(report):
    """Return (touching, x, y) of finger 1, or None if the report is not an input report we know."""
    rid = report[0]
    if rid == 0x01 and len(report) >= 64:
        base = 33           # USB report 0x01
    elif rid == 0x31 and len(report) >= 78:
        base = 34           # Bluetooth report 0x31 (one extra header byte)
    else:
        return None
    t = report[base:base + 4]
    touching = (t[0] & 0x80) == 0
    x = t[1] | ((t[2] & 0x0F) << 8)
    y = (t[2] >> 4) | (t[3] << 4)
    return touching, x, y


# ---- key output -----------------------------------------------------------------------------
class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ctypes.c_void_p)]


class INPUT(ctypes.Structure):
    class _U(ctypes.Union):
        _fields_ = [("ki", KEYBDINPUT), ("pad", ctypes.c_byte * 32)]
    _anonymous_ = ("u",)
    _fields_ = [("type", wt.DWORD), ("u", _U)]


u32.SendInput.argtypes = [wt.UINT, ctypes.POINTER(INPUT), ctypes.c_int]
u32.MapVirtualKeyW.argtypes = [wt.UINT, wt.UINT]


def send_key(vk, up):
    inp = INPUT(type=1)
    inp.ki = KEYBDINPUT(wVk=vk, wScan=u32.MapVirtualKeyW(vk, 0), dwFlags=0x0002 if up else 0)
    u32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))


u32.GetForegroundWindow.restype = wt.HWND
u32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
k32.OpenProcess.restype = wt.HANDLE
k32.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ctypes.POINTER(wt.DWORD)]


def game_in_front():
    if ANY_WINDOW:
        return True
    pid = wt.DWORD()
    u32.GetWindowThreadProcessId(u32.GetForegroundWindow(), ctypes.byref(pid))
    h = k32.OpenProcess(0x1000, False, pid.value)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return False
    try:
        buf, size = ctypes.create_unicode_buffer(520), wt.DWORD(520)
        if k32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)):
            return buf.value.lower().endswith(GAME_EXE)
        return False
    finally:
        k32.CloseHandle(h)


k32.K32EnumProcesses.argtypes = [ctypes.POINTER(wt.DWORD), wt.DWORD, ctypes.POINTER(wt.DWORD)]


def game_running():
    pids = (wt.DWORD * 4096)()
    got = wt.DWORD()
    if not k32.K32EnumProcesses(pids, ctypes.sizeof(pids), ctypes.byref(got)):
        return True  # cannot tell; assume yes rather than go deaf
    buf = ctypes.create_unicode_buffer(520)
    for pid in pids[:got.value // ctypes.sizeof(wt.DWORD)]:
        h = k32.OpenProcess(0x1000, False, pid)
        if not h:
            continue
        try:
            size = wt.DWORD(520)
            if k32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)) and buf.value.lower().endswith(GAME_EXE):
                return True
        finally:
            k32.CloseHandle(h)
    return False


def log(*a):
    if DEBUG:
        print(time.strftime("%H:%M:%S"), *a, flush=True)


# ---- main loop ------------------------------------------------------------------------------
def run():
    while True:
        if not ANY_WINDOW and not game_running():
            time.sleep(5)
            continue
        h, path = find_ds5()
        if not h:
            log("no DualSense found, retrying")
            time.sleep(3)
            continue
        log("reading", path)
        buf = ctypes.create_string_buffer(128)
        got = wt.DWORD()
        start = None      # (t, x, y) when the finger went down
        fired = False
        release_at = {}   # vk -> time to release
        reports = 0
        options_down = options_sent = False
        next_game_check = time.perf_counter() + 3
        while True:
            if not k32.ReadFile(h, buf, 128, ctypes.byref(got), None):
                log("read failed, reconnecting")
                break
            now = time.perf_counter()
            if not ANY_WINDOW and now >= next_game_check:
                next_game_check = now + 3
                if not game_running():
                    log("game closed, going idle")
                    break
            for vk, t in list(release_at.items()):
                if now >= t:
                    send_key(vk, True)
                    del release_at[vk]
            report = buf.raw[:got.value]
            bi = 9 if report[0] == 0x01 else (10 if report[0] == 0x31 else None)
            if bi is not None and len(report) > bi + 1:
                pressed = (report[bi + 1] & 0x02) != 0   # touchpad click
                t = parse_touch(report)
                if pressed and not options_down:
                    # the click bit can arrive a report before the new finger position; wait for a live touch
                    if t and t[0]:
                        options_down = True
                        options_sent = t[1] >= 960
                        if options_sent:
                            send_key(MARKER_VK, False)   # tells unbind_touchpad_press.lua to hide CRight
                        log("%s touchpad press at x=%d" % ("right" if options_sent else "left (ignored)", t[1]))
                elif not pressed and options_down:
                    # V is tapped on RELEASE: the game ignores keys while the pad is busy with the click
                    options_down = False
                    if options_sent:
                        release_at[MARKER_VK] = now + 0.05
                    if options_sent and game_in_front():
                        send_key(OPTIONS_VK, False)
                        release_at[OPTIONS_VK] = now + 0.10
                        log("right touchpad released -> V tap")
                    options_sent = False
            parsed = parse_touch(report)
            if parsed is None:
                continue
            reports += 1
            if DEBUG and reports == 1:
                log("first report id 0x%02X, %d bytes" % (buf.raw[0], got.value))
            touching, x, y = parsed
            if touching:
                last = (x, y)
                if start is None:
                    start = (now, x, y)
                    log("touch at x=%d y=%d" % (x, y))
                continue
            if start is None:
                continue
            # finger lifted: judge the whole stroke
            dx, dy = last[0] - start[1], last[1] - start[2]
            took = now - start[0]
            start = None
            direction = None
            if took <= MAX_TIME:
                if abs(dx) >= abs(dy):
                    if abs(dx) >= MIN_DX and abs(dy) <= abs(dx) * MAX_SLOPE:
                        direction = "right" if dx > 0 else "left"
                elif abs(dy) >= MIN_DY and abs(dx) <= abs(dy) * MAX_SLOPE:
                    direction = "down" if dy > 0 else "up"   # pad y grows downwards
            if direction is None:
                log("lift  dx=%+d dy=%+d after %.2fs  (no swipe)" % (dx, dy, took))
                continue
            vk = SWIPES[direction]
            front = game_in_front()
            log("swipe %s dx=%+d dy=%+d %.2fs -> vk 0x%02X%s" % (direction, dx, dy, took, vk,
                                                               "" if front else " (game not in front, skipped)"))
            if front:
                send_key(vk, False)
                release_at[vk] = now + KEY_HOLD
        for vk in release_at:
            send_key(vk, True)
        k32.CloseHandle(h)
        time.sleep(1)


if __name__ == "__main__":
    if "--probe" in sys.argv:
        h, path = find_ds5()
        print("device:", path)
        if h:
            buf, got = ctypes.create_string_buffer(128), wt.DWORD()
            for _ in range(3):
                ok = k32.ReadFile(h, buf, 128, ctypes.byref(got), None)
                print("read ok" if ok else "read failed %d" % ctypes.get_last_error(), "id=0x%02X len=%d" % (buf.raw[0], got.value),
                      "touch:", parse_touch(buf.raw[:got.value]))
        sys.exit(0)
    try:
        run()
    except KeyboardInterrupt:
        pass
