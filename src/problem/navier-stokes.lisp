;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; navier-stokes.lisp
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

(in-package :cl-user)
(defpackage "FL.NAVIER-STOKES"
  (:use "COMMON-LISP" "FL.MACROS" "FL.UTILITIES" "FL.MATLISP"
	"FL.ALGEBRA" "FL.FUNCTION" "FL.MESH" "FL.PROBLEM")
  (:export
   "<NAVIER-STOKES-PROBLEM>" "NO-SLIP-BOUNDARY"
   "STANDARD-NAVIER-STOKES-PROBLEM"
   "NAVIER-STOKES-VISCOSITY-COEFFICIENT"
   "NAVIER-STOKES-INERTIA-COEFFICIENT"
   "NAVIER-STOKES-UNIT-VECTOR-FORCE"
   "DRIVEN-CAVITY" "PERIODIC-CAVITY")
  (:documentation "Defines the class of Navier-Stokes problems."))
(in-package "FL.NAVIER-STOKES")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; <navier-stokes-problem>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <navier-stokes-problem> (<pde-problem>)
  ()
  (:documentation "Navier-Stokes problem."))

(defmethod shared-initialize :after
    ((problem <navier-stokes-problem>) slot-names &key &allow-other-keys)
  (declare (ignore slot-names))
  (setf (slot-value problem 'components)
	(list (list 'u (dimension (domain problem)))
	      (list 'p 1))))

;;; Warning: in elasticity-fe we handle incompressible Navier-Stokes with a
;;; viscosity term of the form nu*Delta u.  For non-Dirichlet boundary
;;; conditions for the velocity one should use instead a term of the form
;;; div(nu*eps(u)) with eps denoting the strain tensor.  We will switch to
;;; this alternative form soon.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Generation of a standard Navier-Stokes problem
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun no-slip-boundary (dim)
  (let ((flags (make-array (1+ dim) :initial-element t))
	(values (make-array (1+ dim) :initial-element (zeros 1))))
    (setf (aref flags dim) nil)
  (constant-coefficient 'CONSTRAINT flags values)))

(defun navier-stokes-viscosity-coefficient (viscosity)
  (ensure-coefficient 'FL.NAVIER-STOKES::VISCOSITY viscosity))

(defun navier-stokes-inertia-coefficient (reynolds)
  (make-instance
   '<coefficient> :name 'FL.NAVIER-STOKES::REYNOLDS
   :demands (unless (zerop reynolds) '((:fe-parameters :solution)))
   :eval #'(lambda (&key &allow-other-keys)
	     ;; note: there is a special treatment
	     ;; inside discretization which takes
	     ;; care of the nonlinearity
	     reynolds)))

(defun navier-stokes-unit-vector-force (dim &optional (direction 0))
  (constant-coefficient
   'FL.NAVIER-STOKES::FORCE
   (let ((result (make-array (1+ dim) :initial-element (zeros 1))))
     (setf (aref result direction) (eye 1))
     result)))

(defun standard-navier-stokes-problem (domain &key (viscosity 1.0) (reynolds 0.0) force)
  (let ((dim (dimension domain)))
    (make-instance
     '<navier-stokes-problem>
     :domain domain
     :patch->coefficients
     #'(lambda (patch)
	 (cond ((member-of-skeleton? patch (domain-boundary domain))
		(list (no-slip-boundary dim)))
	       ((= dim (dimension patch))
		(list (navier-stokes-viscosity-coefficient viscosity)
		      (navier-stokes-inertia-coefficient reynolds)
		      (ensure-coefficient 'FL.NAVIER-STOKES::FORCE force)))
	       (t ()))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Driven cavity
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun driven-cavity-upper-boundary (dim &optional smooth-p)
  (let ((flags (make-array (1+ dim) :initial-element (not smooth-p)))
	(values (make-array (1+ dim) :initial-element #m(0.0))))
    (setf (aref flags dim) nil) ; no constraint for pressure
    (when smooth-p  ; zero constraint for u_n
      (setf (aref flags (1- dim)) t))
    (unless smooth-p
      (setf (aref values 0) #m(1.0)))
    (constant-coefficient 'CONSTRAINT flags values)))

(defun driven-cavity-force (dim)
  (navier-stokes-unit-vector-force dim 0))

(defun driven-cavity (dim &key (viscosity 1.0) (reynolds 0.0) smooth-p)
  (let ((domain (n-cube-domain dim)))
    (make-instance
     '<navier-stokes-problem>
     :domain domain
     :patch->coefficients
     #'(lambda (patch)
	 (let ((midpoint (midpoint patch)))
	   (cond
	     ((= dim (dimension patch)) ; interior coefficients
	      (list (navier-stokes-viscosity-coefficient viscosity)
		    (navier-stokes-inertia-coefficient reynolds)))
	     ;; upper boundary
	     ((and (= (dimension patch) (1- dim))
		   (= (aref midpoint (1- dim)) 1.0))
	      (list* (driven-cavity-upper-boundary dim smooth-p)
		     (when smooth-p (list (driven-cavity-force dim)))))
	     ;; lower corner sets also pressure to zero:
	     ((mzerop midpoint)
	      (list (constraint-coefficient (1+ dim) 1)))
	     ;; other boundaries have standard no-slip bc
	     (t (list (no-slip-boundary dim)))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Periodic cavity
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun oscillating-force (dim)
  (function->coefficient
   'FL.NAVIER-STOKES::FORCE
   #'(lambda (x)
    (let ((result (make-array (1+ dim) :initial-element nil)))
      (dotimes (i (1+ dim) result)
	(setf (aref result i)
	      (if (< i dim)
		  (make-real-matrix `((,#I"sin(2*pi*x[0])*cos(2*pi*x[1])")))
		  (zeros 1))))))))

(defun periodic-cavity (dim &key (viscosity 1.0) (reynolds 0.0))
  (let ((domain (n-cell-domain dim)))
    (make-instance
     '<navier-stokes-problem>
     :domain domain
     :patch->coefficients
     #'(lambda (patch)
	 (when (= (dimension patch) dim)
	   (list (navier-stokes-viscosity-coefficient viscosity)
		 (navier-stokes-inertia-coefficient reynolds)
		 (oscillating-force dim)))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Channel flow
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun simple-pressure-boundary-conditions (dim dir value)
  "This function is a preliminary version which works only for boundaries
lying in a coordinate hyperplane."
  (assert (<= 0 dir (1- dim)))
  (let ((flags (make-array (1+ dim) :initial-element t))
	(values (make-array (1+ dim) :initial-element #m(0.0))))
    (setf (aref flags dir) nil) ; no constraint for dir-component
    (setf (aref values dim) (ensure-matlisp value))
    (constant-coefficient 'CONSTRAINT flags values)))

(defun cubic-channel (dim &key (viscosity 1.0) (reynolds 0.0) (direction 0))
  "The channel is a simple test problem which has for every Reynolds number
a Hagen-Poiseuille solution with linear pressure.  The corresponding
velocity profile is a solution to @math{-\Delta u = constant}."
  (let ((domain (n-cube-domain dim)))
    (make-instance
     '<navier-stokes-problem>
     :domain domain
     :patch->coefficients
     #'(lambda (patch)
	 (let ((dir-coordinate (aref (midpoint patch) direction)))
	   (cond
	     ((= dim (dimension patch)) ; interior coefficients
	      (list (navier-stokes-viscosity-coefficient viscosity)
		    (navier-stokes-inertia-coefficient reynolds)))
	     ((and (= (1- dim) (dimension patch))
		   (not (/= dir-coordinate 0.0 1.0)))
	      (list (simple-pressure-boundary-conditions
		     dim direction (if (zerop dir-coordinate) 1.0 0.0))))
	     ;; other boundaries have standard no-slip bc
	     (t (list (no-slip-boundary dim)))))))))

;;; Testing

(defun test-navier-stokes ()
  (describe
   (standard-navier-stokes-problem
    (n-cube-domain 2)
    :force (navier-stokes-unit-vector-force 2 0)))
  (describe (driven-cavity 2 :smooth-p nil :reynolds 1.0))
  (describe
   (make-instance '<navier-stokes-problem>
		  :domain (n-cube-domain 2) :multiplicity 2
		  :patch->coefficients
		  `((:d-dimensional
		     (,(navier-stokes-viscosity-coefficient 1.0)
		      ,(navier-stokes-inertia-coefficient 0.0))))))
  )

;;; (test-navier-stokes)
(fl.tests:adjoin-test 'test-navier-stokes)


