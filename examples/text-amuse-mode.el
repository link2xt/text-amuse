(defvar amuse-mode-tag-names
  '("quote" "biblio" "play" "comment" "verse" "center" "right" "example"
    "br" "verbatim"
    "em" "strong" "code" "sup" "sub"))

(defvar amuse-mode-font-lock-defaults
  `((
     ("^\\* .*$" . font-lock-type-face)
     ("^\\*\\* .*$" . font-lock-type-face)
     ("^\\*\\*\\* .*$" . font-lock-type-face)
     ("^\\*\\*\\*\\* .*$" . font-lock-type-face)
     ("^\\*\\*\\*\\*\\* .*$" . font-lock-type-face)
     ("\\[[0-9]+\\]" . font-lock-variable-name-face)
     ("^ +- " . font-lock-keyword-face)
     ("\\*+\\(.*?\\w.*?\\)\\*+" . font-lock-variable-name-face)
     ("=\\(.*?\\w.*?\\)=" . font-lock-variable-name-face)
     ("{{{" . font-lock-keyword-face)
     ("}}}" . font-lock-keyword-face)
     ("^ +[1-9]\\. +" . font-lock-keyword-face)
     ("^ +[a-zA-Z]\\{1,4\\}\\. +" . font-lock-keyword-face)
     ("^ +.* :: " . font-lock-string-face)
     ("^ .* |+ .*$" . font-lock-constant-face)
     ("^ .* |\\+ .*$" . font-lock-constant-face)
     ("\\[\\[.*?\\]\\]" . font-lock-function-name-face)
     ("^ *#\\w+" . font-lock-function-name-face)
     ("^; .*$" . font-lock-comment-face)
     ("\\*" . font-lock-warning-face)
     (,(concat "</?" (regexp-opt amuse-mode-tag-names 'words) ">") . font-lock-keyword-face))))


(define-skeleton amuse-mode-insert-quote "Insert <quote></quote>" "Text: "
  "\n<quote>\n" _ "\n</quote>\n")

(define-skeleton amuse-mode-insert-biblio "Insert <biblio></biblio>" "Text: "
  "\n<biblio>\n" _ "\n</biblio>\n")

(define-skeleton amuse-mode-insert-play "Insert <play></play>" "Text: "
  "\n<play>\n" _ "\n</play>\n")

(define-skeleton amuse-mode-insert-example "Insert <example></example>" "Text: "
  "\n<example>\n" _ "\n</example>\n")

(defvar amuse-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-q" 'amuse-mode-insert-quote)
    (define-key map "\C-c\C-b" 'amuse-mode-insert-biblio)
    (define-key map "\C-c\C-p" 'amuse-mode-insert-play)
    (define-key map "\C-c\C-e" 'amuse-mode-insert-example)
    map))

(define-derived-mode amuse-mode text-mode "Text::Amuse"
  "Amuse mode is a lightweith major mode for amusewiki"
  (setq font-lock-defaults amuse-mode-font-lock-defaults))

(provide 'amuse-mode)
