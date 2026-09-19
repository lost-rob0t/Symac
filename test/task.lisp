(in-package #:symac.test)

(deftest task-idea-is-a-state-not-a-tag
  (let ((task (symac.task:make-task
               :id "task-idea"
               :title "Explore a thing"
               :state :idea
               :tags '("research"))))
    (is (eq :idea (symac.task:task-state task)))
    (is (not (member "IDEA"
                     (symac.task:task-tags task)
                     :test #'string=)))))

(deftest scheduling-does-not-create-a-deadline
  (let ((task (symac.task:make-task
               :id "task-schedule"
               :title "Do it"
               :state :todo)))
    (symac.task:schedule-task task "2026-09-19T10:00:00-04:00")
    (is (equal "2026-09-19T10:00:00-04:00"
               (symac.task:task-scheduled task)))
    (is (null (symac.task:task-deadline task)))))

(deftest invalid-task-state-fails
  (signals symac.task:invalid-task-state
    (symac.task:make-task
     :id "task-invalid"
     :title "Nope"
     :state :banana)))

(deftest slice-verification-requires-all-evidence
  (let* ((store (symac.task:make-task-store))
         (task (symac.task:make-task
                :id "task-verify"
                :title "Verify"
                :state :active))
         (slice (symac.task:make-slice
                 :id "slice-verify"
                 :task-id "task-verify"
                 :title "Implementation"
                 :verification-required '(:tests :review))))
    (symac.task:store-task store task)
    (symac.task:store-slice store slice)
    (symac.task:record-slice-verification slice :tests "unit suite passed")
    (signals symac.task:missing-verification-evidence
      (symac.task:verify-slice slice))
    (symac.task:record-slice-verification slice :review "review approved")
    (symac.task:verify-slice slice)
    (is (eq :verified (symac.task:slice-state slice)))))

(deftest slice-dependency-cycle-fails
  (let* ((store (symac.task:make-task-store))
         (task (symac.task:make-task
                :id "task-dag"
                :title "DAG"
                :state :active))
         (a (symac.task:make-slice
             :id "slice-a"
             :task-id "task-dag"
             :title "A"))
         (b (symac.task:make-slice
             :id "slice-b"
             :task-id "task-dag"
             :title "B")))
    (symac.task:store-task store task)
    (symac.task:store-slice store a)
    (symac.task:store-slice store b)
    (symac.task:add-slice-dependency store "slice-a" "slice-b")
    (signals symac.task:slice-dependency-cycle
      (symac.task:add-slice-dependency store "slice-b" "slice-a"))))
