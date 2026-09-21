(asdf:defsystem "symac/core"
  :description "Symac platform core"
  :version "0.0.1"
  :license "TBD"
  :pathname "src/core/"
  :serial t
  :components ((:file "package")
               (:file "core")))

(asdf:defsystem "symac/task"
  :description "First-class Symac task and slice model"
  :version "0.0.1"
  :depends-on ("symac/core")
  :pathname "src/task/"
  :serial t
  :components ((:file "package")
               (:file "task")))

(asdf:defsystem "symac/coding-agent"
  :description "Coding-agent backend protocol"
  :version "0.0.1"
  :depends-on ("symac/core")
  :pathname "src/coding-agent/"
  :serial t
  :components ((:file "package")
               (:file "coding-agent")))

(asdf:defsystem "symac/task-agent"
  :description "Task/slice to coding-agent integration"
  :version "0.0.1"
  :depends-on ("symac/task" "symac/coding-agent")
  :pathname "src/task-agent/"
  :serial t
  :components ((:file "package")
               (:file "task-agent")))

(asdf:defsystem "symac"
  :description "AI-native Common Lisp workstation"
  :version "0.0.1"
  :depends-on ("symac/core"
               "symac/task"
               "symac/coding-agent"
               "symac/task-agent")
  :in-order-to ((asdf:test-op (asdf:test-op "symac/tests"))))

(asdf:defsystem "symac/tests"
  :description "Deterministic Symac bootstrap tests"
  :depends-on ("symac")
  :pathname "test/"
  :serial t
  :components ((:file "package")
               (:file "harness")
               (:file "task")
               (:file "coding-agent"))
  :perform (asdf:test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call :symac.test :run-all-tests)))
