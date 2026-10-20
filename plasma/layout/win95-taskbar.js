// Matrix 95 taskbar: ONE bottom panel, laid out like Windows 95:
//
//   [Start] [ task buttons ........................ ] [tray] [clock]
//
// Run it through the Plasma shell, for example:
//   qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat win95-taskbar.js)"
// It prints the new panel's id (digits only) so the caller can remember it.
//
// This script only ADDS a panel. It never removes or edits other panels or
// widgets; the installer backs up and removes the old panels itself.
//
// __START_ICON__ below is a placeholder that the installer replaces with the
// absolute path of the rendered Start button image (matrix95-start-button-<color>.svg). With the
// placeholder left in place Kickoff just falls back to its default icon.
//
// Plugin ids and config keys were checked against KDE plasma-desktop and
// plasma-workspace, branch Plasma/6.6:
//   org.kde.plasma.kickoff       group General: icon (String), menuLabel (String)
//   org.kde.plasma.taskmanager   group General: launchers, groupingStrategy,
//                                maxStripes, taskMaxWidth, showToolTips, ...
//                                (org.kde.plasma.icontasks is the icons-only
//                                 variant; taskmanager shows the text labels)
//   org.kde.plasma.systemtray
//   org.kde.plasma.digitalclock  group Appearance: showDate, ...

var panel = new Panel;

// Edge, size and behaviour. Height 32 matches the 2px bevel + 26px button row
// + 2px gap that the Matrix95 Plasma style (widgets/panel-background) is tuned for.
panel.location = "bottom";
panel.height = 32;
panel.floating = false;        // Windows 95 never floated
panel.hiding = "none";         // always visible
panel.lengthMode = "fill";     // full screen width
panel.alignment = "left";
panel.opacity = "opaque";      // the theme is opaque anyway; this avoids blur logic

// Start button: Kickoff showing one wide image (bevel + logo + "Start").
// Kickoff draws a non-square image at an absolute path at full width, and the
// label must be empty or it would be drawn a second time (Plasma/6.6
// applets/kickoff/main.qml, imageFallback). Panel applets get no frame, so
// this is the only way to give Start its raised Windows 95 bevel.
var start = panel.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "__START_ICON__");
start.writeConfig("menuLabel", "");
start.reloadConfig();

// Task buttons with text labels. No pinned launchers (Windows 95 had none in
// the task area), never group windows, one row.
var tasks = panel.addWidget("org.kde.plasma.taskmanager");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", []);
tasks.writeConfig("groupingStrategy", 0);   // 0 = do not group
tasks.writeConfig("maxStripes", 1);
tasks.writeConfig("taskMaxWidth", 2);       // 0 narrow, 1 medium, 2 wide
tasks.writeConfig("showToolTips", true);
tasks.writeConfig("highlightWindows", false);
tasks.reloadConfig();

// The task manager already fills the free width, so no spacer is needed:
// everything added after it sits against the right edge.

panel.addWidget("org.kde.plasma.systemtray");

// Time only, like the Windows 95 clock.
var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", false);
clock.reloadConfig();

print(panel.id);
