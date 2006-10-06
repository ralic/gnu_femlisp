;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; feplot.lisp - plotting of fe functions
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

(in-package :fl.plot)

(with-memoization (:id 'local-evaluation-matrix :test 'equal)
  (defun local-evaluation-matrix (fe depth &optional (type :solution))
    "Returns a local evaluation matrix for the refcell-refinement-vertices of
the given depth."
    (memoizing-let ((fe fe) (depth depth) (type type))
      (funcall (ecase type
		 (:solution 'ip-values)
		 (:gradient 'ip-gradients))
	       fe (refcell-refinement-vertex-positions
		   (reference-cell fe) depth)))))

(defmethod graphic-commands ((asv <ansatz-space-vector>) (program (eql :dx))
			     &rest rest)
  (apply #'fl.graphic::dx-commands-data rest))

(defmethod plot ((asv <ansatz-space-vector>) &rest rest
		 &key depth component index key transformation
		 rank shape &allow-other-keys)
  "Plots a certain component of the ansatz space vector @arg{asv},
e.g. pressure for Navier-Stokes equations.  @arg{index} chooses one of
several solutions if @arg{asv} has multiplicity larger 1."
  (let* ((fe-class (fe-class (ansatz-space asv)))
	 (mesh (mesh asv))
	 (dim (embedded-dimension mesh))
	 (nr-comps (nr-of-components fe-class)))
    (ensure depth
	    #'(lambda (cell)
		(let ((order (discretization-order (get-fe fe-class cell))))
		  (when (and (arrayp order) component)
		    (setq order (aref order component)))
		  (case order
		    ((0 1) 0)
		    ((2) 1)
		    ((3 4) 2)
		    (t 3)))))
    (ensure component (when (= 1 nr-comps) 0))
    (ensure index (when (= (multiplicity asv) 1) 0))
    (ensure rank (if (and component index) 0 1))
    (ensure shape (unless (zerop rank) nr-comps))
    (apply #'graphic-output asv :dx
	   :depth depth
	   :cells (plot-cells mesh)
	   :dimension (plot-dimension dim)
	   :transformation (or transformation (plot-transformation dim))
	   :rank rank :shape shape
	   :cell->values
	   #'(lambda (cell)
	       (let* ((fe (get-fe fe-class cell))
		      (local-vec (get-local-from-global-vec cell fe asv))
		      (depth (if (numberp depth) depth (funcall depth cell)))
		      (m (nr-of-refinement-vertices cell depth))
		      (components (components fe)))
		 ;; not very nice: scalar-fe is special
		 (unless (vectorp local-vec)
		   (setq local-vec (vector local-vec)))
		 (let ((all (loop for k below (length components) collect
				  (vector-map (rcurry #'m*-tn (aref local-vec k))
					      (local-evaluation-matrix (aref components k) depth)))))
		   ;; we have to extract a one component value array
		   (if key
		       (coerce (loop for i below m collecting
				     (funcall key (map 'vector (rcurry #'vref i) all)))
			       'vector)
		       (if component
			   (map 'vector (lambda (vals) (vref vals index))
				(elt all component))
			   (coerce (loop for i below m collecting
					 (map 'vector (lambda (x) (vref x index))
						(map 'vector (rcurry #'vref i) all)))
				   'vector))))))
	   rest)))

#| Test of 1d plotting with dx
dx -script

data = Import("output.dx");
data = Options(data, "mark", "circle");
xyplot = Plot(data);
camera = AutoCamera(xyplot);
image = Render (xyplot, camera);
where = SuperviseWindow("femlisp-output", size=[480,480], visibility=2);
Display (image,where=where);
|#

#| Test of 2d vector plotting with dx
dx -script

data = Import("output.dx");
colored = AutoColor(data);
samples = Sample(data, 400);
glyphs = AutoGlyph(samples, type="arrow");
image = Collect(colored,glyphs);
image = Options(image, "rendering mode", "hardware");
where=SuperviseWindow("femlisp-image",size=[480,480],visibility=2);
where=SuperviseWindow("femlisp-image",size=[480,480],visibility=1);
camera = AutoCamera(image, direction="front", background="black", resolution=480, aspect=1.0);
Display (image, camera, where=where);

content = ReadImageWindow(where);
WriteImage(content, "test", "tiff");
|#
