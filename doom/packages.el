;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el
;;
;; Declare packages here, then run 'doom sync' and restart Emacs.
;;   (package! NAME)
;;   (package! NAME :recipe (:host github :repo "user/repo"))
;;   (package! NAME :disable t)   ; disable one Doom ships with

;; org
(package! org-modern)
(package! org-drill)                    ; spaced-repetition note cards
(package! ox-ipynb
  :recipe (:host github :repo "jkitchin/ox-ipynb"))

;; ai
(unpin! gptel)
;; (package! gptel)                        ; multi-backend LLM client
                                        ; (Doom's ':tools llm' also ships this)

;; quarto
(package! quarto-mode)

;; just
(package! just-mode)
