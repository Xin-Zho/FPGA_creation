module top(
    input                       clk,
    input                       rst_n,
 
    output          vga_out_hs,
    output          vga_out_vs,
    output  [11:0]  vga_data,
    
    // HDMI接口                         
    output          HDMI_CLK_P,
    output          HDMI_D2_P,
    output          HDMI_D1_P,
    output          HDMI_D0_P,
    
    // 摄像头接口                       
    input                 cam_pclk,        // cmos数据像素时钟
    input                 cam_vsync,       // cmos场同步信号
    input                 cam_href,        // cmos行同步信号
    input   [7:0]         cam_data,        // cmos数据
    output                cam_rst_n,       // cmos复位信号，低电平有效
    output                cam_pwdn,        // 电源休眠模式选择
    output                cam_scl,         // cmos SCCB_SCL线
    inout                 cam_sda,         // cmos SCCB_SDA线 
    
    // 以太网PHY接口
    input                       phy1_rgmii_rx_clk,   // RGMII接收时钟
    input                       phy1_rgmii_rx_ctl,   // RGMII接收控制
    input  [3:0]                phy1_rgmii_rx_data,  // RGMII接收数据
    output                      phy1_rgmii_tx_clk,    // RGMII发送时钟
    output                      phy1_rgmii_tx_ctl,    // RGMII发送控制
    output [3:0]                phy1_rgmii_tx_data,   // RGMII发送数据 
    
    output [3:0]               led,
    
    // 拍照控制
    input               key_snapshot,
    input               key_0,
    input               key_1
  
);

// ========================= 信号定义 =========================
wire [3:0] led_cmd;
assign led = led_cmd; 



led_control led_cnl( 
    .sys_clk (clk)  ,                   //50mHz, system clock
    .rst_n   (rst_n)  ,                   //reset sign  ,1 then reset
    .cntl  (last? 4'b0011 : 4'b0000)   ,              //contrl sign ,decide use which kind of led
            
     .led    (led_cmd)        //led output
);  

// 以太网应用层信号
  wire          eth_tx_data_request;   // 以太网发送数据请求
  wire          eth_tx_data_valid;     // 以太网发送数据有效
  wire          eth_tx_data;           // 以太网发送数据
  wire [7:0]    eth_tx_data_length;    // 以太网发送数据长度
  wire [15:0]   eth_tx_ready;          // 以太网发送就绪
  wire          eth_tx_ack;            // 以太网发送应答

// 参数定义
parameter MEM_DATA_BITS = 32;            // 外部存储器用户接口数据宽度
parameter ADDR_BITS = 21;                // 外部存储器用户接口地址宽度
parameter BUSRT_BITS = 10;               // 外部存储器用户接口突发宽度

parameter V_CMOS_DISP = 11'd768;         // CMOS分辨率--行
parameter H_CMOS_DISP = 11'd1024;       // CMOS分辨率--列    
parameter TOTAL_H_PIXEL = H_CMOS_DISP + 12'd1216; // CMOS分辨率--行
parameter TOTAL_V_PIXEL = V_CMOS_DISP + 12'd504; // CMOS分辨率--列

// SDRAM控制信号
wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

// 视频显示信号
wire vga_out_de;
wire hs, vs, de;
wire [23:0] vout_data;

// 时钟信号
wire ext_mem_clk, ext_mem_clk_sft;
wire video_clk, hdmi_5x_clk;

// 帧读写控制信号
wire video_read_req, video_read_req_ack, video_read_en;
wire [31:0] video_read_data;
wire [31:0] screen_data;
wire [31:0] sdram_data_out;
wire cam_write_en, cam_write_req, cam_write_req_ack;
wire [31:0] cam_write_data;

// SDRAM接口信号
wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

// 摄像头数据信号
wire cmos_frame_vsync, cmos_frame_href, cmos_frame_valid;
wire [15:0] cmos_wr_data;

// 主控模块相关信号
wire [1:0] state;
wire [1:0] video_source_sel_to_read;
wire [1:0] video_source_sel_to_write;
wire sd_pic_display_en;
wire photo_trigger;
wire display_en;

// 拍照模块相关信号
wire photo_led;
wire photo_capture_req;
wire photo_capture_ack;
wire [23:0] capture_addr;
wire [ADDR_BITS-1:0] capture_len;
wire [23:0] current_frame_addr;
wire frame_valid_signal;
wire [31:0] eth_send_frame_addr;
wire [31:0] eth_send_image_size;
wire eth_send_busy;
wire eth_send_done;
wire photo_busy_status;
wire photo_done_signal;

// 简化版拍照模块信号
wire snapshot_busy;
wire snapshot_done;

// 命令接口信号
wire cmd_valid;
wire [7:0] cmd_data;

