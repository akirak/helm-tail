;;; helm-tail.el --- Read recent output from various sources -*- lexical-binding: t -*-

;; Copyright (C) 2018 by Akira Komamura

;; Author: Akira Komamura <akira.komamura@gmail.com>
;; Version: 0.2-pre
;; Package-Requires: ((emacs "25.1") (helm "2.7.0"))
;; Keywords: maint tools
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
;; Use C-c TAB or C-c C-k to insert/store a selection.

;;; Code:

(require 'pcase)
(require 'cl-lib)
(require 'helm-source)

(defvar helm-map)

(defgroup helm-tail nil
  "Helm for browsing contents of message buffers."
  :group 'tools
  :group 'maint
  :group 'helm)

(defcustom helm-tail-actions
  ;; TODO: Add org-capture action
  ;; TODO: Add web search action
  `(("Visit" . helm-tail-visit-action)
    ("Copy" . helm-tail-copy-action))
  "Alist of actions in the Helm sources."
  :type 'alist)

(defface helm-tail-highlight '((t :inherit highlight))
  "Face for highlighting a line."
  :group 'helm-tail)

(defcustom helm-tail-source-alist
  '(("*Flycheck errors*")
    ("*Backtrace*")
    ("*compilation*" :lines 2)
    ("*Compile-Log*")
    ("*Warnings*")
    ("*Messages*"))
  "Alist of buffers to display in `helm-tail'."
  :type '(alist)
  :group 'helm-tail)

;; TODO: Add a keymap
(defvar helm-tail-map
  (let ((m (make-composed-keymap nil helm-map)))
    (define-key m (kbd "C-c C-d") #'helm-tail-kill-source-buffer)
    m))

;; TODO: Add a command to kill the original buffer of the helm source

(defclass helm-tail-class (helm-source-sync)
  ((lines :initarg :lines
          :type number
          :custom 'number
          :initform 8
          :documentation "Number of lines displayed in Helm.")
   (buffer :initarg :buffer
           :type (or string buffer)
           :custom 'string
           :documentation "Name of the buffer.")
   (keymap :initform helm-tail-map)
   (candidates :initform #'helm-tail-candidates)
   (action :initform helm-tail-actions)))

(cl-defun helm-tail-candidates (&optional (buffer (helm-attr 'buffer))
                                          (lines (helm-attr 'lines)))
  "Generate candidates for the class."
  (let ((target-buffer (cl-etypecase buffer
                         (string (get-buffer buffer))
                         (buffer buffer))))
    (when (and target-buffer (buffer-live-p target-buffer))
      (pcase-let ((`(,beg . ,str)
                   (with-current-buffer target-buffer
                     (save-excursion
                       (save-restriction
                         (widen)
                         (goto-char (point-max))
                         (beginning-of-line (- lines))
                         (cons (point) (buffer-substring (point) (point-max))))))))
        (cl-loop for line in (cl-remove-if #'string-empty-p (split-string str "\n" nil))
                 with point = beg
                 with result = nil
                 collect (list line
                               :point point
                               :buffer target-buffer
                               :content (substring-no-properties line))
                 into result
                 do (cl-incf point (length line))
                 finally return (nreverse result))))))

(defvar helm-tail-display-window nil)

(defun helm-tail-visit-action (plist)
  "Visit an item according to PLIST."
  (let* ((point (plist-get plist :point))
         (buffer (plist-get plist :buffer))
         (window (setq helm-tail-display-window
                       (or (get-buffer-window buffer)
                           helm-tail-display-window
                           (get-buffer-window helm-current-buffer)))))
    (set-window-buffer window buffer)
    (with-selected-window window
      (remove-overlays (point-min) (point-max) 'helm-tail-highlight t)
      (mapc (lambda (selection-plist)
              (goto-char (plist-get selection-plist :point))
              (let ((ol (make-overlay (line-beginning-position)
                                      (min (point-max) (1+ (line-end-position))))))
                (overlay-put ol 'helm-tail-highlight t)
                (overlay-put ol 'face 'helm-tail-highlight)))
            (helm-marked-candidates))
      (goto-char point)
      (push-mark)
      (recenter))))

(defun helm-tail-copy-action (_)
  "Copy the text of marked candidates."
  (kill-new (mapconcat (lambda (plist) (plist-get plist :content))
                       (nreverse (helm-marked-candidates))
                       "\n")))

(defun helm-tail-kill-source-buffer ()
  "Kill the source buffer of the current candidate."
  (interactive)
  (let* ((buffer (alist-get 'buffer (helm-get-current-source)))
         (buffer-name (cl-etypecase buffer
                        (string buffer)
                        (buffer (buffer-name buffer)))))
    (when (yes-or-no-p (format "Kill buffer %s?" buffer-name))
      (kill-buffer buffer)
      (helm-refresh))))

(defun helm-tail-source-alist ()
  "Return live, non-empty buffer entries in `helm-tail-source-alist'."
  (cl-remove-if-not (lambda (cell)
                      (let ((buffer (get-buffer (car cell))))
                        (and buffer
                             (buffer-live-p buffer)
                             (> (buffer-size buffer) 0))))
                    helm-tail-source-alist))

(defun helm-tail-build-sources (source-alist)
  "Build helm sources from a result of `helm-tail-source-alist'.

SOURCE-ALIST is the result of the function."
  (mapcar (pcase-lambda (`(,buffer . ,plist))
            (apply #'helm-make-source
                   (cl-etypecase buffer
                     (string buffer)
                     (buffer (buffer-name buffer)))
                   'helm-tail-class
                   :buffer buffer
                   plist))
          source-alist))

;;;###autoload
(defun helm-tail ()
  "Display recent output of common special buffers."
  (interactive)
  (setq helm-tail-display-window nil)
  (let* ((source-alist (helm-tail-source-alist))
         (prompt (format "%s: " (string-join (mapcar #'car source-alist)
                                             ", ")))
         (sources (helm-tail-build-sources source-alist)))
    (helm :prompt prompt
          :sources sources
          :buffer "*helm tail*")))

(provide 'helm-tail)
;;; helm-tail.el ends here
