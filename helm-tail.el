;;; helm-tail.el --- Read recent output from various sources -*- lexical-binding: t -*-

;; Copyright (C) 2018 by Akira Komamura

;; Author: Akira Komamura <akira.komamura@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1") (helm "2.7.0"))
;; URL: https://github.com/akirak/helm-tail

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; `helm-tail' command displays contents of some special buffers.
;; Use C-c TAB or C-c C-y to insert/store a selection.

;;; Code:

(require 'helm)
;; For helm-source-kill-ring
;; (require 'helm-ring)

;;;; Variables

;; TODO: Limit the number of candidates in helm-source-kill-ring
(defvar helm-tail-sources
  '(helm-tail-source-backtrace
    helm-tail-source-warnings
    helm-tail-source-messages
    ;; helm-source-kill-ring
    ))

;;;;; Custom variables
(defcustom helm-tail-default-lines 5)

(defcustom helm-tail-messages-lines 5
  "Number of lines from *Messages*."
  :type 'number
  :group 'helm-tail)

;;;;; Sources

(defvar helm-tail-source-messages
  (helm-build-sync-source "Messages"
    :candidates
    (lambda () (helm-tail--buffer-tail "*Messages*" helm-tail-messages-lines))))

(defvar helm-tail-source-warnings
  (helm-build-sync-source "Warnings"
    :candidates
    (lambda () (helm-tail--buffer-tail "*Warnings*"))))

(defvar helm-tail-source-backtrace
  (helm-build-sync-source "Backtrace"
    :candidates
    (lambda () (helm-tail--buffer-contents "*Backtrace*"))))

;;;; Utility functions
(defmacro helm-tail--when-buffer (bufname &rest progn)
  (declare (indent 1))
  `(when-let ((buf (get-buffer ,bufname)))
     (with-current-buffer buf
       ,@progn)))

(defun helm-tail--buffer-contents (bufname)
  (helm-tail--when-buffer bufname
    (list (buffer-string))))

(defun helm-tail--buffer-contents-as-lines (bufname)
  (helm-tail--when-buffer bufname
    (split-string (buffer-string)
                  "\n")))

(defun helm-tail--buffer-tail (bufname &optional nlines)
  (helm-tail--when-buffer bufname
    (nreverse
     (split-string (save-excursion
                     (buffer-substring (goto-char (point-max))
                                       (progn (beginning-of-line
                                               (- (or nlines
                                                      helm-tail-default-lines)))
                                              (point))))
                   "\n"))))

;;;; Command

;;;###autoload
(defun helm-tail ()
  (interactive)
  (helm :sources helm-tail-sources
        :buffer "*helm tail*"))

(provide 'helm-tail)
;;; helm-tail.el ends here
