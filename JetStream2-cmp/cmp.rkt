;; JetStream2 Comparison
;; Copyright (C) 2019  Paulo Matos <pmatos@linki.tools>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require control
         json
         racket/contract
         racket/format
         racket/generic
         racket/list
         racket/set
         racket/string)

;; ---------------------------------------------------------------------------------------------------

(define-generics jsonifiable
  (jsonify jsonifiable))

(define-generics named
  (module-name named))

(define-generics timed
  (module-walltime timed))

(define-generics scored
  (module-score scored))

(struct jetstream2-output
  (modresults    ; hash: name -> module-results
   finalresults  ; final-results
   totalscore)  ; float
  #:methods gen:jsonifiable
  [(define/generic super-jsonify jsonify)
   (define (jsonify s)
     (make-hash `((module-results . ,(for/hash ([(k v) (in-hash (jetstream2-output-modresults s))])
                                       (values (string->symbol k) (super-jsonify v))))
                  (final-results . ,(super-jsonify (jetstream2-output-finalresults s)))
                  (total-score . ,(number->string (jetstream2-output-totalscore s))))))])

(struct module-results
  (name startup worst average score walltime)
  #:methods gen:named
  [(define (module-name s) (module-results-name s))]
  #:methods gen:timed
  [(define (module-walltime s) (module-results-walltime s))]
  #:methods gen:scored
  [(define (module-score s) (module-results-score s))]
  #:methods gen:jsonifiable
  [(define (jsonify s)
     (make-hash `((name . ,(module-results-name s))
                  (startup-time . ,(number->string (module-results-startup s)))
                  (worst-time . ,(number->string (module-results-worst s)))
                  (average-time . ,(number->string (module-results-average s)))
                  (score . ,(number->string (module-results-score s)))
                  (wall-time . ,(module-results-walltime s)))))])

(struct wsl-results
  (name stdlib tests score walltime)
  #:methods gen:named
  [(define (module-name s) (wsl-results-name s))]
  #:methods gen:timed
  [(define (module-walltime s) (wsl-results-walltime s))]
  #:methods gen:scored
  [(define (module-score s) (wsl-results-score s))]
  #:methods gen:jsonifiable
  [(define (jsonify s)
     (make-hash `((name . ,(wsl-results-name s))
                  (stdlib . ,(number->string (wsl-results-stdlib s)))
                  (tests . ,(number->string (wsl-results-tests s)))
                  (score . ,(number->string (wsl-results-score s)))
                  (wall-time . ,(wsl-results-walltime s)))))])

(struct final-results
  (stdlib mainrun first worst average)
  #:methods gen:jsonifiable
  [(define (jsonify s)
     (make-hash `((stdlib . ,(number->string (final-results-stdlib s)))
                  (mainrun . ,(number->string (final-results-mainrun s)))
                  (first . ,(number->string (final-results-first s)))
                  (worst . ,(number->string (final-results-worst s)))
                  (average . ,(number->string (final-results-average s))))))])

