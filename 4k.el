;;; gfourk.el --- major mode for editing (G)Fourk sources

;; Copyright (C) 1995,1996,1997,1998,2000,2001,2003 Free Software Foundation, Inc.

;; This file is part of Gfourk.

;; GFourk is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY.  No author or distributor
;; accepts responsibility to anyone for the consequences of using it
;; or for whether it serves any particular purpose or works at all,
;; unless he says so in writing.  Refer to the GNU Emacs General Public
;; License for full details.

;; Everyone is granted permission to copy, modify and redistribute
;; GNU Emacs, but only under the conditions described in the
;; GNU Emacs General Public License.   A copy of this license is
;; supposed to have been given to you along with Gfourk so you
;; can know your rights and responsibilities.  It should be in a
;; file named COPYING.  Among other things, the copyright notice
;; and this notice must be preserved on all copies.

;; Author: Goran Rydqvist <gorry@ida.liu.se>
;; Maintainer: David Kühling <dvdkhlng@gmx.de>
;; Created: 16 July 88 by Goran Rydqvist
;; Keywords: fourk, gfourk

;; Changes by anton
;; This is a variant of fourk.el that came with TILE.
;; I left most of this stuff untouched and made just a few changes for 
;; the things I use (mainly indentation and syntax tables).
;; So there is still a lot of work to do to adapt this to gfourk.

;; Changes by David
;; Added a syntax-hilighting engine, rewrote auto-indentation engine.
;; Added support for block files.
;; Replaced fourk-process code with comint-based implementation.

;; Tested with Emacs 19.34, 20.5, 21 and XEmacs 21
 
;;-------------------------------------------------------------------
;; A Fourk indentation, documentation search and interaction library
;;-------------------------------------------------------------------
;;
;; Written by Goran Rydqvist, gorry@ida.liu.se, Summer 1988
;; Started:	16 July 88
;; Version:	2.10
;; Last update:	5 December 1989 by Mikael Patel, mip@ida.liu.se
;; Last update:	25 June 1990 by Goran Rydqvist, gorry@ida.liu.se
;;
;; Documentation: See fourk-mode (^HF fourk-mode)
;;-------------------------------------------------------------------

;;; Code:

;(setq debug-on-error t)

