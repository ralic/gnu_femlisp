;;; -*- mode: lisp; -*-

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

(in-package application)

(defun further-laplace-tests ()
  "This function provides further tests for Laplace problems, partially on
non-structured meshes and/or on domains with curved boundary."

  ;; 1D tests
  (format t "~%1d Laplace test with nonzero rhs~%")
  
  (let ((problem
	 (let ((dim 1))
	   (standard-cdr-problem
	    (n-cube-domain dim)
	    :diffusion (identity-diffusion-tensor dim)
	    :source (function->coefficient #'(lambda (x) #I"exp(x[0])"))))))
    (check-h-convergence problem 1 6 :order 1 :position #(0.5))
    (check-p-convergence problem 1 10 :level 1 :position #(0.5)))
  
  (format t "~%1d Laplace test with Dirichlet bc~%")
  (let* ((dim 1)
	 (problem
	  (standard-cdr-problem
	   (n-cube-domain dim)
	   :diffusion (identity-diffusion-tensor dim)
	   :source (function->coefficient #'(lambda (x) #I"exp(x[0])"))
	   :dirichlet (function->coefficient
		       #'(lambda (x) #I"if (x[0]==0.0) then 0.0 else 1.0")))))
    (check-h-convergence problem dim 6 :order 1 :position #(0.5))
    (check-p-convergence problem dim 5 :level 0 :position #(0.5)))

  ;; 2D tests
  (format t "~%2d Laplace test on a triangle domain~%")
  
  (let ((problem (laplace-test-problem-on-domain *unit-triangle-domain*)))
    (check-h-convergence problem 2 6 :order 1 :position #(0.33 0.33)
			 :iteration (geometric-cs :base-level 2 :fmg t))
    (check-p-convergence problem 2 6 :level 2 :position #(0.33 0.33) :method :lu))
  
  (format t "~%2d Laplace test on the unit circle, exact solution u(0,0) = 0.25~%")
  (let ((problem (laplace-test-problem-on-domain
		  #+(or) *circle-domain*
		  (n-ball-domain 2)
		  )))
    (format t "~%h-refinement, O(h^2) convergence~%")
    (check-h-convergence problem 1 3 :order 1 :position #(0.0 0.0)
			 :iteration (geometric-cs :fmg t))
    (format t "~%p-refinement, no convergence, because domain is not approximated~%")
    (check-p-convergence problem 1 3 :level 2 :position #(0.0 0.0) :iteration :lu)
    (format t "~%p-refinement, exponential convergence due to isoparametric approximation~%")
    (check-p-convergence problem 1 5 :level 2 :position #(0.0 0.0)
			 :isopar t :iteration :lu))

  (format t "~%Laplace with exact solution u=exp(x+y), -> u(1/2,1/2)=1.6487212707~%")
  (let* ((dim 2)
	 (problem
	  (standard-cdr-problem
	   (n-cube-domain dim)
	   :diffusion (identity-diffusion-tensor dim)
	   :source
	   (function->coefficient #'(lambda (x) #I"-2.0*exp(x[0]+x[1])"))
	   :dirichlet
	   (function->coefficient #'(lambda (x) #I"exp(x[0]+x[1])")))))
    ;;(plot (solve-laplace problem 2 1)))
    (check-h-convergence problem 1 3 :order 1 :position #(0.25 0.25)
			 :method :ni :mg-steps 1)
    (check-p-convergence problem 1 5 :level 0 :position #(0.25 0.25) :mg-steps 5))
  
  ;; 3D tests
  (format t "~%3d Laplace test on a tetrahedron~%")
  (time
   (let ((problem (laplace-test-problem-on-domain *unit-tetrahedron-domain*)))
     (check-h-convergence problem 2 3 :order 1 :position #(0.25 0.25 0.25)
			  :iteration (geometric-cs :base-level 2 :fmg t))
     (check-p-convergence problem 1 3 :level 2 :position #(0.25 0.25 0.25) :method :lu)))

  (format t "~%Laplace with exact solution u=x*y*z(1-x-y-z), i.e. u(1/4,1/4,1/4)=1/256=3.90625e-3~%")
  (let* ((domain *unit-tetrahedron-domain*)
	 (problem
	  (standard-cdr-problem
	   domain
	   :diffusion (identity-diffusion-tensor (dimension domain))
	   :source (make-instance
		    '<coefficient>
		    :eval #'(lambda (coeff-input)
			      (let* ((in (ci-global coeff-input)))
				#I"2.0*(in[1]*in[2]+in[0]*in[2]+in[0]*in[1])"))))))
    (check-h-convergence problem  2 4 :order 1 :position #(0.25 0.25 0.25)
			 :iteration (geometric-cs :base-level 2 :fmg t))
    ;; integration appears to be ok, because it yields the exact solution
    ;; for ansatz spaces that include the solution
    (check-p-convergence problem 1 5 :level 0 :position #(0.25 0.25 0.25))
    (check-p-convergence problem 4 4 :level 1 :position #(0.25 0.25 0.25)))

  (format t "~%3d Laplace test on the unit ball, exact solution u(0,0,0)=1/6=0.1666...~%")
  (let ((problem (laplace-test-problem-on-domain (n-ball-domain 3))))
    ;;(plot (solve-laplace problem 1 3 :method :lu :parametric (lagrange-mapping 3)))
    (time (check-h-convergence problem 0 3 :order 1 :position #(0.0 0.0 0.0)
			       :iteration (geometric-cs :fmg t)))
    ;; The following test could still be an error, because convergence
    ;; seems to be not exponential.
    #+(or)
    (time (check-p-convergence problem 1 3 :level 1 :position #(0.0 0.0 0.0) :isopar t))
    )
  )

;;; (further-laplace-tests)
(adjoin-femlisp-test #'further-laplace-tests)