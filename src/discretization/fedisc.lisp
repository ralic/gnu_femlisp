;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  fedisc.lisp
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

(in-package :fl.discretization)

;;; This module contains routines for composing functions for local
;;; assembly to a discretization on a global mesh or for constructing a
;;; multi-level discretization.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Interface for standard customization (ellsys-fe.lisp)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgeneric discretize-locally (problem coeffs fe qrule fe-geometry
				&key matrix mass-matrix rhs local-u local-v
				fe-parameters)
  (:documentation "Computes a local stiffness matrix and right-hand side.
The algorithm will usually work as follows:

@enumerate
@item Get coefficient functions for the patch of the cell.
@item Compute geometry information for all ips (values and gradients of the shape functions).
@item Loop over integration points ip:
  @enumerate
    @item If necessary, compute input for coefficient functions.
          This input may contain values of finite element function in the
          property list @arg{fe-parameters}.
    @item Evaluate coefficient functions at ips.
    @item Add the contributions for matrix and right-hand side to @arg{local-mat} and @arg{local-rhs}.
  @end enumerate
@end enumerate

If @arg{local-u} and @arg{local-v} are set, then
@arg{local-v}*@arg{local-mat}*@arg{local-u} and
@arg{local-v}*@arg{local-rhs} is computed.  This feature may be used later
on for implementing matrixless computations."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Interior assembly
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun assemble-cell (cell ansatz-space &key mass-matrix)
  (let* ((h-mesh (hierarchical-mesh ansatz-space))
         (problem (problem ansatz-space))
         (patch (patch-of-cell cell h-mesh))
         (patch-properties (skel-ref (domain h-mesh) patch)))
    ;; for the moment, we assume that the problem is resolved by the
    ;; domain structure, i.e. that distributional coefficients occur
    ;; only on patches.
    (whereas ((coeffs (filter-applicable-coefficients
                       (coefficients-of-cell cell h-mesh problem)
                       cell patch :constraints nil)))
      (dbg :disc "Coefficients: ~A" coeffs)
      (let* ((fe (get-fe ansatz-space cell))
             (qrule (quadrature-rule fe))
             (geometry (fe-cell-geometry
                        cell (integration-points qrule)
                        :weights (integration-weights qrule)
                        :metric (getf patch-properties 'FL.MESH::METRIC)
                        :volume (getf patch-properties 'FL.MESH::VOLUME)))
             (local-mat (make-local-mat ansatz-space cell))
             (local-mass-mat (and mass-matrix (make-local-mat ansatz-space cell)))
             (local-rhs (make-local-vec ansatz-space cell))
             (fe-paras (loop for obj in (required-fe-functions coeffs)
                          collect obj collect
                          (get-local-from-global-vec
                           cell (get-property problem (car obj))))))
        (dbg :disc "FE-parameters: ~A" fe-paras)
        (discretize-locally
         problem coeffs fe qrule geometry
         :matrix local-mat :rhs local-rhs :mass-matrix local-mass-mat
         :fe-parameters fe-paras)
        (dbg :disc "Matrix:~%~A~&Rhs:~%~A" local-mat local-rhs)
        (values local-mat local-rhs local-mass-mat)))))
  
(defun assemble-interior (ansatz-space &key level (where :surface)
			  matrix mass-matrix rhs)
  "Assemble the interior, i.e. ignore constraints arising from boundaries
and hanging nodes.  Discretization is done using the ansatz space
@arg{ansatz-space} on level @arg{level}.  The level argument will usually
be @code{NIL} when performing a global assembly, and be equal to some
number when assembling coarse level matrices for multigrid.  The argument
@arg{where} is a flag indicating where assembly is to be done.  It should
be one of the keywords @code{:surface}, @code{:refined}, @code{:all}.  The
arguments @arg{matrix}, @arg{rhs} should contain vectors/matrices where the
local assembly is accumulated.  Boundary conditions and constraints are not
taken into account within this routine.

In general, this function does most of the assembly work.  Other steps like
handling constraints are intricate, but usually of lower computational
complexity."
  (with-workers
      ((lambda (cell)
         (multiple-value-bind (local-mat local-rhs local-mass-mat)
             (assemble-cell cell ansatz-space :mass-matrix mass-matrix)
           ;; accumulate to global matrix and rhs (if not nil)
           (when (and rhs local-rhs)
             (increment-global-by-local-vec cell rhs local-rhs))
           (when (and matrix local-mat)
             (increment-global-by-local-mat cell matrix local-mat))
           (when (and mass-matrix local-mass-mat)
             (increment-global-by-local-mat cell mass-matrix local-mass-mat)))))
    ;; fill pipeline for workers
    (let* ((h-mesh (hierarchical-mesh ansatz-space))
           (level-skel (if level (cells-on-level h-mesh level) h-mesh)))
      (doskel (cell level-skel)
        (when (ecase where
                (:refined (refined-p cell h-mesh))
                (:surface (not (refined-p cell h-mesh)))
                (:all t))
          (work-on cell))))))

#+(or)  ; new, not yet active
(defun compute-interior-level-matrix (interior-mat sol level)
  "This function is needed for the multilevel decomposition of geometric
multigrid."
  (let* ((ansatz-space (ansatz-space interior-mat))
	 (h-mesh (hierarchical-mesh ansatz-space))
	 (top-level (top-level h-mesh))
	 (mat (extract-level interior-mat level)))
    ;; extend the surface matrix on this level by the refined region
    (when (< level top-level)
      (assemble-interior ansatz-space :matrix mat :solution sol :level level :where :refined))
    ;; extend it by the hanging-node region
    (loop for level from (1- level) downto 0
	  for constraints =
	  (nth-value 1 (hanging-node-constraints ansatz-space :level level :ip-type t))
	  for constraints-p =
	  (eliminate-hanging-node-constraints-from-matrix mat constraints)
	  while constraints-p do
	  (add-local-part! mat interior-mat (column-table constraints)
			   :directions '(:right)))
    ;; and return the result
    mat))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Assembly of full problem
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun fe-discretize-linear-problem (blackboard)
  "Finite element discretization for a linear problem or the linearization
of a nonlinear problem."
  (with-items (&key ansatz-space cells (assemble-constraints-p t)
		    matrix mass-matrix rhs solution
		    interior-matrix interior-rhs interior-mass-matrix
		    discretized-problem)
      blackboard
    (let ((problem (problem ansatz-space)))
      (setq interior-matrix (make-ansatz-space-automorphism ansatz-space))
      (setq interior-rhs (make-ansatz-space-vector ansatz-space))
      (when (typep problem '<evp-mixin>)
	(setf interior-mass-matrix (make-ansatz-space-automorphism ansatz-space)))
      (assert (same-p (remove nil (list interior-matrix interior-mass-matrix interior-rhs solution))
		      :key #'ansatz-space))
      ;; interior assembly
      (assert (null cells) () "TBI: assembly on cells")
      (assemble-interior ansatz-space :where :surface
			 :matrix interior-matrix :rhs interior-rhs
			 :mass-matrix interior-mass-matrix)
      (dbg-when :disc
	(format t "Interior matrix:~%")
	(show interior-matrix)
	(format t "Interior mass matrix:~%")
	(show interior-mass-matrix)
	(format t "Interior rhs:~%")
	(show interior-rhs))
      (when assemble-constraints-p (assemble-constraints ansatz-space))
      (destructuring-bind (&key constraints-P constraints-Q constraints-r
				ip-constraints-P ip-constraints-Q ip-constraints-r
				&allow-other-keys)
	  (properties ansatz-space)
	(multiple-value-bind (result-mat result-rhs)
	    (eliminate-constraints interior-matrix interior-rhs
				   ip-constraints-P ip-constraints-Q ip-constraints-r)
	  ;; We put the constraints in the matrix.  An alternative would be
	  ;; to store the constraints in the ansatz space and to enforce them
	  ;; after application of the operator
	  (m+! constraints-P result-mat)
	  (m-! constraints-Q result-mat)
	  (m+! constraints-r result-rhs)
	  ;; ??? What about eigenvalue problems?
	  
	  ;; for nonlinear problems the solution vector is important
	  (setf (get-property result-mat :solution) solution
		(get-property result-rhs :solution) solution)
	  ;; we keep also interior-matrix and interior-rhs which may be of
	  ;; use when assembling for local multigrid.  Note that they will
	  ;; usually share most of their data with result-mat/result-rhs.
	  (setf (get-property result-mat :interior-matrix) interior-matrix
		(get-property result-mat :interior-mass-matrix) interior-mass-matrix
		(get-property result-rhs :interior-rhs)	interior-rhs)
	  (setf matrix result-mat	; might be dropped later on
		mass-matrix interior-mass-matrix
		rhs result-rhs)
	  (assert (and result-mat result-rhs))))))
  ;; return blackboard
  blackboard)

(defun fe-discretize (blackboard)
  "Finite element discretization for an ansatz space provided on the
blackboard."
  (with-items (&key ansatz-space solution matrix mass-matrix rhs discretized-problem)
      blackboard
    (let ((problem (problem ansatz-space)))
      (setf discretized-problem
	    (cond
	      ((typep problem '<evp-mixin>)
	       ;; eigenvalue problem
	       (fe-discretize-linear-problem blackboard)
	       (make-instance '<ls-evp>
			      :stiffness-matrix matrix
			      :mass-matrix mass-matrix
			      :eigenvalues (slot-value problem 'eigenvalues)
			      :multiplicity (multiplicity problem)
			      :solution (or solution (random-ansatz-space-vector ansatz-space))))
	      ((get-property problem 'linear-p)
	       ;; standard linear problem
	       (fe-discretize-linear-problem blackboard)
	       (make-instance '<lse> :matrix matrix :rhs rhs))
	      (t
	       ;; nonlinear problem
	       (make-instance '<nlse>
			      :linearization
			      #'(lambda (sol)
				  (setf (get-property problem :solution) sol)
				  (let ((bb (fe-discretize-linear-problem
					     (blackboard :problem problem
							 :ansatz-space ansatz-space
							 :solution sol))))
				    (with-items (&key matrix rhs) bb
				      (make-instance '<lse> :matrix matrix :rhs rhs))))
			      :solution
			      (or solution (make-ansatz-space-vector ansatz-space))))))))
  blackboard)

(defun discretize-globally (problem h-mesh fe-class)
  "Discretize @arg{problem} on the hierarchical mesh @arg{h-mesh} using
finite elments given by @arg{fe-class}."
  (let ((ansatz-space (make-fe-ansatz-space fe-class problem h-mesh)))
    (with-items (&key matrix rhs)
      (fe-discretize (blackboard :ansatz-space ansatz-space))
      (destructuring-bind (&key ip-constraints-P ip-constraints-Q
				ip-constraints-r &allow-other-keys)
	  (properties ansatz-space)
	(values matrix rhs ip-constraints-P ip-constraints-Q ip-constraints-r)))))

(defmethod discretize ((fedisc <fe-discretization>) (problem <pde-problem>) blackboard)
  "General discretization interface for FE."
  (whereas ((as (getbb blackboard :ansatz-space)))
    (assert (and (eq (fe-class as) fedisc)
		 (eq (problem as) problem)))
    (return-from discretize (fe-discretize blackboard)))
  (whereas ((mesh (getbb blackboard :mesh))) 
    (setf (getbb blackboard :ansatz-space)
	  (make-fe-ansatz-space fedisc problem mesh))
    (fe-discretize blackboard))
  (error "You have to provide either an ansatz-space or a mesh in the
blackboard."))
