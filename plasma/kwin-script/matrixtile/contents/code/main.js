// Matrix Tile - a small master/stack auto-tiler for KWin 6 (part of matrix-rice).
//
// Layout per monitor and virtual desktop: the first window is the "main" one
// on the left, the rest are stacked on the right. Fullscreen windows (games),
// dialogs, pop-ups, maximized windows and anything you float are left alone.
//
// Shortcuts (change them in System Settings > Shortcuts > KWin):
//   Meta+Shift+T  tiling on/off        Meta+F      float/tile this window
//   Meta+Return   make this the main   Meta+[ / ]  shrink/grow the main area
//
// API names checked against KDE/kwin Plasma/6.6 (src/window.h,
// src/scripting/workspace_wrapper.h, src/scripting/scripting.cpp).

const GAP = Number(readConfig("Gap", 4));
const RATIO_MIN = 0.2;
const RATIO_MAX = 0.8;
// Window classes that never tile (games and launchers float). Matched as
// lower-case prefixes of the window's resource class.
const FLOAT_CLASSES = String(readConfig("FloatClasses",
    "steam,gamescope,lutris,heroic,net.lutris,com.heroicgameslauncher,minecraft,plasmashell,krunner,spectacle,polkit,ksplash,kscreenlocker,xwaylandvideobridge,yakuake"))
    .split(",").map(s => s.trim().toLowerCase()).filter(s => s.length > 0);

let enabled = Boolean(readConfig("Enabled", true));
let ratio = Number(readConfig("MainRatio", 0.58));
let busy = false;           // true while we move windows ourselves
const order = [];           // tracked windows; earlier = closer to "main"

// ---------- pure layout (also used by tests) ----------

// Rectangles for n windows in `area`: main on the left, stack on the right.
function layoutRects(n, area, mainRatio, gap) {
    const r = [];
    if (n <= 0) {
        return r;
    }
    const x = Math.round(area.x + gap), y = Math.round(area.y + gap);
    const w = Math.round(area.width - 2 * gap), h = Math.round(area.height - 2 * gap);
    if (n === 1) {
        r.push({ x: x, y: y, width: w, height: h });
        return r;
    }
    const mainW = Math.round((w - gap) * mainRatio);
    const stackX = x + mainW + gap;
    const stackW = w - mainW - gap;
    r.push({ x: x, y: y, width: mainW, height: h });
    const k = n - 1;
    const each = (h - gap * (k - 1)) / k;
    for (let i = 0; i < k; i++) {
        const top = Math.round(y + i * (each + gap));
        const bottom = Math.round(y + i * (each + gap) + each);
        r.push({ x: stackX, y: top, width: stackW, height: bottom - top });
    }
    return r;
}

// ---------- which windows tile ----------

function floatsByClass(w) {
    const cls = String(w.resourceClass || "").toLowerCase();
    return FLOAT_CLASSES.some(prefix => cls.startsWith(prefix));
}

function isCandidate(w) {
    return Boolean(w) && !w.deleted && w.managed && w.normalWindow && !w.transient &&
        !w.dialog && !w.utility && !w.splash && !w.popupWindow && !w.specialWindow &&
        !w.skipTaskbar && w.resizeable && w.moveable && !floatsByClass(w);
}

function isTiledNow(w) {
    return isCandidate(w) && !w.matrixTileFloating && !w.minimized && !w.fullScreen &&
        !w.maximizeMode && !w.tile;
}

function onDesktop(w, desktop) {
    return w.onAllDesktops || !w.desktops || w.desktops.length === 0 || w.desktops.includes(desktop);
}

function onActivity(w) {
    return !w.activities || w.activities.length === 0 || w.activities.includes(workspace.currentActivity);
}

// ---------- tiling ----------

function groupFor(output, desktop) {
    return order.filter(w => isTiledNow(w) && w.output === output && onDesktop(w, desktop) && onActivity(w));
}

function retile() {
    if (!enabled || busy) {
        return;
    }
    busy = true;
    try {
        const desktop = workspace.currentDesktop;
        for (const output of workspace.screens) {
            const wins = groupFor(output, desktop);
            const area = workspace.clientArea(KWin.PlacementArea, output, desktop);
            const rects = layoutRects(wins.length, area, ratio, GAP);
            wins.forEach((w, i) => {
                if (!w.matrixTilePrev) {
                    const g = w.frameGeometry;
                    w.matrixTilePrev = { x: g.x, y: g.y, width: g.width, height: g.height };
                }
                w.frameGeometry = rects[i];
            });
        }
    } finally {
        busy = false;
    }
}

