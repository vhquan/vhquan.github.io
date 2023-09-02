(require 'ox-publish)

;; OrgMode configs
(setq org-return-follows-link t)
(setq org-hide-emphasis-markers t)
(setq org-html-validation-link nil)

(defun org-sitemap-custom-entry-format (entry style project)
  (let ((filename (org-publish-find-title entry project)))
    (if (= (length filename) 0)
	(format "*%s*" entry)
      (format "%s - [[file:%s][%s]]"
	      (format-time-string "%Y-%m-%d" (org-publish-find-date entry project))
	      entry
	      filename))))

(setq org-publish-project-alist
      '(("posts"
         :base-directory "posts/"
         :base-extension "org"
         :publishing-directory "~/workspace/vhquan.github.io/"
         :recursive t
         :publishing-function org-html-publish-to-html
         :auto-sitemap t
	 :auto-preamble nil
         :sitemap-title "Secret notes"
         :sitemap-filename "index.org"
         :sitemap-format-entry org-sitemap-custom-entry-format
         :sitemap-style list
         :author "Quan Vu"
         :email "vuhongquanbk97@gmail.com"
         :with-creator nil
	 :html-head "<link rel=\"stylesheet\" href=\"css/style.css\" type=\"text/css\"/>"
	 :html-head-include-default-style nil
	 :html-head-include-scripts nil
	 :html-preamble blog-header
	 :html-postamble "<hr><a href=\"/\">Home Page</a>"
	 :html-link-home "/")
        ("static"
         :base-directory "posts/"
         :base-extension "css\\|htaccess\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf\\|txt"
         :publishing-directory "~/workspace/vhquan.github.io/"
         :publishing-function org-publish-attachment
         :recursive t)
        ("all" :components ("posts" "static"))))
