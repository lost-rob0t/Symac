(in-package #:symac.coding-agent)

(define-condition coding-agent-operation-unsupported (symac.core:symac-error)
  ((operation :initarg :operation :reader unsupported-operation)
   (object :initarg :object :reader unsupported-object))
  (:report
   (lambda (condition stream)
     (format stream "Coding-agent operation ~S is unsupported for ~S."
             (unsupported-operation condition)
             (unsupported-object condition)))))

(defclass coding-agent-backend () ())

(defclass coding-agent-session ()
  ((id
    :initarg :id
    :reader coding-agent-session-id)
   (backend
    :initarg :backend
    :reader coding-agent-session-backend)
   (native-id
    :initarg :native-id
    :initform nil
    :accessor coding-agent-session-native-id)
   (project-root
    :initarg :project-root
    :initform nil
    :reader coding-agent-session-project-root)
   (task-id
    :initarg :task-id
    :initform nil
    :accessor coding-agent-session-task-id)
   (slice-ids
    :initarg :slice-ids
    :initform nil
    :accessor coding-agent-session-slice-ids)
   (state
    :initarg :state
    :initform :created
    :accessor coding-agent-session-state)
   (metadata
    :initarg :metadata
    :initform nil
    :accessor coding-agent-session-metadata)))

(defun make-coding-agent-session
    (&key id backend native-id project-root task-id slice-ids
          (state :created) metadata)
  (make-instance
   'coding-agent-session
   :id id
   :backend backend
   :native-id native-id
   :project-root project-root
   :task-id task-id
   :slice-ids (copy-list slice-ids)
   :state state
   :metadata metadata))

(defun attach-session-slice (session slice-id)
  (pushnew slice-id
           (coding-agent-session-slice-ids session)
           :test #'equal)
  session)

(defun %unsupported (operation object)
  (error 'coding-agent-operation-unsupported
         :operation operation
         :object object))

(defgeneric coding-agent-capabilities (backend))
(defgeneric coding-agent-start (backend request))
(defgeneric coding-agent-submit (session input))
(defgeneric coding-agent-interrupt (session))
(defgeneric coding-agent-resume (session))
(defgeneric coding-agent-cancel (session))
(defgeneric coding-agent-status (session))
(defgeneric coding-agent-events (session &key since))
(defgeneric coding-agent-artifacts (session))
(defgeneric coding-agent-usage (session))

(defmethod coding-agent-capabilities ((backend coding-agent-backend))
  (declare (ignore backend))
  nil)

(defmethod coding-agent-start ((backend coding-agent-backend) request)
  (declare (ignore request))
  (%unsupported :start backend))

(defmethod coding-agent-submit ((session coding-agent-session) input)
  (declare (ignore input))
  (%unsupported :submit session))

(defmethod coding-agent-interrupt ((session coding-agent-session))
  (%unsupported :interrupt session))

(defmethod coding-agent-resume ((session coding-agent-session))
  (%unsupported :resume session))

(defmethod coding-agent-cancel ((session coding-agent-session))
  (%unsupported :cancel session))

(defmethod coding-agent-status ((session coding-agent-session))
  (coding-agent-session-state session))

(defmethod coding-agent-events ((session coding-agent-session) &key since)
  (declare (ignore since))
  (%unsupported :events session))

(defmethod coding-agent-artifacts ((session coding-agent-session))
  (%unsupported :artifacts session))

(defmethod coding-agent-usage ((session coding-agent-session))
  (%unsupported :usage session))
