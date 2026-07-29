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

(setq doom-theme 'doom-one
      display-line-numbers-type t)

;;; ------------------------------------------------------------------
;;; paths
;;; ------------------------------------------------------------------

(setq org-directory "~/org/")

(defvar erik/notes-directory
  (expand-file-name "~/personal/mfds/")
  "Root of the current semester's coursework.
Only org files under this tree get automatic headers and lastmod stamps.")

(defvar erik/org-ref-directories
  (mapcar (lambda (d) (expand-file-name d erik/notes-directory))
          '("01_analysis/01_material"
            "02_linear_algebra/01_material"))
  "Directories globbed for .org chapter files when inserting a reference.")

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

;;; ------------------------------------------------------------------
;;; latex / cdlatex
;;; ------------------------------------------------------------------

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
;;; org file headers (scoped to `erik/notes-directory')
;;; ------------------------------------------------------------------

(defun erik/org--managed-file-p ()
  "Non-nil if the current buffer is an org file under `erik/notes-directory'."
  (when-let ((f (buffer-file-name)))
    (file-in-directory-p f erik/notes-directory)))

(defun erik/org--title-from-filename ()
  "A pretty title derived from the buffer's filename."
  (let* ((base  (file-name-base (or (buffer-file-name) (buffer-name))))
         (parts (split-string base "[-_ ]+")))
    (mapconcat #'capitalize parts " ")))

(defun erik/org--header-string ()
  (concat
   (format "#+title: %s\n" (erik/org--title-from-filename))
   (format "#+author: %s\n" user-full-name)
   (format "#+email: %s\n" user-mail-address)
   (format "#+date: %s\n" (format-time-string "<%Y-%m-%d>"))
   (format "#+lastmod: %s\n" (format-time-string "<%Y-%m-%d %H:%M>"))
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

(defun erik/org-insert-header-if-missing ()
  "Insert the standard header into a managed org file that has no keywords yet.
Checks for #+title as well, so a titled file never gets a duplicate."
  (when (and (derived-mode-p 'org-mode)
             (erik/org--managed-file-p))
    (save-excursion
      (goto-char (point-min))
      (let ((case-fold-search t))
        (unless (re-search-forward "^#\\+\\(title\\|author\\|email\\|date\\):" 400 t)
          (insert (erik/org--header-string)))))))

(defun erik/org-update-lastmod-on-save ()
  "Refresh #+lastmod in managed org files."
  (when (and (derived-mode-p 'org-mode)
             (erik/org--managed-file-p))
    (save-excursion
      (goto-char (point-min))
      (let ((ts (format-time-string "<%Y-%m-%d %H:%M>"))
            (case-fold-search t))
        (if (re-search-forward "^#\\+lastmod:.*$" nil t)
            (replace-match (concat "#+lastmod: " ts))
          (goto-char (point-min))
          (when (re-search-forward
                 "^#\\+\\(title\\|author\\|email\\|date\\|options\\|startup\\):.*$" nil t)
            (beginning-of-line)
            (while (and (not (eobp)) (looking-at "^#\\+")) (forward-line 1)))
          (insert (concat "#+lastmod: " ts "\n")))))))

(add-hook 'org-mode-hook    #'erik/org-insert-header-if-missing)
(add-hook 'before-save-hook #'erik/org-update-lastmod-on-save)

;;; ------------------------------------------------------------------
;;; lecture-note cross-reference tooling
;;; ------------------------------------------------------------------

(defvar erik/org-kind-prefix
  '(("Theorem" . "thm") ("Lemma" . "lem") ("Definition" . "def")
    ("Proposition" . "prop") ("Corollary" . "cor"))
  "Slug prefix for each item kind.")

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

(map! :after org :map org-mode-map :localleader
      "i n" #'erik/org-new-item
      "i r" #'erik/org-insert-ref
      "i z" #'erik/org-refresh-ref-links)

