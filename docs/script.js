const root = document.documentElement;
const themeButton = document.querySelector(".theme-toggle");
const languageButtons = [...document.querySelectorAll("[data-language-choice]")];

const copy = {
  de: {
    title: "CommitJet — Gute Commits. Ohne Kontextwechsel.",
    metaDescription: "CommitJet bringt Git in die macOS-Menüleiste: Änderungen gezielt stagen, lokale Branches verwalten, committen und optional Commit-Nachrichten mit Ollama vorschlagen lassen.",
    brandLabel: "CommitJet Startseite",
    navLabel: "Hauptnavigation",
    navFeatures: "Funktionen",
    navHow: "So geht’s",
    navPrivacy: "Datenschutz",
    languageLabel: "Sprache auswählen",
    themeLabel: "Farbschema wechseln",
    themeTitle: "Hell- oder Dunkelmodus",
    themeToDark: "Zu dunklem Farbschema wechseln",
    themeToLight: "Zu hellem Farbschema wechseln",
    downloadShort: "Laden",
    heroEyebrow: "Git für die Menüleiste deines Macs",
    heroTitle: "Gute Commits.<br><span>Ohne Kontextwechsel.</span>",
    heroText: "Prüfe Änderungen, stage gezielt Dateien, verwalte lokale Branches und erstelle Commits direkt aus der Menüleiste. Wenn du möchtest, schlägt Ollama eine Nachricht vor — CommitJet kann dich benachrichtigen, sobald sie bereit ist.",
    downloadMain: "CommitJet laden",
    downloadMac: "für macOS",
    explore: "Entdecke, was drinsteckt",
    requirements: "Für macOS 13 oder neuer <span>·</span> Kostenlos und Open Source",
    previewLabel: "Illustrative Vorschau der CommitJet Menüleisten-App",
    moreOptions: "Weitere Optionen",
    changedCount: "4 geänderte Dateien",
    commitPlaceholder: "Commit-Nachricht",
    messageLength: "Kurz",
    fileSelection: "Dateien (4/4)",
    selectedCount: "4 von 4 ausgewählt",
    selectAll: "Alle",
    selectNone: "Keine",
    stageSelected: "Auswahl stagen",
    unstageSelected: "Auswahl unstagen",
    stagedGroup: "Gestagt (2)",
    changesGroup: "Nicht gestagt (2)",
    fileModified: "Geändert",
    fileAdded: "Hinzugefügt",
    createCommit: "Commit erstellen",
    moreCommitActions: "Weitere Commit-Aktionen",
    settings: "Einstellungen",
    help: "Hilfe",
    quit: "Beenden",
    previewCaption: "Illustrative Oberfläche. Beispieldaten.",
    trustLabel: "CommitJet Eigenschaften",
    trustMenu: "Direkt in der Menüleiste",
    trustLocal: "Lokal und privat",
    trustAI: "KI nur auf Wunsch",
    trustOpen: "Open Source",
    featuresEyebrow: "Weniger drumherum. Mehr Flow.",
    featuresTitle: "Alles fürs Committen.<br><span>Nichts, was ablenkt.</span>",
    featuresIntro: "CommitJet macht die häufigsten Git-Schritte greifbar — ohne ein weiteres Fenster, das offen bleiben muss.",
    featureStageTitle: "Geänderte Dateien auf einen Blick.",
    featureStageText: "Sieh Dateipfade und Git-Status, wähle Dateien einzeln aus und stage oder unstage sie gezielt. In den Commit kommen ausschließlich gestagte Änderungen.",
    fileListLabel: "Vorschau der Dateiliste",
    fileListHeading: "Dateien (3/3)",
    miniSelected: "3 von 3 ausgewählt",
    miniAll: "Alle",
    miniNone: "Keine",
    miniStage: "Auswahl stagen",
    miniUnstage: "Auswahl unstagen",
    miniChanges: "Nicht gestagt (3)",
    featureAITitle: "Die Idee kommt von dir.<br>Der Vorschlag auch.",
    featureAIText: "Fordere auf Wunsch eine Nachricht aus dem gestagten Diff an. Ollama läuft standardmäßig lokal; du kannst den Vorschlag vor dem Commit prüfen und bearbeiten.",
    connected: "Verbunden",
    featureBranchTitle: "Branches wechseln.<br>Remote-Änderungen holen.",
    featureBranchText: "Lokale Branches suchen, anlegen, wechseln oder löschen. CommitJet holt Remote-Änderungen und aktualisiert deinen Branch per Fast-Forward, wenn das sicher möglich ist.",
    featureNotifyTitle: "Fertig? Du bekommst Bescheid.",
    featureNotifyText: "Wenn Ollama eine Commit-Nachricht erstellt hat, kann CommitJet dich mit einer macOS-Mitteilung darauf hinweisen.",
    workflowEyebrow: "So einfach ist der Ablauf",
    workflowTitle: "Von Änderung<br>zu Commit. <span>Weiter geht’s.</span>",
    workflowText: "Wähle ein lokales Repository aus, prüfe und stage die gewünschten Dateien und committe. Hole Änderungen vom Remote und pushe deine Commits, wenn du bereit bist.",
    githubLink: "CommitJet auf GitHub ansehen",
    step1Title: "Repository auswählen",
    step1Text: "Dein Projekt ist sofort griffbereit in der Menüleiste.",
    step2Title: "Änderungen prüfen",
    step2Text: "Branch, Dateistatus und Staging-Bereich auf einen Blick.",
    step3Title: "Committen und weitermachen",
    step3Text: "Ein guter Commit. Und zurück zu dem, was du gebaut hast.",
    privacyEyebrow: "Dein Code gehört dir.",
    privacyTitle: "Privat by design.",
    privacyText: "CommitJet hat keine Konten, Telemetrie oder eigene Cloud-Dienste. Git-Daten werden nicht automatisch übertragen. Wenn du Remote-Änderungen holst oder Commits synchronisierst, verbindet sich CommitJet mit dem konfigurierten Git-Remote. Nur wenn du einen KI-Vorschlag anforderst, geht der gestagte Diff an die in den Einstellungen konfigurierte Ollama-Adresse. Lokal ist die Standardeinstellung.",
    privacyPoint1: "Kein Tracking",
    privacyPoint2: "Kein Konto nötig",
    privacyPoint3: "Ollama standardmäßig lokal",
    downloadEyebrow: "Dein nächster Commit wartet.",
    downloadTitle: "Mach’s dir einfach.",
    downloadText: "Ein kleines Tool. Ein klarer Kopf. Und schon bist du wieder bei deiner Arbeit.",
    downloadMeta: "macOS 13 oder neuer · Kostenlos · Open Source",
    downloadWarning: "Beim ersten Öffnen kann macOS eine Warnung zeigen.",
    downloadHelp: "Hier steht, wie du CommitJet öffnest.",
    footerLine: "Gebaut für deinen Flow. Auf deinem Mac.",
    footerReleases: "Releases",
    footerLicense: "MIT-Lizenz"
  },
  en: {
    title: "CommitJet — Good commits. No context switching.",
    metaDescription: "Bring Git to the macOS menu bar: stage selected changes, manage local branches, commit, and optionally ask Ollama for commit message suggestions.",
    brandLabel: "CommitJet home",
    navLabel: "Main navigation",
    navFeatures: "Features",
    navHow: "How it works",
    navPrivacy: "Privacy",
    languageLabel: "Choose language",
    themeLabel: "Change color theme",
    themeTitle: "Light or dark mode",
    themeToDark: "Switch to dark mode",
    themeToLight: "Switch to light mode",
    downloadShort: "Download",
    heroEyebrow: "Git in your Mac’s menu bar",
    heroTitle: "Good commits.<br><span>No context switching.</span>",
    heroText: "Review changes, stage selected files, manage local branches, and create commits from your menu bar. Ask Ollama for a message if you want; CommitJet can notify you when it is ready.",
    downloadMain: "Download CommitJet",
    downloadMac: "for macOS",
    explore: "See what it can do",
    requirements: "For macOS 13 or later <span>·</span> Free and open source",
    previewLabel: "Illustrative preview of the CommitJet menu bar app",
    moreOptions: "More options",
    changedCount: "4 changed files",
    commitPlaceholder: "Commit message",
    messageLength: "Short",
    fileSelection: "Files (4/4)",
    selectedCount: "4 of 4 selected",
    selectAll: "All",
    selectNone: "None",
    stageSelected: "Stage selected",
    unstageSelected: "Unstage selected",
    stagedGroup: "Staged (2)",
    changesGroup: "Unstaged (2)",
    fileModified: "Modified",
    fileAdded: "Added",
    createCommit: "Create commit",
    moreCommitActions: "More commit actions",
    settings: "Settings",
    help: "Help",
    quit: "Quit",
    previewCaption: "Illustrative interface. Sample data.",
    trustLabel: "CommitJet highlights",
    trustMenu: "Right in the menu bar",
    trustLocal: "Local and private",
    trustAI: "AI only when you ask",
    trustOpen: "Open source",
    featuresEyebrow: "Less overhead. More flow.",
    featuresTitle: "Everything you need to commit.<br><span>Nothing to distract you.</span>",
    featuresIntro: "CommitJet puts everyday Git actions within reach — without another window to keep open.",
    featureStageTitle: "See changed files at a glance.",
    featureStageText: "Review file paths and Git status, select files individually, and stage or unstage them. Commits include staged changes only.",
    fileListLabel: "Preview of the changed files list",
    fileListHeading: "Files (3/3)",
    miniSelected: "3 of 3 selected",
    miniAll: "All",
    miniNone: "None",
    miniStage: "Stage selected",
    miniUnstage: "Unstage selected",
    miniChanges: "Unstaged (3)",
    featureAITitle: "Your idea first.<br>A suggestion if you want one.",
    featureAIText: "Request a message from the staged diff when you want one. Ollama runs locally by default, and you can review and edit the suggestion before committing.",
    connected: "Connected",
    featureBranchTitle: "Switch branches.<br>Pull remote changes.",
    featureBranchText: "Search, create, switch, and delete local branches. CommitJet fetches remote changes and fast-forwards your branch when it is safe to do so.",
    featureNotifyTitle: "Ready? You’ll know.",
    featureNotifyText: "When Ollama finishes a commit message, CommitJet can let you know with a macOS notification.",
    workflowEyebrow: "A simple workflow",
    workflowTitle: "From a change<br>to a commit. <span>Then move on.</span>",
    workflowText: "Choose a local repository, review and stage the files you want, then commit. Pull remote changes and push your commits when you’re ready.",
    githubLink: "Explore CommitJet on GitHub",
    step1Title: "Choose a repository",
    step1Text: "Your project is ready to open from the menu bar.",
    step2Title: "Review your changes",
    step2Text: "See your branch, file status, and staging area at a glance.",
    step3Title: "Commit and get back to it",
    step3Text: "One good commit, then back to what you’re building.",
    privacyEyebrow: "Your code belongs to you.",
    privacyTitle: "Private by design.",
    privacyText: "CommitJet has no accounts, telemetry, or cloud services of its own. Git data is never sent automatically. When you fetch remote changes or synchronize commits, CommitJet contacts the configured Git remote. Only when you request an AI suggestion, the staged diff is sent to the Ollama address configured in Settings. A local server is the default.",
    privacyPoint1: "No tracking",
    privacyPoint2: "No account needed",
    privacyPoint3: "Ollama local by default",
    downloadEyebrow: "Your next commit is waiting.",
    downloadTitle: "Make it easy.",
    downloadText: "A small tool. A clear head. Then you’re straight back to your work.",
    downloadMeta: "macOS 13 or later · Free · Open source",
    downloadWarning: "macOS may show a warning the first time you open the app.",
    downloadHelp: "See how to open CommitJet.",
    footerLine: "Made for your flow. On your Mac.",
    footerReleases: "Releases",
    footerLicense: "MIT License"
  }
};

