* How to write

- Using the template.org to write a post
- Convert the org file to xml file `emacs -Q --batch --eval '(setq org-confirm-babel-evaluate nil)' -l ./ox-rfc.e
l name.org -f ox-rfc-export-to-xml`
- Convert the xml file to the text file `xml2rfc --text -o name.txt name.xml`
- Remove the status of this memo in the text file
- Generate index.htlm `node main.js`