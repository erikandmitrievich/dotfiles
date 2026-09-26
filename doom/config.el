;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
;;
;; No 'doom sync' needed after editing this file (only after init.el/packages.el).

(require 'cl-lib)
(require 'subr-x)

;;; ------------------------------------------------------------------
;;; identity
;;; ------------------------------------------------------------------

(setq user-full-name    "Erik An"
      user-mail-address "obluda2173@gmail.com")

;;; ------------------------------------------------------------------
;;; ui
;;; ------------------------------------------------------------------

;; (setq doom-theme 'doom-one
;;       display-line-numbers-type t)

(setq doom-theme 'doom-plain-dark
      display-line-numbers-type t)

;;; ------------------------------------------------------------------
;;; paths
;;; ------------------------------------------------------------------

(after! org
  (setq org-link-file-path-type 'relative))

(setq org-directory "~/org/")

(defvar erik/notes-directory
  (expand-file-name "~/personal/mfds/")
  "Root of the current semester's coursework.
Only org files under this tree get automatic headers and lastmod stamps.")

(defun erik/org-ref-directories ()
  "Material directories under `erik/notes-directory', per STRUCTURE.org.
Recomputed per call so a rename or a new course needs no config edit."
  (seq-filter #'file-directory-p
              (file-expand-wildcards
               (expand-file-name "01_coursework/*_semester/*/01_material"
                                 erik/notes-directory)
               t)))

;;; ------------------------------------------------------------------
;;; lsp / js / ts
;;; ------------------------------------------------------------------
;; Needs: npm install -g typescript typescript-language-server eslint
;; +lsp and tree-sitter are wired by the modules; no manual hooks needed.

(after! lsp-mode
  (add-to-list 'lsp-file-watch-ignored-directories "node_modules")
  (setq lsp-idle-delay 0.5
        lsp-log-io    nil))

(after! js2-mode
  (setq js-indent-level 2))

(after! typescript-mode
  (setq typescript-indent-level 2))

;;; ------------------------------------------------------------------
;;; gptel
;;; ------------------------------------------------------------------
;; Keys live in `pass'; the lambdas are evaluated per request, so no GPG
;; prompt at startup and no auth-source host/user matching to get wrong.

(defvar erik/gptel-claude nil
  "Anthropic backend.")

(defvar erik/gptel-ollama nil
  "Ollama backend, kept separate from the default one.")

(use-package! gptel
  :config
  (setq gptel-default-mode 'org-mode)

  ;; Naming this "ChatGPT" overwrites Doom/gptel's cluttered built-in backend.
  (setq gptel-backend
        (gptel-make-openai "ChatGPT"
          :key gptel-api-key
          :stream t
          :models '(gpt-5 gpt-5-mini gpt-5-nano o3 o4-mini)))

  (setq erik/gptel-claude
        (gptel-make-anthropic "Claude"
          :key (lambda () (password-store-get "anthropic/api-key-gptel"))
          :stream t
          :models '(claude-opus-5 claude-sonnet-5 claude-haiku-4-5-20251001)))

  (gptel-make-anthropic "Claude-digest"
    :key (lambda () (password-store-get "anthropic/api-key-digest"))
    :stream nil
    :models '(claude-haiku-4-5-20251001))

  (setq erik/gptel-ollama
        (gptel-make-ollama "Ollama"
          :host "localhost:11434"
          :stream t
          :models '(mistral:latest)))

  ;; Claude 5-generation models reject non-default sampling params with a 400.
  (setq gptel-temperature nil)

  (setq gptel-backend erik/gptel-claude
        gptel-model   'claude-sonnet-5))

(map! :leader
      (:prefix ("l" . "llm")
       "l" #'gptel
       "s" #'gptel-send
       "m" #'gptel-menu
       "r" #'gptel-rewrite
       "a" #'gptel-add
       "f" #'gptel-add-file))

(after! gptel
  (setq gptel-default-mode 'org-mode
        gptel-org-branching-context t)
  (setf (alist-get 'org-mode gptel-prompt-prefix-alist) "@user\n")
  (setf (alist-get 'org-mode gptel-response-prefix-alist) "@assistant\n"))

(after! gptel
  (setq gptel-expert-commands t))

(after! gptel
  (gptel-make-preset 'julia
    :description "Julia, minimal, no over-engineering"
    :backend "Claude"
    :model 'claude-sonnet-4-5-20250929
    :system "Idiomatic Julia. Minimal solution. No defensive boilerplate, no comments restating the code."
    :temperature 0.2
    :use-context 'user))

;;; ------------------------------------------------------------------
;;; latex / cdlatex
;;; ------------------------------------------------------------------

(after! org
  (setq org-preview-latex-default-process 'dvisvgm)
  (plist-put org-format-latex-options :scale 1.8)
  (plist-put org-format-latex-options :foreground 'default)
  (plist-put org-format-latex-options :background 'default))

(after! cdlatex
  ;; This is the *user* list; it is consed ahead of
  ;; `cdlatex-math-symbol-alist-default', so these win over the defaults.
  (setq cdlatex-math-symbol-alist
        '((?b ("\\beta" "\\boxplus" "\\boxtimes"))
          (?a ("\\alpha" "\\begin{align*}\n\n\\end{align*}"))
          (?i ("\\in" "\\implies"))
          (?R ("\\mathbb{R}"))
          (?m ("\\mu" "\\mathbb{}"))
          (?t ("\\tau" "\\text{}"))))
  ;; force the combined cache to rebuild
  (setq cdlatex-math-symbol-alist-comb nil))

;;; ------------------------------------------------------------------
;;; quarto / pdf / pass
;;; ------------------------------------------------------------------

(use-package! quarto-mode



  :mode (("\\.Rmd\\'" . poly-quarto-mode)
         ("\\.qmd\\'" . poly-quarto-mode)))

(after! pdf-tools
  (setq pdf-view-resize-factor 1.05)    ; default 1.25
  (add-hook 'pdf-view-mode-hook
            (lambda ()
              (setq pdf-view-midnight-colors
                    (cons (face-foreground 'default)
                          (face-background 'default)))
              (pdf-view-midnight-minor-mode 1)))
  (map! :map pdf-view-mode-map
        :n "i" #'pdf-view-midnight-minor-mode))

(setq password-store-password-length 24)

;;; ------------------------------------------------------------------
;;; org
;;; ------------------------------------------------------------------

(use-package! org-modern
  :hook (org-mode . org-modern-mode))

(use-package! ox-ipynb
  :after ox)

(after! org
  (setq org-todo-keywords
        '((sequence "TODO(t)" "WAIT(w)" "|" "DONE(d)"))
        org-todo-keyword-faces
        '(("WAIT" . (:foreground "#d79921" :weight bold)))))

;; ox-ipynb emits quote blocks without a trailing blank line, which glues the
;; next cell to them.
(with-eval-after-load 'ox-ipynb
  (define-advice ox-ipynb-export-to-buffer-data
      (:around (orig &rest args) ox-ipynb-quote-trailing-newline)
    (cl-letf* ((qb (symbol-function 'org-md-quote-block))
               ((symbol-function 'org-md-quote-block)
                (lambda (&rest a) (concat (apply qb a) "\n\n"))))
      (apply orig args))))

;;; ------------------------------------------------------------------
;;; org file headers
;;; ------------------------------------------------------------------
;; Two profiles:
;;   full  — files under `erik/notes-directory': LaTeX preamble, columns,
;;           latexpreview, numbered sections.
;;   basic — every other org file under `erik/org-managed-roots'.
;; Full back-fills headers into existing files (as before). Basic only
;; fires on a brand-new empty file, so opening an old note or a repo's
;; README.org never rewrites it.

(defvar erik/org-managed-roots
  (list erik/notes-directory
        (expand-file-name "~/org/")
        (expand-file-name "~/personal/"))
  "Roots under which org files get automatic headers and lastmod stamps.")

(defvar erik/org-unmanaged-files
  (mapcar (lambda (f) (expand-file-name f org-directory))
          '("elfeed.org" "papers.org"))
  "Files owned by other tooling; never given a header or a stamp.")

(defun erik/org--managed-file-p ()
  "Non-nil if the current buffer visits a managed org file."
  (when-let* ((f (buffer-file-name))
              (f (file-truename f)))
    (and (not (cl-some (lambda (u) (string= f (file-truename u)))
                       erik/org-unmanaged-files))
         (cl-some (lambda (root) (file-in-directory-p f (file-truename root)))
                  erik/org-managed-roots))))

(defun erik/org--coursework-file-p ()
  "Non-nil if this file gets the full (MFDS) header."
  (when-let ((f (buffer-file-name)))
    (file-in-directory-p (file-truename f)
                         (file-truename erik/notes-directory))))

(defun erik/org--title-from-filename ()
  "A pretty title derived from the buffer's filename."
  (let* ((base  (file-name-base (or (buffer-file-name) (buffer-name))))
         (parts (split-string base "[-_ ]+")))
    (mapconcat #'capitalize parts " ")))

(defun erik/org--keyword-region-end ()
  "Point at the end of the leading #+keyword block."
  (save-excursion
    (goto-char (point-min))
    (while (and (not (eobp)) (looking-at "^\\(?:[ \t]*$\\|#\\+\\)"))
      (forward-line 1))
    (point)))

;;; ---- header strings -------------------------------------------------

(defun erik/org--header-common ()
  (concat
   (format "#+title: %s\n"    (erik/org--title-from-filename))
   (format "#+author: %s\n"   user-full-name)
   (format "#+email: %s\n"    user-mail-address)
   (format "#+date: %s\n"     (format-time-string "<%Y-%m-%d>"))
   (format "#+lastmod: %s\n"  (format-time-string "<%Y-%m-%d %H:%M>"))))

(defun erik/org--header-basic ()
  (concat (erik/org--header-common)
          "#+options: toc:nil num:nil tags:nil\n"
          "#+startup: overview inlineimages\n\n"))

(defun erik/org--header-full ()
  (concat
   (erik/org--header-common)
   ;; paragraph spacing
   "#+latex: \\newpage\n"
   "#+latex_header: \\setlength{\\parindent}{0pt}\n"
   "#+latex_header: \\setlength{\\parskip}{1em}\n"
   ;; math
   "#+latex_header: \\usepackage{amsmath}\n"
   "#+latex_header: \\usepackage{amssymb}\n"
   "#+latex_header: \\usepackage{mathtools}\n"
   "#+latex_header: \\usepackage{amsthm}\n"
   ;; geometry
   "#+latex_header: \\usepackage[margin=1in]{geometry}\n"
   ;; view
   "#+options: num:t tags:nil\n"
   "#+property: header-args :eval never-export\n"
   "#+startup: overview latexpreview inlineimages\n"
   "#+columns: %50ITEM(Item) %8LECTURE_REF(Lecture) %34CUSTOM_ID(ID)\n\n"))

(defun erik/org--header-string ()
  (if (erik/org--coursework-file-p)
      (erik/org--header-full)
    (erik/org--header-basic)))

;;; ---- insertion ------------------------------------------------------

(defun erik/org--header-missing-p ()
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search t))
      (not (re-search-forward "^#\\+\\(title\\|author\\|email\\|date\\):"
                              (erik/org--keyword-region-end) t)))))

(defun erik/org-insert-header ()
  "Insert this file's header profile, unless it already has one.
Interactive escape hatch: works in any org buffer, managed or not."
  (interactive)
  (when (and (derived-mode-p 'org-mode) (erik/org--header-missing-p))
    (save-excursion
      (goto-char (point-min))
      (insert (erik/org--header-string)))))

(defun erik/org-insert-header-if-missing ()
  "Hook: back-fill coursework files, stamp only *new* files elsewhere."
  (when (and (derived-mode-p 'org-mode)
             (erik/org--managed-file-p)
             (or (erik/org--coursework-file-p)
                 (zerop (buffer-size))))
    (erik/org-insert-header)))

(defun erik/org-update-lastmod-on-save ()
  "Refresh #+lastmod in managed org files."
  (when (and (derived-mode-p 'org-mode)
             (erik/org--managed-file-p))
    (save-excursion
      (goto-char (point-min))
      (let ((ts    (format-time-string "<%Y-%m-%d %H:%M>"))
            (limit (erik/org--keyword-region-end))
            (case-fold-search t))
        (cond
         ((re-search-forward "^#\\+lastmod:.*$" limit t)
          (replace-match (concat "#+lastmod: " ts) t t))
         ;; Only coursework files get a stamp grafted on after the fact;
         ;; elsewhere, no stamp in the file means you didn't want one.
         ((erik/org--coursework-file-p)
          (goto-char (point-min))
          (when (re-search-forward
                 "^#\\+\\(title\\|author\\|email\\|date\\|options\\|startup\\):.*$"
                 limit t)
            (beginning-of-line)
            (while (and (not (eobp)) (looking-at "^#\\+")) (forward-line 1))
            (insert (concat "#+lastmod: " ts "\n")))))))))

(add-hook 'org-mode-hook    #'erik/org-insert-header-if-missing)
(add-hook 'before-save-hook #'erik/org-update-lastmod-on-save)

(map! :after org :map org-mode-map :localleader
      "i h" #'erik/org-insert-header)

;;; ------------------------------------------------------------------
;;; lecture-note cross-reference tooling
;;; ------------------------------------------------------------------

;;; ---- item extraction ----------------------------------------------

(defvar erik/org-kind-prefix
  '(("Theorem" . "thm") ("Lemma" . "lem") ("Definition" . "def")
    ("Proposition" . "prop") ("Corollary" . "cor"))
  "Slug prefix for each item kind.")

(defun erik/org-slugify (s)
  (string-trim (replace-regexp-in-string "[^a-z0-9]+" "-" (downcase s))
               "-+" "-+"))

(defun erik/org--clean-heading (h)
  "Strip TODO keyword, priority cookie and tags from raw heading text H."
  (let ((s h))
    (setq s (replace-regexp-in-string "\\`\\(?:TODO\\|WAIT\\|DONE\\)[ \t]+" "" s))
    (setq s (replace-regexp-in-string "\\`\\[#[A-C]\\][ \t]+" "" s))
    (setq s (replace-regexp-in-string "[ \t]+:[[:alnum:]_@#%:]+:[ \t]*\\'" "" s))
    (string-trim s)))

(defun erik/org--split-heading (head)
  "Return (KIND . NAME) for a cleaned heading."
  (let ((parts (split-string head ":")))
    (cons (string-trim (car parts))
          (string-trim (string-join (cdr parts) ":")))))

(defun erik/org--items-in-buffer ()
  "List of (CID KIND REF NAME) for every CUSTOM_ID item in this buffer.
Org-native; used for the current, possibly unsaved, buffer."
  (let (items)
    (org-with-wide-buffer
     (org-map-entries
      (lambda ()
        (let ((cid  (org-entry-get nil "CUSTOM_ID"))
              (head (org-get-heading t t t t)))
          (when (and cid head)
            (let ((kn (erik/org--split-heading head)))
              (push (list cid (car kn)
                          (or (org-entry-get nil "LECTURE_REF") "")
                          (cdr kn))
                    items)))))))
    (nreverse items)))

(defun erik/org--items-from-file (file)
  "Items in FILE, parsed by regex without activating `org-mode'.
Roughly two orders of magnitude cheaper than `find-file-noselect',
which would honour #+startup: latexpreview and render every fragment."
  (let (items)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward "^\\*+[ \t]+\\(.*\\)$" nil t)
        (let* ((kn  (erik/org--split-heading
                     (erik/org--clean-heading (match-string 1))))
               (end (save-excursion
                      (if (re-search-forward "^\\*+[ \t]" nil t)
                          (match-beginning 0)
                        (point-max))))
               (cid (save-excursion
                      (when (re-search-forward
                             "^[ \t]*:CUSTOM_ID:[ \t]*\\(.+?\\)[ \t]*$" end t)
                        (match-string 1))))
               (ref (save-excursion
                      (if (re-search-forward
                           "^[ \t]*:LECTURE_REF:[ \t]*\\(.*?\\)[ \t]*$" end t)
                          (match-string 1) ""))))
          (when cid (push (list cid (car kn) ref (cdr kn)) items)))))
    (nreverse items)))

(defvar erik/org--ref-cache (make-hash-table :test 'equal)
  "FILE -> (MTIME . ITEMS).")

(defun erik/org--items-cached (file)
  "Items in FILE, memoised on modification time.
A visiting buffer with unsaved changes bypasses the cache."
  (let ((buf (find-buffer-visiting file)))
    (if (and buf (buffer-modified-p buf))
        (with-current-buffer buf (erik/org--items-in-buffer))
      (let ((mtime (file-attribute-modification-time (file-attributes file)))
            (hit   (gethash file erik/org--ref-cache)))
        (if (and hit (equal (car hit) mtime))
            (cdr hit)
          (let ((items (erik/org--items-from-file file)))
            (puthash file (cons mtime items) erik/org--ref-cache)
            items))))))

(defun erik/org-ref-cache-clear ()
  "Drop the reference cache."
  (interactive)
  (clrhash erik/org--ref-cache)
  (message "ref cache cleared"))

;;; ---- tables (used by refresh) --------------------------------------

(defun erik/org--table-from-items (items)
  (let ((table (make-hash-table :test 'equal)))
    (dolist (it items table)
      (cl-destructuring-bind (cid kind ref _name) it
        (puthash cid (if (string= ref "") kind (format "%s %s" kind ref))
                 table)))))

(defun erik/org--item-table ()
  (erik/org--table-from-items (erik/org--items-in-buffer)))

(defun erik/org--file-table (file cache)
  "Item table for FILE (nil = current buffer), memoised in CACHE.
Returns the hash table, or `missing' if FILE is unreadable."
  (let ((key (or file :current)))
    (or (gethash key cache)
        (puthash key
                 (if (null file)
                     (erik/org--item-table)
                   (let ((path (expand-file-name file)))
                     (if (file-readable-p path)
                         (erik/org--table-from-items (erik/org--items-cached path))
                       'missing)))
                 cache))))

;;; ---- insertion -----------------------------------------------------

(defun erik/org--all-chapter-files ()
  (seq-uniq
   (mapcan (lambda (d) (directory-files d t "\\`[^.#].*\\.org\\'"))
           (erik/org-ref-directories))))

(defun erik/org--course-label (file)
  "COURSE/BASENAME for FILE, e.g. 01_analysis_ii/03_reihen.org."
  (let ((dir (directory-file-name (file-name-directory file))))  ; …/01_material
    (format "%s/%s"
            (file-name-nondirectory (directory-file-name (file-name-directory dir)))
            (file-name-nondirectory file))))

(defun erik/org-new-item (kind name slug ref)
  "Insert a lecture-item heading with CUSTOM_ID and LECTURE_REF."
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
  "Pick a lecture item from any material directory and insert a link."
  (interactive)
  (unless buffer-file-name
    (user-error "Run this from a file-visiting buffer"))
  (let* ((here    (file-truename buffer-file-name))
         (heredir (file-name-directory here))
         (rows '()))
    (dolist (f (erik/org--all-chapter-files))
      (let ((ftrue (file-truename f))
            (label (erik/org--course-label f)))
        (dolist (it (erik/org--items-cached f))
          (cl-destructuring-bind (cid kind ref name) it
            (push (list (format "%-40s %-11s %-8s %s"
                                label kind (if (string= ref "") "—" ref) name)
                        ftrue cid kind ref)
                  rows)))))
    (setq rows (nreverse rows))
    (unless rows
      (user-error "No items found under %s"
                  (string-join (erik/org-ref-directories) ", ")))
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

(map! :after org :map org-mode-map :localleader
      "i n" #'erik/org-new-item
      "i r" #'erik/org-insert-ref
      "i z" #'erik/org-refresh-ref-links
      "i c" #'erik/org-ref-cache-clear)

;; elfeed for bci papers

(after! elfeed
  ;; Default view: unread, last month only. Old entries do not accumulate
  ;; into a guilt pile — they scroll out of the filter and are gone.
  (setq elfeed-search-filter "@1-month-ago +unread"
        elfeed-search-title-max-width 110
        elfeed-search-title-min-width 60
        ;; Drop entries older than 3 months from the DB entirely.
        elfeed-db-directory (expand-file-name "elfeed/" doom-cache-dir))

  ;; Titles-only discipline: show feed tag + title, nothing else.
  (setq elfeed-search-date-format '("%m-%d" 5 :left))

  ;; Auto-mark the noisy feeds as read on arrival; you skim them by
  ;; explicitly filtering, not by default.
  (add-hook! 'elfeed-new-entry-hook
    (elfeed-make-tagger :feed-url "arxiv\\.org"
                        :entry-title '(not "\\(EEG\\|brain-computer\\|BCI\\|neural decod\\)")
                        :add 'junk :remove 'unread)))

(after! elfeed-org
  (setq rmh-elfeed-org-files (list (expand-file-name "elfeed.org" org-directory))))

;; Filter shortcuts. `gr` refetches, `r` marks read, `s` edits the filter.
(map! :after elfeed
      :map elfeed-search-mode-map
      :n "B" (cmd! (elfeed-search-set-filter "@1-month-ago +unread +bci"))
      :n "C" (cmd! (elfeed-search-set-filter "@3-months-ago +code"))
      :n "A" (cmd! (elfeed-search-set-filter "@1-month-ago")))

;; Capture: only fires when you'd actually cite the thing.
(after! org-capture
  (add-to-list 'org-capture-templates
               '("p" "Paper (from elfeed)" entry
                 (file+headline "~/org/papers.org" "Inbox")
                 "* READ %:description\n:PROPERTIES:\n:URL: %:link\n:CAPTURED: %U\n:END:\n%?"
                 :empty-lines 1)))

(defun ea/elfeed-capture-paper ()
  "Capture the entry at point to papers.org, mark it read, move on."
  (interactive)
  (let ((entry (or elfeed-show-entry (elfeed-search-selected :ignore-region))))
    (org-store-link nil)
    (let ((org-capture-link-is-already-stored t))
      (org-capture nil "p"))
    (when entry (elfeed-untag entry 'unread))))

(map! :after elfeed
      :map (elfeed-search-mode-map elfeed-show-mode-map)
      :n "c" #'ea/elfeed-capture-paper)

(after! elfeed
  (add-hook 'elfeed-new-entry-hook
            (elfeed-make-tagger :entry-title "newsletter:\\|^Cartoon:"
                                :remove '(unread news))))

(load! "news-digest")
