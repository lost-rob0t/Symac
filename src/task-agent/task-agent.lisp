(in-package #:symac.task-agent)

(defun assign-slice-agent (store slice-id session)
  (let ((slice (symac.task:find-slice store slice-id)))
    (unless slice
      (error "Unknown slice: ~A" slice-id))
    (let ((session-task
            (symac.coding-agent:coding-agent-session-task-id session)))
      (when (and session-task
                 (not (equal session-task
                             (symac.task:slice-task-id slice))))
        (error "Agent session task ~A does not match slice task ~A."
               session-task
               (symac.task:slice-task-id slice))))
    (symac.task:assign-slice-session
     slice
     (symac.coding-agent:coding-agent-session-id session))
    (symac.coding-agent:attach-session-slice session slice-id)
    slice))
