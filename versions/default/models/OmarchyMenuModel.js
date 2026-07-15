.pragma library

// The action IDs are stable UI contracts. Shell execution is deliberately
// delegated to qs-menu-action.sh; this file contains no executable commands.
var entries = [
    { id: "apps", parent: "root", kind: "action", icon: "󰀻", label: "Apps", detail: "Application launcher", action: "apps" },
    { id: "learn", parent: "root", kind: "menu", icon: "󰧑", label: "Learn", detail: "Manuals and reference" },
    { id: "trigger", parent: "root", kind: "menu", icon: "󱓞", label: "Trigger", detail: "Capture, share and toggles" },
    { id: "style", parent: "root", kind: "menu", icon: "", label: "Style", detail: "Theme, wallpaper and appearance" },
    { id: "setup", parent: "root", kind: "menu", icon: "", label: "Setup", detail: "Devices and configuration" },
    { id: "install", parent: "root", kind: "menu", icon: "󰉉", label: "Install", detail: "Packages and applications" },
    { id: "remove", parent: "root", kind: "menu", icon: "󰭌", label: "Remove", detail: "Uninstall applications and features" },
    { id: "update", parent: "root", kind: "menu", icon: "", label: "Update", detail: "System and service updates" },
    { id: "about", parent: "root", kind: "action", icon: "", label: "About", detail: "About this system", action: "about" },
    { id: "system", parent: "root", kind: "menu", icon: "", label: "System", detail: "Power and session" },

    { id: "learn.keybindings", parent: "learn", kind: "action", icon: "", label: "Keybindings", action: "learn.keybindings" },
    { id: "learn.omarchy", parent: "learn", kind: "action", icon: "", label: "Omarchy", action: "learn.omarchy" },
    { id: "learn.hyprland", parent: "learn", kind: "action", icon: "", label: "Hyprland", action: "learn.hyprland" },
    { id: "learn.arch", parent: "learn", kind: "action", icon: "󰣇", label: "Arch", action: "learn.arch" },
    { id: "learn.neovim", parent: "learn", kind: "action", icon: "", label: "Neovim", action: "learn.neovim" },
    { id: "learn.bash", parent: "learn", kind: "action", icon: "󱆃", label: "Bash", action: "learn.bash" },

    { id: "trigger.reminder", parent: "trigger", kind: "menu", icon: "󰔛", label: "Reminder" },
    { id: "trigger.capture", parent: "trigger", kind: "menu", icon: "", label: "Capture" },
    { id: "trigger.transcode", parent: "trigger", kind: "action", icon: "󰧸", label: "Transcode", action: "trigger.transcode" },
    { id: "trigger.share", parent: "trigger", kind: "menu", icon: "", label: "Share" },
    { id: "trigger.toggle", parent: "trigger", kind: "menu", icon: "󰔎", label: "Toggle" },
    { id: "trigger.hardware", parent: "trigger", kind: "menu", icon: "", label: "Hardware" },
    { id: "trigger.capture.screenshot", parent: "trigger.capture", kind: "action", icon: "", label: "Screenshot", action: "capture.screenshot" },
    { id: "trigger.capture.screenrecord", parent: "trigger.capture", kind: "action", icon: "", label: "Screenrecord", action: "capture.screenrecord" },
    { id: "trigger.capture.text", parent: "trigger.capture", kind: "action", icon: "󰴑", label: "Text Extraction", action: "capture.text" },
    { id: "trigger.capture.color", parent: "trigger.capture", kind: "action", icon: "󰃉", label: "Color", action: "capture.color" },
    { id: "trigger.reminder.set", parent: "trigger.reminder", kind: "action", icon: "󰔛", label: "Set one", action: "reminder.set" },
    { id: "trigger.reminder.show", parent: "trigger.reminder", kind: "action", icon: "󰔛", label: "Show all", action: "reminder.show" },
    { id: "trigger.reminder.clear", parent: "trigger.reminder", kind: "action", icon: "󰔛", label: "Clear all", action: "reminder.clear" },
    { id: "trigger.share.clipboard", parent: "trigger.share", kind: "action", icon: "", label: "Clipboard", action: "share.clipboard" },
    { id: "trigger.share.file", parent: "trigger.share", kind: "action", icon: "", label: "File", action: "share.file" },
    { id: "trigger.share.folder", parent: "trigger.share", kind: "action", icon: "", label: "Folder", action: "share.folder" },

    { id: "system.screensaver", parent: "system", kind: "action", icon: "󱄄", label: "Screensaver", action: "system.screensaver" },
    { id: "system.lock", parent: "system", kind: "action", icon: "", label: "Lock", action: "system.lock" },
    { id: "system.suspend", parent: "system", kind: "action", icon: "󰒲", label: "Suspend", action: "system.suspend", confirm: false },
    { id: "system.hibernate", parent: "system", kind: "action", icon: "󰤁", label: "Hibernate", action: "system.hibernate", confirm: false },
    { id: "system.logout", parent: "system", kind: "action", icon: "󰍃", label: "Logout", action: "system.logout", confirm: true },
    { id: "system.restart", parent: "system", kind: "action", icon: "󰜉", label: "Restart", action: "system.restart", confirm: true },
    { id: "system.shutdown", parent: "system", kind: "action", icon: "󰐥", label: "Shutdown", action: "system.shutdown", confirm: true }
]

