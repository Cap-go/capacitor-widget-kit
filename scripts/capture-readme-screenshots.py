#!/usr/bin/env python3
"""Capture README widget screenshots via serve-sim / serve-emul (no host UI automation).

iOS: `bunx serve-sim --detach --no-preview` for lock/home buttons; framebuffer via `simctl io screenshot`.
Android: `bunx serve-emul` HTTP `/api/screenshot` + `/api/tap` (no `adb shell input`).

Setup once: `python3 -m venv .venv-screenshots && .venv-screenshots/bin/pip install Pillow`
Run: `.venv-screenshots/bin/python scripts/capture-readme-screenshots.py`
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "screenshots"
EXAMPLE = ROOT / "example-app"
IOS_UDID = os.environ.get("IOS_SIM_UDID", "94B6CA17-4FF7-4B8C-871C-E08AA21BCE6A")
ANDROID_HOME = os.environ.get("ANDROID_HOME", str(Path.home() / "Library/Android/sdk"))
ADB = Path(ANDROID_HOME) / "platform-tools/adb"
SERVE_SIM = os.environ.get("SERVE_SIM", "bunx")
SERVE_EMUL = os.environ.get("SERVE_EMUL", "bunx")
ANDROID_AVD = os.environ.get("ANDROID_AVD", "Pixel_9a")
MAX_ATTEMPTS = int(os.environ.get("SCREENSHOT_ATTEMPTS", "5"))
DERIVED = Path(os.environ.get("WIDGET_KIT_DERIVED", "/tmp/widget-kit-dd"))
BUNDLE_ID = "app.capgo.widgetkit.exampleapp"
ANDROID_PKG = "app.capgo.widgetkit.exampleapp"

try:
    from PIL import Image
except ImportError:
    print("Pillow required: python3 -m venv .venv && .venv/bin/pip install Pillow", file=sys.stderr)
    sys.exit(2)


from collections import namedtuple

Metrics = namedtuple("Metrics", ["strict", "accent", "dark", "white", "variance"])


def run(cmd, *, cwd=None, check=True, capture=True):
    printable = " ".join(str(part) for part in cmd)
    print("+", printable)
    kwargs = {"cwd": cwd, "check": check, "text": True}
    if capture:
        kwargs["capture_output"] = True
    return subprocess.run(cmd, **kwargs)


def http_json(url: str, *, method="GET", data: dict | None = None, timeout=120):
    body = None
    headers = {}
    if data is not None:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
        if not raw:
            return {}
        return json.loads(raw.decode())


def http_bytes(url: str, *, timeout=120) -> bytes:
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return resp.read()


def serve_sim(*args):
    return run([SERVE_SIM, "serve-sim@latest", *args], check=False)


def serve_emul_base(port: int = 3300) -> str:
    return f"http://127.0.0.1:{port}"


def ensure_serve_sim():
    listed = serve_sim("--list", "-q", IOS_UDID)
    if listed.returncode == 0 and listed.stdout.strip():
        try:
            payload = json.loads(listed.stdout)
            if isinstance(payload, list):
                if payload:
                    return payload[0]
            elif isinstance(payload, dict) and payload.get("running"):
                return payload
        except json.JSONDecodeError:
            pass
    started = serve_sim("--detach", "-q", "--no-preview", IOS_UDID)
    if started.returncode != 0:
        raise RuntimeError(started.stderr or started.stdout or "serve-sim failed to start")
    return json.loads(started.stdout.strip())


def sim_screenshot(path: Path):
    run(["xcrun", "simctl", "io", IOS_UDID, "screenshot", str(path)])


def sim_button(name: str):
    serve_sim("button", "-d", IOS_UDID, name)


def sim_tap(x: float, y: float):
    serve_sim("tap", "-d", IOS_UDID, str(x), str(y))


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
            dark_in_col = sum(
                1
                for yy in range(y, min(y + 220, h))
                if arr[x, yy][0] < 35 and arr[x, yy][1] < 35 and arr[x, yy][2] < 35
            )
            if dark_in_col > 120:
                dark_cols += 1
        if dark_cols > w * 0.55 and dark_cols > best_score:
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
                xs.append(x)
                ys.append(y)
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
    if m.dark < 40000:
        return False, f"card too small (dark={m.dark})"
    if m.accent < 2000:
        return False, f"missing widget accents (accent={m.accent})"
    if m.white < 1500:
        return False, f"missing widget text (white={m.white})"
    return True, "ok"


def validate_island(im):
    box = find_top_accent_bbox(im)
    if not box:
        return False, "no dynamic-island accents detected"
    m = analyze_region(im, box)
    if m.strict < 120 and m.accent < 400:
        return False, f"island accents too weak (strict={m.strict}, accent={m.accent})"
    return True, "ok"


def validate_home(im):
    w, h = im.size
    card = find_dark_card_bbox(im)
    if card:
        m = analyze_region(im, card)
        if m.accent >= 1500 and m.white >= 800:
            return True, "ok"
    m = analyze_region(im, (0, int(h * 0.18), w, int(h * 0.72)))
    if m.accent >= 1200 and m.white >= 600 and m.dark >= 8000:
        return True, "ok"
    return False, "no home widget content"


def validate_android(im):
    w, h = im.size
    box = (int(w * 0.05), int(h * 0.12), int(w * 0.95), int(h * 0.55))
    m = analyze_region(im, box)
    if m.variance < 2500:
        return False, f"widget area too flat (var={m.variance:.0f})"
    if m.white < 500 and m.accent < 300:
        return False, "no widget content"
    if m.dark > (box[2] - box[0]) * (box[3] - box[1]) * 0.85:
        return False, "mostly black"
    return True, "ok"


def crop_lock(im):
    return im.crop(find_dark_card_bbox(im))


def crop_island(im):
    return im.crop(find_top_accent_bbox(im))


def crop_home(im):
    w, h = im.size
    card = find_dark_card_bbox(im)
    if card:
        return im.crop(card)
    return im.crop((int(w * 0.06), int(h * 0.22), int(w * 0.94), int(h * 0.62)))


def crop_android(im):
    w, h = im.size
    best = None
    best_var = 0
    band_h = int(h * 0.28)
    y = int(h * 0.08)
    while y < int(h * 0.5):
        m = analyze_region(im, (0, y, w, y + band_h))
        if m.variance > best_var:
            best_var = m.variance
            best = (0, y, w, y + band_h)
        y += 40
    return im.crop(best)


def to_webp(src, dest):
    run(["cwebp", "-q", "92", str(src), "-o", str(dest)])


def patch_main_js(enable: bool):
    path = EXAMPLE / "src" / "main.js"
    text = path.read_text()
    marker = "// Screenshot capture helper (local only, not for commit)\n"
    if enable and marker not in text:
        text = text.replace(
            "let currentEvents = [];\n\nconst setOutput",
            """let currentEvents = [];\n\n// Screenshot capture helper (local only, not for commit)\nif (Capacitor.isNativePlatform()) {\n  queueMicrotask(() => {\n    setTimeout(async () => {\n      try {\n        const result = await CapgoWidgetKit.startTemplateActivity({\n          ...createWorkoutTemplateActivity(sampleSession()),\n          startLiveActivity: true,\n        });\n        currentActivity = result.activity;\n        currentEvents = [];\n        setActivityBadge(currentActivity);\n        renderPreview();\n        renderEvents();\n        await CapgoWidgetKit.startTemplateWidget(\n          createWorkoutTemplateActivity(sampleSession()),\n        );\n      } catch (error) {\n        setOutput(`Capture start error: ${error?.message ?? error}`);\n      }\n    }, 1500);\n  });\n}\n\nconst setOutput""",
        )
        path.write_text(text)
    elif not enable and marker in text:
        start = text.index(marker)
        end = text.index("\nconst setOutput", start)
        path.write_text(text[:start] + text[end + 1 :])


