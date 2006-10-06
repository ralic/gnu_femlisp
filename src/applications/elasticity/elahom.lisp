;;; -*- mode: lisp; fill-column: 64; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; elahom.lisp - homogenized coefficients for linear elasticity
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

(in-package :fl.application)

(defun elasticity-cell-problem-gamma (dim)
  "Returns a right-hand side for an elasticity cell problem."
  (ensure-coefficient
   (let* ((gamma (make-array dim :initial-element nil)))
     (dotimes (j dim)
       (setf (aref gamma j)
	     (let ((entry (zeros dim (* dim dim))))
	       (dotimes (mu dim)
		 (dotimes (k dim)
		   (dotimes (nu dim)
		     (and (= mu nu) (= k j)
			  (setf (mref entry mu (+ nu (* dim k)))
				1.0)))))
	       entry)))
     gamma)))

(defun elasticity-cell-problem-tensor (dim value)
  (constant-coefficient
   (isotropic-elasticity-tensor :dim dim :lambda value :mu value)))

(defun elasticity-inlay-cell-problem (domain &key (inlay-p #'patch-in-inlay-p)
				      (interior 100.0))
  "Generates the inlay cell problem.  The coefficient is of the
form @math{A^{ij}_{\lambda \mu}}$, and the equation to be solved
is in variational form

@math{ 0 = \partial_\lambda \phi^i A^{ij}_{\lambda \mu}
    (\partial_\mu N^j_m + \Gamma^j_{\mu m}) }

With @math{k,\nu} being such that @math{m= k n + \nu} we have
@math{\Gamma^{j_k}{\mu\nu}=\delta_{jk}\delta_{\mu\nu}} leading
to matrix-valued functions @math{N_\nu} in the notation of
\cite{Bakhvalov-Panasenko}.  We should also have
@math{N^{jk}_\nu = N^{j\nu}_k} because of the symmetries of A.
The correction to the arithmetic average has to be computed as

@math{ A_{corr}^{kr}_{iq} := \int_Y A^{kl}_{ij} \grad_{x_j}
N^{lr}_q = \int_Y \div_{x_j} A^{lk}_{ji} N^{lr}_q = F[k*dim+i]
\cdot N[r*dim+q].}"
  (let ((dim (dimension domain)))
    (make-instance
     '<ellsys-problem> :domain domain
     :nr-of-components dim :multiplicity (* dim dim)
     :patch->coefficients
     #'(lambda (patch)
	 (when (= (dimension patch) dim)
	   (list
	    'FL.ELLSYS::A (elasticity-cell-problem-tensor
			   dim (if (funcall inlay-p patch) interior 1.0))
	    'FL.ELLSYS::H (elasticity-cell-problem-gamma dim)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; utilities
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun inlay-block-decomposition (blockit asa)
  "Block decomposition for obtaining a coarse-grid solver which is robust
against the size of the coefficient jump."
  (declare (ignore blockit))
  (let ((inlay-block ())
	(rest-blocks ())
	(mesh (mesh asa)))
    (for-each-row-key
     #'(lambda (key)
	 (let ((cell (representative key)))
	   (if (patch-in-inlay-p (patch-of-cell cell mesh))
	       (push key inlay-block)
	       (push (list key) rest-blocks))))
     asa)
    (mapcar (rcurry #'coerce 'vector) (cons inlay-block rest-blocks))))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Demos
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun elasticity-interior-effective-coeff-demo (problem &key order levels plot (output 1))
  "Computes the effective elasticity for a certain periodic
medium.  The approximation is done with finite elements and
blending.  Uniform refinement is used, the linear solver is a
geometric multigrid scheme used in a nested iteration fashion.
A subtle point here is that the coarse-grid smoother has to
treat the inlay as a block to be robust against the large
coefficient jump.

The solution to this cell problem is a tensor field of rank 3
with dim^3 components which are plotted one after the other."
  (let* ((domain (domain problem))
	 (dim (dimension domain))
	 (*output-depth* output))
    (defparameter *result*
      (solve
       (make-instance
	'<stationary-fe-strategy>
	:fe-class (lagrange-fe order :nr-comps dim :type :gauss-lobatto)
	:estimator (make-instance '<projection-error-estimator>)
	:indicator (make-instance '<largest-eta-indicator> :fraction 1.0)
	:success-if `(>= :max-level ,(1- levels))
	:solver
	(make-instance
	 '<linear-solver> :iteration
	 (let ((smoother (if (>= dim 3)
			     *gauss-seidel*
			     (geometric-ssc))))
	   (geometric-cs
	    :coarse-grid-iteration
	    (make-instance '<multi-iteration> :nr-steps 10 :base
			   (make-instance '<custom-ssc>
					  :block-setup #'inlay-block-decomposition))
	    :smoother smoother :pre-steps 2 :post-steps 2
	    :gamma 2 :fmg t))
	 :success-if `(and (> :step 2) (> :step-reduction 0.9) (< :defnorm 1.0e-9))
	 :failure-if `(and (> :step 2) (> :step-reduction 0.9) (> :defnorm 1.0e-9)))
	:observe
	(append *stationary-fe-strategy-observe*
		(list
		 (list (format nil "~19@A~19@A~19@A" "A^00_00" "A^00_11" "A^10_10") "~57A"
		       #'(lambda (blackboard)
			   (let ((tensor (effective-tensor blackboard)))
			     (format nil "~19,10,2E~19,10,2E~19,10,2E"
				     (and tensor (mref (mref tensor 0 0) 0 0))
				     (and tensor (mref (mref tensor 0 0) 1 1))
				     (and tensor (mref (mref tensor 1 0) 1 0)))))))))
       (blackboard :problem problem)))
    (when plot
      ;; plot components of cell solution tensor
      (dotimes (j dim)
	(dotimes (k dim)
	  (plot (getbb *result* :solution) :index (+ (* j dim) k))
	  (sleep 1.0))))
    ;; compute the homogenized coefficient
    (format t "The effective elasticity tensor is:~%~A~%"
	    (effective-tensor *result*))))

#+(or)
(elasticity-interior-effective-coeff-demo
 (elasticity-inlay-cell-problem (n-cell-with-ball-inlay 2))
 :order 4 :levels 2 :output :all)

#|
(prof:with-profiling (:type :time)
  (elasticity-interior-effective-coeff-demo
   (elasticity-inlay-cell-problem (n-cell-with-ball-inlay 2))
   :order 4 :levels 1 :output :all))
(prof:show-call-graph)
|#

#+(or)
(plot (getbb *result* :solution) :index 1 :depth 2)

#+(or)
(let ((dim 2)
      (counter -1))
  (dotimes (i dim)
    (dotimes (j dim)
      (dotimes (k dim)
	(plot (getbb *result* :solution) :component i :index (+ (* j dim) k)
	      :background :white
	      :filename (format nil "ela-cell-sol-x~D" (incf counter)))))))
;; montage -geometry 480x480 -tile 2x4 ela-cell-*.tiff ela-cell-sols.eps

(defparameter *effective-elasticity-demo*
  (make-demo
   :name "effective-elasticity"
   :short "Computes an effective elasticity tensor"
   :long (documentation 'elasticity-interior-effective-coeff-demo 'function)))

(adjoin-demo *effective-elasticity-demo* *interior-coeffs-demo*)
(adjoin-demo *effective-elasticity-demo* *elasticity-demo*)


(defun make-effective-elasticity-porous-domain-demo (dim order levels)
  (let* ((short (format nil "Effective tensor for a ~DD cell with hole" dim))
	 (demo
	  (make-demo
	   :name (format nil "~DD-hole-cell" dim)
	   :short short
	   :long (format nil "We compute the effective
elasticity tensor for a medium with periodically distributed
holes by solving a cell problem on a periodicity cell.~%
Parameters: order=~D, max-levels=~D~%~%"
			      order levels)
		:execute
		(lambda ()
		  (elasticity-interior-effective-coeff-demo
		   (elasticity-inlay-cell-problem (n-cell-with-ball-hole dim))
		   :order order :levels levels :plot t)))))
    (adjoin-demo demo *effective-elasticity-demo*)))

(make-effective-elasticity-porous-domain-demo 2 5 2)
(make-effective-elasticity-porous-domain-demo 3 4 1)

(defun make-effective-elasticity-inlay-domain-demo (dim order levels)
  (let* ((short (format nil "Effective tensor for a ~DD cell with inlay." dim))
	 (demo
	  (make-demo
	   :name (format nil "~DD-inlay-cell" dim) :short short
	   :long
	   (format nil "We compute the effective elasticity
tensor for a mixture of two isotropic media forming a ball
inlay.  The Lame constants are 1/1 outside the inlay and 100/100
inside.
Parameters: order=~D, levels=~D~%~%"
		   order levels)
		:execute
		(lambda ()
		  (elasticity-interior-effective-coeff-demo
		   (elasticity-inlay-cell-problem (n-cell-with-ball-inlay 2))
		   :order order :levels levels)))))
    (adjoin-demo demo *effective-elasticity-demo*)))

(make-effective-elasticity-inlay-domain-demo 2 4 2)
(make-effective-elasticity-inlay-domain-demo 3 4 2)

#+(or)(demo *effective-elasticity-demo*)
     
(defun test-homogenization-elasticity ()
  (time (elasticity-interior-effective-coeff-demo
	 (elasticity-inlay-cell-problem (n-cell-with-ball-inlay 2)) :order 3 :levels 1))
  ;;(profile:report-time)
  ;;(profile:profile :methods 'fl.algebra:sparse-matrix->matlisp)
  ;;(profile:unprofile)
  ;; we should have N^{lr}_q = N^{lq}_r
  (with-items (&key mesh solution ansatz-space rhs) *result*
    (let ((average-tensor
	   (average-coefficient ansatz-space :coefficient 'FL.ELLSYS::A))
	  (correction-tensor
	   (convert-correction
	    (correction-tensor solution rhs)))
	  (dim (dimension mesh)))
      (check-elasticity-tensor average-tensor dim 0.0)
      (check-elasticity-tensor correction-tensor dim 1.0e-4)
      (check-elasticity-tensor (m- average-tensor correction-tensor) dim)))
  (effective-tensor *result*)

  (isotropic-elasticity-tensor :dim 2 :lambda 100 :mu 100)

  (plot (getbb *result* :solution) :component 1 :index 0)
  
  )

;;; (test-homogenization-elasticity)
(fl.tests:adjoin-test 'test-homogenization-elasticity)