;;;###autoload
(with-eval-after-load 'lsp-mode
  (lsp-register-client
    (make-lsp-client
      :new-connection (lsp-stdio-connection '("cargo" "owlsp"))
      :major-modes '(rust-mode)
      :server-id 'rustowlsp
      :priority -1
      :add-on? t)))

(defun rustowlsp-cursor (params)
  (lsp-request-async
    "rustowl/cursor"
    params
    (lambda (response)
      (let ((decorations (gethash "decorations" response)))
        (mapc
          (lambda (deco)
            (let* ((type (gethash "type" deco))
                   (start (gethash "start" (gethash "range" deco)))
                   (end (gethash "end" (gethash "range" deco)))
                   (start-pos
                     (line-col-to-pos
                       (gethash "line" start)
                       (gethash "character" start)))
                   (end-pos
                     (line-col-to-pos
                       (gethash "line" end)
                       (gethash "character" end))))
              (cond
                ((equal type "lifetime")
                 (underline start-pos end-pos "#00cc00"))
                ((equal type "imm_borrow")
                 (underline start-pos end-pos "#0000cc"))
                ((equal type "mut_borrow")
                 (underline start-pos end-pos "#cc00cc"))
                ((or (equal type "move") (equal type "call"))
                 (underline start-pos end-pos "#cccc00"))
                ((equal type "outlive")
                 (underline start-pos end-pos "#cc0000")))))
                decorations)))
    :mode 'current))


(defun rustowlsp-line-number-at-pos ()
  (save-excursion
    (goto-char (point))
    (count-lines (point-min) (line-beginning-position))))
(defun rustowlsp-current-column ()
  (save-excursion
    (let ((start (point)))
      (move-beginning-of-line 1)
      (- start (point)))))

(defun rustowlsp-cursor-call ()
  (let ((line (rustowlsp-line-number-at-pos))
        (column (rustowlsp-current-column))
        (uri (lsp--buffer-uri)))
    (rustowlsp-cursor `(
                        :position ,`(
                                    :line ,line
                                    :character ,column
                                    )
                        :document ,`(
                                     :uri ,uri
                                     )
                        ))))

;;;###autoload
(defvar rustowlsp-cursor-timer nil)
;;;###autoload
(defvar rustowlsp-cursor-timeout 2)

;;;###autoload
(defun rustowlsp-reset-cursor-timer ()
  (when rustowlsp-cursor-timer
    (cancel-timer rustowlsp-cursor-timer))
  (clear-overlays)
  (setq rustowlsp-cursor-timer
    (run-with-idle-timer rustowlsp-cursor-timeout nil #'rustowlsp-cursor-call)))

;;;###autoload
(defun enable-rustowlsp-cursor ()
  (add-hook 'post-command-hook #'rustowlsp-reset-cursor-timer))

;;;###autoload
(defun disable-rustowlsp-cursor ()
  (remove-hook 'post-command-hook #'rustowlsp-reset-cursor-timer)
  (when rustowlsp-cursor-timer
    (cancel-timer rustowlsp-cursor-timer)
    (setq rustowlsp-cursor-timer nil)))

;;;###autoload
(enable-rustowlsp-cursor)

;; RustOwl visualization
(defun line-col-to-pos (line col)
  (save-excursion
    (goto-char (point-min))
    (forward-line line)
    (move-to-column col)
    (point)))
(defvar rustowl-overlays nil)
(defun underline (start end color)
  (let ((overlay (make-overlay start end)))
    (overlay-put overlay 'face `(:underline (:color ,color :style wave)))
    (push overlay rustowl-overlays)
    overlay))
(defun clear-overlays ()
  (interactive)
  (mapc #'delete-overlay rustowl-overlays)
  (setq rustowl-overlays nil))
