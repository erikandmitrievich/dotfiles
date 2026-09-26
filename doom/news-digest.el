;;; news-digest.el --- Weekly news digest from elfeed into a static org file -*- lexical-binding: t; -*-

;; Commands:
;;   M-x erik/news-digest          build the file from the elfeed database
;;   C-u M-x erik/news-digest      fetch feeds first, then build
;;   M-x erik/news-digest-enrich   score everything, keep the best, add synthesis
;;
;; erik/news-digest applies the caps by recency, because without scores it has
;; nothing better to go on.  erik/news-digest-enrich collects the window
;; UNCAPPED, scores every entry, and only then applies the caps by score — so
;; nothing is discarded before the model has seen it.
;;
;; Only entries carrying `erik/news-digest-tag' are considered, so the BCI
;; feeds are never touched.  The enrich command writes nothing unless the
;; request succeeds, so a failure leaves the plain digest intact.
;;
;; NOTE: `defvar' does not reassign a variable that is already bound.  After
;; editing a default below, restart Emacs — reloading this file is not enough.

(require 'cl-lib)
(require 'seq)

;;; ---------------------------------------------------------------- settings

(defvar erik/news-digest-directory nil
  "Directory for digest files.  Defaults to \"news/\" under `org-directory'.")

(defvar erik/news-digest-tag 'news
  "Only entries carrying this tag enter the digest.")

(defvar erik/news-digest-categories
  '((world . "World")
    (ideas . "Ideas"))
  "Ordered alist of (TAG . HEADING).
An entry lands in the first category whose TAG it carries.
Entries matching none land under \"Other\".")

(defvar erik/news-digest-days 7
  "Length of the window, in days, counting back from now.")

(defvar erik/news-digest-max-per-feed 8
  "Hard cap on entries taken from any single feed.")

(defvar erik/news-digest-max-total 40
  "Hard cap on entries in the whole digest.")

(defvar erik/news-digest-max-per-feed-scored 15
  "Per-feed cap used once entries have been scored.
Higher than `erik/news-digest-max-per-feed', which exists only to stop one
feed dominating a digest selected by recency.  Once selection is by score,
its only job is to prevent a monoculture.")

(defvar erik/news-digest-summary-max-chars 1500
  "Summaries longer than this are truncated with an ellipsis.")

(defvar erik/news-digest-strip-patterns
  '("Новая газета\\. Европа — Читайте также"
    "🔵"
    "[[:alnum:]À-ž_-]+\\( [[:alnum:]À-ž_-]+\\)\\{0,2\\}/\\(Shutterstock\\|Unsplash\\|Pexels\\|Flickr\\|Getty\\( Images\\)?\\|Wikimedia\\( Commons\\)?\\|Alamy\\|Reuters\\|Vida Press\\)"
    "\\bLeer más:"
    "[[:alnum:]À-ž-]+\\.\\(com\\|org\\|net\\)\\b")
  "Regexps removed from every title and summary.  Feed boilerplate goes here.")

(defvar erik/news-digest-mark-read t
  "When non-nil, entries that entered the digest are marked read in elfeed.")

(defvar erik/news-digest-fetch-timeout 30
  "Seconds to wait for `elfeed-update' when called with a prefix argument.")

;;; ------------------------------------------------------------ llm settings

(defvar erik/news-digest-backend-name "Claude-digest"
  "Name of the gptel backend to use, as registered in `gptel--known-backends'.")

(defvar erik/news-digest-model 'claude-haiku-4-5-20251001
  "Model symbol to use, or nil for the backend default.")

(defvar erik/news-digest-score-threshold 5
  "Entries scoring below this move to the \"Lower priority\" section.")

(defvar erik/news-digest-prompt-chars 600
  "Characters of each entry's text sent to the model for scoring.")

(defvar erik/news-digest-profile
  "The reader is a mathematics and data science student in Vienna working
toward computational neuroscience, with a serious parallel interest in
philosophy of mind — consciousness, eliminativism, the limits of what can be
said about inner states. He reads Russian and English. He writes
philosophical essays himself, and reads fiction (Tolstoy, Dostoevsky,
Marquez) as a way of understanding people rather than for entertainment.

Score highly: pieces that explain a mechanism rather than report an event;
work on consciousness, cognition, neuroscience, and the philosophy of mind;
mathematics and its applications where the argument is actually presented;
essays where one person thinks carefully about a hard question; Russian
politics and society reported concretely, with attention to how institutions
actually behave; anything that changes how he would think about a problem
rather than telling him what happened.

Score low: event coverage that will be stale in a week; commentary whose
content is an opinion about a person; process journalism about who said
what; consumer and lifestyle material; anything whose interest is primarily
that it is surprising or absurd, without a further point."
  "Description of the reader, used as the scoring criterion.")

(defvar erik/news-digest-score-system-prompt
  "You rank articles for one specific reader.

You will be given a description of the reader and a numbered list of
articles.  Score every article from 0 to 10 for how much this particular
reader would want to read it.  Use the full range; a flat distribution is
useless.

Reply with JSON only.  No markdown fences, no commentary.  Shape:

{\"scores\": {\"1\": 7, \"2\": 3}}

Every article number must appear in scores."
  "System prompt for the scoring request.")

(defvar erik/news-digest-synthesis-system-prompt
  "You summarise one week of reading for a specific reader.

You will be given the articles selected for this week's digest.  Write one
paragraph of at most 120 words describing what they are collectively about,
naming any place where two of them disagree or where one complicates
another.  Do not list the articles and do not refer to any of them by
number.  Refer to a piece by its title or by what it is about.

Reply with the paragraph only.  No preamble, no markdown, no heading."
  "System prompt for the synthesis request.")

;;; ----------------------------------------------------------------- helpers

(defun erik/news-digest--plain-text (string)
  "Strip tags, entities and boilerplate from STRING; collapse whitespace."
  (let ((s (or string "")))
    (setq s (replace-regexp-in-string "<[^>]*>" " " s))
    (dolist (pair '(("&nbsp;"  . " ") ("&amp;"   . "&") ("&lt;"    . "<")
                    ("&gt;"    . ">") ("&quot;"  . "\"") ("&apos;"  . "'")
                    ("&#39;"   . "'") ("&#8217;" . "'") ("&hellip;" . "...")
                    ("&mdash;" . "—") ("&ndash;" . "–")))
      (setq s (replace-regexp-in-string (car pair) (cdr pair) s t t)))
    (dolist (re erik/news-digest-strip-patterns)
      (setq s (replace-regexp-in-string re "" s)))
    (string-trim (replace-regexp-in-string "[ \t\n\r]+" " " s))))

(defun erik/news-digest--truncate (text limit)
  "Return TEXT cut to LIMIT characters, with an ellipsis if cut."
  (if (<= (length text) limit)
      text
    (concat (substring text 0 limit) "...")))

(defun erik/news-digest--summary (entry)
  "Return ENTRY's text as plain text, truncated, or nil if empty."
  (let ((text (erik/news-digest--plain-text
               (elfeed-deref (elfeed-entry-content entry)))))
    (and (> (length text) 0)
         (erik/news-digest--truncate text erik/news-digest-summary-max-chars))))

(defun erik/news-digest--category (entry)
  "Return the (TAG . HEADING) cell ENTRY belongs to."
  (let ((tags (elfeed-entry-tags entry)))
    (or (seq-find (lambda (cell) (memq (car cell) tags))
                  erik/news-digest-categories)
        '(other . "Other"))))

(defun erik/news-digest--source (entry)
  "Return the display name of ENTRY's feed."
  (let ((feed (elfeed-entry-feed entry)))
    (or (and feed (elfeed-meta feed :title))
        (and feed (elfeed-feed-title feed))
        "unknown source")))

(defun erik/news-digest--title (entry)
  "Return ENTRY's title as plain text."
  (erik/news-digest--plain-text
   (or (elfeed-entry-title entry) "(untitled)")))

;;; --------------------------------------------------------------- selection

(defun erik/news-digest--collect (&optional uncapped)
  "Walk the elfeed database and return (ENTRIES . OMITTED).
ENTRIES is newest-first.  With UNCAPPED non-nil, every entry in the window is
returned and OMITTED is empty; otherwise the caps are applied by recency."
  (let* ((cutoff (- (float-time) (* erik/news-digest-days 86400)))
         (taken (make-hash-table :test 'equal))
         (omitted (make-hash-table :test 'equal))
         (total 0)
         (kept nil))
    (with-elfeed-db-visit (entry _feed)
      (when (< (elfeed-entry-date entry) cutoff)
        (elfeed-db-return))
      (when (memq erik/news-digest-tag (elfeed-entry-tags entry))
        (let* ((source (erik/news-digest--source entry))
               (n (gethash source taken 0)))
          (if (or uncapped
                  (and (< n erik/news-digest-max-per-feed)
                       (< total erik/news-digest-max-total)))
              (progn
                (puthash source (1+ n) taken)
                (setq total (1+ total))
                (push entry kept))
            (puthash source (1+ (gethash source omitted 0)) omitted)))))
    (cons (nreverse kept) omitted)))

(defun erik/news-digest--sort (entries scores)
  "Return ENTRIES ordered by descending score, unchanged when SCORES is nil."
  (if (null scores)
      entries
    (sort (copy-sequence entries)
          (lambda (a b)
            (> (or (gethash a scores) 0)
               (or (gethash b scores) 0))))))

(defun erik/news-digest--select (entries scores)
  "Apply the caps to ENTRIES in descending SCORES order.
Return (KEPT . OMITTED), so what survives is the best-scoring rather than
the most recent."
  (let ((taken (make-hash-table :test 'equal))
        (omitted (make-hash-table :test 'equal))
        (total 0)
        (kept nil))
    (dolist (entry (erik/news-digest--sort entries scores))
      (let* ((source (erik/news-digest--source entry))
             (n (gethash source taken 0)))
        (if (and (< n erik/news-digest-max-per-feed-scored)
                 (< total erik/news-digest-max-total))
            (progn
              (puthash source (1+ n) taken)
              (setq total (1+ total))
              (push entry kept))
          (puthash source (1+ (gethash source omitted 0)) omitted))))
    (cons (nreverse kept) omitted)))

;;; ---------------------------------------------------------------- renderer

(defun erik/news-digest--insert-entry (entry scores)
  "Insert ENTRY as an org subtree.  SCORES may be nil."
  (let ((score (and scores (gethash entry scores)))
        (summary (erik/news-digest--summary entry)))
    (insert (format "** %s\n"
                    (org-link-make-string (or (elfeed-entry-link entry) "")
                                          (erik/news-digest--title entry))))
    (insert ":PROPERTIES:\n")
    (insert (format ":SOURCE: %s\n" (erik/news-digest--source entry)))
    (insert (format ":DATE: %s\n"
                    (format-time-string
                     "%Y-%m-%d"
                     (seconds-to-time (elfeed-entry-date entry)))))
    (when score
      (insert (format ":SCORE: %s\n" score)))
    (insert ":END:\n")
    (when summary
      (insert summary "\n"))
    (insert "\n")))

(defun erik/news-digest--render (entries omitted week start end scores synthesis)
  "Return the org document for ENTRIES as a string."
  (let* ((low (when scores
                (seq-filter (lambda (e)
                              (< (or (gethash e scores) 10)
                                 erik/news-digest-score-threshold))
                            entries)))
         (main (seq-difference entries low)))
    (with-temp-buffer
      (insert (format "#+title: News — %s (%s – %s)\n" week start end))
      (insert "#+startup: content\n")
      (insert (format "#+created: %s\n\n" (format-time-string "%Y-%m-%d %H:%M")))
      (when synthesis
        (insert "* Synthesis\n")
        (insert synthesis "\n\n"))
      (dolist (cell (append erik/news-digest-categories '((other . "Other"))))
        (let ((group (erik/news-digest--sort
                      (seq-filter
                       (lambda (e)
                         (eq (car (erik/news-digest--category e)) (car cell)))
                       main)
                      scores)))
          (when group
            (insert (format "* %s (%d)\n\n" (cdr cell) (length group)))
            (dolist (entry group)
              (erik/news-digest--insert-entry entry scores)))))
      (when low
        (insert (format "* Lower priority (%d)\n\n" (length low)))
        (dolist (entry (erik/news-digest--sort low scores))
          (erik/news-digest--insert-entry entry scores)))
      (when (> (hash-table-count omitted) 0)
        (insert "* Omitted\n")
        (let (lines)
          (maphash (lambda (source n)
                     (push (format "- %d more from %s\n" n source) lines))
                   omitted)
          (dolist (line (sort lines #'string<))
            (insert line))))
      (buffer-string))))

;;; ------------------------------------------------------------------ output

(defun erik/news-digest--file ()
  "Return the path of this week's digest file, creating its directory."
  (let ((dir (or erik/news-digest-directory
                 (expand-file-name "news/" (or (bound-and-true-p org-directory)
                                               "~/org/")))))
    (make-directory dir t)
    (expand-file-name (concat (format-time-string "%G-W%V") ".org") dir)))

(defun erik/news-digest--write (entries omitted scores synthesis)
  "Render and write the digest file.  Return its path."
  (let* ((now (current-time))
         (start (time-subtract now (seconds-to-time
                                    (* erik/news-digest-days 86400))))
         (file (erik/news-digest--file))
         (text (erik/news-digest--render
                entries omitted
                (format-time-string "%G-W%V" now)
                (format-time-string "%b %-d" start)
                (format-time-string "%b %-d" now)
                scores synthesis)))
    (with-temp-file file (insert text))
    file))

(defun erik/news-digest--mark-read (entries)
  "Mark ENTRIES read in elfeed and refresh the search buffer."
  (when erik/news-digest-mark-read
    (dolist (entry entries)
      (elfeed-untag entry 'unread))
    (elfeed-db-save)
    (when (get-buffer "*elfeed-search*")
      (with-current-buffer "*elfeed-search*"
        (elfeed-search-update :force)))))

(defun erik/news-digest--wait-for-fetch ()
  "Run `elfeed-update' and block until the queue drains or time runs out."
  (elfeed-update)
  (let ((deadline (+ (float-time) erik/news-digest-fetch-timeout)))
    (while (and (> (elfeed-queue-count-total) 0)
                (< (float-time) deadline))
      (sit-for 0.3))))

;;;###autoload
(defun erik/news-digest (&optional fetch)
  "Write this week's digest to a static org file and open it.
Caps are applied by recency.  With prefix argument FETCH, update the feeds
first and wait for them."
  (interactive "P")
  (require 'elfeed)
  (when fetch
    (erik/news-digest--wait-for-fetch))
  (let* ((result (erik/news-digest--collect))
         (entries (car result))
         (omitted (cdr result)))
    (if (null entries)
        (message "News digest: nothing tagged %s in the last %d days."
                 erik/news-digest-tag erik/news-digest-days)
      (let ((file (erik/news-digest--write entries omitted nil nil)))
        (erik/news-digest--mark-read entries)
        (find-file file)
        (message "News digest: %d entries -> %s" (length entries) file)))))

;;; --------------------------------------------------------------------- llm

(defun erik/news-digest--backend ()
  "Return the configured gptel backend object, or nil."
  (cdr (assoc erik/news-digest-backend-name
              (symbol-value 'gptel--known-backends))))

(defun erik/news-digest--request (prompt system on-success on-failure)
  "Send PROMPT with SYSTEM to the configured backend.
Call ON-SUCCESS with the response text, or ON-FAILURE with no arguments."
  (let ((gptel-backend (or (erik/news-digest--backend)
                           (symbol-value 'gptel-backend)))
        (gptel-model (or erik/news-digest-model
                         (symbol-value 'gptel-model))))
    (gptel-request prompt
      :system system
      :callback
      (lambda (response _info)
        (if (not (stringp response))
            (funcall on-failure)
          (condition-case err
              (funcall on-success response)
            (error
             (message "News digest: %s" (error-message-string err))
             (funcall on-failure))))))))

(defun erik/news-digest--prompt (entries &optional header)
  "Build a user message listing ENTRIES, preceded by HEADER."
  (with-temp-buffer
    (insert (or header
                (concat "READER\n\n" erik/news-digest-profile "\n\n"))
            "ARTICLES\n\n")
    (let ((i 0))
      (dolist (entry entries)
        (setq i (1+ i))
        (insert (format "%d. [%s] %s\n" i
                        (erik/news-digest--source entry)
                        (erik/news-digest--title entry)))
        (let ((text (erik/news-digest--summary entry)))
          (when text
            (insert (erik/news-digest--truncate
                     text erik/news-digest-prompt-chars)
                    "\n")))
        (insert "\n")))
    (buffer-string)))

(defun erik/news-digest--parse (response entries)
  "Parse RESPONSE into a score table keyed by entry."
  (let* ((clean (string-trim
                 (replace-regexp-in-string "```\\(?:json\\)?" "" response)))
         (data (json-parse-string clean :object-type 'hash-table))
         (raw (gethash "scores" data))
         (scores (make-hash-table :test 'eq))
         (i 0))
    (dolist (entry entries)
      (setq i (1+ i))
      (let ((v (and raw (gethash (number-to-string i) raw))))
        (when (numberp v)
          (puthash entry v scores))))
    scores))

;;;###autoload
(defun erik/news-digest-enrich ()
  "Score every entry in the window, keep the best, and write the digest.
Two requests: the first scores the whole window, so nothing is discarded
before the model has seen it; the second writes the synthesis paragraph over
the entries that were actually kept, so it never describes an article
missing from the file.  The digest is written after the first request, so a
failure in the second still leaves a usable file."
  (interactive)
  (require 'elfeed)
  (require 'gptel)
  (let ((entries (car (erik/news-digest--collect t))))
    (when (null entries)
      (user-error "News digest: nothing to score"))
    (erik/news-digest--request
     (erik/news-digest--prompt entries)
     erik/news-digest-score-system-prompt
     (lambda (response)
       (let* ((scores (erik/news-digest--parse response entries))
              (chosen (erik/news-digest--select entries scores))
              (kept (car chosen))
              (omitted (cdr chosen)))
         (erik/news-digest--write kept omitted scores nil)
         (erik/news-digest--mark-read entries)
         (message "News digest: scored %d, kept %d; writing synthesis..."
                  (hash-table-count scores) (length kept))
         (erik/news-digest--request
          (erik/news-digest--prompt
           kept "These are the articles selected for this week.\n\n")
          erik/news-digest-synthesis-system-prompt
          (lambda (synthesis)
            (let ((file (erik/news-digest--write
                         kept omitted scores (string-trim synthesis))))
              (find-file file)
              (message "News digest: %d entries -> %s" (length kept) file)))
          (lambda ()
            (find-file (erik/news-digest--file))
            (message "News digest: synthesis failed; digest written without it")))))
     (lambda ()
       (message "News digest: scoring failed; file unchanged")))
    (message "News digest: scoring %d entries..." (length entries))))

(provide 'news-digest)
;;; news-digest.el ends here
