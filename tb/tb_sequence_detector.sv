`timescale 1ns/1ps

module tb_sequence_detector;

  logic clk = 1'b0, reset = 1'b1, bit_in = 1'b0;
  logic detected;

  sequence_detector dut (.clk(clk), .reset(reset), .bit_in(bit_in), .detected(detected));

  always #5 clk = ~clk;                 // 10 ns clock period

  int cycle = 0, errors = 0, checks = 0, csv;
  always @(posedge clk) cycle++;

  // sliding-window oracle

  logic [3:0] window;                   // last four sampled bits, newest in [0]
  string      history;                  // bits since the last reset, for the diagnostic


  task automatic check(input string sname, input int bit_idx,
                       input string bit_txt, input logic exp);
    checks++;
    $fdisplay(csv, "%0d,%s,%0d,%s,%0b,%0b", cycle, sname, bit_idx, bit_txt, exp, detected);
    if (detected !== exp) begin
      errors++;
      if (errors == 1) begin
        $display("******************** FIRST MISMATCH ********************");
        $display("  stream    : %s", sname);
        $display("  cycle     : %0d (time %0t)", cycle, $time);
        $display("  bit index : %0d (since last reset), bit_in = %s", bit_idx, bit_txt);
        $display("  history   : %s", history);
        $display("  expected  : detected = %0b", exp);
        $display("  observed  : detected = %0b", detected);
        if (exp) $display("  diagnosis : MISSED detection (history ends in 1011)");
        else     $display("  diagnosis : FALSE detection (history does not end in 1011)");
        $display("********************************************************");
      end else
        $display("  MISMATCH #%0d %s bit %0d cycle %0d: exp=%0b obs=%0b",
                 errors, sname, bit_idx, cycle, exp, detected);
    end
  endtask


  // bit_in and reset change on the falling edge; the DUT samples on the rising edge.

  task automatic apply_reset(input string sname);
    @(negedge clk); reset = 1'b1; bit_in = 1'b1;
    @(posedge clk); window = 4'b0000; history = "";
    #1 check(sname, 0, "RST", 1'b0);
  endtask

  task automatic apply_bit(input string sname, input logic b, input int bit_idx);
    @(negedge clk); reset = 1'b0; bit_in = b;
    @(posedge clk); window = {window[2:0], b}; history = {history, b ? "1" : "0"};
    #1 check(sname, bit_idx, b ? "1" : "0", window == 4'b1011);
  endtask

  // Every stream starts with its own reset, so streams are independent.

  task automatic run_stream(input string sname, input string stim);
    int bit_idx = 0;
    int err_before = errors;
    apply_reset(sname);
    for (int i = 0; i < stim.len(); i++) begin
      if (stim[i] == "R") begin
        apply_reset(sname);
        bit_idx = 0;
      end else if (stim[i] == "0" || stim[i] == "1") begin
        bit_idx++;
        apply_bit(sname, stim[i] == "1", bit_idx);
      end
    end
    $display("  %-16s %-46s %s", sname, stim, (errors == err_before) ? "PASS" : "FAIL");
  endtask

  // test plan

  initial begin
    csv = $fopen("part2_timing.csv", "w");
    $fdisplay(csv, "cycle,stream,bit_index,bit_in,expected_detected,observed_detected");
    $display("Part II.B - sequence_detector (1011, overlapping, Moore) testbench");

    run_stream("basic_1011",      "1011");      // one detection after bit 4
    run_stream("overlap_1011011", "1011011");   // detections after bits 4 and 7
    run_stream("all_zeros",       "00000000");  // no detections
    run_stream("all_ones",        "11111111");  // no detections
    run_stream("near_miss_1010",  "1010");      // no false positive
    run_stream("near_miss_1110",  "1110");      // no false positive
    run_stream("reset_mid_101",   "101R1011");  // reset discards "101"; only the new 1011 matches

    run_stream("long_mixed",      "11011_10011_0111011_01011_000_1011_0110_1110");

    $fclose(csv);
    $display("=== Summary: %0d checks, %0d error(s)", checks, errors);
    if (errors == 0) $display("TEST PASSED");
    else begin
      $display("TEST FAILED");
      $fatal(1, "sequence_detector testbench failed with %0d error(s)", errors);
    end
    $finish;
  end

endmodule
