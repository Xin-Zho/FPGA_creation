module video_mux (
    input wire video_clk,        // 添加VGA像素时钟（与显示时序同步）
    input wire rst_n,            // 复位信号（低有效）
    input wire [31:0] cam_video_data,
    input wire cam_video_de,
    input wire [31:0] photo_video_data,
    input wire photo_video_de,
    input wire [31:0] sd_pic_video_data,
    input wire sd_pic_video_de,
    input wire [1:0] sel,        // 选择信号（需同步到video_clk域）
    output reg [23:0] vga_data_out,
    output reg vga_de_out
);

// 第一步：对输入的控制信号（de）做跨时钟域同步（假设输入来自不同时钟）
reg [1:0] cam_de_sync, photo_de_sync, sd_de_sync;
reg [1:0] sel_sync;  // 选择信号也需要同步到video_clk域

// 同步摄像头有效信号
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n)
        cam_de_sync <= 2'b00;
    else
        cam_de_sync <= {cam_de_sync[0], cam_video_de};
end
wire cam_de_vld = cam_de_sync[1];

// 同步拍照数据有效信号
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n)
        photo_de_sync <= 2'b00;
    else
        photo_de_sync <= {photo_de_sync[0], photo_video_de};
end
wire photo_de_vld = photo_de_sync[1];

// 同步SD卡数据有效信号
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n)
        sd_de_sync <= 2'b00;
    else
        sd_de_sync <= {sd_de_sync[0], sd_pic_video_de};
end
wire sd_de_vld = sd_de_sync[1];

// 同步选择信号（关键：避免异步切换导致的毛刺）
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n)
        sel_sync <= 2'b00;
    else
        sel_sync <= sel;  // 若sel来自其他时钟域，需改为两级同步：{sel_sync[0], sel}
end

// 第二步：用时序逻辑切换输出（在video_clk边沿采样，消除毛刺）
always @(posedge video_clk or negedge rst_n) begin
    if (!rst_n) begin
        vga_data_out <= 24'h000000;
        vga_de_out <= 1'b0;
    end else begin
        case(sel_sync)  // 使用同步后的选择信号
            2'b00: begin
                vga_data_out <= 24'h000000;
                vga_de_out <= 1'b0;
            end
            2'b01: begin  // 摄像头数据（注意31:0转24:0的截取是否正确）
                vga_data_out <= cam_video_data[23:0];  // 假设输入高24位有效
                vga_de_out <= cam_de_vld;
            end
            2'b10: begin  // 拍照数据
                vga_data_out <= photo_video_data[23:0];
                vga_de_out <= photo_de_vld;
            end
            2'b11: begin  // SD卡数据
                vga_data_out <= sd_pic_video_data[23:0];
                vga_de_out <= sd_de_vld;
            end
        endcase
    end
end

endmodule