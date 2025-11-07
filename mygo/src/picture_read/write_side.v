module write_side (
    input        clk_wr,     // 写时钟（与FIFO wr_clk一致）
    input        rst_n,      // 复位（低有效）
    input [7:0]  data_in,    // 输入8bit数据（来自以太网）
    input        valid_in,   // 输入数据有效（高有效）
    output [7:0] fifo_din,   // 输出到FIFO的8bit数据
    output       fifo_we     // 输出到FIFO的写使能
);
// 直接连接：FIFO会自动将连续4个8bit数据拼接为32bit
assign fifo_din = data_in;
// 仅当数据有效且FIFO未满时，允许写入（避免溢出）
assign fifo_we = valid_in;  // 若需更安全，可添加 !fifo_full 约束

endmodule