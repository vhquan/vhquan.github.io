# Makefile for generate blog posts
.PHONY: all publish clean

all: publish

publish: .scripts/publish.el
	@echo "Publishing ... with current Emacs configuration."
	emacs --batch --load .scripts/publish.el --load .scripts/htmlize.el --funcall org-publish-all
	@cp html/index.html ~/vhquan.github.io

clean:
	@echo "Cleaning up ..."
	@rm -rf cache/
	@rm -rvf *.elc
	@rm -rvf ~/.org-timestamps/*
