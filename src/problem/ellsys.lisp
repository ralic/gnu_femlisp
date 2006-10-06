;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ellsys.lisp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (C) 2006 Nicolas Neuss, University of Karlsruhe.
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
;;; NO EVENT SHALL THE AUTHOR, THE UNIVERSITY OF KARLSRUHE OR OTHER
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

(defpackage "FL.ELLSYS"
  (:use "COMMON-LISP" "FL.MACROS" "FL.UTILITIES"
	"FL.MATLISP" "FL.ALGEBRA"
	"FL.MESH" "FL.PROBLEM")
  (:export "<ELLSYS-PROBLEM>" "NR-OF-COMPONENTS"
	   "DIAGONAL-TENSOR" "ISOTROPIC-DIFFUSION" "ELLSYS-MODEL-PROBLEM")
  (:documentation "This package contains the problem definition of systems
of convection-diffusion-reaction equations.  The system is given in the
following form which is suited for a fixed-point iteration:

@math{-div(a(x,u_old,\nabla u_old) \nabla u)
 - div(b(x,u_old,\nabla u_old) u) +
 + c(x,u_old,\nabla u_old) u
= f(x,u_old, \nabla u_old) 
- div(g(x,u_old, \nabla u_old))
- div(a(x,u_old,\nabla u_old) h(x,u_old, \nabla u_old)) }

where @math{u:G \to \R^N}.  Note that the last two terms are introduced in
the variational formulation and imply a natural Neumann boundary condition
@math{\derivative{u}{n} = (g+a h) \cdot n} at boundaries where no Dirichlet
constraints are posed."))

(in-package :fl.ellsys)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; <ellsys-problem>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass <ellsys-problem> (<pde-problem>)
  ((nr-of-components :reader nr-of-components :initform 1 :initarg :nr-of-components))
  (:documentation "Systems of convection-diffusion-reaction equations.  The
coefficients should be vector-valued functions in this case."))

(defmethod interior-coefficients ((problem <ellsys-problem>))
  "Coefficients for a CDR system."
  '(A B C F G H CONSTRAINT))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Generation of standard ellsys problems
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun isotropic-diffusion (dim values)
  "Returns a sparse diagonal diffusion tensor with isotropic diffusion in
each component.  @arg{value} should be a vector or a number and contains
the amount of diffusion in each component."
  (let ((values (if (numberp values) (vector values) values)))
    (diagonal-sparse-tensor
     (map 'vector #'(lambda (val) (scal val (eye dim))) values))))

(defun ellsys-model-problem
    (domain ncomps
     &key a b c f g h dirichlet initial evp properties derived-class)
  "Generates a rather general elliptic problem on the given domain."
  (setq domain (ensure-domain domain))
  (apply #'fl.amop:make-programmatic-instance
	 (remove nil (list (or derived-class '<ellsys-problem>)
			   (and initial '<time-dependent-problem>)))
	 :nr-of-components ncomps
	 :properties properties
	 :domain domain :patch->coefficients
	 `((:external-boundary
	    ,(when dirichlet
		   `(CONSTRAINT ,(ensure-coefficient dirichlet))))
	   (:d-dimensional
	    ,(macrolet ((coefflist (&rest coeffs)
				   `(append
				     ,@(loop for sym in coeffs collect
					     `(when ,sym (list ',sym (ensure-coefficient ,sym)))))))
		       (coefflist a b c f g h initial))))
	 (append
	  (when evp (destructuring-bind (&key lambda mu) evp
		      (list :lambda lambda :mu mu))))
	 ))

;;; Testing: (test-ellsys)

(defun test-ellsys ()
  (ellsys-model-problem 
   2 2
   :a (isotropic-diffusion 2 #(1.0 2.0))
   :b (vector #m((1.0) (0.0)) #m((0.0) (1.0)))
   :f (vector #m(1.0) #m(1.0))
   :dirichlet (constraint-coefficient 2 1))
  )

(fl.tests:adjoin-test 'test-ellsys)

