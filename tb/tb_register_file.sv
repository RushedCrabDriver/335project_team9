`timescale 1ns/1ps
// I.D - register_file testbench
// R0 = 0, 2 async read ports, write/reset on posedge, no bypass
module tb_register_file;

  function automatic string h2(input logic [7:0] v); return $sformatf("%h", v); endfunction

  logic       clk = 1'b0;
  logic       reset = 1'b0, write_enable = 1'b0;
  logic [2:0] write_address = 3'd0, read_address1 = 3'd0, read_address2 = 3'd0;
  logic [7:0] write_data = 8'h00;
  logic [7:0] read_data1, read_data2;

  register_file dut (
    .clk(clk), .reset(reset), .write_enable(write_enable),
    .write_address(write_address), .write_data(write_data),
    .read_address1(read_address1), .read_address2(read_address2),
    .read_data1(read_data1), .read_data2(read_data2)
  );

  always #5 clk = ~clk;

  // scoreboard - своя копия регистров
  logic [7:0] model [0:7];
  int errors = 0, tests = 0, checks = 0;
  bit scenario_bad;

  task automatic model_edge(input logic rst, we, input logic [2:0] wa, input logic [7:0] wd);
    if (rst)                    for (int r = 0; r < 8; r++) model[r] = 8'h00;
    else if (we && wa != 3'd0)  model[wa] = wd;
    model[0] = 8'h00;
  endtask

  task automatic check_port(input int port, input logic [2:0] addr,
                            input logic [7:0] got, input string when);
    checks++;
    if (got !== model[addr]) begin
      scenario_bad = 1;
      $display("        FAIL  port%0d R%0d %-10s got %s, expected %s",
               port, addr, when, h2(got), h2(model[addr]));
    end
  endtask

  // reads are combinational, no clock needed
  task automatic read_pair(input logic [2:0] ra1, ra2, input string when);
    read_address1 = ra1; read_address2 = ra2;
    #1;
    check_port(1, ra1, read_data1, when);
    check_port(2, ra2, read_data2, when);
  endtask

  // port1 R0..R7, port2 R7..R0
  task automatic read_all(input string when);
    for (int r = 0; r < 8; r++) read_pair(r[2:0], 3'(7 - r), when);
  endtask

  task automatic begin_scenario();
    scenario_bad = 0;
  endtask

  task automatic end_scenario(input string name, input string detail);
    tests++;
    if (scenario_bad) begin
      errors++;
      $display("FAIL [%0d] %-40s %s", tests, name, detail);
    end else
      $display("PASS [%0d] %-40s %s", tests, name, detail);
  endtask

  task automatic write_cycle(input string name, input logic rst, we,
                             input logic [2:0] wa, input logic [7:0] wd);
    logic [7:0] old_val;
    begin_scenario();
    @(negedge clk);
    reset = rst; write_enable = we; write_address = wa; write_data = wd;
    old_val = model[wa];
    read_pair(wa, 3'(wa + 1), "pre-edge");    // до фронта должно быть старое значение
    @(posedge clk);
    model_edge(rst, we, wa, wd);
    #1;
    read_pair(wa, 3'(wa + 1), "post-edge");
    @(negedge clk);
    reset = 0; write_enable = 0;
    end_scenario(name, $sformatf("rst=%b we=%b R%0d<=%s : before %s, after %s",
                                 rst, we, wa, h2(wd), h2(old_val), h2(read_data1)));
  endtask

  // two writes on neighbouring edges, no idle cycle between them
  task automatic back_to_back(input logic [2:0] wa1, input logic [7:0] wd1,
                              input logic [2:0] wa2, input logic [7:0] wd2);
    begin_scenario();
    @(negedge clk);
    write_enable = 1; write_address = wa1; write_data = wd1;
    @(posedge clk); model_edge(0, 1, wa1, wd1);
    @(negedge clk);
    write_address = wa2; write_data = wd2;
    @(posedge clk); model_edge(0, 1, wa2, wd2);
    @(negedge clk);
    write_enable = 0;
    read_pair(wa1, wa2, "b2b");
    end_scenario($sformatf("back-to-back writes R%0d, R%0d", wa1, wa2),
                 $sformatf("on consecutive edges: R%0d=%s R%0d=%s",
                           wa1, h2(read_data1), wa2, h2(read_data2)));
  endtask

  task automatic idle_cycles(input int n);
    @(negedge clk);
    reset = 0; write_enable = 0;
    repeat (n) begin
      @(posedge clk);
      model_edge(0, 0, 3'd0, 8'h00);
    end
    @(negedge clk);
  endtask

  initial begin
    // reset
    write_cycle("reset clears R1..R7",                1, 0, 3'd1, 8'h00);
    begin_scenario(); read_all("after rst");
    end_scenario("all 8 registers read 00 after reset", "both ports, R0..R7");

    write_cycle("write FF to R0 is ignored",           0, 1, 3'd0, 8'hFF);

    // R1..R7
    write_cycle("write R1 = 11",                       0, 1, 3'd1, 8'h11);
    write_cycle("write R2 = 22",                       0, 1, 3'd2, 8'h22);
    write_cycle("write R3 = 33",                       0, 1, 3'd3, 8'h33);
    write_cycle("write R4 = 44",                       0, 1, 3'd4, 8'h44);
    write_cycle("write R5 = 55",                       0, 1, 3'd5, 8'h55);
    write_cycle("write R6 = 66",                       0, 1, 3'd6, 8'h66);
    write_cycle("write R7 = 77",                       0, 1, 3'd7, 8'h77);

    begin_scenario(); read_all("readback");
    end_scenario("read back R0..R7 on both ports", "R0=00, R1=11 ... R7=77");

    // two ports at once
    begin_scenario(); read_pair(3'd1, 3'd2, "dual read");
    end_scenario("dual read R1 & R2", $sformatf("port1=%s port2=%s", h2(read_data1), h2(read_data2)));
    begin_scenario(); read_pair(3'd7, 3'd3, "dual read");
    end_scenario("dual read R7 & R3", $sformatf("port1=%s port2=%s", h2(read_data1), h2(read_data2)));
    begin_scenario(); read_pair(3'd5, 3'd5, "same reg");
    end_scenario("both ports read the same R5", $sformatf("port1=%s port2=%s", h2(read_data1), h2(read_data2)));
    begin_scenario(); read_pair(3'd0, 3'd6, "R0 + R6");
    end_scenario("dual read R0 & R6 (R0 = 00)", $sformatf("port1=%s port2=%s", h2(read_data1), h2(read_data2)));

    // 4 reads x 1ns fit in half period, so no edge in between
    begin_scenario();
    @(negedge clk);
    read_pair(3'd1, 3'd7, "no clock");
    read_pair(3'd2, 3'd6, "no clock");
    read_pair(3'd3, 3'd5, "no clock");
    read_pair(3'd4, 3'd4, "no clock");
    end_scenario("address changes without a clock edge", "4 address pairs inside one half-period");

    write_cycle("write disabled (we=0) leaves R3",     0, 0, 3'd3, 8'hEE);

    idle_cycles(5);
    begin_scenario(); read_all("retention");
    end_scenario("state retained over 5 idle cycles", "all registers unchanged");

    // главная проверка на bypass: до фронта 33, после A5
    write_cycle("overwrite R3 = A5 (old 33 until edge)", 0, 1, 3'd3, 8'hA5);

    write_cycle("write R7 = 00",                       0, 1, 3'd7, 8'h00);

    back_to_back(3'd1, 8'hC1, 3'd2, 8'hC2);

    // reset vs write in the same cycle
    write_cycle("reset + write R2 = BB: reset wins",   1, 1, 3'd2, 8'hBB);
    begin_scenario(); read_all("after rst");
    end_scenario("all registers 00 after second reset", "both ports, R0..R7");

    write_cycle("write after reset R4 = 4F",           0, 1, 3'd4, 8'h4F);

    $display("--------------------------------------------");
    $display("scenarios: %0d, individual port checks: %0d", tests, checks);
    if (errors == 0) $display("REGFILE: ALL %0d TESTS PASSED", tests);
    else             $display("REGFILE: %0d of %0d TESTS FAILED", errors, tests);
    $finish;
  end
endmodule
