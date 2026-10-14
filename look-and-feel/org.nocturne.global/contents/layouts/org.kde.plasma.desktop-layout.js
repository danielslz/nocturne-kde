// Nocturne global theme — default desktop/panel layout
// A slim floating top panel + a centered, floating bottom dock (macOS-style).

var plasmaVersion = parseInt(plasma.getApiVersion(1)) || 1;

// ---- Desktop containment ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
}

// ---- Top panel: global menu-ish bar with clock + tray ----
var topPanel = new Panel();
topPanel.location = "top";
topPanel.height = Math.round(gridUnit * 1.6);
topPanel.floating = true;

var kickoff = topPanel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["Shortcuts"];
kickoff.writeConfig("global", "Alt+F1");

topPanel.addWidget("org.kde.plasma.appmenu");
topPanel.addWidget("org.kde.plasma.panelspacer");
topPanel.addWidget("org.kde.plasma.systemtray");
topPanel.addWidget("org.kde.plasma.digitalclock");

// ---- Bottom dock: centered, floating task manager ----
var dock = new Panel();
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3);
dock.floating = true;
// Center the dock and shrink it to content width
dock.alignment = "center";
dock.lengthMode = "fit";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", false);
