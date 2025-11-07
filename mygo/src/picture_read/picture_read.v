module picture_read (
    // 写侧（以太网）：8bit输入，写时钟域
    input               clk_wr,       // 写时钟（如50MHz，连接FIFO clkw）
    input               rst_n,        // 全局复位（低有效）
    input [7:0]         data_in,      // 以太网输入8bit数据
    input               valid_in,     // 以太网数据有效（高有效）
    // 读侧（SDRAM）：32bit输出，读时钟域
    output [31:0]       data_out,     // 输出到SDRAM的32bit数据
    output              valid_out,    // 输出数据有效（高有效）
    // FIFO状态信号（可选输出）
    output              fifo_full,    // FIFO满标志
    output              fifo_empty,   // FIFO空标志
    output              overflow,     // 溢出警告
    output              underflow     // 下溢警告
);

// 中间信号
wire        fifo_we;       // FIFO写使能（连接we）
wire        fifo_re;       // FIFO读使能（连接re）
wire [31:0] fifo_dout;     // FIFO输出32bit数据
wire        fifo_valid;    // FIFO读数据有效（连接valid）
wire        wr_rst_done;   // 写侧复位完成（可忽略）
wire        rd_rst_done;   // 读侧复位完成（可忽略）

// 1. 写使能控制：仅当数据有效且FIFO未满时，允许写入
assign fifo_we = valid_in & !fifo_full & rst_n;

// 2. 读使能控制：当FIFO非空且读侧复位完成时，允许读取
//    （可根据下游SDRAM需求调整，此处简单处理为非空就读）
assign fifo_re = !fifo_empty & rd_rst_done & rst_n;

// 3. 实例化8→32 FIFO（Soft_FIFO_8_32）
Soft_FIFO_8_32 u_Soft_FIFO_8_32 (
    .di          (data_in),       // 8bit写数据（来自以太网）
    .clkr        (clk_wr),        // 读时钟（SDRAM侧时钟）
    .rrst        (!rst_n),        // 读侧复位（高有效，全局复位取反）
    .re          (fifo_re),       // 读使能
    .clkw        (clk_wr),        // 写时钟（以太网侧时钟）
    .wrst        (!rst_n),        // 写侧复位（高有效，全局复位取反）
    .we          (fifo_we),       // 写使能
    .dout        (fifo_dout),     // 32bit读数据
    .empty_flag  (fifo_empty),    // FIFO空标志
    .aempty      (),              // 几乎空（未使用）
    .full_flag   (fifo_full),     // FIFO满标志
    .afull       (),              // 几乎满（未使用）
    .valid       (fifo_valid),    // 读数据有效
    .overflow    (overflow),      // 溢出标志
    .underflow   (underflow),     // 下溢标志
    .wr_success  (),              // 写成功（未使用）
    .rdusedw     (),              // 读侧已用深度（未使用）
    .wrusedw     (),              // 写侧已用深度（未使用）
    .wr_rst_done (wr_rst_done),   // 写复位完成
    .rd_rst_done (rd_rst_done)    // 读复位完成
);

Soft_FIFO_cv u_Soft_FIFO_cv (
    .di          (fifo_dout),       // 8bit写数据（来自以太网）
    .clkr        (video_clk),        // 读时钟（SDRAM侧时钟）
    .rrst        (!rst_n),        // 读侧复位（高有效，全局复位取反）
    .re          (fifo_re),       // 读使能
    .clkw        (clk_wr),        // 写时钟（以太网侧时钟）
    .wrst        (!rst_n),        // 写侧复位（高有效，全局复位取反）
    .we          (fifo_we),       // 写使能
    .dout        (fifo_dout_1),     // 32bit读数据
    .empty_flag  (fifo_empty_1),    // FIFO空标志
    .aempty      (),              // 几乎空（未使用）
    .full_flag   (fifo_full_1),     // FIFO满标志
    .afull       (),              // 几乎满（未使用）
    .valid       (fifo_valid_1),    // 读数据有效
    .overflow    (overflow_1),      // 溢出标志
    .underflow   (underflow_1),     // 下溢标志
    .wr_success  (),              // 写成功（未使用）
    .rdusedw     (),              // 读侧已用深度（未使用）
    .wrusedw     (),              // 写侧已用深度（未使用）
    .wr_rst_done (wr_rst_done_1),   // 写复位完成
    .rd_rst_done (rd_rst_done_1)    // 读复位完成
);
// 4. 输出信号连接：FIFO的32bit数据和有效信号直接输出到SDRAM
assign data_out = fifo_dout_1;
assign valid_out = fifo_valid_1;

endmodule