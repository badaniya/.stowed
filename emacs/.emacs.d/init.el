(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(add-to-list 'package-archives '("org" . "https://orgmode.org/elpa/") t)

;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.  
(package-initialize)

;; refresh package list if it is not already available
(when (not package-archive-contents) (package-refresh-contents))

;; install use-package if it isn't already installed
(when (not (package-installed-p 'use-package))
  (package-install 'use-package))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-faces-vector
   [default default default italic underline success warning error])
 '(company-quickhelp-color-background "#4F4F4F")
 '(company-quickhelp-color-foreground "#DCDCCC")
 '(custom-enabled-themes '(tango))
 '(custom-safe-themes
   '("e6df46d5085fde0ad56a46ef69ebb388193080cc9819e2d6024c9c6e27388ba9" "84d2f9eeb3f82d619ca4bfffe5f157282f4779732f48a5ac1484d94d5ff5b279" "9ffe970317cdfd1a9038ee23f4f5fe0b28b99950281799e4397e1a1380123147" "8efa3d21b3fa1ac084798fae4e89848ec26ae5c724b9417caf4922f4b2e31c2a" default))
 '(fci-rule-color "#383838")
 '(nrepl-message-colors
   '("#CC9393" "#DFAF8F" "#F0DFAF" "#7F9F7F" "#BFEBBF" "#93E0E3" "#94BFF3" "#DC8CC3"))
 '(package-selected-packages
   '(treemacs-tab-bar treemacs-magit treemacs-all-the-icons treemacs treemacs-projectile all-the-icons dap-mode company-go lsp-treemacs ox-jira help-find-org-mode gotest go-dlv lsp-mode cmake-ide rtags zotxt helm-gtags windresize helm-git-grep helm-ls-git helm-projectile org-plus-contrib helm-git helm-chrome helm go-guru org org-evil evil-magit ggtags treemacs-evil evil powerline magit zenburn-theme neotree go-mode gnu-elpa-keyring-update ##))
 '(pdf-view-midnight-colors '("#DCDCCC" . "#383838"))
 '(show-paren-mode t)
 '(vc-annotate-background "#2B2B2B")
 '(vc-annotate-color-map
   '((20 . "#BC8383")
     (40 . "#CC9393")
     (60 . "#DFAF8F")
     (80 . "#D0BF8F")
     (100 . "#E0CF9F")
     (120 . "#F0DFAF")
     (140 . "#5F7F5F")
     (160 . "#7F9F7F")
     (180 . "#8FB28F")
     (200 . "#9FC59F")
     (220 . "#AFD8AF")
     (240 . "#BFEBBF")
     (260 . "#93E0E3")
     (280 . "#6CA0A3")
     (300 . "#7CB8BB")
     (320 . "#8CD0D3")
     (340 . "#94BFF3")
     (360 . "#DC8CC3")))
 '(vc-annotate-very-old-color "#DC8CC3")
 '(warning-suppress-log-types '((emacs) (emacs)))
 '(warning-suppress-types '((emacs) (emacs))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; Evil - Extensible VI Layer for Emacs
(use-package evil
  :ensure t
  :config
  (evil-mode 1)
  )

;; evil-org-mode - keybindgs for org-mode
(use-package evil-org
  :ensure t
  :hook (evil-org-mode . org-mode-hook)
  :config
  (evil-org-set-key-theme
   '(navigation insert textobjects additional calendar)
   )
  )

;; LSP-Mode
(use-package lsp-mode
  :ensure t
  :commands (lsp lsp-deferred)
  :hook ((go-mode . lsp-deferred)
         ;;Set up before-save hooks to format buffer and add/delete imports.
         (before-save-hook . lsp-organize-imports)
         (before-save-hook . lsp-format-buffer)
         (go-mode-hook . lsp-go-install-save-hooks)
         )
  :bind (("C-c d" . lsp-describe-thing-at-point)
         ("C-c e r" . lsp-find-references)
         ("C-c e d" . lsp-find-definition)
         ("C-c e i" . lsp-find-implementation)
         ("C-c e t" . lsp-find-type-definition)
         )
  :init
  ;;Make sure you don't have other gofmt/goimports hooks enabled.
  (defun lsp-go-install-save-hooks ()
    (add-hook 'before-save-hook #'lsp-organize-imports t t)
    )
 
  :config
  ;;(lsp-register-custom-settings
  ;; '(
  ;;   ("gopls.expandWorkspaceToModule" t t)
  ;;   ("gopls.experimentalWorkspaceModule" t t)
  ;;   ("gopls.allowModfileModifications" t t)
  ;;   )
  ;;  )
  (setq lsp-gopls-complete-unimported t)
  (setq lsp-gopls-staticcheck t)
  (setq lsp-go-use-gofumpt t)
  (setq lsp-eldoc-render-all t)
  (setq lsp-enable-file-watchers t)
  (setq lsp-file-watch-threshold 50000)
  )

