# Makefile for my blog
.PHONY: all publish publish_no_init debug

all: publish

publish: publish.el
	@echo "Publishing ... with current Emacs configurations."
	emacs --batch --load publish.el --funcall org-publish-all

publish_no_init: publish.el
	@echo "Publishing ... with --no-init."
	emacs --batch --no-init --load publish.el --funcall org-publish-all

clean:
	@echo "Cleaning up..."
	@rm -rvf *.elc
	@rm -rvf ~/.org-timestamps/*

debug:
	python -m http.server
