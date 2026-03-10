--------------------------- MODULE BlockingQueue ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS Producers,   (* the (nonempty) set of producers                       *)
          Consumers,   (* the (nonempty) set of consumers                       *)
          BufCapacity  (* the maximum number of messages in the bounded buffer  *)

ASSUME Assumption ==
       /\ Producers # {}                      (* at least one producer *)
       /\ Consumers # {}                      (* at least one consumer *)
       /\ Producers \intersect Consumers = {} (* no thread is both consumer and producer *)
       /\ BufCapacity \in (Nat \ {0})         (* buffer capacity is at least 1 *)

-----------------------------------------------------------------------------

VARIABLES buffer, waitSet
vars == <<buffer, waitSet>>

(*********************************************************************************)
(* This variable is not used... Just marker what running thread is.              *)
(*********************************************************************************)
RunningThreads == (Producers \cup Consumers) \ waitSet

NotifyOther(Others) ==
    IF waitSet \cap Others # {}
    THEN \E t \in waitSet \cap Others : waitSet' = waitSet  \ {t}
    ELSE UNCHANGED waitSet

(*********************************************************************************)
(* @see java.lang.Object#wait                                                    *)
(*********************************************************************************)
Wait(t) == /\ waitSet' = waitSet \cup {t}
           /\ UNCHANGED <<buffer>>

-----------------------------------------------------------------------------

Put(t, d) ==
/\ t \notin waitSet
/\ \/ /\ Len(buffer) < BufCapacity
      /\ buffer' = Append(buffer, d) \* Put is possible only when there is a space.
      /\ NotifyOther(Consumers)
   \/ /\ Len(buffer) = BufCapacity   \* Otherwise we wait for a free slot.
      /\ Wait(t)

Get(t) ==
/\ t \notin waitSet
/\ \/ /\ buffer # <<>>
      /\ buffer' = Tail(buffer)      \* We can pop iff buffer is not empty.
      /\ NotifyOther(Producers)
   \/ /\ buffer = <<>>
      /\ Wait(t)

-----------------------------------------------------------------------------

(*********************************************************************************)
(* Initially, the buffer is empty and no thread is waiting.                      *)
(*********************************************************************************)
Init == /\ buffer = <<>>
        /\ waitSet = {}

(*********************************************************************************)
(* Then, pick a thread out of all running threads and have it do its thing.      *)
(* This enables arbitrary order of put/get operations.                           *)
(*********************************************************************************)
Next == \/ \E p \in Producers: Put(p, p) \* Add some data to buffer
        \/ \E c \in Consumers: Get(c)

-----------------------------------------------------------------------------

(*********************************************************************************)
(* TLA+ is untyped, thus lets verify the range of some values in each state.     *)
(*********************************************************************************)
TypeOK == /\ buffer \in Seq(Producers)
          /\ Len(buffer) \in 0..BufCapacity
          /\ waitSet \in SUBSET (Producers \cup Consumers)

(* No Deadlock *)
Invariant == waitSet # (Producers \cup Consumers)

-----------------------------------------------------------------------------

MySeq(P) == UNION {[1..n -> P] : n \in 0..BufCapacity}

INSTANCE TLAPS

Spec == Init /\ [][Next]_vars

(*********************************************************************************)
(* TypeOK will be a conjunct of the inductive invariant, so prove it inductive.  *)
(* An invariant I is inductive, iff Init => I and I /\ [Next]_vars => I. Note    *)
(* though, that TypeOK itself won't imply Invariant though!  TypeOK alone        *)
(* does not help us prove Invariant.                                             *)
(* Luckily, TLAPS does not require us to decompose the proof into substeps.      *)
(*********************************************************************************)

(*********************************************************************************)
(* If Spec holds, then always TypeOK holds. In other words, if the system        *)
(* follows Spec, TypeOK is correct for each reachable state.                     *)
(*********************************************************************************)
LEMMA TypeCorrect == Spec => []TypeOK
<1> USE Assumption DEF TypeOK
(*********************************************************************************)
(* From the initial predicate we can prove TypeOK. This tells that system starts *)
(* in a type-correct state.                                                      *)
(*********************************************************************************)
<1>1. Init => TypeOK BY SMT DEF Init
(*********************************************************************************)
(* Inductive step. We take next state, and system in the next state holds        *)
(* TypeOK'. *)
(*********************************************************************************)
<1>2. TypeOK /\ [Next]_vars => TypeOK' BY SMT DEF Next, Put, Get, Wait, NotifyOther, vars
<1>3. QED BY <1>1, <1>2, PTL DEF Spec

(*********************************************************************************)
(* The naive thing to do is to check if the conjunct of TypeOK /\ Invariant      *)
(*********************************************************************************)
IInv == /\ TypeOK!2
        /\ TypeOK!3
        /\ Invariant
        (*************************************************************************)
        (* When the buffer is empty, a consumer will be added to the waitSet.    *)
        (* However, this does not crate a deadlock, because at least one producer*)
        (* will not be in the waitSet.                                           *)
        (*************************************************************************)
        /\ buffer = <<>> => \E p \in Producers : p \notin waitSet
        (*************************************************************************)
        (* Vice versa, when buffer is full, a producer will be added to waitSet, *)
        (* but at least one consumer won't be in waitSet.                        *)
        (*************************************************************************)
        /\ Len(buffer) = BufCapacity => \E c \in Consumers : c \notin waitSet

(*********************************************************************************)
(* Notice that THEOREM and LEMMA are synomyms and treated the same way by TLA+.  *)
(*********************************************************************************)
LEMMA DeadlockFreedom == Spec => []Invariant
(*********************************************************************************)
(* We use previous TypeCorrect lemma and require it to be true.                  *)
(*********************************************************************************)
<1> USE Assumption, TypeCorrect DEF IInv, Invariant
<1>1. Init => IInv BY DEF Init
(*********************************************************************************)
(* Same inductive step as for LEMMA TypeCorrect.                                 *)
(*                                                                               *)
(* The induction should say that we always have a next state to go to.           *)
(* This assured by IInv: waitSet # (Producers \cup Consumers). This says that    *)
(* intersection of producers/consumers is not equal the wait set. This is the    *)
(* condition to push this thread pool further. If apparently waitSet equals      *)
(* Producers \cup Consumers, then no thread can pick up the work. This leads     *)
(* system to stutter. And exactly this is a deadlock.                            *)
(*                                                                               *)
(* Note also that all implicitly used predicates hidden inside the Next must     *)
(* be listed in BY DEF clause to pass them to the prover backend.                *)
(*********************************************************************************)
<1>2. TypeOK /\ IInv /\ [Next]_vars => IInv' BY DEF TypeOK, Next, Put, Get, Wait, NotifyOther, vars
<1>3. IInv => Invariant OBVIOUS
<1>4. QED BY <1>1,<1>2,<1>3, PTL DEF Spec

MCIInv == TypeOK!1 /\ IInv

-----------------------------------------------------------------------------

PutEnabled == \A p \in Producers : ENABLED Put(p, p)

(*********************************************************************************)
(* Weak Fairness of action A means: If A is continuously enabled (never becomes  *)
(* disabled) from some point onward, then A must eventually occur.               *)
(*                                                                               *)
(* Strong Fairness of action A means: If A is infinitely often enabled (maybe    *)
(* enabled, disabled, re-enabled, etc.) from some point onward, then A must      *)
(* eventually occur.                                                             *)
(*********************************************************************************)
FairSpec ==
    /\ Spec

    (********************************************************************************)
    (* Assert that producers take steps should their  Put  action be (continuously) *)
    (* enabled. This is the basic case of fairness that rules out stuttering, i.e., *)
    (* assert global progress.                                                      *)
    (********************************************************************************)
    /\ \A t \in Producers:
            WF_vars(Put(t,t))
    (********************************************************************************)
    (* Stipulates that  Get  actions (consumers!) will eventually notify *all*      *)
    (* waiting producers. In other words, given repeated  Get  actions (we don't    *)
    (* care which consumer, thus, existential quantification), all waiting          *)
    (* producers will eventually be notified.  Because  Get  actions are not        *)
    (* continuously enabled (the buffer might be empty), weak fairness is not       *)
    (* strong enough. Obviously, no real system scheduler implements such an        *)
    (* inefficient "policy".                                                        *)
    (* This fairness constraint was initially proposed by Leslie Lamport, although  *)
    (* with the minor typo "in" instead of "notin", which happens to hold for       *)
    (* configurations with at most two producers.                                   *)
    (********************************************************************************)
    /\ \A t \in Producers:
            SF_vars(\E self \in Consumers: Get(self) /\ t \notin waitSet')

    \* See notes above (except swap "producer" with "consumer").
    /\ \A t \in Consumers:
            WF_vars(Get(t)) 
    /\ \A t \in Consumers:
            SF_vars(\E self \in Producers: Put(self, self) /\ t \notin waitSet')

(************************************************************************************)
(* All producers will continuously be serviced. For this to be violated,            *)
(* ASSUME Cardinality(Producers) > 1 has to hold (a single producer cannot          *)
(* starve itself).                                                                  *)
(************************************************************************************)
Starvation ==
    /\ \A p \in Producers: []<>(<<Put(p, p)>>_vars)
    /\ \A c \in Consumers: []<>(<<Get(c)>>_vars)

=============================================================================
