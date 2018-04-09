;;; calibre.el --- Package for working with calibre library -*- lexical-binding: t; -*-

;; Copyright (c) 2018 Abhinav Tushar

;; Author: Abhinav Tushar <lepisma@fastmail.com>
;; Version: 0.0.1
;; Package-Requires: ((emacs "25") (dash "2.13.0") (dash-functional "2.13.0") (f "0.20.0") (s "1.12.0") (helm "2.9.2"))
;; URL: https://github.com/lepisma/calibre.el

;;; Commentary:

;; Package for working with calibre library
;; This file is not a part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'helm)
(require 's)
(require 'f)
(require 'dash)
(require 'dash-functional)

(defgroup calibre nil
  "Calibre")

(defcustom calibre-root nil
  "Path to calibre root directory"
  :type 'directory
  :group 'calibre)

(defcustom calibre-db nil
  "Path to calibre database. Defaults to calibre-root/metadata.db"
  :type '(file :must-match t)
  :group 'calibre)

(defcustom calibre-ext-preference '("pdf" "cbr" "cbz" "djvu" "epub" "azw3" "mobi")
  "Preference order for book formats"
  :group 'calibre)

(defcustom calibre-open-fn (lambda (ext) (if (string-equal "mobi" ext) "xdg-open" "okular"))
  "Function that takes an extension and provides command to open that"
  :group 'calibre)

(defun calibre-get-db-path ()
  (or calibre-db (f-join calibre-root "metadata.db")))

(defun calibre-get-sql-stmt (query)
  "Return sql statement for the given query."
  (s-concat "SELECT title, author_sort, path FROM books "
            (format "WHERE lower(title || ' ' || author_sort) like '%%' || lower('%s') || '%%'" query)))

(defun calibre-search-in-calibre (query)
  "Search for items in calibre library."
  (let* ((calibre-db (calibre-get-db-path))
         (search-result (->> (shell-command-to-string (format "sqlite3 %s %s"
                                                            (shell-quote-argument calibre-db)
                                                            (shell-quote-argument (calibre-get-sql-stmt query))))
                           (s-trim)
                           (s-split "\n")
                           (-map (-cut s-split "|" <>))
                           (-remove (lambda (item) (string-equal (car item) ""))))))
    search-result))

(defun calibre-get-book-extension (book-path ext)
  "Return file path for given format. NIL if not found."
  (car (f-glob (format "*.%s" ext) book-path)))

(defun calibre-open-preferred-format (book-path &optional ext-list)
  "Loop over ext-list to open the book."
  (if ext-list
      (let ((file-path (calibre-get-book-extension book-path (car ext-list))))
        (if file-path
            (let ((calibre-opener (funcall calibre-open-fn (car ext-list))))
              (start-process calibre-opener nil calibre-opener file-path))
          (calibre-open-preferred-format book-path (cdr ext-list))))
    (message "No suitable book format found.")))

(defun calibre-open-book (book-item)
  "Open book represented in book-item using xdg-open."
  (let ((book-path (f-join calibre-root (third book-item))))
    (calibre-open-preferred-format book-path calibre-ext-preference)))

;;;###autoload
(defun calibre-open (&optional search-term)
  (interactive)
  (let* ((books (calibre-search-in-calibre (or search-term "")))
         (total-items (length books)))
    (cond ((= total-items 0) (message "No results"))
          ((= total-items 1) (calibre-open-book (car books)))
          (t (helm :sources (helm-build-sync-source "search results"
                              :candidates (-map (lambda (book)
                                                  (cons (format "%s\n%s" (car book) (second book)) book))
                                                books)
                              :action 'calibre-open-book
                              :multiline t)
                   :buffer "*helm calibre open*")))))

(provide 'calibre)

;;; calibre.el ends here
