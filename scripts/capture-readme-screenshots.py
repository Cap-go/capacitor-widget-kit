#!/usr/bin/env python3
"""Capture README widget screenshots with content detection and retry loops."""
from __future__ import annotations
import json, os, subprocess, sys, time
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "screenshots"
EXAMPLE = ROOT / "example-app"
IOS_UDID = os.environ.get("IOS_SIM_UDID", "94B6CA17-4FF7-4B8C-871C-E08AA21BCE6A")
ANDROID_HOME = os.environ.get("ANDROID_HOME", str(Path.home() / "Library/Android/sdk"))
ADB = Path(ANDROID_HOME) / "platform-tools/adb"
MAX_ATTEMPTS = 5

class Metrics:
    strict_green: int
    accent_green: int
    dark: int
    white: int
    variance: float

def run(cmd, *, cwd=None, check=True):
    print("+", " ".join(cmd))
    return subprocess.run(cmd, cwd=cwd, check=check, text=True, capture_output=True)

def load_rgb(path: Path) -> Image.Image:
    return Image.open(path).convert("RGB")

def analyze_region(im, box):
    crop = im.crop(box)
    pixels = list(crop.getdata())
    n = max(len(pixels), 1)
    strict = accent = dark = white = 0
    lum_sum = 0
    for r, g, b in pixels:
        lum = (r + g + b) / 3
        lum_sum += lum * lum
        if g > 170 and r < 90 and b < 90 and g > r + 40:
            strict += 1
        if g > r + 25 and g > 90 and b < 160:
            accent += 1
        if r < 40 and g < 40 and b < 40:
            dark += 1
        if r > 210 and g > 210 and b > 210:
            white += 1
    return Metrics(strict, accent, dark, white, lum_sum / n)

def find_dark_card_bbox(im):
    w, h = im.size
    arr = im.load()
    top = int(h * 0.35)
    best = None
    best_score = 0
    y = top
    while y < int(h * 0.92):
        dark_cols = 0
        for x in range(w):
            dark_in_col = sum(1 for yy in range(y, min(y + 220, h)) if arr[x, yy][0] < 35 and arr[x, yy][1] < 35 and arr[x, yy][2] < 35)
            if dark_in_col > 120:
                dark_cols += 1
        if dark_cols > w * 0.55:
            if dark_cols > best_score:
                best_score = dark_cols
                best = (0, max(0, y - 520), w, min(h, y + 720))
        y += 20
    return best

def find_top_accent_bbox(im):
    w, h = im.size
    arr = im.load()
    xs, ys = [], []
    for y in range(int(h * 0.02), int(h * 0.12)):
        for x in range(int(w * 0.22), int(w * 0.78)):
            r, g, b = arr[x, y]
            if (g > r + 15 and g > 95 and b < 180) or (r < 40 and g < 40 and b < 40):
                xs.append(x); ys.append(y)
    if len(xs) < 120:
        return None
    pad_x, pad_y = 60, 40
    return (
        max(0, min(xs) - pad_x),
        0,
        min(w, max(xs) + pad_x),
        min(h, max(ys) + pad_y + int(h * 0.18)),
    )

def validate_lock(im):
    box = find_dark_card_bbox(im)
    if not box:
        return False, "no live-activity card detected"
    m = analyze_region(im, box)
    if m.dark < 40000: return False, f"card too small (dark={m.dark})"
    if m.accent < 2000: return False, f"missing widget accents (accent={m.accent})"
    if m.white < 1500: return False, f"missing widget text (white={m.white})"
    return True, "ok"

def validate_island(im):
    box = find_top_accent_bbox(im)
    if not box:
        return False, "no dynamic-island accents detected"
    m = analyze_region(im, box)
    if m.strict_green < 120 and m.accent < 400:
        return False, f"island accents too weak (strict={m.strict_green}, accent={m.accent})"
    return True, "ok"

def validate_home(im):
    w, h = im.size
    card = find_dark_card_bbox(im)
    if card:
        m = analyze_region(im, card)
        if m.accent >= 1500 and m.white >= 800:
            return True, "ok"
    m = analyze_region(im, (0, 0, w, int(h * 0.22)))
    if m.strict_green >= 200:
        return True, "ok"
    return False, "no home widget content"

def validate_android(im):
    w, h = im.size
    box = (int(w * 0.05), int(h * 0.12), int(w * 0.95), int(h * 0.55))
    m = analyze_region(im, box)
    if m.variance < 2500: return False, f"widget area too flat (var={m.variance:.0f})"
    if m.white < 500 and m.accent < 300: return False, f"no widget content"
    if m.dark > (box[2]-box[0])*(box[3]-box[1])*0.85: return False, "mostly black"
    return True, "ok"

