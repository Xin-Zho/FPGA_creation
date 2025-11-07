module snapshot_udp_direct(
    // 系统接口
    input               clk_50,
    input               sys_rst_n,
    
    // 拍照控制
    input               key_snapshot,
    output reg          snapshot_busy,
    output reg          snapshot_done,
    
    // 摄像头接口
    input               cam_pclk,
    input               cam_vsync,
    input               cam_href,
    input [7:0]         cam_data,
    
    // 以太网应用层接口（使用eth_*变量）
    input               eth_tx_ready,
    input               eth_tx_ack,
    output reg          eth_tx_data_request,
    output reg          eth_tx_data_valid,
    output reg [7:0]    eth_tx_data,
    output reg [15:0]   eth_tx_data_length
);

// ========================= 参数定义 =========================
parameter IMAGE_WIDTH  = 1024;
parameter IMAGE_HEIGHT = 768;
parameter HEADER_SIZE  = 16;
parameter PACKET_SIZE  = 1024;

// ========================= 状态机定义 =========================
reg [3:0] state;
localparam IDLE        = 4'b0000;
localparam WAIT_FRAME  = 4'b0001;
localparam CAPTURE     = 4'b0010;
localparam SEND_HEADER = 4'b0011;
localparam SEND_DATA   = 4'b0100;
localparam DONE        = 4'b0101;

// ========================= 内部信号 =========================
reg [15:0] pixel_counter;
reg [15:0] line_counter;
reg [31:0] total_bytes;
reg [15:0] packet_counter;
reg [10:0] byte_in_packet;

reg cam_vsync_dly, cam_href_dly;
wire vsync_negedge, href_posedge;

// 跨时钟域同步
reg key_sync0, key_sync1, key_sync2;
wire key_trigger;

// 图像数据缓存
reg [7:0] data_buffer;
reg data_valid;
reg byte_switch;

// 简化模式控制信号
reg direct_mode;
reg [23:0] frame_timeout;

// ========================= 时钟域同步 =========================
assign vsync_negedge = cam_vsync_dly & ~cam_vsync;
assign href_posedge = ~cam_href_dly & cam_href;
assign key_trigger = key_sync1 & ~key_sync2;

// 按键同步
always @(posedge clk_50 or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        key_sync0 <= 1'b0;
        key_sync1 <= 1'b0;
        key_sync2 <= 1'b0;
    end else begin
        key_sync0 <= key_snapshot;
        key_sync1 <= key_sync0;
        key_sync2 <= key_sync1;
    end
end

// ========================= 简化模式控制 =========================
always @(posedge clk_50 or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        direct_mode <= 1'b0;
        frame_timeout <= 24'd0;
    end else begin
        if (key_trigger) begin
            direct_mode <= 1'b1;
            frame_timeout <= 24'd0;
        end
        
        if (direct_mode) begin
            frame_timeout <= frame_timeout + 1'b1;
            
            if (frame_timeout > 24'd2500000) begin
                direct_mode <= 1'b0;
            end
        end
    end
end

// ========================= 摄像头数据采集 =========================
always @(posedge cam_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        cam_vsync_dly <= 1'b0;
        cam_href_dly <= 1'b0;
        data_buffer <= 8'd0;
        data_valid <= 1'b0;
        byte_switch <= 1'b0;
        pixel_counter <= 16'd0;
        line_counter <= 16'd0;
    end else begin
        cam_vsync_dly <= cam_vsync;
        cam_href_dly <= cam_href;
        
        if (direct_mode) begin
            if (cam_href && cam_vsync) begin
                if (!byte_switch) begin
                    data_buffer <= cam_data;
                    data_valid <= 1'b0;
                end else begin
                    data_valid <= 1'b1;
                end
                byte_switch <= ~byte_switch;
                
                if (byte_switch) begin
                    pixel_counter <= pixel_counter + 1'b1;
                end
            end else begin
                data_valid <= 1'b0;
                byte_switch <= 1'b0;
            end
            
            if (href_posedge) begin
                line_counter <= line_counter + 1'b1;
                pixel_counter <= 16'd0;
            end
            
            if (vsync_negedge) begin
                line_counter <= 16'd0;
                pixel_counter <= 16'd0;
            end
        end else begin
            data_valid <= 1'b0;
            byte_switch <= 1'b0;
            pixel_counter <= 16'd0;
            line_counter <= 16'd0;
        end
    end
end

// ========================= 主状态机 =========================
always @(posedge clk_50 or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        state <= IDLE;
        eth_tx_data_request <= 1'b0;
        eth_tx_data_valid <= 1'b0;
        eth_tx_data <= 8'd0;
        eth_tx_data_length <= 16'd0;
        snapshot_busy <= 1'b0;
        snapshot_done <= 1'b0;
        total_bytes <= 32'd0;
        packet_counter <= 16'd0;
        byte_in_packet <= 11'd0;
    end else begin
        eth_tx_data_valid <= 1'b0;
        snapshot_done <= 1'b0;
        
        case (state)
            IDLE: begin
                snapshot_busy <= 1'b0;
                eth_tx_data_request <= 1'b0;
                total_bytes <= 32'd0;
                packet_counter <= 16'd0;
                byte_in_packet <= 11'd0;
                
                if (direct_mode) begin
                    state <= CAPTURE;
                    snapshot_busy <= 1'b1;
                    eth_tx_data_request <= 1'b1;
                end
            end
            
            CAPTURE: begin
                snapshot_busy <= 1'b1;
                
                if (data_valid && eth_tx_ready) begin
                    eth_tx_data_valid <= 1'b1;
                    eth_tx_data <= data_buffer;
                    total_bytes <= total_bytes + 1'b1;
                    byte_in_packet <= byte_in_packet + 1'b1;
                    
                    if (byte_in_packet >= PACKET_SIZE-1) begin
                        packet_counter <= packet_counter + 1'b1;
                        byte_in_packet <= 11'd0;
                    end
                end
                
                if (!direct_mode || (line_counter >= IMAGE_HEIGHT && pixel_counter >= IMAGE_WIDTH)) begin
                    state <= DONE;
                    eth_tx_data_request <= 1'b0;
                end
            end
            
            DONE: begin
                snapshot_busy <= 1'b0;
                snapshot_done <= 1'b1;
                
                if (packet_counter > 16'd10) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
        
        if (byte_in_packet < PACKET_SIZE) begin
            eth_tx_data_length <= byte_in_packet + 1'b1;
        end else begin
            eth_tx_data_length <= PACKET_SIZE;
        end
    end
end

endmodule