def sync_web_assets():
    run(["bun", "run", "build"], cwd=EXAMPLE)
    run(["rsync", "-a", "dist/", "ios/App/App/public/"], cwd=EXAMPLE)


def build_ios():
    sync_web_assets()
    run(
        [
            "xcodebuild",
            "-scheme",
            "App",
            "-destination",
            "platform=iOS Simulator,name=iPhone 17 Pro",
            "-derivedDataPath",
            str(DERIVED),
            "build",
        ],
        cwd=EXAMPLE / "ios/App",
    )


def ios_prepare():
    app = DERIVED / "Build/Products/Debug-iphonesimulator/App.app"
    if not app.exists():
        raise FileNotFoundError(app)
    public = app / "public"
    src_public = EXAMPLE / "ios/App/App/public"
    if src_public.exists():
        if public.exists():
            shutil.rmtree(public)
        shutil.copytree(src_public, public)
    ensure_serve_sim()
    run(["xcrun", "simctl", "boot", IOS_UDID], check=False)
    run(["xcrun", "simctl", "bootstatus", IOS_UDID, "-b"])
    run(["xcrun", "simctl", "install", IOS_UDID, str(app)])
    run(["xcrun", "simctl", "terminate", IOS_UDID, BUNDLE_ID], check=False)
    run(["xcrun", "simctl", "launch", IOS_UDID, BUNDLE_ID])


