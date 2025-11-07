// Verilog netlist created by Tang Dynasty v6.2.168116
// Mon Nov  3 18:26:47 2025

`timescale 1ns / 1ps
module FIFO_8_32  // FIFO_8_32.v(14)
  (
  clkr,
  clkw,
  di,
  re,
  rst,
  we,
  do,
  empty_flag,
  full_flag
  );

  input clkr;  // FIFO_8_32.v(25)
  input clkw;  // FIFO_8_32.v(24)
  input [7:0] di;  // FIFO_8_32.v(23)
  input re;  // FIFO_8_32.v(25)
  input rst;  // FIFO_8_32.v(22)
  input we;  // FIFO_8_32.v(24)
  output [31:0] do;  // FIFO_8_32.v(27)
  output empty_flag;  // FIFO_8_32.v(28)
  output full_flag;  // FIFO_8_32.v(29)

  wire empty_flag_syn_2;  // FIFO_8_32.v(28)
  wire full_flag_syn_2;  // FIFO_8_32.v(29)

  EG_PHY_CONFIG #(
    .DONE_PERSISTN("ENABLE"),
    .INIT_PERSISTN("ENABLE"),
    .JTAG_PERSISTN("DISABLE"),
    .PROGRAMN_PERSISTN("DISABLE"))
    config_inst ();
  not empty_flag_syn_1 (empty_flag_syn_2, empty_flag);  // FIFO_8_32.v(28)
  EG_PHY_FIFO #(
    .AE(32'b00000000000000000000000001101100),
    .AEP1(32'b00000000000000000000000001111100),
    .AF(32'b00000000000000000001111111101000),
    .AFM1(32'b00000000000000000001111111100100),
    .ASYNC_RESET_RELEASE("SYNC"),
    .DATA_WIDTH_A("4"),
    .DATA_WIDTH_B("18"),
    .E(32'b00000000000000000000000000001100),
    .EP1(32'b00000000000000000000000000011100),
    .F(32'b00000000000000000010000000000000),
    .FM1(32'b00000000000000000001111111111100),
    .GSR("DISABLE"),
    .MODE("FIFO8K"),
    .REGMODE_A("NOREG"),
    .REGMODE_B("NOREG"),
    .RESETMODE("ASYNC"))
    fifo_inst_syn_1 (
    .clkr(clkr),
    .clkw(clkw),
    .csr({2'b11,empty_flag_syn_2}),
    .csw({2'b11,full_flag_syn_2}),
    .dia({open_n47,open_n48,open_n49,open_n50,open_n51,di[3:0]}),
    .orea(1'b0),
    .oreb(1'b0),
    .re(re),
    .rprst(rst),
    .rst(rst),
    .we(we),
    .doa({open_n63,do[19:16],do[27:24]}),
    .dob({open_n64,do[3:0],do[11:8]}),
    .empty_flag(empty_flag),
    .full_flag(full_flag));  // FIFO_8_32.v(41)
  EG_PHY_FIFO #(
    .AE(32'b00000000000000000000000001101100),
    .AEP1(32'b00000000000000000000000001111100),
    .AF(32'b00000000000000000001111111101000),
    .AFM1(32'b00000000000000000001111111100100),
    .ASYNC_RESET_RELEASE("SYNC"),
    .DATA_WIDTH_A("4"),
    .DATA_WIDTH_B("18"),
    .E(32'b00000000000000000000000000001100),
    .EP1(32'b00000000000000000000000000011100),
    .F(32'b00000000000000000010000000000000),
    .FM1(32'b00000000000000000001111111111100),
    .GSR("DISABLE"),
    .MODE("FIFO8K"),
    .REGMODE_A("NOREG"),
    .REGMODE_B("NOREG"),
    .RESETMODE("ASYNC"))
    fifo_inst_syn_2 (
    .clkr(clkr),
    .clkw(clkw),
    .csr({2'b11,empty_flag_syn_2}),
    .csw({2'b11,full_flag_syn_2}),
    .dia({open_n65,open_n66,open_n67,open_n68,open_n69,di[7:4]}),
    .orea(1'b0),
    .oreb(1'b0),
    .re(re),
    .rprst(rst),
    .rst(rst),
    .we(we),
    .doa({open_n81,do[23:20],do[31:28]}),
    .dob({open_n82,do[7:4],do[15:12]}));  // FIFO_8_32.v(41)
  not full_flag_syn_1 (full_flag_syn_2, full_flag);  // FIFO_8_32.v(29)

endmodule 

