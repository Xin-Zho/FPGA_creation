module read_side (
    input         clk_rd,       // 读时钟（与FIFO rd_clk一致）
    input         rst_n,        // 复位（低有效）
    input [31:0]  fifo_dout,    // FIFO输出的32bit数据
    input         fifo_empty,   // FIFO空信号（高有效）
    output reg    fifo_rd_en,   // 输出到FIFO的读使能
    output [31:0] data_out,     // 输出到SDRAM的32bit数据
    output        valid_out     // 输出数据有效（高有效）
);

// 读使能控制：当FIFO非空时，产生读请求（可根据下游需求调整）
always @(posedge clk_rd or negedge rst_n) begin
    if (!rst_n) begin
        fifo_rd_en <= 1'b0;
    end else begin
        // 简单逻辑：FIFO非空就读（若下游有握手，需添加应答信号）
        fifo_rd_en <= !fifo_empty;
    end
end

// 数据输出：直接连接FIFO的32bit输出
assign data_out = fifo_dout;
// 数据有效：读使能有效时，数据在下一拍有效（根据FIFO输出延迟调整）
// 若FIFO为"读使能后立即输出"，则valid_out = fifo_rd_en;
// 若FIFO为"读使能后延迟1拍输出"，则需打一拍：
reg valid_out_r;
always @(posedge clk_rd or negedge rst_n) begin
    if (!rst_n) begin
        valid_out_r <= 1'b0;
    end else begin
        valid_out_r <= fifo_rd_en;  // 延迟1拍有效
    end
end
assign valid_out = valid_out_r;

endmodule