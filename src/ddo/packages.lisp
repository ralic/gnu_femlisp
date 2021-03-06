(in-package :cl-user)

(defpackage "NET.SCIPOLIS.RELATIONS"
  (:nicknames "RELATIONS")
  (:use "COMMON-LISP"
        "FL.MACROS" "FL.UTILITIES" "FL.DEBUG" "FL.AMOP")
  (:import-from "TREES"
                "MAKE-BINARY-TREE" "RIGHT" "LEFT" "ROOT" "DATUM" "TEST" "PRED"
                "INSERT"
                "LOWER-BOUND-NODE-WITH-PATH" "LOWER-BOUND-NODE"
                "UPPER-BOUND-NODE-WITH-PATH" "UPPER-BOUND-NODE"
                "EXTREME-NODE-WITH-PATH"
                "MAKE-ITERATOR"
                "DOTREE" "PPRINT-TREE")
  (:export "LIST-COMPARISON" "MAKE-NUMBER-RELATION" "R-INSERT" "R-REMOVE" "R-SELECT" "R-SOME")
  (:documentation
   "This package provides relations built upon binary trees."))

(defpackage "DDO"
  (:use "COMMON-LISP"
        "FL.MACROS" "FL.UTILITIES" "FL.DEBUG" "FL.AMOP" "FL.PORT" "FL.PARALLEL"
        "NET.SCIPOLIS.RELATIONS"
        "CL-MPI-EXTENSIONS")
  (:import-from "TREES"
                "MAKE-BINARY-TREE" "RIGHT" "LEFT" "ROOT" "DATUM" "TEST" "PRED"
                "INSERT"
                "LOWER-BOUND-NODE-WITH-PATH" "LOWER-BOUND-NODE"
                "UPPER-BOUND-NODE-WITH-PATH" "UPPER-BOUND-NODE"
                "EXTREME-NODE-WITH-PATH"
                "MAKE-ITERATOR"
                "DOTREE" "PPRINT-TREE")
  (:import-from "CL-MPI"
                "MPI-INIT" "MPI-INITIALIZED" "MPI-COMM-SIZE" "MPI-COMM-RANK")
  (:export
   ;; specials.lisp
   "*DEBUG-SHOW-DATA*"
   "*SYNCHRONIZATION-REAL-TIME*"
   "*COMMUNICATION-REAL-TIME*"
   "*COMMUNICATION-SIZE*"
   ;; ddo.lisp
   "NEW-LOCAL-ID" "LOCAL-ID" "DISTRIBUTED-P"
   "DISTRIBUTED-DATA" "RESET-DISTRIBUTED-OBJECTS"
   "DDO-MIXIN" "DDO-CONTAINER-MIXIN"
   "DISTRIBUTED-P" "DISTRIBUTED-CONTAINER-P"
   "DISTRIBUTED-SLOTS" "DISTRIBUTED-SLOT-NAMES" "DISTRIBUTED-SLOT-VALUES"
   "DDO-PERFORMANCE-CHECK"
   ;; utils.lisp
   "MPI-DBG" "WITH-SPLIT-MPI-DEBUG-OUTPUT"
   "ALL-PROCESSORS" "OWNERS" "NEIGHBORS-FOR" "DO-NEIGHBORS" "MASTERP"
   "DO-PROCESSORS" "DO-NEIGHBORS" "NEIGHBORS"
   ;; synchronize.lisp
   "ENSURE-DISTRIBUTED-CLASS" "MAKE-DISTRIBUTED-OBJECT" "MAKE-DISTRIBUTED-CONTAINER"
   "MINIMUM-ID-MERGER" "OP-MERGER"
   "INSERT-INTO-CHANGED"
   "SYNCHRONIZE" "*SYNCHRONIZATION-MERGER*"
   ;; remote-control.lisp
   "DDO" "DDOX" "DDO-" "DDO-CAPTURE")
  (:DOCUMENTATION
   "This package provides distributed objects."))

(defpackage "MPI-WORKER"
  (:use "CL" "MPI"
        "FL.MACROS" "FL.UTILITIES")
  (:export "WORKER-CONNECT"
           "*MPI-WORKERS*"
           "CONNECT-TO-MPI-WORKERS" "DISCONNECT-FROM-MPI-WORKERS"))

(defpackage "DDO-TEST"
  (:use "COMMON-LISP"
        "FL.MACROS" "FL.UTILITIES" "FL.DEBUG" "FL.AMOP" "FL.PARALLEL"
        "LFARM" "MPI"
        "RELATIONS" "DDO" "MPI-WORKER")
  (:export )
  (:documentation
   "This package uses what the others provide."))
