;;; mfds-gptel.el --- gptel commands for the mfds notes  -*- lexical-binding: t; -*-

;;; Commentary:

;; Editor layer for the mfds repository.  The repository holds the prompts;
;; this file holds the two commands that send them.
;;
;; `mfds-gptel-answer'   Point on a question under "** Questions" in a notes
;;   file.  Sends the item, the earlier questions on it and the question,
;;   with notes_material_qa_api.org as the system prompt, and inserts the
;;   reply under the question.  The entry whose body is the reply gets
;;   ":LLM: <model>": the question itself when its body was empty, else a
;;   new "Answer" sub-heading after your own text.  gptel-mode is never
;;   turned on in notes files.
;;
;; `mfds-gptel-ps-chat'  Point in a problem of ps_NN.org.  Opens
;;   ps_NN_chat.org beside it at that problem; a new conversation starts with
;;   the Task and your Solution so far.  With C-u on a problem that already
;;   has a conversation, your current Solution is added as a new message.
;;   Type your question below and send it with `gptel-send'.
;;
;; Chat files are gptel chats: opening one turns on gptel-mode, and a new
;; one gets ps_tutor.org as its system prompt.  Each "* Problem N" carries a
;; GPTEL_TOPIC property, so a conversation sees only its own problem.  Edit
;; chat files only through gptel: gptel records the model's text by
;; character position.
;;
;; Setup, in config.el:
;;   (load! "mfds-gptel")
;;   (map! :map org-mode-map :localleader
;;         "a" #'mfds-gptel-answer
;;         "c" #'mfds-gptel-ps-chat)
;; `mfds-gptel-backend' must name your Anthropic backend in gptel.

;;; Code:

(require 'org)
(require 'org-src)
(require 'cl-lib)
(require 'subr-x)

(declare-function gptel-request "gptel-request")
(declare-function gptel-mode "gptel")
(declare-function gptel-prompt-prefix-string "gptel-request")
(defvar gptel-backend)
(defvar gptel-model)
(defvar gptel-use-tools)
(defvar gptel-use-context)
(defvar gptel--known-backends)
(defvar gptel-org-branching-context)
(defvar gptel-org-convert-response)

(defgroup mfds-gptel nil
  "gptel commands for the mfds notes."
  :group 'gptel)

(defcustom mfds-gptel-backend "Claude"
  "Name of the gptel backend the mfds commands use."
  :type 'string)

(defcustom mfds-gptel-model 'claude-opus-5
  "Model the mfds commands use; the backend's :models must list it.
Its name is what the :LLM: property and a new chat file record."
  :type 'symbol)

(defconst mfds-gptel--qa-rule
  "00_global/prompts/01_material/notes_material_qa_api.org")
(defconst mfds-gptel--tutor-rule
  "00_global/prompts/02_problems/ps_tutor.org")
(defconst mfds-gptel--notation
  "00_global/prompts/math_notation.org")
(defconst mfds-gptel--chat-file-re "/ps_[0-9][0-9]_chat\\.org\\'")


;;;; Shared

(defun mfds-gptel--root ()
  "The mfds repository that holds the current file."
  (or (and buffer-file-name
           (locate-dominating-file buffer-file-name "STRUCTURE.org"))
      (user-error "Not in the mfds repository: no STRUCTURE.org above this file")))

(defun mfds-gptel--org-body (file)
  "FILE from its first heading on, the way the extraction scripts read a rule.
Comma escapes inside example blocks are removed."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((beg (if (re-search-forward "^\\* " nil t)
                   (match-beginning 0)
                 (point-min))))
      (string-trim
       (org-unescape-code-in-string
        (buffer-substring-no-properties beg (point-max)))))))

(defun mfds-gptel--system (root rule)
  "System prompt for RULE in ROOT: notation first, rule second.
The same assembly as build_system_prompt in extraction_common.py."
  (format "<math_notation>\n%s\n</math_notation>\n\n%s"
          (mfds-gptel--org-body (expand-file-name mfds-gptel--notation root))
          (mfds-gptel--org-body (expand-file-name rule root))))

(defun mfds-gptel--backend ()
  "The gptel backend named `mfds-gptel-backend', checked to list the model.
gptel quietly replaces a model its backend does not list with the
backend's first model, and the :LLM: property would then name the wrong
one, so an unlisted `mfds-gptel-model' is an error here."
  (require 'gptel)
  (let ((backend (cdr (assoc mfds-gptel-backend gptel--known-backends))))
    (unless backend
      (user-error "No gptel backend named %S; set `mfds-gptel-backend'"
                  mfds-gptel-backend))
    (unless (memq mfds-gptel-model (gptel-backend-models backend))
      (user-error "gptel backend %S does not list %s: add it to the backend's :models, or set `mfds-gptel-model'"
                  mfds-gptel-backend mfds-gptel-model))
    backend))