def dismiss_ios_dialogs():
    for x, y in ((0.5, 0.62), (0.5, 0.67), (0.5, 0.72)):
        sim_tap(x, y)
        time.sleep(0.8)


def ios_pin_home_widget():
    """Add Capgo Template widget via SpringBoard edit mode (serve-sim taps only)."""
    sim_button("home")
    time.sleep(1.5)
    sim_tap(0.5, 0.5)
    time.sleep(0.4)
    sim_tap(0.5, 0.5)
    time.sleep(1.2)
    # Edit / jiggle mode
    sim_tap(0.12, 0.92)
    time.sleep(1.0)
    # Add widget (+) top-left in edit chrome
    sim_tap(0.08, 0.08)
    time.sleep(1.5)
    # Search / pick Capgo Template
    for y in (0.22, 0.30, 0.38, 0.46):
        sim_tap(0.5, y)
        time.sleep(0.5)
    sim_tap(0.85, 0.92)
    time.sleep(1.0)
    sim_button("home")
    time.sleep(1.0)


def ios_capture_raw(tmp: Path):
    ios_prepare()
    time.sleep(8)
    dismiss_ios_dialogs()
    time.sleep(2)

    # Dynamic Island: live activity while app is backgrounded
    sim_button("home")
    time.sleep(2)
    island = tmp / "ios-island-raw.png"
    sim_screenshot(island)

    # Lock screen live activity
    sim_button("power")
    time.sleep(1.2)
    lock = tmp / "ios-lock-raw.png"
    sim_screenshot(lock)

    # Wake, pin widget if needed, capture home screen
    sim_button("power")
    time.sleep(1.0)
    ios_pin_home_widget()
    home = tmp / "ios-home-raw.png"
    sim_screenshot(home)
    return {"lock": lock, "island": island, "home": home}


