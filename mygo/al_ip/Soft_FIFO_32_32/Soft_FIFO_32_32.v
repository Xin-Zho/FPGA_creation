/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Nov 04 2025 16:06:36
**	TD version	:	6.2.168116
************************************************************/
`timescale 1ns/1ps
module Soft_FIFO_32_32
(
  input   [31:0]                di,
  input                         clkr,
  input                         rrst,
  input                         re,
  input                         clkw,
  input                         wrst,
  input                         we,
  output  [31:0]                dout,
  output                        empty_flag,
  output                        aempty,
  output                        full_flag,
  output                        afull,
  output                        valid,
  output                        overflow,
  output                        underflow,
  output                        wr_success,
  output  [8:0]                 rdusedw,
  output  [8:0]                 wrusedw,
  output                        wr_rst_done,
  output                        rd_rst_done
);

  soft_fifo_fff555ab1f33
  #(
      .COMMON_CLK_EN(0),
      .MEMORY_TYPE(0),
      .RST_TYPE(1),
      .DATA_WIDTH_W(32),
      .ADDR_WIDTH_W(9),
      .DATA_WIDTH_R(32),
      .ADDR_WIDTH_R(9),
      .DOUT_INITVAL(32'h0),
      .OUTREG_EN("NOREG"),
      .SHOW_AHEAD_EN(0),
      .AL_FULL_NUM(3),
      .AL_EMPTY_NUM(2),
      .RDUSEDW_WIDTH(9),
      .WRUSEDW_WIDTH(9),
      .ASYNC_RST_SYNC_RELS(0),
      .SYNC_STAGE(2)
  )soft_fifo_fff555ab1f33_Inst
  (
      .di(di),
      .clkr(clkr),
      .rrst(rrst),
      .re(re),
      .clkw(clkw),
      .wrst(wrst),
      .we(we),
      .dout(dout),
      .empty_flag(empty_flag),
      .aempty(aempty),
      .full_flag(full_flag),
      .afull(afull),
      .valid(valid),
      .overflow(overflow),
      .underflow(underflow),
      .wr_success(wr_success),
      .rdusedw(rdusedw),
      .wrusedw(wrusedw),
      .wr_rst_done(wr_rst_done),
      .rd_rst_done(rd_rst_done)
  );
endmodule
