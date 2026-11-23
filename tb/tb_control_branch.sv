`timescale 1ns/1ps
// I.B - control_unit + branch_unit testbench
module tb_control_branch;

  // print helpers (same %h issue as in tb_alu8)
  function automatic string h2(input logic [7:0] v); return $sformatf("%h", v); endfunction
  function automatic string bn(input logic [7:0] v, input int w);
    string s = "";
    for (int i = w - 1; i >= 0; i--)
      s = {s, (v[i] === 1'b1) ? "1" : (v[i] === 1'b0) ? "0" : "x"};
    return s;
  endfunction

  // control_unit
  logic [3:0] opcode;
  logic       reg_write, alu_src, mem_read, mem_write, branch_o, jump_o, illegal;
  logic [1:0] result_src, alu_op;

  control_unit u_ctrl (
    .opcode(opcode), .reg_write(reg_write), .alu_src(alu_src),
    .mem_read(mem_read), .mem_write(mem_write), .result_src(result_src),
    .branch(branch_o), .jump(jump_o), .alu_op(alu_op), .illegal(illegal)
  );

  // branch_unit
  logic [7:0] a, b, branch_target, jump_target, redirect_target;
  logic       branch, jump, take_branch, redirect;
  logic [2:0] branch_control;

  branch_unit u_br (
    .a(a), .b(b), .branch(branch), .jump(jump),
    .branch_control(branch_control), .branch_target(branch_target),
    .jump_target(jump_target), .take_branch(take_branch),
    .redirect(redirect), .redirect_target(redirect_target)
  );

  int errors = 0;
  int tests  = 0;

  // expected outputs, copied from the HW2 table (не из RTL!)
  // {RW, AS, MR, MW, RS[1:0], B, J, AO[1:0], I}
  function automatic logic [10:0] ctrl_model(input logic [3:0] op);
    case (op)
      //                 RW    AS    MR    MW    RS     B     J     AO     I
      4'b0000: return {1'b1, 1'b0, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 2'b10, 1'b0}; // ALU-R
      4'b0001: return {1'b1, 1'b1, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 2'b10, 1'b0}; // ALU-I
      4'b0010: return {1'b1, 1'b1, 1'b1, 1'b0, 2'b01, 1'b0, 1'b0, 2'b00, 1'b0}; // LOAD
      4'b0011: return {1'b0, 1'b1, 1'b0, 1'b1, 2'b00, 1'b0, 1'b0, 2'b00, 1'b0}; // STORE
      4'b0100: return {1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b1, 1'b0, 2'b01, 1'b0}; // BRANCH
      4'b0101: return {1'b1, 1'b0, 1'b0, 1'b0, 2'b10, 1'b0, 1'b1, 2'b00, 1'b0}; // JAL
      default: return {1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 1'b0, 1'b0, 2'b00, 1'b1}; // 0110-1111
    endcase
  endfunction

  function automatic string op_name(input logic [3:0] op);
    case (op)
      4'b0000: return "ALU-R";
      4'b0001: return "ALU-I";
      4'b0010: return "LOAD";
      4'b0011: return "STORE";
      4'b0100: return "BRANCH";
      4'b0101: return "JAL";
      default: return "illegal";
    endcase
  endfunction

  function automatic string ctrl_str(input logic [10:0] v);
    return $sformatf("%s  %s  %s  %s  %s %s %s %s %s",
                     bn(v[10], 1), bn(v[9], 1), bn(v[8], 1), bn(v[7], 1),
                     bn(v[6:5], 2), bn(v[4], 1), bn(v[3], 1), bn(v[2:1], 2), bn(v[0], 1));
  endfunction

  task automatic check_opcode(input logic [3:0] op);
    logic [10:0] got, exp;
    logic        both_mem;
    opcode = op;
    #1;
    exp = ctrl_model(op);
    got = {reg_write, alu_src, mem_read, mem_write, result_src,
           branch_o, jump_o, alu_op, illegal};
    both_mem = (mem_read === 1'b1) && (mem_write === 1'b1);
    tests++;
    // all outputs vs table + mem_read/mem_write never both 1
    if (got !== exp || both_mem) begin
      errors++;
      $display("FAIL [%0d] opcode=%s (%-7s) got  RW AS MR MW RS B J AO I = %s",
               tests, bn(op, 4), op_name(op), ctrl_str(got));
      $display("                                exp  RW AS MR MW RS B J AO I = %s", ctrl_str(exp));
      if (both_mem) $display("     invariant violated: mem_read=1 and mem_write=1");
    end else
      $display("PASS [%0d] opcode=%s (%-7s) RW AS MR MW RS B J AO I = %s   (MR&MW=0 ok)",
               tests, bn(op, 4), op_name(op), ctrl_str(got));
  endtask

  localparam logic [2:0] BEQ = 3'b000, BNE = 3'b001, BLT = 3'b010,
                         BGE = 3'b011, BLTU = 3'b100, BGEU = 3'b101;

  // branch reference. в RTL < и $signed нельзя, а тут можно - поэтому независимо
  task automatic br_model(input  logic [7:0] ta, tb, input logic tbranch, tjump,
                          input  logic [2:0] ctl, input logic [7:0] btgt, jtgt,
                          output logic e_take, e_redir, output logic [7:0] e_tgt);
    logic cond;
    case (ctl)
      BEQ:     cond = (ta == tb);
      BNE:     cond = (ta != tb);
      BLT:     cond = ($signed(ta) <  $signed(tb));
      BGE:     cond = ($signed(ta) >= $signed(tb));
      BLTU:    cond = (ta <  tb);
      BGEU:    cond = (ta >= tb);
      default: cond = 1'b0;                          // 110/111
    endcase
    e_take  = tbranch & cond;
    e_redir = tjump | e_take;
    if (tjump)       e_tgt = jtgt;                   // jump wins
    else if (e_take) e_tgt = btgt;
    else             e_tgt = 8'h00;
  endtask

  // different targets so it's obvious in the log which one got picked
  localparam logic [7:0] BT = 8'h20, JT = 8'h60;

  task automatic run_br(input string name, input logic [2:0] ctl,
                        input logic [7:0] ta, tb, input logic tbranch, tjump,
                        input bit quiet);
    logic e_take, e_redir; logic [7:0] e_tgt;
    a = ta; b = tb; branch = tbranch; jump = tjump; branch_control = ctl;
    branch_target = BT; jump_target = JT;
    #1;
    br_model(ta, tb, tbranch, tjump, ctl, BT, JT, e_take, e_redir, e_tgt);
    tests++;
    if (take_branch !== e_take || redirect !== e_redir || redirect_target !== e_tgt) begin
      errors++;
      $display("FAIL [%0d] %-26s ctl=%s a=%s b=%s br=%b j=%b | got  take=%b redir=%b tgt=%s",
               tests, name, bn(ctl, 3), h2(ta), h2(tb), tbranch, tjump,
               take_branch, redirect, h2(redirect_target));
      $display("     %-58s | exp  take=%b redir=%b tgt=%s", "", e_take, e_redir, h2(e_tgt));
    end else if (!quiet)
      $display("PASS [%0d] %-26s ctl=%s a=%s b=%s br=%b j=%b -> take=%b redir=%b tgt=%s",
               tests, name, bn(ctl, 3), h2(ta), h2(tb), tbranch, tjump,
               take_branch, redirect, h2(redirect_target));
  endtask

  initial begin
    logic [7:0] vals [6];
    int directed_start, sweep_start, sweep_err_start;

    $display("=== control_unit: all 16 opcodes ===");
    for (int op = 0; op < 16; op++) check_opcode(op[3:0]);

    $display("=== branch_unit: directed scenarios (branch_target=%s, jump_target=%s) ===",
             h2(BT), h2(JT));
    directed_start = tests;
    // beq / bne
    run_br("BEQ equal -> taken",         BEQ,    8'h05, 8'h05, 1, 0, 0);
    run_br("BEQ not equal",              BEQ,    8'h05, 8'h06, 1, 0, 0);
    run_br("BNE not equal -> taken",     BNE,    8'h05, 8'h06, 1, 0, 0);
    run_br("BNE equal",                  BNE,    8'h42, 8'h42, 1, 0, 0);
    // signed
    run_br("BLT -128 < 1 -> taken",      BLT,    8'h80, 8'h01, 1, 0, 0);
    run_br("BLT 1 < -128 ? no",          BLT,    8'h01, 8'h80, 1, 0, 0);
    run_br("BLT equal",                  BLT,    8'h7F, 8'h7F, 1, 0, 0);
    run_br("BLT -2 < -1 -> taken",       BLT,    8'hFE, 8'hFF, 1, 0, 0);
    run_br("BGE equal -> taken",         BGE,    8'h7F, 8'h7F, 1, 0, 0);
    run_br("BGE 127 >= -128 -> taken",   BGE,    8'h7F, 8'h80, 1, 0, 0);
    run_br("BGE -128 >= 127 ? no",       BGE,    8'h80, 8'h7F, 1, 0, 0);
    // unsigned - те же числа что у BLT, ответ обратный
    run_br("BLTU 1 < 128 -> taken",      BLTU,   8'h01, 8'h80, 1, 0, 0);
    run_br("BLTU 128 < 1 ? no",          BLTU,   8'h80, 8'h01, 1, 0, 0);
    run_br("BLTU 0 < 255 -> taken",      BLTU,   8'h00, 8'hFF, 1, 0, 0);
    run_br("BGEU 128 >= 1 -> taken",     BGEU,   8'h80, 8'h01, 1, 0, 0);
    run_br("BGEU equal -> taken",        BGEU,   8'h00, 8'h00, 1, 0, 0);
    run_br("BGEU 1 >= 255 ? no",         BGEU,   8'h01, 8'hFF, 1, 0, 0);
    // invalid ctl / disabled / jumps
    run_br("invalid ctl 110",            3'b110, 8'h05, 8'h05, 1, 0, 0);
    run_br("invalid ctl 111",            3'b111, 8'h05, 8'h05, 1, 0, 0);
    run_br("branch disabled (BEQ true)", BEQ,    8'h05, 8'h05, 0, 0, 0);
    run_br("jump only",                  BEQ,    8'h05, 8'h06, 0, 1, 0);
    run_br("jump + branch taken",        BEQ,    8'h05, 8'h05, 1, 1, 0);
    run_br("jump + branch not taken",    BNE,    8'h05, 8'h05, 1, 1, 0);
    run_br("jump + invalid ctl",         3'b111, 8'h00, 8'h00, 1, 1, 0);
    run_br("nothing requested",          BNE,    8'h01, 8'h02, 0, 0, 0);

    // sweep: all 8 ctl codes x boundary values, prints only fails
    vals[0] = 8'h00; vals[1] = 8'h01; vals[2] = 8'h7F;
    vals[3] = 8'h80; vals[4] = 8'h81; vals[5] = 8'hFF;
    sweep_start = tests; sweep_err_start = errors;
    for (int c = 0; c < 8; c++)
      for (int i = 0; i < 6; i++)
        for (int j = 0; j < 6; j++)
          run_br("sweep", c[2:0], vals[i], vals[j], 1, 0, 1);
    $display("=== boundary sweep (8 controls x 6 x 6 values): %0d checks, %0d failures ===",
             tests - sweep_start, errors - sweep_err_start);

    $display("--------------------------------------------");
    $display("checks: 16 opcodes + %0d directed branch scenarios + %0d sweep",
             sweep_start - directed_start, tests - sweep_start);
    if (errors == 0) $display("CONTROL/BRANCH: ALL %0d TESTS PASSED", tests);
    else             $display("CONTROL/BRANCH: %0d of %0d TESTS FAILED", errors, tests);
    $finish;
  end
endmodule