function restore(w) {
    if (w && w.matrixTilePrev) {
        busy = true;
        w.frameGeometry = w.matrixTilePrev;
        busy = false;
        w.matrixTilePrev = undefined;
    }
}

// The user dragged a tiled window: drop it onto another tile to swap them,
// or resize it to change the main area's width.
function onUserMoveResize(w) {
    if (!enabled || !isTiledNow(w)) {
        return;
    }
    const desktop = workspace.currentDesktop;
    const wins = groupFor(w.output, desktop);
    const area = workspace.clientArea(KWin.PlacementArea, w.output, desktop);
    const rects = layoutRects(wins.length, area, ratio, GAP);
    const i = wins.indexOf(w);
    const g = w.frameGeometry;
    const cx = g.x + g.width / 2, cy = g.y + g.height / 2;
    const target = rects.findIndex(r => cx >= r.x && cx < r.x + r.width && cy >= r.y && cy < r.y + r.height);
    if (i >= 0 && target >= 0 && target !== i) {
        const a = order.indexOf(w), b = order.indexOf(wins[target]);
        order[a] = wins[target];
        order[b] = w;
    } else if (i >= 0 && wins.length > 1 && Math.abs(g.width - rects[i].width) > 2) {
        const inner = area.width - 3 * GAP;
        const mainW = i === 0 ? g.width : inner - g.width;
        ratio = Math.min(RATIO_MAX, Math.max(RATIO_MIN, mainW / inner));
    }
    retile();
}

function track(w) {
    if (!isCandidate(w) || order.includes(w)) {
        return;
    }
    order.push(w);
    w.minimizedChanged.connect(retile);
    w.fullScreenChanged.connect(retile);
    w.maximizedChanged.connect(retile);
    w.outputChanged.connect(retile);
    w.desktopsChanged.connect(retile);
    w.tileChanged.connect(retile);
    w.interactiveMoveResizeFinished.connect(() => onUserMoveResize(w));
}

function untrack(w) {
    const i = order.indexOf(w);
    if (i >= 0) {
        order.splice(i, 1);
    }
}

// ---------- shortcuts ----------

function toggleTiling() {
    enabled = !enabled;
    if (enabled) {
        retile();
    } else {
        order.forEach(restore);
    }
}

function toggleFloat() {
    const w = workspace.activeWindow;
    if (!isCandidate(w)) {
        return;
    }
    w.matrixTileFloating = !w.matrixTileFloating;
    if (w.matrixTileFloating) {
        restore(w);
    }
    retile();
}

function makeMain() {
    const w = workspace.activeWindow;
    if (!isTiledNow(w)) {
        return;
    }
    const wins = groupFor(w.output, workspace.currentDesktop);
    if (wins.length < 2 || wins[0] === w) {
        return;
    }
    const a = order.indexOf(w), b = order.indexOf(wins[0]);
    order[a] = wins[0];
    order[b] = w;
    retile();
}

function resizeMain(delta) {
    ratio = Math.min(RATIO_MAX, Math.max(RATIO_MIN, ratio + delta));
    retile();
}

// ---------- start ----------

function main() {
    workspace.windowList().forEach(track);
    workspace.windowAdded.connect(w => { track(w); retile(); });
    workspace.windowRemoved.connect(w => { untrack(w); retile(); });
    workspace.currentDesktopChanged.connect(retile);
    workspace.currentActivityChanged.connect(retile);
    workspace.screensChanged.connect(retile);

    registerShortcut("MatrixTileToggle", "Matrix Tile: turn tiling on/off", "Meta+Shift+T", toggleTiling);
    registerShortcut("MatrixTileFloat", "Matrix Tile: float or tile this window", "Meta+F", toggleFloat);
    registerShortcut("MatrixTileMain", "Matrix Tile: make this the main window", "Meta+Return", makeMain);
    registerShortcut("MatrixTileShrink", "Matrix Tile: shrink the main area", "Meta+[", () => resizeMain(-0.05));
    registerShortcut("MatrixTileGrow", "Matrix Tile: grow the main area", "Meta+]", () => resizeMain(0.05));

    retile();
}

main();
