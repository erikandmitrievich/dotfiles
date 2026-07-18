;;; init.el -*- lexical-binding: t; -*-

;; Controls which Doom modules load, and in what order. Run 'doom sync' after
;; editing. 'SPC h d h' for docs, 'K' on a module name for its README.

(doom! :input
       ;;bidi
       ;;chinese
       ;;japanese
       ;;layout

       :completion
       ;;company             ; superseded by corfu
       ;;(corfu +orderless)  ; in-buffer completion -- you have LSP but no popup
       vertico             ; minibuffer completion

       :ui
       doom
       doom-dashboard
       (emoji +unicode)
       hl-todo
       modeline
       ophints
       (popup +defaults)
       ;;smooth-scroll     ; drop the ';;' to enable (was typo'd as 'mooth-scroll')
       treemacs
       (vc-gutter +pretty)
       vi-tilde-fringe
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       snippets

       :emacs
       dired
       electric
       eww
       undo
       vc

       :term
       eshell
       vterm

       :checkers
       syntax

       :tools
       ein
       (eval +overlay)
       lookup
       lsp
       magit
       (pass +auth)
       pdf
       tree-sitter

       :os
       (:if (featurep :system 'macos) macos)
       tty

       :lang
       (cc +lsp)
       data
       emacs-lisp
       (ess +lsp)
       json
       (javascript +lsp)
       (typescript +lsp)
       julia
       (latex +cdlatex +latexmk)
       lean
       markdown
       (org +roam2)
       (python +lsp)
       sh
       yaml

       :email
       ;;(mu4e +org +gmail)

       :app
       ;;calendar
       ;;(rss +org)

       :config
       (default +bindings +smartparens))
