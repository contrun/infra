;; -*- coding: utf-8; no-byte-compile: t; lexical-binding: t -*-
;;; This init file only loads config.el in its parent directory
;;; or the EMACS_CONFIG file from environment variable.

;;* Base directory
(defconst my/home
  ;;; User's HOME directory
  (expand-file-name "~/"))

(defconst my/emacs-d
  ;;; Customized `user-emacs-directory', used for several separate configurations.
  (if (boundp 'my/emacs-d) ;; Make defining `my/emacs-d' nilpotent
      my/emacs-d
    (let ((parent (file-name-directory
                   (file-chase-links load-file-name))))
      (if (string= parent my/home)
          (expand-file-name "~/.emacs.d/")
        parent))))

(defvar my/config-location
  ;;; Set config location to be environment variable `EMACS_CONFIG' or `config.el' under `my/emacs-d'
  (let ((config (getenv "EMACS_CONFIG")))
    (if config
        config
      (expand-file-name "config.el" my/emacs-d))))

(defun my/try-load-config ()
  "Try to load `my/config-location'"
  (interactive)
  (if (file-exists-p my/config-location)
      (load-file my/config-location)
    (message "Config file %s does not exist" my/config-location)))

(defun my/is-file-more-up-to-date (file1 file2)
  "Returns true if `file1' is more up to date than `file2'"
  (time-less-p (nth 5 (file-attributes file2)) (nth 5 (file-attributes file1))))

(defun my/load-compiled-or-compile (config-file)
  "Try to load compiled `config-file' or compile and load `config-file'"
  (let* ((compiled-config-file (concat config-file "c"))
         (file (if (and (file-exists-p compiled-config-file) (my/is-file-more-up-to-date compiled-config-file config-file))
                   compiled-config-file
                 config-file)))
    (message "Loading config %s" file)
    (load-file file)))

(my/try-load-config)