(define/contract (parse-final-results in)
  (input-port? . -> . final-results?)
  ; Input will look like this:
  ; Stdlib: 1.111
  ; MainRun: 0.234
  ; First: 52.725
  ; Worst: 53.054
  ; Average: 62.766

  (define stdlib (string->number (second (regexp-match #px"^Stdlib: ([0-9]+.[0-9]+)$" (read-line in)))))
  (define mainrun (string->number (second (regexp-match #px"^MainRun: ([0-9]+.[0-9]+)$" (read-line in)))))
  (define first (string->number (second (regexp-match #px"^First: ([0-9]+.[0-9]+)$" (read-line in)))))
  (define worst (string->number (second (regexp-match #px"^Worst: ([0-9]+.[0-9]+)$" (read-line in)))))
  (define average (string->number (second (regexp-match #px"^Average: ([0-9]+.[0-9]+)$" (read-line in)))))

  (final-results stdlib mainrun first worst average))


(define/contract (parse-module in)
  (input-port? . -> . (or/c module-results? wsl-results?))
  ; Input will look like this:
  ; Running acorn-wtb:
  ;  Startup: 11.547
  ;  Worst Case: 12.048
  ;  Average: 12.323
  ;  Score: 11.968
  ;  Wall time: 0:02.787
  (define name (second (regexp-match #px"^Running ([^:]+):$" (read-line in))))
  (printf "Parsing ~a~n" name)

  (cond
    [(string=? name "WSL")
     (define stdlib (string->number (second (regexp-match #px"^[[:blank:]]+Stdlib: ([0-9]+(.[0-9]+)?)$" (read-line in)))))
     (define tests (string->number (second (regexp-match #px"^[[:blank:]]+Tests: ([0-9]+(.[0-9]+)?)$" (read-line in)))))
     (define score (string->number (second (regexp-match #px"^[[:blank:]]+Score: ([0-9]+(.[0-9]+)?)$" (read-line in)))))
     (define walltime (second (regexp-match #px"^[[:blank:]]+Wall time: ([0-9]+:[0-9]+\\.[0-9]+)$" (read-line in))))

     (wsl-results name stdlib tests score walltime)]
    [else
     (define startup (string->number (second (regexp-match #px"^[[:blank:]]+Startup: ([0-9]+(.[0-9]+)?)$" (read-line in)))))
     (define worstcase (string->number (second (regexp-match #px"^[[:blank:]]+Worst Case: ([0-9]+(.[0-9]+)?)$" (read-line in)))))
     (define average (string->number (second (regexp-match #px"^[[:blank:]]+Average: ([0-9]+(.[0-9]+)?)$" (read-line in)))))
     (define score (string->number (second (regexp-match #px"^[[:blank:]]+Score: ([0-9]+(.[0-9]+)?)$" (read-line in)))))
     (define walltime (second (regexp-match #px"^[[:blank:]]+Wall time: ([0-9]+:[0-9]+\\.[0-9]+)$" (read-line in))))

     (module-results name startup worstcase average score walltime)]))

(define/contract (parse-result-file f)
  (path-string? . -> . jetstream2-output?)
  ; File will look like this:
  ;  Starting JetStream2
  ;  Running WSL:
  ;    Stdlib: 1.111
  ;    Tests: 0.234
  ;    Score: 0.510
  ;    Wall time: 0:25.869
  ; Running UniPoker:
  ;    Startup: 61.728
  ;    Worst Case: 50
  ; ...
  ;
  ; Stdlib: 1.111
  ; MainRun: 0.234
  ; First: 52.725
  ; Worst: 53.054
  ; Average: 62.766
  ;
  ; Total Score:  51.565
  (call-with-input-file* f #:mode 'text
    (lambda (in)
      (define header (read-line in))
      (unless (string=? header "Starting JetStream2")
        (error 'parse-result-file "unexpected results header: ~a" header))

      (define modules (make-hash))
      (while (not (char=? (peek-char in) #\newline))
        (define mod (parse-module in))
        (hash-set! modules (string->symbol (module-name mod)) mod))

      ; read two new lines
      (read-char in)
      (read-char in)

      ; read final
      (define final (parse-final-results in))

      ; another new line
      (read-char in)

      ; final score
      (define last-line (read-line in))
      (define total-score (string->number (string-trim (second (string-split last-line ":")))))
      (jetstream2-output modules final total-score))))

(define/contract (find-common-modules r1 r2)
  (jetstream2-output? jetstream2-output? . -> . (listof symbol?))

  (define r1-mods (apply set (hash-keys (jetstream2-output-modresults r1))))
  (define r2-mods (apply set (hash-keys (jetstream2-output-modresults r2))))

  (set->list (set-intersect r1-mods r2-mods)))

(define/contract (percent n1 n2)
  (number? number? . -> . number?)
  (* (/ (- n2 n1) n1) 100))

(define/contract (print-row name r1 r2)
  (string? any/c any/c . -> . void?)
  (if (and (number? r1) (number? r2))
      (printf "~a:\t~a\t~a\t~a%~n" name r1 r2 (~r (percent r1 r2) #:precision 2))
      (printf "~a:\t~a\t~a~n" name r1 r2)))

(define (compare-modules m1 m2)

  (unless (string=? (module-name m1) (module-name m2))
    (error 'compare-modules "given modules of different names ~a, ~a" (module-name m1) (module-name m2)))

  (printf "Module ~a:~n" (module-name m1))

  (cond
    [(string=? (module-name m1) "WSL")
     (print-row "Stdlib" (wsl-results-stdlib m1) (wsl-results-stdlib m2))
     (print-row "Tests" (wsl-results-stdlib m1) (wsl-results-stdlib m2))
     (print-row "Score" (wsl-results-score m1) (wsl-results-score m2))
     (print-row "Wall time" (wsl-results-walltime m1) (wsl-results-walltime m2))]
    [else
     (print-row "Startup" (module-results-startup m1) (module-results-startup m2))
     (print-row "Worst Case" (module-results-worst m1) (module-results-worst m2))
     (print-row "Average" (module-results-average m1) (module-results-average m2))
     (print-row "Score" (module-results-score m1) (module-results-score m2))
     (print-row "Wall time" (module-results-walltime m1) (module-results-walltime m2))]))

(define (compare-finals f1 f2)
  (final-results? final-results? . -> . void?)

  (print-row "Stdlib" (final-results-stdlib f1) (final-results-stdlib f2))
  (print-row "MainRun" (final-results-mainrun f1) (final-results-mainrun f2))
  (print-row "First" (final-results-first f1) (final-results-first f2))
  (print-row "Worst" (final-results-worst f1) (final-results-worst f2))
  (print-row "Average" (final-results-average f1) (final-results-average f2)))

(define (compare-jetstream2 n1 r1 n2 r2)
  (printf "Comparing JetStream2 results of ~a and ~a~n" n1 n2)

  (define common-modules (find-common-modules r1 r2))
  (unless (= (length common-modules)
             (hash-count (jetstream2-output-modresults r1))
             (hash-count (jetstream2-output-modresults r2)))
    (fprintf (current-error-port) "WARNING: Not all modules are common - comparing COMMON modules only~n"))

  (for ([m (in-list common-modules)])
    (compare-modules (hash-ref (jetstream2-output-modresults r1) m)
                     (hash-ref (jetstream2-output-modresults r2) m)))

  (printf "~n~n")
  (compare-finals (jetstream2-output-finalresults r1)
                  (jetstream2-output-finalresults r2))

  (define score1 (jetstream2-output-totalscore r1))
  (define score2 (jetstream2-output-totalscore r2))
  (print-row "Total Score" score1 score2)

  (show-winners-by-duration n1 r1 n2 r2 common-modules))

(define (time->ms strtime)
  (define-values (mins secs mss) (apply values (map string->number (rest (regexp-match #px"([0-9]+):([0-9]+).([0-9]+)" strtime)))))
  (+ mss (* secs 1000) (* mins 60000)))

(define (show-winners-by-duration n1 r1 n2 r2 common)
  (define winners
    (for/list ([m (in-list common)])
      (define m1 (hash-ref (jetstream2-output-modresults r1) m))
      (define m2 (hash-ref (jetstream2-output-modresults r2) m))

      (define name (module-name m1))
      (define mstime1 (time->ms (module-walltime m1)))
      (define mstime2 (time->ms (module-walltime m2)))

      (define score1 (module-score m1))
      (define score2 (module-score m2))

      (define winner (if (> score1 score2) n1 n2))
      (define winnertime (if (> score1 score2) mstime1 mstime2))
      (define-values (winnerscore loserscore)
        (if (> score1 score2)
            (values score1 score2)
            (values score2 score1)))

      (cons winnertime (list name winner winnerscore loserscore))))

  (define sorted-winners (sort winners < #:key car))

  (printf "~nWINNERS:~n")
  (printf "--------~n")

  (for ([w (in-list sorted-winners)])
    (define-values (name winner winnerscore loserscore) (apply values (rest w)))
    (printf "~a\t~a\t~a\t~a (vs ~a)~n" (first w) name winner winnerscore loserscore)))

(module+ main

  (require racket/cmdline)

  (define-values (n1 f1 n2 f2)
    (command-line
     #:program "jetstream2-cmp"
     #:args (n1 filename1 n2 filename2)
     (unless (file-exists? filename1)
       (error 'jetstream2-cmp "filename does not exist: ~a" filename1))
     (unless (file-exists? filename2)
       (error 'jetstream2-cmp "filename does not exist: ~a" filename2))

     (values n1 filename1 n2 filename2)))

  (compare-jetstream2 n1 (parse-result-file f1)
                      n2 (parse-result-file f2)))
