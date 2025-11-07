module picture_send (
    input               clk,            // 模块工作时钟
    input               rst_n,          // 复位信号（低有效）
    input               eth_send_start,             // 使能
    input               eth_send_done,
    input               eth_tx_ready,
    
    // 输入：来自SDRAM的32位图片数据（拍照模块读取的数据）
    input               sdram_data_valid,  // SDRAM读出数据有效（来自frame_read_write的read_en）
    input [31:0]        sdram_data,        // SDRAM读出的32位数据（来自frame_read_write的read_data）
    
    // 输出：8位数据（发送到以太网模块）
    output reg          eth_data_valid,     // 8位数据有效信号
    output wire [7:0]    eth_data           // 拆分后的8位数据
);
reg             en;
reg             rd_en_dly;
wire            fifo_empty;
wire            rd_en;           // FIFO读使能

assign rd_en = en & ~fifo_empty & eth_tx_ready;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_en_dly <= 1'b0;
        eth_data_valid <= 1'b0;
    end else begin
        rd_en_dly <= rd_en;          // 延迟一拍，与FIFO输出数据同步
        eth_data_valid <= rd_en_dly; // 数据有效信号跟随读使能延迟
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        en <= 1'b0;
    end else begin
        en <= eth_send_start & ~eth_send_done;  // 寄存器输出，稳定使能信号
    end
end
// 例化FIFO（假设IP核名为fifo_32to8）
Soft_FIFO_32_8 u_Soft_FIFO_32_8 (
    .clkr        (clk),                  // 共用模块时钟
    .rrst        (~rst_n | ~en),         // 复位或非使能时清空FIFO
    .we      (en & sdram_data_valid),// 使能且SDRAM数据有效时写FIFO
    .di        (sdram_data),           // 32位输入数据（来自SDRAM）
    .afull       (),                     // FIFO满信号（可忽略或用于调试）
    .re      (en & ~fifo_empty),     // 使能且FIFO非空时读FIFO
    .dout       (eth_data),             // 8位输出数据（到以太网）
    .aempty      (fifo_empty)            // FIFO空信号
);


endmodule
