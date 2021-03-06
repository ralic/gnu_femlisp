;;; -*- mode: lisp; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; debug.lisp - debug facility (from Peter Norvig's PAIP book)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (C) 1998-2002 Peter Norvig.
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

;;; This utility is a modified version from code contained in
;;; http://www.norvig.com/paip/auxfns.lisp.

(defpackage "FL.DEBUG"
  (:use "COMMON-LISP")
  (:export "DBG-ON" "DBG-OFF" "DBG-P" "DBG-WHEN" "DBG"
           "DBG-SHOW" "DBG-PRINT" "DBG-INDENT")
  (:documentation "This package adds debugging tools to Femlisp.  This is a
slightly modified version of the debugging suite proposed in @cite{(Norvig
1992)}."))

(in-package :fl.debug)

(defvar *dbg-ids* () "Identifiers used by dbg.")

(defun dbg-p (id)
  "Returns T if @arg{id} is in the debug list, NIL otherwise."
  (or (member t *dbg-ids*)
      (member id *dbg-ids*)))

(defun dbg-on (&rest ids)
  "Register ids for dbg."
  (setf *dbg-ids* (union ids *dbg-ids*)))

(defun dbg-off (&rest ids)
  "Stop debugging on the passed symbols.  With no arguments, stop debugging
altogether."
  (setf *dbg-ids* (and ids (set-difference *dbg-ids* ids))))

(defmacro dbg-when (id &body body)
  "Perform a check only if debugging @arg{id}."
  (let ((the-id (gensym)))
    `(let ((,the-id ,id))
       (when (or (eq ,the-id t) (dbg-p ,the-id))
         ,@body))))

(defgeneric dbg (id format-string &rest args)
  (:documentation "When debugging on @arg{id} print out the arguments
@arg{args} using the format in @arg{format-string}.")
  (:method (id format-string &rest args)
    (dbg-when id
      (format *debug-io* "~&~?~%" format-string args)
      (force-output *debug-io*))))

(defmacro dbg-show (id &rest args)
  `(dbg ,id "~@{~A=~S~%~}~%"
        ,@(loop for expr in args appending
               `(',expr ,expr))))

(defmacro dbg-print (id &rest args)
  (let ((result (gensym "RESULT")))
    `(let ((,result (list ,@args)))
       (apply #'dbg ,id "~@{~A=~S~%~}~%"
              (loop for expr in ',args
                 and value in ,result appending
                 (list expr value)))
       ,result)))

(defgeneric dbg-indent (id indent format-string &rest args)
  (:documentation "When debugging @arg{id}, print out the arguments
@arg{args} using the format in @arg{format-string} with indentation given
by @arg{indent}.")
  (:method (id indent format-string &rest args)
    (dbg-when id
      (format *debug-io* "~&~VT~?" indent format-string args)
      (force-output *debug-io*))))

;;;; Testing

