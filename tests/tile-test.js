// Runs plasma/kwin-script/matrixtile/contents/code/main.js against a fake
// KWin (windows, screens, desktops, shortcuts) and checks the tiling.
// Usage: node tests/tile-test.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const SCRIPT = path.join(__dirname, "..", "plasma", "kwin-script", "matrixtile", "contents", "code", "main.js");

function signal() {
    const handlers = [];
    const s = (...args) => handlers.forEach(h => h(...args));
    s.connect = h => handlers.push(h);
    return s;
}

function makeWorld() {
    const desk1 = { id: "d1" }, desk2 = { id: "d2" };
    const left = { name: "eDP-1" }, right = { name: "HDMI-1" };
    const areas = new Map([[left, { x: 0, y: 0, width: 1920, height: 1048 }], [right, { x: 1920, y: 0, width: 1920, height: 1048 }]]);
    const windows = [];
    const shortcuts = {};
    const workspace = {
        currentDesktop: desk1,
        currentActivity: "a1",
        screens: [left, right],
        activeWindow: null,
        windowList: () => windows.slice(),
        clientArea: (opt, output) => areas.get(output),
        windowAdded: signal(), windowRemoved: signal(), currentDesktopChanged: signal(),
        currentActivityChanged: signal(), screensChanged: signal(),
    };
    const sandbox = {
        workspace,
        KWin: { PlacementArea: 0 },
        readConfig: (k, d) => d,
        registerShortcut: (name, text, keys, fn) => { shortcuts[name] = { keys, fn }; return true; },
        console,
    };
    function win(caption, props = {}) {
        const w = Object.assign({
            caption, deleted: false, managed: true, normalWindow: true, transient: false, dialog: false,
            utility: false, splash: false, popupWindow: false, specialWindow: false, skipTaskbar: false,
            resizeable: true, moveable: true, resourceClass: caption.toLowerCase(), minimized: false,
            fullScreen: false, maximizeMode: 0, tile: null, onAllDesktops: false, desktops: [desk1],
            activities: [], output: left, frameGeometry: { x: 100, y: 100, width: 800, height: 600 },
            minimizedChanged: signal(), fullScreenChanged: signal(), maximizedChanged: signal(),
            outputChanged: signal(), desktopsChanged: signal(), tileChanged: signal(),
            interactiveMoveResizeFinished: signal(),
        }, props);
        return w;
    }
    function add(w) { windows.push(w); workspace.windowAdded(w); return w; }
    function remove(w) { windows.splice(windows.indexOf(w), 1); workspace.windowRemoved(w); }
    return { workspace, sandbox, shortcuts, win, add, remove, desk1, desk2, left, right, areas };
}

let failures = 0;
function check(name, cond) {
    console.log(`  ${cond ? "\x1b[32mPASS\x1b[0m" : "\x1b[31mFAIL\x1b[0m"} ${name}`);
    if (!cond) failures++;
}
const inside = (r, a) => r.x >= a.x && r.y >= a.y && r.x + r.width <= a.x + a.width && r.y + r.height <= a.y + a.height;
const overlap = (a, b) => a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
const same = (a, b) => a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;

const W = makeWorld();
const editor = W.win("Kate", { frameGeometry: { x: 10, y: 20, width: 700, height: 500 } });
W.workspace.windowList = () => [editor];
vm.createContext(W.sandbox);
vm.runInContext(fs.readFileSync(SCRIPT, "utf8"), W.sandbox, { filename: "main.js" });
const A = W.areas.get(W.left);

console.log("== Matrix Tile");
check("registers its 5 shortcuts", Object.keys(W.shortcuts).length === 5);
check("on/off is Meta+Shift+T (Meta+T is KDE's tile editor)", W.shortcuts.MatrixTileToggle.keys === "Meta+Shift+T");
check("one window fills the screen minus 4px gaps", same(editor.frameGeometry, { x: 4, y: 4, width: 1912, height: 1040 }));