def crop_lock(im): return im.crop(find_dark_card_bbox(im))
def crop_island(im): return im.crop(find_top_accent_bbox(im))
def crop_home(im):
    card = find_dark_card_bbox(im)
    if card: return im.crop(card)
    w, h = im.size
    return im.crop((0, 0, w, int(h * 0.35)))
def crop_android(im):
    w, h = im.size
    best = None; best_var = 0; band_h = int(h * 0.28); y = int(h * 0.08)
    while y < int(h * 0.5):
        m = analyze_region(im, (0, y, w, y + band_h))
        if m.variance > best_var: best_var = m.variance; best = (0, y, w, y + band_h)
        y += 40
    return im.crop(best)

def to_webp(src, dest):
    run(["cwebp", "-q", "92", str(src), "-o", str(dest)])

def patch_main_js(enable):
    path = EXAMPLE / "src" / "main.js"
    text = path.read_text()
    marker = "// Screenshot capture helper (local only, not for commit)\n"
    if enable and marker not in text:
        text = text.replace("let currentEvents = [];\n\nconst setOutput", """let currentEvents = [];\n\n// Screenshot capture helper (local only, not for commit)\nif (Capacitor.isNativePlatform()) {\n  queueMicrotask(() => {\n    setTimeout(async () => {\n      try {\n        const result = await CapgoWidgetKit.startTemplateActivity({\n          ...createWorkoutTemplateActivity(sampleSession()),\n          startLiveActivity: true,\n        });\n        currentActivity = result.activity;\n        currentEvents = [];\n        setActivityBadge(currentActivity);\n        renderPreview();\n        renderEvents();\n      } catch (error) {\n        setOutput(`Capture start error: ${error?.message ?? error}`);\n      }\n    }, 1500);\n  });\n}\n\nconst setOutput""")
        path.write_text(text)
    elif not enable and marker in text:
        start = text.index(marker)
        end = text.index("\nconst setOutput", start)
        path.write_text(text[:start] + text[end+1:])

def build_ios():
    run(["bun", "run", "build"], cwd=EXAMPLE)
    run(["rsync", "-a", "dist/", "ios/App/App/public/"], cwd=EXAMPLE)
    run(["xcodebuild", "-scheme", "App", "-destination", "platform=iOS Simulator,name=iPhone 17 Pro", "-derivedDataPath", "/tmp/widget-kit-dd", "build"], cwd=EXAMPLE / "ios/App")

def ios_capture_raw(tmp):
    app = "/tmp/widget-kit-dd/Build/Products/Debug-iphonesimulator/App.app"
    run(["xcrun", "simctl", "boot", IOS_UDID], check=False)
    run(["xcrun", "simctl", "bootstatus", IOS_UDID, "-b"])
    run(["xcrun", "simctl", "install", IOS_UDID, app])
    run(["xcrun", "simctl", "terminate", IOS_UDID, "app.capgo.widgetkit.exampleapp"], check=False)
    run(["xcrun", "simctl", "launch", IOS_UDID, "app.capgo.widgetkit.exampleapp"])
    time.sleep(8)
    subprocess.run(["osascript", "-e", "tell application \"Simulator\" to activate"], check=False)
    subprocess.run(["cliclick", "c:900,1890"], check=False)
    time.sleep(1)
    subprocess.run(["osascript", "-e", "tell application \"System Events\" to tell process \"Simulator\" to click menu item \"Lock\" of menu \"Device\" of menu bar 1"], check=False)
    time.sleep(2)
    lock = tmp / "ios-lock-raw.png"
    run(["xcrun", "simctl", "io", IOS_UDID, "screenshot", str(lock)])
    subprocess.run(["osascript", "-e", "tell application \"System Events\" to tell process \"Simulator\" to click menu item \"Home\" of menu \"Device\" of menu bar 1"], check=False)
    time.sleep(2)
    home = tmp / "ios-home-raw.png"
    run(["xcrun", "simctl", "io", IOS_UDID, "screenshot", str(home)])
    return {"lock": lock, "home": home}

