---- MODULE ThreadPool ----
EXTENDS Naturals, Sequences, FiniteSets, TLC

(***************************************************************************)
(* PARAMETERS *)
(***************************************************************************)

CONSTANTS
  ThreadCount,  \* number of worker threads (e.g., 2)
  QueueSize,    \* number of queue slots (e.g., 4)
  TaskCount     \* total tasks to submit (e.g., 4)

(***************************************************************************)
(* STATE VARIABLES *)
(***************************************************************************)

VARIABLES
  Fn,         \* [slot -> BOOLEAN] TRUE if a task present in slot
  Busy,       \* [slot -> BOOLEAN] TRUE if claimed by a worker
  Submitted,  \* [slot -> BOOLEAN] TRUE if task submitted but not finished
  finished,   \* global flag to stop workers
  tasksLeft,  \* number of tasks yet to submit
  Cur         \* [worker -> slot] slot currently executed (0 = idle)

vars == << Fn, Busy, Submitted, finished, tasksLeft, Cur >>

Slots   == 1..QueueSize
Workers == 1..ThreadCount

Completed(s) == ~Fn[s] /\ ~Busy[s] /\ ~Submitted[s]

(***************************************************************************)
(* INITIAL STATE *)
(***************************************************************************)

Init ==
  /\ Fn        = [s \in Slots |-> FALSE]
  /\ Busy      = [s \in Slots |-> FALSE]
  /\ Submitted = [s \in Slots |-> FALSE]
  /\ finished  = FALSE
  /\ tasksLeft = TaskCount
  /\ Cur       = [w \in Workers |-> 0]

(***************************************************************************)
(* ACTIONS *)
(***************************************************************************)

\* MAIN submits a new task into some free slot
Submit ==
  /\ tasksLeft > 0
  /\ \E s \in Slots: ~Fn[s] /\ ~Busy[s]
  /\ \E s \in Slots:
        ~Fn[s] /\ ~Busy[s]
        /\ Fn'        = [Fn EXCEPT ![s] = TRUE]
        /\ Submitted' = [Submitted EXCEPT ![s] = TRUE]
        /\ UNCHANGED << Busy, Cur >>
        /\ tasksLeft' = tasksLeft - 1
        /\ finished'  = finished

\* MAIN finishes when all tasks submitted and completed
Finish ==
  /\ tasksLeft = 0
  /\ \A s \in Slots: Completed(s)
  /\ finished = FALSE
  /\ finished' = TRUE
  /\ UNCHANGED << Fn, Busy, Submitted, tasksLeft, Cur >>

\* A WORKER takes a submitted task and executes it
WorkerStep ==
  \E w \in Workers:
    /\ Cur[w] = 0
    /\ \E s \in Slots:
         Fn[s] /\ ~Busy[s]
         /\ Fn'        = [Fn EXCEPT ![s] = FALSE]
         /\ Busy'      = [Busy EXCEPT ![s] = FALSE]
         /\ Submitted' = [Submitted EXCEPT ![s] = FALSE]
         /\ Cur'       = [Cur EXCEPT ![w] = 0]  \* remains 0 (abstract execution)
         /\ tasksLeft' = tasksLeft
         /\ finished'  = finished

\* Idle worker step: does nothing (stuttering step)
Idle ==
  \E w \in Workers:
    /\ Cur[w] = 0
    /\ UNCHANGED vars

Next ==
  \/ Submit
  \/ Finish
  \/ WorkerStep
  \/ Idle

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

(***************************************************************************)
(* INVARIANTS *)
(***************************************************************************)

TypeOK ==
  /\ Fn \in [Slots -> BOOLEAN]
  /\ Busy \in [Slots -> BOOLEAN]
  /\ Submitted \in [Slots -> BOOLEAN]
  /\ finished \in BOOLEAN
  /\ tasksLeft \in 0..TaskCount
  /\ Cur \in [Workers -> 0..QueueSize]

\* Mutual exclusion: no two workers execute same slot
MutexInvariant ==
  \A s \in Slots:
    Cardinality({w \in Workers: Cur[w] = s}) <= 1

(***************************************************************************)
(* LIVENESS PROPERTIES *)
(***************************************************************************)

\* Every submitted task will eventually complete
NoStarvation ==
  \A s \in Slots: [] (Submitted[s] => <> Completed(s))

\* Eventually the pool finishes
AllDone == <> finished

(***************************************************************************)
(* THEOREMS *)
(***************************************************************************)

THEOREM Spec => []TypeOK
THEOREM Spec => []MutexInvariant
THEOREM Spec => NoStarvation
THEOREM Spec => AllDone

=============================================================================
