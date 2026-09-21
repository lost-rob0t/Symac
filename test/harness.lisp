(in-package #:symac.test)

(defvar *tests* '())

(defmacro deftest (name &body body)
  `(progn
     (pushnew ',name *tests*)
     (defun ,name ()
       ,@body)))

(defmacro is (form &optional (message "Assertion failed: ~S"))
  `(unless ,form
     (error ,message ',form)))

(defmacro signals (condition &body body)
  `(let ((caught nil))
     (handler-case
         (progn ,@body)
       (,condition ()
         (setf caught t)))
     (unless caught
       (error "Expected condition ~S" ',condition))
     t))

(defun run-all-tests ()
  (let ((failures '())
        (tests (reverse *tests*)))
    (format t "~&Running ~D Symac tests.~%" (length tests))
    (dolist (test tests)
      (handler-case
          (progn
            (funcall test)
            (format t "PASS ~A~%" test))
        (error (condition)
          (push (cons test condition) failures)
          (format *error-output* "FAIL ~A: ~A~%" test condition))))
    (when failures
      (error "~D Symac test(s) failed." (length failures)))
    (format t "All Symac tests passed.~%")
    t))
