`timescale 1ns/1ps
// I.C - program_counter testbench
// priority on posedge: reset > redirect > stall > +4 (mod 256), sync reset
module tb_program_counter;

  function automatic string h2(input logic [7:0] v); return $sformatf("%h", v); endfunction

  logic       clk = 1'b0;
  logic       reset = 1'b0, stall = 1'b0, redirect = 1'b0;
  logic [7:0] redirect_target = 8'h00;
  logic [7:0] pc;

  program_counter dut (
    .clk(clk), .reset(reset), .stall(stall), .redirect(redirect),
    .redirect_target(redirect_target), .pc(pc)
  );

  always #5 clk = ~clk;          // 10 ns period

  // scoreboard
  logic [7:0] exp_pc;
  bit         exp_known = 0;     // pc is X until first reset
  int         errors = 0, tests = 0, cycle = 0;

  function automatic logic [7:0] pc_model(input logic [7:0] cur,
                                          input logic rst, red, stl,
                                          input logic [7:0] tgt);
    if (rst)      return 8'h00;
    else if (red) return tgt;
    else if (stl) return cur;
    else          return (cur + 8'd4) % 256;   // FC -> 00
  endfunction

  // one call = one clock = one row in the trace
  task automatic cycle_step(input string name, input logic rst, red, stl,
                            input logic [7:0] tgt);
    bit early;
    // inputs change on negedge, so no race with posedge
    @(negedge clk);
    reset = rst; redirect = red; stall = stl; redirect_target = tgt;

    // между фронтами pc не должен меняться (иначе reset не синхронный)
    #1;
    early = exp_known && (pc !== exp_pc);
    if (early)
      $display("      !! PC changed BETWEEN edges: got %s, still expected %s",
               h2(pc), h2(exp_pc));

    @(posedge clk);
    cycle++;
    exp_pc    = pc_model(exp_pc, rst, red, stl, tgt);
    exp_known = 1;
    #1;
    tests++;
    if (pc !== exp_pc || early) begin
      errors++;
      $display("%4d    %b    %b    %b    %s  |  %s   %s  | FAIL  %s",
               cycle, rst, red, stl, h2(tgt), h2(exp_pc), h2(pc), name);
      exp_pc = pc;             // resync, otherwise every next row fails too
    end else
      $display("%4d    %b    %b    %b    %s  |  %s   %s  | PASS  %s",
               cycle, rst, red, stl, h2(tgt), h2(exp_pc), h2(pc), name);
  endtask

  // reset goes 1 and back to 0 between two edges -> should be ignored
  task automatic reset_pulse_between_edges();
    logic [7:0] pc_before;
    @(negedge clk);
    reset = 0; redirect = 0; stall = 0;
    pc_before = pc;
    #1 reset = 1;
    #1;
    tests++;
    if (pc !== pc_before) begin
      errors++;
      $display("        reset pulse between edges: PC changed to %s immediately | FAIL", h2(pc));
    end else
      $display("        reset=1 between edges: PC still %s (no immediate change)  | PASS", h2(pc));
    #1 reset = 0;
    @(posedge clk);
    cycle++;
    exp_pc = pc_model(exp_pc, 0, 0, 0, 8'h00);
    #1;
    tests++;
    if (pc !== exp_pc) begin
      errors++;
      $display("%4d    0    0    0    00  |  %s   %s  | FAIL  reset pulse ignored by the edge",
               cycle, h2(exp_pc), h2(pc));
      exp_pc = pc;
    end else
      $display("%4d    0    0    0    00  |  %s   %s  | PASS  reset pulse ignored by the edge",
               cycle, h2(exp_pc), h2(pc));
  endtask

  initial begin
    $display("cycle  rst  red  stl  tgt  |  exp  got  | result / scenario");
    $display("---------------------------------------------------------------------------");
    //          name                                      rst red stl target
    cycle_step("reset -> 00",                              1,  0,  0,  8'h00);
    cycle_step("normal +4",                                0,  0,  0,  8'h00);
    cycle_step("normal +4",                                0,  0,  0,  8'h00);
    cycle_step("normal +4",                                0,  0,  0,  8'h00);
    cycle_step("stall holds",                              0,  0,  1,  8'h00);
    cycle_step("stall holds (2nd cycle)",                  0,  0,  1,  8'h00);
    cycle_step("redirect -> 40",                           0,  1,  0,  8'h40);
    cycle_step("redirect + stall: redirect wins",          0,  1,  1,  8'h80);  // мутант B ловится тут
    cycle_step("normal after redirect",                    0,  0,  0,  8'h00);
    reset_pulse_between_edges();    // pc = 84 here, so async reset would show up
    cycle_step("reset + redirect + stall: reset wins",     1,  1,  1,  8'h55);
    cycle_step("normal after reset",                       0,  0,  0,  8'h00);
    cycle_step("reset + stall: reset wins",                1,  0,  1,  8'h00);
    cycle_step("normal",                                   0,  0,  0,  8'h00);
    cycle_step("reset + redirect: reset wins",             1,  1,  0,  8'h77);
    cycle_step("redirect -> F8",                           0,  1,  0,  8'hF8);
    cycle_step("normal F8 -> FC",                          0,  0,  0,  8'h00);
    cycle_step("wraparound FC -> 00",                      0,  0,  0,  8'h00);
    cycle_step("normal after wrap",                        0,  0,  0,  8'h00);
    cycle_step("redirect + stall -> FC",                   0,  1,  1,  8'hFC);
    cycle_step("stall at FC",                              0,  0,  1,  8'h00);
    cycle_step("wrap after stall FC -> 00",                0,  0,  0,  8'h00);
    cycle_step("redirect to same target twice",            0,  1,  0,  8'h10);
    cycle_step("redirect to same target twice",            0,  1,  0,  8'h10);

    $display("---------------------------------------------------------------------------");
    if (errors == 0) $display("PC: ALL %0d TESTS PASSED (%0d clock cycles)", tests, cycle);
    else             $display("PC: %0d of %0d TESTS FAILED (%0d clock cycles)", errors, tests, cycle);
    $finish;
  end
endmodule