(defun mfds-gptel--strip-drawers (s)
  "S without drawers (properties, logbook)."
  (replace-regexp-in-string
   (concat "^[ \t]*:[A-Za-z][A-Za-z0-9_-]*:[ \t]*\n"
           "\\(?:.*\n\\)*?[ \t]*:END:[ \t]*\\(?:\n\\|\\'\\)")
   "" s))

(defun mfds-gptel--tidy (s)
  "S trimmed, with runs of blank lines collapsed to one."
  (replace-regexp-in-string "\n\\(?:[ \t]*\n\\)\\{2,\\}" "\n\n" (string-trim s)))

(defun mfds-gptel--body ()
  "Text of the entry at point after its meta data, up to the next heading."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion (outline-next-heading) (point))))
      (org-end-of-meta-data t)
      (string-trim (buffer-substring-no-properties (min (point) end) end)))))

(defun mfds-gptel--subtree-end ()
  "Start of the heading after the subtree at point, or `point-max'."
  (save-excursion (org-end-of-subtree t t) (point)))

(defun mfds-gptel--trim-tail ()
  "Delete the whitespace before the next heading; point at the last text."
  (let ((end (point)))
    (skip-chars-backward " \t\n")
    (delete-region (point) end)))


;;;; Q&A in the notes

(defvar-local mfds-gptel--pending nil
  "Markers of the questions whose answer is on its way.")

