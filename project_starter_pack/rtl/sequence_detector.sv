`timescale 1ns/1ps
// Five-state Moore detector for the serial pattern 1011 (overlapping).
//   - One bit_in sample per rising edge of clk.
//   - Synchronous, active-high reset returns the FSM to S0.
//   - detected is a pure function of the current state (high only in S4).
//
//   State | Meaning (last useful prefix) | bit_in=0 | bit_in=1 | detected
//   ------+------------------------------+----------+----------+---------
//   S0    | none                         |   S0     |   S1     |   0
//   S1    | 1                            |   S2     |   S1     |   0
//   S2    | 10                           |   S0     |   S3     |   0
//   S3    | 101                          |   S2     |   S4     |   0
//   S4    | 1011 (match)                 |   S2     |   S1     |   1
module sequence_detector (
  input  logic clk, reset, bit_in,
  output logic detected
);
  // Binary encoding: 3 bits are enough for 5 states (3'b101..3'b111 unused).
  localparam logic [2:0] S0=3'b000, S1=3'b001, S2=3'b010,
                         S3=3'b011, S4=3'b100;
  logic [2:0] state, next_state;

  // State register: synchronous active-high reset.
  always_ff @(posedge clk) begin
    if (reset) state <= S0;
    else state <= next_state;
  end

  // Next-state logic.
  always_comb begin
    next_state = S0;                       // safe default
    case (state)
      S0: next_state = bit_in ? S1 : S0;
      S1: next_state = bit_in ? S1 : S2;   // "11" keeps prefix "1"
      S2: next_state = bit_in ? S3 : S0;   // "100" loses all progress
      S3: next_state = bit_in ? S4 : S2;   // "1010" falls back to "10"
      S4: next_state = bit_in ? S1 : S2;   // overlap: "1011"+0 -> "10", +1 -> "1"
      default: next_state = S0;            // unused encodings recover to S0
    endcase
  end

  // Moore output: depends only on the current state.
  assign detected = (state == S4);
endmodule