// The installed Omarchy menu has a large set of backend-driven leaves. Keep
// those routes visible in the native menu as well; the dispatcher deliberately
// hands package/configuration work back to Omarchy's trusted helpers.
function addMenu(id, parent, label, detail) { entries.push({ id: id, parent: parent, kind: "menu", icon: "•", label: label, detail: detail || "" }) }
function addAction(id, parent, label, action) { entries.push({ id: id, parent: parent, kind: "action", icon: "•", label: label, action: action || id }) }
function addLegacyLeaves(parent, labels, route) {
    for (var i = 0; i < labels.length; i++)
        addAction(parent + "." + labels[i].toLowerCase().replace(/[^a-z0-9]+/g, "-"), parent, labels[i], "legacy." + route)
}

addMenu("style.theme", "style", "Theme", "Choose the active theme")
addMenu("style.font", "style", "Font", "Choose the system font")
addAction("style.unlocks", "style", "Unlock", "legacy.style.unlocks")
addAction("style.background", "style", "Background", "legacy.style.background")
addAction("style.hyprland", "style", "Hyprland", "legacy.style.hyprland")
addMenu("style.screensaver", "style", "Screensaver", "Screensaver branding")
addMenu("style.about", "style", "About", "About branding")
for (var styleLeaf of ["Edit Text", "Set From Image", "Restore Default"]) {
    addAction("style.screensaver." + styleLeaf.toLowerCase().replace(/ /g, "-"), "style.screensaver", styleLeaf, "legacy.style.screensaver")
    addAction("style.about." + styleLeaf.toLowerCase().replace(/ /g, "-"), "style.about", styleLeaf, "legacy.style.about")
}

for (var setup of ["Audio", "Wifi", "Bluetooth", "Power Profile", "System Sleep", "Monitors", "Keybindings", "Input", "Defaults", "DNS", "Security", "Config"])
    addMenu("setup." + setup.toLowerCase().replace(/ /g, "-"), "setup", setup)
for (var config of ["Hyprland", "Hypridle", "Hyprlock", "Hyprsunset", "SwayOSD", "Walker", "Waybar", "XCompose"])
    addAction("setup.config." + config.toLowerCase(), "setup.config", config, "legacy.setup.config")
for (var security of ["Fingerprint", "Fido2"])
    addAction("setup.security." + security.toLowerCase(), "setup.security", security, "legacy.setup.security")
for (var def of ["Browser", "Terminal", "Editor"])
    addMenu("setup.defaults." + def.toLowerCase(), "setup.defaults", def)