;;;###autoload
(defun mfds-gptel-answer ()
  "Answer the question at point with gptel and insert the reply below it.
Point must be on a question: a direct child of a \"Questions\" heading,
whose parent is the item asked about."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Not an Org buffer"))
  (let ((root (mfds-gptel--root))
        q-pos q-end item-pos questions-pos first-q question ref)
    (save-excursion
      (org-back-to-heading t)
      (setq q-pos (point)
            q-end (mfds-gptel--subtree-end))
      (setq question
            (let ((head (org-get-heading t t t t))
                  (body (mfds-gptel--strip-drawers (mfds-gptel--body))))
              (if (string-empty-p body) head (concat head "\n\n" body))))
      (unless (and (org-up-heading-safe)
                   (equal (org-get-heading t t t t) "Questions"))
        (user-error "Point is not on a question under a \"Questions\" heading"))
      (setq questions-pos (point))
      (save-excursion (org-goto-first-child) (setq first-q (point)))
      (unless (org-up-heading-safe)
        (user-error "The \"Questions\" heading has no item above it"))
      (setq item-pos (point)
            ref (org-entry-get nil "LECTURE_REF")))
    (when (save-excursion (goto-char q-pos)
                          (re-search-forward "^[ \t]*:LLM:" q-end t))
      (user-error "Already answered (:LLM: is set); ask a follow-up as a new question"))
    (when (cl-find q-pos mfds-gptel--pending :test #'=)
      (user-error "An answer to this question is already on its way"))
    (let* ((item (mfds-gptel--tidy
                  (mfds-gptel--strip-drawers
                   (buffer-substring-no-properties item-pos questions-pos))))
           (earlier (mfds-gptel--tidy
                     (mfds-gptel--strip-drawers
                      (buffer-substring-no-properties first-q q-pos))))
           (prompt (concat
                    (format "<item%s>\n%s\n</item>\n\n"
                            (if (and ref (not (member ref '("" "none"))))
                                (format " lecture_ref=\"%s\"" ref)
                              "")
                            item)
                    (if (string-empty-p earlier) ""
                      (format "<earlier_questions>\n%s\n</earlier_questions>\n\n"
                              earlier))
                    (format "<question>\n%s\n</question>" question)))
           (system (mfds-gptel--system root mfds-gptel--qa-rule))
           (marker (copy-marker q-pos)))
      (let ((gptel-backend (mfds-gptel--backend))
            (gptel-model mfds-gptel-model)
            (gptel-use-tools nil)
            (gptel-use-context nil))
        (push marker mfds-gptel--pending)
        (gptel-request prompt
          :system system
          :stream nil
          :callback (lambda (response info)
                      (mfds-gptel--receive marker response info))))
      (message "mfds: asking %s..." mfds-gptel-model))))

(defun mfds-gptel--receive (marker response info)
  "Insert RESPONSE under the question at MARKER.
INFO is gptel's request plist; the model recorded is the one it names,
when it names one."
  (let ((buf (marker-buffer marker))
        (model (format "%s" (or (plist-get info :model) mfds-gptel-model))))
    (cond
     ((not (buffer-live-p buf))
      (message "mfds: the notes buffer is gone; answer dropped"))
     ((consp response))                 ;reasoning or tool blocks
     (t
      (with-current-buffer buf
        (setq mfds-gptel--pending (delq marker mfds-gptel--pending))
        (if (not (stringp response))
            (message "mfds: no answer (%s)" (or (plist-get info :status) response))
          (let ((text (mfds-gptel--clean response)))
            (if (string-match-p "^\\*+ " text)
                (mfds-gptel--refuse text "the reply contains an Org heading")
              (save-excursion
                (save-restriction
                  (widen)
                  (goto-char marker)
                  (mfds-gptel--place text model)))
              (message "mfds: answered by %s" model)))))))))

(defun mfds-gptel--clean (s)
  "Reply S without surrounding whitespace or a stray fence."
  (let ((s (string-trim s)))
    (when (string-match "\\````[a-z]*\n\\(\\(?:.\\|\n\\)*?\\)\n```\\'" s)
      (setq s (match-string 1 s)))
    (mfds-gptel--tidy s)))

(defun mfds-gptel--refuse (text why)
  "Show TEXT, which was not inserted because of WHY."
  (with-current-buffer (get-buffer-create "*mfds-gptel*")
    (erase-buffer)
    (insert text)
    (org-mode))
  (display-buffer "*mfds-gptel*")
  (message "mfds: not inserted, %s; the reply is in *mfds-gptel*" why))

(defun mfds-gptel--place (text model)
  "Insert TEXT under the question heading at point, marked with MODEL.
An empty question body becomes TEXT.  Otherwise the body is your own
text, and TEXT goes into an \"Answer\" sub-heading after the subtree."
  (org-back-to-heading t)
  (if (string-empty-p (mfds-gptel--body))
      (progn
        (let ((org-property-format "%s %s"))
          (org-entry-put nil "LLM" model))
        (goto-char (save-excursion (outline-next-heading) (point)))
        (mfds-gptel--trim-tail)
        (insert "\n\n" text "\n"))
    (let ((stars (make-string (org-get-valid-level (org-current-level) 1) ?*)))
      (goto-char (mfds-gptel--subtree-end))
      (mfds-gptel--trim-tail)
      (insert "\n\n" stars " Answer\n:PROPERTIES:\n:LLM: " model "\n:END:\n\n"
              text "\n")))
  (unless (eobp) (insert "\n")))


;;;; Problem-set chats

(defun mfds-gptel--child-text (name)
  "Text under the direct child heading NAME of the subtree at point.
Drawers are dropped and sub-headings become plain lines."
  (save-excursion
    (let ((end (mfds-gptel--subtree-end)) found)
      (when (org-goto-first-child)
        (while (and (not found) (< (point) end))
          (if (equal (org-get-heading t t t t) name)
              (setq found (point))
            (unless (org-get-next-sibling) (goto-char end)))))
      (when found
        (goto-char found)
        (mfds-gptel--tidy
         (replace-regexp-in-string
          "^\\*+[ \t]+" ""
          (mfds-gptel--strip-drawers
           (buffer-substring-no-properties (line-beginning-position 2)
                                           (mfds-gptel--subtree-end)))))))))

;;;###autoload
(defun mfds-gptel-ps-chat (&optional with-attempt)
  "Open the conversation about the problem at point in ps_NN_chat.org.
A new conversation starts with the problem's Task and your Solution so
far.  With WITH-ATTEMPT (\\[universal-argument]) on an existing one, your
current Solution is added as a new message."
  (interactive "P")
  (let* ((file (and buffer-file-name (file-name-nondirectory buffer-file-name)))
         (nn (and file (string-match "\\`ps_\\([0-9][0-9]\\)\\.org\\'" file)
                  (match-string 1 file)))
         problem task attempt)
    (unless nn (user-error "Not in a ps_NN.org file"))
    (mfds-gptel--root)
    (mfds-gptel--backend)
    (save-excursion
      (org-back-to-heading t)
      (while (org-up-heading-safe))
      (setq problem (org-get-heading t t t t))
      (unless (string-match-p "\\`\\(?:Problem\\|Aufgabe\\|Exercise\\)\\b" problem)
        (user-error "Point is not in a problem (\"* Problem N\")"))
      (setq task (mfds-gptel--child-text "Task")
            attempt (mfds-gptel--child-text "Solution")))
    (unless task (user-error "%s has no \"Task\" heading" problem))
    (when (equal attempt "") (setq attempt nil))
    (pop-to-buffer
     (find-file-noselect
      (expand-file-name (format "ps_%s_chat.org" nn)
                        (file-name-directory buffer-file-name))))
    (unless (bound-and-true-p gptel-mode) (mfds-gptel--chat-setup))
    (widen)
    (when (= (buffer-size) 0)
      (insert (format "#+title: Ps %s Chat\n#+date: <%s>\n#+startup: overview\n"
                      nn (format-time-string "%Y-%m-%d"))))
    (goto-char (point-min))
    (let ((head
           (if (re-search-forward (format "^\\* %s[ \t]*$" (regexp-quote problem))
                                  nil t)
               (copy-marker (line-beginning-position))
             (goto-char (point-max))
             (mfds-gptel--trim-tail)
             (mfds-gptel--drop-empty-prompt)
             (insert (if (bobp) "" "\n\n"))
             (prog1 (copy-marker (point))
               (insert "* " problem "\n:PROPERTIES:\n:GPTEL_TOPIC: "
                       (downcase (replace-regexp-in-string "[ \t]+" "-" problem))
                       "\n:END:\n\n" task
                       (if attempt (concat "\n\n" "My attempt so far:\n\n" attempt) "")
                       "\n")
               (setq with-attempt nil)))))
      (mfds-gptel--goto-prompt head)
      (when (and with-attempt attempt)
        ;; the prefix may end in a newline ("@user\n"), so look back by length
        (let ((prefix (gptel-prompt-prefix-string)))
          (unless (looking-back (regexp-quote prefix)
                                (max (point-min) (- (point) (length prefix))))
            (insert prefix)))
        (insert "My current attempt:\n\n" attempt "\n\n"))
      (save-excursion
        (goto-char head)
        (if (fboundp 'org-fold-show-subtree)
            (org-fold-show-subtree)
          (outline-show-subtree)))
      (set-marker head nil))
    (ignore-errors (recenter))))

(defun mfds-gptel--drop-empty-prompt ()
  "Delete the empty prompt gptel leaves after a reply, if point ends it.
Return non-nil if there was one."
  (let ((bare (string-trim (gptel-prompt-prefix-string))))
    (when (and (not (string-empty-p bare))
               (looking-back (concat "^" (regexp-quote bare))
                             (line-beginning-position)))
      (delete-region (line-beginning-position) (point))
      (mfds-gptel--trim-tail)
      t)))

(defun mfds-gptel--goto-prompt (head)
  "Put point where the next message goes, at the end of the subtree at HEAD."
  (goto-char head)
  (goto-char (mfds-gptel--subtree-end))
  (mfds-gptel--trim-tail)
  (if (mfds-gptel--drop-empty-prompt)
      ;; gptel's empty prompt after a reply: write on a fresh one
      (insert "\n\n" (gptel-prompt-prefix-string))
    (insert "\n\n"))
  (unless (eobp) (save-excursion (insert "\n\n"))))

(defun mfds-gptel--chat-setup ()
  "Make a ps_NN_chat.org buffer a gptel chat.  Runs from `org-mode-hook'."
  (when (and buffer-file-name
             (string-match-p mfds-gptel--chat-file-re buffer-file-name))
    (require 'gptel)
    (require 'gptel-org)
    (setq-local gptel-org-branching-context nil) ;GPTEL_TOPIC narrows instead
    (setq-local gptel-org-convert-response nil)  ;the tutor writes Org
    (if (org-with-wide-buffer (org-entry-get (point-min) "GPTEL_SYSTEM"))
        (gptel-mode 1)                  ;restores model, backend, prompt
      ;; a new chat: nothing to restore, so silence gptel's complaint
      (let ((inhibit-message t)) (gptel-mode 1))
      (with-demoted-errors "mfds: %S"
        (let ((root (locate-dominating-file buffer-file-name "STRUCTURE.org")))
          (setq-local gptel-backend (mfds-gptel--backend))
          (setq-local gptel-model mfds-gptel-model)
          (set (make-local-variable (if (boundp 'gptel-system-prompt)
                                        'gptel-system-prompt
                                      'gptel--system-message))
               (mfds-gptel--system root mfds-gptel--tutor-rule)))))))

(add-hook 'org-mode-hook #'mfds-gptel--chat-setup)

(provide 'mfds-gptel)
;;; mfds-gptel.el ends here
