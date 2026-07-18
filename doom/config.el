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
;; --------------------------

;; You can add further customizations below...

(use-package! org-modern
  :hook (org-mode . org-modern-mode))


(use-package! gptel
  :config
  (setq gptel-default-mode 'org-mode)

  ;; 1. OVERWRITE the default "ChatGPT" backend
  ;; By naming this "ChatGPT" (instead of "OpenAI"), we replace the built-in
  ;; backend that has all the clutter.
  (setq gptel-backend
        (gptel-make-openai "ChatGPT"
          :key gptel-api-key
          :stream t
          :models '(gpt-5
                    gpt-5-mini
                    gpt-5-nano
                    o3
                    o4-mini)))

  ;; 2. Define Ollama (Optional, keeps it separate)
  (setq my/gptel-ollama
        (gptel-make-ollama "Ollama"
          :host "localhost:11434"
          :stream t
          :models '(mistral:latest)))

  ;; 3. Ensure we start with the clean ChatGPT backend
  (setq gptel-model 'gpt-5-mini))


(after! cdlatex
  ;; 1. Remove the existing default definition for 'b' (which is just \beta)
  ;;    This prevents any conflict or merging issues.
  (setq cdlatex-math-symbol-alist
        (assq-delete-all ?b cdlatex-math-symbol-alist))

  ;; 2. Add your custom definition directly to the main list
  ;;    Structure: (?char ("level1" "level2" "level3"))
  (add-to-list 'cdlatex-math-symbol-alist
               '(?b ("\\beta" "\\boxplus" "\\boxtimes")))

  (add-to-list 'cdlatex-math-symbol-alist
               '(?a ("\\alpha" "\\begin{align*}\n\n\\end{align*}")))

  (add-to-list 'cdlatex-math-symbol-alist
               '(?i ("\\in" "\\implies")))

  (add-to-list 'cdlatex-math-symbol-alist
               '(?R ("\\mathbb{R}")))

  (add-to-list 'cdlatex-math-symbol-alist
               '(?m ("\\mu" "\\mathbb{}")))

  (add-to-list 'cdlatex-math-symbol-alist
               '(?t ("\\tau" "\\text{}")))

  ;; 3. Force cdlatex to reset its internal cache immediately
  (setq cdlatex-math-symbol-alist-comb nil))

;; quarto
(use-package! quarto-mode
  :mode (("\\.Rmd\\'" . poly-quarto-mode)
         ("\\.qmd\\'" . poly-quarto-mode)))

;; pdf
(after! pdf-tools
  (add-hook 'pdf-view-mode-hook
    (lambda ()
      (setq pdf-view-midnight-colors
            (cons (face-foreground 'default) (face-background 'default)))
      (pdf-view-midnight-minor-mode 1)))
  (map! :map pdf-view-mode-map
        :n "i" #'pdf-view-midnight-minor-mode))
(after! pdf-view
  (setq pdf-view-resize-factor 1.05))  ;; default is 1.25

;; pass - password generation length
(setq password-store-password-length 24)

;; org to ipynb
(use-package! ox-ipynb
  :after ox)

;; TODO for definitions
(after! org
  (setq org-todo-keywords
        '((sequence "TODO(t)" "WAIT(w)" "|" "DONE(d)")))
  (setq org-todo-keyword-faces
        '(("WAIT" . (:foreground "#d79921" :weight bold)))))


;;; --- lecture-note cross-reference tooling --------------------------
(require 'cl-lib)
(require 'subr-x)

(defvar erik/org-kind-prefix
  '(("Theorem" . "thm") ("Lemma" . "lem") ("Definition" . "def")
    ("Proposition" . "prop") ("Corollary" . "cor"))
  "Slug prefix for each item kind.")

(defvar erik/org-ref-directories
  '("/Users/ziro2173/personal/mfds/01_coursework/02_semester/01_analysis/01_material"
    "/Users/ziro2173/personal/mfds/01_coursework/02_semester/02_linear_algebra/01_material")
  "Directories globbed for .org chapter files when inserting a reference.")

;;; --- helpers -------------------------------------------------------
(defun erik/org-slugify (s)
  (string-trim (replace-regexp-in-string "[^a-z0-9]+" "-" (downcase s))
               "-+" "-+"))

(defun erik/org--items-in-buffer ()
  "List of (CID KIND REF NAME) for every CUSTOM_ID item in this buffer."
  (let (items)
    (org-with-wide-buffer
     (org-map-entries
      (lambda ()
        (let ((cid  (org-entry-get nil "CUSTOM_ID"))
              (head (org-get-heading t t t t)))
          (when (and cid head)
            (let* ((parts (split-string head ":"))
                   (kind  (string-trim (car parts)))
                   (name  (string-trim (string-join (cdr parts) ":"))))
              (push (list cid kind
                          (or (org-entry-get nil "LECTURE_REF") "")
                          name)
                    items)))))))
    (nreverse items)))

(defun erik/org--item-table ()
  "Hash CUSTOM_ID -> \"<Kind> <LECTURE_REF>\" for items that have a ref."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (it (erik/org--items-in-buffer) table)
      (cl-destructuring-bind (cid kind ref _name) it
        (unless (string= ref "")
          (puthash cid (format "%s %s" kind ref) table))))))

(defun erik/org--file-table (file cache)
  "Item table for FILE (nil = current buffer), memoised in CACHE.
Returns the hash table, or the symbol `missing' if FILE is unreadable."
  (let ((key (or file :current)))
    (or (gethash key cache)
        (puthash key
                 (if (null file)
                     (erik/org--item-table)
                   (let ((path (expand-file-name file)))
                     (if (file-readable-p path)
                         (with-current-buffer (find-file-noselect path)
                           (erik/org--item-table))
                       'missing)))
                 cache))))

(defun erik/org--all-chapter-files ()
  "Every .org chapter file under `erik/org-ref-directories'."
  (seq-uniq
   (mapcan (lambda (d)
             (and (file-directory-p d)
                  (directory-files d t "\\`[^.#].*\\.org\\'")))
           erik/org-ref-directories)))

;;; --- commands ------------------------------------------------------
(defun erik/org-new-item (kind name slug ref)
  "Insert a lecture-item heading with CUSTOM_ID and LECTURE_REF.
SLUG defaults to a mechanical slug of NAME; edit it to a concise form."
  (interactive
   (let* ((kind (completing-read "Kind: " erik/org-kind-prefix))
          (name (read-string "Name: ")))
     (list kind name
           (read-string "Slug: " (erik/org-slugify name))
           (read-string "Lecture ref: "))))
  (insert (format "* %s: %s\n:PROPERTIES:\n:CUSTOM_ID: %s:%s\n:LECTURE_REF: %s\n:END:\n\n"
                  kind name (cdr (assoc kind erik/org-kind-prefix))
                  slug ref)))

(defun erik/org-insert-ref ()
  "Pick a lecture item from any configured chapter file and insert a link.
A target in the current file yields [[#cid][...]]; a target elsewhere
yields [[file:RELPATH::#cid][...]], the path relative to this file."
  (interactive)
  (unless buffer-file-name
    (user-error "Run this from a file-visiting buffer"))
  (let* ((here    (file-truename buffer-file-name))
         (heredir (file-name-directory here))
         (rows '()))
    (dolist (f (erik/org--all-chapter-files))
      (let ((ftrue (file-truename f)))
        (with-current-buffer (find-file-noselect f)
          (dolist (it (erik/org--items-in-buffer))
            (cl-destructuring-bind (cid kind ref name) it
              (push (list (format "%-26s %-11s %-8s %s"
                                  (file-name-nondirectory f)
                                  kind (if (string= ref "") "—" ref) name)
                          ftrue cid kind ref)
                    rows))))))
    (setq rows (nreverse rows))
    (unless rows
      (user-error "No items found under erik/org-ref-directories"))
    (let* ((choice (completing-read "Reference: " rows nil t))
           (r (assoc choice rows)))
      (when r
        (cl-destructuring-bind (_disp ftrue cid kind ref) r
          (let ((desc (if (string= ref "") kind (format "%s %s" kind ref))))
            (insert
             (if (file-equal-p ftrue here)
                 (format "[[#%s][%s]]" cid desc)
               (format "[[file:%s::#%s][%s]]"
                       (file-relative-name ftrue heredir) cid desc)))))))))

(defun erik/org-refresh-ref-links ()
  "Refresh descriptions of CUSTOM_ID links in the current buffer.
Handles in-file [[#cid][...]] and cross-file [[file:PATH::#cid][...]]
links; each description is rewritten to \"<Kind> <LECTURE_REF>\" of
its target."
  (interactive)
  (let ((cache (make-hash-table :test 'equal))
        (n 0) (warn '()))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "\\[\\[\\(?:file:\\([^]]*?\\)::\\)?#\\([^]]+\\)\\]\\[\\([^]]*\\)\\]\\]"
              nil t)
        (let* ((file  (match-string 1))
               (cid   (match-string 2))
               (old   (match-string 3))
               (table (save-match-data (erik/org--file-table file cache))))
          (cond
           ((eq table 'missing)
            (push (format "file not found: %s" file) warn))
           (t (let ((new (gethash cid table)))
                (cond
                 ((null new)
                  (push (format "unresolved: %s%s"
                                (if file (concat file "::") "") cid)
                        warn))
                 ((not (string= new old))
                  (replace-match new t t nil 3)
                  (setq n (1+ n))))))))))
    (if warn
        (message "Refreshed %d link(s); %d warning(s): %s"
                 n (length warn)
                 (string-join (delete-dups (nreverse warn)) "; "))
      (message "Refreshed %d link(s); no warnings." n))))

;;; --- keybindings ---------------------------------------------------
(map! :after org :map org-mode-map :localleader
      "i n" #'erik/org-new-item
      "i r" #'erik/org-insert-ref
      "i z" #'erik/org-refresh-ref-links)

;; ox-ipynb
(with-eval-after-load 'ox-ipynb
  (define-advice ox-ipynb-export-to-buffer-data
      (:around (orig &rest args) ox-ipynb-quote-trailing-newline)
    (cl-letf* ((qb (symbol-function 'org-md-quote-block))
               ((symbol-function 'org-md-quote-block)
                (lambda (&rest a) (concat (apply qb a) "\n\n"))))
      (apply orig args))))