// 以太网相关信号
wire eth_cmd_valid;
wire [7:0] eth_cmd;
wire [15:0] eth_data_length;
wire [15:0] eth_port_num;
wire [2:0] eth_leds;

// 其他信号
wire sdram_wr_en;
wire sdram_wr_data;
wire sdram_wr_addr;

// 以太网发送完成信号
wire eth_send_done_to_pho;
wire eth_send_start;
wire eth_send_req;

// 拍照传输完成信号
wire photo_tx_done = photo_done_signal;
wire sd_pic_receive_done = 1'b0;

reg display_en_1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        display_en_1 <= 1'b1;  // 初始默认显示
    else
        display_en_1 <= key_0;  // 直接用拨钮电平控制（switch=1则显示，0则黑屏）
end

// ========================= 时钟生成 =========================
sys_pll sys_pll_m0(
    .refclk     (clk),
    .clk0_out   (ext_mem_clk),
    .clk1_out   (ext_mem_clk_sft),
    .reset      (1'b0)
);

video_pll video_pll_m0(
    .refclk     (clk),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),
    .reset      (1'b0)
);

// ========================= 摄像头驱动 =========================
ov5640_dri u_ov5640_dri(
    .clk               (clk),
    .rst_n             (rst_n),

    .cam_pclk          (cam_pclk),
    .cam_vsync         (cam_vsync),
    .cam_href          (cam_href),
    .cam_data          (cam_data),
    .cam_rst_n         (cam_rst_n),
    .cam_pwdn          (cam_pwdn),
    .cam_scl           (cam_scl),
    .cam_sda           (cam_sda),
    
    .capture_start     (Sdr_init_done),
    .cmos_h_pixel      (H_CMOS_DISP),
    .cmos_v_pixel      (V_CMOS_DISP),
    .total_h_pixel     (TOTAL_H_PIXEL),
    .total_v_pixel     (TOTAL_V_PIXEL),
    .cmos_frame_vsync  (cmos_frame_vsync),
    .cmos_frame_href   (cmos_frame_href),
    .cmos_frame_valid  (cmos_frame_valid),
    .cmos_frame_data   (cmos_wr_data)
);

ov5640_delay u_ov5640_delay(
    .clk               (cam_pclk),
    .rst_n             (rst_n),
    .cmos_frame_vsync  (cmos_frame_vsync),
    .cmos_frame_href   (cmos_frame_href),
    .cmos_frame_valid  (cmos_frame_valid),
    .cmos_wr_data      (cmos_wr_data),
    
    .cam_write_req     (cam_write_req),
    .cam_write_req_ack (cam_write_req_ack),
    .cam_write_en      (cam_write_en),
    .cam_write_data    (cam_write_data),
    .key_snapshot      (key_snapshot)
);

// ========================= 视频时序和数据 =========================
wire hs_0, vs_0, de_0;

video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (~rst_n),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .display_en        (display_en_1)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (~rst_n),
    .read_en           (video_read_en),
    .read_data         (screen_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data),
    .display_en        (display_en_1)
);

// ========================= HDMI输出 =========================
hdmi_tx #(.FAMILY("EG4")) u3_hdmi_tx(
    .PXLCLK_I          (video_clk),
    .PXLCLK_5X_I       (hdmi_5x_clk),
    .RST_N             (rst_n),
    .VGA_HS            (hs),
    .VGA_VS            (vs),
    .VGA_DE            (de),
    .VGA_RGB           (vout_data),
    .HDMI_CLK_P        (HDMI_CLK_P),
    .HDMI_D2_P         (HDMI_D2_P),
    .HDMI_D1_P         (HDMI_D1_P),
    .HDMI_D0_P         (HDMI_D0_P)
);

