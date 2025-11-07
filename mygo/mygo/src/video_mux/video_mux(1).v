module video_mux (
    input wire [31:0] cam_video_data, // 摄像头实时数据
    input wire cam_video_de,
    input wire [31:0] photo_video_data, // 拍照数据
    input wire photo_video_de,
    input wire [31:0] sd_pic_video_data, // SD卡图片数据
    input wire sd_pic_video_de,
    input wire [1:0] sel, // 选择信号，来自主控模块
    output reg [23:0] vga_data_out, // 输出到VGA/HDMI驱动
    output reg vga_de_out
);

always @(*) begin
    case (sel)
        2'b00: begin // 待机状态，可显示黑屏或LOGO
            vga_data_out = 24'h000000; // 黑屏
            vga_de_out = 1'b0; 
        end
        2'b01: begin // 状态1：实时显示
            vga_data_out = cam_video_data;
            vga_de_out = cam_video_de;
        end
        2'b10: begin // 状态2：拍照显示
            vga_data_out = photo_video_data;
            vga_de_out = photo_video_de;
        end
        2'b11: begin // 状态3：SD卡图片显示
            vga_data_out = sd_pic_video_data;
            vga_de_out = sd_pic_video_de;
        end
        default: begin
            vga_data_out = 24'h000000;
            vga_de_out = 1'b0;
        end
    endcase
end

endmodule