;;Optional - provides fancier overlays.
(use-package lsp-ui
  :ensure t
  :commands lsp-ui-mode
  :config
  ;;lsp-ui-doc-enable is false because I don't like the popover that shows up on the right
  (setq lsp-ui-doc-enable nil
        lsp-ui-peek-enable t
        lsp-ui-sideline-enable t
        lsp-ui-imenu-enable t
        lsp-ui-flycheck-enable t
        )
  )

;;Company mode is a standard completion package that works well with lsp-mode.
;;company-lsp integrates company mode completion with lsp-mode.
;;completion-at-point also works out of the box but doesn't support snippets.
(use-package company
  :ensure t
  :config
  (progn
    ;; don't add any delay before trying to complete thing being typed
    ;; the call/response to gopls is asynchronous so this should have little
    ;; to no affect on edit latency
    (setq company-idle-delay 0)
    ;; start completing after a single character instead of 3
    (setq company-minimum-prefix-length 1)
    ;; align fields in completions
    (setq company-tooltip-align-annotations t)
    )
  :hook (after-init-hook . global-company-mode)
  )

;;Optional - provides snippet support.
(use-package yasnippet
  :ensure t
  :commands yas-minor-mode
  :hook (go-mode . yas-minor-mode)
  )

;; Magit
(use-package magit
  :ensure t
  :bind (("C-x g" . magit-status)
         ("C-x M-g" . magit-dispatch)
         )
  :config
  )

;; Graphics for Neotree
(use-package all-the-icons
  :ensure t
  :if (display-graphic-p)
  )

