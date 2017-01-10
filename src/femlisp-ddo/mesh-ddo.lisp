(in-package :ddo-femlisp)

(defmethod skel-map :around (func skel)
  (lret ((result (call-next-method)))
    (when (get-property skel :distributed-p)
      (setf (get-property result :distributed-p) t))))

(add-hook 'fl.mesh::skeleton-substance
          'assert-not-on-dd-interface
          (lambda (table)
            (dohash (cell table)
              (assert (not (distributed-p cell))))))

(add-hook 'fl.mesh::substance-boundary-cells
          'assert-non-distributed-substance-boundary
          (lambda (table)
            ;; check that all distributed substance faces have a remote neighbor
            (synchronize)
            (dohash (cell table)
              (when (distributed-p cell)
                (insert-into-changed cell)))
            (let ((*synchronization-merger*
                    (lambda (object id-value-pairs)
                      (let ((nr-neighbors (length id-value-pairs)))
                        (assert (= (length id-value-pairs) 2) ()
                                "Object ~A has ~D distributed neighbors"
                                object nr-neighbors)))))
              (synchronize))
            ;; remove those distributed faces
            (dohash (cell table)
              (when (distributed-p cell)
                (remhash cell table)))))

(defun mesh-graph (mesh)
  ;; we have to take care that the graph does
  ;; not depend at all on the internal cell ordering
  (let ((cells-of-highest-dim
          (safe-sort
           (cells-of-highest-dim mesh)
           (compare-lexicographically)
           :key #'midpoint))
        (table (make-hash-table)))
    (loop for cell in cells-of-highest-dim do
      (loop for side across (boundary cell)
            for key = (or (cell-identification side mesh) side)
            do (push cell (gethash key table))))
    (let ((edges (loop for key being each hash-key of table using (hash-value cells)
                       when (= (length cells) 2)
                         collect (append cells (list 1 key)))))
      (flet ((edge->vec (edge)
               (vector (position (edge-from edge) cells-of-highest-dim)
                       (position (edge-to edge) cells-of-highest-dim))))
        (sort edges (compare-lexicographically) :key #'edge->vec)))))

(defun distribute-mesh (mesh nr-workers)
  (let ((*graph* (mesh-graph mesh))
        (distribution (make-hash-table)))
    ;; fill distribution according to partition of mesh graph
    (loop for part in (partition-graph nr-workers)
          and k from 0 do
            (loop for cell in part do
              (loop for subcell across (subcells cell) do
                (pushnew k (gethash subcell distribution)))))
    ;; perform actual distribution
    (doskel (cell mesh)
      (let ((procs (gethash cell distribution)))
        ;; identified cells are distributed to the same processors
        (when (identified-p cell mesh)
          (setf procs (reduce #'union (identified-cells cell mesh)
                              :key (rcurry #'gethash distribution)
                              :initial-value ())))
        (if (member (mpi:mpi-comm-rank) procs)
            (unless (single? procs)
              (dbg :partition-mesh "Distributing ~A to ~A" cell procs)
              (ddo:ensure-distributed-class (class-of cell))
              (ddo:make-distributed-object cell procs))
            (remhash cell (etable mesh (dimension cell)))))))
  ;; propagate changes
  (synchronize)
  (setf (get-property mesh :distributed-p) t)
  )

(defmethod fl.mesh::do-refinement! :before
    ((skel <skeleton>) (refined-skel <skeleton>) (task list) &key refined-region)
  "Refines the distributed region first."
  (when (get-property skel :distributed-p)
    (setf (get-property refined-skel :distributed-p) t)
    (let ((distributed-task
            (remove-if-not #'distributed-p task :key #'car)))
      (dbg :ddo-refine "~D: Distributed cells to be refined: ~:{~A belonging to ~A~%~}"
           (mpi-comm-rank)
           (loop repeat 10
                 for (cell . nil) in distributed-task
                 collect (list cell (owners cell))))
      (when distributed-task
        (let ((tree (make-binary-tree
                     :red-black (list-comparison '(0 1))
                     :key (_ (let ((cell (car _)))
                               (list (dimension cell) (local-id cell)))))))
          (dbg :ddo-refine "Inserting in tree: ~D work units" (length distributed-task))
          (loop for work in distributed-task do
            (insert work tree))
          (dbg :ddo-refine "Working on tree")
          (dotree (work tree)
            (destructuring-bind (cell . rule) work
              (fl.mesh::refine-cell! rule cell skel refined-skel refined-region)
              ;; distribute children in the same way as the parent cell
              (let ((procs (owners cell)))
                (assert (> (length procs) 1))
                (for-each (lambda (child)
                            (make-distributed-object child procs))
                          (children cell skel))))))
        (dbg :ddo-refine "Synchronizing")
        (synchronize)))))
