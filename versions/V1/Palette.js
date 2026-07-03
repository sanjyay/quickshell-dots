.pragma library

// WANTED is the single source of truth for which raw colors.toml keys map
// onto this shell's semantic slots. Both the startup FileView read and the
// IPC push path translate through it.
const WANTED = {
    background: "paper",
    foreground: "ink",
    color7:     "inkDeep",
    color8:     "sumi",
    color1:     "sealRaw",
    color2:     "color02",
    color3:     "color03",
    color4:     "indigo",
    accent:     "accentHint",
};

const LINE = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;

function parseAll(text) {
    const out = {};
    if (!text) return out;
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const m = lines[i].match(LINE);
        if (m) out[m[1].toLowerCase()] = m[2];
    }
    return out;
}

function mapKeys(raw) {
    const out = {};
    if (!raw) return out;
    for (const key in WANTED) {
        if (raw[key]) out[WANTED[key]] = raw[key];
    }
    return out;
}

function parse(text) {
    return mapKeys(parseAll(text));
}

function validColor(value) {
    return typeof value === "string" && /^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(value);
}

function setColor(theme, key, value) {
    if (validColor(value)) theme[key] = value;
}

// Write a parsed palette onto a Theme.qml instance. Missing slots are left
// at their current value so a partial or malformed palette never blanks the
// live theme. Omarchy colors.toml values used by this shell are #RRGGBB; accept
// #RRGGBBAA too for forward-compatible alpha colours.
function apply(theme, palette) {
    if (!palette) return;
    setColor(theme, "paper",      palette.paper);
    setColor(theme, "ink",        palette.ink);
    setColor(theme, "inkDeep",    palette.inkDeep);
    setColor(theme, "sumi",       palette.sumi);
    setColor(theme, "indigo",     palette.indigo);
    setColor(theme, "sealRaw",    palette.sealRaw);
    setColor(theme, "color02",    palette.color02);
    setColor(theme, "color03",    palette.color03);
    setColor(theme, "accentHint", palette.accentHint);
}
