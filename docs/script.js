const root = document.documentElement;
const themeButton = document.querySelector(".theme-toggle");
const languageButtons = [...document.querySelectorAll("[data-language-choice]")];

const copy = {
  de: {
    title: "CommitJet — Gute Commits. Ohne Kontextwechsel.",
    metaDescription: "CommitJet bringt Git in die Menüleiste deines Macs. Committe gezielt, wechsle Branches und lass dir optional lokal Commit-Nachrichten vorschlagen.",
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
    heroText: "Git gehört in deinen Flow. CommitJet bringt Branches, Änderungen und Commits direkt in die Menüleiste — klar, schnell und ganz bei dir.",
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
    stageSelected: "Auswahl vormerken",
    unstageSelected: "Vormerkung aufheben",
    stagedGroup: "Gestagete Änderungen (2)",
    changesGroup: "Änderungen (2)",
    fileModified: "Geändert",
    fileAdded: "Hinzugefügt",
    syncUpToDate: "Synchronisiert",
    createCommit: "Commit erstellen",
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
    featureStageText: "CommitJet zeigt Dateinamen und ihren Status. Wähle gezielt aus, welche Dateien du fürs Staging vormerken willst.",
    fileListLabel: "Vorschau der Dateiliste",
    fileListHeading: "Dateien (3/3)",
    miniSelected: "3 von 3 ausgewählt",
    miniAll: "Alle",
    miniNone: "Keine",
    miniStage: "Auswahl vormerken",
    miniUnstage: "Vormerkung aufheben",
    miniChanges: "Änderungen (3)",
    featureAITitle: "Die Idee kommt von dir.<br>Der Vorschlag auch.",
    featureAIText: "Optional schlägt Ollama eine Commit-Nachricht vor. Standardmäßig lokal — und du entscheidest, ob du den Text übernimmst.",
    connected: "Verbunden",
    featureBranchTitle: "Branch wechseln.<br>Im Flow bleiben.",
    featureBranchText: "Lokale Branches suchen und wechseln. CommitJet zeigt dir, wenn ungesicherte Änderungen einem Wechsel im Weg stehen.",
    workflowEyebrow: "So einfach ist der Ablauf",
    workflowTitle: "Von Änderung<br>zu Commit. <span>Weiter geht’s.</span>",
    workflowText: "Wähle ein Repository aus. Prüfe, was sich geändert hat. Committe — oder synchronisiere deinen Branch, wenn du bereit bist.",
    githubLink: "CommitJet auf GitHub ansehen",
    step1Title: "Repository auswählen",
    step1Text: "Dein Projekt ist sofort griffbereit in der Menüleiste.",
    step2Title: "Änderungen prüfen",
    step2Text: "Branch, Dateistatus und Staging-Bereich auf einen Blick.",
    step3Title: "Committen und weitermachen",
    step3Text: "Ein guter Commit. Und zurück zu dem, was du gebaut hast.",
    privacyEyebrow: "Dein Code gehört dir.",
    privacyTitle: "Privat by design.",
    privacyText: "CommitJet hat keine Konten, keine Telemetrie und keine Cloud-Anbindung. Git-Daten werden nicht automatisch hochgeladen. KI-Vorschläge sind optional und standardmäßig lokal.",
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
    metaDescription: "Bring Git to your Mac menu bar. Stage exactly what you want, switch branches, and optionally get local commit message suggestions with CommitJet.",
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
    heroText: "Git belongs in your flow. CommitJet brings branches, changes, and commits to your menu bar — clear, quick, and yours.",
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
    stagedGroup: "Staged Changes (2)",
    changesGroup: "Changes (2)",
    fileModified: "Modified",
    fileAdded: "Added",
    syncUpToDate: "Up to date",
    createCommit: "Create commit",
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
    featureStageText: "CommitJet shows file names and their status. Choose exactly which files to stage.",
    fileListLabel: "Preview of the changed files list",
    fileListHeading: "Files (3/3)",
    miniSelected: "3 of 3 selected",
    miniAll: "All",
    miniNone: "None",
    miniStage: "Stage selected",
    miniUnstage: "Unstage selected",
    miniChanges: "Changes (3)",
    featureAITitle: "Your idea first.<br>A suggestion if you want one.",
    featureAIText: "Ollama can suggest a commit message when you ask. It runs locally by default, and you decide whether to use the suggestion.",
    connected: "Connected",
    featureBranchTitle: "Switch branches.<br>Stay in your flow.",
    featureBranchText: "Find and switch local branches. CommitJet lets you know when uncommitted changes would get in the way.",
    workflowEyebrow: "A simple workflow",
    workflowTitle: "From a change<br>to a commit. <span>Then move on.</span>",
    workflowText: "Choose a repository. Review what changed. Commit, or sync your branch when you’re ready.",
    githubLink: "Explore CommitJet on GitHub",
    step1Title: "Choose a repository",
    step1Text: "Your project is ready to open from the menu bar.",
    step2Title: "Review your changes",
    step2Text: "See your branch, file status, and staging area at a glance.",
    step3Title: "Commit and get back to it",
    step3Text: "One good commit, then back to what you’re building.",
    privacyEyebrow: "Your code belongs to you.",
    privacyTitle: "Private by design.",
    privacyText: "CommitJet has no accounts, telemetry, or cloud integration. Git data is never uploaded automatically. AI suggestions are optional and use a local server by default.",
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