// ========================= 视频帧数据读写控制 =========================
frame_read_write frame_read_write_m0(
    .mem_clk           (ext_mem_clk),
    .rst               (~rst_n),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),
    
    .read_clk          (video_clk),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (24'd0),
    .read_addr_1       (24'd0),
    .read_addr_2       (24'd0),
    .read_addr_3       (24'd0),
    .read_addr_index   (2'd0),
    .read_len          (24'd786432),
    .read_en           (video_read_en),
    .read_data         (video_read_data),
    
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),
    
    .write_clk         (cam_pclk),
    .write_req         (cam_write_req),
    .write_req_ack     (cam_write_req_ack),
    .write_finish      (),
    .write_addr_0      (24'd0),
    .write_addr_1      (24'd0),
    .write_addr_2      (24'd0),
    .write_addr_3      (24'd0),
    .write_addr_index  (2'd0),
    .write_len         (24'd786432),
    .write_en          (cam_write_en),
    .write_data        (cam_write_data),
    
    .photo_capture_req (photo_capture_req),
    .photo_capture_ack (photo_capture_ack),
    .photo_done_signal (photo_done_signal),
    .capture_len       (capture_len),
    .photo_addr_index  (1'b1)
);

// ========================= SDRAM控制器 =========================
sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (~rst_n),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

// ========================= 主控制器 =========================
main_control_new u_main_control_new(
    .clk               (clk),
    .video_clk         (video_clk),
    .cam_pclk          (cam_pclk),
    .rst_n             (rst_n),
    .eth_cmd           (cmd_data),
    .eth_cmd_valid     (cmd_valid),
    .photo_tx_done     (photo_done_signal),
    .sd_pic_receive_done(1'b0),
    .state             (state),
    .sel_read          (video_source_sel_to_read),
    .sel_write         (video_source_sel_to_write),
    .photo_trigger     (photo_trigger),
    .display_en        (display_en)
);

// ========================= 简化版拍照模块 =========================
snapshot_udp_direct u_snapshot_direct(
    .clk_50            (clk),
    .sys_rst_n         (rst_n),
    .key_snapshot      (key_snapshot),
    .snapshot_busy     (snapshot_busy),
    .snapshot_done     (snapshot_done),
    .cam_pclk          (cam_pclk),
    .cam_vsync         (cam_vsync),
    .cam_href          (cam_href),
    .cam_data          (cam_data),
    .eth_tx_ready      (eth_tx_ready),
    .eth_tx_ack        (eth_tx_ack),
    .eth_tx_data_request(eth_tx_data_request),
    .eth_tx_data_valid (eth_tx_data_valid),
    .eth_tx_data       (eth_tx_data),
    .eth_tx_data_length(eth_tx_data_length)
);

// ========================= 以太网模块 =========================
// 创建内部信号来连接以太网模块
wire udp_tx_ready;          // UDP发送就绪
wire app_tx_ack;            // 应用层发送应答
wire app_tx_data_request;   // 应用层发送数据请求
wire app_tx_data_valid;     // 应用层发送数据有效
wire [7:0] app_tx_data;     // 应用层发送数据
wire [15:0] udp_data_length;// UDP数据长度

// 信号映射：将eth_*信号映射到ethernet模块的实际端口
assign eth_tx_ready = udp_tx_ready;
assign eth_tx_ack = app_tx_ack;
assign app_tx_data_request = eth_tx_data_request;
assign app_tx_data_valid = eth_tx_data_valid;
assign app_tx_data = eth_tx_data;
assign udp_data_length = eth_tx_data_length;

ethernet eth_manager(
    // 系统时钟和复位
    .sys_clk                  (clk),
    .rst_n                    (rst_n),
    
    // PHY1 RGMII接口信号
    .phy1_rgmii_rx_clk       (phy1_rgmii_rx_clk),
    .phy1_rgmii_rx_ctl       (phy1_rgmii_rx_ctl),
    .phy1_rgmii_rx_data      (phy1_rgmii_rx_data),
    .phy1_rgmii_tx_clk       (phy1_rgmii_tx_clk),
    .phy1_rgmii_tx_ctl       (phy1_rgmii_tx_ctl),
    .phy1_rgmii_tx_data      (phy1_rgmii_tx_data),
    
    // ========================= 修复点：使用正确的端口名称 =========================
    // UDP应用层接口
    .udp_tx_ready            (udp_tx_ready),          // UDP发送就绪状态
    .app_tx_ack              (app_tx_ack),            // 应用层发送应答
    .eth_send_done_to_pho    (eth_send_done_to_pho),
    
    .app_tx_data_request     (app_tx_data_request),   // 应用层发送数据请求
    .app_tx_data_valid       (app_tx_data_valid),     // 应用层发送数据有效
    .app_tx_data             (app_tx_data),           // 应用层发送数据
    .udp_data_length         (udp_data_length),       // UDP数据长度
    .last(last),
    // 主控模块接口（指令输出）
    .cmd_valid               (cmd_valid),
    .cmd_data                (cmd_data),
    
    // 读侧（SDRAM）
    .sdram_data_out          (sdram_data_out),
    .sdram_valid_out         (),
    
    // FIFO状态
    .fifo_full               ()
);

selector_screen u_selector_screen( 
    .image_data         (sdram_data_out),
    
    .video_data         (video_read_data),
    
    .key                (key_1),
    
    .screen_data        (screen_data)   
);
// ========================= 输出连接 =========================
assign vga_out_hs = hs;
assign vga_out_vs = vs;
assign vga_out_de = de;
assign vga_data = {vout_data[23:20], vout_data[15:12], vout_data[7:4]};

endmodule