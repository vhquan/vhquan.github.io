(require 'ox-publish)
(require 'cl)
(require 'ox-latex)
(require 'seq)
(require 'subr-x)

(setq sfoj-project-dir "~/vhquan.github.io/")
(setq sfoj-org-dir (concat sfoj-project-dir "org/"))
(setq sfoj-www-dir (concat sfoj-project-dir "html/"))
(setq sfoj-blog-org-dir (concat sfoj-org-dir "posts/"))
(setq sfoj-blog-www-dir (concat sfoj-www-dir "posts/"))
(setq sfoj-header-file
      (concat sfoj-project-dir "org/header.html"))
(setq sfoj-posts-per-page 12)

(setq sfoj-head
      (concat
       "<meta name=\"twitter:site\" content=\"@null\" />\n"
       "<meta name=\"twitter:creator\" content=\"@null\" />\n"
       "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n"
       "<link rel=\"icon\" type=\"image/png\" href=\"https://vhquan.github.io/.images/icon/favicon-32x32.png\" />\n"
       "<link rel=\"apple-touch-icon-precomposed\" href=\"https://vhquan.github.io/.images/icon/apple-touch-icon.png\" />\n"
       "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://vhquan.github.io/.css/font.css\">\n"
       "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://vhquan.github.io/.css/main.css\">\n"))

(setq sfoj-footer
      (concat
       "<div id=\"footer\">\n"
       "<p>Proudly with "
       "<a href=\"https://www.gnu.org/software/emacs/\">Emacs</a> and "
       "<a href=\"https://orgmode.org/\">Org Mode</a>."
       "</div>"))

(defun sfoj-publish-local ()
  "Publish my website, but do not push to the server."
  (interactive)
  (remove-hook 'find-file-hooks 'vc-find-file-hook)
  (magit-file-mode -1)
  (global-git-gutter-mode -1)
  (org-publish-all)
  (global-git-gutter-mode +1)
  (magit-file-mode +1)
  (add-hook 'find-file-hooks 'vc-find-file-hook))

(defun sfoj-rsync-www ()
  "Rsync my working directory to my public web directory."
  (interactive)
  (let ((publish-dir sfoj-www-dir)
        (remote-dir "neon.vhquan.github.io:/var/www/sfoj/"))
    (when (file-exists-p publish-dir)
      (shell-command
       (format
        "rsync -avz --delete --delete-after %s %s"
        publish-dir
        remote-dir)))))

(defun sfoj-publish-full ()
  "Publish my website."
  (interactive)
  (sfoj-publish-local)
  (sfoj-rsync-www))

(defun sfoj--get-preview (filename)
  "Get a preview string for a file.
This function returns a list, '(<needs-more> <preview-string>),
where <needs-more> is nil or non-nil, and indicates whether
a \"Read More →\" link is needed.

FILENAME The file to get a preview for."
  (with-temp-buffer
    (insert-file-contents (concat sfoj-blog-org-dir filename))
    (goto-char (point-min))
    (let ((content-start (or
                          ;; Look for the first non-keyword line
                          (and (re-search-forward "^[^#]" nil t)
                               (match-beginning 0))
                          ;; Failing that, assume we're malformed and
                          ;; have no content
                          (buffer-size)))
          (marker (or
                   (and (re-search-forward "^#\\+BEGIN_more$" nil t)
                        (match-beginning 0))
                   (buffer-size))))
      ;; Return a pair of '(needs-more preview-string)
      (list (not (= marker (buffer-size)))
            (buffer-substring content-start marker)))))

(defun sfoj--header (_)
  "Insert the header of the page."
  (with-temp-buffer
    (insert-file-contents sfoj-header-file)
    (buffer-string)))

(defun sfoj--sitemap-for-group (title previous-page next-page list)
  "Generate the sitemap for one group of pages.

TITLE  The title of the page
PREVIOUS-PAGE  The previous index page to link to.
NEXT-PAGE  The next index page to link to.
LIST  The group of pages."
  (let ((previous-link (if previous-page
                           (format "[[%s][← Previous Page]]" previous-page)
                         ""))
        (next-link (if next-page
                       (format "[[%s][Next Page →]]" next-page)
                     "")))
    (concat "#+TITLE: " title "\n\n"
            "#+BEGIN_pagination\n"
            (format "- %s\n" previous-link)
            (format "- %s\n" next-link)
            "#+END_pagination\n\n"
            (string-join (mapcar #'car (cdr list)) "\n\n"))))

(defun sfoj--sitemap-entry (entry project)
  "Sitemap (Blog Main Page) Entry Formatter.

ENTRY  The sitemap entry to format.
PROJECT  The project structure."
  (when (not (directory-name-p entry))
    (format (string-join
             '("* [[file:%s][%s]]\n"
               "  :PROPERTIES:\n"
               "  :PUBDATE: %s\n"
               "  :END:\n"
               "#+BEGIN_published\n"
               "%s\n"
               "#+END_published\n"
               "%s"))
            entry
            (org-publish-find-title entry project)
            (format-time-string (cdr org-time-stamp-formats) (org-publish-find-date entry project))
            (format-time-string "%A, %B %_d %Y at %l:%M %p %Z" (org-publish-find-date entry project))
            (let* ((preview (sfoj--get-preview entry))
                   (needs-more (car preview))
                   (preview-text (cadr preview)))
              (if needs-more
                  (format
                   (concat
                    "%s\n\n"
                    "#+BEGIN_morelink\n"
                    "[[file:%s][Read More →]]\n"
                    "#+END_morelink\n")
                   preview-text entry)
                (format "%s" preview-text))))))

(defun sfoj--sitemap-files-to-lisp (files project)
  "Convert a group of entries into a list.

FILES  The group of entries to list-ify.
PROJECT  The project structure."
  (let ((root (expand-file-name
               (file-name-as-directory
                (org-publish-property :base-directory project)))))
    (cons 'unordered
          (mapcar
           (lambda (f)
             (list (sfoj--sitemap-entry (file-relative-name f root) project)))
           files))))

(defun sfoj--group (source n)
  "Group a list by 'n' elements.

SOURCE  The list.
N  The number to group the list by."
  (if (not (endp (nthcdr n source)))
      (cons (subseq source 0 n)
            (sfoj--group (nthcdr n source) n))
    (list source)))

;;
;; We keep a local cache of filename to date. This speeds up
;; publishing tremendously, because org-publish-find-date is very
;; expensive, and the sorting predicate we use calls it n^2 times.
;;
(setq sfoj-sitemap-file-dates (make-hash-table))

(defun sfoj--find-date (file-name project)
  "Find the date for a file and cache it.

FILE-NAME  The file in which to find a date.
PROJECT  The project structure."
  (let ((maybe-date (gethash file-name sfoj-sitemap-file-dates nil)))
    (if maybe-date
        maybe-date
      (let ((new-date (org-publish-find-date file-name project)))
        (puthash file-name new-date sfoj-sitemap-file-dates)
        new-date))))

(fmakunbound 'org-html-template)

(defun org-html-template (contents info)
  "Return complete document string after HTML conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (concat
   (when (and (not (org-html-html5-p info)) (org-html-xhtml-p info))
     (let* ((xml-declaration (plist-get info :html-xml-declaration))
            (decl (or (and (stringp xml-declaration) xml-declaration)
                      (cdr (assoc (plist-get info :html-extension)
                                  xml-declaration))
                      (cdr (assoc "html" xml-declaration))
                      "")))
       (when (not (or (not decl) (string= "" decl)))
         (format "%s\n"
                 (format decl
                         (or (and org-html-coding-system
                                  (fboundp 'coding-system-get)
                                  (coding-system-get org-html-coding-system 'mime-charset))
                             "iso-8859-1"))))))
   (org-html-doctype info)
   "\n"
   (concat "<html"
           (when (org-html-xhtml-p info)
             (format
              " xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"%s\" xml:lang=\"%s\""
              (plist-get info :language) (plist-get info :language)))
           ">\n")
   "<head>\n"
   (org-html--build-meta-info info)
   (org-html--build-head info)
   (org-html--build-mathjax-config info)
   "</head>\n"
   "<body>\n"
   "<div id=\"wrapper\">\n"
   (let ((link-up (org-trim (plist-get info :html-link-up)))
         (link-home (org-trim (plist-get info :html-link-home))))
     (unless (and (string= link-up "") (string= link-home ""))
       (format (plist-get info :html-home/up-format)
               (or link-up link-home)
               (or link-home link-up))))
   ;; Preamble.
   (org-html--build-pre/postamble 'preamble info)
   ;; Document contents.
   (let ((div (assq 'content (plist-get info :html-divs))))
     (format "<%s id=\"%s\">\n" (nth 1 div) (nth 2 div)))
   ;; Document title.
   (when (plist-get info :with-title)
     (let* ((title (plist-get info :title))
            (subtitle (plist-get info :subtitle))
            (with-date (plist-get info :with-date))
            (date-fmt (plist-get info :html-metadata-timestamp-format))
            (date (org-export-get-date info date-fmt)))
       (when title
         (format
          (if (plist-get info :html-html5-fancy)
              "<header>\n<h1 class=\"title\">%s</h1>\n%s%s</header>"
            "<h1 class=\"title\">%s%s%s</h1>\n")
          (org-export-data title info)
          (if subtitle
              (format
               (if (plist-get info :html-html5-fancy)
                   "<p class=\"subtitle\">%s</p>\n"
                 "\n<br>\n<span class=\"subtitle\">%s</span>\n")
               (org-export-data subtitle info))
            "")
          (if (and with-date date)
              (format "\n<h2 class=\"date\">%s</h2>" date)
            "")))))
   contents
   (format "</%s>\n" (nth 1 (assq 'content (plist-get info :html-divs))))
   ;; Postamble.
   (org-html--build-pre/postamble 'postamble info)
   ;; Closing document.
   "</div>\n</body>\n</html>"))

;; Un-define the original version of 'org-publish-sitemap'
(fmakunbound 'org-publish-sitemap)

;; Define our own version. This function for created for blog sitemap
(defun org-publish-sitemap (project &optional sitemap-filename)
  "Publish the blog.

This is actually a heavily modified and customized version of the
function by the same name in ox-publish.el.  It allows the
generation of a sitemap with multiple pages.

PROJECT  The project structure.
SITEMAP-FILENAME  The filename to use as the default index."
  (let* ((base (file-name-sans-extension (or sitemap-filename "index.org")))
         (root (file-name-as-directory (expand-file-name
                                        (concat sfoj-org-dir "posts/"))))
         (title (or (org-publish-property :sitemap-title project)
                    (concat "Sitemap for project " (car project))))
         (sort-predicate
          (lambda (a b)
            (let* ((adate (sfoj--find-date a project))
                   (bdate (sfoj--find-date b project))
                   (A (+ (lsh (car adate) 16) (cadr adate)))
                   (B (+ (lsh (car bdate) 16) (cadr bdate))))
              (>= A B))))
         (file-filter (lambda (f) (not (string-match (format "%s.*\\.org" base) f))))
         (files (seq-filter file-filter (org-publish-get-base-files project))))
    (message (format "Generating blog indexes for %s" title))
    (let* ((pages (sort files sort-predicate))
           (page-groups (sfoj--group pages sfoj-posts-per-page))
           (page-number 0))
      (dolist (group page-groups page-number)
        (let ((fname (if (eq 0 page-number)
                         (concat root (format "%s.org" base))
                       (concat root (format "%s_%d.org" base page-number))))

              (previous-page (cond ((eq 0 page-number) nil)
                                   ((eq 1 page-number) (concat root (format "%s.org" base)))
                                   (t (concat root (format "%s_%d.org" base (- page-number 1))))))
              (next-page (if (eq (- (length page-groups) 1) page-number)
                             nil
                           (concat root (format "%s_%d.org" base (+ page-number 1))))))
          (setq page-number (+ 1 page-number))
          (with-temp-file fname
            (insert
             (sfoj--sitemap-for-group
              title
              previous-page
              next-page
              (sfoj--sitemap-files-to-lisp group project)))))))))

(setq org-publish-timestamp-directory (concat sfoj-project-dir "cache/"))
(setq org-publish-project-alist
      `(("sfoj"
         :components ("blog" "pages" "resources" "images"))

        ("blog"
         :base-directory ,sfoj-blog-org-dir
         :base-extension "org"
         :publishing-directory ,sfoj-blog-www-dir
         :publishing-function org-html-publish-to-html
         :with-author t
         :author "Quan"
         :email "vuhongquanbk97@gmail.com"
         :with-creator nil
         :with-date t
         :section-numbers nil
         :with-title t
         :with-toc nil
         :with-drawers t
         :with-sub-superscript nil
         :html-html5-fancy t
         :html-metadata-timestamp-format "%A, %B %_d %Y at %l:%M %p"
         :html-doctype "html5"
         :html-link-home "https://vhquan.github.io/"
         :html-link-use-abs-url t
         :html-head ,sfoj-head
         :html-head-extra nil
         :html-head-include-default-style nil
         :html-head-include-scripts nil
         :html-viewport nil
         :html-link-up ""
         :html-link-home ""
         :html-preamble sfoj--header
         :html-postamble ,sfoj-footer
         :auto-sitemap t
         :sitemap-filename "index.org"
         :sitemap-title "ls /home/quan/blog/"
         :sitemap-sort-files anti-chronologically)

        ("pages"
         :base-directory ,sfoj-org-dir
         :base-extension "org"
         :exclude ".*blog/.*"
         :publishing-directory ,sfoj-www-dir
         :publishing-function org-html-publish-to-html
         :section-numbers nil
         :recursive t
         :with-title t
         :with-toc nil
         :with-drawers t
         :with-sub-superscript nil
         :with-author t
         :author "Quan"
         :email "vuhongquanbk97@gmail.com"
         :html-html5-fancy t
         :with-creator nil
         :with-date nil
         :html-link-home "/"
         :html-head nil
         :html-doctype "html5"
         :html-head ,sfoj-head
         :html-head-extra nil
         :html-head-include-default-style nil
         :html-head-include-scripts nil
         :html-link-up ""
         :html-preamble sfoj--header
         :html-postamble ,sfoj-footer
         :html-viewport nil)

        ("resources"
         :base-directory ,sfoj-org-dir
         :base-extension "css\\|js\\|woff2\\|woff\\|ttf"
         :recursive t
         :publishing-directory ,sfoj-www-dir
         :publishing-function org-publish-attachment)

        ("images"
         :base-directory ,sfoj-org-dir
         :base-extension "png\\|jpg\\|gif\\|pdf\\|svg"
         :recursive t
         :publishing-directory ,sfoj-www-dir
         :publishing-function org-publish-attachment)))