const term = W.add(W.win("Konsole"));
const browser = W.add(W.win("Firefox"));
const r = [editor, term, browser].map(w => w.frameGeometry);
check("three windows: main on the left, two stacked right", r[0].x < r[1].x && r[1].x === r[2].x && r[1].y < r[2].y);
check("main area is about 58% wide", Math.abs(r[0].width / 1908 - 0.58) < 0.01);
check("tiles stay on screen", r.every(g => inside(g, A)));
check("tiles never overlap", !overlap(r[0], r[1]) && !overlap(r[0], r[2]) && !overlap(r[1], r[2]));

const game = W.add(W.win("Game", { fullScreen: true, frameGeometry: { x: 0, y: 0, width: 1920, height: 1080 } }));
const steamGame = W.add(W.win("steam_app_1091500", { frameGeometry: { x: 0, y: 0, width: 1920, height: 1080 } }));
const dialog = W.add(W.win("Save As", { dialog: true, normalWindow: false, frameGeometry: { x: 600, y: 300, width: 500, height: 400 } }));
check("fullscreen game is not touched", same(game.frameGeometry, { x: 0, y: 0, width: 1920, height: 1080 }));
check("Steam/Proton game window is not touched", same(steamGame.frameGeometry, { x: 0, y: 0, width: 1920, height: 1080 }));
check("dialog is not touched", same(dialog.frameGeometry, { x: 600, y: 300, width: 500, height: 400 }));
check("games and dialogs don't change the layout", same(term.frameGeometry, r[1]));

browser.minimized = true; browser.minimizedChanged();
check("minimizing a window re-lays the others", term.frameGeometry.height > r[1].height);
browser.minimized = false; browser.minimizedChanged();

W.workspace.activeWindow = browser;
W.shortcuts.MatrixTileMain.fn();
check("Meta+Return makes the active window main", browser.frameGeometry.x === 4 && editor.frameGeometry.x > 4);

W.shortcuts.MatrixTileGrow.fn();
check("Meta+] grows the main area", browser.frameGeometry.width > r[0].width);

W.workspace.activeWindow = term;
W.shortcuts.MatrixTileFloat.fn();
check("Meta+F floats a window back to its old size", same(term.frameGeometry, { x: 100, y: 100, width: 800, height: 600 }));
check("...and the others re-tile without it", editor.frameGeometry.height === 1040);
W.shortcuts.MatrixTileFloat.fn();
check("Meta+F again tiles it", term.frameGeometry.x > 4 && term.frameGeometry.height < 1040);

const other = W.add(W.win("Dolphin", { output: W.right }));
check("second monitor tiles on its own", same(other.frameGeometry, { x: 1924, y: 4, width: 1912, height: 1040 }));

const desk2win = W.add(W.win("Spotify", { desktops: [W.desk2], frameGeometry: { x: 5, y: 5, width: 300, height: 300 } }));
check("windows on another virtual desktop are left alone", same(desk2win.frameGeometry, { x: 5, y: 5, width: 300, height: 300 }));

// Drag the editor onto the main tile: they swap.
const mainBefore = browser.frameGeometry;
editor.frameGeometry = { x: 200, y: 300, width: editor.frameGeometry.width, height: editor.frameGeometry.height };
editor.interactiveMoveResizeFinished();
check("dragging a window onto the main tile swaps them", editor.frameGeometry.x === 4 && same(editor.frameGeometry, mainBefore));

W.shortcuts.MatrixTileToggle.fn();
check("Meta+Shift+T off: windows go back to their own sizes", same(editor.frameGeometry, { x: 10, y: 20, width: 700, height: 500 }));
const t = W.add(W.win("Gwenview", { frameGeometry: { x: 50, y: 60, width: 640, height: 480 } }));
check("while off, new windows are not tiled", same(t.frameGeometry, { x: 50, y: 60, width: 640, height: 480 }));
W.shortcuts.MatrixTileToggle.fn();
check("Meta+Shift+T on: tiling comes back", t.frameGeometry.x > 4 && inside(t.frameGeometry, A));

W.remove(term);
const all = [browser, editor, t].map(w => w.frameGeometry);
check("closing a window closes the gap", all.every(g => inside(g, A)) && !overlap(all[0], all[1]) && !overlap(all[1], all[2]));

console.log(failures === 0 ? "ALL TILE TESTS PASSED" : `${failures} TILE TEST(S) FAILED`);
process.exit(failures === 0 ? 0 : 1);