;; Code ripped from `version.el' for compatability with Emacs versions
;; prior to 19.23.
(if (not (boundp 'emacs-major-version))
    (defconst emacs-major-version
      (progn (string-match "^[0-9]+" emacs-version)
	     (string-to-int (match-string 0 emacs-version)))))

(defun fourk-emacs-older (major minor)
  (or (< emacs-major-version major)
      (and (= emacs-major-version major) (< emacs-minor-version minor))))

;; Code ripped from `subr.el' for compatability with Emacs versions
;; prior to 20.1
(eval-when-compile 
  (if (fourk-emacs-older 20 1)
      (progn
	(defmacro when (cond &rest body)
	  "If COND yields non-nil, do BODY, else return nil."
	  (list 'if cond (cons 'progn body)))
	(defmacro unless (cond &rest body)
	  "If COND yields nil, do BODY, else return nil."
	  (cons 'if (cons cond (cons nil body)))))))

;; `no-error' argument of require not supported in Emacs versions
;; prior to 20.4 :-(
(defun fourk-require (feature)
  (condition-case err (require feature) (error nil)))

(require 'font-lock)

;; define `font-lock-warning-face' in emacs-versions prior to 20.1
;; (ripped from `font-lock.el')
(unless (boundp 'font-lock-warning-face)
  (message "defining font-lock-warning-face")
  (make-face 'font-lock-warning-face)
  (defvar font-lock-warning-face 'font-lock-warning-face)
  (set-face-foreground font-lock-warning-face "red")
  (make-face-bold font-lock-warning-face))

;; define `font-lock-constant-face' in XEmacs (just copy
;; `font-lock-preprocessor-face')
(unless (boundp 'font-lock-constant-face)
  (copy-face font-lock-preprocessor-face 'font-lock-constant-face))


;; define `regexp-opt' in emacs versions prior to 20.1 
;; (this implementation is extremely inefficient, though)
(eval-and-compile (fourk-require 'regexp-opt))
(unless (memq 'regexp-opt features)
  (message (concat 
	    "Warning: your Emacs version doesn't support `regexp-opt'. "
            "Hilighting will be slow."))
  (defun regexp-opt (STRINGS &optional PAREN)
    (let ((open (if PAREN "\\(" "")) (close (if PAREN "\\)" "")))
      (concat open (mapconcat 'regexp-quote STRINGS "\\|") close)))
  (defun regexp-opt-depth (re)
    (if (string= (substring re 0 2) "\\(") 1 0)))

; todo:
;

; Wörter ordentlich hilighten, die nicht auf Whitespace beginnen ( ..)IF
; -- mit aktueller Konzeption nicht möglich??
;
; Konfiguration über customization groups
;
; Bereich nur auf Wortanfang/ende ausweiten, wenn Anfang bzw Ende in einem 
; Wort liegen (?) -- speed!
;
; 'fourk-word' property muss eindeutig sein!
;
; Fourk-Menu 
;
; Interface zu GFourk Prozessen (Patches von Michael Scholz)
;
; Byte-compile-Code rausschmeißen, Compilieren im Makefile über Emacs
; batch-Modus
;
; fourk-help Kram rausschmeißen
;
; XEmacs Kompatibilität? imenu/speedbar -> fume?
; 
; Folding neuschreiben (neue Parser-Informationen benutzen)

;;; Motion-hooking (dk)
;;;
(defun fourk-idle-function ()
  "Function that is called when Emacs is idle to detect cursor motion
in fourk-block-mode buffers (which is mainly used for screen number
display in).  Currently ignores fourk-mode buffers but that may change
in the future."
  (if (eq major-mode 'fourk-block-mode)
      (fourk-check-motion)))

(defvar fourk-idle-function-timer nil 
  "Timer that runs `fourk-idle-function' or nil if no timer installed.")

(defun fourk-install-motion-hook ()
  "Install the motion-hooking mechanism.  Currently uses idle timers
but might be transparently changed in the future."
  (unless fourk-idle-function-timer
    ;; install idle function only once (first time fourk-mode is used)
    (setq fourk-idle-function-timer 
	  (run-with-idle-timer .05 t 'fourk-idle-function))))

(defvar fourk-was-point nil)

(defun fourk-check-motion ()
  "Run `fourk-motion-hooks', if `point' changed since last call.  This
used to be called via `post-command-hook' but uses idle timers now as
users complaint about lagging performance."
  (when (or (eq fourk-was-point nil) (/= fourk-was-point (point)))
    (setq fourk-was-point (point))
    (run-hooks 'fourk-motion-hooks)))


;;; Hilighting and indentation engine (dk)
;;;
(defvar fourk-disable-parser nil
  "*Non-nil means to disable on-the-fly parsing of Fourk-code.

This will disable hilighting of fourk-mode buffers and will decrease
the smartness of the indentation engine. Only set it to non-nil, if
your computer is very slow. To disable hilighting, set
`fourk-hilight-level' to zero.")

(defvar fourk-jit-parser nil
  "*Non-nil means to parse Fourk-code just-in-time.

This eliminates the need for initially parsing fourk-mode buffers and
thus speeds up loading of Fourk files. That feature is only available
in Emacs21 (and newer versions).")

(defvar fourk-words nil 
  "List of words for hilighting and recognition of parsed text areas. 

Hilighting of object-oriented Fourk code is achieved, by appending either
`fourk-objects-words' or `fourk-oof-words' to the list, depending on the values of `fourk-use-objects' or `fourk-use-oof'.

After `fourk-words' changed, `fourk-compile-words' must be called to
make the changes take effect.

Each item of `fourk-words' has the form 
   (MATCHER TYPE HILIGHT . &optional PARSED-TEXT ...)

MATCHER is either a list of strings to match, or a REGEXP.
   If it's a REGEXP, it should not be surrounded by '\\<' or '\\>', since 
   that'll be done automatically by the search routines.

TYPE should be one of 'definiton-starter', 'definition-ender', 'compile-only',
   'immediate' or 'non-immediate'. Those information are required to determine
   whether a word actually parses (and whether that parsed text needs to be
   hilighted).

HILIGHT is a cons cell of the form (FACE . MINIMUM-LEVEL)
   Where MINIMUM-LEVEL specifies the minimum value of `fourk-hilight-level',
   that's required for matching text to be hilighted.

PARSED-TEXT specifies whether and how a word parses following text. You can
   specify as many subsequent PARSED-TEXT as you wish, but that shouldn't be
   necessary very often. It has the following form:
   (DELIM-REGEXP SKIP-LEADING-FLAG PARSED-TYPE HILIGHT)

DELIM-REGEXP is a regular expression that should match strings of length 1,
   which are delimiters for the parsed text.

A non-nil value for PARSE-LEADING-FLAG means, that leading delimiter strings
   before parsed text should be skipped. This is the parsing behaviour of the
   Fourk word WORD. Set it to t for name-parsing words, nil for comments and
   strings.

PARSED-TYPE specifies what kind of text is parsed. It should be on of 'name',
   'string' or 'comment'.")
(setq fourk-words
      '(
	(("[") definition-ender (font-lock-keyword-face . 1))
	(("]" "]l") definition-starter (font-lock-keyword-face . 1))
	((":") definition-starter (font-lock-keyword-face . 1)
	 "[ \t\n]" t name (font-lock-function-name-face . 3))
	(("immediate" "compile-only" "restrict")
	 immediate (font-lock-keyword-face . 1))
	(("does>") compile-only (font-lock-keyword-face . 1))
	((":noname") definition-starter (font-lock-keyword-face . 1))
	((";" ";code") definition-ender (font-lock-keyword-face . 1))
	(("include" "require" "needs" "use") 
         non-immediate (font-lock-keyword-face . 1) 
	(("Render:" "Display:") definition-starter (font-lock-keyword-face . 1))
	((";Render" ";Display") definition-ender (font-lock-keyword-face . 1))
	 "[\n\t ]" t string (font-lock-string-face . 1))
	(("included" "required" "thru" "load")
	 non-immediate (font-lock-keyword-face . 1))
	(("[char]") compile-only (font-lock-keyword-face . 1)
	 "[ \t\n]" t string (font-lock-string-face . 1))
	(("c:") compile-only (font-lock-keyword-face . 1)
	 "[ \t\n]" t string (font-lock-string-face . 1))
	(("char") non-immediate (font-lock-keyword-face . 1)
	 "[ \t\n]" t string (font-lock-string-face . 1))
	(("s\"" "c\"") immediate (font-lock-string-face . 1)
	 "[\"\n]" nil string (font-lock-string-face . 1))
	((".\"") compile-only (font-lock-string-face . 1)
	 "[\"\n]" nil string (font-lock-string-face . 1))
	(("\"") compile-only (font-lock-string-face . 1)
	 "[\"]" nil string (font-lock-string-face . 1))
	(("abort\"") compile-only (font-lock-keyword-face . 1)
	 "[\"\n]" nil string (font-lock-string-face . 1))
	(("{") compile-only (font-lock-variable-name-face . 1)
	 "[\n}]" nil name (font-lock-variable-name-face . 1))
	((".(" "(") immediate (font-lock-comment-face . 1)
	  ")" nil comment (font-lock-comment-face . 1))
	(("(*") immediate (font-lock-comment-face . 1)
	  "*)" nil comment (font-lock-comment-face . 1))
	(("|" "\\" "\\G") immediate (font-lock-comment-face . 1)
	 "[\n]" nil comment (font-lock-comment-face . 1))
	  
	(("[if]" "[?do]" "[do]" "[for]" "[begin]" 
	  "[endif]" "[then]" "[loop]" "[+loop]" "[next]" "[until]" "[repeat]"
	  "[again]" "[while]" "[else]")
	 immediate (font-lock-keyword-face . 2))
	(("[ifdef]" "[ifundef]") immediate (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-function-name-face . 3))
	(("if" "begin" "ahead" "do" "?do" "+do" "u+do" "-do" "u-do" "for" 
	  "case" "of" "?dup-if" "?dup-0=-if" "then" "endif" "until"
	  "repeat" "again" "leave" "?leave"
	  "loop" "+loop" "-loop" "next" "endcase" "endof" "else" "while" "try"
	  "recover" "endtry" "assert(" "assert0(" "assert1(" "assert2(" 
	  "assert3(" ")" "<interpretation" "<compilation" "interpretation>" 
	  "compilation>")
	 compile-only (font-lock-keyword-face . 2))

	(("true" "false" "c/l" "bl" "cell" "pi" "w/o" "r/o" "r/w") 
	 non-immediate (font-lock-constant-face . 2))
	(("~~" "break:" "dbg") compile-only (font-lock-warning-face . 2))
	(("break\"") compile-only (font-lock-warning-face . 1)
	 "[\"\n]" nil string (font-lock-string-face . 1))
	(("postpone" "[is]" "defers" "[']" "[compile]") 
	 compile-only (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-function-name-face . 3))
	(("is" "what's") immediate (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-function-name-face . 3))
	(("<is>" "'" "see") non-immediate (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-function-name-face . 3))
	(("[to]") compile-only (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-variable-name-face . 3))
	(("to") immediate (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-variable-name-face . 3))
	(("<to>") non-immediate (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-variable-name-face . 3))

	(("create" "variable" "constant" "2variable" "2constant" "fvariable"
	  "fconstant" "value" "field" "user" "vocabulary" 
	  "create-interpret/compile")
	 non-immediate (font-lock-type-face . 2)
	 "[ \t\n]" t name (font-lock-variable-name-face . 3))
	("\\S-+%" non-immediate (font-lock-type-face . 2))
	(("defer" "alias" "create-interpret/compile:") 
	 non-immediate (font-lock-type-face . 1)
	 "[ \t\n]" t name (font-lock-function-name-face . 3))
	(("end-struct") non-immediate (font-lock-keyword-face . 2)
	 "[ \t\n]" t name (font-lock-type-face . 3))
	(("struct") non-immediate (font-lock-keyword-face . 2))
	("-?[0-9]+\\(\\.[0-9]*e\\(-?[0-9]+\\)?\\|\\.?[0-9a-f]*\\)" 
	 immediate (font-lock-constant-face . 3))
	))

(defvar fourk-use-objects nil 
  "*Non-nil makes fourk-mode also hilight words from the \"Objects\" package.")
(defvar fourk-objects-words
  '(((":m") definition-starter (font-lock-keyword-face . 1)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("m:") definition-starter (font-lock-keyword-face . 1))
    ((";m") definition-ender (font-lock-keyword-face . 1))
    (("[current]" "[parent]") compile-only (font-lock-keyword-face . 1)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("current" "overrides") non-immediate (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("[to-inst]") compile-only (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-variable-name-face . 3))
    (("[bind]") compile-only (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-type-face . 3)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("bind") non-immediate (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-type-face . 3)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("inst-var" "inst-value") non-immediate (font-lock-type-face . 2)
     "[ \t\n]" t name (font-lock-variable-name-face . 3))
    (("method" "selector")
     non-immediate (font-lock-type-face . 1)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("end-class" "end-interface")
     non-immediate (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-type-face . 3))
    (("public" "protected" "class" "exitm" "implementation" "interface"
      "methods" "end-methods" "this") 
     non-immediate (font-lock-keyword-face . 2))
    (("object") non-immediate (font-lock-type-face . 2)))
  "Hilighting description for words of the \"Objects\" package")


(defvar fourk-use-oof nil 
  "*Non-nil makes fourk-mode also hilight words from the \"OOF\" package.")
(defvar fourk-oof-words 
  '((("class") non-immediate (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-type-face . 3))
    (("var") non-immediate (font-lock-type-face . 2)
     "[ \t\n]" t name (font-lock-variable-name-face . 3))
    (("method" "early") non-immediate (font-lock-type-face . 2)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("::" "super" "bind" "bound" "link") 
     immediate (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-function-name-face . 3))
    (("ptr" "asptr" "[]") 
     immediate (font-lock-keyword-face . 2)
     "[ \t\n]" t name (font-lock-variable-name-face . 3))
    (("class;" "how:" "self" "new" "new[]" "definitions" "class?" "with"
      "endwith")
     non-immediate (font-lock-keyword-face . 2))
    (("object") non-immediate (font-lock-type-face . 2)))
  "Hilighting description for words of the \"OOF\" package")

(defvar fourk-local-words nil 
  "List of Fourk words to prepend to `fourk-words'. Should be set by a 
 fourk source, using a local variables list at the end of the file 
 (\"Local Variables: ... fourk-local-words: ... End:\" construct).") 

(defvar fourk-custom-words nil
  "List of Fourk words to prepend to `fourk-words'. Should be set in your
 .emacs.")

(defvar fourk-hilight-level 3 "*Level of hilighting of Fourk code.")

(defvar fourk-compiled-words nil "Compiled representation of `fourk-words'.")

(defvar fourk-indent-words nil 
  "List of words that have indentation behaviour.
Each element of `fourk-indent-words' should have the form
   (MATCHER INDENT1 INDENT2 &optional TYPE) 
  
MATCHER is either a list of strings to match, or a REGEXP.
   If it's a REGEXP, it should not be surrounded by `\\<` or `\\>`, since 
   that'll be done automatically by the search routines.

TYPE might be omitted. If it's specified, the only allowed value is 
   currently the symbol `non-immediate', meaning that the word will not 
   have any effect on indentation inside definitions. (:NONAME is a good 
   example for this kind of word).

INDENT1 specifies how to indent a word that's located at the beginning
   of a line, following any number of whitespaces.

INDENT2 specifies how to indent words that are not located at the
   beginning of a line.

INDENT1 and INDENT2 are indentation specifications of the form
   (SELF-INDENT . NEXT-INDENT), where SELF-INDENT is a numerical value, 
   specifying how the matching line and all following lines are to be 
   indented, relative to previous lines. NEXT-INDENT specifies how to indent 
   following lines, relative to the matching line.
  
   Even values of SELF-INDENT and NEXT-INDENT correspond to multiples of
   `fourk-indent-level'. Odd values get an additional 
   `fourk-minor-indent-level' added/substracted. Eg a value of -2 indents
   1 * fourk-indent-level  to the left, wheras 3 indents 
   1 * fourk-indent-level + fourk-minor-indent-level  columns to the right.")

(setq fourk-indent-words
      '((("if" "begin" "do" "?do" "+do" "-do" "u+do"
	  "u-do" "?dup-if" "?dup-0=-if" "case" "of" "try"
	  "[if]" "[ifdef]" "[ifundef]" "[begin]" "[for]" "[do]" "[?do]" "Render:" "Display" )
	 (0 . 2) (0 . 2))
	((":" ":noname" "code" "struct" "m:" ":m" "class" "interface")
	 (0 . 2) (0 . 2) non-immediate)
	("\\S-+%$" (0 . 2) (0 . 0) non-immediate)
	((";" ";m") (-2 . 0) (0 . -2))
	(("again" "then" "endif" "endtry" "endcase" "endof" 
	  "[then]" "[endif]" "[loop]" "[+loop]" "[next]" 
	  "[until]" "[again]" "loop" ";Render" ";Display" )
	 (-2 . 0) (0 . -2))
	(("end-code" "end-class" "end-interface" "end-class-noname" 
	  "end-interface-noname" "end-struct" "class;")
	 (-2 . 0) (0 . -2) non-immediate)
	(("protected" "public" "how:") (-1 . 1) (0 . 0) non-immediate)
	(("+loop" "-loop" "until") (-2 . 0) (-2 . 0))
	(("else" "recover" "[else]") (-2 . 2) (0 . 0))
	(("does>") (-1 . 1) (0 . 0))
	(("while" "[while]") (-2 . 4) (0 . 2))
	(("repeat" "[repeat]") (-4 . 0) (0 . -4))
	(("\\g") (-2 . 2) (0 . 0))))

(defvar fourk-local-indent-words nil 
  "List of Fourk words to prepend to `fourk-indent-words', when a fourk-mode
buffer is created. Should be set by a Fourk source, using a local variables 
list at the end of the file (\"Local Variables: ... fourk-local-words: ... 
End:\" construct).")

(defvar fourk-custom-indent-words nil
  "List of Fourk words to prepend to `fourk-indent-words'. Should be set in
 your .emacs.")

(defvar fourk-indent-level 4
  "*Indentation of Fourk statements.")
(defvar fourk-minor-indent-level 2
  "*Minor indentation of Fourk statements.")
(defvar fourk-compiled-indent-words nil)

;(setq debug-on-error t)

;; Filter list by predicate. This is a somewhat standard function for 
;; functional programming languages. So why isn't it already implemented 
;; in Lisp??
(defun fourk-filter (predicate list)
  (let ((filtered nil))
    (mapcar (lambda (item)
	      (when (funcall predicate item)
		(if filtered
		    (nconc filtered (list item))
		  (setq filtered (cons item nil))))
	      nil) list)
    filtered))

;; Helper function for `fourk-compile-word': return whether word has to be
;; added to the compiled word list, for syntactic parsing and hilighting.
(defun fourk-words-filter (word)
  (let* ((hilight (nth 2 word))
	 (level (cdr hilight))
	 (parsing-flag (nth 3 word)))
    (or parsing-flag 
	(<= level fourk-hilight-level))))

;; Helper function for `fourk-compile-word': translate one entry from 
;; `fourk-words' into the form  (regexp regexp-depth word-description)
(defun fourk-compile-words-mapper (word)
  ;; warning: we cannot rely on regexp-opt's PAREN argument, since
  ;; XEmacs will use shy parens by default :-(
  (let* ((matcher (car word))
	 (regexp 
	  (concat "\\(" (cond ((stringp matcher) matcher)
			      ((listp matcher) (regexp-opt matcher))
			      (t (error "Invalid matcher `%s'")))
		  "\\)"))
	 (depth (regexp-opt-depth regexp))
	 (description (cdr word)))
    (list regexp depth description)))

;; Read `words' and create a compiled representation suitable for efficient
;; parsing of the form  
;; (regexp (subexp-count word-description) (subexp-count2 word-description2)
;;  ...)
(defun fourk-compile-wordlist (words)
  (let* ((mapped (mapcar 'fourk-compile-words-mapper words))
	 (regexp (concat "\\<\\(" 
			 (mapconcat 'car mapped "\\|")
			 "\\)\\>"))
	 (sub-count 2)
	 (sub-list (mapcar 
		    (lambda (i) 
		      (let ((sub (cons sub-count (nth 2 i))))
			(setq sub-count (+ sub-count (nth 1 i)))
			sub 
			)) 
		    mapped)))
    (let ((result (cons regexp sub-list)))
      (byte-compile 'result)
      result)))

(defun fourk-compile-words ()
  "Compile the the words from `fourk-words' and `fourk-indent-words' into
 the format that's later used for doing the actual hilighting/indentation.
 Store the resulting compiled wordlists in `fourk-compiled-words' and 
`fourk-compiled-indent-words', respective"
  (setq fourk-compiled-words 
	(fourk-compile-wordlist 
	 (fourk-filter 'fourk-words-filter fourk-words)))
  (setq fourk-compiled-indent-words 
	(fourk-compile-wordlist fourk-indent-words)))

(defun fourk-hack-local-variables ()
  "Parse and bind local variables, set in the contents of the current 
 fourk-mode buffer. Prepend `fourk-local-words' to `fourk-words' and 
 `fourk-local-indent-words' to `fourk-indent-words'."
  (hack-local-variables)
  (setq fourk-words (append fourk-local-words fourk-words))
  (setq fourk-indent-words (append fourk-local-indent-words 
				   fourk-indent-words)))

(defun fourk-customize-words ()
  "Add the words from `fourk-custom-words' and `fourk-custom-indent-words'
 to `fourk-words' and `fourk-indent-words', respective. Add 
 `fourk-objects-words' and/or `fourk-oof-words' to `fourk-words', if
 `fourk-use-objects' and/or `fourk-use-oof', respective is set."
  (setq fourk-words (append fourk-custom-words fourk-words
			    (if fourk-use-oof fourk-oof-words nil)
			    (if fourk-use-objects fourk-objects-words nil)))
  (setq fourk-indent-words (append 
			    fourk-custom-indent-words fourk-indent-words)))



;; get location of first character of previous fourk word that's got 
;; properties
(defun fourk-previous-start (pos)
  (let* ((word (get-text-property pos 'fourk-word))
	 (prev (previous-single-property-change 
		(min (point-max) (1+ pos)) 'fourk-word 
		(current-buffer) (point-min))))
    (if (or (= (point-min) prev) word) prev
      (if (get-text-property (1- prev) 'fourk-word)
	  (previous-single-property-change 
	   prev 'fourk-word (current-buffer) (point-min))
	(point-min)))))

;; Get location of the last character of the current/next fourk word that's
;; got properties, text that's parsed by the word is considered as parts of 
;; the word.
(defun fourk-next-end (pos)
  (let* ((word (get-text-property pos 'fourk-word))
	 (next (next-single-property-change pos 'fourk-word 
					    (current-buffer) (point-max))))
    (if word next
      (if (get-text-property next 'fourk-word)
	  (next-single-property-change 
	   next 'fourk-word (current-buffer) (point-max))
	(point-max)))))

(defun fourk-next-whitespace (pos)
  (save-excursion
    (goto-char pos)
    (skip-syntax-forward "-" (point-max))
    (point)))
(defun fourk-previous-word (pos)
  (save-excursion
    (goto-char pos)
    (re-search-backward "\\<" pos (point-min) 1)
    (point)))

;; Delete all properties, used by Fourk mode, from `from' to `to'.
(defun fourk-delete-properties (from to)
  (remove-text-properties 
   from to '(face nil fontified nil 
		  fourk-parsed nil fourk-word nil fourk-state nil)))

;; Get the index of the branch of the most recently evaluated regular 
;; expression that matched. (used for identifying branches "a\\|b\\|c...")
(defun fourk-get-regexp-branch ()
  (let ((count 2))
    (while (not (condition-case err (match-beginning count)
		  (args-out-of-range t)))  ; XEmacs requires error handling
      (setq count (1+ count)))
    count))

;; seek to next fourk-word and return its "word-description"
(defun fourk-next-known-fourk-word (to)
  (if (<= (point) to)
      (progn
	(let* ((regexp (car fourk-compiled-words))
	       (pos (re-search-forward regexp to t)))
	  (if pos (let ((branch (fourk-get-regexp-branch))
			(descr (cdr fourk-compiled-words)))
		    (goto-char (match-beginning 0))
		    (cdr (assoc branch descr)))
	    'nil)))
    nil))

;; Set properties of fourk word at `point', eventually parsing subsequent 
;; words, and parsing all whitespaces. Set point to delimiter after word.
;; The word, including it's parsed text gets the `fourk-word' property, whose 
;; value is unique, and may be used for getting the word's start/end 
;; positions.
(defun fourk-set-word-properties (state data)
  (let* ((start (point))
	 (end (progn (re-search-forward "[ \t]\\|$" (point-max) 1)
		     (point)))
	 (type (car data))
	 (hilight (nth 1 data))
	 (bad-word (and (not state) (eq type 'compile-only)))
	 (hlface (if bad-word font-lock-warning-face
		   (if (<= (cdr hilight) fourk-hilight-level)
		       (car hilight) nil))))
    (when hlface (put-text-property start end 'face hlface))
    ;; if word parses in current state, process parsed range of text
    (when (or (not state) (eq type 'compile-only) (eq type 'immediate))
      (let ((parse-data (nthcdr 2 data)))
	(while parse-data
	  (let ((delim (nth 0 parse-data))
		(skip-leading (nth 1 parse-data))
		(parse-type (nth 2 parse-data))
		(parsed-hilight (nth 3 parse-data))
		(parse-start (point))
		(parse-end))
	    (when skip-leading
	      (while (and (looking-at delim) (> (match-end 0) (point))
			  (not (looking-at "\n")))
		(forward-char)))
	    (re-search-forward delim (point-max) 1)
	    (setq parse-end (point))
	    (fourk-delete-properties end parse-end)
	    (when (<= (cdr parsed-hilight) fourk-hilight-level)
	      (put-text-property 
	       parse-start parse-end 'face (car parsed-hilight)))
	    (put-text-property 
	     parse-start parse-end 'fourk-parsed parse-type)
	    (setq end parse-end)
	    (setq parse-data (nthcdr 4 parse-data))))))
    (put-text-property start end 'fourk-word start)))

;; Search for known Fourk words in the range `from' to `to', using 
;; `fourk-next-known-fourk-word' and set their properties via 
;; `fourk-set-word-properties'.
(defun fourk-update-properties (from to &optional loudly)
  (save-excursion
    (let ((msg-count 0) (state) (word-descr) (last-location))
      (goto-char (fourk-previous-word (fourk-previous-start 
				       (max (point-min) (1- from)))))
      (setq to (fourk-next-end (min (point-max) (1+ to))))
      ;; `to' must be on a space delimiter, if a parsing word was changed
      (setq to (fourk-next-whitespace to))
      (setq state (get-text-property (point) 'fourk-state))
      (setq last-location (point))
      (fourk-delete-properties (point) to)
      (put-text-property (point) to 'fontified t)
      ;; hilight loop...
      (while (setq word-descr (fourk-next-known-fourk-word to))
	(when loudly
	  (when (equal 0 (% msg-count 100))
	    (message "Parsing Fourk code...%s"
		     (make-string (/ msg-count 100) ?.)))
	  (setq msg-count (1+ msg-count)))
	(fourk-set-word-properties state word-descr)
	(when state (put-text-property last-location (point) 'fourk-state t))
	(let ((type (car word-descr)))
	  (if (eq type 'definition-starter) (setq state t))
	  (if (eq type 'definition-ender) (setq state nil))
	  (setq last-location (point))))
      ;; update state property up to `to'
      (if (and state (< (point) to))
	  (put-text-property last-location to 'fourk-state t))
      ;; extend search if following state properties differ from current state
      (if (< to (point-max))
	  (if (not (equal state (get-text-property (1+ to) 'fourk-state)))
	      (let ((extend-to (next-single-property-change 
				to 'fourk-state (current-buffer) (point-max))))
		(fourk-update-properties to extend-to))
	    ))
      )))

;; save-buffer-state borrowed from `font-lock.el'
(eval-when-compile 
  (defmacro fourk-save-buffer-state (varlist &rest body)
    "Bind variables according to VARLIST and eval BODY restoring buffer state."
    (` (let* ((,@ (append varlist
		   '((modified (buffer-modified-p)) (buffer-undo-list t)
		     (inhibit-read-only t) (inhibit-point-motion-hooks t)
		     before-change-functions after-change-functions
		     deactivate-mark buffer-file-name buffer-file-truename))))
	 (,@ body)
	 (when (and (not modified) (buffer-modified-p))
	   (set-buffer-modified-p nil))))))

;; Function that is added to the `change-functions' hook. Calls 
;; `fourk-update-properties' and keeps care of disabling undo information
;; and stuff like that.
(defun fourk-change-function (from to len &optional loudly)
  (save-match-data
    (fourk-save-buffer-state 
     () 
     (unless fourk-disable-parser (fourk-update-properties from to loudly))
     (fourk-update-warn-long-lines))))

(defun fourk-fontification-function (from)
  "Function to be called from `fontification-functions' of Emacs 21."
  (save-match-data
    (fourk-save-buffer-state
     ((to (min (point-max) (+ from 100))))
     (unless (or fourk-disable-parser (not fourk-jit-parser)
		 (get-text-property from 'fontified))
       (fourk-update-properties from to)))))

(eval-when-compile
  (byte-compile 'fourk-set-word-properties)
  (byte-compile 'fourk-next-known-fourk-word)
  (byte-compile 'fourk-update-properties)
  (byte-compile 'fourk-delete-properties)
  (byte-compile 'fourk-get-regexp-branch)) 

;;; imenu support
;;;
(defvar fourk-defining-words 
  '("VARIABLE" "CONSTANT" "2VARIABLE" "2CONSTANT" "FVARIABLE" "FCONSTANT"
   "USER" "VALUE" "field" "end-struct" "VOCABULARY" "CREATE" ":" "CODE"
   "DEFER" "ALIAS")
  "List of words, that define the following word.
Used for imenu index generation.")

(defvar fourk-defining-words-regexp nil 
  "Regexp that's generated for matching `fourk-defining-words'")
 
(defun fourk-next-definition-starter ()
  (progn
    (let* ((pos (re-search-forward fourk-defining-words-regexp (point-max) t)))
      (if pos
	  (if (or (text-property-not-all (match-beginning 0) (match-end 0) 
					 'fourk-parsed nil)
		  (text-property-not-all (match-beginning 0) (match-end 0)
					 'fourk-state nil)) 
	      (fourk-next-definition-starter)
	    t)
	nil))))

(defun fourk-create-index ()
  (let* ((fourk-defining-words-regexp 
	  (concat "\\<\\(" (regexp-opt fourk-defining-words) "\\)\\>"))
	 (index nil))
    (goto-char (point-min))
    (while (fourk-next-definition-starter)
      (if (looking-at "[ \t]*\\([^ \t\n]+\\)")
	  (setq index (cons (cons (match-string 1) (point)) index))))
    index))

;; top-level require is executed at byte-compile and load time
(eval-and-compile (fourk-require 'speedbar))

;; this code is executed at load-time only
(when (memq 'speedbar features)
  (speedbar-add-supported-extension ".fs")
  (speedbar-add-supported-extension ".fb"))

;; (require 'profile)
;; (setq profile-functions-list '(fourk-set-word-properties fourk-next-known-fourk-word fourk-update-properties fourk-delete-properties fourk-get-regexp-branch))

;;; Indentation
;;;

;; Return, whether `pos' is the first fourk word on its line
(defun fourk-first-word-on-line-p (pos)
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " \t")
    (= pos (point))))

;; Return indentation data (SELF-INDENT . NEXT-INDENT) of next known 
;; indentation word, or nil if there is no word up to `to'. 
;; Position `point' at location just after found word, or at `to'. Parsed 
;; ranges of text will not be taken into consideration!
(defun fourk-next-known-indent-word (to)
  (if (<= (point) to)
      (progn
	(let* ((regexp (car fourk-compiled-indent-words))
	       (pos (re-search-forward regexp to t)))
	  (if pos
	      (let* ((start (match-beginning 0))
		     (end (match-end 0))
		     (branch (fourk-get-regexp-branch))
		     (descr (cdr fourk-compiled-indent-words))
		     (indent (cdr (assoc branch descr)))
		     (type (nth 2 indent)))
		;; skip words that are parsed (strings/comments) and 
		;; non-immediate words inside definitions
		(if (or (text-property-not-all start end 'fourk-parsed nil)
			(and (eq type 'non-immediate) 
			     (text-property-not-all start end 
						    'fourk-state nil)))
		    (fourk-next-known-indent-word to)
		  (if (fourk-first-word-on-line-p (match-beginning 0))
		      (nth 0 indent) (nth 1 indent))))
	    nil)))
    nil))
  
;; Translate indentation value `indent' to indentation column. Multiples of
;; 2 correspond to multiples of `fourk-indent-level'. Odd numbers get an
;; additional `fourk-minor-indent-level' added (or substracted).
(defun fourk-convert-to-column (indent)
  (let* ((sign (if (< indent 0) -1 1))
	 (value (abs indent))
	 (major (* (/ value 2) fourk-indent-level))
	 (minor (* (% value 2) fourk-minor-indent-level)))
    (* sign (+ major minor))))

;; Return the column increment, that the current line of fourk code does to
;; the current or following lines. `which' specifies which indentation values
;; to use. 0 means the indentation of following lines relative to current 
;; line, 1 means the indentation of the current line relative to the previous 
;; line. Return `nil', if there are no indentation words on the current line.
(defun fourk-get-column-incr (which)
  (save-excursion
    (let ((regexp (car fourk-compiled-indent-words))
	  (word-indent)
	  (self-indent nil)
	  (next-indent nil)
	  (to (save-excursion (end-of-line) (point))))
      (beginning-of-line)
      (while (setq word-indent (fourk-next-known-indent-word to))
	(let* ((self-incr (car word-indent))
	       (next-incr (cdr word-indent))
	       (self-column-incr (fourk-convert-to-column self-incr))
	       (next-column-incr (fourk-convert-to-column next-incr)))
	  (setq next-indent (if next-indent next-indent 0))
	  (setq self-indent (if self-indent self-indent 0))
	  (if (or (and (> next-indent 0) (< self-column-incr 0))
		  (and (< next-indent 0) (> self-column-incr 0)))
	      (setq next-indent (+ next-indent self-column-incr))
	    (setq self-indent (+ self-indent self-column-incr)))
	  (setq next-indent (+ next-indent next-column-incr))))
      (nth which (list self-indent next-indent)))))

;; Find previous line that contains indentation words, return the column,
;; to which following text should be indented to.
(defun fourk-get-anchor-column ()
  (save-excursion
    (if (/= 0 (forward-line -1)) 0
      (let ((indent))
	(while (not (or (setq indent (fourk-get-column-incr 1))
			(<= (point) (point-min))))
	  (forward-line -1))
	(+ (current-indentation) (if indent indent 0))))))

(defun fourk-indent-line (&optional flag)
  "Correct indentation of the current Fourk line."
  (let* ((anchor (fourk-get-anchor-column))
	 (column-incr (fourk-get-column-incr 0)))
    (fourk-indent-to (if column-incr (+ anchor column-incr) anchor))))

(defun fourk-current-column ()
  (- (point) (save-excursion (beginning-of-line) (point))))
(defun fourk-current-indentation ()
  (- (save-excursion (beginning-of-line) (forward-to-indentation 0) (point))
     (save-excursion (beginning-of-line) (point))))

(defun fourk-indent-to (x)
  (let ((p nil))
    (setq p (- (fourk-current-column) (fourk-current-indentation)))
    (fourk-delete-indentation)
    (beginning-of-line)
    (indent-to x)
    (if (> p 0) (forward-char p))))

(defun fourk-delete-indentation ()
  (save-excursion
    (delete-region 
     (progn (beginning-of-line) (point)) 
     (progn (back-to-indentation) (point)))))

(defun fourk-indent-command ()
  (interactive)
  (fourk-indent-line t))

;; remove trailing whitespaces in current line
(defun fourk-remove-trailing ()
  (save-excursion
    (end-of-line)
    (delete-region (point) (progn (skip-chars-backward " \t") (point)))))

;; insert newline, removing any trailing whitespaces in the current line
(defun fourk-newline-remove-trailing ()
  (save-excursion
    (delete-region (point) (progn (skip-chars-backward " \t") (point))))
  (newline))
;  (let ((was-point (point-marker)))
;    (unwind-protect 
;	(progn (forward-line -1) (fourk-remove-trailing))
;      (goto-char (was-point)))))

;; workaround for bug in `reindent-then-newline-and-indent'
(defun fourk-reindent-then-newline-and-indent ()
  (interactive "*")
  (indent-according-to-mode)
  (fourk-newline-remove-trailing)
  (indent-according-to-mode))


;;; Block file encoding/decoding  (dk)
;;;

(defconst fourk-c/l 64 "Number of characters per block line")
(defconst fourk-l/b 16 "Number of lines per block")

;; Check whether the unconverted block file line, point is in, does not
;; contain `\n' and `\t' characters.
(defun fourk-check-block-line (line)
  (let ((end (save-excursion (beginning-of-line) (forward-char fourk-c/l)
			     (point))))
    (save-excursion 
      (beginning-of-line)
      (when (search-forward "\n" end t)
	(message "Warning: line %i contains newline character #10" line)
	(ding t))
      (beginning-of-line)
      (when (search-forward "\t" end t)
	(message "Warning: line %i contains tab character #8" line)
	(ding t)))))

(defun fourk-convert-from-block (from to)
  "Convert block file format to stream source in current buffer."
  (let ((line (count-lines (point-min) from)))
    (save-excursion
      (goto-char from)
      (set-mark to)
      (while (< (+ (point) fourk-c/l) (mark t))
	(setq line (1+ line))
	(fourk-check-block-line line)
	(forward-char fourk-c/l)
	(fourk-newline-remove-trailing))
      (when (= (+ (point) fourk-c/l) (mark t))
	(fourk-remove-trailing))
      (mark t))))

;; Pad a line of a block file up to `fourk-c/l' characters, positioning `point'
;; at the end of line.
(defun fourk-pad-block-line ()
  (save-excursion
    (end-of-line)
    (if (<= (current-column) fourk-c/l)
	(move-to-column fourk-c/l t)
      (message "Line %i longer than %i characters, truncated"
	       (count-lines (point-min) (point)) fourk-c/l)
      (ding t)
      (move-to-column fourk-c/l t)
      (delete-region (point) (progn (end-of-line) (point))))))

;; Replace tab characters in current line by spaces.
(defun fourk-convert-tabs-in-line ()
  (save-excursion
    (beginning-of-line)
    (while (search-forward "\t" (save-excursion (end-of-line) (point)) t)
      (backward-char)
      (delete-region (point) (1+ (point)))
      (insert-char ?\  (- tab-width (% (current-column) tab-width))))))

;; Delete newline at end of current line, concatenating it with the following
;; line. Place `point' at end of newly formed line.
(defun fourk-delete-newline ()
  (end-of-line)
  (delete-region (point) (progn (beginning-of-line 2) (point))))

(defun fourk-convert-to-block (from to &optional original-buffer) 
  "Convert range of text to block file format in current buffer."
  (let* ((lines 0)) ; I have to count lines myself, since `count-lines' has
		    ; problems with trailing newlines...
    (save-excursion
      (goto-char from)
      (set-mark to)
      ;; pad lines to full length (`fourk-c/l' characters per line)
      (while (< (save-excursion (end-of-line) (point)) (mark t))
	(setq lines (1+ lines))
	(fourk-pad-block-line)
	(fourk-convert-tabs-in-line)
	(forward-line))
      ;; also make sure the last line is padded, if `to' is at its end
      (end-of-line)
      (when (= (point) (mark t))
	(setq lines (1+ lines))
	(fourk-pad-block-line)
	(fourk-convert-tabs-in-line))
      ;; remove newlines between lines
      (goto-char from)
      (while (< (save-excursion (end-of-line) (point)) (mark t))
	(fourk-delete-newline))
      ;; append empty lines, until last block is complete
      (goto-char (mark t))
      (let* ((required (* (/ (+ lines (1- fourk-l/b)) fourk-l/b) fourk-l/b))
	     (pad-lines (- required lines)))
	(while (> pad-lines 0)
	  (insert-char ?\  fourk-c/l)
	  (setq pad-lines (1- pad-lines))))
      (point))))

(defun fourk-detect-block-file-p ()
  "Return non-nil if the current buffer is in block file format. Detection is
done by checking whether the first line has 1024 characters or more."
  (save-restriction 
    (widen)
    (save-excursion
       (goto-char (point-min))
       (end-of-line)
       (>= (current-column) 1024))))

;; add block file conversion routines to `format-alist'
(defconst fourk-block-format-description
  '(fourk-blocks "Fourk block source file" nil 
		 fourk-convert-from-block fourk-convert-to-block 
		 t normal-mode))
(unless (memq fourk-block-format-description format-alist)
  (setq format-alist (cons fourk-block-format-description format-alist)))

;;; End block file encoding/decoding

;;; Block file editing
;;;
(defvar fourk-overlay-arrow-string ">>")
(defvar fourk-block-base 1 "Number of first block in block file")
(defvar fourk-show-screen nil
  "Non-nil means to show screen starts and numbers (for block files)")
(defvar fourk-warn-long-lines nil
  "Non-nil means to warn about lines that are longer than 64 characters")

(defvar fourk-screen-marker nil)
(defvar fourk-screen-number-string nil)

(defun fourk-update-show-screen ()
  "If `fourk-show-screen' is non-nil, put overlay arrow to start of screen, 
`point' is in. If arrow now points to different screen than before, display 
screen number."
  (if (not fourk-show-screen)
      (setq overlay-arrow-string nil)
    (save-excursion
      (let* ((line (count-lines (point-min) (min (point-max) (1+ (point)))))
	     (first-line (1+ (* (/ (1- line) fourk-l/b) fourk-l/b)))
	     (scr (+ fourk-block-base (/ first-line fourk-l/b))))
	(setq overlay-arrow-string fourk-overlay-arrow-string)
	(goto-line first-line)
	(setq overlay-arrow-position fourk-screen-marker)
	(set-marker fourk-screen-marker 
		    (save-excursion (goto-line first-line) (point)))
	(setq fourk-screen-number-string (format "%d" scr))))))

(add-hook 'fourk-motion-hooks 'fourk-update-show-screen)

(defun fourk-update-warn-long-lines ()
  "If `fourk-warn-long-lines' is non-nil, display a warning whenever a line
exceeds 64 characters."
  (when fourk-warn-long-lines
    (when (> (save-excursion (end-of-line) (current-column)) fourk-c/l)
      (message "Warning: current line exceeds %i characters"
	       fourk-c/l))))

(add-hook 'fourk-motion-hooks 'fourk-update-warn-long-lines)

;;; End block file editing


(defvar fourk-mode-abbrev-table nil
  "Abbrev table in use in Fourk-mode buffers.")

(define-abbrev-table 'fourk-mode-abbrev-table ())

(defvar fourk-mode-map nil
  "Keymap used in Fourk mode.")

(if (not fourk-mode-map)
    (setq fourk-mode-map (make-sparse-keymap)))

;(define-key fourk-mode-map "\M-\C-x" 'compile)
(define-key fourk-mode-map "\C-x\\" 'comment-region)
(define-key fourk-mode-map "\C-x~" 'fourk-remove-tracers)
(define-key fourk-mode-map "\C-x\C-m" 'fourk-split)
(define-key fourk-mode-map "\e " 'fourk-reload)
(define-key fourk-mode-map "\t" 'fourk-indent-command)
(define-key fourk-mode-map "\C-m" 'fourk-reindent-then-newline-and-indent)
(define-key fourk-mode-map "\M-q" 'fourk-fill-paragraph)
(define-key fourk-mode-map "\e." 'fourk-find-tag)

;; setup for C-h C-i to work
(eval-and-compile (fourk-require 'info-look))
(when (memq 'info-look features)
  (defvar fourk-info-lookup '(symbol (fourk-mode "\\S-+" t 
						  (("(gfourk)Word Index"))
						  "\\S-+")))
  (unless (memq fourk-info-lookup info-lookup-alist)
    (setq info-lookup-alist (cons fourk-info-lookup info-lookup-alist)))
  ;; in X-Emacs C-h C-i is by default bound to Info-query
  (define-key fourk-mode-map "\C-h\C-i" 'info-lookup-symbol))


;;   (info-lookup-add-help
;;    :topic 'symbol
;;    :mode 'fourk-mode
;;    :regexp "[^ 	
;; ]+"
;;    :ignore-case t
;;    :doc-spec '(("(gfourk)Name Index" nil "`" "'  "))))

(require 'etags)

(defun fourk-find-tag (tagname &optional next-p regexp-p)
  (interactive (find-tag-interactive "Find tag: "))
  (unless (or regexp-p next-p)
    (setq tagname (concat "\\(^\\|\\s-+\\)\\(" (regexp-quote tagname) 
			    "\\)\\s-*\x7f")))
  (switch-to-buffer
   (find-tag-noselect tagname next-p t)))

(defvar fourk-mode-syntax-table nil
  "Syntax table in use in Fourk-mode buffers.")

;; Important: hilighting/indentation now depends on a correct syntax table.
;; All characters, except whitespace *must* belong to the "word constituent"
;; syntax class. If different behaviour is required, use of Categories might
;; help.
(if (not fourk-mode-syntax-table)
    (progn
      (setq fourk-mode-syntax-table (make-syntax-table))
      (let ((char 0))
	(while (< char ?!)
	  (modify-syntax-entry char " " fourk-mode-syntax-table)
	  (setq char (1+ char)))
	(while (< char 256)
	  (modify-syntax-entry char "w" fourk-mode-syntax-table)
	  (setq char (1+ char))))
      ))

(defun fourk-mode-variables ()
  (set-syntax-table fourk-mode-syntax-table)
  (setq local-abbrev-table fourk-mode-abbrev-table)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start (concat "^$\\|" page-delimiter))
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'fourk-indent-line)
;  (make-local-variable 'require-final-newline)
;  (setq require-final-newline t)
  (make-local-variable 'comment-start)
  (setq comment-start "\\ ")
  ;(make-local-variable 'comment-end)
  ;(setq comment-end " )")
  (make-local-variable 'comment-column)
  (setq comment-column 40)
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "\\\\ ")
  (make-local-variable 'comment-indent-function)
  (setq comment-indent-function 'fourk-comment-indent)
  (make-local-variable 'parse-sexp-ignore-comments)
  (setq parse-sexp-ignore-comments t)
  (setq case-fold-search t)
  (make-local-variable 'fourk-was-point)
  (setq fourk-was-point -1)
  (make-local-variable 'fourk-words)
  (make-local-variable 'fourk-compiled-words)
  (make-local-variable 'fourk-compiled-indent-words)
  (make-local-variable 'fourk-hilight-level)
  (make-local-variable 'after-change-functions)
  (make-local-variable 'fourk-show-screen)
  (make-local-variable 'fourk-screen-marker)
  (make-local-variable 'fourk-warn-long-lines)
  (make-local-variable 'fourk-screen-number-string)
  (make-local-variable 'fourk-use-oof)
  (make-local-variable 'fourk-use-objects) 
  (setq fourk-screen-marker (copy-marker 0))
  (add-hook 'after-change-functions 'fourk-change-function)
  (if (and fourk-jit-parser (>= emacs-major-version 21))
      (add-hook 'fontification-functions 'fourk-fontification-function))
  (setq imenu-create-index-function 'fourk-create-index))

;;;###autoload
(defun fourk-mode ()
  "
Major mode for editing Fourk code. Tab indents for Fourk code. Comments
are delimited with \\ and newline. Paragraphs are separated by blank lines
only. Block files are autodetected, when read, and converted to normal 
stream source format. See also `fourk-block-mode'.
\\{fourk-mode-map}

Variables controlling syntax hilighting/recognition of parsed text:
 `fourk-words'
    List of words that have a special parsing behaviour and/or should be
    hilighted. Add custom words by setting fourk-custom-words in your
    .emacs, or by setting fourk-local-words, in source-files' local 
    variables lists.
 fourk-use-objects
    Set this variable to non-nil in your .emacs, or in a local variables 
    list, to hilight and recognize the words from the \"Objects\" package 
    for object-oriented programming.
 fourk-use-oof
    Same as above, just for the \"OOF\" package.
 fourk-custom-words
    List of custom Fourk words to prepend to `fourk-words'. Should be set
    in your .emacs.
 fourk-local-words
    List of words to prepend to `fourk-words', whenever a fourk-mode
    buffer is created. That variable should be set by Fourk sources, using
    a local variables list at the end of file, to get file-specific
    hilighting.
    0 [IF]
       Local Variables: ... 
       fourk-local-words: ...
       End:
    [THEN]
 fourk-hilight-level
    Controls how much syntax hilighting is done. Should be in the range 
    0..3

Variables controlling indentation style:
 `fourk-indent-words'
    List of words that influence indentation.
 fourk-local-indent-words
    List of words to prepend to `fourk-indent-words', similar to 
    fourk-local-words. Should be used for specifying file-specific 
    indentation, using a local variables list.
 fourk-custom-indent-words
    List of words to prepend to `fourk-indent-words'. Should be set in your
    .emacs.    
 fourk-indent-level
    Indentation increment/decrement of Fourk statements.
 fourk-minor-indent-level
    Minor indentation increment/decrement of Fourk statemens.

Variables controlling block-file editing:
 fourk-show-screen
    Non-nil means, that the start of the current screen is marked by an
    overlay arrow, and screen numbers are displayed in the mode line.
    This variable is by default nil for `fourk-mode' and t for 
    `fourk-block-mode'.
 fourk-overlay-arrow-string
    String to display as the overlay arrow, when `fourk-show-screen' is t.
    Setting this variable to nil disables the overlay arrow.
 fourk-block-base
    Screen number of the first block in a block file. Defaults to 1.
 fourk-warn-long-lines
    Non-nil means that a warning message is displayed whenever you edit or
    move over a line that is longer than 64 characters (the maximum line
    length that can be stored into a block file). This variable defaults to
    t for `fourk-block-mode' and to nil for `fourk-mode'.

Variables controlling interaction with the Fourk-process (also see
`run-fourk'):
  fourk-program-name
    Program invoked by the `run-fourk' command (including arguments).
  inferior-fourk-mode-hook
    Hook for customising inferior-fourk-mode.
  fourk-compile-command
    Default command to execute on `compile'.
" 
  (interactive)
  (kill-all-local-variables)
  (use-local-map fourk-mode-map)
  (setq mode-name "Fourk")
  (setq major-mode 'fourk-mode)
  (fourk-install-motion-hook)
  ;; convert buffer contents from block file format, if necessary
  (when (fourk-detect-block-file-p)
    (widen)
    (message "Converting from Fourk block source...")
    (fourk-convert-from-block (point-min) (point-max))
    (message "Converting from Fourk block source...done"))
  ;; if user switched from fourk-block-mode to fourk-mode, make sure the file
  ;; is now stored as normal strem source
  (when (equal buffer-file-format '(fourk-blocks))
    (setq buffer-file-format nil))
  (fourk-mode-variables)
;  (if (not (fourk-process-running-p))
;      (run-fourk fourk-program-name))
  (run-hooks 'fourk-mode-hook))

;;;###autoload
(define-derived-mode fourk-block-mode fourk-mode "Fourk Block Source" 
  "Major mode for editing Fourk block source files, derived from 
`fourk-mode'. Differences to `fourk-mode' are:
 * files are converted to block format, when written (`buffer-file-format' 
   is set to `(fourk-blocks)')
 * `fourk-show-screen' and `fourk-warn-long-lines' are t by default
  
Note that the length of lines in block files is limited to 64 characters.
When writing longer lines to a block file, a warning is displayed in the
echo area and the line is truncated. 

Another problem is imposed by block files that contain newline or tab 
characters. When Emacs converts such files back to block file format, 
it'll translate those characters to a number of spaces. However, when
you read such a file, a warning message is displayed in the echo area,
including a line number that may help you to locate and fix the problem.

So have a look at the *Messages* buffer, whenever you hear (or see) Emacs' 
bell during block file read/write operations."
  (setq buffer-file-format '(fourk-blocks))
  (setq fourk-show-screen t)
  (setq fourk-warn-long-lines t)
  (setq fourk-screen-number-string (format "%d" fourk-block-base))
  (setq mode-line-format (append (reverse (cdr (reverse mode-line-format)))
				 '("--S" fourk-screen-number-string "-%-"))))

(add-hook 'fourk-mode-hook
      '(lambda () 
	 (make-local-variable 'compile-command)
	 (setq compile-command "gfourk ")
	 (fourk-hack-local-variables)
	 (fourk-customize-words)
	 (fourk-compile-words)
	 (unless (and fourk-jit-parser (>= emacs-major-version 21))
	   (fourk-change-function (point-min) (point-max) nil t))))

(defun fourk-fill-paragraph () 
  "Fill comments (starting with '\'; do not fill code (block style
programmers who tend to fill code won't use emacs anyway:-)."
  ; Currently only comments at the start of the line are filled.
  ; Something like lisp-fill-paragraph may be better.  We cannot use
  ; fill-paragraph, because it removes the \ from the first comment
  ; line. Therefore we have to look for the first line of the comment
  ; and use fill-region.
  (interactive)
  (save-excursion
    (beginning-of-line)
    (while (and
	     (= (forward-line -1) 0)
	     (looking-at "[ \t]*\\\\g?[ \t]+")))
    (if (not (looking-at "[ \t]*\\\\g?[ \t]+"))
	(forward-line 1))
    (let ((from (point))
	  (to (save-excursion (forward-paragraph) (point))))
      (if (looking-at "[ \t]*\\\\g?[ \t]+")
	  (progn (goto-char (match-end 0))
		 (set-fill-prefix)
		 (fill-region from to nil))))))

(defun fourk-comment-indent ()
  (save-excursion
    (beginning-of-line)
    (if (looking-at ":[ \t]*")
	(progn
	  (end-of-line)
	  (skip-chars-backward " \t\n")
	  (1+ (current-column)))
      comment-column)))


;; Fourk commands

(defun fourk-remove-tracers ()
  "Remove tracers of the form `~~ '. Queries the user for each occurrence."
  (interactive)
  (query-replace-regexp "\\(~~ \\| ~~$\\)" "" nil))

(define-key fourk-mode-map "\C-x\C-e" 'compile)
(define-key fourk-mode-map "\C-x\C-n" 'next-error)
(require 'compile)

(defvar fourk-compile-command "gfourk ")
;(defvar fourk-compilation-window-percent-height 30)

(defun fourk-split ()
  (interactive)
  (fourk-split-1 "*fourk*"))

(defun fourk-split-1 (buffer)
  (if (not (eq (window-buffer) (get-buffer buffer)))
      (progn
	(delete-other-windows)
	(split-window-vertically
	 (/ (* (screen-height) fourk-percent-height) 100))
	(other-window 1)
	(switch-to-buffer buffer)
	(goto-char (point-max))
	(other-window 1))))

(defun fourk-compile (command)
  (interactive (list (setq fourk-compile-command (read-string "Compile command: " fourk-compile-command))))
  (fourk-split-1 "*compilation*")
  (setq ctools-compile-command command)
  (compile1 ctools-compile-command "No more errors"))

;;; Fourk menu
;;; Mikael Karlsson <qramika@eras70.ericsson.se>

;; (dk) code commented out due to complaints of XEmacs users.  After
;; all, there's imenu/speedbar, which uses much smarter scanning
;; rules.

;; (cond ((string-match "XEmacs\\|Lucid" emacs-version)
;;        (require 'func-menu)

;;   (defconst fume-function-name-regexp-fourk
;;    "^\\(:\\)[ \t]+\\([^ \t]*\\)"
;;    "Expression to get word definitions in Fourk.")

;;   (setq fume-function-name-regexp-alist
;;       (append '((fourk-mode . fume-function-name-regexp-fourk) 
;;              ) fume-function-name-regexp-alist))

;;   ;; Find next fourk word in the buffer
;;   (defun fume-find-next-fourk-function-name (buffer)
;;     "Searches for the next fourk word in BUFFER."
;;     (set-buffer buffer)
;;     (if (re-search-forward fume-function-name-regexp nil t)
;;       (let ((beg (match-beginning 2))
;;             (end (match-end 2)))
;;         (cons (buffer-substring beg end) beg))))

;;   (setq fume-find-function-name-method-alist
;;   (append '((fourk-mode    . fume-find-next-fourk-function-name))))

;;   ))
;;; End Fourk menu

;;; File folding of fourk-files
;;; uses outline
;;; Toggle activation with M-x fold-f (when editing a fourk-file) 
;;; Use f9 to expand, f10 to hide, Or the menubar in xemacs
;;;
;;; Works most of the times but loses sync with the cursor occasionally 
;;; Could be improved by also folding on comments

;; (dk) This code needs a rewrite; just too ugly and doesn't use the
;; newer and smarter scanning rules of `imenu'. Who needs it anyway??

;; (require 'outline)

;; (defun f-outline-level ()
;;   (cond	((looking-at "\\`\\\\")
;; 	 0)
;; 	((looking-at "\\\\ SEC")
;; 	 0)
;; 	((looking-at "\\\\ \\\\ .*")
;; 	 0)
;; 	((looking-at "\\\\ DEFS")
;; 	 1)
;; 	((looking-at "\\/\\* ")
;; 	 1)
;; 	((looking-at ": .*")
;; 	 1)
;; 	((looking-at "\\\\G")
;; 	 2)
;; 	((looking-at "[ \t]+\\\\")
;; 	 3)))
  
;; (defun fold-f  ()
;;    (interactive)
;;    (add-hook 'outline-minor-mode-hook 'hide-body)

;;    ; outline mode header start, i.e. find word definitions
;; ;;;   (setq  outline-regexp  "^\\(:\\)[ \t]+\\([^ \t]*\\)")
;;    (setq  outline-regexp  "\\`\\\\\\|:\\|\\\\ SEC\\|\\\\G\\|[ \t]+\\\\\\|\\\\ DEFS\\|\\/\\*\\|\\\\ \\\\ .*")
;;    (setq outline-level 'f-outline-level)

;;    (outline-minor-mode)
;;    (define-key outline-minor-mode-map '(shift up) 'hide-sublevels)
;;    (define-key outline-minor-mode-map '(shift right) 'show-children)
;;    (define-key outline-minor-mode-map '(shift left) 'hide-subtree)
;;    (define-key outline-minor-mode-map '(shift down) 'show-subtree))


;;(define-key global-map '(shift up) 'fold-f)

;;; end file folding

;;; func-menu is a package that scans your source file for function definitions
;;; and makes a menubar entry that lets you jump to any particular function
;;; definition by selecting it from the menu.  The following code turns this on
;;; for all of the recognized languages.  Scanning the buffer takes some time,
;;; but not much.
;;;
;; (cond ((string-match "XEmacs\\|Lucid" emacs-version)
;;        (require 'func-menu)
;; ;;       (define-key global-map 'f8 'function-menu)
;;        (add-hook 'find-fible-hooks 'fume-add-menubar-entry)
;; ;       (define-key global-map "\C-cg" 'fume-prompt-function-goto)
;; ;       (define-key global-map '(shift button3) 'mouse-function-menu)
;; ))

;;;
;;; Inferior Fourk interpreter 
;;;	-- mostly copied from `cmuscheme.el' of Emacs 21.2
;;;

(eval-and-compile (fourk-require 'comint))

(when (memq 'comint features)

  (defvar fourk-program-name "gfourk"
    "*Program invoked by the `run-fourk' command, including program arguments")

  (defcustom inferior-fourk-mode-hook nil
    "*Hook for customising inferior-fourk-mode."
    :type 'hook
    :group 'fourk)

  (defvar inferior-fourk-mode-map
    (let ((m (make-sparse-keymap)))
      (define-key m "\r" 'comint-send-input)
      (define-key m "\M-\C-x" 'fourk-send-paragraph-and-go)
      (define-key m "\C-c\C-l" 'fourk-load-file)
      m))
  ;; Install the process communication commands in the fourk-mode keymap.
  (define-key fourk-mode-map "\e\C-m" 'fourk-send-paragraph-and-go)
  (define-key fourk-mode-map "\eo" 'fourk-send-buffer-and-go)

  (define-key fourk-mode-map "\M-\C-x" 'fourk-send-paragraph-and-go)
  (define-key fourk-mode-map "\C-c\C-r" 'fourk-send-region)
  (define-key fourk-mode-map "\C-c\M-r" 'fourk-send-region-and-go)
  (define-key fourk-mode-map "\C-c\C-z" 'fourk-switch-to-interactive)
  (define-key fourk-mode-map "\C-c\C-l" 'fourk-load-file)

  (defvar fourk-process-buffer)

  (define-derived-mode inferior-fourk-mode comint-mode "Inferior Fourk"
    "Major mode for interacting with an inferior Fourk process.

The following commands are available:
\\{inferior-fourk-mode-map}

A Fourk process can be fired up with M-x run-fourk.

Customisation: Entry to this mode runs the hooks on comint-mode-hook and
inferior-fourk-mode-hook (in that order).

You can send text to the inferior Fourk process from other buffers containing
Fourk source.
    fourk-switch-to-interactive switches the current buffer to the Fourk
        process buffer. 
    fourk-send-paragraph sends the current paragraph to the Fourk process.
    fourk-send-region sends the current region to the Fourk process.
    fourk-send-buffer sends the current buffer to the Fourk process.

    fourk-send-paragraph-and-go, fourk-send-region-and-go,
        fourk-send-buffer-and-go switch to the Fourk process buffer after
        sending their text.
For information on running multiple processes in multiple buffers, see
documentation for variable `fourk-process-buffer'.

Commands:
Return after the end of the process' output sends the text from the
end of process to point. If you accidentally suspend your process, use
\\[comint-continue-subjob] to continue it. "
    ;; Customise in inferior-fourk-mode-hook
    (setq comint-prompt-regexp "^") 
    (setq mode-line-process '(":%s")))

  (defun fourk-args-to-list (string)
    (let ((where (string-match "[ \t]" string)))
      (cond ((null where) (list string))
	    ((not (= where 0))
	     (cons (substring string 0 where)
		   (fourk-args-to-list (substring string (+ 1 where)
						  (length string)))))
	    (t (let ((pos (string-match "[^ \t]" string)))
		 (if (null pos)
		     nil
		   (fourk-args-to-list (substring string pos
						  (length string)))))))))

;;;###autoload
  (defun run-fourk (cmd)
    "Run an inferior Fourk process, input and output via buffer *fourk*.
If there is a process already running in `*fourk*', switch to that buffer.
With argument, allows you to edit the command line (default is value
of `fourk-program-name').  Runs the hooks `inferior-fourk-mode-hook'
\(after the `comint-mode-hook' is run).
\(Type \\[describe-mode] in the process buffer for a list of commands.)"

    (interactive (list (if current-prefix-arg
			   (read-string "Run Fourk: " fourk-program-name)
			 fourk-program-name)))
    (if (not (comint-check-proc "*fourk*"))
	(let ((cmdlist (fourk-args-to-list cmd)))
	  (set-buffer (apply 'make-comint "fourk" (car cmdlist)
			     nil (cdr cmdlist)))
	  (inferior-fourk-mode)))
    (setq fourk-program-name cmd)
    (setq fourk-process-buffer "*fourk*")
    (pop-to-buffer "*fourk*"))

  (defun fourk-send-region (start end)
    "Send the current region to the inferior Fourk process."
    (interactive "r")
    (comint-send-region (fourk-proc) start end)
    (comint-send-string (fourk-proc) "\n"))

  (defun fourk-end-of-paragraph ()
    (if (looking-at "[\t\n ]+") (skip-chars-backward  "\t\n "))
    (if (not (re-search-forward "\n[ \t]*\n" nil t))
	(goto-char (point-max))))

  (defun fourk-send-paragraph ()
    "Send the current or the previous paragraph to the Fourk process"
    (interactive)
    (let (end)
      (save-excursion
	(fourk-end-of-paragraph)
	(skip-chars-backward  "\t\n ")
	(setq end (point))
	(if (re-search-backward "\n[ \t]*\n" nil t)
	    (setq start (point))
	  (goto-char (point-min)))
	(skip-chars-forward  "\t\n ")
	(fourk-send-region (point) end))))

  (defun fourk-send-paragraph-and-go ()
    "Send the current or the previous paragraph to the Fourk process.
Then switch to the process buffer."
    (interactive)
    (fourk-send-paragraph)
    (fourk-switch-to-interactive t))

  (defun fourk-send-buffer ()
    "Send the current buffer to the Fourk process."
    (interactive)
    (if (eq (current-buffer) fourk-process-buffer)
	(error "Not allowed to send this buffer's contents to Fourk"))
    (fourk-send-region (point-min) (point-max)))

  (defun fourk-send-buffer-and-go ()
    "Send the current buffer to the Fourk process.
Then switch to the process buffer."
    (interactive)
    (fourk-send-buffer)
    (fourk-switch-to-interactive t))


  (defun fourk-switch-to-interactive (eob-p)
    "Switch to the Fourk process buffer.
With argument, position cursor at end of buffer."
    (interactive "P")
    (if (get-buffer fourk-process-buffer)
	(pop-to-buffer fourk-process-buffer)
      (error "No current process buffer.  See variable `fourk-process-buffer'"))
    (cond (eob-p
	   (push-mark)
	   (goto-char (point-max)))))

  (defun fourk-send-region-and-go (start end)
    "Send the current region to the inferior Fourk process.
Then switch to the process buffer."
    (interactive "r")
    (fourk-send-region start end)
    (fourk-switch-to-interactive t))

  (defcustom fourk-source-modes '(fourk-mode fourk-block-mode)
    "*Used to determine if a buffer contains Fourk source code.
If it's loaded into a buffer that is in one of these major modes, it's
considered a Fourk source file by `fourk-load-file' and `fourk-compile-file'.
Used by these commands to determine defaults."
    :type '(repeat function)
    :group 'fourk)

  (defvar fourk-prev-l/c-dir/file nil
    "Caches the last (directory . file) pair.
Caches the last pair used in the last `fourk-load-file' or
`fourk-compile-file' command. Used for determining the default in the
next one.")

  (defun fourk-load-file (file-name)
    "Load a Fourk file FILE-NAME into the inferior Fourk process."
    (interactive (comint-get-source "Load Fourk file: " fourk-prev-l/c-dir/file
				    fourk-source-modes t)) ; T because LOAD
					; needs an exact name
    (comint-check-source file-name) ; Check to see if buffer needs saved.
    (setq fourk-prev-l/c-dir/file (cons (file-name-directory    file-name)
					(file-name-nondirectory file-name)))
    (comint-send-string (fourk-proc) (concat "(load \""
					     file-name
					     "\"\)\n")))


  
  (defvar fourk-process-buffer nil "*The current Fourk process buffer.

See `scheme-buffer' for an explanation on how to run multiple Fourk 
processes.")

  (defun fourk-proc ()
    "Return the current Fourk process.  See variable `fourk-process-buffer'."
    (let ((proc (get-buffer-process (if (eq major-mode 'inferior-fourk-mode)
					(current-buffer)
				      fourk-process-buffer))))
      (or proc
	  (error "No current process.  See variable `fourk-process-buffer'"))))
  )  ; (memq 'comint features)

(provide 'fourk-mode)

;;; gfourk.el ends here