def android_capture_raw(tmp):
    apk = EXAMPLE / "android/app/build/outputs/apk/debug/app-debug.apk"
    run([str(ADB), "wait-for-device"])
    run([str(ADB), "install", "-r", str(apk)], check=False)
    run([str(ADB), "shell", "am", "start", "-n", "app.capgo.widgetkit.exampleapp/.MainActivity"])
    time.sleep(6)
    run([str(ADB), "shell", "input", "tap", "540", "2050"])
    time.sleep(2)
    run([str(ADB), "shell", "input", "keyevent", "KEYCODE_HOME"], check=False)
    time.sleep(1)
    run([str(ADB), "shell", "input", "swipe", "540", "1300", "540", "1300", "900"], check=False)
    time.sleep(1)
    run([str(ADB), "shell", "input", "tap", "700", "790"], check=False)
    time.sleep(2)
    run([str(ADB), "shell", "input", "tap", "540", "900"], check=False)
    time.sleep(2)
    run([str(ADB), "shell", "input", "tap", "540", "1200"], check=False)
    time.sleep(2)
    out = tmp / "android-raw.png"
    proc = run([str(ADB), "exec-out", "screencap", "-p"], check=False)
    if proc.returncode == 0 and proc.stdout:
        out.write_bytes(proc.stdout)
    return out

def capture_with_retries():
    tmp = Path("/tmp/widget-kit-screenshots"); tmp.mkdir(parents=True, exist_ok=True)
    report = {}
    patch_main_js(True)
    try:
        build_ios()
        for attempt in range(1, MAX_ATTEMPTS + 1):
            print(f"\n=== iOS attempt {attempt}/{MAX_ATTEMPTS} ===")
            raw = ios_capture_raw(tmp)
            lock_im, home_im = load_rgb(raw["lock"]), load_rgb(raw["home"])
            ok_lock, why_lock = validate_lock(lock_im)
            ok_island, why_island = validate_island(home_im)
            ok_home, why_home = validate_home(home_im)
            print("lock:", ok_lock, why_lock)
            print("island:", ok_island, why_island)
            print("home:", ok_home, why_home)
            if ok_lock and ok_island:
                crop_lock(lock_im).save(tmp / "lock.png")
                crop_island(home_im).save(tmp / "island.png")
                (crop_home(home_im) if ok_home else crop_lock(lock_im)).save(tmp / "home.png")
                to_webp(tmp / "lock.png", DOCS / "lock-screen-live-activity.webp")
                to_webp(tmp / "island.png", DOCS / "dynamic-island-widget.webp")
                to_webp(tmp / "home.png", DOCS / "home-screen-widget.webp")
                report["ios"] = "ok"; break
            time.sleep(3)
        else:
            report["ios"] = "failed"
        run(["./gradlew", ":app:assembleDebug"], cwd=EXAMPLE / "android")
        run(["bunx", "cap", "copy", "android"], cwd=EXAMPLE)
        for attempt in range(1, MAX_ATTEMPTS + 1):
            print(f"\n=== Android attempt {attempt}/{MAX_ATTEMPTS} ===")
            raw_android = android_capture_raw(tmp)
            if not raw_android.exists() or raw_android.stat().st_size < 10000:
                print("android: empty screencap"); continue
            ok, why = validate_android(load_rgb(raw_android))
            print("android:", ok, why)
            if ok:
                crop_android(load_rgb(raw_android)).save(tmp / "android.png")
                to_webp(tmp / "android.png", DOCS / "android-app-widget.webp")
                report["android"] = "ok"; break
            time.sleep(3)
        else:
            report["android"] = "failed"
    finally:
        patch_main_js(False)
    return report

def from_raw():
    tmp=Path("/tmp")
    lock=load_rgb(tmp/"cap-lock-raw.png")
    home=load_rgb(tmp/"cap-home2-raw.png")
    print("lock", validate_lock(lock), find_dark_card_bbox(lock))
    print("island", validate_island(home), find_top_accent_bbox(home))
    print("home", validate_home(home))
    if validate_lock(lock)[0] and validate_island(home)[0]:
        crop_lock(lock).save(tmp/"out-lock.png")
        crop_island(home).save(tmp/"out-island.png")
        (crop_home(home) if validate_home(home)[0] else crop_lock(lock)).save(tmp/"out-home.png")
        to_webp(tmp/"out-lock.png", DOCS/"lock-screen-live-activity.webp")
        to_webp(tmp/"out-island.png", DOCS/"dynamic-island-widget.webp")
        to_webp(tmp/"out-home.png", DOCS/"home-screen-widget.webp")
        return 0
    return 1

def main():
    DOCS.mkdir(parents=True, exist_ok=True)
    report = capture_with_retries()
    print("REPORT", json.dumps(report, indent=2))
    return 0 if all(v == "ok" for v in report.values()) else 1

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--from-raw":
        sys.exit(from_raw())
    sys.exit(main())
