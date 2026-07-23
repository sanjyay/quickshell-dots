#!/usr/bin/env python3
import argparse
import configparser
import json
import os
import tempfile
import time


DEFAULT_APPLICATION_DIRS = (
    "~/.local/share/applications",
    "~/.local/share/flatpak/exports/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    "/usr/local/share/applications",
    "/usr/share/applications",
)
DEFAULT_ICON_DIRS = (
    "~/.local/share/icons",
    "~/.icons",
    "~/.local/share/flatpak/exports/share/icons",
    "/var/lib/flatpak/exports/share/icons",
    "/usr/local/share/icons",
    "/usr/share/icons",
    "/usr/share/pixmaps",
)
EXCLUDED_TERMS = ("avahi", "btop", "fcitx")


def expanded(paths):
    return [os.path.expanduser(path) for path in paths]


def resolve_icon(icon, icon_dirs):
    if not icon:
        return ""
    if icon.startswith("/"):
        return icon
    names = [icon] if os.path.splitext(icon)[1] else [icon + ext for ext in (".png", ".svg", ".xpm", ".svgz")]
    for base in icon_dirs:
        if not os.path.isdir(base):
            continue
        for root, _dirs, files in os.walk(base):
            available = set(files)
            for name in names:
                if name in available:
                    return os.path.join(root, name)
    return icon


def field(parser, key):
    return parser.get("Desktop Entry", key, fallback="").strip()


def scan(application_dirs, icon_dirs):
    apps = []
    seen = set()
    for directory in application_dirs:
        if not os.path.isdir(directory):
            continue
        for filename in sorted(os.listdir(directory)):
            if not filename.endswith(".desktop"):
                continue
            path = os.path.join(directory, filename)
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.optionxform = str
            try:
                parser.read(path, encoding="utf-8")
            except Exception:
                continue
            if not parser.has_section("Desktop Entry"):
                continue
            if field(parser, "NoDisplay").lower() == "true" or field(parser, "Hidden").lower() == "true":
                continue
            name, command = field(parser, "Name"), field(parser, "Exec")
            if not name or not command:
                continue
            search_key = (name + " " + command + " " + path).lower()
            if any(term in search_key for term in EXCLUDED_TERMS) or name in seen:
                continue
            seen.add(name)
            apps.append({
                "name": name,
                "exec": command,
                "icon": resolve_icon(field(parser, "Icon"), icon_dirs),
                "file": path,
                "categories": field(parser, "Categories"),
                "keywords": field(parser, "Keywords"),
                "mtime": int(os.path.getmtime(path)) if os.path.exists(path) else 0,
            })
    apps.sort(key=lambda app: app["name"].lower())
    return apps


def write_cache(cache, payload):
    directory = os.path.dirname(cache)
    os.makedirs(directory, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix="apps.", suffix=".json.tmp", dir=directory, text=True)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(payload, stream, ensure_ascii=False, separators=(",", ":"))
        os.replace(temporary, cache)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", default="~/.cache/quickshell/app-launcher/apps.json")
    parser.add_argument("--application-dir", action="append", dest="application_dirs")
    parser.add_argument("--icon-dir", action="append", dest="icon_dirs")
    return parser.parse_args()


def main():
    args = parse_args()
    cache = os.path.expanduser(args.cache)
    application_dirs = expanded(args.application_dirs or DEFAULT_APPLICATION_DIRS)
    icon_dirs = expanded(args.icon_dirs or DEFAULT_ICON_DIRS)
    print("APP_LAUNCHER rescan started cache=" + cache, file=__import__("sys").stderr)
    apps = scan(application_dirs, icon_dirs)
    payload = {"version": 1, "generatedAt": int(time.time()), "apps": apps}
    try:
        write_cache(cache, payload)
        print(f"APP_LAUNCHER cache write success count={len(apps)} path={cache}", file=__import__("sys").stderr)
    except Exception as error:
        print(f"APP_LAUNCHER cache write failure path={cache} error={error}", file=__import__("sys").stderr)
    print(json.dumps(payload, ensure_ascii=False))
    print(f"APP_LAUNCHER rescan finished count={len(apps)}", file=__import__("sys").stderr)


if __name__ == "__main__":
    main()
