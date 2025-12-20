;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file—but you will after adding new modules/packages.

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for presentations
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;; Example:
;; (setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))

;; There are two ways to load a theme. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect.
;; If set to `nil', line numbers are disabled.
;; For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Here are some additional functions/macros that will help you configure Doom.
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path'
;; - `map!' for binding new keys
;; Use `C-h v` or `C-h f` to get documentation on any variable or function.

;; -------------------------------------------------------------------
;; BEGIN: JavaScript / TypeScript / Node.js REPL Setup
;; -------------------------------------------------------------------
;; (Requires you have enabled `:lang javascript +lsp +tree-sitter`
;;  and `:lang typescript +lsp` in your init.el, and installed:
;;    npm install -g typescript-language-server typescript eslint)

;; 1. LSP performance tweaks
(after! lsp-mode
  ;; Don’t watch node_modules (speeds up file watching)
  (add-to-list 'lsp-file-watch-ignored-directories "node_modules")
  (setq lsp-idle-delay 0.5
        lsp-log-io    nil))

;; 2. JS2 mode + LSP + Tree-sitter
(after! js2-mode
  (setq js-indent-level 2)
  (add-hook 'js2-mode-hook     #'lsp)
  (add-hook 'js2-mode-hook     #'tree-sitter-hl-mode))

;; 3. TypeScript mode + LSP + Tree-sitter
(after! typescript-mode
  (setq typescript-indent-level 2)
  (add-hook 'typescript-mode-hook #'lsp)
  (add-hook 'typescript-mode-hook #'tree-sitter-hl-mode))

;; 4. Node.js REPL integration
(use-package! nodejs-repl
  :after js2-mode
  :config
  (defun my-nodejs-repl-launch ()
    "Run Node.js REPL in the project root."
    (interactive)
    (let ((default-directory (projectile-project-root)))
      (run-nodejs)))
  (map! :map js2-mode-map
        :localleader
        "r" #'my-nodejs-repl-launch))

;; 5. Company completion tweaks
(after! company
  (setq company-minimum-prefix-length 1
        company-idle-delay          0.2))

;; 6. Flycheck: ESLint/TSLint
(after! flycheck
  (flycheck-add-mode 'javascript-eslint 'js2-mode)
  (flycheck-add-mode 'typescript-tslint 'typescript-mode))
;; -------------------------------------------------------------------
;; END: JavaScript / TypeScript / Node.js REPL Setup
;; -------------------------------------------------------------------

;; You can add further customizations below...

(use-package! org-modern
  :hook (org-mode . org-modern-mode))


;; ensure gptel is loaded when needed
(use-package! gptel
  :commands (gptel gptel-send gptel-rewrite gptel-menu)
  :config
  ;; for OpenAI/Anthropic API keys (ignore for Ollama)
  (setq gptel-api-key #'gptel-api-key-from-auth-source)
  ;; use Org for chat buffers
  (setq gptel-default-mode 'org-mode)

  ;; --- OpenAI backend ---
  (setq my/gptel-openai-backend
        (gptel-make-openai
         "OpenAI"
         :stream t
         :key gptel-api-key
         ;; :models '("gpt-5" "gpt-4")
         :models '(gpt-5 gpt-4 gpt-4o gpt-3.5-turbo)))

  ;; --- Ollama backend (local, no API key) ---
  (setq my/gptel-ollama-backend
        (gptel-make-ollama "Ollama"
          :host "localhost:11434"
          :stream t
          :models '(mistral:latest)))

  ;; Set Ollama as default
  (setq gptel-backend my/gptel-ollama-backend
        gptel-model 'mistral:latest))

;; PDF READER CSTMZ
(after! pdf-tools
  ;; (1) Set the midnight colours to something that matches your theme.
  ;;      (foreground . background)
  ;; (setq pdf-view-midnight-colors '("#9c9b98" . "#222222")) ; plain dark
  (setq pdf-view-midnight-colors '("#282c34" . "#222222")) ; doom one

  ;; (2) Auto-enable 'themed' mode (adapts to your active Emacs theme).
  ;; Use themed mode if you want PDFs to follow your theme automatically.
  (add-hook 'pdf-view-mode-hook (lambda () (pdf-view-themed-minor-mode 1)))

  ;; --- Alternative: always force classic midnight mode instead:
  ;; (add-hook 'pdf-view-mode-hook (lambda () (pdf-view-midnight-minor-mode 1)))

  ;; (3) Optional: some niceties for pdf-view-mode
  (setq pdf-view-resize-factor 1.1)   ; smoother zoom steps
  (add-hook 'pdf-view-mode-hook #'pdf-view-fit-width-to-window) ; fit width on open
  )


;; -----------------------------
;; Org Pomodoro
;; -----------------------------
(use-package! org-pomodoro
  :after org
  :config
  (setq org-pomodoro-finished-sound "/Users/ziro2173/.doom.d/sounds/pomodoro-boop.wav"
        org-pomodoro-short-break-sound t
        org-pomodoro-long-break-sound t
        org-pomodoro-length 25
        org-pomodoro-short-break-length 5
        org-pomodoro-long-break-length 15
        org-pomodoro-format "🍅 %s"
        org-pomodoro-short-break-format "☕ %s"
        org-pomodoro-long-break-format "🌙 %s")
)

;; --- Org Pomodoro Keybinding ---
(map! :after org
      :map org-mode-map
      :localleader
      "p" #'org-pomodoro)

;; --- Org Pomodoro Modeline ---
(require 'org-pomodoro)
(add-to-list 'global-mode-string 'org-pomodoro-mode-line)
