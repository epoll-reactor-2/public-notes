---- MODULE ThreadPoolBuggy ----

EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
  ThreadCount, \* number of worker threads (e.g. 2)
  QueueSize,   \* number of queue slots (e.g. 4)
  TaskCount    \* total tasks to submit (e.g. 4)

VARIABLES
  Fn,         \* [slot -> BOOLEAN] TRUE if a task present in slot
  Busy,       \* [slot -> BOOLEAN] TRUE if claimed by a worker
  Submitted,  \* [slot -> BOOLEAN] TRUE if task submitted but not finished
  finished,   \* global flag to stop workers (set by buggy Finish)
  tasksLeft,  \* number of tasks yet to submit
  Cur         \* [worker -> slot] slot currently executed (0 = idle)

vars == << Fn, Busy, Submitted, finished, tasksLeft, Cur >>

Slots   == 1..QueueSize
Workers == 1..ThreadCount

Completed(s) == ~Fn[s] /\ ~Busy[s] /\ ~Submitted[s]

(***************************************************************************)
(* INITIAL STATE *)
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

\* BUGGY Finish: checks only Busy (this matches the C bug)
\* If no slot is busy, set finished = TRUE (even if Submitted or Fn set)
FinishBuggy ==
  /\ tasksLeft = 0
  /\ \A s \in Slots: ~Busy[s]      \* BUG: does NOT check Submitted or Fn
                                   \*      instead \A s \in Slots: Completed(s)
  /\ finished = FALSE
  /\ finished' = TRUE
  /\ UNCHANGED << Fn, Busy, Submitted, tasksLeft, Cur >>

\* A WORKER takes a submitted task and executes it (abstract)
WorkerStep ==
  \E w \in Workers:
    /\ Cur[w] = 0
    /\ \E s \in Slots:
         Fn[s] /\ ~Busy[s]
         /\ Fn'        = [Fn EXCEPT ![s] = FALSE]
         /\ Busy'      = [Busy EXCEPT ![s] = FALSE]  \* we don't model claim separately
         /\ Submitted' = [Submitted EXCEPT ![s] = FALSE]
         /\ Cur'       = [Cur EXCEPT ![w] = 0]
         /\ tasksLeft' = tasksLeft
         /\ finished'  = finished

\* Idle worker step: stuttering / do-nothing step
Idle ==
  \E w \in Workers:
    /\ Cur[w] = 0
    /\ UNCHANGED vars

Next ==
  \/ Submit
  \/ FinishBuggy
  \/ WorkerStep
  \/ Idle

\* Fair Spec: include weak fairness for Submit and WorkerStep to avoid trivial stutter
Spec == Init /\ [][Next]_vars /\ WF_vars(Submit) /\ WF_vars(WorkerStep)

(***************************************************************************)
(* INVARIANTS *)
TypeOK ==
  /\ Fn \in [Slots -> BOOLEAN]
  /\ Busy \in [Slots -> BOOLEAN]
  /\ Submitted \in [Slots -> BOOLEAN]
  /\ finished \in BOOLEAN
  /\ tasksLeft \in 0..TaskCount
  /\ Cur \in [Workers -> 0..QueueSize]

\* Mutual exclusion invariant: no two workers executing same slot
MutexInvariant ==
  \A s \in Slots:
    Cardinality({w \in Workers: Cur[w] = s}) <= 1

(***************************************************************************)
(* LIVENESS / PROPERTIES                                                   *)
(*                                                                         *)
(* We can actually replace this statement with TRUE to show that no erors  *)
(* was reported. But this buggy implementation creates starvation.         *)
(*                                                                         *)
(*                                                                         *)
(* The correct NoStarvation property we want to hold in a correct impl.    *)

NoStarvation ==
  \A s \in Slots: [] (Submitted[s] => <> Completed(s))

\* Finish reachable (in buggy model it may occur prematurely)
AllDone == <> finished

(***************************************************************************)
THEOREM Spec => []TypeOK
THEOREM Spec => []MutexInvariant

\* These should fail in the buggy model (TLC should produce counterexample):
THEOREM Spec => NoStarvation
THEOREM Spec => AllDone

=============================================================================
