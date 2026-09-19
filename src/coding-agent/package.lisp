(defpackage #:symac.coding-agent
  (:use #:cl)
  (:export
   #:coding-agent-backend
   #:coding-agent-session
   #:coding-agent-operation-unsupported
   #:coding-agent-capabilities
   #:coding-agent-start
   #:coding-agent-submit
   #:coding-agent-interrupt
   #:coding-agent-resume
   #:coding-agent-cancel
   #:coding-agent-status
   #:coding-agent-events
   #:coding-agent-artifacts
   #:coding-agent-usage
   #:make-coding-agent-session
   #:coding-agent-session-id
   #:coding-agent-session-backend
   #:coding-agent-session-native-id
   #:coding-agent-session-project-root
   #:coding-agent-session-task-id
   #:coding-agent-session-slice-ids
   #:coding-agent-session-state
   #:coding-agent-session-metadata
   #:attach-session-slice))