function readPreference(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function savePreference(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // The choice still applies for the current visit when storage is unavailable.
  }
}

function updateThemeButton(language) {
  const labels = copy[language];
  themeButton.setAttribute("aria-label", root.dataset.theme === "dark" ? labels.themeToLight : labels.themeToDark);
  themeButton.title = labels.themeTitle;
}

function setLanguage(language) {
  if (!copy[language]) return;
  const labels = copy[language];
  root.dataset.language = language;
  root.lang = language;
  document.title = labels.title;

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.dataset.i18n;
    if (labels[key] !== undefined) element.innerHTML = labels[key];
  });
  document.querySelectorAll("[data-i18n-aria]").forEach((element) => {
    const key = element.dataset.i18nAria;
    if (labels[key] !== undefined) element.setAttribute("aria-label", labels[key]);
  });
  document.querySelectorAll("[data-i18n-title]").forEach((element) => {
    const key = element.dataset.i18nTitle;
    if (labels[key] !== undefined) element.title = labels[key];
  });
  document.querySelectorAll("[data-i18n-content]").forEach((element) => {
    const key = element.dataset.i18nContent;
    if (labels[key] !== undefined) element.content = labels[key];
  });
  languageButtons.forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.languageChoice === language));
  });
  updateThemeButton(language);
  savePreference("commitjet-language", language);
}

let savedTheme = readPreference("commitjet-theme");
if (savedTheme === "light" || savedTheme === "dark") {
  root.dataset.theme = savedTheme;
} else if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
  root.dataset.theme = "dark";
}

const savedLanguage = readPreference("commitjet-language");
setLanguage(savedLanguage === "en" ? "en" : "de");

languageButtons.forEach((button) => {
  button.addEventListener("click", () => setLanguage(button.dataset.languageChoice));
});

themeButton.addEventListener("click", () => {
  root.dataset.theme = root.dataset.theme === "dark" ? "light" : "dark";
  savePreference("commitjet-theme", root.dataset.theme);
  updateThemeButton(root.dataset.language);
  document.querySelector('meta[name="theme-color"]').content = root.dataset.theme === "dark" ? "#10141b" : "#f7f8fa";
});
