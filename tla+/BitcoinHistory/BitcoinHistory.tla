---------------------------- MODULE BitcoinHistory ----------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS 
    XPub,     \* placeholder, not used in numeric spec
    GapLimit, \* maximum gap of empty addresses
    MaxBatches

VARIABLES
  addrIndex,      \* index of next address batch
  addresses,      \* current batch of addresses (as a set of numbers)
  balances,       \* map from address -> balance
  sumBalances,
  stored          \* set of stored addresses

\* Recursive sum over a finite set of numbers
RECURSIVE Sum(_)
Sum(S) ==
  IF S = {} THEN 0
  ELSE LET x == CHOOSE e \in S : TRUE IN x + Sum(S \ {x})

NextAddresses(xpub, idx) == { idx*20 + i : i \in 1..20 }

FetchBalances(addrs) == [a \in addrs
  |-> IF a \in DOMAIN balances
        THEN balances[a]
        ELSE 0
  ]

\* Initialize
Init ==
  /\ addrIndex = 0
  /\ addresses = {}
  /\ balances = [a \in {} |-> 0]
  /\ sumBalances = 0
  /\ stored = {}

\* Main loop
Next ==
  /\ addrIndex < MaxBatches
  /\ addrIndex' = addrIndex + 1
  /\ addresses' = NextAddresses(XPub, addrIndex)
  /\ balances' = FetchBalances(addresses')
  /\ sumBalances' = Sum({ balances'[a] : a \in DOMAIN balances' })
  /\ stored' = IF sumBalances' > 0 THEN stored \cup addresses' ELSE stored

\* Specification
Spec == Init /\ [][Next]_<<addrIndex, addresses, balances, sumBalances, stored>>

InvBalancesGreaterOrEqZero
  == sumBalances >= 0

InvSomeBalances
  == IF sumBalances > 0
       THEN \E a \in DOMAIN balances : balances[a] > 0
       ELSE TRUE

Invariant ==
  /\ InvBalancesGreaterOrEqZero
  /\ InvSomeBalances

=============================================================================
