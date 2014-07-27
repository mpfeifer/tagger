;;;; auto etags

;; This tags-handler is ment to be used for simple script fashion files
;; These files are ment to be not part of a bigger project. Standalone
;; files that would oppose a 1:1 relationship between sourcecode-files
;; and TAGS files if the classical TAGS file would be used.
;;
;; tags-file-name is used in a buffer local fashion. For each buffer
;; a tags file name is calculated which determines a tagfile stored in
;; ~/.emacs.d/auto-etags.

;; logic
;;    minor-mode-definition
;;       takes care for checking if tags file already exists for buffer
;;       if so load the tags file, if not initially generate one and load it
;; - how to refresh?
;;       after saving, after-enter
;;       post-command-hook?

(define-minor-mode tagger-mode
  "Automagically create TAGS files for simple scripts. And store them
in a directory under ~/.emacs.d/ where they do not clutter the whole filesystem."
  :ligher " T+"
  :keymap (let ((map (make-sparse-keymap)))
	    (define-key map (kbd "C-c C-t") 'tagger/update-tags-file)
	    map)
  (setq tagger/etags-process nil)
  (setq tagger/timeout nil)
  (setq tags-file-name nil)
  (setq tags-table-list nil)
  (tagger/update-tags-file)
  )

(defconst tagger/repository "/home/matthias/.emacs.d/tags/"
  "The name of the directory where tags files are stored.")

(defconst tagger/etags-path "/usr/bin/etags")

(defconst tagger/status-buffer-name "*etags*")

(defconst tagger/timeout 3
  "The number of seconds to wait for the next update, after a tags file was updated.")

(defconst tagger/modes (list 'perl-mode-hook 'sh-mode-hook 'cperl-mode-hook))

(defvar tagger/original-enter-handler 'newline)

(defvar tagger/timeout nil)

(defvar tagger/etags-process nil)

(defun tagger/process-sentinel (process event)
  "This is the process sentinel for the etags process."
  (when (string= event "finished\n")
    (let ((tags-file-path (process-get process 'tags-file-path)))
      (progn
	(message (concat "Process sentinel will load tags file " tags-file-path)
		 (when (file-exists-p tags-file-path)
		   (visit-tags-table tags-file-path t)
		   )
		 )
	)
      )
    )
  )

(defun tagger/update-tags-file ()
  "If a tags file exists and is newer then the buffers file - visit it. Otherwise create tags file and visit that."
  (interactive)
    ;; First check if a new file has to be generated by etags.
  (let ((tags-file-path (tagger/tags-file-path))
	(create-new-tags-file nil))
    (if (not (file-exists-p tags-file-path))
	(setq create-new-tags-file t)
      (when (file-newer-than-file-p (buffer-file-name) tags-file-path)
	(setq create-new-tags-file t)
	)
      )
    (if create-new-tags-file
	(progn
	  (setq tagger/etags-process (start-process "etags" tagger/status-buffer-name tagger/etags-path
							   (concat "--output=" tags-file-path)
							   (concat "--parse-stdin=" (buffer-name))))
	  (process-put tagger/etags-process 'tags-file-path tags-file-path)
	  (set-process-sentinel tagger/etags-process 'tagger/process-sentinel)
	  (process-send-region tagger/etags-process (point-min) (point-max))
	  (process-send-eof tagger/etags-process)
	  )
      (visit-tags-table tags-file-path t)
      )
    )
  )

(defun tagger/tags-file-path ()
  "Calculate the tags file belonging to the current buffer."
  (let* 
      ((tags-file (replace-regexp-in-string "[/.]" "_" (buffer-file-name)))
       (tags-file-path (concat tagger/repository tags-file)))
    tags-file-path))

(defun tagger/enter-handler ()
  (interactive)
  (when (null tagger/timeout)
    (setq tagger/timeout t)
    (tagger/update-tags-file)
    (run-with-timer tagger/timeout nil '(lambda () (setq tagger/timeout nil)))
    )
  (when (not (null tagger/original-enter-handler))
    (funcall tagger/original-enter-handler)
    )
  )

(defun tagger/start()
  (interactive)
  (dolist (hook tagger/modes)
    (add-hook hook 'tagger-mode)
    )
  )
  
(provide 'tagger)
