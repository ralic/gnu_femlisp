;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  mflop.lisp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (C) 2003 Nicolas Neuss, University of Heidelberg.
;;; All rights reserved.
;;; 
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions are
;;; met:
;;; 
;;; 1. Redistributions of source code must retain the above copyright
;;; notice, this list of conditions and the following disclaimer.
;;; 
;;; 2. Redistributions in binary form must reproduce the above copyright
;;; notice, this list of conditions and the following disclaimer in the
;;; documentation and/or other materials provided with the distribution.
;;; 
;;; THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
;;; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
;;; NO EVENT SHALL THE AUTHOR, THE UNIVERSITY OF HEIDELBERG OR OTHER
;;; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;;; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;;; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; mflop.lisp defines the function measure-time for time measuring and
;;; sets a parameter *hardware-speed*.  This can be used to make test and
;;; demo durations more independent of the hardware on which the test is
;;; running.

(in-package :fl.utilities)

(defconstant +N-long+ #x080000)  ; should not fit in secondary cache
(defconstant +N-short+ #x100)    ; should fit in primary cache

(defparameter *mflop-delta* 0.3
  "Time interval in seconds over which we measure performance.")

(defun make-double-float-array (size &optional (initial 0.0))
   (make-array size :element-type 'double-float :initial-element initial))

(defun daxpy (x a y n)
  (declare (type fixnum n)
	   (type (simple-array double-float (*)) x y)
	   (type double-float a))
  (declare (optimize (safety 0) (space 0) (debug 0) (speed 3)))
  (loop for i of-type fixnum from 0 below n do
	(incf (aref y i) (* a (aref x i)))))

(defun ddot (x y n)
  (declare (type fixnum n)
	   (type (simple-array double-float (*)) x y))
  (declare (optimize (safety 0) (space 0) (debug 0) (speed 3)))
  (loop for i of-type fixnum from 0 below n
	summing (* (aref x i) (aref y i)) double-float))

(defun measure-time (fn count &optional real-p)
  "Measures the time in secondswhich @arg{count}-time execution of @arg{fn}
needs."
  (declare (type function fn) (type fixnum count))
  (declare (optimize speed))
  (flet ((time-stamp ()
	   (if real-p
	       (get-internal-real-time)
	       (get-internal-run-time))))
    (let ((before (time-stamp)))
      (loop repeat count do (funcall fn))
      ;; return time in seconds
      (float (/ (- (time-stamp) before)
		internal-time-units-per-second)))))

(defun measure-time-repeated (fn &optional (delta *mflop-delta*))
  "Calls fn repeatedly until it takes more than *mflop-delta* seconds.
Returns the time in seconds together with the repetition count."
  (declare (type function fn))
  (loop	for count of-type fixnum = 1 then (* count 2)
	for secs = (measure-time fn count) 
	until (> secs delta)
	finally (return (values secs count))))

(defun daxpy-speed (n)
  "Returns the speed with which @function{daxpy} works for vectors of size
@arg{n}."
  (let ((x (make-array n :element-type 'double-float :initial-element 2.0))
	(y (make-array n :element-type 'double-float :initial-element 1.0)))
    ;;(/ (measure-time #'(lambda () (blas::DAXPY n 2.0 x 1 y 1))))
    (multiple-value-bind (secs count)
	(measure-time-repeated #'(lambda () (daxpy x 2.0 y n)))
      (/ (* 2 n count) 1.0e6 secs))))

(defun common-lisp-speed (&key (cache 0.5) (memory 0.5))
  "Returns the speed which should be characteristic for the setting
determined by the keyword arguments."
  (+ (* cache (daxpy-speed +N-short+))
     (* memory (daxpy-speed +N-long+))))

(defun test-mflop ()
  (daxpy-speed +N-long+)
  (common-lisp-speed)
  )