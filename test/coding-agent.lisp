(in-package #:symac.test)

(defclass fake-coding-agent (symac.coding-agent:coding-agent-backend) ())

(defmethod symac.coding-agent:coding-agent-capabilities
    ((backend fake-coding-agent))
  (declare (ignore backend))
  '(:streaming t :resume t :worktree t))

(defmethod symac.coding-agent:coding-agent-start
    ((backend fake-coding-agent) request)
  (symac.coding-agent:make-coding-agent-session
   :id "agent-session-1"
   :backend backend
   :project-root (getf request :project-root)
   :task-id (getf request :task-id)
   :state :running))

(deftest coding-agent-backend-is-normalized
  (let ((backend (make-instance 'fake-coding-agent)))
    (is (getf (symac.coding-agent:coding-agent-capabilities backend)
              :streaming))
    (let ((session
            (symac.coding-agent:coding-agent-start
             backend
             '(:project-root "/tmp/project"
               :task-id "task-agent"))))
      (is (string= "agent-session-1"
                   (symac.coding-agent:coding-agent-session-id session)))
      (is (eq :running
              (symac.coding-agent:coding-agent-session-state session))))))

(deftest unsupported-agent-operation-is-explicit
  (let* ((backend (make-instance 'fake-coding-agent))
         (session
           (symac.coding-agent:coding-agent-start
            backend
            '(:project-root "/tmp/project"))))
    (signals symac.coding-agent:coding-agent-operation-unsupported
      (symac.coding-agent:coding-agent-submit session "do work"))))

(deftest assigning-slice-links-task-and-agent-session
  (let* ((store (symac.task:make-task-store))
         (task (symac.task:make-task
                :id "task-agent-link"
                :title "Agent task"
                :state :active))
         (slice (symac.task:make-slice
                 :id "slice-agent-link"
                 :task-id "task-agent-link"
                 :title "Agent slice"))
         (backend (make-instance 'fake-coding-agent))
         (session
           (symac.coding-agent:coding-agent-start
            backend
            '(:project-root "/tmp/project"
              :task-id "task-agent-link"))))
    (symac.task:store-task store task)
    (symac.task:store-slice store slice)
    (symac.task-agent:assign-slice-agent
     store
     "slice-agent-link"
     session)
    (is (string=
         "agent-session-1"
         (symac.task:slice-agent-session-id slice)))
    (is (member "slice-agent-link"
                (symac.coding-agent:coding-agent-session-slice-ids session)
                :test #'string=))))