for (var installGroup of ["Package", "AUR", "Web App", "TUI", "Service", "Style", "Development", "Editor", "Terminal", "Browser", "AI", "Gaming", "Windows"])
    addMenu("install." + installGroup.toLowerCase().replace(/ /g, "-"), "install", installGroup)
for (var removeGroup of ["Package", "Web App", "TUI", "Development", "Theme", "Browser", "Dictation", "Gaming", "Windows", "Preinstalls", "Security"])
    addMenu("remove." + removeGroup.toLowerCase().replace(/ /g, "-"), "remove", removeGroup)
for (var updateGroup of ["Omarchy", "Channel", "Config", "Extra Themes", "Process", "Hardware", "Firmware", "Password", "Timezone", "Time"])
    addMenu("update." + updateGroup.toLowerCase().replace(/ /g, "-"), "update", updateGroup)

addLegacyLeaves("install.service", ["Dropbox", "Tailscale", "NordVPN", "ONCE", "Bitwarden", "Chromium Account"], "install.service")
addLegacyLeaves("install.style", ["Theme", "Background", "Font"], "install.style")
addLegacyLeaves("install.development", ["Ruby on Rails", "Docker DB", "JavaScript", "Go", "PHP", "Python", "Elixir", "Zig", "Rust", "Java", ".NET", "OCaml", "Clojure", "Scala"], "install.development")
addLegacyLeaves("install.editor", ["VSCode", "Cursor", "Zed", "Sublime Text", "Helix", "Vim", "Emacs"], "install.editor")
addLegacyLeaves("install.terminal", ["Alacritty", "Foot", "Ghostty", "Kitty"], "install.terminal")
addLegacyLeaves("install.browser", ["Chrome", "Edge", "Brave", "Brave Origin", "Firefox", "Zen"], "install.browser")
addLegacyLeaves("install.ai", ["Dictation", "LM Studio", "Ollama", "Crush"], "install.ai")
addLegacyLeaves("install.gaming", ["Steam", "RetroArch", "Minecraft", "NVIDIA GeForce NOW", "Xbox Cloud Gaming", "Xbox Controller", "Moonlight", "Lutris", "Heroic"], "install.gaming")
addLegacyLeaves("remove.development", ["Ruby on Rails", "JavaScript", "Go", "PHP", "Python", "Elixir", "Zig", "Rust", "Java", ".NET", "OCaml", "Clojure", "Scala"], "remove.development")
addLegacyLeaves("remove.browser", ["Chrome", "Edge", "Brave", "Brave Origin", "Firefox", "Zen"], "remove.browser")
addLegacyLeaves("remove.gaming", ["Steam", "RetroArch", "Minecraft", "NVIDIA GeForce NOW", "Xbox Cloud Gaming", "Xbox Controller", "Moonlight", "Lutris", "Heroic"], "remove.gaming")
addLegacyLeaves("update.channel", ["Stable", "RC", "Edge", "Dev"], "update.channel")
addLegacyLeaves("update.config", ["Hyprland", "Hypridle", "Hyprlock", "Hyprsunset", "Plymouth", "SwayOSD", "Tmux", "Walker", "Waybar"], "update.config")
addLegacyLeaves("update.process", ["Hypridle", "Hyprsunset", "Mako", "SwayOSD", "Walker", "Waybar"], "update.process")
addLegacyLeaves("update.hardware", ["Audio", "Wi-Fi", "Bluetooth", "Trackpad"], "update.hardware")

for (var captureMode of ["With no audio", "With desktop audio", "With desktop + microphone audio", "With desktop + microphone audio + webcam"])
    addAction("trigger.capture.recording." + captureMode.toLowerCase().replace(/[^a-z]+/g, "-"), "trigger.capture", captureMode, "capture.screenrecord")

function children(parent) {
    return entries.filter(function(entry) { return entry.parent === parent })
}

function find(id) {
    return entries.find(function(entry) { return entry.id === id }) || null
}
