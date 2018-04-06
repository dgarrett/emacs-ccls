;;; -*- lexical-binding: t; -*-

;; Copyright (C) 2017 Tobias Pisani
;; Copyright (C) 2018 Fangrui Song

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and-or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Code:

(require 'ccls-common)

;; ---------------------------------------------------------------------
;;   Customization
;; ---------------------------------------------------------------------

(defgroup ccls-sem nil
  "ccls semantic highlighting."
  :group 'tools
  :group 'ccls)

(defface ccls-inactive-region-face
  '((t :inherit shadow))
  "The face used to mark inactive regions."
  :group 'ccls-sem)

(defvar ccls-sem-face-function 'ccls-sem--default-face
  "Function used to determine the face of a symbol in semantic highlighting.")

(defface ccls-sem-global-variable-face
  '((t :weight extra-bold))
  "The additional face for global variables."
  :group 'ccls-sem)

(defface ccls-sem-local-face
  '((t :weight normal))
  "The additional face for local entities."
  :group 'ccls-sem)

(defface ccls-sem-local-function-face
  '((t :inherit ccls-sem-local-face))
  "The additional face for local functions."
  :group 'ccls-sem)

(defface ccls-sem-member-face
  '((t :slant italic))
  "The extra face applied to member functions/variables."
  :group 'ccls-sem)

(defface ccls-sem-static-face
  '((t :weight bold))
  "The additional face for variables with static storage."
  :group 'ccls-sem)

(defface ccls-sem-static-field-face
  '((t :inherit ccls-sem-static-face))
  "The additional face for static member variables."
  :group 'ccls-sem)

(defface ccls-sem-static-method-face
  '((t :inherit ccls-sem-static-face))
  "The additional face for static member functions."
  :group 'ccls-sem)

(defcustom ccls-sem-function-faces [font-lock-function-name-face]
  "Faces for functions."
  :type '(repeat face)
  :group 'ccls-sem)

(defcustom ccls-sem-macro-faces [font-lock-variable-name-face]
  "Faces for macros."
  :type '(repeat face)
  :group 'ccls-sem)

(defcustom ccls-sem-namespace-faces [font-lock-constant-face]
  "Faces for namespaces."
  :type '(repeat face)
  :group 'ccls-sem)

(defcustom ccls-sem-parameter-faces [font-lock-variable-name-face]
  "Faces for parameters."
  :type '(repeat face)
  :group 'ccls-sem)

(defcustom ccls-sem-type-faces [font-lock-type-face]
  "Faces used to mark types."
  :type '(repeat face)
  :group 'ccls-sem)

(defcustom ccls-sem-variable-faces [font-lock-variable-name-face]
  "Faces for variables."
  :type '(repeat face)
  :group 'ccls-sem)

;; Default colors used by `ccls-use-default-rainbow-sem-highlight'
(defcustom ccls-sem-function-colors
  '("#e5b124" "#927754" "#eb992c" "#e2bf8f" "#d67c17"
    "#88651e" "#e4b953" "#a36526" "#b28927" "#d69855")
  "Default colors for `ccls-sem-function-faces'."
  :type '(repeat color)
  :group 'ccls-sem)

(defcustom ccls-sem-macro-colors
  '("#e79528" "#c5373d" "#e8a272" "#d84f2b" "#a67245"
    "#e27a33" "#9b4a31" "#b66a1e" "#e27a71" "#cf6d49")
  "Default colors for `ccls-sem-macro-faces'."
  :type '(repeat color)
  :group 'ccls-sem)

(defcustom ccls-sem-namespace-colors
  '("#429921" "#58c1a4" "#5ec648" "#36815b" "#83c65d"
    "#417b2f" "#43cc71" "#7eb769" "#58bf89" "#3e9f4a")
  "Default colors for `ccls-sem-namespace-faces'."
  :type '(repeat color)
  :group 'ccls-sem)

(defcustom ccls-sem-parameter-colors
  '("#429921" "#58c1a4" "#5ec648" "#36815b" "#83c65d"
    "#417b2f" "#43cc71" "#7eb769" "#58bf89" "#3e9f4a")
  "Default colors for `ccls-sem-parameter-faces'."
  :type '(repeat color)
  :group 'ccls-sem)

(defcustom ccls-sem-type-colors
  '("#e1afc3" "#d533bb" "#9b677f" "#e350b6" "#a04360"
    "#dd82bc" "#de3864" "#ad3f87" "#dd7a90" "#e0438a")
  "Default colors for `ccls-sem-type-faces'."
  :type '(repeat color)
  :group 'ccls-sem)

(defcustom ccls-sem-variable-colors
  ccls-sem-parameter-colors
  "Default colors for `ccls-sem-variable-faces'."
  :type '(repeat color)
  :group 'ccls-sem)

(defcustom ccls-enable-inactive-region
  t
  "Enable inactive region.
Regions that are disabled by preprocessors will be displayed in shadow."
  :group 'ccls-sem
  :type 'bool)

(defcustom ccls-sem-highlight-method
  nil
  "The method used to draw semantic highlighting.
overlays are more accurate than font-lock, but slower.
If nil, disable semantic highlighting."
  :group 'ccls-sem
  :type '(radio
          (const nil)
          (const :tag "overlay" overlay)
          (const :tag "font-lock" font-lock)))

;; ---------------------------------------------------------------------
;;   Semantic highlighting
;; ---------------------------------------------------------------------

(defvar-local ccls--inactive-overlays nil "Inactive overlays.")
(defvar-local ccls--sem-overlays nil "Semantic highlighting overlays.")

(defun ccls--clear-sem-highlights ()
  "."
  (pcase ccls-sem-highlight-method
    ('overlay
     (while ccls--sem-overlays
       (delete-overlay (pop ccls--sem-overlays))))
    ('font-lock
     (font-lock-ensure))))

(defun ccls-sem--default-face (symbol)
  "Get semantic highlighting face of SYMBOL."
  ;; https://github.com/ccls-project/ccls/blob/master/src/symbol.h
  (-let* (((&hash "type" type "kind" kind "storage" storage
                  "parentKind" parent-kind "stableId" stable-id) symbol)
         (fn0 (lambda (faces lo0 hi0)
                (let* ((n (length faces))
                       (lo (/ (* lo0 n) 1000))
                       (hi (/ (* hi0 n) 1000))
                       (idx (max 0 (if (= lo hi) (1- hi) (+ lo (% stable-id (- hi lo)))))))
                  (elt faces idx))))
         (fn (lambda (faces) (elt faces (% stable-id (length faces))))))
    ;; ccls/src/indexer.h ClangSymbolKind
    ;; clang/Index/IndexSymbol.h clang::index::SymbolKind
    (pcase kind
      ;; Functions
      (6 `(,(funcall fn0 ccls-sem-function-faces 0 800)
           ccls-sem-member-face)) ; Method
      (9 `(,(funcall fn0 ccls-sem-function-faces 800 1000)
           ccls-sem-member-face)) ; Constructor
      (12 `(,(funcall fn0 ccls-sem-function-faces 0 1000)
            ,@(when (= storage 3)
                '(ccls-sem-local-function-face)))) ; Function
      (254 `(,(funcall fn0 ccls-sem-function-faces 0 1000)
             ccls-sem-static-method-face)) ; StaticMethod

      ;; Types
      (3 (funcall fn0 ccls-sem-namespace-faces 0 1000)) ; Namespace
      ((or 5 23) (funcall fn0 ccls-sem-type-faces 0 800)) ; Struct, Class
      (10 (funcall fn0 ccls-sem-type-faces 800 1000)) ; Enum
      (26 (funcall fn0 ccls-sem-type-faces 0 1000)) ; TypeParameter
      (252 `(,(funcall fn0 ccls-sem-type-faces 0 1000)
            ccls-sem-member-face)) ; TypeAlias

      ;; Variables
      (13 `(,(funcall fn0 ccls-sem-variable-faces 0 1000)
            ,@(when (member parent-kind '(1 3))
                '(ccls-sem-global-variable-face))
            ,@(when (= storage 3)
                '(ccls-sem-static-face)))) ; Variable
      (253 (funcall fn0 ccls-sem-parameter-faces 0 1000)) ; Parameter
      (255 (funcall fn0 ccls-sem-macro-faces 0 1000)) ; Macro
      (8 `(,(funcall fn0 ccls-sem-variable-faces 0 1000)
           ,(if (= storage 3)
                'ccls-sem-static-field-face
              'ccls-sem-member-face
              ))) ; Field
      (22 `(,(funcall fn0 ccls-sem-variable-faces 0 1000)
            ccls-sem-member-face)) ; EnumMember

      (_ (pcase type
           (0 (funcall fn ccls-sem-type-faces))
           (1 (funcall fn ccls-sem-function-faces))
           (_ (funcall fn ccls-sem-variable-faces)))))))

(defun ccls--publish-semantic-highlighting (_workspace params)
  "Publish semantic highlighting information according to PARAMS."
  (when ccls-sem-highlight-method
    (-when-let* ((file (lsp--uri-to-path (gethash "uri" params)))
                 (buffer (find-buffer-visiting file))
                 (symbols (gethash "symbols" params)))
      (with-current-buffer buffer
        (save-excursion
          (with-silent-modifications
            (ccls--clear-sem-highlights)
            (let (ranges point0 point1 (line 0) overlays)
              (dolist (symbol symbols)
                (-when-let* ((face (funcall ccls-sem-face-function symbol)))
                  (dolist (range (gethash "ranges" symbol))
                    (-let (((&hash "start" start "end" end) range))
                      (push (list (gethash "line" start) (gethash "character" start)
                                  (gethash "line" end) (gethash "character" end) face) ranges)))))
              ;; Sort by start-line ASC, start-character ASC.
              ;; The server guarantees the ranges are non-overlapping.
              (setq ranges
                    (sort ranges (lambda (x y)
                                   (let ((x0 (car x)) (y0 (car y)))
                                     (if (/= x0 y0)
                                         (< x0 y0)
                                       (< (cadr x) (cadr y)))))))
              (widen)
              (goto-char 1)
              (dolist (range ranges)
                (-let (((l0 c0 l1 c1 face) range))
                  (forward-line (- l0 line))
                  (forward-char c0)
                  (setq point0 (point))
                  (forward-line (- l1 l0))
                  (forward-char c1)
                  (setq point1 (point))
                  (setq line l1)
                  (push (list point0 point1 face) overlays)))
              (pcase ccls-sem-highlight-method
                ('font-lock
                 (dolist (x overlays)
                   (set-text-properties (car x) (cadr x)
                                        `(fontified t face ,(caddr x) font-lock-face ,(caddr x)))))
                ('overlay
                 (dolist (x overlays)
                   (let ((ov (make-overlay (car x) (cadr x))))
                     (overlay-put ov 'face (caddr x))
                     (overlay-put ov 'ccls-sem-highlight t)
                     (push ov ccls--sem-overlays))))))))))))

(defmacro ccls-use-default-rainbow-sem-highlight ()
  "Use default rainbow semantic highlighting theme."
  (require 'dash)
  `(progn
     ,@(cl-loop
        for kind in '("function" "macro" "namespace" "parameter" "type" "variable") append
        (let ((colors (intern (format "ccls-sem-%s-colors" kind))))
          (append
           (--map-indexed
            `(defface ,(intern (format "ccls-sem-%s-face-%S" kind it-index))
               '((t :foreground ,it)) "." :group 'ccls-sem)
            (symbol-value colors))
           (list
            `(setq ,(intern (format "ccls-sem-%s-faces" kind))
                   (apply #'vector
                          (cl-loop for i below (length ,colors) collect
                                   (intern (format "ccls-sem-%s-face-%S" ,kind i)))))))))))

;; Add handler
(push '("$ccls/publishSemanticHighlighting" . (lambda (w p) (ccls--publish-semantic-highlighting w p)))
      ccls--handlers)

;; ---------------------------------------------------------------------
;;   Inactive regions
;; ---------------------------------------------------------------------

(defun ccls--clear-inactive-regions ()
  "Clean up overlays."
  (while ccls--inactive-overlays
    (delete-overlay (pop ccls--inactive-overlays))))

(defun ccls--set-inactive-regions (_workspace params)
  "Put overlays on (preprocessed) inactive regions according to PARAMS."
  (-when-let* ((file (lsp--uri-to-path (gethash "uri" params)))
               (regions (mapcar 'ccls--read-range (gethash "inactiveRegions" params)))
               (buffer (find-buffer-visiting file)))
    (with-current-buffer buffer
       (save-excursion
         (ccls--clear-inactive-regions)
         (when ccls-enable-inactive-region
           (overlay-recenter (point-max))
           (dolist (region regions)
             (let ((ov (make-overlay (car region) (cdr region) buffer)))
               (overlay-put ov 'face 'ccls-inactive-region-face)
               (overlay-put ov 'ccls-inactive t)
               (push ov ccls--inactive-overlays))))))))

;; Add handler
(push '("$ccls/setInactiveRegions" . (lambda (w p) (ccls--set-inactive-regions w p)))
      ccls--handlers)

(provide 'ccls-semantic-highlighting)