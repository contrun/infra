;; -*- lexical-binding: t; coding: utf-8; no-byte-compile: t; -*-
;;; Main configuration file

(setq package-enable-at-startup nil)
;;----------------------------------------------------------------------------
;; Adjust garbage collection thresholds during startup, and thereafter
;;----------------------------------------------------------------------------
;; (toggle-debug-on-error)
(let ((normal-gc-cons-threshold (* 128 1024 1024))
      (init-gc-cons-threshold (* 256 1024 1024)))
  (setq gc-cons-threshold init-gc-cons-threshold)
  (add-hook 'emacs-startup-hook
            (lambda () (setq gc-cons-threshold normal-gc-cons-threshold))))
(setq read-process-output-max (* 1024 1024))
(require 'cl-lib)

(defun my/path-under-emacs-d (path)
  "Expand `PATH' to path under `my/emacs-d'"
  (expand-file-name path my/emacs-d))

(defun my/add-subdirs-to-load-path (dir)
  "Add every subdir of DIR to `load-path', do nothing on DIR does not exist"
  (let ((default-directory dir))
    (message "adding dir %s to load-path" dir)
    (normal-top-level-add-to-load-path '("."))
    (normal-top-level-add-subdirs-to-load-path)))

(dolist (dir '("lisp" "site-lisp"))
  (let ((dir (my/path-under-emacs-d dir)))
    (make-directory dir t)
    (my/add-subdirs-to-load-path dir)))

(load (my/path-under-emacs-d "secrets") t)



(setq straight-base-dir (expand-file-name "straight" my/emacs-d)
      straight-use-package-by-default t)

(defvar bootstrap-version)
(defun my/bootstrap-straight ()
  (let ((bootstrap-file (expand-file-name "straight/repos/straight.el/bootstrap.el" straight-base-dir))
        (bootstrap-version 5))
    (unless (file-exists-p bootstrap-file)
      (with-current-buffer
          (url-retrieve-synchronously
           "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
           'silent 'inhibit-cookies)
        (goto-char (point-max))
        (eval-print-last-sexp)))
    (load bootstrap-file nil 'nomessage)))
(my/bootstrap-straight)

(straight-use-package 'use-package)
(straight-use-package 'el-patch)
;; Enable defer and ensure by default for use-package
(setq use-package-always-defer t
      use-package-always-ensure t)



(use-package my/constants
  :ensure nil
  :straight nil
  :init
  (defconst my/initial-frame (selected-frame)
    "The frame (if any) active during Emacs initialization.")
  (defconst my/is-mac (eq system-type 'darwin))
  (defconst my/emacs-tmp-d (my/path-under-emacs-d "tmp")))



(use-package my/functions
  :ensure nil
  :straight nil
  :init
  (defun my/shell-command-to-string (command)
    "Just `shell-command-to-string' COMMAND without the trailing newline."
    (substring (shell-command-to-string command) 0 -1))

  (defun my/secrets (&rest args)
    "Obtain secrets from secret-tool."
    (my/shell-command-to-string
     (mapconcat
      'shell-quote-argument
      (cons "secretTool.py" args)
      " ")))

  (defun my/slugify (str)
    "Slugify STR."
    (replace-regexp-in-string
     "-+" "-"
     (replace-regexp-in-string
      " " "-"
      (replace-regexp-in-string
       "[^[:alnum:]()]" " "
       (replace-regexp-in-string
        "\\." ""
        (replace-regexp-in-string
         "&" " and "
         (replace-regexp-in-string
          "[\(\)]" ""
          (downcase str))))))))
  )



(use-package general
  :init
  (dolist (key '("s-q" "s-t" "s-h" "s-m" "<f1>" "s-g" "s-j" "s-k"
                 "<f2>" "s-o" "C-z"))
    (global-unset-key (kbd key)))

  ;; Set your own keyboard shortcuts to reload/save/switch WGs:
  ;; "s" == "Super" or "Win"-key, "S" == Shift, "C" == Control
  (defvar my-major-mode-leader-key ","
    "Major mode leader key is a shortcut key which is the equivalent of
pressing `<leader> m`. Set it to `nil` to disable it.")
  (setq my/leader1 "s-,")
  (general-define-key :prefix my/leader1
                      "g" 'counsel-git
                      "s" 'counsel-git-grep
                      "k" 'counsel-ag
                      "L" 'counsel-locate
                      "b" 'link-hint-open-link
                      "l" 'link-hint-copy-link
                      "a" 'org-agenda
                      "p" 'prodigy
                      "x" 'my/expand-file-name-at-point
                      "m" 'mu4e
                      "o" 'crux-open-with
                      "f" 'dired
                      "F" 'my/toggle-format-project-files
                      "j" 'ein:jupyter-server-start
                      "r" 'ivy-resume
                      "i" 'counsel-info-lookup-symbol
                      "u" 'counsel-unicode-char
                      "n" 'simplenote2-list
                      "d" 'helm-dash-at-point
                      "D" 'helm-dash
                      "r" 'revert-buffer-no-confirm
                      "R" 'counsel-rhythmbox
                      "e" 'elfeed
                      )

  (global-set-key (kbd (format "%s %s" my/leader1 "[")) (kbd "C-x 3 C-u 30 C-x {"))
  (global-set-key (kbd (format "%s %s" my/leader1 "]")) (kbd "C-x 3 C-u 30 C-x }"))
  (global-set-key (kbd (format "%s %s" my/leader1 "^")) (kbd "C-x 2 C-u 5 C-x ^"))

  (setq persp-keymap-prefix (kbd "s-q"))
  ;; (setq wg-prefix-key (kbd "s-d"))
  (general-define-key
   "M-x" 'counsel-M-x
   "C-s" 'swiper
   "C-h f" 'counsel-describe-function
   "C-h v" 'counsel-describe-variable
   "C-h l" 'counsel-find-library
   "C-x C-f" 'counsel-find-file
   "C-x C-r" 'ivy-resume
   ;;  "s-/"  'wg-switch-to-previous-workgroup
   "s-w" 'bjm/kill-this-buffer
   "s-g" 'keyboard-quit
   "S-s-w" 'delete-window
   ;; "s-r" 'recentf-open-files
   ;; "s-b" 'ivy-switch-buffer
   "s-i" 'switch-to-minibuffer-window
   "s-j" 'dired-jump
   "s-f" 'counsel-find-file
   "s-s" 'modi/switch-to-scratch-and-back
   "s-m" 'magit-status
   "s-c" 'org-capture
   "s-u" 'undo-tree-visualize
   "s-b" 'ivy-switch-buffer
   ;; "s-r" 'session-jump-to-last-change
   "s-<tab>" 'nswbuff-switch-to-next-buffer
   "s-o" 'ace-window
   ;; "s-j" 'other-window
   "s-k" 'delete-window
   ;; "s-y" 'browse-kill-ring
   "s-t" 'taskwarrior
   "s-T" 'theme-looper-enable-random-theme
   "s-y" 'aya-expand
   "s-v" 'aya-create
   "s-d" 'helm-dash-at-point
   "s-S-d" 'helm-dash
   "s-z" 'fzf-directory
   "s-." 'ace-window
   ;; "s-q" 'save-buffers-kill-terminal
   "s-0" 'delete-window
   "s-1" 'my/toggle-delete-other-windows
   "s-2" 'my/split-window-below
   "s-3" 'my/split-window-right
   "C-:" 'avy-goto-char

   "M-s-p" 'sp-previous-sexp
   "M-s-n" 'sp-next-sexp
   "M-s-f" 'sp-forward-sexp
   "M-s-b" 'sp-backward-sexp
   "M-s-z" 'sp-backward-up-sexp
   "M-s-x" 'sp-backward-down-sexp
   "M-s-u" 'sp-up-sexp
   "M-s-d" 'sp-down-sexp
   "M-s-k" 'sp-kill-sexp
   "M-s-m" 'sp-mark-sexp
   "M-s-t" 'sp-transpose-sexp
   "M-s-i" 'sp-change-inner
   "M-s-D" 'sp-backward-kill-sexp
   "M-s-j" 'sp-join-sexp
   "M-s-s" 'sp-splice-sexp
   "M-s-c" 'sp-copy-sexp
   "M-s-;" 'sp-comment
   "M-s-a" 'sp-beginning-of-sexp
   "M-s-e" 'sp-end-of-sexp

   "<pause>" 'wg-reload-session
   "C-S-<pause>" 'wg-save-session

   "<f23>" 'set-mark-command)
  )

(use-package my/keymaps
  :ensure nil
  :straight nil
  :init
  (define-key read-expression-map (kbd "C-r") 'counsel-expression-history)

  ;; set up my own map
  (define-prefix-command 'customized-map)
  (global-set-key (kbd "<f2>") 'customized-map)

  ;; https://yoo2080.wordpress.com/2014/03/26/using-emacs-with-windows-8-touch-keyboard/
  (defun my/read-function-mapped-event ()
    "Read an event or function key.
  Like `read-event', but input is first translated according to
  `function-key-map' and `key-translation-map', so that a function key
  event may be composed."
    (let ((event (read-event)))
      (if (consp event)
          ;; Don't touch mouse events.
          event
        ;; Otherwise, block out the maps that are used after
        ;; key-translation-map, and call read-key-sequence.
        (push event unread-command-events)
        (let ((overriding-local-map (make-sparse-keymap))
              (global (current-global-map)))
          (unwind-protect
              (progn (use-global-map (make-sparse-keymap))
                     (let ((vec (read-key-sequence-vector nil)))
                       (if (> (length vec) 1)
                           (setq unread-command-events
                                 (cdr (append vec unread-command-events))))
                       (aref vec 0)))
            (use-global-map global))))))

  ;; These functions -- which are not commands -- each add one modifier
  ;; to the following event.

  (defun my/event-apply-alt-modifier (_ignore-prompt)
    "Add the Alt modifier to the following event.
  For example, type \\[my/event-apply-alt-modifier] & to enter Alt-&."
    `[,(my/event-apply-modifier (my/read-function-mapped-event) 'alt)])
  (defun my/event-apply-super-modifier (_ignore-prompt)
    "Add the Super modifier to the following event.
  For example, type \\[my/event-apply-super-modifier] & to enter Super-&."
    `[,(my/event-apply-modifier (my/read-function-mapped-event) 'super)])
  (defun my/event-apply-hyper-modifier (_ignore-prompt)
    "Add the Hyper modifier to the following event.
  For example, type \\[my/event-apply-hyper-modifier] & to enter Hyper-&."
    `[,(my/event-apply-modifier (my/read-function-mapped-event) 'hyper)])
  (defun my/event-apply-shift-modifier (_ignore-prompt)
    "Add the Shift modifier to the following event.
  For example, type \\[my/event-apply-shift-modifier] & to enter Shift-&."
    `[,(my/event-apply-modifier (my/read-function-mapped-event) 'shift)])
  (defun my/event-apply-control-modifier (_ignore-prompt)
    "Add the Control modifier to the following event.
  For example, type \\[my/event-apply-control-modifier] & to enter Control-&."
    `[,(my/event-apply-modifier (my/read-function-mapped-event) 'control)])
  (defun my/event-apply-meta-modifier (_ignore-prompt)
    "Add the Meta modifier to the following event.
  For example, type \\[my/event-apply-meta-modifier] & to enter Meta-&."
    `[,(my/event-apply-modifier (my/read-function-mapped-event) 'meta)])

  (defun my/event-apply-meta-super-modifier (_ignore-prompt)
    `[,(my/event-apply-modifier (my/event-apply-modifier (my/read-function-mapped-event) 'meta) 'super)])
  (defun my/event-apply-control-super-modifier (_ignore-prompt)
    `[,(my/event-apply-modifier (my/event-apply-modifier (my/read-function-mapped-event) 'control) 'super)])
  (defun my/event-apply-shift-super-modifier (_ignore-prompt)
    `[,(my/event-apply-modifier (my/event-apply-modifier (my/read-function-mapped-event) 'shift) 'super)])
  (defun my/event-apply-control-meta-modifier (_ignore-prompt)
    `[,(my/event-apply-modifier (my/event-apply-modifier (my/read-function-mapped-event) 'control) 'meta)])
  (defun my/event-apply-control-shift-modifier (_ignore-prompt)
    `[,(my/event-apply-modifier (my/event-apply-modifier (my/read-function-mapped-event) 'control) 'shift)])
  (defun my/event-apply-meta-shift-modifier (_ignore-prompt)
    `[,(my/event-apply-modifier (my/event-apply-modifier (my/read-function-mapped-event) 'meta) 'shift)])

  (defun my/event-apply-modifier (event modifier)
    "Apply a modifier flag to event EVENT.
  MODIFIER is the name of the modifier, as a symbol."
    (let ((modified (event-convert-list `(,modifier
                                          ,@(delq 'click (event-modifiers event))
                                          ,(event-basic-type event)))))
      (if (consp event)
          (cons modified (cdr event))
        modified)))

  (require 'cl-lib)
  (cl-loop for (ks def ok) in (list
                               (list "œ" 'my/event-apply-meta-modifier t)
                               (list "ō" 'my/event-apply-control-meta-modifier t)
                               (list "õ" 'my/event-apply-control-modifier t)
                               (list "ó" 'my/event-apply-control-shift-modifier t)
                               (list "ö" 'my/event-apply-shift-modifier t)
                               (list "ò" 'my/event-apply-meta-shift-modifier t)
                               (list "<f2>" 'my/event-apply-super-modifier t)
                               (list "<f5>" 'my/event-apply-meta-super-modifier t)
                               (list "<f8>" 'my/event-apply-super-modifier t)
                               (list "<f29>" (kbd my/leader1) t)
                               (list "<f31>" 'my/event-apply-super-modifier t)
                               (list "<f33>" (kbd "C-g") t)
                               (list "<kp-1>" 'my/event-apply-control-modifier t)
                               (list "<kp-2>" 'my/event-apply-meta-modifier t)
                               (list "<kp-3>" 'my/event-apply-super-modifier t)
                               (list "<kp-4>" 'my/event-apply-shift-modifier t)
                               (list "<kp-5>" 'my/event-apply-hyper-modifier t)
                               (list "<kp-6>" 'my/event-apply-alt-modifier t)

                               ;; for up and down
                               (list "ĝ" (kbd "<up>") t)
                               (list "ĥ" (kbd "<down>") t)

                               (list "s-g" (kbd "C-g") t)
                               ;; for quicker access to M-x, C-x, C-c
                               (list "ê" (kbd "M-x") t)
                               (list "ē" (kbd "C-x") t)
                               (list "é" (kbd "C-c") t))
           for key = (kbd ks)
           for bound = (key-binding key)
           do (progn (and bound
                          (not ok)
                          (warn "key %s is already bound to %s" ks bound))
                     (define-key key-translation-map key def)))
  )



(use-package el-get
  :init
  (defvar my/el-get-d
    (expand-file-name "el-get/el-get" my/emacs-d))
  (add-to-list 'load-path my/el-get-d)
  (setq el-get-recipe-path
        (list (expand-file-name "recipes" my/el-get-d)
              (expand-file-name "el-get/user/recipes" my/emacs-d)))
  (setq el-get-user-package-directory
        (expand-file-name "el-get/user/init-files" my/emacs-d)))

(use-package req-package)

;; (use-package quelpa)

;; (use-package quelpa-use-package)

;; (use-package auto-package-update
;;   :init
;;   (setq auto-package-update-delete-old-versions t)
;;   (setq auto-package-update-hide-results t)
;;   (auto-package-update-maybe))

(use-package paradox
  :defer t
  :custom
  (paradox-execute-asynchronously t)
  (paradox-lines-per-entry        1)
  (paradox-automatically-star     t)
  (paradox-github-token           nil)
  :commands (paradox-enable
             paradox-upgrade-packages
             paradox-list-packages))



(use-package ssh-agency)

(use-package exec-path-from-shell
  :init
  (setq exec-path-from-shell-variables '("SSH_AUTH_SOCK" "SSH_AGENT_PID" "GPG_AGENT_INFO" "LANG" "LC_CTYPE" "GOPATH" "PYTHONPATH" "PATH"))
  (when (memq window-system '(mac ns x))
    (exec-path-from-shell-initialize))
  )

(use-package no-littering
  :config
  (setq no-littering-etc-directory
        (expand-file-name "config/" user-emacs-directory))
  (setq no-littering-var-directory
        (expand-file-name "data/" user-emacs-directory))
  )

(use-package wgrep)
(use-package diminish)
(use-package scratch)
(use-package command-log-mode)

(use-package term-mode
  :ensure nil
  :straight nil
  :hook
  (term-mode-hook . (lambda () (setq line-spacing 0))))


(use-package disable-mouse)

(setq-default dired-dwim-target t)

;; Prefer g-prefixed coreutils version of standard utilities when available
(let ((gls (executable-find "gls")))
  (when gls (setq insert-directory-program gls)))

(use-package eww
  :ensure nil
  :straight nil
  :bind
  (:map eww-mode-map
        ("s" . my/eww-split-right)
        ("Q" . my/eww-quit))
  :hook
  (eww-after-render . my/set-eww-buffer-title)
  :init
  (defvar eww-previous-window-configuration nil
    "Window configuration before switching to eww buffer.")

  (defun my/set-eww-buffer-title ()
    (let* ((title  (plist-get eww-data :title))
           (url    (plist-get eww-data :url))
           (result (concat "*eww-" (or title
                                       (if (string-match "://" url)
                                           (substring url (match-beginning 0))
                                         url)) "*")))
      (rename-buffer result t)))

  (defun my/eww-quit ()
    "Bury eww buffer and restore the previous window configuration."
    (interactive)
    (quit-window)
    (if (window-configuration-p eww-previous-window-configuration)
        (progn
          (set-window-configuration eww-previous-window-configuration)
          (setq eww-previous-window-configuration nil))
      )
    )

  (defun eww-open-in-other-window (url)
    "Open eww in other window"
    (interactive
     (let* ((uris (eww-suggested-uris))
            (prompt (concat "Enter URL or keywords"
                            (if uris (format " (default %s)" (car uris)) "")
                            ": ")))
       (list (read-string prompt nil nil uris))))
    (setq eww-previous-window-configuration (current-window-configuration))
    (let* ((buffer (let ((buffer (get-buffer-create "*eww*")))
                     (with-current-buffer buffer
                       (unless (eq major-mode 'eww-mode)
                         (eww-mode)))
                     buffer))
           (window (get-buffer-window buffer)))
      (with-current-buffer buffer
        (if (null window)
            (switch-to-buffer-other-window buffer)
          (select-window window))
        (add-hook 'eww-mode-hook (local-set-key (kbd "q") 'my/eww-quit))
        (eww url)))
    )

  (defun my/open-in-right-window ()
    "Open the selected link on the right window plane"
    (interactive)
    (delete-other-windows nil)
    (split-window-right nil)
    (other-window 1)
    (org-return nil)
    )

  (defun my/eww-split-right ()
    "Splits the Window. Moves eww to the right and underlying content on the left."
    (interactive)
    (split-window-right nil)
    (quit-window nil)
    (other-window 1)
    )
  )

(use-package dired+
  :straight (dired+ :type git :host github :repo "emacsmirror/dired-plus"))

(use-package diredfl
  :after dired
  :config
  (diredfl-global-mode)
  )

(use-package dired
  :ensure nil
  :straight nil
  :config
  (setq dired-recursive-deletes 'top)
  (define-key dired-mode-map [mouse-2] 'dired-find-file)
  (define-key dired-mode-map (kbd "C-c C-p") 'wdired-change-to-wdired-mode)
  (defun kill-dired-buffers ()
    (interactive)
    (mapc (lambda (buffer)
            (when (eq 'dired-mode (buffer-local-value 'major-mode buffer))
              (kill-buffer buffer)))
          (buffer-list)))
  )

(use-package diff-hl
  :hook
  (dired-mode . diff-hl-dired-mode))

(use-package dired-atool
  :after dired)

(use-package dired-rsync
  :after dired)

;; (use-package dired-open
;;   :after dired)

(use-package dired-launch
  :after dired)

(use-package dired-ranger
  :after dired)

(use-package fd-dired
  :after dired)

;; (use-package dirvish)

(use-package fzf)

(use-package wakatime-mode
  :config
  (let ((api-key (shell-command-to-string "sed -En '/api_key\s*=\s*/ s/api_key\s*=\s*//p' ~/.wakatime.cfg")))
    (when api-key
      (customize-set-variable 'wakatime-api-key (substring api-key 0 -1))))
  (setq wakatime-disable-on-error t)
  :hook
  (after-init . global-wakatime-mode))

(use-package sunrise-commander
  :straight (sunrise-commander :type git :host github :repo "escherdragon/sunrise-commander"))

;; Show number of matches while searching
(use-package anzu)

;; Activate occur easily inside isearch
(with-eval-after-load 'isearch
  ;; DEL during isearch should edit the search string, not jump back to the previous result
  (define-key isearch-mode-map [remap isearch-delete-char] 'isearch-del-char)

  (when (fboundp 'isearch-occur)
    ;; to match ivy conventions
    (define-key isearch-mode-map (kbd "C-c C-o") 'isearch-occur)))

;; Search back/forth for the symbol at point
;; See http://www.emacswiki.org/emacs/SearchAtPoint
(defun isearch-yank-symbol ()
  "*Put symbol at current point into search string."
  (interactive)
  (let ((sym (thing-at-point 'symbol)))
    (if sym
        (progn
          (setq isearch-regexp t
                isearch-string (concat "\\_<" (regexp-quote sym) "\\_>")
                isearch-message (mapconcat 'isearch-text-char-description isearch-string "")
                isearch-yank-flag t))
      (ding)))
  (isearch-search-and-update))

(define-key isearch-mode-map "\C-\M-w" 'isearch-yank-symbol)


;; http://www.emacswiki.org/emacs/ZapToISearch
(defun my/isearch-exit-other-end (rbeg rend)
  "Exit isearch, but at the other end of the search string.
This is useful when followed by an immediate kill."
  (interactive "r")
  (isearch-exit)
  (goto-char isearch-other-end))

(define-key isearch-mode-map [(control return)] 'my/isearch-exit-other-end)

(setq-default grep-highlight-matches t
              grep-scroll-output t)

(use-package woman)

;; (use-package info+
;;   :straight (info+ :type git :host github :repo "emacsmirror/info-plus")
;;   :init (with-eval-after-load 'info
;;           (require 'info+))
;;   :defer t)

(use-package helm-dash
  :hook
  (haskell-mode . (lambda () (setq-local dash-docs-docsets '("Haskell"))))
  (rust-mode . (lambda () (setq-local dash-docs-docsets '("Rust"))))
  (scala-mode . (lambda () (setq-local dash-docs-docsets '("Scala"))))
  (python-mode . (lambda () (setq-local dash-docs-docsets '("Python_3"))))
  (c-mode . (lambda () (setq-local dash-docs-docsets '("C"))))
  (c++-mode . (lambda () (setq-local dash-docs-docsets '("C++"))))
  (plain-tex-mode . (lambda ()
                      (setq-local dash-docs-browser-func 'browse-url)
                      (setq-local dash-docs-docsets '("LaTeX"))))
  (latex-mode . (lambda ()
                  (setq-local dash-docs-browser-func 'browse-url)
                  (setq-local dash-docs-docsets '("LaTeX"))))
  (emacs-lisp-mode . (lambda () (setq-local dash-docs-docsets '("Emacs_Lisp"))))
  (ruby-mode . (lambda () (setq-local dash-docs-docsets '("Ruby"))))
  :config
  (setq dash-docs-browser-func 'eww-open-in-other-window)
  (defun dash-docs-browse-url-other-window (search-result)
    "Call to `browse-url' with the result returned by `dash-docs-result-url'.
Get required params to call `dash-docs-result-url' from SEARCH-RESULT."
    (let ((oldbuf (buffer-name))
          (this-is-the-only-window (< (length (window-list)) 2))
          (docset-name (car search-result))
          (filename (nth 2 (cadr search-result)))
          (anchor (nth 3 (cadr search-result))))
      (progn (if (eq dash-docs-browser-func 'eww)
                 (progn
                   (if this-is-the-only-window
                       (split-window-horizontally)
                     )
                   (other-window 1)
                   (eww (dash-docs-result-url docset-name filename anchor))
                   (my/split-window-right)
                   ;; (if this-is-the-only-window
                   ;;     (delete-other-windows)
                   ;;   )
                   ;; (switch-to-buffer oldbuf)
                   )
               (funcall dash-docs-browser-func (dash-docs-result-url docset-name filename anchor))
               )
             )
      )
    )
  (defun dash-docs-actions (actions doc-item)
    "Return an alist with the possible ACTIONS to execute with DOC-ITEM."
    (ignore doc-item)
    (ignore actions)
    `(("Go to doc" . dash-docs-browse-url)
      ("Go to doc other window" . dash-docs-browse-url-other-window)
      ("Copy to clipboard" . dash-docs-add-to-kill-ring)))
  )

(use-package ag
  :init
  (when (executable-find "ag")
    (global-set-key (kbd "M-?") 'ag-project))
  (use-package wgrep-ag)
  )

(use-package rg
  :init
  (when (executable-find "rg")
    (global-set-key (kbd "M-?") 'rg-project))
  (use-package deadgrep)
  )

(use-package helm-rg)

(use-package uniquify
  :ensure nil
  :straight nil
  :init
  (setq uniquify-buffer-name-style 'reverse)
  (setq uniquify-separator " • ")
  (setq uniquify-after-kill-buffer-p t)
  (setq uniquify-ignore-buffers-re "^\\*")
  )

;; TODO: enhance ibuffer-fontification-alist
;;   See http://www.reddit.com/r/emacs/comments/21fjpn/fontifying_buffer_list_for_emacs_243/

(use-package fullframe
  :init
  (with-eval-after-load 'ibuffer
    (fullframe ibuffer ibuffer-quit))
  )

(use-package ibuffer-vc)

(use-package ibuffer
  :ensure nil
  :straight nil
  :init
  (defun ibuffer-set-up-preferred-filters ()
    (ibuffer-vc-set-filter-groups-by-vc-root)
    (unless (eq ibuffer-sorting-mode 'filename/process)
      (ibuffer-do-sort-by-filename/process)))
  (with-eval-after-load 'ibuffer
    (require 'ibuffer-vc))
  (setq ibuffer-formats
        '((mark modified read-only vc-status-mini " "
                (name 18 18 :left :elide)
                " "
                (size-h 9 -1 :right)
                " "
                (mode 16 16 :left :elide)
                " "
                filename-and-process)
          (mark modified read-only vc-status-mini " "
                (name 18 18 :left :elide)
                " "
                (size-h 9 -1 :right)
                " "
                (mode 16 16 :left :elide)
                " "
                (vc-status 16 16 :left)
                " "
                filename-and-process)))

  (setq ibuffer-filter-group-name-face 'font-lock-doc-face)

  (global-set-key (kbd "C-x C-b") 'ibuffer)

  :hook
  (ibuffer . ibuffer-set-up-preferred-filters)
  :custom
  (ibuffer-show-empty-filter-groups nil)
  :config
  (define-ibuffer-column size-h
    (:name "Size" :inline t)
    (cond
     ((> (buffer-size) 1000000) (format "%7.1fM" (/ (buffer-size) 1000000.0)))
     ((> (buffer-size) 1000) (format "%7.1fk" (/ (buffer-size) 1000.0)))
     (t (format "%8d" (buffer-size)))))
  )

(use-package flycheck
  :hook
  (after-init . global-flycheck-mode)
  :custom
  (flycheck-display-errors-function #'flycheck-display-error-messages-unless-error-list)
  :init
  (defvar-local my/flycheck-local-cache nil)

  (defun my/flycheck-checker-get (fn checker property)
    (or (alist-get property (alist-get checker my/flycheck-local-cache))
        (funcall fn checker property)))

  (advice-add 'flycheck-checker-get :around 'my/flycheck-checker-get))

(use-package flycheck-color-mode-line
  :hook
  (flycheck-mode . flycheck-color-mode-line-mode))

(use-package flycheck-package
  :init
  (flycheck-package-setup))

(use-package quick-peek)

(use-package flycheck-inline
  :hook
  (flycheck-mode . flycheck-inline-mode))

(use-package editorconfig
  :diminish editorconfig-mode
  :config
  (editorconfig-mode 1))

(setq recentf-keep '(file-remote-p file-readable-p))
(setq-default
 recentf-max-saved-items 1000
 recentf-exclude '("/tmp/" "/sudo:"))

(use-package smex
  :init
  (setq-default smex-save-file (expand-file-name ".smex-items" my/emacs-d))
  (global-set-key [remap execute-extended-command] 'smex))

(use-package ivy
  :hook (after-init . ivy-mode)
  :diminish ivy-mode
  :init
  (setq-default ivy-use-virtual-buffers t
                ivy-virtual-abbreviate 'fullpath
                ivy-count-format ""
                projectile-completion-system 'ivy
                ivy-magic-tilde nil
                ivy-dynamic-exhibit-delay-ms 150
                ivy-initial-inputs-alist
                '((man . "^")
                  (woman . "^")))
  :config
  ;; IDO-style directory navigation
  (define-key ivy-minibuffer-map (kbd "RET") #'ivy-alt-done)
  (dolist (k '("C-j" "C-RET"))
    (define-key ivy-minibuffer-map (kbd k) #'ivy-immediate-done))

  (define-key ivy-minibuffer-map (kbd "<up>") #'ivy-previous-line-or-history)
  (defun my/enable-ivy-flx-matching ()
    "Make `ivy' matching work more like IDO."
    (interactive)
    (use-package flx)
    (setq-default ivy-re-builders-alist
                  '((t . ivy--regex-fuzzy))))
  )

(use-package counsel
  :diminish counsel-mode
  :hook
  (after-init . counsel-mode)
  :init
  (setq-default counsel-mode-override-describe-bindings t)

  (use-package projectile
    :config
    (let ((search-function
           (cond
            ((executable-find "rg") 'counsel-rg)
            ((executable-find "ag") 'counsel-ag)
            ((executable-find "pt") 'counsel-pt)
            ((executable-find "ack") 'counsel-ack))))
      (when search-function
        (defun my/counsel-search-project (initial-input &optional use-current-dir)
          "Search using `counsel-rg' or similar from the project root for INITIAL-INPUT.
If there is no project root, or if the prefix argument
USE-CURRENT-DIR is set, then search from the current directory
instead."
          (interactive (list (thing-at-point 'symbol)
                             current-prefix-arg))
          (let ((current-prefix-arg)
                (dir (if use-current-dir
                         default-directory
                       (condition-case err
                           (projectile-project-root)
                         (error default-directory)))))
            (funcall search-function initial-input dir)))
        (global-set-key (kbd "M-?") 'my/counsel-search-project)))
    )
  )


(use-package swiper
  :config
  (defun my/swiper-at-point (sym)
    "Use `swiper' to search for the symbol at point."
    (interactive (list (thing-at-point 'symbol)))
    (swiper sym))
  (define-key ivy-mode-map (kbd "M-s /") 'my/swiper-at-point)
  )


(use-package ivy-xref
  :custom
  (xref-show-xrefs-function 'ivy-xref-show-xrefs)
  )


(use-package hippie-expand
  :ensure nil
  :straight nil
  :init
  (global-set-key (kbd "M-/") 'hippie-expand)

  (setq hippie-expand-try-functions-list
        '(try-complete-file-name-partially
          try-complete-file-name
          try-expand-dabbrev
          try-expand-dabbrev-all-buffers
          try-expand-dabbrev-from-kill))
  )

(setq tab-always-indent 'complete)
(add-to-list 'completion-styles 'initials t)

(use-package company
  :diminish
  :init
  (global-company-mode 1)
  (defun local-push-company-backend (backend)
    "Add BACKEND to a buffer-local version of `company-backends'."
    (make-local-variable 'company-backends)
    (push backend company-backends))

  (global-set-key (kbd "M-C-/") 'company-complete)
  ;; (add-to-list 'company-backends 'company-files)
  (define-key company-mode-map (kbd "M-/") 'company-complete)
  (define-key company-active-map (kbd "M-/") 'company-other-backend)
  (define-key company-active-map (kbd "C-n") 'company-select-next)
  (define-key company-active-map (kbd "C-p") 'company-select-previous)
  (setq-default company-dabbrev-other-buffers 'all
                company-tooltip-align-annotations t)
  (with-eval-after-load 'page-break-lines
    (defvar my/page-break-lines-on-p nil)
    (make-variable-buffer-local 'my/page-break-lines-on-p)

    (defun my/page-break-lines-disable (&rest ignore)
      (when (setq my/page-break-lines-on-p (bound-and-true-p page-break-lines-mode))
        (page-break-lines-mode -1)))

    (defun my/page-break-lines-maybe-reenable (&rest ignore)
      (when my/page-break-lines-on-p
        (page-break-lines-mode 1)))

    (add-hook 'company-completion-started-hook 'my/page-break-lines-disable)
    (add-hook 'company-completion-finished-hook 'my/page-break-lines-maybe-reenable)
    (add-hook 'company-completion-cancelled-hook 'my/page-break-lines-maybe-reenable))
  )

(use-package company-posframe
  :hook (company-mode . company-posframe-mode))

(use-package company-box
  :diminish
  :hook (company-mode . company-box-mode))

(use-package company-tabnine
  :after company
  ;; :init
  ;; (when (member (system-name) '("ssg"))
  ;;   (add-to-list 'company-backends #'company-tabnine))
  )

(use-package company-quickhelp
  :hook
  (after-init . company-quickhelp-mode))



(use-package winner
  :ensure nil
  :straight nil
  :hook
  (after-init . winner-mode)
  )

(use-package ace-window)

(use-package treemacs)

(use-package my/window-managerment
  :ensure nil
  :straight nil
  :init

  ;; Make "C-x o" prompt for a target window when there are more than 2
  (use-package switch-window
    :bind
    ("C-x o" . switch-window)
    :init
    (setq-default switch-window-shortcut-style 'alphabet)
    (setq-default switch-window-timeout nil)
    )


  ;;----------------------------------------------------------------------------
  ;; When splitting window, show (other-buffer) in the new window
  ;;----------------------------------------------------------------------------
  (defun split-window-func-with-other-buffer (split-function)
    (lambda (&optional arg)
      "Split this window and switch to the new window unless ARG is provided."
      (interactive "P")
      (funcall split-function)
      (let ((target-window (next-window)))
        (set-window-buffer target-window (other-buffer))
        (unless arg
          (select-window target-window)))))

  (global-set-key (kbd "C-x 2") (split-window-func-with-other-buffer 'split-window-vertically))
  (global-set-key (kbd "C-x 3") (split-window-func-with-other-buffer 'split-window-horizontally))

  (defun my/toggle-delete-other-windows ()
    "Delete other windows in frame if any, or restore previous window config."
    (interactive)
    (if (and winner-mode
             (equal (selected-window) (next-window)))
        (winner-undo)
      (delete-other-windows)))

  (defun my/write-copy-to-file ()
    "Write a copy of the current buffer or region to a file."
    (interactive)
    (let* ((curr (buffer-file-name))
           (new (read-file-name
                 "Copy to file: " nil nil nil
                 (and curr (file-name-nondirectory curr))))
           (mustbenew (if (and curr (file-equal-p new curr)) 'excl t)))
      (if (use-region-p)
          (write-region (region-beginning) (region-end) new nil nil nil mustbenew)
        (save-restriction
          (widen)
          (write-region (point-min) (point-max) new nil nil nil mustbenew)))))

  ;;----------------------------------------------------------------------------
  ;; Rearrange split windows
  ;;----------------------------------------------------------------------------
  (defun split-window-horizontally-instead ()
    "Kill any other windows and re-split such that the current window is on the top half of the frame."
    (interactive)
    (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
      (delete-other-windows)
      (split-window-horizontally)
      (when other-buffer
        (set-window-buffer (next-window) other-buffer))))

  (defun split-window-vertically-instead ()
    "Kill any other windows and re-split such that the current window is on the left half of the frame."
    (interactive)
    (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
      (delete-other-windows)
      (split-window-vertically)
      (when other-buffer
        (set-window-buffer (next-window) other-buffer))))

  (global-set-key (kbd "C-x |") 'split-window-horizontally-instead)
  (global-set-key (kbd "C-x _") 'split-window-vertically-instead)

  ;; Borrowed from http://postmomentum.ch/blog/201304/blog-on-emacs
  (defun my/split-window-right()
    "Split the window to see the most recent buffer in the other window.
Call a second time to restore the original window configuration."
    (interactive)
    (if (eq last-command 'my/split-window-right)
        (progn
          (jump-to-register :my/split-window-right)
          (setq this-command 'my/unsplit-window-right))
      (window-configuration-to-register :my/split-window-right)
      (switch-to-buffer-other-window nil)))

  (defun my/split-window-below()
    "Split the window to see the most recent buffer in the other window.
Call a second time to restore the original window configuration."
    (interactive)
    (let ((split-width-threshold nil))
      (if (eq last-command 'my/split-window-below)
          (progn
            (jump-to-register :my/split-window-below)
            (setq this-command 'my/unsplit-window-below))
        (window-configuration-to-register :my/split-window-below)
        (switch-to-buffer-other-window nil))))

  (defun my/toggle-current-window-dedication ()
    "Toggle whether the current window is dedicated to its current buffer."
    (interactive)
    (let* ((window (selected-window))
           (was-dedicated (window-dedicated-p window)))
      (set-window-dedicated-p window (not was-dedicated))
      (message "Window %sdedicated to %s"
               (if was-dedicated "no longer " "")
               (buffer-name))))

  (unless (memq window-system '(nt w32))
    (windmove-default-keybindings 'control))
  )



(use-package session
  :demand t
  :config
  (setq session-jump-undo-threshold 80))

;;----------------------------------------------------------------------------
;; Multiple major modes
;;----------------------------------------------------------------------------
(use-package mmm-mode
  :init
  (require 'mmm-auto)
  (setq mmm-global-mode 'buffers-with-submode-classes)
  (setq mmm-submode-decoration-level 2)
  )

(use-package unfill)

(put 'set-goal-column 'disabled nil)

(use-package list-unicode-display)

(use-package goto-chg
  :commands goto-last-change
  ;; complementary to
  ;; C-x r m / C-x r l
  ;; and C-<space> C-<space> / C-u C-<space>
  :bind (("s-l" . goto-last-change)
         ("s-L" . goto-last-change-reverse)))

;;----------------------------------------------------------------------------
;; Some basic preferences
;;----------------------------------------------------------------------------
(setq-default
 blink-cursor-interval 0.4
 bookmark-default-file (expand-file-name ".bookmarks.el" my/emacs-d)
 buffers-menu-max-size 30
 case-fold-search t
 column-number-mode t
 delete-selection-mode t
 ediff-split-window-function 'split-window-horizontally
 ediff-window-setup-function 'ediff-setup-windows-plain
 indent-tabs-mode nil
 make-backup-files nil
 mouse-yank-at-point t
 save-interprogram-paste-before-kill t
 scroll-preserve-screen-position 'always
 set-mark-command-repeat-pop t
 tooltip-delay 1.5
 truncate-lines nil
 truncate-partial-width-windows nil)

(add-hook 'after-init-hook 'global-auto-revert-mode)
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose nil)
(with-eval-after-load 'autorevert
  (diminish 'auto-revert-mode))

(add-hook 'after-init-hook 'transient-mark-mode)



;; Huge files

(use-package vlf)

(defun ffap-vlf ()
  "Find file at point with VLF."
  (interactive)
  (let ((file (ffap-file-at-point)))
    (unless (file-exists-p file)
      (error "File does not exist: %s" file))
    (vlf file)))


;;; A simple visible bell which works in all terminal types
(use-package mode-line-bell
  :hook
  (after-init . mode-line-bell-mode)
  )



(use-package beacon
  :init
  (setq-default beacon-lighter "")
  (setq-default beacon-size 5)
  :hook
  (after-init . beacon-mode)
  )



;;; Newline behaviour

(global-set-key (kbd "RET") 'newline-and-indent)
(defun my/newline-at-end-of-line ()
  "Move to end of line, enter a newline, and reindent."
  (interactive)
  (move-end-of-line 1)
  (newline-and-indent))

(global-set-key (kbd "S-<return>") 'my/newline-at-end-of-line)



(use-package subword
  :diminish)



(use-package rainbow-delimiters
  :hook
  (prog-mode . rainbow-delimiters-mode)
  )



(use-package undo-tree
  :diminish undo-tree-mode
  :hook
  (after-init . global-undo-tree-mode)
  :custom
  (undo-tree-auto-save-history t)
  :init
  (setq undo-tree-history-directory-alist
        `(("" . ,(concat my/emacs-tmp-d "undo-hist")))))



(use-package my/save-and-backup
  :ensure nil
  :straight nil
  ;; :hook
  ;; (before-save . force-backup-of-buffer)
  :init
  ;; Put backup files neatly away
  (let ((backup-dir (expand-file-name "backup" my/emacs-tmp-d))
        (auto-saves-dir (expand-file-name "" my/emacs-tmp-d)))
    (dolist (dir (list backup-dir auto-saves-dir))
      (when (not (file-directory-p dir))
        (make-directory dir t)))
    (setq backup-directory-alist `(("" . ,backup-dir))
          auto-save-file-name-transforms `((".*" ,auto-saves-dir t))
          auto-save-list-file-prefix (concat auto-saves-dir ".saves-")
          tramp-backup-directory-alist `((".*" . ,backup-dir))
          tramp-auto-save-directory auto-saves-dir))

  (setq backup-by-copying t    ; Don't delink hardlinks
        delete-old-versions t  ; Clean up the backups
        version-control t      ; Use version numbers on backups,
        kept-new-versions 5    ; keep some new versions
        kept-old-versions 2)   ; and some old ones, too

  (defun force-backup-of-buffer ()
    ;; Make a special "per session" backup at the first save of each
    ;; emacs session.
    (when (not buffer-backed-up)
      ;; Override the default parameters for per-session backups.
      (let ((backup-directory-alist `(("" . ,(concat my/emacs-tmp-d "session-backup/"))))
            (kept-new-versions 3))
        (backup-buffer)))
    ;; Make a "per save" backup on each save.  The first save results in
    ;; both a per-session and a per-save backup, to keep the numbering
    ;; of per-save backups consistent.
    (let ((buffer-backed-up nil))
      (backup-buffer)))
  )



(use-package symbol-overlay
  :hook
  ((prog-mode html-mode css-mode yaml-mode conf-mode) . symbol-overlay-mode)
  :diminish symbol-overlay-mode
  :config
  (define-key symbol-overlay-mode-map (kbd "M-i") 'symbol-overlay-put)
  (define-key symbol-overlay-mode-map (kbd "M-n") 'symbol-overlay-jump-next)
  (define-key symbol-overlay-mode-map (kbd "M-p") 'symbol-overlay-jump-prev)
  )

;;----------------------------------------------------------------------------
;; Zap *up* to char is a handy pair for zap-to-char
;;----------------------------------------------------------------------------
(autoload 'zap-up-to-char "misc" "Kill up to, but not including ARGth occurrence of CHAR.")
(global-set-key (kbd "M-Z") 'zap-up-to-char)



(use-package browse-kill-ring
  :init
  (setq browse-kill-ring-separator "\f")
  (global-set-key (kbd "M-Y") 'browse-kill-ring)
  (with-eval-after-load 'browse-kill-ring
    (define-key browse-kill-ring-mode-map (kbd "C-g") 'browse-kill-ring-quit)
    (define-key browse-kill-ring-mode-map (kbd "M-n") 'browse-kill-ring-forward)
    (define-key browse-kill-ring-mode-map (kbd "M-p") 'browse-kill-ring-previous))
  (with-eval-after-load 'page-break-lines
    (push 'browse-kill-ring-mode page-break-lines-modes))
  )


;;----------------------------------------------------------------------------
;; Don't disable narrowing commands
;;----------------------------------------------------------------------------
(put 'narrow-to-region 'disabled nil)
(put 'narrow-to-page 'disabled nil)
(put 'narrow-to-defun 'disabled nil)

;;----------------------------------------------------------------------------
;; Show matching parens
;;----------------------------------------------------------------------------
(add-hook 'after-init-hook 'show-paren-mode)

;;----------------------------------------------------------------------------
;; Expand region
;;----------------------------------------------------------------------------
(use-package expand-region
  :init
  (global-set-key (kbd "C-=") 'er/expand-region)
  )


;;----------------------------------------------------------------------------
;; Don't disable case-change functions
;;----------------------------------------------------------------------------
(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)


;;----------------------------------------------------------------------------
;; Rectangle selections, and overwrite text when the selection is active
;;----------------------------------------------------------------------------
(cua-selection-mode t)                  ; for rectangles, CUA is nice


;;----------------------------------------------------------------------------
;; Handy key bindings
;;----------------------------------------------------------------------------

(global-set-key (kbd "M-g M-m") 'set-mark-command)
(global-set-key (kbd "M-g m") 'pop-global-mark)

(use-package avy
  :bind
  ("M-g c" . 'avy-goto-char-timer)
  )

(use-package multiple-cursors
  :init
  ;; multiple-cursors
  (global-set-key (kbd "C-<") 'mc/mark-previous-like-this)
  (global-set-key (kbd "C->") 'mc/mark-next-like-this)
  (global-set-key (kbd "C-+") 'mc/mark-next-like-this)
  (global-set-key (kbd "C-c C-<") 'mc/mark-all-like-this)
  ;; From active region to multiple cursors:
  (global-set-key (kbd "C-c m r") 'set-rectangular-region-anchor)
  (global-set-key (kbd "C-c m c") 'mc/edit-lines)
  (global-set-key (kbd "C-c m e") 'mc/edit-ends-of-lines)
  (global-set-key (kbd "C-c m a") 'mc/edit-beginnings-of-lines)
  )


;; Train myself to use M-f and M-b instead
(global-unset-key [M-left])
(global-unset-key [M-right])

(defun kill-back-to-indentation ()
  "Kill from point back to the first non-whitespace character on the line."
  (interactive)
  (let ((prev-pos (point)))
    (back-to-indentation)
    (kill-region (point) prev-pos)))

(global-set-key (kbd "C-M-<backspace>") 'kill-back-to-indentation)


;;----------------------------------------------------------------------------
;; Page break lines
;;----------------------------------------------------------------------------
(use-package page-break-lines
  :hook
  (after-init . global-page-break-lines-mode)
  :diminish page-break-lines-mode
  )

;;----------------------------------------------------------------------------
;; Shift lines up and down with M-up and M-down. When paredit is enabled,
;; it will use those keybindings. For this reason, you might prefer to
;; use M-S-up and M-S-down, which will work even in lisp modes.
;;----------------------------------------------------------------------------
(use-package move-dup
  :init
  (global-set-key [M-up] 'md-move-lines-up)
  (global-set-key [M-down] 'md-move-lines-down)
  (global-set-key [M-S-up] 'md-move-lines-up)
  (global-set-key [M-S-down] 'md-move-lines-down)

  (global-set-key (kbd "C-c d") 'md-duplicate-down)
  (global-set-key (kbd "C-c u") 'md-duplicate-up)
  )


;;----------------------------------------------------------------------------
;; Cut/copy the current line if no region is active
;;----------------------------------------------------------------------------
(use-package whole-line-or-region
  :init
  (require 'whole-line-or-region)
  :diminish whole-line-or-region-mode
  )

(defun suspend-mode-during-cua-rect-selection (mode-name)
  "Add an advice to suspend `MODE-NAME' while selecting a CUA rectangle."
  (let ((flagvar (intern (format "%s-was-active-before-cua-rectangle" mode-name)))
        (advice-name (intern (format "suspend-%s" mode-name))))
    (with-eval-after-load 'cua-rect
      `(progn
         (defvar ,flagvar nil)
         (make-variable-buffer-local ',flagvar)
         (defadvice cua--activate-rectangle (after ,advice-name activate)
           (setq ,flagvar (and (boundp ',mode-name) ,mode-name))
           (when ,flagvar
             (,mode-name 0)))
         (defadvice cua--deactivate-rectangle (after ,advice-name activate)
           (when ,flagvar
             (,mode-name 1)))))))

(suspend-mode-during-cua-rect-selection 'whole-line-or-region-mode)




(defun my/open-line-with-reindent (n)
  "A version of `open-line' which reindents the start and end positions.
If there is a fill prefix and/or a `left-margin', insert them
on the new line if the line would have been blank.
With arg N, insert N newlines."
  (interactive "*p")
  (let* ((do-fill-prefix (and fill-prefix (bolp)))
         (do-left-margin (and (bolp) (> (current-left-margin) 0)))
         (loc (point-marker))
         ;; Don't expand an abbrev before point.
         (abbrev-mode nil))
    (delete-horizontal-space t)
    (newline n)
    (indent-according-to-mode)
    (when (eolp)
      (delete-horizontal-space t))
    (goto-char loc)
    (while (> n 0)
      (cond ((bolp)
             (if do-left-margin (indent-to (current-left-margin)))
             (if do-fill-prefix (insert-and-inherit fill-prefix))))
      (forward-line 1)
      (setq n (1- n)))
    (goto-char loc)
    (end-of-line)
    (indent-according-to-mode)))

(global-set-key (kbd "C-o") 'my/open-line-with-reindent)


;;----------------------------------------------------------------------------
;; Random line sorting
;;----------------------------------------------------------------------------
(defun sort-lines-random (beg end)
  "Sort lines in region randomly."
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (let ;; To make `end-of-line' and etc. to ignore fields.
          ((inhibit-field-text-motion t))
        (sort-subr nil 'forward-line 'end-of-line nil nil
                   (lambda (s1 s2) (eq (random 2) 0)))))))




(use-package highlight-escape-sequences
  :hook
  (after-init . hes-mode)
  )



(use-package which-key
  :init
  (require 'which-key)
  :hook
  (after-init . which-key-mode)
  :diminish which-key-mode
  )

(setq-default show-trailing-whitespace t)


;;; Whitespace

(use-package whitespace-cleanup-mode
  :hook (after-init . global-whitespace-cleanup-mode)
  :diminish whitespace-cleanup-mode
  )

(global-set-key [remap just-one-space] 'cycle-spacing)

(use-package diff-hl
  :hook
  (magit-post-refresh . diff-hl-magit-post-refresh)
  (after-init . global-diff-hl-mode)
  :config
  (define-key diff-hl-mode-map
    (kbd "<left-fringe> <mouse-1>")
    'diff-hl-diff-goto-hunk)
  )

(use-package browse-at-remote)

(use-package darcsum)
(use-package vc-darcs)


;; TODO: include this in the vc-darcs ELPA package
(add-to-list 'vc-handled-backends 'DARCS)
(autoload 'vc-darcs-find-file-hook "vc-darcs")
(add-hook 'find-file-hooks 'vc-darcs-find-file-hook)

(setq darcsum-whatsnew-switches "-l")

;; TODO: link commits from vc-log to magit-show-commit
;; TODO: smerge-mode
(use-package git-blamed)
(use-package gitignore-templates)
(use-package gitconfig)
(use-package git-timemachine)
(use-package github-clone)
(use-package magithub)
(use-package magit-gh-pulls)
(use-package git-link)
(use-package browse-at-remote)
(use-package github-review)
(use-package org2issue)
(use-package github-stars)
(use-package git-timemachine)
(use-package orgit)
(use-package yagist)

(use-package bug-reference-github
  :hook
  (prog-mode . bug-reference-prog-mode))

(use-package bug-hunter)
(use-package magit
  :init
  (setq-default magit-diff-refine-hunk t)
  ;; Hint: customize `magit-repository-directories' so that you can use C-u M-F12 to
  ;; quickly open magit on any one of your projects.
  (global-set-key [(meta f12)] 'magit-status)
  (global-set-key (kbd "C-x g") 'magit-status)
  (global-set-key (kbd "C-x M-g") 'magit-dispatch-popup)
  (use-package magit-todos)
  (use-package fullframe)
  :config
  (define-key magit-status-mode-map (kbd "C-M-<up>") 'magit-section-up)
  (fullframe magit-status magit-mode-quit-window)
  ;; (magit-todos-mode)
  )

(use-package git-commit
  :hook
  (git-commit-mode . goto-address-mode)
  )

(use-package webpaste)

(use-package systemd)
(use-package helm-systemd)


(use-package git-messenger)
;; Though see also vc-annotate's "n" & "p" bindings
(with-eval-after-load 'vc
  (setq git-messenger:show-detail t)
  (define-key vc-prefix-map (kbd "p") #'git-messenger:popup-message))

(use-package k8s-mode
  :config
  (setq k8s-search-documentation-browser-function 'browse-url-firefox)
  :hook (k8s-mode . yas-minor-mode))

(use-package kubel)

(use-package kubernetes
  :commands (kubernetes-overview))

(use-package kubernetes-helm)

(use-package tramp
  :ensure nil
  :straight nil
  :init
  (require 'tramp)
  (setq tramp-default-method "ssh")
  ;; Avoid indefinite hang in tramp, https://www.emacswiki.org/emacs/TrampMode#toc9
  (setq tramp-terminal-type "tramp")
  (add-to-list 'tramp-remote-path "~/.nix-profile/bin")
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path))

(use-package projectile
  :bind-keymap
  ("s-p" . projectile-command-map)
  ("C-c C-p" . projectile-command-map)
  :hook
  (after-init . projectile-mode)
  :config
  (setq-default
   projectile-mode-line
   '(:eval
     (if (file-remote-p default-directory)
         " Proj"
       (format " Proj[%s]" (projectile-project-name)))))
  (setq projectile-globally-ignored-files
        (delq nil (delete-dups
                   (append
                    '("*~")
                    projectile-globally-ignored-files))))
  (setq projectile-globally-ignored-file-suffixes
        (delq nil (delete-dups
                   (append
                    '("DS_Store" "cache" "class" "elc" "eld" "jar" ".ccls-cache")
                    projectile-globally-ignored-file-suffixes))))
  )

(use-package helm-projectile
  :after projectile)

(use-package prog-mode
  :ensure nil
  :straight nil
  :hook (prog-mode . my-prog-mode-hook)
  :init
  (defun my-prog-mode-hook ()
    (display-line-numbers-mode 1)))

(use-package clang-format
  :config
  (defun clang-format-this-buffer-gnu ()
    (interactive)
    (format-all-mode -1)
    (setq clang-format-style "gnu")
    (add-hook 'before-save-hook 'clang-format-buffer nil 'local)
    )
  )

(use-package ormolu
  :hook (haskell-mode . ormolu-format-on-save-mode)
  :bind
  (:map haskell-mode-map
        ("C-c r" . ormolu-format-buffer)
        )
  )

(use-package cmm-mode)

;; (use-package nix-haskell-mode
;;   :hook (haskell-mode . nix-haskell-mode)
;;   )

(use-package lsp-haskell
  :init
  (setq   lsp-haskell-process-path-hie "haskell-language-server-wrapper"
          default-nix-wrapper (lambda (args)
                                (let ((sandbox (nix-current-sandbox))
                                      (nix-shell "nix-shell"))
                                  (if (and (executable-find nix-shell)
                                           (file-exists-p sandbox)
                                           (not (file-directory-p sandbox)))
                                      (append
                                       (list nix-shell "-I" "." "--command")
                                       (list (mapconcat 'identity args " "))
                                       (list sandbox)
                                       )
                                    args
                                    )
                                  )
                                )
          lsp-haskell-process-wrapper-function default-nix-wrapper
          haskell-enable-hindent t
          haskell-enable-hlint t
          haskell-completion-backend 'lsp
          haskell-process-type 'cabal-new-repl
          )
  )

(use-package lsp-pyright
  :hook (python-mode . (lambda ()
                         (require 'lsp-pyright)
                         (lsp))))
(use-package lsp-python-ms)
(use-package lsp-metals)
(use-package lsp-java)
(use-package caml)
(use-package flycheck-ocaml)
(use-package tuareg)
(use-package dune)

(use-package merlin
  :init
  (setq merlin-use-auto-complete-mode t)
  (setq merlin-error-after-save nil)
  (let ((opam-share (ignore-errors (car (process-lines "opam" "config" "var" "share")))))
    (when (and opam-share (file-directory-p opam-share))
      (add-to-list 'load-path (expand-file-name "emacs/site-lisp" opam-share))
      (autoload 'merlin-mode "merlin" nil t nil)
      (add-hook 'tuareg-mode-hook 'merlin-mode t)
      (add-hook 'caml-mode-hook 'merlin-mode t)
      (autoload 'utop-setup-ocaml-buffer "utop" "Toplevel for OCaml" t)
      (add-hook 'tuareg-mode-hook 'utop-setup-ocaml-buffer)))
  )
(use-package merlin-eldoc)

(use-package flycheck-rust
  :after flycheck
  :init
  (add-hook 'flycheck-mode-hook #'flycheck-rust-setup)
  )

(use-package rust-mode)

(use-package go-dlv
  :after go-mode
  )

(use-package sbt-mode
  :commands sbt-start sbt-command
  :config
  ;; WORKAROUND: https://github.com/ensime/emacs-sbt-mode/issues/31
  ;; allows using SPACE when in the minibuffer
  (substitute-key-definition
   'minibuffer-complete-word
   'self-insert-command
   minibuffer-local-completion-map))

(use-package elixir-mode)

(use-package scala-mode)

(use-package cuda-mode)

(use-package dhall-mode
  :config
  (setq
   ;; uncomment the next line to disable automatic format
   ;; dhall-format-at-save nil

   ;; comment the next line to use unicode syntax
   dhall-format-arguments (\` ("--ascii"))

   ;; header-line is obsoleted by lsp-mode
   dhall-use-header-line nil))

(use-package csharp-mode)

(use-package lsp-mode
  :commands lsp
  :hook
  ;; (prog-major-mode . lsp)
  (c-mode . lsp)
  (cuda-mode . lsp)
  (c++-mode . lsp)
  (csharp-mode . lsp)
  (objc-mode . lsp)
  (dhall-mode . lsp)
  (nix-mode . lsp)
  (haskell-mode . lsp)
  (elixir-mode . lsp)
  (typescript-mode . lsp)
  (rust-mode . lsp)
  (scala-mode . lsp)
  (go-mode . lsp)
  (sh-mode . lsp)
  (python-mode . lsp)
  (ruby-mode . lsp)
  (java-mode . lsp)
  ;; https://github.com/flycheck/flycheck/issues/1762
  ;; seem to be not working.
  (lsp-managed-mode . (lambda ()
                        (when (derived-mode-p 'sh-mode)
                          (setq my/flycheck-local-cache '((lsp . ((next-checkers . (sh-shellcheck)))))))))
  :init
  (when (executable-find "python-language-server")
    (setq lsp-python-ms-executable "python-language-server")
    (require 'lsp-python-ms))
  ;; It seems full path to omnisharp is required
  (let ((omnisharp-bin (executable-find "omnisharp")))
    (when omnisharp-bin
      (setq lsp-csharp-server-path omnisharp-bin)))
  (setq lsp-csharp-server-path "omnisharp")
  :config
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-tramp-connection "rust-analyzer")
                    :major-modes '(rust-mode)
                    :remote? t
                    :server-id 'rust-analyzer-remote))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-tramp-connection "gopls")
                    :major-modes '(go-mode)
                    :remote? t
                    :server-id 'gopls-remote))
  :custom
  (lsp-ui-doc-enable t)
  (lsp-clients-clangd-args '("-log=verbose"))
  (lsp-rust-racer-completion nil)
  (lsp-rust-server 'rust-analyzer)
  (lsp-prefer-flymake nil)
  (lsp-auto-guess-root t)
  (lsp-idle-delay 0.500)
  (lsp-keep-workspace-alive nil)
  (lsp-enable-on-type-formatting t)
  (lsp-enable-file-watchers nil)
  (lsp-file-watch-threshold 3000))

(use-package lsp-ui :commands lsp-ui-mode)
(use-package lsp-origami)
;; (use-package company-lsp :commands company-lsp)
(use-package helm-lsp :commands helm-lsp-workspace-symbol)
(use-package lsp-treemacs :commands lsp-treemacs-errors-list)

(use-package dap-mode
  :config
  (dap-ui-mode t)
  (require 'dap-gdb-lldb)
  (require 'dap-java)
  (dap-gdb-lldb-setup)
  )

(use-package crux)

(use-package dumb-jump
  :bind (("M-g o" . dumb-jump-go-other-window)
         ("M-g j" . dumb-jump-go)
         ("M-g b" . dumb-jump-back)
         ("M-g i" . dumb-jump-go-prompt)
         ("M-g x" . dumb-jump-go-prefer-external)
         ("M-g z" . dumb-jump-go-prefer-external-other-window))
  :config
  (setq dumb-jump-selector 'ivy)
  )

(setq-default compilation-scroll-output t)

(use-package alert)

;; Customize `alert-default-style' to get messages after compilation

(defun my/alert-after-compilation-finish (buf result)
  "Use `alert' to report compilation RESULT if BUF is hidden."
  (when (buffer-live-p buf)
    (unless (catch 'is-visible
              (walk-windows (lambda (w)
                              (when (eq (window-buffer w) buf)
                                (throw 'is-visible t))))
              nil)
      (alert (concat "Compilation " result)
             :buffer buf
             :category 'compilation))))

(with-eval-after-load 'compile
  (add-hook 'compilation-finish-functions
            'my/alert-after-compilation-finish))

(defvar my/last-compilation-buffer nil
  "The last buffer in which compilation took place.")

(with-eval-after-load 'compile
  (defadvice compilation-start (after my/save-compilation-buffer activate)
    "Save the compilation buffer to find it later."
    (setq my/last-compilation-buffer next-error-last-buffer))

  (defadvice recompile (around my/find-prev-compilation (&optional edit-command) activate)
    "Find the previous compilation buffer, if present, and recompile there."
    (if (and (null edit-command)
             (not (derived-mode-p 'compilation-mode))
             my/last-compilation-buffer
             (buffer-live-p (get-buffer my/last-compilation-buffer)))
        (with-current-buffer my/last-compilation-buffer
          ad-do-it)
      ad-do-it)))

(global-set-key [f6] 'recompile)

(defadvice shell-command-on-region
    (after my/shell-command-in-view-mode
           (start end command &optional output-buffer replace &rest other-args)
           activate)
  "Put \"*Shell Command Output*\" buffers into view-mode."
  (unless (or output-buffer replace)
    (with-current-buffer "*Shell Command Output*"
      (view-mode 1))))


(with-eval-after-load 'compile
  (require 'ansi-color)
  (defun my/colourise-compilation-buffer ()
    (when (eq major-mode 'compilation-mode)
      (ansi-color-apply-on-region compilation-filter-start (point-max))))
  (add-hook 'compilation-filter-hook 'my/colourise-compilation-buffer))


(use-package cmd-to-echo)

(use-package textile-mode
  :mode "\\.textile\\'"
  )

(use-package markdown-mode
  :mode "\\.md\\.html\\'"
  :init
  (use-package whitespace-cleanup-mode
    :config
    (push 'markdown-mode whitespace-cleanup-mode-ignore-modes))
  )

(use-package adoc-mode
  :mode
  "\\.adoc\\'" "\\.asciidoc\\'"
  )

(use-package csv-mode
  :mode "\\.[Cc][Ss][Vv]\\'"
  :custom
  (csv-separators '("," ";" "|" " ")))

(use-package erlang)

(use-package json-mode)
(use-package js2-mode)
(use-package coffee-mode)
(use-package typescript-mode)
(use-package prettier-js)



;; ---------------------------------------------------------------------------
;; Run and interact with an inferior JS via js-comint.el
;; ---------------------------------------------------------------------------

(use-package js-comint
  :init
  (setq inferior-js-program-command "node")

  (defvar inferior-js-minor-mode-map (make-sparse-keymap))
  (define-key inferior-js-minor-mode-map "\C-x\C-e" 'js-send-last-sexp)
  (define-key inferior-js-minor-mode-map "\C-\M-x" 'js-send-last-sexp-and-go)
  (define-key inferior-js-minor-mode-map "\C-cb" 'js-send-buffer)
  (define-key inferior-js-minor-mode-map "\C-c\C-b" 'js-send-buffer-and-go)
  (define-key inferior-js-minor-mode-map "\C-cl" 'js-load-file-and-go)

  (define-minor-mode inferior-js-keys-mode
    "Bindings for communicating with an inferior js interpreter."
    :init-value nil :lighter " InfJS" :keymap inferior-js-minor-mode-map)

  (dolist (hook '(js2-mode-hook js-mode-hook))
    (add-hook hook 'inferior-js-keys-mode))
  )

;; ---------------------------------------------------------------------------
;; Alternatively, use skewer-mode
;; ---------------------------------------------------------------------------

(use-package skewer-mode
  :hook
  (skewer-mode . (lambda () (inferior-js-keys-mode -1)))
  )

(use-package add-node-modules-path
  :init
  (with-eval-after-load 'typescript-mode
    (add-hook 'typescript-mode-hook 'add-node-modules-path))
  (with-eval-after-load 'js2-mode
    (add-hook 'js2-mode-hook 'add-node-modules-path))
  )

(use-package php-mode
  :init
  (use-package smarty-mode)

  (use-package company-php
    :after company
    :hook
    (php-mode . (lambda () (local-push-company-backend 'company-ac-php-backend)))
    )
  )



(use-package habitica)

(use-package taskwarrior
  :straight (taskwarrior :type git :host github :repo "winpat/taskwarrior.el"))

(use-package el-patch
  :straight (papis :type git :host github :repo "papis/papis.el")
  :init
  (require 'papis))

(use-package helm-bibtex)

(use-package ivy-bibtex)



(require 'org-protocol)

(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode)
  )

(use-package org-cliplink)

(use-package org-msg)

(use-package ox-clip)

;; Various preferences
(setq org-log-done t
      org-edit-timestamp-down-means-later t
      org-hide-emphasis-markers t
      org-catch-invisible-edits 'show
      org-export-coding-system 'utf-8
      org-fast-tag-selection-single-key 'expert
      org-html-validation-link nil
      org-export-kill-product-buffer-when-displayed t
      org-startup-with-inline-images t
      org-tags-column 80
      org-startup-truncated nil
      org-highlight-latex-and-related '(latex))

;; (setq org-latex-to-pdf-process '("xelatex -interaction nonstopmode %f"
;; "xelatex -interaction nonstopmode %f"))
(setq org-latex-pdf-process
      '("lualatex -interaction nonstopmode -output-directory %o %f"
        "bibtex %b"
        "lualatex -interaction nonstopmode -output-directory %o %f"
        "lualatex -interaction nonstopmode -output-directory %o %f"))

(setq org-directory (expand-file-name "~/Sync/docs/org-mode"))

(defvar my/org-gtd-directory
  (expand-file-name "gtd" org-directory)
  "Where all the org gtd files are saved.")

(defvar my/org-capture-directory
  (expand-file-name "~/Sync/docs/org-mode/capture")
  "Where all the org mode capture files are saved.")

(defvar my/org-capture-quick-notes-directory
  (expand-file-name "quick" my/org-capture-directory)
  "Where all the org mode capture files are saved.")

(setq org-agenda-include-all-todo nil)
(setq org-agenda-skip-scheduled-if-done t)
(setq org-agenda-skip-deadline-if-done t)
;; (setq org-agenda-include-diary t)
(setq org-agenda-columns-add-appointments-to-effort-sum t)
(setq org-agenda-custom-commands nil)
(setq org-agenda-default-appointment-duration 60)
(setq org-agenda-mouse-1-follows-link t)
(setq org-agenda-skip-unavailable-files t)
(setq org-agenda-use-time-grid nil)
(setq org-agenda-files
      (expand-file-name "superset.org" my/org-gtd-directory))
(setq org-icalendar-use-scheduled '(event-if-todo todo-start))
(setq org-icalendar-use-scheduled '(even-if-not-todo event-if-todo todo-due))

(use-package doct
  :commands (doct))

(use-package deft
  :init
  (setq deft-directory "~/Sync/docs/deft")
  (setq deft-extensions '("org"))
  (setq deft-default-extension "org")
  (setq deft-text-mode 'org-mode)
  (setq deft-use-filename-as-title t)
  (setq deft-use-filter-string-for-filename t)
  (setq deft-auto-save-interval 0)
  )

(use-package org-sidebar)

(defun my/generate-org-quick-note-name ()
  "Generate hakyll file name."
  (setq my-org-note--title (read-string "Title: "))
  (setq my-org-note--title-slugified (my/slugify my-org-note--title))
  (setq my-org-note--date (format-time-string "%Y-%m-%d"))
  ;; rfc 5322 style time format, shell command: date -R
  (setq my-org-note--time (let ((system-time-locale "en_US.UTF-8"))
                            (format-time-string "%a, %d %b %Y %H:%M:%S %z")
                            ))
  (expand-file-name (format "%s-%s.org" my-org-note--date my-org-note--title-slugified) my/org-capture-quick-notes-directory))

(defun org-capture-template-goto-link ()
  "Set point for capturing at what capture target file+headline with headline set to %l would do."
  (org-capture-put :target (list 'file+headline (nth 1 (org-capture-get :target)) (org-capture-get :annotation)))
  (org-capture-put-target-region-and-position)
  (widen)
  (let ((hd (nth 2 (org-capture-get :target))))
    (goto-char (point-min))
    (if (re-search-forward
         (format org-complex-heading-regexp-format (regexp-quote hd))
         nil t)
        (goto-char (point-at-bol))
      (goto-char (point-max))
      (or (bolp) (insert "\n"))
      (insert "* " hd "\n")
      (beginning-of-line 0))))

(setq org-capture-templates
      (doct
       `(("bookmarks"
          :keys "b"
          :file ,(expand-file-name "bookmarks.org" my/org-capture-directory)
          :headline "Bookmark inbox"
          :template ("* %:description"
                     "   CREATED: %U"
                     "   [[%:link][%:description]]"
                     "   %:initial")
          :immediate-finish 1
          :empty-lines 1)
         ("quick"
          :keys "q"
          :type plain
          :file my/generate-org-quick-note-name
          :template ("%(format \"#+TITLE: %s\" my-org-note--title)"
                     "%(format \"#+DATE: %s\" my-org-note--time)"
                     "%(format \"#+SLUG: %s\" my-org-note--title-slugified)"
                     ""
                     "%?"))
         ("todo"
          :keys "t"
          :file ,(expand-file-name "todo.org" my/org-capture-directory)
          :headline "Future tasks"
          :template ("* TODO %:description"
                     "   CREATED: %U"
                     "   REFERENCE: [[%:link][%:description]]"
                     "   %?%:initial")
          :empty-lines 1
          :prepend t
          :kill-buffer 1)
         ("wiki capture"
          :keys "w"
          :file ,(expand-file-name "wiki.org"  my/org-capture-directory)
          :headline "Captured personal wiki items"
          :template ("* %:description"
                     "   CREATED: %U"
                     "   [[%:link][%:description]]"
                     "   %:initial")
          :empty-lines 1
          :prepend t
          :kill-buffer 1)
         ("capture"
          :keys "c"
          :file ,(expand-file-name "capture.org" my/org-capture-directory)
          :headline "captured"
          :template ("* %:description"
                     "CREATED: %U"
                     "REFERENCE: [[%:link][%:description]]"
                     "%?%:initial")
          :empty-lines 1
          :prepend t
          :kill-buffer 1)
         ("ideas"
          :keys "i"
          :file ,(expand-file-name "ideas.org" my/org-capture-directory)
          :headline "ideas"
          :template ("* %?%:description"
                     "   CREATED: %U"
                     "   TAGS: "
                     "   SOURCE: [[%:link][%:description]]"
                     "   BODY: %:initial")
          :empty-lines 1
          :prepend t
          :kill-buffer 1)
         ("journal"
          :keys "j"
          :file ,(expand-file-name "journal.org" my/org-capture-directory)
          :datetree t
          :template ("* %?%:description"
                     "Entered on %U"
                     "  %:initial"
                     "  %a")
          :kill-buffer 1)
         ("got stuck"
          :keys "s"
          :file ,(expand-file-name "stuck.org" my/org-capture-directory)
          :datetree t
          :template ("* %?%:description"
                     "Entered on %U"
                     "  %:initial"
                     "  %a")
          :kill-buffer 1)
         ("disposable"
          :keys "d"
          :file ,(expand-file-name "disposable.org" my/org-capture-directory)
          :datetree t
          :template ("* %?%:description"
                     "Entered on %U"
                     "  %:initial"
                     "  %a")
          :kill-buffer 1)
         ("unfiled"
          :keys "u"
          :file ,(expand-file-name "unfiled.org" my/org-capture-directory)
          :datetree t
          :template ("* %?%:description"
                     "Entered on %U"
                     "  %:initial"
                     "  %a"))
         ("vocabulary builder"
          :keys "v"
          :file ,(expand-file-name "vocabulary.org" my/org-capture-directory)
          :type checkitem
          :template ("[ ] %:description"
                     "%:initial")
          :children (("English"
                      :keys "e"
                      :headline "English")
                     ("French"
                      :keys "f"
                      :headline "French")
                     ("German"
                      :keys "g"
                      :headline "German"))
          :immediate-finish 1)
         ("cameo collector"
          :keys "m"
          :file ,(expand-file-name "cameo.org" my/org-capture-directory)
          :template ("* %:description"
                     " %:initial")
          :children (("English"
                      :keys "e"
                      :headline "English")
                     ("French"
                      :keys "f"
                      :headline "French")
                     ("German"
                      :keys "g"
                      :headline "German"))
          :immediate-finish 1
          :empty-lines 1)
         ("reading"
          :keys "r"
          :file ,(expand-file-name "reading.org" my/org-capture-directory)
          :function (lambda() (org-capture-template-goto-link))
          :template ("* P%:initial %? %U "
                     "%x")
          :kill-buffer 1)
         ("test"
          :keys "z"
          :file "/tmp/1.org"
          :function org-capture-template-goto-link
          :template ("* P%:initial %? %U "
                     "%x")))))

(defadvice org-capture-finalize
    (after delete-capture-frame activate)
  "Advise capture-finalize to close the frame"
  (if (equal "capture" (frame-parameter nil 'name))
      (delete-frame)))

(defadvice org-capture-destroy
    (after delete-capture-frame activate)
  "Advise capture-destroy to close the frame"
  (if (equal "capture" (frame-parameter nil 'name))
      (delete-frame)))

(defun make-capture-frame ()
  "Create a new frame and run org-capture."
  (interactive)
  (make-frame '((name . "capture")))
  (select-frame-by-name "capture")
  (delete-other-windows)
  (noflet ((switch-to-buffer-other-window (buf) (switch-to-buffer buf)))
          (org-capture)))

(defvar my-org-capture-before-config nil
  "Window configuration before `org-capture'.")

(defadvice org-capture (before save-config activate)
  "Save the window configuration before `org-capture'."
  (setq my-org-capture-before-config (current-window-configuration)))

(add-hook 'org-capture-mode-hook 'delete-other-windows)

(defun my/org-capture-cleanup ()
  "Clean up the frame created while capturing via org-protocol."
  ;; In case we run capture from emacs itself and not an external app,
  ;; we want to restore the old window config
  (when my-org-capture-before-config
    (set-window-configuration my-org-capture-before-config))
  (-when-let ((&alist 'name name) (frame-parameters))
    (when (equal name "org-protocol-capture")
      (delete-frame)))
  (if (plist-get org-capture-plist :kill-buffer)
      (save-buffers-kill-terminal)))

(add-hook 'org-capture-after-finalize-hook 'my/org-capture-cleanup)

;; use ivy to insert a link to a heading in the current document
;; based on `worf-goto`
(defun bjm/worf-insert-internal-link ()
  "Use ivy to insert a link to a heading in the current `org-mode' document. Code is based on `worf-goto'."
  (interactive)
  (let ((cands (worf--goto-candidates)))
    (ivy-read "Heading: " cands
              :action 'bjm/worf-insert-internal-link-action)))

(defun bjm/worf-insert-internal-link-action (x)
  "Insert link for `bjm/worf-insert-internal-link'"
  ;; go to heading
  (save-excursion
    (goto-char (cdr x))
    ;; store link
    (call-interactively 'org-store-link)
    )
  ;; return to original point and insert link
  (org-insert-last-stored-link 1)
  ;; org-insert-last-stored-link adds a newline so delete this
  (delete-backward-char 1)
  )


;; Lots of stuff from http://doc.norang.ca/org-mode.html

;; TODO: fail gracefully
(defun my/grab-ditaa (url jar-name)
  "Download URL and extract JAR-NAME as `org-ditaa-jar-path'."
  ;; TODO: handle errors
  (message "Grabbing %s for org." jar-name)
  (let ((zip-temp (make-temp-name "emacs-ditaa")))
    (unwind-protect
        (progn
          (when (executable-find "unzip")
            (url-copy-file url zip-temp)
            (shell-command (concat "unzip -p " (shell-quote-argument zip-temp)
                                   " " (shell-quote-argument jar-name) " > "
                                   (shell-quote-argument org-ditaa-jar-path)))))
      (when (file-exists-p zip-temp)
        (delete-file zip-temp)))))

(with-eval-after-load 'ob-ditaa
  (unless (and (boundp 'org-ditaa-jar-path)
               (file-exists-p org-ditaa-jar-path))
    (let ((jar-name "ditaa0_9.jar")
          (url "http://jaist.dl.sourceforge.net/project/ditaa/ditaa/0.9/ditaa0_9.zip"))
      (setq org-ditaa-jar-path (expand-file-name jar-name (file-name-directory user-init-file)))
      (unless (file-exists-p org-ditaa-jar-path)
        (my/grab-ditaa url jar-name)))))

(with-eval-after-load 'ob-plantuml
  (let ((jar-name "plantuml.jar")
        (url "http://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar"))
    (setq org-plantuml-jar-path (expand-file-name jar-name (file-name-directory user-init-file)))
    (unless (file-exists-p org-plantuml-jar-path)
      (url-copy-file url org-plantuml-jar-path))))


;; Re-align tags when window shape changes
(with-eval-after-load 'org-agenda
  (add-hook 'org-agenda-mode-hook
            (lambda () (add-hook 'window-configuration-change-hook 'org-agenda-align-tags nil t))))




(use-package writeroom-mode)

(define-minor-mode prose-mode
  "Set up a buffer for prose editing.
  This enables or modifies a number of settings so that the
  experience of editing prose is a little more like that of a
  typical word processor."
  :init-value nil
  :lighter " Prose"
  :keymap nil
  (if prose-mode
      (progn
        (when (fboundp 'writeroom-mode)
          (writeroom-mode 1))
        (setq truncate-lines nil)
        (setq word-wrap t)
        (setq cursor-type 'bar)
        (when (eq major-mode 'org)
          (kill-local-variable 'buffer-face-mode-face))
        (buffer-face-mode 1)
        ;;(delete-selection-mode 1)
        (set (make-local-variable 'blink-cursor-interval) 0.6)
        (set (make-local-variable 'show-trailing-whitespace) nil)
        (set (make-local-variable 'line-spacing) 0.2)
        (set (make-local-variable 'electric-pair-mode) nil)
        (ignore-errors (flyspell-mode 1))
        (visual-line-mode 1))
    (kill-local-variable 'truncate-lines)
    (kill-local-variable 'word-wrap)
    (kill-local-variable 'cursor-type)
    (kill-local-variable 'blink-cursor-interval)
    (kill-local-variable 'show-trailing-whitespace)
    (kill-local-variable 'line-spacing)
    (kill-local-variable 'electric-pair-mode)
    (buffer-face-mode -1)
    ;; (delete-selection-mode -1)
    (flyspell-mode -1)
    (visual-line-mode -1)
    (when (fboundp 'writeroom-mode)
      (writeroom-mode 0))))

;;(add-hook 'org-mode-hook 'buffer-face-mode)


(setq org-support-shift-select t)


;;; Refiling

(setq org-refile-use-cache nil)

;; Targets include this file and any file contributing to the agenda - up to 5 levels deep
(setq org-refile-targets '((nil :maxlevel . 5) (org-agenda-files :maxlevel . 5)))

(with-eval-after-load 'org-agenda
  (add-to-list 'org-agenda-after-show-hook 'org-show-entry))

(defadvice org-refile (after my/save-all-after-refile activate)
  "Save all org buffers after each refile operation."
  (org-save-all-org-buffers))

;; Exclude DONE state tasks from refile targets
(defun my/verify-refile-target ()
  "Exclude todo keywords with a done state from refile targets."
  (not (member (nth 2 (org-heading-components)) org-done-keywords)))
(setq org-refile-target-verify-function 'my/verify-refile-target)

(defun my/org-refile-anywhere (&optional goto default-buffer rfloc msg)
  "A version of `org-refile' which allows refiling to any subtree."
  (interactive "P")
  (let ((org-refile-target-verify-function))
    (org-refile goto default-buffer rfloc msg)))

(defun my/org-agenda-refile-anywhere (&optional goto rfloc no-update)
  "A version of `org-agenda-refile' which allows refiling to any subtree."
  (interactive "P")
  (let ((org-refile-target-verify-function))
    (org-agenda-refile goto rfloc no-update)))

;; Targets start with the file name - allows creating level 1 tasks
;;(setq org-refile-use-outline-path (quote file))
(setq org-refile-use-outline-path t)
(setq org-outline-path-complete-in-steps nil)

;; Allow refile to create parent tasks with confirmation
(setq org-refile-allow-creating-parent-nodes 'confirm)


;;; To-do settings

(setq org-todo-keywords
      (quote ((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d!/!)")
              (sequence "PROJECT(p)" "|" "DONE(d!/!)" "CANCELLED(c@/!)")
              (sequence "WAITING(w@/!)" "DELEGATED(e!)" "HOLD(h)" "|" "CANCELLED(c@/!)")))
      org-todo-repeat-to-state "NEXT")

(setq org-todo-keyword-faces
      (quote (("NEXT" :inherit warning)
              ("PROJECT" :inherit font-lock-string-face))))



;;; Agenda views

(setq-default org-agenda-clockreport-parameter-plist '(:link t :maxlevel 3))

(let ((active-project-match "-INBOX/PROJECT"))

  (setq org-stuck-projects
        `(,active-project-match ("NEXT")))

  (setq org-agenda-compact-blocks t
        org-agenda-sticky t
        org-agenda-start-on-weekday nil
        org-agenda-span 'day
        org-agenda-include-diary nil
        org-agenda-sorting-strategy
        '((agenda habit-down time-up user-defined-up effort-up category-keep)
          (todo category-up effort-up)
          (tags category-up effort-up)
          (search category-up))
        org-agenda-window-setup 'current-window
        org-agenda-custom-commands
        `(("N" "Notes" tags "NOTE"
           ((org-agenda-overriding-header "Notes")
            (org-tags-match-list-sublevels t)))
          ("g" "GTD"
           ((agenda "" nil)
            (tags "INBOX"
                  ((org-agenda-overriding-header "Inbox")
                   (org-tags-match-list-sublevels nil)))
            (stuck ""
                   ((org-agenda-overriding-header "Stuck Projects")
                    (org-agenda-tags-todo-honor-ignore-options t)
                    (org-tags-match-list-sublevels t)
                    (org-agenda-todo-ignore-scheduled 'future)))
            (tags-todo "-INBOX"
                       ((org-agenda-overriding-header "Next Actions")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("HOLD" "WAITING"))
                                (org-agenda-skip-entry-if 'nottodo '("NEXT")))))
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(todo-state-down effort-up category-keep))))
            (tags-todo ,active-project-match
                       ((org-agenda-overriding-header "Projects")
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "-INBOX/-NEXT"
                       ((org-agenda-overriding-header "Orphaned Tasks")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("PROJECT" "HOLD" "WAITING" "DELEGATED"))
                                (org-agenda-skip-subtree-if 'nottododo '("TODO")))))
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "/WAITING"
                       ((org-agenda-overriding-header "Waiting")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "/DELEGATED"
                       ((org-agenda-overriding-header "Delegated")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "-INBOX"
                       ((org-agenda-overriding-header "On Hold")
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("WAITING"))
                                (org-agenda-skip-entry-if 'nottodo '("HOLD")))))
                        (org-tags-match-list-sublevels nil)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            ;; (tags-todo "-NEXT"
            ;;            ((org-agenda-overriding-header "All other TODOs")
            ;;             (org-match-list-sublevels t)))
            )))))


(add-hook 'org-agenda-mode-hook 'hl-line-mode)


;;; Org clock

;; Save the running clock and all clock history when exiting Emacs, load it on startup
(with-eval-after-load 'org
  (org-clock-persistence-insinuate))
(setq org-clock-persist t)
(setq org-clock-in-resume t)

;; Save clock data and notes in the LOGBOOK drawer
(setq org-clock-into-drawer t)
;; Save state changes in the LOGBOOK drawer
(setq org-log-into-drawer t)
;; Removes clocked tasks with 0:00 duration
(setq org-clock-out-remove-zero-time-clocks t)

;; Show clock sums as hours and minutes, not "n days" etc.
(setq org-time-clocksum-format
      '(:hours "%d" :require-hours t :minutes ":%02d" :require-minutes t))



;;; Show the clocked-in task - if any - in the header line
(defun my/show-org-clock-in-header-line ()
  (setq-default header-line-format '((" " org-mode-line-string " "))))

(defun my/hide-org-clock-from-header-line ()
  (setq-default header-line-format nil))

(add-hook 'org-clock-in-hook 'my/show-org-clock-in-header-line)
(add-hook 'org-clock-out-hook 'my/hide-org-clock-from-header-line)
(add-hook 'org-clock-cancel-hook 'my/hide-org-clock-from-header-line)

(with-eval-after-load 'org-clock
  (define-key org-clock-mode-line-map [header-line mouse-2] 'org-clock-goto)
  (define-key org-clock-mode-line-map [header-line mouse-1] 'org-clock-menu))


;;; Archiving

(setq org-archive-mark-done nil)
(setq org-archive-location (expand-file-name "archive/%s_archive::" org-directory))


(use-package org
  :ensure nil
  :straight nil
  :hook
  (org-mode . org-indent-mode))

(use-package org-pomodoro
  :custom (org-pomodoro-keep-killed-pomodoro-time t)
  :init
  (with-eval-after-load 'org-agenda
    (define-key org-agenda-mode-map (kbd "P") 'org-pomodoro))
  )

(use-package org-download
  :init (require 'org-download))

(define-key global-map (kbd "s-r l") 'org-store-link)

(use-package org-roam
  :init
  (require 'org-roam-protocol)
  (setq org-roam-v2-ack t)
  :hook
  (after-init . org-roam-db-autosync-mode)
  :config
  (setq-default org-download-image-dir (expand-file-name "assets/images" org-roam-directory))
  (setq-default org-download-heading-lvl nil)
  :custom
  (org-roam-directory (expand-file-name "roam/org" org-directory))
  :bind (("s-r r" . org-roam-node-find)
         ("s-r c" . org-roam-capture)
         ("s-r b" . org-roam-buffer-toggle)
         ("s-r g" . org-roam-graph)
         ("s-r t" . org-roam-tag-add)
         ("s-r i" . org-roam-insert)
         ("s-r I" . org-roam-insert-immediate)))

(use-package org-roam-server)

(use-package nroam
  :straight '(nroam
              :host github
              :branch "master"
              :repo "NicolasPetton/nroam")
  :after org-roam
  :config
  (add-hook 'org-mode-hook #'nroam-setup-maybe))

(use-package org-marginalia
  :straight '(org-marginalia
              :host github
              :repo "nobiot/org-marginalia"))

(use-package org-similarity
  :straight '(org-similarity
              :type git
              :host github
              :repo "brunoarine/org-similarity"))

(use-package org-rich-yank
  :bind (:map org-mode-map
              ("C-M-y" . org-rich-yank)))

(use-package org-superstar
  :init
  (setq org-superstar-leading-bullet " ")
  :hook
  (org-mode . org-superstar-mode))

(use-package org-caldav
  :init
  (setq org-icalendar-timezone "Asia/Shanghai")
  (setq org-export-with-todo-keywords t)
  (setq org-icalendar-combined-agenda-file (expand-file-name "export.ics" my/org-gtd-directory))
  (setq org-caldav-url "https://framagenda.org/remote.php/dav/calendars/v/")
  (setq org-caldav-calendars
        `((:calendar-id "org-mode" :files (,(expand-file-name "superset.org" my/org-gtd-directory))
                        :skip-conditions (regexp "TEMP")
                        :inbox ,(expand-file-name "davinbox.org" my/org-gtd-directory))))
  ;; (run-with-idle-timer 900 100 'org-caldav-sync-quiet)
  (defun org-caldav-sync-quiet ()
    "Sync Org with calendar."
    (interactive)
    (org-caldav-debug-print 1 "========== Started sync.")
    (if (and org-caldav-event-list
             (not (eq org-caldav-resume-aborted 'never))
             (or (eq org-caldav-resume-aborted 'always)
                 (and (eq org-caldav-resume-aborted 'ask))
                 (y-or-n-p "Last sync seems to have been aborted. \
  Should I try to resume? ")))
        (org-caldav-sync-calendar org-caldav-previous-calendar t)
      (setq org-caldav-sync-result nil)
      (if (null org-caldav-calendars)
          (org-caldav-sync-calendar)
        (dolist (calendar org-caldav-calendars)
          (org-caldav-debug-print 1 "Syncing first calendar entry:" calendar)
          (org-caldav-sync-calendar calendar))))
    (message "Finished org-caldav-sync.")))

(use-package org-ref
  :init
  (require 'org-ref)
  (setq reftex-default-bibliography '("~/Sync/docs/bib/references.bib"))

  ;; see org-ref for use of these variables
  (setq org-ref-bibliography-notes "~/Sync/docs/bib/notes.org"
        org-ref-default-bibliography '("~/Sync/docs/bib/references.bib")
        org-ref-pdf-directory "~/Sync/docs/bib/docs/")

  (setq bibtex-completion-bibliography "~/Sync/docs/bib/references.bib"
        bibtex-completion-library-path "~/Sync/docs/bib/docs"
        bibtex-completion-notes-path "~/Sync/docs/bib/notes")
  (setq bibtex-completion-pdf-open-function 'org-open-file)
  )

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-M-<up>") 'org-up-element)
  )

(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   `((R . t)
     ;; (ditaa . t)
     (dot . t)
     (emacs-lisp . t)
     (gnuplot . t)
     (haskell . nil)
     (latex . t)
     ;; (ledger . t)
     (ocaml . nil)
     (octave . t)
     ;; (plantuml . t)
     (python . t)
     (ruby . t)
     (screen . nil)
     (,(if (locate-library "ob-sh") 'sh 'shell) . t)
     (sql . nil)
     (sqlite . t))))


(defun my/simplenote-setup ()
  "Setup simplenote credentials."
  (interactive)
  (setq simplenote2-email (my/secrets "simplenote" "username"))
  (setq simplenote2-password (my/secrets "simplenote" "password"))
  )

(use-package simplenote2
  :commands simplenote2-list simplenote2-browse simplenote2-create-note-from-buffer
  ;; :init
  ;; (require 'simplenote2)
  ;; (simplenote2-setup)
  :config
  (my/simplenote-setup)
  )

(use-package nxml-mode
  :ensure nil
  :straight nil
  :mode
  "\\.xml\\'" "\\.xsd\\'" "\\.sch\\'" "\\.rng\\'" "\\.xslt\\'"
  "\\.svg\\'" "\\.rss\\'" "\\.gpx\\'" "\\.tcx\\'" "\\.plist\\'"
  :magic "<\\?xml ")

(fset 'xml-mode 'nxml-mode)
(setq nxml-slash-auto-complete-flag t)

(use-package my/html
  :ensure nil
  :straight nil
  :mode ("\\.\\(jsp\\|tmpl\\)\\'". html-mode))

(use-package tagedit)
(with-eval-after-load 'sgml-mode
  (tagedit-add-paredit-like-keybindings)
  (define-key tagedit-mode-map (kbd "M-?") nil)
  (add-hook 'sgml-mode-hook (lambda () (tagedit-mode 1))))

;;; Colourise CSS colour literals
(use-package rainbow-mode
  :hook
  ((css-mode html-mode sass-mode) . rainbow-mode))


;;; Embedding in html
(with-eval-after-load 'mmm-vars
  (mmm-add-group
   'html-css
   '((css-cdata
      :submode css-mode
      :face mmm-code-submode-face
      :front "<style[^>]*>[ \t\n]*\\(//\\)?<!\\[CDATA\\[[ \t]*\n?"
      :back "[ \t]*\\(//\\)?]]>[ \t\n]*</style>"
      :insert ((?c css-tag nil @ "<style type=\"text/css\">"
                   @ "\n" _ "\n" @ "</style>" @)))
     (css
      :submode css-mode
      :face mmm-code-submode-face
      :front "<style[^>]*>[ \t]*\n?"
      :back "[ \t]*</style>"
      :insert ((?c css-tag nil @ "<style type=\"text/css\">"
                   @ "\n" _ "\n" @ "</style>" @)))
     (css-inline
      :submode css-mode
      :face mmm-code-submode-face
      :front "style=\""
      :back "\"")))
  (dolist (mode (list 'html-mode 'nxml-mode))
    (mmm-add-mode-ext-class mode "\\.r?html\\(\\.erb\\)?\\'" 'html-css)))


;;; SASS and SCSS
(use-package sass-mode)
(unless (fboundp 'scss-mode)
  ;; Prefer the scss-mode built into Emacs
  (use-package scss-mode))
(setq-default scss-compile-at-save nil)


(use-package less-css-mode)
(use-package skewer-less
  :hook
  (less-css-mode . skewer-less-mode)
  )


;; Skewer CSS
(use-package skewer-mode
  :hook
  (css-mode . skewer-css-mode)
  )


;;; Use eldoc for syntax hints
(use-package css-eldoc)
(autoload 'turn-on-css-eldoc "css-eldoc")
(add-hook 'css-mode-hook 'turn-on-css-eldoc)

(use-package haml-mode)

(with-eval-after-load 'haml-mode
  (define-key haml-mode-map (kbd "C-o") 'open-line))

(use-package httprepl)
(use-package restclient
  :mode ("\\.rest\\'" . restclient-mode)
  :init
  (defun my/restclient ()
    (interactive)
    (with-current-buffer (get-buffer-create "*restclient*")
      (restclient-mode)
      (pop-to-buffer (current-buffer)))))

(use-package idris-mode
  :init
  (add-to-list 'completion-ignored-extensions ".ibc")
  )

(when (executable-find "agda-mode")
  (use-package agda2
    :ensure nil
    :straight nil
    :load-path (lambda ()
                 (let ((coding-system-for-read 'utf-8))
                   (file-name-directory (shell-command-to-string "agda-mode locate"))))
    :mode ("\\.l?agda\\'" . agda2-mode)
    :interpreter ("agda -I" . agda2-mode)))

(use-package elm-mode
  :init
  (setq-default elm-format-on-save t)
  (use-package elm-test-runner)
  (use-package flycheck-elm
    :after elm-mode
    :config
    (flycheck-elm-setup)
    )
  :hook (elm-mode . (lambda () (local-push-company-backend 'company-elm)))
  :diminish elm-indent-mode
  :config
  (when (executable-find "elm-format")
    (setq-default elm-format-on-save t))
  )

(use-package purescript-mode
  :init
  (use-package psc-ide
    :hook
    (purescript-mode . (lambda ()
                         (psc-ide-mode)
                         (turn-on-purescript-indentation)))
    )
  )


;; ;;; Basic ruby setup
;; (use-package ruby-mode
;;   :mode
;;   "Rakefile\\'" "\\.rake\\'" "\\.rxml\\'" "\\.rjs\\'"
;;   "\\.irbrc\\'" "\\.pryrc\\'" "\\.builder\\'" "\\.ru\\'"
;;   "\\.gemspec\\'" "Gemfile\\'" "Kirkfile\\'" "Brewfile\\'"
;;   :mode ("Gemfile\\.lock\\'" . conf-mode )
;;   :hook (ruby-mode . subword-mode)
;;   :init
;;   (setq-default
;;    ruby-use-encoding-map nil
;;    ruby-insert-encoding-magic-comment nil)
;;   )

;; (use-package ruby-hash-syntax)

;; (with-eval-after-load 'page-break-lines
;;   (push 'ruby-mode page-break-lines-modes))

;; (use-package rspec-mode)

;; ;;; Inferior ruby
;; (use-package inf-ruby)

;; ;;; Ruby compilation
;; (use-package ruby-compilation)

;; (with-eval-after-load 'ruby-mode
;;   (let ((m ruby-mode-map))
;;     (define-key m [S-f7] 'ruby-compilation-this-buffer)
;;     (define-key m [f7] 'ruby-compilation-this-test)))

;; (with-eval-after-load 'ruby-compilation
;;   (defalias 'rake 'ruby-compilation-rake))

;; ;;; Robe
;; (use-package robe
;;   :init
;;   (with-eval-after-load 'ruby-mode
;;     (add-hook 'ruby-mode-hook 'robe-mode))
;;   (with-eval-after-load 'company
;;     (dolist (hook (mapcar 'derived-mode-hook-name '(ruby-mode inf-ruby-mode html-erb-mode haml-mode)))
;;       (add-hook hook
;;                 (lambda () (local-push-company-backend 'company-robe))))))


;;; ri support
(use-package yari)
(defalias 'ri 'yari)


(use-package bundler)


(use-package yard-mode
  :hook (ruby-mode . yard-mode)
  :diminish yard-mode
  )


;;----------------------------------------------------------------------------
;; Ruby - my convention for heredocs containing SQL
;;----------------------------------------------------------------------------

;; Needs to run after rinari to avoid clobbering font-lock-keywords?

;; (my/try-install-package 'mmm-mode)
;; (with-eval-after-load 'mmm-mode
;;   '(progn
;;      (mmm-add-classes
;;       '((ruby-heredoc-sql
;;          :submode sql-mode
;;          :front "<<-?[\'\"]?\\(end_sql\\)[\'\"]?"
;;          :save-matches 1
;;          :front-offset (end-of-line 1)
;;          :back "^[ \t]*~1$"
;;          :delimiter-mode nil)))
;;      (mmm-add-mode-ext-class 'ruby-mode "\\.rb\\'" 'ruby-heredoc-sql)))

                                        ;(add-to-list 'mmm-set-file-name-for-modes 'ruby-mode)

(use-package projectile-rails
  :hook
  (projectile-mode .
                   (lambda () (projectile-rails-global-mode projectile-mode)))
  )

(with-eval-after-load 'sql
  ;; sql-mode pretty much requires your psql to be uncustomised from stock settings
  (push "--no-psqlrc" sql-postgres-options))

(defun my/fix-postgres-prompt-regexp ()
  "Work around https://debbugs.gnu.org/cgi/bugreport.cgi?bug=22596.
  Fix for the above hasn't been released as of Emacs 25.2."
  (when (eq sql-product 'postgres)
    (setq-local sql-prompt-regexp "^[[:alnum:]_]*=[#>] ")
    (setq-local sql-prompt-cont-regexp "^[[:alnum:]_]*[-(][#>] ")))

(add-hook 'sql-interactive-mode-hook 'my/fix-postgres-prompt-regexp)

(defun my/pop-to-sqli-buffer ()
  "Switch to the corresponding sqli buffer."
  (interactive)
  (if (and sql-buffer (buffer-live-p sql-buffer))
      (progn
        (pop-to-buffer sql-buffer)
        (goto-char (point-max)))
    (sql-set-sqli-buffer)
    (when sql-buffer
      (my/pop-to-sqli-buffer))))

(with-eval-after-load 'sql
  (define-key sql-mode-map (kbd "C-c C-z") 'my/pop-to-sqli-buffer)
  (when (package-installed-p 'dash-at-point)
    (defun my/maybe-set-dash-db-docset ()
      (when (eq sql-product 'postgres)
        (set (make-local-variable 'dash-at-point-docset) "psql")))

    (add-hook 'sql-mode-hook 'my/maybe-set-dash-db-docset)
    (add-hook 'sql-interactive-mode-hook 'my/maybe-set-dash-db-docset)
    (defadvice sql-set-product (after set-dash-docset activate)
      (my/maybe-set-dash-db-docset))))

(setq-default sql-input-ring-file-name
              (expand-file-name ".sqli_history" my/emacs-d))

;; See my answer to https://emacs.stackexchange.com/questions/657/why-do-sql-mode-and-sql-interactive-mode-not-highlight-strings-the-same-way/673
(defun my/font-lock-everything-in-sql-interactive-mode ()
  (unless (eq 'oracle sql-product)
    (sql-product-font-lock nil nil)))
(add-hook 'sql-interactive-mode-hook 'my/font-lock-everything-in-sql-interactive-mode)

(defun my/sqlformat (beg end)
  "Reformat SQL in region from BEG to END using the \"sqlformat\" program.
  If no region is active, the current statement (paragraph) is reformatted.
  Install the \"sqlparse\" (Python) package to get \"sqlformat\"."
  (interactive "r")
  (unless (use-region-p)
    (setq beg (save-excursion
                (backward-paragraph)
                (skip-syntax-forward " >")
                (point))
          end (save-excursion
                (forward-paragraph)
                (skip-syntax-backward " >")
                (point))))
  (shell-command-on-region beg end "sqlformat -r -" nil t "*sqlformat-errors*" t))

(with-eval-after-load 'sql
  (define-key sql-mode-map (kbd "C-c C-f") 'my/sqlformat))

;; Package ideas:
;;   - PEV
(defun my/sql-explain-region-as-json (beg end &optional copy)
  "Explain the SQL between BEG and END in detailed JSON format.
  This is suitable for pasting into tools such as
  http://tatiyants.com/pev/.

  When the prefix argument COPY is non-nil, do not display the
  resulting JSON, but instead copy it to the kill ring.

  If the region is not active, uses the current paragraph, as per
  `sql-send-paragraph'.

  Connection information is taken from the special sql-* variables
  set in the current buffer, so you will usually want to start a
  SQLi session first, or otherwise set `sql-database' etc.

  This command currently blocks the UI, sorry."
  (interactive "rP")
  (unless (eq sql-product 'postgres)
    (user-error "This command is for PostgreSQL only"))
  (unless (use-region-p)
    (setq beg (save-excursion (backward-paragraph) (point))
          end (save-excursion (forward-paragraph) (point))))
  (let ((query (buffer-substring-no-properties beg end)))
    (with-current-buffer (if (sql-buffer-live-p sql-buffer)
                             sql-buffer
                           (current-buffer))
      (let* ((process-environment
              (append (list (concat "PGDATABASE=" sql-database)
                            (concat "PGHOST=" sql-server)
                            (concat "PGUSER=" sql-user))
                      process-environment))
             (args (list "--no-psqlrc"
                         "-qAt"
                         "-w"             ; Never prompt for password
                         "-E"
                         "-c" (concat "EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) " query ";")
                         ))
             (err-file (make-temp-file "sql-explain-json")))
        (with-current-buffer (get-buffer-create "*sql-explain-json*")
          (setq buffer-read-only nil)
          (delete-region (point-min) (point-max))
          (let ((retcode (apply 'call-process sql-postgres-program nil (list (current-buffer) err-file) nil args)))
            (if (zerop retcode)
                (progn
                  (json-mode)
                  (if copy
                      (progn
                        (kill-ring-save (buffer-substring-no-properties (point-min) (point-max)))
                        (message "EXPLAIN output copied to kill-ring."))
                    (view-buffer (current-buffer))))
              (with-current-buffer (get-buffer-create "*sql-explain-errors*")
                (setq buffer-read-only nil)
                (insert-file-contents err-file nil nil nil t)
                (view-buffer (current-buffer))
                (user-error "EXPLAIN failed")))))))))


;; Submitted upstream as https://github.com/stanaka/dash-at-point/pull/28
(with-eval-after-load 'sql
  (with-eval-after-load 'dash-at-point
    (add-to-list 'dash-at-point-mode-alist '(sql-mode . "psql,mysql,sqlite,postgis"))))


(with-eval-after-load 'page-break-lines
  (push 'sql-mode page-break-lines-modes))

(use-package toml-mode
  :hook
  (toml-mode . goto-address-prog-mode)
  )

(use-package yaml-mode
  :hook
  (yaml-mode . goto-address-prog-mode)
  )

(use-package json
  :hook
  (json-mode . (lambda () (format-all-mode 1)))
  )

(use-package docker
  :config
  (fullframe docker-images tablist-quit)
  (fullframe docker-machines tablist-quit)
  (fullframe docker-volumes tablist-quit)
  (fullframe docker-networks tablist-quit)
  (fullframe docker-containers tablist-quit)
  )

(use-package dockerfile-mode)

(use-package docker-api)

(use-package docker-compose-mode)

(use-package vagrant-tramp)

(use-package terraform-mode
  :init
  (use-package company-terraform)
  :config
  (company-terraform-init)
  )

(use-package nix-update)

(use-package nix-mode
  :hook
  (nix-mode . (lambda ()
                (format-all-mode 1)
                (smartparens-mode -1)))
  )

(use-package nix-sandbox)

(use-package nix-buffer)

(use-package nixos-options)

(use-package company-nixos-options
  :after company
  :config
  (add-hook 'nix-mode
            (lambda ()
              (local-push-company-backend 'company-nixos-options)
              )
            )
  )

(use-package direnv
  :init
  :hook
  (after-init . direnv-mode)
  )

(use-package projectile-direnv
  :after projectile direnv)

(use-package smartparens
  :init
  (setq sp-show-pair-from-inside nil)
  (require 'smartparens-config)
  (smartparens-global-mode 1)
  :diminish smartparens-mode
  :bind
  ("s-a s-a" . 'sp-beginning-of-sexp)
  ("s-a s-e" . 'sp-end-of-sexp)
  ("s-a j" . 'sp-down-sexp)
  ("s-a k" .   'sp-up-sexp)
  ("s-a s-j" . 'sp-backward-down-sexp)
  ("s-a s-k" . 'sp-backward-up-sexp)
  ("s-a s-f" . 'sp-forward-sexp)
  ("s-a s-b" . 'sp-backward-sexp)
  ("s-a s-n" . 'sp-next-sexp)
  ("s-a s-p" . 'sp-previous-sexp)
  ("s-a f" . 'sp-forward-symbol)
  ("s-a b" . 'sp-backward-symbol)
  ("s-a l" . 'sp-forward-slurp-sexp)
  ("s-a s-l" . 'sp-forward-barf-sexp)
  ("s-a h" .  'sp-backward-slurp-sexp)
  ("s-a s-h" .  'sp-backward-barf-sexp)
  ("s-a s-t" . 'sp-transpose-sexp)
  ("s-a s-x" . 'sp-kill-sexp)
  ("s-a x" .   'sp-kill-hybrid-sexp)
  ("s-a s-d" .   'sp-backward-kill-sexp)
  ("s-a s-c" . 'sp-copy-sexp)
  ("s-a u" . 'sp-backward-unwrap-sexp)
  ("s-a s-u" . 'sp-unwrap-sexp)
  ("s-a s-r" . 'sp-rewrap-sexp)
  ("s-a (" .  'wrap-with-parens)
  ("s-a [" .  'wrap-with-brackets)
  ("s-a {" .  'wrap-with-braces)
  ("s-a '" .  'wrap-with-single-quotes)
  ("s-a \"" . 'wrap-with-double-quotes)
  ("s-a _" .  'wrap-with-underscores)
  ("s-a `" .  'wrap-with-back-quotes)
  )

(use-package wrap-region
  :config
  (wrap-region-global-mode t)
  (wrap-region-add-wrapper "~" "~" nil 'org-mode)  ; code
  (wrap-region-add-wrapper "*" "*" nil 'org-mode)  ; bold
  (wrap-region-add-wrapper "/" "/" nil 'org-mode)  ; italic
  (wrap-region-add-wrapper "+" "+" nil 'org-mode)  ; strikethrough
  (wrap-region-add-wrapper "=" "=" nil 'org-mode)) ; verbatim

(use-package yasnippet
  :init
  (add-to-list 'load-path
               "~/.emacs.d/plugins/yasnippet")
  (require 'yasnippet)
  (yas-global-mode 1)
  :diminish yas-minor-mode)

(use-package emr)

(use-package erefactor)

(use-package elisp-slime-nav)

(dolist (hook '(emacs-lisp-mode-hook ielm-mode-hook))
  (add-hook hook 'turn-on-elisp-slime-nav-mode))
(add-hook 'emacs-lisp-mode-hook (lambda () (setq mode-name "ELisp")))

;; (setq-default initial-scratch-message
;;               (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n"))
;; Supply a random fortune cookie as the *scratch* message.
(when (executable-find "fortune")
  (setq initial-scratch-message
        (with-temp-buffer
          (shell-command "fortune" t)
          (let ((comment-start ";;"))
            (comment-region (point-min) (point-max)))
          (concat (buffer-string) "\n"))))


;; Make C-x C-e run 'eval-region if the region is active

(defun my/eval-last-sexp-or-region (prefix)
  "Eval region from BEG to END if active, otherwise the last sexp."
  (interactive "P")
  (if (and (mark) (use-region-p))
      (eval-region (min (point) (mark)) (max (point) (mark)))
    (pp-eval-last-sexp prefix)))

(global-set-key [remap eval-expression] 'pp-eval-expression)

(with-eval-after-load 'lisp-mode
  (define-key emacs-lisp-mode-map (kbd "C-x C-e") 'my/eval-last-sexp-or-region))

;; (when (my/try-install-package 'ipretty)
;;   (add-hook 'after-init-hook 'ipretty-mode))


(defadvice pp-display-expression (after my/make-read-only (expression out-buffer-name) activate)
  "Enable `view-mode' in the output buffer - if any - so it can be closed with `\"q\"."
  (when (get-buffer out-buffer-name)
    (with-current-buffer out-buffer-name
      (view-mode 1))))



(defun my/maybe-set-bundled-elisp-readonly ()
  "If this elisp appears to be part of Emacs, then disallow editing."
  (when (and (buffer-file-name)
             (string-match-p "\\.el\\.gz\\'" (buffer-file-name)))
    (setq buffer-read-only t)
    (view-mode 1)))

(add-hook 'emacs-lisp-mode-hook 'my/maybe-set-bundled-elisp-readonly)


;; Use C-c C-z to toggle between elisp files and an ielm session
;; I might generalise this to ruby etc., or even just adopt the repl-toggle package.

(defvar my/repl-original-buffer nil
  "Buffer from which we jumped to this REPL.")
(make-variable-buffer-local 'my/repl-original-buffer)

(defvar my/repl-switch-function 'switch-to-buffer-other-window)

(defun my/switch-to-ielm ()
  (interactive)
  (let ((orig-buffer (current-buffer)))
    (if (get-buffer "*ielm*")
        (funcall my/repl-switch-function "*ielm*")
      (ielm))
    (setq my/repl-original-buffer orig-buffer)))

(defun my/repl-switch-back ()
  "Switch back to the buffer from which we reached this REPL."
  (interactive)
  (if my/repl-original-buffer
      (funcall my/repl-switch-function my/repl-original-buffer)
    (error "No original buffer")))

(with-eval-after-load 'elisp-mode
  (define-key emacs-lisp-mode-map (kbd "C-c C-z") 'my/switch-to-ielm))
(with-eval-after-load 'ielm
  (define-key ielm-map (kbd "C-c C-z") 'my/repl-switch-back))

;; ----------------------------------------------------------------------------
;; Hippie-expand
;; ----------------------------------------------------------------------------

(defun set-up-hippie-expand-for-elisp ()
  "Locally set `hippie-expand' completion functions for use with Emacs Lisp."
  (make-local-variable 'hippie-expand-try-functions-list)
  (add-to-list 'hippie-expand-try-functions-list 'try-complete-lisp-symbol t)
  (add-to-list 'hippie-expand-try-functions-list 'try-complete-lisp-symbol-partially t)
  (add-to-list 'hippie-expand-try-functions-list 'my/try-complete-lisp-symbol-without-namespace t))


;; ----------------------------------------------------------------------------
;; Automatic byte compilation
;; ----------------------------------------------------------------------------
(use-package auto-compile
  :hook
  (after-init . auto-compile-on-save-mode)
  (after-init . auto-compile-on-load-mode)
  )

;; ----------------------------------------------------------------------------
;; Load .el if newer than corresponding .elc
;; ----------------------------------------------------------------------------
(setq load-prefer-newer t)



(use-package immortal-scratch
  :hook
  (after-init . immortal-scratch-mode)
  )


;;; Support byte-compilation in a sub-process, as

(defun my/byte-compile-file-batch (filename)
  "Byte-compile FILENAME in batch mode, ie. a clean sub-process."
  (interactive "fFile to byte-compile in batch mode: ")
  (let ((emacs (car command-line-args)))
    (compile
     (concat
      emacs " "
      (mapconcat
       'shell-quote-argument
       (list "-Q" "-batch" "-f" "batch-byte-compile" filename)
       " ")))))


;; ----------------------------------------------------------------------------
;; Enable desired features for all lisp modes
;; ----------------------------------------------------------------------------

(defun my/lisp-setup ()
  "Enable features useful in any Lisp mode."
  (run-hooks 'my/lispy-modes-hook))

(defvar my/lispy-modes-hook
  '(my/enable-check-parens-on-save)
  "Hook run in all Lisp modes.")

(defun my/enable-check-parens-on-save ()
  "Run `check-parens' when the current buffer is saved."
  (add-hook 'after-save-hook #'check-parens nil t))

(use-package aggressive-indent
  :init
  (add-to-list 'my/lispy-modes-hook 'aggressive-indent-mode))

(defun my/emacs-lisp-setup ()
  "Enable features useful when working with elisp."
  (set-up-hippie-expand-for-elisp))

(defconst my/elispy-modes
  '(emacs-lisp-mode ielm-mode)
  "Major modes relating to elisp.")

(defconst my/lispy-modes
  (append my/elispy-modes
          '(lisp-mode inferior-lisp-mode lisp-interaction-mode))
  "All lispy major modes.")

(require 'derived)

(dolist (hook (mapcar #'derived-mode-hook-name my/lispy-modes))
  (add-hook hook 'my/lisp-setup))

(dolist (hook (mapcar #'derived-mode-hook-name my/elispy-modes))
  (add-hook hook 'my/emacs-lisp-setup))

(if (boundp 'eval-expression-minibuffer-setup-hook)
    (add-hook 'eval-expression-minibuffer-setup-hook #'eldoc-mode)
  (use-package eldoc-eval)
  (require 'eldoc-eval)
  (add-hook 'after-init-hook 'eldoc-in-minibuffer-mode))

(add-to-list 'auto-mode-alist '("\\.emacs-project\\'" . emacs-lisp-mode))
(add-to-list 'auto-mode-alist '("archive-contents\\'" . emacs-lisp-mode))

(use-package cl-lib-highlight
  :hook
  (lisp-mode .
             (cl-lib-highlight-initialize))
  )

;; ----------------------------------------------------------------------------
;; Delete .elc files when reverting the .el from VC or magit
;; ----------------------------------------------------------------------------

;; When .el files are open, we can intercept when they are modified
;; by VC or magit in order to remove .elc files that are likely to
;; be out of sync.

;; This is handy while actively working on elisp files, though
;; obviously it doesn't ensure that unopened files will also have
;; their .elc counterparts removed - VC hooks would be necessary for
;; that.

(defvar my/vc-reverting nil
  "Whether or not VC or Magit is currently reverting buffers.")

(defadvice revert-buffer (after my/maybe-remove-elc activate)
  "If reverting from VC, delete any .elc file that will now be out of sync."
  (when my/vc-reverting
    (when (and (eq 'emacs-lisp-mode major-mode)
               buffer-file-name
               (string= "el" (file-name-extension buffer-file-name)))
      (let ((elc (concat buffer-file-name "c")))
        (when (file-exists-p elc)
          (message "Removing out-of-sync elc file %s" (file-name-nondirectory elc))
          (delete-file elc))))))

(defadvice magit-revert-buffers (around my/reverting activate)
  (let ((my/vc-reverting t))
    ad-do-it))
(defadvice vc-revert-buffer-internal (around my/reverting activate)
  (let ((my/vc-reverting t))
    ad-do-it))



(use-package macrostep
  :bind (:map emacs-lisp-mode-map
              ("C-c e" . macrostep-expand)))



;; A quick way to jump to the definition of a function given its key binding
(global-set-key (kbd "C-h K") 'find-function-on-key)



(use-package rainbow-mode
  :hook
  (help-mode . rainbow-mode))



(use-package highlight-quoted
  :hook
  (emacs-lisp-mode . highlight-quoted-mode)
  )



(use-package elisp-format)


;; ERT
(with-eval-after-load 'ert
  (define-key ert-results-mode-map (kbd "g") 'ert-results-rerun-all-tests))


(defun my/cl-libify-next ()
  "Find next symbol from 'cl and replace it with the 'cl-lib equivalent."
  (interactive)
  (let ((case-fold-search nil))
    (re-search-forward
     (concat
      "("
      (regexp-opt
       ;; Not an exhaustive list
       '("loop" "incf" "plusp" "first" "decf" "minusp" "assert"
         "case" "destructuring-bind" "second" "third" "defun*"
         "defmacro*" "return-from" "labels" "cadar" "fourth"
         "cadadr") t)
      "\\_>")))
  (let ((form (match-string 1)))
    (backward-sexp)
    (cond
     ((string-match "^\\(defun\\|defmacro\\)\\*$")
      (kill-sexp)
      (insert (concat "cl-" (match-string 1))))
     (t
      (insert "cl-")))
    (when (fboundp 'aggressive-indent-indent-defun)
      (aggressive-indent-indent-defun))))


(use-package cask-mode)

(use-package slime
  :config
  (setq slime-protocol-version 'ignore)
  (setq slime-net-coding-system 'utf-8-unix)
  (let ((extras (when (require 'slime-company nil t)
                  '(slime-company))))
    (slime-setup (append '(slime-repl slime-fuzzy) extras)))
  (setq slime-complete-symbol*-fancy t)
  (setq slime-complete-symbol-function 'slime-fuzzy-complete-symbol))

(use-package hippie-expand-slime
  :hook
  (slime-mode . set-up-slime-hippie-expand))
(use-package slime-company)



(use-package clojure-mode
  :hook
  (clojure-mode . my/lisp-setup)
  (clojure-mode . subword-mode)
  :init
  (use-package cljsbuild-mode)
  (use-package elein)
  (with-eval-after-load 'clojure-mode
    )
  )

(use-package cider
  :hook
  (cider-mode . eldoc-mode)
  (cider-repl-mode . 'subword-mode)
  :config
  (flycheck-clojure-setup)
  :init
  (setq nrepl-popup-stacktraces nil)
  (use-package flycheck-clojure))

(use-package slime
  :hook (lisp-mode . (lambda ()
                       (unless (featurep 'slime)
                         (require 'slime)
                         (normal-mode))))
  :bind
  (:map lisp-mode-map
        ("C-c l" . lispdoc))
  :init
  (when (executable-find "sbcl")
    (add-to-list 'slime-lisp-implementations
                 '(sbcl ("sbcl") :coding-system utf-8-unix)))
  (when (executable-find "lisp")
    (add-to-list 'slime-lisp-implementations
                 '(cmucl ("lisp") :coding-system iso-latin-1-unix)))
  (when (executable-find "ccl")
    (add-to-list 'slime-lisp-implementations
                 '(ccl ("ccl") :coding-system utf-8-unix)))

  ;; From http://bc.tech.coop/blog/070515.html
  (defun lispdoc ()
    "Searches lispdoc.com for SYMBOL, which is by default the symbol currently under the curser"
    (interactive)
    (let* ((word-at-point (word-at-point))
           (symbol-at-point (symbol-at-point))
           (default (symbol-name symbol-at-point))
           (inp (read-from-minibuffer
                 (if (or word-at-point symbol-at-point)
                     (concat "Symbol (default " default "): ")
                   "Symbol (no default): "))))
      (if (and (string= inp "") (not word-at-point) (not
                                                     symbol-at-point))
          (message "you didn't enter a symbol!")
        (let ((search-type (read-from-minibuffer
                            "full-text (f) or basic (b) search (default b)? ")))
          (browse-url (concat "http://lispdoc.com?q="
                              (if (string= inp "")
                                  default
                                inp)
                              "&search="
                              (if (string-equal search-type "f")
                                  "full+text+search"
                                "basic+search")))))))
  )

(use-package auctex
  :defer t
  :hook
  (LaTeX-mode . (lambda () (format-all-mode 1) (lsp)))
  :init
  (setq TeX-engine 'luatex)
  (setq TeX-save-query nil)
  (setq reftex-plug-into-AUCTeX t)
  (setq TeX-electric-sub-and-superscript t)
  (defvar mg-TeX-insert-subscript-history nil)
  (defvar mg-TeX-insert-superscript-history nil)

  ;;(setq TeX-view-program-selection '((output-pdf "Zathura"))

  ;; to use pdfview with auctex
  ;;(setq TeX-view-program-selection '((output-pdf "PDF Tools"))
  ;;   TeX-view-program-list '(("PDF Tools" TeX-pdf-tools-sync-view))
  ;;   TeX-source-correlate-start-server t) ;; not sure if last line is neccessary

  ;; to have the buffer refresh after compilation
  (add-hook 'TeX-after-compilation-finished-functions
            #'TeX-revert-document-buffer)

  ;;(defun my-TeX-command-run-all ()
  ;;  (TeX-command-run-all 'TeX-master-file)
  ;;  (other-window))

  (defun LaTeX-auto-compile ()
    (if (bound-and-true-p TeX-master)
        (progn
          (my-LaTeX-compile))
      ;;    (progn
      ;;      (dolist (timer timer-list)
      ;;        (if (eq (elt timer 5) 'LaTeX-auto-compile)
      ;;            (cancel-timer timer))))
      (progn
        (cancel-timer tex-auto-compile-timer)
        (cancel-function-timers 'LaTeX-auto-compile))
      ))
  (defun my-LaTeX-mode-config ()
    ;;    (local-set-key (kbd "C-c C-a") (my-TeX-command-run-all))
    (smartparens-mode 1)
    ;;(setq tex-auto-compile-timer (run-with-timer 10 100 'LaTeX-auto-compile))
    (add-to-list 'TeX-expand-list
                 '("%(tex-file-name)"
                   (lambda ()
                     (concat
                      "\"" (car (split-string (buffer-file-name) "\\.Rnw"))
                      ".tex" "\""))))
    (push
     '("LaTeXmk" "latexmk -synctex=1 -pdf %s" TeX-run-TeX nil t
       :help "Run latexmk on file") TeX-command-list)
    (push
     '("knitr" "R -e 'knitr::knit(\"%s\")'" TeX-run-TeX nil t
       :help "Run knitr on file") TeX-command-list)
    (push
     '("klatex" "R -e 'knitr::knit(\"%s\")';latexmk -pdf %(tex-file-name)"
       TeX-run-TeX nil t
       :help "Run knitr and latexmk on .tex") TeX-command-list)
    (push
     '("arara" "arara --verbose %s" TeX-run-TeX nil t
       :help "Run arara on file") TeX-command-list)
    (push
     '("compileboth" "compileboth %s" TeX-run-TeX nil t
       :help "Generate questions and answers") TeX-command-list)
    (push
     '("bothaspects" "bothaspects %s" TeX-run-TeX nil t
       :help "Generate 16:9 and 4:3 slides") TeX-command-list)
    (setq TeX-command-default "arara")
    )

  (defun TeX-insert-sub-or-superscript (arg)
    "Insert typed key ARG times and possibly a pair of braces.
  Brace insertion is only done if point is in a math construct and
  `TeX-electric-sub-and-superscript' has a non-nil value."
    (interactive "*p")
    (self-insert-command arg)
    (when (and TeX-electric-sub-and-superscript (texmathp))
      (let* ((history (cond
                       ((equal last-input-event ?_)
                        'mg-TeX-insert-subscript-history)
                       ((equal last-input-event ?^)
                        'mg-TeX-insert-superscript-history)))
             (content (read-string "Content: " (car (symbol-value history)) history)))
        (insert (concat TeX-grop content TeX-grcl))
        (if (zerop (length content))
            (backward-char)))))

  (defun my-TeX-mode-config ()
    ;;    (local-set-key (kbd "C-c C-a") (my-TeX-command-run-all))
    ;; (setq-local company-backends
    ;;             append '((company-math-symbols-latex company-latex-commands))
    ;;             company-backends)
    ;; (company-auctex-init)
    (smartparens-mode 1)
    (TeX-source-correlate-mode 1)
    (setq TeX-source-correlate-start-server t)
    ;;    (run-with-timer 10 60 'my-TeX-compile)
    )

  (add-hook 'TeX-mode-hook 'my-TeX-mode-config)
  (add-hook 'LaTeX-mode-hook 'my-LaTeX-mode-config)

  (defun my-LaTeX-compile ()
    (interactive)
    ;;(if (eq major-mode 'latex-mode)
    (if (and (eq major-mode 'latex-mode)
             (not (get-process "LaTeX")))
        (progn
          (TeX-save-document (TeX-master-file))
          (TeX-command "LaTeX" 'TeX-master-file -1))))

  (defun my-TeX-compile ()
    (interactive)
    (TeX-save-document (TeX-master-file))
    (TeX-command "TeX" 'TeX-master-file))

  (with-eval-after-load 'latex
    '(define-key LaTeX-mode-map (kbd "C-c C-a") 'my-LaTeX-compile))

  (with-eval-after-load 'plain-tex
    '(define-key plain-TeX-mode-map (kbd "C-c C-a") 'my-TeX-compile))

  ;;(global-set-key (kbd "<f1> C-a") 'my-TeX-command-run-all)

  ;;(add-hook 'TeX-after-compilation-finished-functions 'other-window)

  ;;(defun TeX-compile-hook (x)
  ;;  (TeX-revert-document-buffer x)
  ;;  (other-window)
  ;;  )

  ;;(add-hook 'TeX-after-compilation-finished-functions 'TeX-compile-hook)

  ;;(add-hook 'TeX-after-compilation-finished-functions (lambda (x)
  ;;     (TeX-revert-document-buffer x)
  ;;     (other-window)
  ;;     (message 'compilation finished)
  ;;     ))

  )

(use-package company-math
  :after company auctex
  :config
  (setq-local company-backends
              (append '((company-math-symbols-latex company-latex-commands))
                      company-backends))
  )

(use-package company-bibtex
  :after company auctex
  :config
  (require 'company-bibtex)
  (add-to-list 'company-backends 'company-bibtex)
  )

(use-package company-auctex
  :after company auctex
  :config
  (require 'company-auctex)
  (company-auctex-init)
  )

(use-package company-reftex
  :after company auctex
  :config
  (require 'company-auctex)
  (company-auctex-init)
  )

;; (use-package latex-extra
;;   ;; :config
;;   ;; (add-hook 'LaTeX-mode-hook #'latex-extra-mode)
;;   )

(use-package latexdiff)

(use-package org-edit-latex
  :after org
  :config
  (require 'org-edit-latex)
  )

(use-package latex-math-preview)

(use-package latex-preview-pane)

(use-package latex-unicode-math-mode)

(defun toogle-max-screen-estate ()
  "maximize screen estate"
  (interactive)
  (toggle-mode-line))

(defun toggle-mode-line ()
  "toggles the modeline on and off"
  (interactive)
  (setq mode-line-format
        (if (equal mode-line-format nil)
            (default-value 'mode-line-format)) )
  (redraw-display))

(use-package calibredb
  :config
  (setq calibredb-root-dir "~/Storage/Calibre")
  (setq calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir))
  (setq calibredb-library-alist '(("~/Storage/Calibre"))))

(use-package org-logseq
  :straight (org-logseq :type git :host github :repo "llcc/org-logseq")
  :custom (org-logseq-dir "~/Sync/docs/logseq"))

(use-package zotero
  :commands (zotero-browser zotero-sync))

(use-package zotxt)

(use-package pdf-tools
  :magic ("%PDF" . pdf-view-mode)
  :custom
  (image-cache-eviction-delay 150)
  :hook
  (pdf-view-mode . (lambda ()
                     (local-set-key "C-s" 'isearch-forward)
                     (toogle-max-screen-estate)))
  (after-init . (lambda () (pdf-tools-install t)))
  )

(use-package djvu
  :straight (djvu :type git :host github :repo "dalanicolai/djvu2.el"))

(use-package proof-general
  :init
  (setq proof-splash-enable nil)
  (setq coq-compile-before-require t)
  (setq coq-prog-args `("-R" ,(expand-file-name "~/Workspace/cpdt/src") "Cpdt"))
  ;; (setq coq-debug t)
  )

(use-package company-coq
  :after coq
  :init
  (add-hook 'coq-mode-hook #'company-coq-mode)
  )

(use-package synosaurus
  :bind
  ("s-x l" . 'synosaurus-lookup)
  ("s-x r" . 'synosaurus-choose-and-replace)
  ("s-x i" . 'synosaurus-choose-and-insert))

(use-package auto-capitalize
  :straight (auto-capitalize :type git :host github :repo "emacsmirror/auto-capitalize"))

(use-package pangu-spacing)

(use-package langtool
  :bind
  ("s-x K" . 'langtool-check)
  ("s-x D" . 'langtool-check-done)
  ("s-x L" . 'langtool-switch-default-language)
  ("s-x s-m" . 'langtool-show-message-at-point)
  ("s-x s-l" . 'langtool-correct-buffer)
  :config
  (setq langtool-default-language "en-US")
  (let ((server (executable-find "languagetool-commandline")))
    (if server (setq langtool-bin server)))
  )

(use-package flyspell-correct)

(use-package flyspell
  :hook (prog-mode . flyspell-prog-mode)
  :bind
  ("s-x s" . 'flyspell-mode)
  ("s-x n" . 'flyspell-correct-next)
  ("s-x p" . 'flyspell-correct-previous)
  ("s-x s-n" . 'flyspell-goto-next-error)
  ("s-x s-p" . 'flyspell-correct-previous)
  ("s-x s-x" . 'flyspell-auto-correct-word)
  ("s-x x" . 'flyspell-correct-at-point)
  ("s-x b" . 'flyspell-correct-word-before-point)
  ("s-x c" . 'flyspell-do-correct)
  ("s-x d" . 'ispell-change-dictionary)
  ("s-x s-b" . 'flyspell-buffer)
  :init
  (setq ispell-dictionary "english")
  ;; (define-key flyspell-mode-map (kbd "C-;") nil)
  ;; if (aspell installed) { use aspell}
  ;; else if (hunspell installed) { use hunspell }
  ;; whatever spell checker I use, I always use English dictionary
  ;; I prefer use aspell because:
  ;; 1. aspell is older
  ;; 2. looks Kevin Atkinson still get some road map for aspell:
  ;; @see http://lists.gnu.org/archive/html/aspell-announce/2011-09/msg00000.html
  (defun flyspell-detect-ispell-args (&optional run-together)
    "if RUN-TOGETHER is true, spell check the CamelCase words."
    (let (args)
      (cond
       ((string-match  "aspell$" ispell-program-name)
        ;; Force the English dictionary for aspell
        ;; Support Camel Case spelling check (tested with aspell 0.6)
        (setq args (list "--sug-mode=ultra" "--lang=en_US"))
        (if run-together
            (setq args (append args '("--run-together"))))
        ((string-match "hunspell$" ispell-program-name)
         ;; Force the English dictionary for hunspell
         (setq args "-d en_US")))
       args))

    (cond
     ((executable-find "aspell")
      ;; you may also need `ispell-extra-args'
      (setq ispell-program-name "aspell"))
     ((executable-find "hunspell")
      (setq ispell-program-name "hunspell")

      ;; Please note that `ispell-local-dictionary` itself will be passed to hunspell cli with "-d"
      ;; it's also used as the key to lookup ispell-local-dictionary-alist
      ;; if we use different dictionary
      (setq ispell-local-dictionary "en_US")
      (setq ispell-local-dictionary-alist
            '(("en_US" "[[:alpha:]]" "[^[:alpha:]]" "[']" nil ("-d" "en_US") nil utf-8))))
     (t (setq ispell-program-name nil)))

    ;; ispell-cmd-args is useless, it's the list of *extra* arguments we will append to the ispell process when "ispell-word" is called.
    ;; ispell-extra-args is the command arguments which will *always* be used when start ispell process
    ;; Please note when you use hunspell, ispell-extra-args will NOT be used.
    ;; Hack ispell-local-dictionary-alist instead.
    (setq-default ispell-extra-args (flyspell-detect-ispell-args t))
    ;; (setq ispell-cmd-args (flyspell-detect-ispell-args))
    (defadvice ispell-word (around my-ispell-word activate)
      (let ((old-ispell-extra-args ispell-extra-args))
        (ispell-kill-ispell t)
        (setq ispell-extra-args (flyspell-detect-ispell-args))
        ad-do-it
        (setq ispell-extra-args old-ispell-extra-args)
        (ispell-kill-ispell t)))

    (defadvice flyspell-auto-correct-word (around my-flyspell-auto-correct-word activate)
      (let ((old-ispell-extra-args ispell-extra-args))
        (ispell-kill-ispell t)
        ;; use emacs original arguments
        (setq ispell-extra-args (flyspell-detect-ispell-args))
        ad-do-it
        ;; restore our own ispell arguments
        (setq ispell-extra-args old-ispell-extra-args)
        (ispell-kill-ispell t)))

    (defun text-mode-hook-setup ()
      ;; Turn off RUN-TOGETHER option when spell check text-mode
      (setq-local ispell-extra-args (flyspell-detect-ispell-args)))
    (add-hook 'text-mode-hook 'text-mode-hook-setup)
    )
  )

;; (use-package chinese-yasdcv)

(use-package google-this
  :diminish google-this-mode
  :init
  (google-this-mode 1)
  (global-set-key (kbd "s-/") 'google-this-mode-submap))

(use-package github-search)

(use-package sdcv
  :bind
  ("s-x s-d" . 'sdcv-search-input)
  ("s-x s-c" . 'sdcv-search-pointer)
  )

;;----------------------------------------------------------------------------
;; Misc config - yet to be placed in separate files
;;----------------------------------------------------------------------------
(use-package proxy-mode
  :config
  (setq proxy-mode-socks-proxy '("1081" "127.0.0.1" 1081 5))
  )

(use-package link-hint
  :defer t)

(setq url-gateway-local-host-regexp
      (concat "\\`" (regexp-opt '("localhost" "127.0.0.1")) "\\'"))

(global-auto-revert-mode t)

(toggle-truncate-lines t)
(setq tab-width 4)
(fset 'yes-or-no-p 'y-or-n-p)

(add-hook 'prog-mode-hook 'goto-address-prog-mode)
(setq goto-address-mail-face 'link)

(defun my-create-non-existent-directory ()
  (let ((parent-directory (file-name-directory buffer-file-name)))
    (when (and (not (file-exists-p parent-directory))
               (y-or-n-p (format "Directory `%s' does not exist! Create it?" parent-directory)))
      (make-directory parent-directory t))))

(add-to-list 'find-file-not-found-functions #'my-create-non-existent-directory)

(defun contextual-backspace ()
  "Hungry whitespace or delete word depending on context."
  (interactive)
  (if (looking-back "[[:space:]\n]\\{2,\\}" (- (point) 2))
      (while (looking-back "[[:space:]\n]" (- (point) 1))
        (delete-char -1))
    (cond
     ((and (boundp 'smartparens-strict-mode)
           smartparens-strict-mode)
      (sp-backward-kill-word 1))
     ((and (boundp 'subword-mode)
           subword-mode)
      (subword-backward-kill 1))
     (t
      (backward-kill-word 1)))))

(global-set-key (kbd "C-<backspace>") 'contextual-backspace)

;; TODO: publish this as "newscript" package or similar, providing global minor mode
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)
(add-hook 'after-save-hook 'my/set-mode-for-new-scripts)

(save-place-mode 1)
(setq save-place-file (expand-file-name "places" my/emacs-d))

(defun my/set-mode-for-new-scripts ()
  "Invoke `normal-mode' if this file is a script and in `fundamental-mode'."
  (and
   (eq major-mode 'fundamental-mode)
   (>= (buffer-size) 2)
   (save-restriction
     (widen)
     (string= "#!" (buffer-substring (point-min) (+ 2 (point-min)))))
   (normal-mode)))


;; Handle the prompt pattern for the 1password command-line interface
(with-eval-after-load 'comint
  (setq comint-password-prompt-regexp
        (concat
         comint-password-prompt-regexp
         "\\|^Please enter your password for user .*?:\\s *\\'")))

(use-package format-all)

(use-package nswbuff
  :config
  (setq nswbuff-exclude-buffer-regexps '("^ .*" "^\\*.*\\*" "diary" "wunderlist\\.md"))
  (setq nswbuff-include-buffer-regexps '("^\\*Org.*\\*"
                                         "^\\*eww.*\\*"
                                         "^\\*eshell.*\\*" ))
  (setq nswbuff-start-with-current-centered t)
  (setq nswbuff-clear-delay-ends-switching t)
  (setq nswbuff-display-intermediate-buffers t)
  )

(use-package eshell-toggle
  :custom
  (eshell-toggle-size-fraction 3)
  (eshell-toggle-use-projectile-root t)
  (eshell-toggle-run-command nil)
  :bind
  ("s-`" . eshell-toggle)
  ("s-~" . eshell)
  )

(use-package counsel-jq
  )

(use-package regex-tool
  :custom
  (regex-tool-backend 'perl)
  )

(with-eval-after-load 're-builder
  ;; Support a slightly more idiomatic quit binding in re-builder
  (define-key reb-mode-map (kbd "C-c C-k") 'reb-quit))

;; turn off auto revert messages
(setq auto-revert-verbose nil)

;; custom autosave to suppress messages
;;
;; For some reason `do-auto-save' doesn't work if called manually
;; after switching off the default autosave altogether. Instead set
;; to a long timeout so it is not called.
(setq auto-save-timeout 99999)

;; Set up my timer
(defvar bjm/auto-save-timer nil
  "Timer to run `bjm/auto-save-silent'")

;; Auto-save every 5 seconds of idle time
(defvar bjm/auto-save-interval 5
  "How often in seconds of idle time to auto-save with `bjm/auto-save-silent'")

;; Function to auto save files silently
(defun bjm/auto-save-silent ()
  "Auto-save all buffers silently"
  (interactive)
  (do-auto-save t))

;; Start new timer
(setq bjm/auto-save-timer
      (run-with-idle-timer 0 bjm/auto-save-interval 'bjm/auto-save-silent))

(defun bjm/kill-this-buffer ()
  "Kill the current buffer."
  (interactive)
  (kill-buffer (current-buffer)))

(defun switch-to-minibuffer-window ()
  "switch to minibuffer window (if active)"
  (interactive)
  (when (active-minibuffer-window)
    (select-frame-set-input-focus (window-frame (active-minibuffer-window)))
    (select-window (active-minibuffer-window))))

(defvar killed-file-list nil
  "List of recently killed files.")

(defun add-file-to-killed-file-list ()
  "If buffer is associated with a file name, add that file to the
  `killed-file-list' when killing the buffer."
  (when buffer-file-name
    (push buffer-file-name killed-file-list)))

(add-hook 'kill-buffer-hook #'add-file-to-killed-file-list)

(defun reopen-killed-file ()
  "Reopen the most recently killed file, if one exists."
  (interactive)
  (when killed-file-list
    (find-file (pop killed-file-list))))

(defun reopen-killed-file-fancy ()
  "Pick a file to revisit from a list of files killed during this
  Emacs session."
  (interactive)
  (if killed-file-list
      (let ((file (completing-read "Reopen killed file: " killed-file-list
                                   nil nil nil nil (car killed-file-list))))
        (when file
          (setq killed-file-list (cl-delete file killed-file-list :test #'equal))
          (find-file file)))
    (error "No recently-killed files to reopen")))

(defun revert-buffer-no-confirm ()
  "Revert buffer without confirmation."
  (interactive) (revert-buffer t t))

(use-package origami
  :hook
  (prog-mode-hook . origami-mode)
  :config
  (define-key origami-mode-map (kbd "C-c f") 'origami-recursively-toggle-node)
  (define-key origami-mode-map (kbd "C-c F") 'origami-toggle-all-nodes)
  )

(use-package matrix-client
  :straight (matrix-client :type git :host github :repo "alphapapa/matrix-client.el"))

(use-package iscroll)

(use-package nov
  :init
  :mode ("\\.epub\\'" . nov-mode )
  )

(use-package mu4e
  :ensure nil
  :straight nil
  :init
  (unless (require 'mu4e nil t)
    ;; try to add mu4e to load-path on nixos
    (ignore-errors
      (let ((mu4epath
             (concat
              (f-dirname
               (file-truename
                (executable-find "mu")))
              "/../share/emacs/site-lisp/mu4e")))
        (when (and
               (string-prefix-p "/nix/store/" mu4epath)
               (file-directory-p mu4epath))
          (add-to-list 'load-path mu4epath))
        (require 'mu4e))
      )
    )
  :config
  (defun my-mu4e-set-account ()
    "Set the account for composing a message."
    (let* ((account
            (if mu4e-compose-parent-message
                (let ((maildir (mu4e-message-field mu4e-compose-parent-message :maildir)))
                  (string-match "/\\(.*?\\)/" maildir)
                  (match-string 1 maildir))
              (completing-read (format "Compose with account: (%s) "
                                       (mapconcat #'(lambda (var) (car var))
                                                  my-mu4e-account-alist "/"))
                               (mapcar #'(lambda (var) (car var)) my-mu4e-account-alist)
                               nil t nil nil (caar my-mu4e-account-alist))))
           (account-vars (cdr (assoc account my-mu4e-account-alist))))
      (if account-vars
          (mapc #'(lambda (var)
                    (set (car var) (cadr var)))
                account-vars)
        (error "No email account found"))))

  (defun get-account-info (host &optional user)
    (let* ((tmp-auth-info
            (auth-source-search
             :max 100
             :host host
             :require '(:user :secret :host :port)
             :create nil))
           (auth-info
            (car (if user
                     (seq-filter '(lambda (x) (string-match-p user (plist-get x :user))) tmp-auth-info)
                   (tmp-auth-info))))
           (user (plist-get auth-info :user))
           (password (plist-get auth-info :secret))
           (host (plist-get auth-info :host))
           (port (plist-get auth-info :port)))
      (when (functionp password)
        (setq password (funcall password)))
      (plist-put auth-info :password password)
      auth-info)
    )

  ;; ask for account when composing mail
  (add-hook 'mu4e-compose-pre-hook 'my-mu4e-set-account)

  (setq mu4e-maildir "~/.mail")
  (setq mu4e-get-mail-command "offlineimap")
  (setq mu4e-sent-messages-behavior 'delete)
  (setq mu4e-show-images t)
  (setq mu4e-use-fancy-chars t)
  (setq mail-user-agent 'mu4e-user-agent)
  (setq mu4e-view-show-addresses t)
  (setq mu4e-user-mail-address-list
        (mapcar (lambda (account) (cadr (assq 'user-mail-address account)))
                my-mu4e-account-alist))

  (setq mu4e-maildir-shortcuts
        '(("/work/INBOX" . ?w)
          ("/push/Inbox" . ?p)
          ("/unified/Inbox" . ?u)
          ("/sudo/INBOX" . ?s)))

  (setq mu4e-contexts
        (mapcar (lambda (accout) (make-mu4e-context
                                  :name(car accout)
                                  :match-func `(lambda (msg)
                                                 (when msg (mu4e-message-contact-field-matches msg :to ,(cadr (assq 'user-mail-address accout)))))
                                  :vars `((mu43-sent-folder . ,(cadr (assq 'mu4e-sent-folder accout)))
                                          (mu43-drafts-folder . ,(cadr (assq 'mu4e-drafts-folder accout)))
                                          (mu43-trash-folder . ,(cadr (assq 'mu4e-trash-folder accout)))
                                          (mu43-refle-folder . ,(cadr (assq 'mu4e-refile-folder accout)))))) my-mu4e-account-alist))

  (setq mu4e-confirm-quit nil)
  (setq mu4e-compose-signature-auto-include nil)
  (setq mu4e-completing-read-function 'ivy-completing-read)

  ;; use imagemagick, if available
  (when (fboundp 'imagemagick-register-types)
    (imagemagick-register-types))

  (setq send-mail-function 'smtpmail-send-it)

  (setq mu4e-html2text-command "w3m -dump -cols 80 -T text/html")
  ;; spell check
  (add-hook 'mu4e-compose-mode-hook
            (defun my-do-compose-stuff ()
              "My settings for message composition."
              (set-fill-column 72)
              (flyspell-mode)))

  ;; add option to view html message in a browser
  ;; `aV` in view to activate
  (add-to-list 'mu4e-view-actions
               '("ViewInBrowser" . mu4e-action-view-in-browser) t)

  ;; fetch mail every 10 mins
  ;; (setq mu4e-update-interval 600)

  )

(use-package mu4e-maildirs-extension
  :after mu4e
  :config
  (mu4e-maildirs-extension))

(use-package mu4e-alert
  :after mu4e
  :init
  (setq mu4e-alert-interesting-mail-query
        (concat
         "flag:unread maildir:/sudo/INBOX "
         "OR "
         "flag:unread maildir:/push/INBOX"
         "OR "
         "flag:unread maildir:/unified/INBOX"
         ))
  ;; (mu4e-alert-enable-mode-line-display)
  (defun gjstein-refresh-mu4e-alert-mode-line ()
    (interactive)
    (mu4e~proc-kill)
    (mu4e-alert-enable-mode-line-display)
    )
  ;; (run-with-timer 0 60 'gjstein-refresh-mu4e-alert-mode-line)
  )

(use-package emacsql)

(use-package emacsql-sqlite)

(use-package emacsql-sqlite3)

(use-package emacsql-mysql)

(use-package emacsql-psql)

(use-package wallabag
  :straight (:host github :repo "chenyanming/wallabag.el" :files ("*.el" "*.alist" "*.css"))
  :config
  (setq wallabag-db-file (expand-file-name ".cache/wallabag.sqlite" my/emacs-d)))

(use-package elfeed
  :bind
  (:map elfeed-search-mode-map
        ("*" . my/elfeed-toggle-star)
        ("R" . my/elfeed-mark-above-as-read)
        ("B" . my/elfeed-open-with-eww))
  (:map elfeed-show-mode-map
        ("*" . my/elfeed-toggle-star)
        ("B" . my/elfeed-open-with-eww))
  :config
  (setq elfeed-use-curl t)
  (defun ap/elfeed-search-mark-group-as-read (predicate)
    "Mark all non-starred entries as read in the group at point, grouped by PREDICATE."
    (let* ((offset (- (line-number-at-pos) elfeed-search--offset))
           (current-entry (nth offset elfeed-search-entries))
           (value (funcall predicate current-entry))
           (entries (--filter (and (equal value (funcall predicate it))
                                   (not (member 'starred (elfeed-entry-tags it))))
                              elfeed-search-entries)))
      (elfeed-untag entries 'unread)
      (mapc #'elfeed-search-update-entry entries)))

  (defun ap/elfeed-search-mark-site-as-read ()
    "Mark all entries as read in the current site and day at point."
    (interactive)
    (ap/elfeed-search-mark-group-as-read (lambda (entry)
                                           (list (time-to-days (seconds-to-time (elfeed-entry-date entry)))
                                                 (pocket-reader--url-domain (elfeed-entry-link entry))))))
  (defun ap/elfeed-search-mark-day-as-read ()
    "Mark all entries as read in the day at point."
    (interactive)
    (ap/elfeed-search-mark-group-as-read (lambda (entry)
                                           (time-to-days (seconds-to-time (elfeed-entry-date entry))))))

  (defun my/elfeed-mark-above-as-read ()
    "Mark the feeds above point as read."
    (interactive)
    (save-excursion
      (set-mark-command nil)
      (goto-char (point-min))
      (elfeed-search-untag-all-unread)))

  (defun my/elfeed-mark-below-as-read ()
    "Mark the feeds above point as read."
    (interactive)
    (save-excursion
      (set-mark-command nil)
      (goto-char (point-max))
      (elfeed-search-untag-all-unread)))

  (defun my/elfeed-open-with (browse-function)
    "Open the current entry with `browse-function'."
    (let ((browse-url-browser-function browse-function))
      (if (eq browse-function 'eww-browse-url)
          (add-hook 'eww-after-render-hook 'eww-readable nil t))
      (cond ((eq major-mode 'elfeed-search-mode) (elfeed-search-browse-url))
            ((eq major-mode 'elfeed-show-mode) (elfeed-show-visit))
            (t (message "Not calling from elfeed")))))

  (defun my/elfeed-open-with-eww ()
    "Open the current entry with eww."
    (interactive)
    (my/elfeed-open-with 'eww-browse-url))

  (defun my/elfeed-toggle-tag (tag)
    "Toggle tag to all selected entries."
    (cond ((eq major-mode 'elfeed-search-mode) (elfeed-search-toggle-all tag))
          ((eq major-mode 'elfeed-show-mode) (if (elfeed-tagged-p tag elfeed-show-entry)
                                                 (elfeed-show-untag tag)
                                               (elfeed-show-tag tag)))
          (t (message "Not calling from elfeed"))))

  (defun my/elfeed-toggle-star ()
    "Toggle starred to all selected entries."
    (interactive)
    (my/elfeed-toggle-tag 'star))
  )

(use-package elfeed-protocol
  :after elfeed
  :init
  (elfeed-protocol-enable)
  :config
  (setq elfeed-curl-extra-arguments '("-c" "/tmp/newsblur-cookie"
                                      "-b" "/tmp/newsblur-cookie"))
  (setq elfeed-protocol-newsblur-maxpages 20)
  (setq elfeed-feeds (list
                      (let* ((file (expand-file-name "~/.config/elfeed-newsblur"))
                             (password-file (if (file-exists-p file)
                                                (list :password-file file)))
                             (password (unless (file-exists-p file)
                                         (list :password (my/secrets "newsblur" "password")))))
                        (append '("newsblur+https://vvv@newsblur.com") password-file password))))
  )

(use-package ledger-mode
  :init
  (use-package flycheck-ledger
    :after (flycheck ledger-mode)
    :init
    (require 'flycheck-ledger)
    )
  (setq ledger-highlight-xact-under-point nil
        ledger-use-iso-dates nil)

  :config
  (define-key ledger-mode-map (kbd "RET") 'newline)
  (define-key ledger-mode-map (kbd "C-o") 'open-line)

  (when (memq window-system '(mac ns))
    (exec-path-from-shell-copy-env "LEDGER_FILE"))

  :hook
  (ledger-mode . goto-address-prog-mode)
  )

(use-package gnuplot)
(use-package lua-mode)
(use-package htmlize)
(use-package dsvn)

(when my/is-mac
  )

(unless (eq system-type 'windows-nt)
  (use-package daemons))
(use-package dotenv-mode)

(use-package uptimes
  :init
  (setq-default uptimes-keep-count 200))


(require 'server)
(unless (server-running-p)
  (server-start))

(setq custom-file (expand-file-name "custom.el" my/emacs-d))
(when (file-exists-p custom-file)
  (load custom-file))

(use-package my/locales
  :ensure nil
  :straight nil
  :init
  (defun my/utf8-locale-p (v)
    "Return whether locale string V relates to a UTF-8 locale."
    (and v (string-match "UTF-8" v)))

  (defun my/locale-is-utf8-p ()
    "Return t iff the \"locale\" command or environment variables prefer UTF-8."
    (or (my/utf8-locale-p (and (executable-find "locale") (shell-command-to-string "locale")))
        (my/utf8-locale-p (getenv "LC_ALL"))
        (my/utf8-locale-p (getenv "LC_CTYPE"))
        (my/utf8-locale-p (getenv "LANG"))))

  (when (or window-system (my/locale-is-utf8-p))
    (set-language-environment 'utf-8)
    (setq locale-coding-system 'utf-8)
    (set-default-coding-systems 'utf-8)
    (set-terminal-coding-system 'utf-8)
    (set-selection-coding-system (if (eq system-type 'windows-nt) 'utf-16-le 'utf-8))
    (prefer-coding-system 'utf-8))

  (setq system-time-locale "en_US.UTF-8")
  )

(use-package my/appearance
  :ensure nil
  :straight nil
  :hook
  (after-init . reapply-themes)
  :init
  (global-visual-line-mode 1)
  (defun reapply-themes ()
    "Forcibly load the themes listed in `custom-enabled-themes'."
    (dolist (theme custom-enabled-themes)
      (unless (custom-theme-p theme)
        (load-theme theme t)))
    (custom-set-variables `(custom-enabled-themes (quote ,custom-enabled-themes))))

  (use-package prettify-symbols
    :ensure nil
    :straight nil
    :when (fboundp 'global-prettify-symbols-mode)
    :hook
    (after-init . global-prettify-symbols-mode))

  (use-package default-text-scale
    :hook
    (after-init . default-text-scale-mode)
    )

  (use-package visual-fill-column)

  (use-package dimmer
    :hook
    (after-init . dimmer-mode)
    :custom
    (dimmer-fraction 0.15)
    )
  (set-face-attribute 'default nil :foreground "white" :background "black")
  (setq use-file-dialog nil)
  (setq use-dialog-box nil)
  (setq inhibit-startup-screen t)
  (tool-bar-mode -1)
  (when (fboundp 'set-scroll-bar-mode)
    (if (fboundp 'exordium-scroll-bar)
        (set-scroll-bar-mode 'right)
      (set-scroll-bar-mode nil)))
  (menu-bar-mode -1)
  (pixel-scroll-mode 1)
  (setq frame-title-format
        '((:eval (if (buffer-file-name)
                     (abbreviate-file-name (buffer-file-name))
                   "%b"))))
  (let ((no-border '(internal-border-width . 0)))
    (add-to-list 'default-frame-alist no-border)
    (add-to-list 'initial-frame-alist no-border))
  (defun my/adjust-opacity (frame incr)
    "Adjust the background opacity of FRAME by increment INCR."
    (unless (display-graphic-p frame)
      (error "Cannot adjust opacity of this frame"))
    (let* ((oldalpha (or (frame-parameter frame 'alpha) 100))
           ;; The 'alpha frame param became a pair at some point in
           ;; emacs 24.x, e.g. (100 100)
           (oldalpha (if (listp oldalpha) (car oldalpha) oldalpha))
           (newalpha (+ incr oldalpha)))
      (when (and (<= frame-alpha-lower-limit newalpha) (>= 100 newalpha))
        (modify-frame-parameters frame (list (cons 'alpha newalpha))))))
  (global-set-key (kbd "M-C-8") (lambda () (interactive) (my/adjust-opacity nil -2)))
  (global-set-key (kbd "M-C-9") (lambda () (interactive) (my/adjust-opacity nil 2)))
  (global-set-key (kbd "M-C-7") (lambda () (interactive) (modify-frame-parameters nil `((alpha . 100)))))

  (use-package my/frame-hooks
    :ensure nil
    :straight nil
    :init
    (defvar after-make-console-frame-hook '()
      "Hooks to run after creating a new TTY frame")
    (defvar after-make-window-system-frame-hook '()
      "Hooks to run after creating a new window-system frame")

    (defun run-after-make-frame-hooks (frame)
      "Run configured hooks in response to the newly-created FRAME.
Selectively runs either `after-make-console-frame-hooks' or
`after-make-window-system-frame-hooks'"
      (with-selected-frame frame
        (run-hooks (if window-system
                       'after-make-window-system-frame-hook
                     'after-make-console-frame-hook))))

    (add-hook 'after-make-frame-functions 'run-after-make-frame-hooks)

    (global-set-key [mouse-4] (lambda () (interactive) (scroll-down 1)))
    (global-set-key [mouse-5] (lambda () (interactive) (scroll-up 1)))

    (autoload 'mwheel-install "mwheel")

    (defun my/console-frame-setup ()
      (xterm-mouse-mode 1) ; Mouse in a terminal (Use shift to paste with middle button)
      (mwheel-install))

    (defun my/window-system-frame-setup ()
      (modify-frame-parameters nil (list (cons 'alpha 80))))

    :hook
    (after-make-console-frame . my/console-frame-setup)
    (after-make-window-system-frame . my/window-system-frame-setup)
    (after-init . (lambda () (when my/initial-frame
                               (run-after-make-frame-hooks my/initial-frame))))
    )
  )

(use-package theme-looper)

(use-package format-all
  ;; For some unfathomable reason, this hangs tramp.
  ;; :hook
  ;; (first-change . my/format-all-mode)
  :commands my/format-all-mode my/toggle-format-project-files format-all-buffer format-all-mode
  :init
  (setq format-all-formatters
        '(("Nix" nixpkgs-fmt)))
  :config
  (defvar my/just-format-it-root-marker ".just_format_it")

  (defun my/toggle-format-project-files ()
    "Toggle format all buffers under projectile root"
    (interactive)
    (let ((file (expand-file-name my/just-format-it-root-marker (projectile-project-root))))
      (if (f-exists? file)
          (delete-file file)
        (write-region "" nil file))))

  (defun my/format-all-mode ()
    "Format buffer when `my/just-format-it-root-marker' exists in project root"
    (interactive)
    (if (f-exists? (expand-file-name my/just-format-it-root-marker (projectile-project-root)))
        (format-all-mode 1)
      (format-all-mode -1))))

(use-package my/convenient-functions
  :ensure nil
  :straight nil
  :init
  ;;----------------------------------------------------------------------------
  ;; Delete the current file
  ;;----------------------------------------------------------------------------
  (defun delete-this-file ()
    "Delete the current file, and kill the buffer."
    (interactive)
    (unless (buffer-file-name)
      (error "No file is currently being edited"))
    (when (yes-or-no-p (format "Really delete '%s'?"
                               (file-name-nondirectory buffer-file-name)))
      (delete-file (buffer-file-name))
      (kill-this-buffer)))


  ;;----------------------------------------------------------------------------
  ;; Rename the current file
  ;;----------------------------------------------------------------------------
  ;; Originally from stevey, adapted to support moving to a new directory.
  (defun rename-file-and-buffer (new-name)
    "Renames both current buffer and file it's visiting to NEW-NAME."
    (interactive
     (progn
       (if (not (buffer-file-name))
           (error "Buffer '%s' is not visiting a file!" (buffer-name)))
       ;; Disable ido auto merge since it too frequently jumps back to the original
       ;; file name if you pause while typing. Reenable with C-z C-z in the prompt.
       (let ((ido-auto-merge-work-directories-length -1))
         (list (read-file-name (format "Rename %s to: " (file-name-nondirectory
                                                         (buffer-file-name))))))))
    (if (equal new-name "")
        (error "Aborted rename"))
    (setq new-name (if (file-directory-p new-name)
                       (expand-file-name (file-name-nondirectory
                                          (buffer-file-name))
                                         new-name)
                     (expand-file-name new-name)))
    ;; Only rename if the file was saved before. Update the
    ;; buffer name and visited file in all cases.
    (if (file-exists-p (buffer-file-name))
        (rename-file (buffer-file-name) new-name 1))
    (let ((was-modified (buffer-modified-p)))
      ;; This also renames the buffer, and works with uniquify
      (set-visited-file-name new-name)
      (if was-modified
          (save-buffer)
        ;; Clear buffer-modified flag caused by set-visited-file-name
        (set-buffer-modified-p nil)))

    (setq default-directory (file-name-directory new-name))

    (message "Renamed to %s." new-name))

  ;;----------------------------------------------------------------------------
  ;; Browse current HTML file
  ;;----------------------------------------------------------------------------
  (defun browse-current-file ()
    "Open the current file as a URL using `browse-url'."
    (interactive)
    (let ((file-name (buffer-file-name)))
      (if (and (fboundp 'tramp-tramp-file-p)
               (tramp-tramp-file-p file-name))
          (error "Cannot open tramp file")
        (browse-url (concat "file://" file-name)))))

  (defun my-toggle-var (var)
    "..."
    (interactive
     (let* ((def  (variable-at-point))
            (def  (and def
                       (not (numberp def))
                       (memq (symbol-value def) '(nil t))
                       (symbol-name def))))
       (list
        (completing-read
         "Toggle value of variable: "
         obarray (lambda (c)
                   (unless (symbolp c) (setq c  (intern c)))
                   (and (boundp c)  (memq (symbol-value c) '(nil t))))
         'must-confirm nil 'variable-name-history def))))
    (let ((sym  (intern var)))
      (set sym (not (symbol-value sym)))
      (message "`%s' is now `%s'" var (symbol-value sym))))

  (defmacro my-save-excursion (&rest forms)
    (let ((old-point (gensym "old-point"))
          (old-buff (gensym "old-buff")))
      `(let ((,old-point (point))
             (,old-buff (current-buffer)))
         (prog1
             (progn ,@forms)
           (unless (eq (current-buffer) ,old-buff)
             (switch-to-buffer ,old-buff))
           (goto-char ,old-point)))))

  ;; https://emacs.stackexchange.com/questions/80/how-can-i-quickly-toggle-between-a-file-and-a-scratch-buffer-having-the-same-m
  (defun modi/switch-to-scratch-and-back (&optional arg)
    "Toggle between *scratch-MODE* buffer and the current buffer.
If a scratch buffer does not exist, create it with the major mode set to that
of the buffer from where this function is called.

        COMMAND -> Open/switch to a scratch buffer in the current buffer's major mode
    C-0 COMMAND -> Open/switch to a scratch buffer in `fundamental-mode'
    C-u COMMAND -> Open/switch to a scratch buffer in `org-mode'
C-u C-u COMMAND -> Open/switch to a scratch buffer in `emacs-elisp-mode'

Even if the current major mode is a read-only mode (derived from `special-mode'
or `dired-mode'), we would want to be able to write in the scratch buffer. So
the scratch major mode is set to `org-mode' for such cases.

Return the scratch buffer opened."
    (interactive "p")
    (if (and (or (null arg)               ; no prefix
                 (= arg 1))
             (string-match-p "\\*scratch" (buffer-name)))
        (switch-to-buffer (other-buffer))
      (let* ((mode-str (cl-case arg
                         (0  "fundamental-mode") ; C-0
                         (4  "org-mode") ; C-u
                         (16 "emacs-lisp-mode") ; C-u C-u
                         ;; If the major mode turns out to be a `special-mode'
                         ;; derived mode, a read-only mode like `help-mode', open
                         ;; an `org-mode' scratch buffer instead.
                         (t (if (or (derived-mode-p 'special-mode) ; no prefix
                                    (derived-mode-p 'dired-mode))
                                "org-mode"
                              (format "%s" major-mode)))))
             (buf (get-buffer-create (concat "*scratch-" mode-str "*"))))
        (switch-to-buffer buf)
        (funcall (intern mode-str))   ; http://stackoverflow.com/a/7539787/1219634
        buf)))

  (defun switch-to-scratch-and-back ()
    "Toggle between *scratch* buffer and the current buffer.
     If the *scratch* buffer does not exist, create it."
    (interactive)
    (let ((scratch-buffer-name (get-buffer-create "*scratch*")))
      (if (equal (current-buffer) scratch-buffer-name)
          (switch-to-buffer (other-buffer))
        (switch-to-buffer scratch-buffer-name (lisp-interaction-mode)))))

  (defun copy-file-name-to-clipboard ()
    "Copy the current buffer file name to the clipboard."
    (interactive)
    (let ((filename (if (equal major-mode 'dired-mode)
                        default-directory
                      (buffer-file-name))))
      (when filename
        (kill-new filename)
        (message "Copied buffer file name '%s' to the clipboard." filename))))
  )

(use-package my/mac
  :ensure nil
  :straight nil
  :when (eq system-type 'darwin)
  :init
  (use-package osx-location)
  (use-package dash-at-point
    :bind ("C-c D" . dash-at-point))
  (define-key org-mode-map (kbd "M-h") nil)
  (define-key org-mode-map (kbd "C-c g") 'org-mac-grab-link)
  ;; Show iCal calendars in the org agenda
  (when (require 'org-mac-iCal nil t)
    (setq org-agenda-include-diary t
          org-agenda-custom-commands
          '(("I" "Import diary from iCal" agenda ""
             ((org-agenda-mode-hook #'org-mac-iCal)))))

    (add-hook 'org-agenda-cleanup-fancy-diary-hook
              (lambda ()
                (goto-char (point-min))
                (save-excursion
                  (while (re-search-forward "^[a-z]" nil t)
                    (goto-char (match-beginning 0))
                    (insert "0:00-24:00 ")))
                (while (re-search-forward "^ [a-z]" nil t)
                  (goto-char (match-beginning 0))
                  (save-excursion
                    (re-search-backward "^[0-9]+:[0-9]+-[0-9]+:[0-9]+ " nil t))
                  (insert (match-string 0))))))

  (setq-default locate-command "mdfind")
  (use-package grab-mac-link)
  (setq mac-command-modifier 'meta)
  (setq mac-option-modifier 'none)
  ;; Make mouse wheel / trackpad scrolling less jerky
  (setq mouse-wheel-scroll-amount '(1
                                    ((shift) . 5)
                                    ((control))))
  (dolist (multiple '("" "double-" "triple-"))
    (dolist (direction '("right" "left"))
      (global-set-key (read-kbd-macro (concat "<" multiple "wheel-" direction ">")) 'ignore)))
  (global-set-key (kbd "M-`") 'ns-next-frame)
  (global-set-key (kbd "M-h") 'ns-do-hide-emacs)
  (global-set-key (kbd "M-˙") 'ns-do-hide-others)
  (with-eval-after-load 'nxml-mode
    (define-key nxml-mode-map (kbd "M-h") nil))
  (global-set-key (kbd "M-ˍ") 'ns-do-hide-others) ;; what describe-key reports for cmd-option-h
  (add-hook 'after-make-frame-functions
            (lambda (frame)
              (set-frame-parameter frame 'menu-bar-lines
                                   (if (display-graphic-p frame)
                                       1 0))))
  (when (file-directory-p "/Applications/org-clock-statusbar.app")
    (add-hook 'org-clock-in-hook
              (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                       (concat "tell application \"org-clock-statusbar\" to clock in \"" org-clock-current-task "\""))))
    (add-hook 'org-clock-out-hook
              (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                       "tell application \"org-clock-statusbar\" to clock out"))))
  )
