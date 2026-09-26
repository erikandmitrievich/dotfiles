// Firefox config
// Location: <profile folder>/user.js  (symlinked from dotfiles)
// Find the profile folder: about:support → "Profile Folder" → Show in Finder.
//
// Firefox applies these at every start, overriding the Settings page.
// Deleting a line does NOT undo it: set the opposite value, or reset the
// pref in about:config.

// ── Allow later customisation ──────────────────────────────
// Lets Firefox read chrome/userChrome.css (CSS for Firefox's own UI).
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.aboutConfig.showWarning", false);

// ── Layout ─────────────────────────────────────────────────
// Tabs as a vertical list on the left, like Arc.
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);
// No bookmarks bar; bookmarks are searched through Tridactyl (,b).
user_pref("browser.toolbars.bookmarks.visibility", "never");

// ── Tabs and startup ───────────────────────────────────────
// Reopen the previous session's windows and tabs.
user_pref("browser.startup.page", 3);
// Closing the last tab leaves an empty window instead of closing it.
user_pref("browser.tabs.closeWindowWithLastTab", false);

// ── Less clutter ───────────────────────────────────────────
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
// AI chatbot button in the sidebar.
user_pref("browser.ml.chat.enabled", false);

// ── Privacy ────────────────────────────────────────────────
// Strict tracking protection. If a uni/42 login page breaks, turn it off
// for that site only via the shield icon in the address bar.
user_pref("browser.contentblocking.category", "strict");
user_pref("dom.security.https_only_mode", true);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);

// ── Passwords ──────────────────────────────────────────────
// Uncomment only if you use browserpass (pass inside Firefox);
// it stops Firefox from offering to save passwords itself.
// user_pref("signon.rememberSignons", false);
