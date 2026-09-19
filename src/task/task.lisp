(in-package #:symac.task)

(defparameter *task-states*
  '(:todo :next :active :blocked :review :done :idea :canceled))

(defparameter *slice-states*
  '(:queued :ready :running :blocked :review :verified :done :failed :canceled))

(define-condition invalid-task-state (symac.core:symac-error)
  ((state :initarg :state :reader invalid-task-state-state))
  (:report
   (lambda (condition stream)
     (format stream "Invalid Symac task state: ~S"
             (invalid-task-state-state condition)))))

(define-condition invalid-slice-state (symac.core:symac-error)
  ((state :initarg :state :reader invalid-slice-state-state))
  (:report
   (lambda (condition stream)
     (format stream "Invalid Symac slice state: ~S"
             (invalid-slice-state-state condition)))))

(define-condition missing-verification-evidence (symac.core:symac-error)
  ((missing :initarg :missing :reader missing-verification-evidence-missing))
  (:report
   (lambda (condition stream)
     (format stream "Missing slice verification evidence for: ~S"
             (missing-verification-evidence-missing condition)))))

(define-condition slice-dependency-cycle (symac.core:symac-error)
  ((slice-id :initarg :slice-id :reader cycle-slice-id)
   (dependency-id :initarg :dependency-id :reader cycle-dependency-id))
  (:report
   (lambda (condition stream)
     (format stream "Adding slice dependency ~A -> ~A would create a cycle."
             (cycle-slice-id condition)
             (cycle-dependency-id condition)))))

(defstruct (task (:constructor %make-task))
  id
  title
  (state :todo)
  tags
  priority
  scheduled
  deadline
  dependencies
  metadata)

(defun %check-task-state (state)
  (unless (member state *task-states*)
    (error 'invalid-task-state :state state))
  state)

(defun make-task (&key id title (state :todo) tags priority scheduled deadline
                       dependencies metadata)
  (%check-task-state state)
  (%make-task
   :id id
   :title title
   :state state
   :tags (copy-list tags)
   :priority priority
   :scheduled scheduled
   :deadline deadline
   :dependencies (copy-list dependencies)
   :metadata metadata))

(defun transition-task (task state)
  (%check-task-state state)
  (setf (task-state task) state)
  task)

(defun schedule-task (task scheduled)
  (setf (task-scheduled task) scheduled)
  task)

(defun set-task-deadline (task deadline)
  (setf (task-deadline task) deadline)
  task)

(defstruct (slice (:constructor %make-slice))
  id
  task-id
  title
  (state :queued)
  dependencies
  verification-required
  verification-evidence
  agent-session-id)

(defun %check-slice-state (state)
  (unless (member state *slice-states*)
    (error 'invalid-slice-state :state state))
  state)

(defun make-slice (&key id task-id title (state :queued) dependencies
                        verification-required agent-session-id)
  (%check-slice-state state)
  (%make-slice
   :id id
   :task-id task-id
   :title title
   :state state
   :dependencies (copy-list dependencies)
   :verification-required (copy-list verification-required)
   :verification-evidence (make-hash-table :test #'eq)
   :agent-session-id agent-session-id))

(defun record-slice-verification (slice kind evidence)
  (setf (gethash kind (slice-verification-evidence slice)) evidence)
  slice)

(defun %missing-verification (slice)
  (loop for requirement in (slice-verification-required slice)
        unless (nth-value 1
                          (gethash requirement
                                   (slice-verification-evidence slice)))
          collect requirement))

(defun verify-slice (slice)
  (let ((missing (%missing-verification slice)))
    (when missing
      (error 'missing-verification-evidence :missing missing)))
  (setf (slice-state slice) :verified)
  slice)

(defun assign-slice-session (slice session-id)
  (setf (slice-agent-session-id slice) session-id)
  slice)

(defstruct (task-store (:constructor %make-task-store))
  tasks
  slices)

(defun make-task-store ()
  (%make-task-store
   :tasks (make-hash-table :test #'equal)
   :slices (make-hash-table :test #'equal)))

(defun store-task (store task)
  (setf (gethash (task-id task) (task-store-tasks store)) task)
  task)

(defun find-task (store task-id)
  (gethash task-id (task-store-tasks store)))

(defun store-slice (store slice)
  (unless (find-task store (slice-task-id slice))
    (error "Cannot store slice ~A: task ~A does not exist."
           (slice-id slice)
           (slice-task-id slice)))
  (setf (gethash (slice-id slice) (task-store-slices store)) slice)
  slice)

(defun find-slice (store slice-id)
  (gethash slice-id (task-store-slices store)))

(defun %slice-depends-on-p (store slice-id target-id seen)
  (when (member slice-id seen :test #'equal)
    (return-from %slice-depends-on-p nil))
  (let ((slice (find-slice store slice-id)))
    (and slice
         (or (member target-id
                     (slice-dependencies slice)
                     :test #'equal)
             (some
              (lambda (dependency-id)
                (%slice-depends-on-p
                 store
                 dependency-id
                 target-id
                 (cons slice-id seen)))
              (slice-dependencies slice))))))

(defun add-slice-dependency (store slice-id dependency-id)
  (let ((slice (find-slice store slice-id))
        (dependency (find-slice store dependency-id)))
    (unless slice
      (error "Unknown slice: ~A" slice-id))
    (unless dependency
      (error "Unknown dependency slice: ~A" dependency-id))
    (when (or (equal slice-id dependency-id)
              (%slice-depends-on-p store dependency-id slice-id nil))
      (error 'slice-dependency-cycle
             :slice-id slice-id
             :dependency-id dependency-id))
    (pushnew dependency-id
             (slice-dependencies slice)
             :test #'equal)
    slice))