def start_serve_emul(port: int = 3300) -> str:
    base = serve_emul_base(port)
    try:
        http_json(f"{base}/health", timeout=2)
        return base
    except (urllib.error.URLError, TimeoutError):
        pass

    emulator_bin = Path(ANDROID_HOME) / "emulator/emulator"
    devices = run([str(ADB), "devices"], check=False).stdout
    if "device" not in devices.splitlines()[1:]:
        if emulator_bin.exists():
            subprocess.Popen(
                [str(emulator_bin), f"@{ANDROID_AVD}", "-gpu", "host", "-no-window", "-no-audio"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            run([str(ADB), "wait-for-device"], check=False)
            for _ in range(90):
                booted = run([str(ADB), "shell", "getprop", "sys.boot_completed"], check=False).stdout.strip()
                if booted == "1":
                    break
                time.sleep(2)

    proc = subprocess.Popen(
        [SERVE_EMUL, "serve-emul@latest", "-s", "emulator-5554", "-p", str(port)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    deadline = time.time() + 180
    while time.time() < deadline:
        if proc.poll() is not None:
            out = proc.stdout.read() if proc.stdout else ""
            raise RuntimeError(f"serve-emul exited early:\n{out}")
        try:
            http_json(f"{base}/health", timeout=3)
            return base
        except (urllib.error.URLError, TimeoutError):
            time.sleep(2)
    proc.kill()
    raise TimeoutError("serve-emul did not become healthy in time")


def emul_screenshot(base: str, path: Path):
    path.write_bytes(http_bytes(f"{base}/api/screenshot"))


def emul_tap(base: str, x: float, y: float):
    http_json(f"{base}/api/tap", method="POST", data={"x": x, "y": y})


def emul_key(base: str, key: str):
    http_json(f"{base}/api/key", method="POST", data={"key": key})


def android_capture_raw(tmp: Path, base: str):
    apk = EXAMPLE / "android/app/build/outputs/apk/debug/app-debug.apk"
    # multipart install via curl (urllib is awkward for files)
    run(
        [
            "curl",
            "-fsS",
            "-X",
            "POST",
            f"{base}/api/apps/install",
            "-F",
            f"apk=@{apk}",
        ],
        check=False,
    )
    http_json(
        f"{base}/api/apps/launch",
        method="POST",
        data={"packageName": ANDROID_PKG, "activity": ".MainActivity"},
    )
    time.sleep(8)
    # Start template + live activity in app (same auto patch)
    emul_tap(base, 0.5, 0.55)
    time.sleep(2)
    # Pin widget flow inside app
    emul_tap(base, 0.5, 0.72)
    time.sleep(2)
    emul_tap(base, 0.5, 0.82)
    time.sleep(2)
    emul_key(base, "home")
    time.sleep(1.5)
    out = tmp / "android-raw.png"
    emul_screenshot(base, out)
    return out


def export_ios(lock_im, island_im, home_im, tmp: Path):
    crop_lock(lock_im).save(tmp / "lock.png")
    crop_island(island_im).save(tmp / "island.png")
    (crop_home(home_im) if validate_home(home_im)[0] else crop_lock(lock_im)).save(tmp / "home.png")
    to_webp(tmp / "lock.png", DOCS / "lock-screen-live-activity.webp")
    to_webp(tmp / "island.png", DOCS / "dynamic-island-widget.webp")
    to_webp(tmp / "home.png", DOCS / "home-screen-widget.webp")


def capture_with_retries(*, skip_build: bool = False):
    tmp = Path("/tmp/widget-kit-screenshots")
    tmp.mkdir(parents=True, exist_ok=True)
    report: dict[str, str] = {}
    patch_main_js(True)
    try:
        sync_web_assets()
        if not skip_build:
            run(
                [
                    "xcodebuild",
                    "-scheme",
                    "App",
                    "-destination",
                    "platform=iOS Simulator,name=iPhone 17 Pro",
                    "-derivedDataPath",
                    str(DERIVED),
                    "build",
                ],
                cwd=EXAMPLE / "ios/App",
            )
        for attempt in range(1, MAX_ATTEMPTS + 1):
            print(f"\n=== iOS attempt {attempt}/{MAX_ATTEMPTS} ===")
            raw = ios_capture_raw(tmp)
            lock_im = load_rgb(raw["lock"])
            island_im = load_rgb(raw["island"])
            home_im = load_rgb(raw["home"])
            ok_lock, why_lock = validate_lock(lock_im)
            ok_island, why_island = validate_island(island_im)
            ok_home, why_home = validate_home(home_im)
            print("lock:", ok_lock, why_lock)
            print("island:", ok_island, why_island)
            print("home:", ok_home, why_home)
            if ok_lock and ok_island:
                export_ios(lock_im, island_im, home_im, tmp)
                report["ios"] = "ok" if ok_home else "ok-partial-home"
                if ok_home:
                    break
            time.sleep(3)
        else:
            if report.get("ios", "").startswith("ok"):
                pass
            else:
                report["ios"] = "failed"

        run(["./gradlew", ":app:assembleDebug"], cwd=EXAMPLE / "android")
        run(["bunx", "cap", "copy", "android"], cwd=EXAMPLE)
        base = start_serve_emul()
        for attempt in range(1, MAX_ATTEMPTS + 1):
            print(f"\n=== Android attempt {attempt}/{MAX_ATTEMPTS} ===")
            raw_android = android_capture_raw(tmp, base)
            if not raw_android.exists() or raw_android.stat().st_size < 10000:
                print("android: empty screencap")
                continue
            ok, why = validate_android(load_rgb(raw_android))
            print("android:", ok, why)
            if ok:
                crop_android(load_rgb(raw_android)).save(tmp / "android.png")
                to_webp(tmp / "android.png", DOCS / "android-app-widget.webp")
                report["android"] = "ok"
                break
            time.sleep(3)
        else:
            report["android"] = "failed"
    finally:
        patch_main_js(False)
    return report


def from_raw():
    tmp = Path("/tmp")
    lock = load_rgb(tmp / "cap-lock-raw.png")
    island = load_rgb(tmp / "cap-island-raw.png" if (tmp / "cap-island-raw.png").exists() else tmp / "cap-home2-raw.png")
    home = load_rgb(tmp / "cap-home2-raw.png")
    print("lock", validate_lock(lock), find_dark_card_bbox(lock))
    print("island", validate_island(island), find_top_accent_bbox(island))
    print("home", validate_home(home))
    if validate_lock(lock)[0] and validate_island(island)[0]:
        export_ios(lock, island, home, tmp)
        return 0
    return 1


def main():
    DOCS.mkdir(parents=True, exist_ok=True)
    skip_build = "--skip-build" in sys.argv
    report = capture_with_retries(skip_build=skip_build)
    print("REPORT", json.dumps(report, indent=2))
    ios_ok = report.get("ios", "").startswith("ok")
    return 0 if ios_ok and report.get("android") == "ok" else 1


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--from-raw":
        sys.exit(from_raw())
    sys.exit(main())