;; Neotree package setup
(defun neotree-project-dir ()
  (interactive)
  (if (and (fboundp 'neo-global--window-exists-p)
           (neo-global--window-exists-p))
      (neotree-hide)
    (progn
      (neotree-dir "/home/badaniya/workspace/badaniya"))
    )
  )

(use-package neotree
  :ensure t
  :bind (:map global-map
              ("C-x n t" . neotree-project-dir)
              )
  :config
  (progn
    (setq neo-theme (if (display-graphic-p) 'icons 'arrow)
          neo-smart-open                   t
          projectile-switch-project-action 'neotree-projectile-action
          )
    )
  )

;; Treemacs packaage setup
(use-package treemacs
  :ensure t
  :defer t
  :bind (:map global-map
              ("M-0"       . treemacs-select-window)
              ("C-x t 1"   . treemacs-delete-other-windows)
              ("C-x t t"   . treemacs)
              ("C-x t B"   . treemacs-bookmark)
              ("C-x t C-t" . treemacs-find-file)
              ("C-x t M-t" . treemacs-find-tag)
              )
  :init
  (with-eval-after-load 'winum
    (define-key winum-keymap (kbd "M-0") #'treemacs-select-window)
    )
  :config
  (progn
    (setq treemacs-collapse-dirs                 (if treemacs-python-executable 3 0)
          treemacs-deferred-git-apply-delay      0.5
          treemacs-directory-name-transformer    #'identity
          treemacs-display-in-side-window        t
          treemacs-eldoc-display                 t
          treemacs-file-event-delay              5000
          treemacs-file-extension-regex          treemacs-last-period-regex-value
          treemacs-file-follow-delay             0.2
          treemacs-file-name-transformer         #'identity
          treemacs-follow-after-init             t
          treemacs-git-command-pipe              ""
          treemacs-goto-tag-strategy             'refetch-index
          treemacs-indentation                   2
          treemacs-indentation-string            " "
          treemacs-is-never-other-window         nil
          treemacs-max-git-entries               5000
          treemacs-missing-project-action        'ask
          treemacs-move-forward-on-expand        nil
          treemacs-no-png-images                 nil
          treemacs-no-delete-other-windows       t
          treemacs-project-follow-cleanup        nil
          treemacs-persist-file                  (expand-file-name ".cache/treemacs-persist" user-emacs-directory)
          treemacs-position                      'left
          treemacs-recenter-distance             0.1
          treemacs-recenter-after-file-follow    nil
          treemacs-recenter-after-tag-follow     nil
          treemacs-recenter-after-project-jump   'always
          treemacs-recenter-after-project-expand 'on-distance
          treemacs-show-cursor                   nil
          treemacs-show-hidden-files             t
          treemacs-silent-filewatch              nil
          treemacs-silent-refresh                nil
          treemacs-sorting                       'alphabetic-asc
          treemacs-space-between-root-nodes      t
          treemacs-tag-follow-cleanup            t
          treemacs-tag-follow-delay              1.5
          treemacs-user-mode-line-format         nil
          treemacs-user-header-line-format       nil
          treemacs-width                         35
          treemacs-workspace-switch-cleanup      nil)

    ;; The default width and height of the icons is 22 pixels. If you are
    ;; using a Hi-DPI display, uncomment this to double the icon size.
    ;;(treemacs-resize-icons 44)

    (treemacs-follow-mode t)
    (treemacs-filewatch-mode t)
    (treemacs-fringe-indicator-mode t)
    (pcase (cons (not (null (executable-find "git")))
                 (not (null treemacs-python-executable)))
      (`(t . t)
       (treemacs-git-mode 'deferred))
      (`(t . _)
       (treemacs-git-mode 'simple))
      )
    )
  )

(use-package treemacs-evil
  :ensure t
  :after treemacs evil
  )

(use-package treemacs-magit
  :ensure t
  :after treemacs magit
  )

;; org-mode exporters
(eval-after-load "org"
  '(require 'ox-md nil t)
  )

;; Helm
(use-package helm
  :ensure t
  :config
  (helm-mode 1)
  (global-set-key [f6] 'helm-imenu)
  )

;; Helm-git-grep
;;(use-package helm-git-grep
;;  :ensure t
;;  :config
;;  (global-set-key (kbd "C-c g") 'helm-git-grep)
;;  ;;Invoke `helm-git-grep' from isearch.
;;  (define-key isearch-mode-map (kbd "C-c g") 'helm-git-grep-from-isearch)
;;  ;;Invoke `helm-git-grep' from other helm.
;;  (eval-after-load 'helm
;;    '(define-key helm-map (kbd "C-c g") 'helm-git-grep-from-helm)
;;    )
;;  )

;; Projectile
(use-package projectile
  :ensure t
  :config
  (projectile-mode 1)
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
  (define-key projectile-mode-map (kbd "s-p") 'projectile-command-map)
  (define-key projectile-mode-map [?\s-d] 'projectile-find-dir)
  (define-key projectile-mode-map [?\s-p] 'projectile-switch-project)
  (define-key projectile-mode-map [?\s-f] 'projectile-find-file)
  (define-key projectile-mode-map [?\s-g] 'projectile-grep)
  (setq projectile-project-search-path '("~/workspace/badaniya"))
;; (setq projectile-enable-caching t)
  ) 

(use-package use-package-hydra
  :ensure t
  )

;; Hydra
(use-package hydra
  :ensure t
  :init
  (add-hook 'dap-stopped-hook
            (lambda (arg) (call-interactively #'hydra-go/body))
            )
  :config
  (require 'dap-mode)
  (require 'dap-ui)
  (global-set-key (kbd "C-c h w") 'hydra-window-stuff/body)
  )

(defhydra hydra-go (:color pink :hint nil :foreign-keys run)
  "
 _n_: Next       _c_: Continue _g_: goroutines      _i_: break log
 _s_: Step in    _o_: Step out _k_: break condition _h_: break hit condition
 _Q_: Disconnect _q_: quit     _l_: locals
"
  
  ("n" dap-next)
  ("c" dap-continue)
  ("s" dap-step-in)
  ("o" dap-step-out)
  ("g" dap-ui-sessions)
  ("l" dap-ui-locals)
  ("e" dap-eval-thing-at-point)
  ("h" dap-breakpoint-hit-condition)
  ("k" dap-breakpoint-condition)
  ("i" dap-breakpoint-log-message)
  ("q" nil "quit" :color blue)
  ("Q" dap-disconnect :color red)
  )

(defhydra hydra-window-stuff (:hint nil)
  "
        Split: _v_ert  _s_:horz
       Delete: _c_lose  _o_nly
Switch Window: _h_:left  _j_:down  _k_:up  _l_:right
      Buffers: _p_revious  _n_ext  _b_:select  _f_ind-file  _F_projectile
       Winner: _u_ndo  _r_edo
       Resize: _H_:splitter left  _J_:splitter down  _K_:splitter up  _L_:splitter right
         Move: _a_:up  _z_:down  _i_menu
"

  ("z" scroll-up-line)
  ("a" scroll-down-line)
  ("i" idomenu)

  ("u" winner-undo)
  ("r" winner-redo)

  ("h" windmove-left)
  ("j" windmove-down)
  ("k" windmove-up)
  ("l" windmove-right)

  ("p" previous-buffer)
  ("n" next-buffer)
  ("b" ido-switch-buffer) 
  ("f" ido-find-file)
  ("F" projectile-find-file)
  
  ("s" split-window-below)
  ("v" split-window-right)

  ("c" delete-window)
  ("o" delete-other-windows)

  ("H" hydra-move-splitter-left)
  ("J" hydra-move-splitter-down)
  ("K" hydra-move-splitter-up)
  ("L" hydra-move-splitter-right)

  ("q" nil)
  )

;; Go DAP Delve - Go Debugger
(use-package dap-mode
  :ensure t
  :config
  (dap-mode 1)
  (setq dap-print-io t)
  (require 'dap-hydra)
  (require 'dap-dlv-go)
  (use-package dap-ui
    :ensure nil
    :config
    (dap-ui-mode 1)
    )
  )

(add-hook 'dap-stopped-hook
          (lambda (arg) (call-interactively #'dap-hydra))
          )

(provide 'gopls-config)

;; rg
(use-package rg
  :ensure t
  :config
  (rg-enable-default-bindings)
  (global-set-key [f9] 'rg-dwim)
  )

;; Go-Mode
(defun custom-go-mode ()
  (display-line-numbers-mode 1)
  )

(use-package go-mode
  :ensure t
  :defer t
  :mode ("\\.go\\'" . go-mode)
  :bind (("M-," . compile)
         ("M-]" . godef-jump)
         )
  :init
    (setq compile-command "echo Building... && go build -v && echo Testing... && go test -v && echo Linter... && golint")  
    (setq compilation-read-command nil)
    (add-hook 'go-mode-hook 'custom-go-mode)
    )
  
(setq compilation-window-height 14)
(defun my-compilation-hook ()
  (when (not (get-buffer-window "*compilation*"))
    (save-selected-window
      (save-excursion
	(let* ((w (split-window-vertically))
	       (h (window-height w)))
          (select-window w)
	  (switch-to-buffer "*compilation*")
	  (shrink-window (- h compilation-window-height))
          )
        )
      )
    )
  )
(add-hook 'compilation-mode-hook 'my-compilation-hook)

(global-set-key (kbd "C-c C-c") 'comment-or-uncomment-region)
(setq compilation-scroll-output t)

;; Yang-mode
(use-package yang-mode
  :ensure t
  )

;; C++ RTags
(use-package rtags
  :ensure t
  :hook (c++-mode . rtags-start-process-unless-running)
  :bind (("C-c c E" . rtags-find-symbol)
     ("C-c c e" . rtags-find-symbol-at-point)
     ("C-c c O" . rtags-find-references)
     ("C-c c o" . rtags-find-references-at-point)
     ("C-c c s" . rtags-find-file)
     ("C-c c v" . rtags-find-virtuals-at-point)
     ("C-c c F" . rtags-fixit)
     ("C-c c f" . rtags-location-stack-forward)
     ("C-c c b" . rtags-location-stack-back)
     ("C-c c n" . rtags-next-match)
     ("C-c c p" . rtags-previous-match)
     ("C-c c P" . rtags-preprocess-file)
     ("C-c c R" . rtags-rename-symbol)
     ("C-c c x" . rtags-show-rtags-buffer)
     ("C-c c T" . rtags-print-symbol-info)
     ("C-c c t" . rtags-symbol-type)
     ("C-c c I" . rtags-include-file)
     ("C-c c i" . rtags-get-include-file-for-symbol)
     )
  :config
  (setq rtags-completions-enabled t
        ;; rtags-path "/usr/local/share/emacs/site-lisp/rtags"
        ;; rtags-rc-binary-name "/usr/local/bin/rc"
        ;; rtags-rdm-binary-name "/usr/local/bin/"
        rtags-rc-binary-name "~/.emacs.d/rtags/bin/rc"
        rtags-rdm-binary-name "~/.emacs.d/rtags/bin/rdm"

        ;; rtags-use-helm t
        ;; rtags-display-result-backend 'helm
        rtags-autostart-diagnostics t)
  )

;;Live code checking.
(use-package flycheck-rtags
  :ensure t
  :config
  (progn
    ;; ensure that we use only rtags checking
    ;; https://github.com/Andersbakken/rtags#optional-1
    (defun setup-flycheck-rtags ()
      (flycheck-select-checker 'rtags)
      (setq-local flycheck-highlighting-mode nil) ;; RTags creates more accurate overlays.
      (setq-local flycheck-check-syntax-automatically nil)
      (rtags-set-periodic-reparse-timeout 2.0)  ;; Run flycheck 2 seconds after being idle.
      )
    (add-hook 'c-mode-hook #'setup-flycheck-rtags)
    (add-hook 'c++-mode-hook #'setup-flycheck-rtags)
    )
  )

(use-package company-rtags
  :ensure t
  :after company
  :config
  (progn
    ;; (push 'company-clang company-backends)
    ;; (push '(company-rtags company-clang company-keywords) company-backends)
    ;; (push 'company-rtags company-backends)
    (define-key c-mode-base-map (kbd "<C-tab>") (function company-complete))
    )
  )

(defun company-rtags-setup ()
  "Configure company-backends for company-rtags."
  (delete 'company-semantic company-backends)
  (setq rtags-completions-enabled t)
  (rtags-start-process-unless-running)
  (push '(company-rtags :with company-yasnippet) company-backends)
  )

(add-hook 'c++-mode-hook #'company-rtags-setup)
(add-hook 'c-mode-hook #'company-rtags-setup)

;; Personal Customizations
(use-package powerline
  :ensure t
  )

(powerline-default-theme)
(load-theme 'zenburn t)

;; Tab-line-mode
(global-tab-line-mode t)
;;(setq tab-line-new-button-show nil)  ;; do not show add-new button
;;(setq tab-line-close-button-show nil)  ;; do not show close button
;;(setq tab-line-separator "")  ;; set it to empty
(setq tab-line-tab-name-function #'my/tab-line-tab-name-buffer)
;; tab color settings
(set-face-attribute 'tab-line nil ;; background behind tabs
  :background "gray25"
  :foreground "gray30" 
  :distant-foreground "gray35"
  :height 1.0 
  :box nil
)
(set-face-attribute 'tab-line-tab nil ;; active tab in another window
  :inherit 'tab-line
  :background "gray35" 
  :foreground "gray65" 
  :box nil
)
(set-face-attribute 'tab-line-tab-current nil ;; active tab in current window
  :background "gray35" 
  :foreground "gray85" 
  :box nil
)
(set-face-attribute 'tab-line-tab-inactive nil ;; inactive tab
  :background "gray25" 
  :foreground "gray45" 
  :box nil
)
(set-face-attribute 'tab-line-highlight nil ;; mouseover
  :background "gray45" 
  :foreground 'unspecified
)
;; Set up powerline settings after colors are set
(defvar my/tab-height 22)
(defvar my/tab-left (powerline-wave-right 'tab-line nil my/tab-height))
(defvar my/tab-right (powerline-bar-left nil 'tab-line my/tab-height))
(defun my/tab-line-tab-name-buffer
  (buffer &optional _buffers)
  (powerline-render (list my/tab-left (format "%s" (buffer-name buffer)) my/tab-right))
  )

;; Shell command history key mapping (when using M-x shell)
;; These mapping don't quite work well with zsh (use M-x term instead)
;;(define-key comint-mode-map (kbd "<up>") 'comint-previous-input)
;;(define-key comint-mode-map (kbd "<down>") 'comint-next-input)
;;(define-key comint-mode-map (kbd "<tab>") 'comint-dynamic-complete)

;; General formatting options
(xterm-mouse-mode)
(global-set-key [mouse-4] (kbd "C-u 3 M-x scroll-down-line"))
(global-set-key [mouse-5] (kbd "C-u 3 M-x scroll-up-line"))

(setq-default tab-2idth 8)
(setq-default indent-tabs-mode nil)
(setq-default tab-stop-list (quote (4 8)))
(put 'list-timers 'disabled nil)
