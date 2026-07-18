#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
model="$repo/versions/default/models/OmarchyMenuModel.js"

node - "$model" <<'NODE'
const fs = require("fs")
const vm = require("vm")
const path = process.argv[2]
const source = fs.readFileSync(path, "utf8").replace(/^\.pragma library\s*\n/, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context, { filename: path })

const empty = Object.entries(context.menuInfo)
    .filter(([id, info]) => id !== "root" && info.type === "submenu"
        && !info.dynamicSource && (!context.menus[id] || context.menus[id].length === 0))
    .map(([id]) => id)
if (empty.length) {
    console.error("FAIL: empty Super Menu submenus: " + empty.join(", "))
    process.exit(1)
}

const removeRows = context.menus.remove || []
if (!removeRows.some(row => row.actionId === "remove-theme")) {
    console.error("FAIL: Theme removal action missing")
    process.exit(1)
}
if (!removeRows.some(row => row.submenuId === "remove.security")) {
    console.error("FAIL: Security removal submenu missing")
    process.exit(1)
}
for (const id of ["trigger.hardware", "style.unlocks", "style.font"])
    if (!context.menuInfo[id] || !context.menuInfo[id].dynamicSource) {
        console.error("FAIL: dynamic menu source missing for " + id)
        process.exit(1)
    }
const malformed = Object.values(context.menus).flat()
    .filter(row => row.type === "action" && /--/.test(row.actionId || ""))
    .map(row => row.actionId)
if (malformed.length) {
    console.error("FAIL: malformed Super Menu action IDs: " + malformed.join(", "))
    process.exit(1)
}
console.log("ok (Super Menu has no empty submenus)")
NODE
