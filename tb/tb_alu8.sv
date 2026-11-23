`timescale 1ns/1ps
// I.A - alu8 testbench (addsub8 is checked through alu8)
module tb_alu8;

  // alu_control encodings from HW2
  localparam logic [2:0] ADD = 3'b000, SUB = 3'b001, AND_ = 3'b010, OR_ = 3'b011,
                         XOR_ = 3'b100, SLT = 3'b101, SLL = 3'b110, SRL = 3'b111;

  logic [7:0] a, b, result;
  logic [2:0] alu_control;
  logic       zero, negative, carry, overflow;

  alu8 dut (.a(a), .b(b), .alu_control(alu_control), .result(result),
            .zero(zero), .negative(negative), .carry(carry), .overflow(overflow));

  int errors = 0;
  int tests  = 0;

  // print helpers - without them %h loses leading zeros after #1 (verilator 5.020 bug)
  function automatic string h2(input logic [7:0] v); return $sformatf("%h", v); endfunction
  function automatic string b3(input logic [2:0] v); return $sformatf("%b", v); endfunction

  // reference model, plain int math (no 9-bit adder like in RTL)
  task automatic model(input  logic [7:0] ta, tb, input logic [2:0] ctl,
                       output logic [7:0] r, output logic z, n, c, v);
    int ua, ub, sa, sb, s;
    int sh;
    ua = ta;            ub = tb;              // 0..255
    sa = $signed(ta);   sb = $signed(tb);     // -128..127
    sh = tb[2:0];
    c = 0; v = 0; r = 0;
    case (ctl)
      ADD: begin
        r = (ua + ub) % 256;
        c = (ua + ub) > 255;
        s = sa + sb;
        v = (s > 127) || (s < -128);          // overflow по диапазону, не по 9-му биту
      end
      SUB: begin
        r = (ua - ub + 256) % 256;
        c = (ua >= ub);                       // carry = no borrow
        s = sa - sb;
        v = (s > 127) || (s < -128);
      end
      AND_: r = ta & tb;
      OR_:  r = ta | tb;
      XOR_: r = ta ^ tb;
      SLT:  r = (sa < sb) ? 1 : 0;            // signed
      SLL:  r = (ua * (1 << sh)) % 256;
      SRL:  r = ua / (1 << sh);
    endcase
    z = (r == 0);
    n = r[7];
  endtask

  task automatic run(string name, logic [2:0] ctl, logic [7:0] ta, tb);
    logic [7:0] er; logic ez, en, ec, ev;
    a = ta; b = tb; alu_control = ctl;
    #1;
    model(ta, tb, ctl, er, ez, en, ec, ev);
    tests++;
    if (result !== er || zero !== ez || negative !== en || carry !== ec || overflow !== ev) begin
      errors++;
      $display("FAIL [%0d] %-28s a=%s b=%s ctl=%s | got  r=%s z=%b n=%b c=%b v=%b",
               tests, name, h2(ta), h2(tb), b3(ctl), h2(result), zero, negative, carry, overflow);
      $display("     %-51s | exp  r=%s z=%b n=%b c=%b v=%b",
               "", h2(er), ez, en, ec, ev);
    end else
      $display("PASS [%0d] %-28s a=%s b=%s -> r=%s z=%b n=%b c=%b v=%b",
               tests, name, h2(ta), h2(tb), h2(result), zero, negative, carry, overflow);
  endtask

  initial begin
    // add
    run("ADD basic",               ADD,  8'h05, 8'h03);
    run("ADD positive overflow",   ADD,  8'h7F, 8'h01);  // 127+1
    run("ADD carry + zero",        ADD,  8'hFF, 8'h01);
    run("ADD negative overflow",   ADD,  8'h80, 8'h80);  // -128 + -128
    // sub
    run("SUB negative overflow",   SUB,  8'h80, 8'h01);  // -128-1
    run("SUB with borrow",         SUB,  8'h03, 8'h05);
    run("SUB zero, no borrow",     SUB,  8'h42, 8'h42);
    run("SUB positive overflow",   SUB,  8'h7F, 8'hFF);  // 127-(-1)
    run("SUB basic, no borrow",    SUB,  8'h10, 8'h01);
    // logic ops, c/v must stay 0
    run("AND -> zero",             AND_, 8'hF0, 8'h0F);
    run("AND -> negative",         AND_, 8'hFF, 8'h81);
    run("OR -> zero",              OR_,  8'h00, 8'h00);
    run("OR -> negative",          OR_,  8'h80, 8'h01);
    run("XOR -> zero",             XOR_, 8'hAA, 8'hAA);
    run("XOR -> all ones",         XOR_, 8'hAA, 8'h55);
    // slt
    run("SLT neg < pos",           SLT,  8'h80, 8'h01);  // на этом падает мутант A
    run("SLT pos vs neg",          SLT,  8'h01, 8'h80);
    run("SLT equal",               SLT,  8'h01, 8'h01);
    run("SLT internal ovf, c=v=0", SLT,  8'h7F, 8'h80);  // a-b overflows inside
    run("SLT both negative",       SLT,  8'hFE, 8'hFF);
    // shifts, only b[2:0] counts
    run("SLL by 0",                SLL,  8'hA5, 8'h00);
    run("SLL by 1, MSB drops",     SLL,  8'h81, 8'h01);
    run("SLL by 7",                SLL,  8'h01, 8'h07);
    run("SRL by 1",                SRL,  8'h80, 8'h01);
    run("SRL by 7",                SRL,  8'h80, 8'h07);
    run("SRL b[7:3]!=0 (shift 1)", SRL,  8'hF0, 8'hF9);
    run("SLL b[7:3]!=0 (shift 0)", SLL,  8'h81, 8'h08);

    $display("--------------------------------------------");
    if (errors == 0) $display("ALU: ALL %0d TESTS PASSED", tests);
    else             $display("ALU: %0d of %0d TESTS FAILED", errors, tests);
    $finish;
  end
endmodule
