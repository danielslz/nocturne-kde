// Nocturne global theme — default desktop/panel layout (Plasma 6)
//
// Estratégia defensiva: SEMPRE começa carregando o painel padrão via template.
// Assim, se qualquer passo adicional falhar, o usuário nunca fica sem painel
// (foi esse o bug da versão anterior, que usava propriedades inexistentes como
// `panel.floating` / `panel.lengthMode` e abortava deixando o desktop vazio).

// 1) Painel padrão garantido -------------------------------------------------
loadTemplate("org.kde.plasma.desktop.defaultPanel")

// 2) Papel de parede ---------------------------------------------------------
try {
    var desktopsArray = desktopsForActivity(currentActivity());
    for (var j = 0; j < desktopsArray.length; j++) {
        desktopsArray[j].wallpaperPlugin = "org.kde.image";
    }
} catch (e) { /* ignora: não vale deixar o desktop sem painel por causa do wallpaper */ }

// 3) Painel superior estilo macOS (menu global + relógio + bandeja) ----------
//    Envolto em try/catch: se algo falhar, o painel padrão do passo 1 continua.
try {
    var topPanel = new Panel();
    topPanel.location = "top";
    topPanel.height = Math.round(gridUnit * 1.6);

    // "flutuante" é uma opção de configuração do containment do painel,
    // não uma propriedade do objeto Panel na API de script.
    topPanel.currentConfigGroup = ["Configuration", "General"];
    topPanel.writeConfig("floating", true);

    topPanel.addWidget("org.kde.plasma.kickoff");
    topPanel.addWidget("org.kde.plasma.appmenu");
    topPanel.addWidget("org.kde.plasma.panelspacer");
    topPanel.addWidget("org.kde.plasma.systemtray");
    topPanel.addWidget("org.kde.plasma.digitalclock");
} catch (e) { /* mantém apenas o painel padrão */ }

// 4) Dock inferior centralizado e flutuante ----------------------------------
try {
    var dock = new Panel();
    dock.location = "bottom";
    dock.height = Math.round(gridUnit * 3);
    dock.alignment = "center";

    dock.currentConfigGroup = ["Configuration", "General"];
    dock.writeConfig("floating", true);

    var tasks = dock.addWidget("org.kde.plasma.icontasks");
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", [
        "preferred://filemanager",
        "applications:org.kde.konsole.desktop",
        "preferred://browser"
    ]);
    tasks.writeConfig("showOnlyCurrentDesktop", false);
    tasks.reloadConfig();
} catch (e) { /* mantém o painel padrão + topo, se o dock falhar */ }
