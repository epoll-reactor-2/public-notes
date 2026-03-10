---- MODULE Handshake ----
EXTENDS Naturals, Sequences, TLC

CONSTANTS
  MaxSyns \* maximum number of SYN retransmits the client may do

\* ---------------------------------------------------------------------
\* Messages are simple records with a `type` field: "SYN", "SYNACK", "ACK"
\* channel is a FIFO (sequence) shared between client and server.
\* clientState / serverState are small string-valued states.
\* synsSent counts how many SYN the client sent (bounded by MaxSyns).
\* ---------------------------------------------------------------------

VARIABLES
  channel,      \* FIFO sequence of messages
  clientState,  \* "Init", "SynSent", "Established"
  serverState,  \* "Init", "SynRcvd", "Established"
  synsSent

\* convenience
IsHead(seq, t) == seq /= << >> /\ Head(seq).type = t

\* Initial state
Init ==
  /\ channel = << >>
  /\ clientState = "Init"
  /\ serverState = "Init"
  /\ synsSent = 0

\* ---------------------------------------------------------------------
\* Actions
\* ---------------------------------------------------------------------

\* Client sends SYN (from Init) — may retry up to MaxSyns
ClientSendSYN ==
  /\ clientState = "Init"
  /\ synsSent < MaxSyns
  /\ channel' = Append(channel, [type |-> "SYN"])
  /\ clientState' = "SynSent"
  /\ synsSent' = synsSent + 1
  /\ UNCHANGED serverState

\* Server receives SYN and replies SYNACK
ServerRecvSYN ==
  /\ serverState = "Init"
  /\ IsHead(channel, "SYN")
  /\ LET ch == Tail(channel) IN
       channel' = Append(ch, [type |-> "SYNACK"])
  /\ serverState' = "SynRcvd"
  /\ UNCHANGED << clientState, synsSent >>

\* Client receives SYNACK and transitions to Established
ClientRecvSYNACK ==
  /\ clientState = "SynSent"
  /\ IsHead(channel, "SYNACK")
  /\ channel' = Tail(channel)
  /\ clientState' = "Established"
  /\ UNCHANGED << serverState, synsSent >>

\* Client (once Established) may send ACK to server
ClientSendACK ==
  /\ clientState = "Established"
  /\ serverState = "SynRcvd"
  /\ channel' = Append(channel, [type |-> "ACK"])
  /\ UNCHANGED << clientState, serverState, synsSent >>

\* Server consumes ACK and becomes Established
ServerRecvACK ==
  /\ serverState = "SynRcvd"
  /\ IsHead(channel, "ACK")
  /\ channel' = Tail(channel)
  /\ serverState' = "Established"
  /\ UNCHANGED << clientState, synsSent >>

\* Allow stuttering (do-nothing) steps so TLC can schedule fairly
Stutter == UNCHANGED << channel, clientState, serverState, synsSent >>

Next ==
  \/ ClientSendSYN
  \/ ServerRecvSYN
  \/ ClientRecvSYNACK
  \/ ClientSendACK
  \/ ServerRecvACK
  \/ Stutter

Spec == Init /\ [][Next]_<<channel, clientState, serverState, synsSent>>

\* ---------------------------------------------------------------------
\* Safety invariant: no ACK appears in the channel before a SYNACK that precedes it.
\* (Equivalent: an ACK must be preceded by a SYNACK in the FIFO)
\* This is checked by examining indices 1..Len(channel) — TLC can enumerate that.
\* ---------------------------------------------------------------------
Inv_ACK_after_SYNACK ==
  \A i \in 1..Len(channel) :
     channel[i].type = "ACK" => clientState = "Established"

\* Liveness property: eventually both sides reach Established (3-way handshake completes)
EventuallyEstablished == <> (clientState = "Established" /\ serverState = "Established")

\* Optional convenience invariants
Inv_states_are_valid ==
  clientState \in {"Init","SynSent","Established"} /\ serverState \in {"Init","SynRcvd","Established"}

\* =====================================================================
\* End of module
\* =====================================================================
====  
