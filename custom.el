;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("3061706fa92759264751c64950df09b285e3a2d3a9db771e99bcbb2f9b470037"
     "452068f2985179294c73c5964c730a10e62164deed004a8ab68a5d778a2581da"
     "aec7b55f2a13307a55517fdf08438863d694550565dee23181d2ebd973ebd6b8"
     "f4d1b183465f2d29b7a2e9dbe87ccc20598e79738e5d29fc52ec8fb8c576fcfd"
     "0d2c5679b6d087686dcfd4d7e57ed8e8aedcccc7f1a478cd69704c02e4ee36fe"
     "c1d5759fcb18b20fd95357dcd63ff90780283b14023422765d531330a3d3cec2"
     "32f22d075269daabc5e661299ca9a08716aa8cda7e85310b9625c434041916af" default))
 '(gptel-context-restrict-to-project-files nil)
 '(org-agenda-files
   '("~/personal/projects/org_mode_note_taking/stage-5-navigation.org"))
 '(package-selected-packages '(@ ess gptel org-drill org-pomodoro))
 '(safe-local-variable-values
   '((eval add-hook 'after-save-hook
      (lambda nil
        (when
            (string-equal (file-name-nondirectory buffer-file-name) "README.org")
          (org-pandoc-export-to-gfm)))
      nil t)
     (org-roam-db-location
      . "~/workspace/transcendence/Notes/roam/transcendence.db")
     (org-roam-directory . "~/workspace/transcendence/Notes/roam"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(put 'customize-variable 'disabled nil)
