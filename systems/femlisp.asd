;;; -*- mode: lisp; fill-column: 70; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; femlisp.asd - System definition file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (C) 2017-
;;; Nicolas Neuss, Friedrich-Alexander-Universitaet Erlangen-Nuernberg
;;; All rights reserved.
;;; 
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
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
;;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
;;; IN NO EVENT SHALL THE AUTHOR, THE FAU ERLANGEN-NUERNBERG, OR OTHER
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

(asdf:defsystem :femlisp
  :author "Nicolas Neuss"
  :license "Modified BSD"
  :depends-on (:femlisp-basic
               :femlisp-parallel :femlisp-matlisp
               :femlisp-dictionary
               :infix :flexi-streams :cl-ppcre :cl-gd)
  :pathname "../src"
  :around-compile call-with-read-double-float-environment
  :components
  ((:module
    "function"
    :components
    ((:file "function-defp")
     (:file "function" :depends-on ("function-defp"))
     (:file "polynom" :depends-on ("function"))
     (:file "spline" :depends-on ("polynom"))))
   ;;
   ;; Mesh
   ;;
   (:module
    "mesh"
    :depends-on ("function")
    :components
    ((:file "mesh-defp")
     (:file "cell" :depends-on ("mesh-defp"))
     (:file "skeleton" :depends-on ("cell"))
     (:file "identify" :depends-on ("skeleton"))
     (:file "refine" :depends-on ("identify"))
     (:file "vertex" :depends-on ("refine"))
     (:file "simplex" :depends-on ("vertex"))
     (:file "product-cell" :depends-on ("simplex"))
     (:file "skeleton-build" :depends-on ("product-cell" "identify"))
     (:file "anisotropic" :depends-on ("product-cell" "skeleton-build"))
     (:file "domain" :depends-on ("skeleton-build"))
     (:file "mesh" :depends-on ("domain"))
     (:file "meshgen" :depends-on ("mesh"))
     (:file "blending" :depends-on ("meshgen"))
     (:file "triangulate" :depends-on ("blending"))
     (:file "triangle" :depends-on ("triangulate"))
     (:file "tetgen" :depends-on ("triangulate" "triangle"))
     (:file "extend" :depends-on ("meshgen"))
     ))
   ;;
   ;; Problems
   ;;
   (:module
    "problem"
    :depends-on ("mesh")
    :components
    ((:file "problem-defp")
     (:file "problem" :depends-on ("problem-defp"))
     (:file "pde-problem" :depends-on ("problem"))
     (:file "pdef" :depends-on ("pde-problem"))
     (:file "evp" :depends-on ("pdef"))
     (:file "time" :depends-on ("pdef"))
     (:file "ellsys" :depends-on ("evp" "time" "pdef"))
     (:file "cdr" :depends-on ("ellsys"))
     ;;(:file "cdrsys" :depends-on ("cdr"))
     (:file "elasticity" :depends-on ("ellsys"))
     (:file "navier-stokes" :depends-on ("ellsys"))
     ;;(:file "navier-stokes-ellsys" :depends-on ("ellsys"))
     ))
   ;;
   ;; Iteration
   ;;
   (:module
    "iteration"
    :depends-on ("function" "problem")
    :components
    ((:file "iteration-defp")
     (:file "iterate" :depends-on ("iteration-defp"))
     (:file "linit" :depends-on ("iteration-defp"))
     (:file "blockit" :depends-on ("linit"))
     (:file "krylow" :depends-on ("linit"))
     (:file "solve" :depends-on ("iteration-defp" "iterate"))
     (:file "linsolve" :depends-on ("linit" "solve"))
     (:file "nlsolve" :depends-on ("linsolve"))
     (:file "evpsolve" :depends-on ("nlsolve"))
     (:file "multigrid-defp" :depends-on ("iteration-defp"))
     (:file "multigrid" :depends-on ("linit" "linsolve" "multigrid-defp"))
     (:file "amg" :depends-on ("multigrid"))
     (:file "selection-amg" :depends-on ("amg"))
     (:file "aggregation-amg" :depends-on ("amg"))
     (:file "stueben" :depends-on ("selection-amg"))))
   ;;
   ;; Discretization
   ;;
   (:module
    "discretization"
    :depends-on ("function" "mesh" "problem" "iteration")
    :components
    ((:file "discretization-defp")
     (:file "discretization" :depends-on ("discretization-defp"))
     (:file "quadrature" :depends-on ("discretization-defp"))
     (:file "fe" :depends-on ("discretization" "quadrature"))
     (:file "ansatz-space" :depends-on ("fe"))
     (:file "lagrange" :depends-on ("ansatz-space"))
     (:file "fetransfer" :depends-on ("ansatz-space" "lagrange"))
     (:file "sparseas" :depends-on ("ansatz-space" "fetransfer"))
     (:file "sparseif" :depends-on ("ansatz-space" "sparseas"))
     (:file "feeval" :depends-on ("ansatz-space" "sparseif"))
     (:file "constraints" :depends-on ("ansatz-space" "sparseif"))
     (:file "assembly-heap" :depends-on ("discretization-defp"))
     (:file "fedisc" :depends-on ("sparseif" "constraints" "assembly-heap"))
     ;;
     ;;(:file "cdr-fe" :depends-on ("fedisc"))
     (:file "system-fe" :depends-on ("fedisc"))
     (:file "ellsys-fe" :depends-on ("fedisc"))
     (:file "elasticity-fe" :depends-on ("system-fe"))
     (:file "navier-stokes-fe" :depends-on ("system-fe"))
     ;;(:file "cdrsys-fe" :depends-on ("system-fe"))
     ))
   (:module
    "special-iteration"
    :depends-on ("mesh" "problem" "discretization" "iteration")
    :pathname "iteration"
    :components
    ((:file "geomg-defp")
     (:file "geoblock" :depends-on ("geomg-defp"))
     (:file "vanka" :depends-on ("geoblock"))
     (:file "geomg" :depends-on ("geoblock"))))
   ;;
   ;; Post-processing
   ;;
   (:module
    "graphic"
    :components
    ((:file "graphics-defp" :depends-on ())
     (:file "graphics" :depends-on ("graphics-defp"))
     (:file "dx" :depends-on ("graphics"))
     (:file "vtk" :depends-on ("graphics"))
     (:file "gnuplot" :depends-on ("graphics"))
     ))
   (:module
    "plot"
    :depends-on ("graphic" "mesh" "problem" "discretization")
    :components
    ((:file "plot-defp")
     (:file "plot" :depends-on ("plot-defp"))
     (:file "plot-dx" :depends-on ("plot"))
     (:file "meshplot" :depends-on ("plot-dx"))
     (:file "feplot" :depends-on ("meshplot"))
     (:file "coeffplot" :depends-on ("feplot"))
     (:file "function-plot" :depends-on ("plot-dx"))
     (:file "asaplot" :depends-on ("plot-dx"))
     (:file "plot-gnuplot" :depends-on ("plot"))
     (:file "plot-vtk" :depends-on ("plot"))
     (:file "picture" :depends-on ("plot"))
     ))
   ;;
   ;; Strategy
   ;;
   (:module
    "strategy"
    :depends-on ("mesh" "problem" "discretization" "iteration"
			"special-iteration" "plot")
    :components
    ((:file "strategy-defp")
     (:file "strategy" :depends-on ("strategy-defp"))
     (:file "strategy-utilities" :depends-on ("strategy"))
     (:file "error-estimator" :depends-on ("strategy-utilities"))
     (:file "error-indicator" :depends-on ("strategy-utilities"))
     (:file "fe-approximation" :depends-on
	    ("strategy" "strategy-utilities" "error-estimator" "error-indicator"))
     (:file "fe-interpolation" :depends-on ("fe-approximation"))
     (:file "fe-stationary" :depends-on ("fe-approximation"))
     (:file "fe-evp" :depends-on ("fe-stationary"))
     (:file "rothe" :depends-on ("fe-stationary"))
     (:file "rothe-ellsys" :depends-on ("rothe"))
     (:file "gps" :depends-on ("fe-stationary"))))
   ;;
   ;; Applications
   ;;
   (:module
    "applications"
    :depends-on ("function" "iteration" "mesh"
		 "problem" "discretization" "strategy" "plot")
    :components
    ((:module
      "domains"
      :components
      ((:file "domains-defp")
       (:file "circle-ring-domain" :depends-on ("domains-defp"))
       (:file "bl-cell" :depends-on ("domains-defp"))
       (:file "hole-domain" :depends-on ("domains-defp"))
       (:file "inlay-domain" :depends-on ("hole-domain"))
       ))
     (:file "application-defp" :depends-on ("domains"))
     (:file "app-utils" :depends-on ("application-defp"))
     (:module
      "demos"
      :depends-on ("app-utils" "domains")
      :components
      ((:file "application-demos")
       (:file "discretization-demos" :depends-on ("application-demos"))
       (:file "multigrid-demos" :depends-on ("application-demos"))
       (:file "refinement-demos" :depends-on ("application-demos"))
       (:file "problem-demos" :depends-on ("application-demos"))))
     (:module
      "cdr"
      :depends-on ("demos" "domains")
      :components
      ((:file "tools")
       (:file "model-problem" :depends-on ("tools"))
       (:file "unstructured" :depends-on ("tools"))
       (:file "locref" :depends-on ("tools"))
       (:file "hom-cdr" :depends-on ("tools"))
       (:file "bl-cdr")
       (:file "mg-cdr")
       (:file "amg-cdr" :depends-on ("tools"))
       (:file "bratu")
       (:file "evp-cdr")
       (:file "heat")
       (:file "sturm")))
     (:module
      "elasticity"
      :depends-on ("demos" "domains")
      :components
      ((:file "model-problem")
       (:file "elahom")))
     (:module
      "navier-stokes"
      :depends-on ("demos" "domains")
      :components
      ((:file "driven-cavity")
       (:file "hom-ns")))
     (:module
      "articles"
      :depends-on ("demos" "domains" "cdr" "elasticity")
      :components
      ((:file "heuveline-rannacher-2003")
       (:file "heisig-neuss-2017")))
     (:module
      "books"
      :depends-on ("demos" "domains" "cdr" "elasticity")
      :components
      ())
     (:module
      "courses"
      :depends-on ("demos" "domains" "cdr" "elasticity")
      :components
      ())
     (:module
      "talks"
      :depends-on ("demos" "domains" "cdr" "elasticity")
      :components
      ((:file "effcoeff")))
     )					; application components
    )					; applications module
    (:file "finalize" :depends-on ("applications"))
   )					; femlisp modules
  )


