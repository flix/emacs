;;; flix-mode.el --- Major mode for the Flix programming language -*- lexical-binding: t; -*-

;;; Copyright (C) 2025 Matthias Varberg Ingesman
;;; SPDX-License-Identifier: Apache-2.0

;;; Author: Matthias Varberg Ingesman <matthias@ingesman.dk>
;;; Created: 23. Feb 2025
;;; URL: https://github.com/flix/emacs

;;; Package-Requires: ((emacs "29.0"))

;;; Version: 1.0.1

;;; Commentary:
;; This package adds a major mode for the Flix programming language. It relies on an LSP server to
;; provide all functionality, including syntax highlighting.

;;; Code:

(require 'toml)

(defgroup flix-mode nil
  "Flix mode settings."
  :group 'external
  :tag "flix-mode"
  :prefix "flix-mode-")

(defcustom flix-mode-project-file "flix.toml"
  "The Flix project definition file."
  :type 'string
  :group 'flix-mode-mode)

(defcustom flix-mode-jar-name "flix.jar"
  "Name of the downloaded Flix jar files."
  :type 'string
  :group 'flix-mode-mode)

(defcustom flix-mode-releases-url "https://github.com/flix/flix/releases/download/"
  "Where Flix releases are made available for download."
  :type 'string
  :group 'flix-mode-mode)

(defcustom flix-mode-download-dir (expand-file-name "flix" user-emacs-directory)
  "Where Flix releases are downloaded to."
  :type 'string
  :group 'flix-mode-mode)


(defun flix-mode--download-file (src-url dest-path)
  (let* ((dest-dir (file-name-directory dest-path)))
    (unless (file-exists-p dest-dir)
      (make-directory dest-dir t))
    (message "Downloading %s to %s, please wait..." src-url dest-path)
    (url-copy-file src-url dest-path)))

(defun flix-mode--project-file ()
  (let* ((root-path (project-root (project-current))))
    (expand-file-name flix-mode-project-file root-path)))

(defun flix-mode--project-flix-version (project-toml-path)
  "Get the Flix version number from flix.toml, defaulting to latest."
  (let* ((project-props (toml:read-from-file project-toml-path))
         (package-alist (cdr (assoc "package" project-props)))
         (flix-version (cdr (assoc "flix" package-alist))))
    (if flix-version
        (concat "v" flix-version)
      "latest")))

(defun flix-mode--flix-jar-path (install-dir flix-version)
  "Path to Flix jar file for version."
  (expand-file-name flix-mode-jar-name (expand-file-name flix-version install-dir)))

(defun flix-mode--detect-lsp-server (install-dir flix-version)
  "Check if Flix version is already present in install dir."
  (file-exists-p (flix-mode--flix-jar-path install-dir flix-version)))

(defun flix-mode--install-lsp-server (install-dir flix-version)
  "Install the Flix LSP server.

INSTALL-DIR is the destination for the installation."
  (let* ((destination-dir (expand-file-name install-dir))
         (destination-path (flix-mode--flix-jar-path destination-dir flix-version)))
    (when (yes-or-no-p (concat "Download Flix jar " flix-version " to " destination-path "?"))
      (flix-mode--download-file
       (concat flix-mode-releases-url flix-version "/" flix-mode-jar-name)
       destination-path))))

;;;###autoload
(defun flix-mode-ensure ()
  "Install the LSP server if needed."
  (unless (flix-mode--project-file)
    (throw 'flix-mode-no-project (list (format "Expected a %s file in project root but found none." flix-mode-project-file))))
  (let* ((flix-version (flix-mode--project-flix-version (flix-mode--project-file)))
         (install-dir flix-mode-download-dir))
    (unless (flix-mode--detect-lsp-server install-dir flix-version)
      (flix-mode--install-lsp-server install-dir flix-version))))

;;;###autoload
(defun flix-mode-server-path (i)
  "Function for eglot to determine a suitable Flix LSP. Requires a current project with a Flix project config file.

The argument is intentionally ignored."
  (let* ((project-flix-version (flix-mode--project-flix-version (flix-mode--project-file)))
         (jar-path (flix-mode--flix-jar-path flix-mode-download-dir project-flix-version)))
    (list "java" "-jar" jar-path "lsp")))

;;;###autoload
(define-derived-mode flix-mode prog-mode "Flix"
  "Major mode for the Flix programming language.")

(add-to-list 'auto-mode-alist '("\\.flix\\'" . flix-mode))

(provide 'flix-mode)
