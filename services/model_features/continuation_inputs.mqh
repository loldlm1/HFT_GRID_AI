#ifndef MODEL_CONTINUATION_INPUTS_MQH
#define MODEL_CONTINUATION_INPUTS_MQH

// Distinct evidence profile; intervals collect/synchronize, never train.
input group "+= Intake Continuation Export =+"
input bool Enable_Intake_Continuation = false;
input string Intake_Source_Id = "";
input string Intake_Session_Id = "";
input string Intake_Source_Proof = "";
input string Intake_Configuration_Proof = "";
// TESTER: immutable original source/history anchor, not a dated job receipt.
input string Intake_History_Proof = "";
input int Intake_Segment_Seconds = 3600;
input string Intake_Replay_Witness_Id = "";
input string Intake_Replay_Witness_Proof = "";

#endif
