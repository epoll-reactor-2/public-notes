----------------------------- MODULE SimpleLemma -----------------------------
EXTENDS Naturals, TLC

(***************************************************************************)
(* Lemma: Adding 0 does not change a natural number                        *)
(***************************************************************************)
LEMMA AddZeroRight ==
  ASSUME NEW n \in Nat
  PROVE n + 0 = n
PROOF
  OBVIOUS

------------------------------------------------------------------------------

(***************************************************************************)
(* Lemma: Addition is commutative                                          *)
(***************************************************************************)
LEMMA AddCommutative ==
  ASSUME NEW a \in Nat, NEW b \in Nat
  PROVE a + b = b + a
PROOF
  OBVIOUS

------------------------------------------------------------------------------

(***************************************************************************)
(* Lemma: Subset membership: if x ∈ A and A ⊆ B then x ∈ B                 *)
(***************************************************************************)
LEMMA SubsetImpliesMembership ==
  ASSUME NEW A, NEW B, NEW x,
         A \subseteq B,
         x \in A
  PROVE x \in B
PROOF
  OBVIOUS

------------------------------------------------------------------------------

(***************************************************************************)
(* Lemma: Transitive law                                                   *)
(***************************************************************************)
LEMMA Transitive ==
  ASSUME
    NEW X \in Nat,
    NEW Y \in Nat,
    NEW Z \in Nat,
    X > Y,
    Y > Z
  PROVE X > Z + 1
PROOF
  OBVIOUS

------------------------------------------------------------------------------

(***************************************************************************)
(* Lemma: Transitive law                                                   *)
(***************************************************************************)

SquareExists(Y) == \E k \in 1..Y : k * k = Y

(***************************************************************************)
(* Note that PROOF OBVIOUS is not enough there.                            *)
(* Backends (Zenon, Izabelle, SMT) failed to figure out how to prove it    *)
(* by standard mathematical laws.                                          *)
(*                                                                         *)
(* When PROVE statement marked with OBVIOUS, TLAPS will try each           *)
(* backend to prove this. If lemma is simple enough to be proved without   *)
(* additional facts about the statement, OBVIOUS succeeds.                 *)
(*                                                                         *)
(* Note that Z3 is the backend for SMT (satisfiability modulo theories)    *)
(* prover.                                                                 *)
(*                                                                         *)
(* Possible error:                                                         *)
(*                                                                         *)
(* [ERROR]: Could not prove or check:                                      *)
(*            ASSUME NEW CONSTANT X \in                                    *)
(*                   {4, 9}                                                *)
(*            PROVE  SquareExists(X)                                       *)
(***************************************************************************)
LEMMA SquareExistsRootProof ==
  ASSUME
    NEW X \in {4, 9, 16}  \* These numbers are squares so provable. Others not
  PROVE SquareExists(X)
PROOF
  <1>1. /\ SquareExists(4)
        /\ SquareExists(9)
        /\ SquareExists(16) BY DEF SquareExists
  <1>2. QED BY <1>1

=============================================================================
