module top(
	input                       clk,
	input                       rst_n,
 
    output			vga_out_hs,
    output			vga_out_vs,
//    output			vga_out_de,
    output	[11:0]	vga_data,
    //hdmi接口                         
	//HDMI
	output			HDMI_CLK_P,
	output			HDMI_D2_P,
	output			HDMI_D1_P,
	output			HDMI_D0_P,
	//摄像头接口                       
    input                 cam_pclk     ,  //cmos 数据像素时钟
    input                 cam_vsync    ,  //cmos 场同步信号
    input                 cam_href     ,  //cmos 行同步信号
    input   [7:0]         cam_data     ,  //cmos 数据
    output                cam_rst_n    ,  //cmos 复位信号，低电平有效
    output                cam_pwdn     ,  //电源休眠模式选择 0：正常模式 1：电源休眠模式
    output                cam_scl      ,  //cmos SCCB_SCL线
    inout                 cam_sda      ,  //cmos SCCB_SDA线 
    input                       phy1_rgmii_rx_clk,   // RGMII接收时钟
    input                       phy1_rgmii_rx_ctl,   // RGMII接收控制
    input  [3:0]                phy1_rgmii_rx_data,  // RGMII接收数据
    output                      phy1_rgmii_tx_clk,    // RGMII发送时钟
    output                      phy1_rgmii_tx_ctl,    // RGMII发送控制
    output [3:0]                phy1_rgmii_tx_data    // RGMII发送数据 
);

parameter MEM_DATA_BITS         = 32  ;            //external memory user interface data width
parameter ADDR_BITS             = 21  ;            //external memory user interface address width
parameter BUSRT_BITS            = 10  ;            //external memory user interface burst width

                                
parameter  V_CMOS_DISP = 11'd768;                  //CMOS分辨率--行
parameter  H_CMOS_DISP = 11'd1024;                 //CMOS分辨率--列	
parameter  TOTAL_H_PIXEL = H_CMOS_DISP + 12'd1216; //CMOS分辨率--行
parameter  TOTAL_V_PIXEL = V_CMOS_DISP + 12'd504;    										   
							   

wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire    vga_out_de;
wire                            read_req;
wire                            read_req_ack;
wire                            read_en;
wire                            write_en;
wire                            write_req;
wire                            write_req_ack;
wire                            sd_card_clk;       //SD card controller clock
wire                            ext_mem_clk;       //external memory clock
wire                            ext_mem_clk_sft;

wire                            video_clk;         //video pixel clock
wire							hdmi_5x_clk;
wire                            hs;
wire                            vs;
wire 							de;
wire[23:0]                      vout_data;


wire									  write_clk;
wire									  read_clk;

wire                            video_read_req;
wire                            video_read_req_ack;
wire                            video_read_en;
wire[31:0]                      video_read_data;
wire                            cam_write_en_to_mux;
wire[31:0]                      cam_write_data_to_mux;
wire                            cam_write_req;
wire                            cam_write_req_ack;

wire                            final_vga_data;
wire                            final_vga_de;

wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS - 1 : 0]Sdr_rd_dout;

wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS - 1 : 0]App_wr_din;
wire [3:0] App_wr_dm;

wire cmos_frame_vsync;
wire cmos_frame_href;
wire cmos_frame_valid;
wire [15:0] cmos_wr_data;

// 以太网相关信号
wire [1:0] eth_cmd;
wire eth_cmd_valid;
wire photo_tx_done;
wire sd_pic_receive_done;

// 主控模块输出的控制信号
wire [1:0] state;
wire [1:0] video_source_sel;
wire sd_pic_display_en;
wire photo_trigger;  // 这是主控模块的输出信号

// 拍照模块相关信号
wire photo_led;
wire photo_capture_req;
wire photo_capture_ack;
wire [23:0] capture_addr;
wire capture_len;
wire [23:0] current_frame_addr;
wire frame_valid_signal;
wire [31:0] eth_send_frame_addr;
wire [31:0] eth_send_image_size;
wire eth_send_busy;
wire eth_send_done;
wire photo_busy_status;
wire photo_done_signal;  

assign vga_out_hs = hs;
assign vga_out_vs = vs;
assign vga_out_de = de;
assign vga_data = {vout_data[23:20],vout_data[15:12],vout_data[7:4]};
//assign vga_out_r  = vout_data[15:11];
//assign vga_out_g  = vout_data[10:5];
//assign vga_out_b  = vout_data[4:0];
assign sdram_clk = ext_mem_clk;
//generate SD card controller clock and  SDRAM controller clock

sys_pll sys_pll_m0(
	.refclk                     (clk),
	.clk0_out                   (ext_mem_clk),
	.clk1_out                   (ext_mem_clk_sft),
    .reset						(1'b0)
    );
//generate video pixel clock	
video_pll video_pll_m0(
	.refclk                     (clk),
	.clk0_out                   (video_clk),
    .clk1_out					(hdmi_5x_clk),
    .reset						(1'b0)
	);
//ov5640 驱动
ov5640_dri u_ov5640_dri(
    .clk               (clk),
    .rst_n             (rst_n),

    .cam_pclk          (cam_pclk ),
    .cam_vsync         (cam_vsync),
    .cam_href          (cam_href ),
    .cam_data          (cam_data ),
    .cam_rst_n         (cam_rst_n),
    .cam_pwdn          (cam_pwdn ),
    .cam_scl           (cam_scl  ),
    .cam_sda           (cam_sda  ),
    
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
    .cmos_wr_data   (cmos_wr_data),
    
    .cam_write_req(cam_write_req),
    .cam_write_req_ack(cam_write_req_ack),
    .cam_write_en(cam_write_en),
    .cam_write_data(cam_write_data)
);
//
wire hs_0;
wire vs_0;
wire de_0;
video_timing_data video_timing_data_m0
(
	.video_clk                  (video_clk                ),
	.rst                        (~rst_n    ),
	.read_req                   (video_read_req           ),
	.read_req_ack               (video_read_req_ack       ),
	//.read_en                    (video_read_en            ),
	//.read_data                  (video_read_data          ),
	.hs                         (hs_0                       ),
	.vs                         (vs_0                       ),
	.de                         (de_0                         )
    

	//.vout_data                  (vout_data                )
);
video_delay video_delay_m0
(
    .video_clk                  (video_clk                ),
	.rst                        (~rst_n    ),
    .read_en					(video_read_en),
    .read_data					(video_read_data[31:8]),
    .hs                         (hs_0                       ),
	.vs                         (vs_0                       ),
	.de                         (de_0                         ),
	.hs_r                       (hs                       ),
	.vs_r                       (vs                       ),
	.de_r                       (de                       ),
	.vout_data					(vout_data)
);
hdmi_tx #(.FAMILY("EG4"))	//EF2、EF3、EG4、AL3、PH1

 u3_hdmi_tx
	(
		.PXLCLK_I(video_clk),
		.PXLCLK_5X_I(hdmi_5x_clk),

		.RST_N (rst_n),
		
		//VGA
		.VGA_HS (hs ),
		.VGA_VS (vs ),
		.VGA_DE (de ),
		.VGA_RGB(vout_data),

		//HDMI
		.HDMI_CLK_P(HDMI_CLK_P),
		.HDMI_D2_P (HDMI_D2_P ),
		.HDMI_D1_P (HDMI_D1_P ),
		.HDMI_D0_P (HDMI_D0_P )	
		
	);
//video frame data read-write control
frame_read_write frame_read_write_m0(
    .mem_clk					(ext_mem_clk),
    .rst						(~rst_n),
    .Sdr_init_done				(Sdr_init_done),
    .Sdr_init_ref_vld			(Sdr_init_ref_vld),
    .Sdr_busy					(Sdr_busy),
    
    .App_rd_en					(App_rd_en),
    .App_rd_addr				(App_rd_addr),
    .Sdr_rd_en					(Sdr_rd_en),
    .Sdr_rd_dout				(Sdr_rd_dout),
    
    .read_clk                   (video_clk           ),
	.read_req                   (video_read_req           ),
	.read_req_ack               (video_read_req_ack       ),
	.read_finish                (                   ),
	.read_len                   (24'd786432         ), //frame size//24'd786432
	.read_en                    (video_read_en            ),
	.read_data                  (video_read_data          ),
    
    .App_wr_en					(App_wr_en),
    .App_wr_addr				(App_wr_addr),
    .App_wr_din					(App_wr_din),
    .App_wr_dm					(App_wr_dm),
    
    .write_clk                  (cam_pclk        ),
	.write_req                  (cam_write_req        ),
	.write_req_ack              (cam_write_req_ack    ),
	.write_finish               (                 ),
	.write_addr_0               (24'd0            ),
	.write_addr_1               (24'd0       ),
	.write_addr_2               (24'd0            ),
	.write_addr_3               (24'd0            ),
	.write_addr_index           (2'd0             ), //use only write_addr_0
	.write_len                  (24'd786432       ), //frame size
	.write_en                   (cam_write_en         ),
	.write_data                 (cam_write_data       ),
    .capture_req                (photo_capture_req    ),
    .capture_ack                (photo_capture_ack    ),
    .capture_src_addr               (capture_addr  ),
    .capture_length                (capture_len  ),

    .sel                        (video_source_sel)
);

sdram U3
(
.Clk				(ext_mem_clk),
.Clk_sft			(ext_mem_clk_sft),
.Rst				(~rst_n),
    
.Sdr_init_done		(Sdr_init_done),
.Sdr_init_ref_vld	(Sdr_init_ref_vld),
.Sdr_busy			(Sdr_busy),
    
.App_wr_en			(App_wr_en),
.App_wr_addr		(App_wr_addr),  	
.App_wr_dm			(App_wr_dm),
.App_wr_din			(App_wr_din),
    
.App_rd_en			(App_rd_en),//data_req
.App_rd_addr		(App_rd_addr),
.Sdr_rd_en			(Sdr_rd_en),//data_valid
.Sdr_rd_dout		(Sdr_rd_dout)
);

ethernet_trans u_ethernet_trans (
    // 系统时钟和复位
    .clk_50                  (clk),                    // 50MHz系统时钟
    .sys_rst_n               (rst_n),                 // 系统复位，低电平有效
    
    // PHY1 RGMII接口信号
    .phy1_rgmii_rx_clk       (phy1_rgmii_rx_clk),     // RGMII接收时钟（需要从PHY芯片输入）
    .phy1_rgmii_rx_ctl       (phy1_rgmii_rx_ctl),     // RGMII接收控制（需要从PHY芯片输入）
    .phy1_rgmii_rx_data      (phy1_rgmii_rx_data),    // RGMII接收数据（需要从PHY芯片输入）
    .phy1_rgmii_tx_clk       (phy1_rgmii_tx_clk),     // RGMII发送时钟（输出到PHY芯片）
    .phy1_rgmii_tx_ctl       (phy1_rgmii_tx_ctl),     // RGMII发送控制（输出到PHY芯片）
    .phy1_rgmii_tx_data      (phy1_rgmii_tx_data),    // RGMII发送数据（输出到PHY芯片）
    
    .led                     (eth_leds),              // LED状态指示（可连接到实际LED）
    
    // UDP应用层接口信号 - 接收侧（从网络接收命令）
    .app_rx_data_valid       (eth_cmd_valid),         // 连接到主控模块的命令有效信号
    .app_rx_data             (eth_cmd),         // 接收到的命令数据
    .app_rx_data_length      (eth_data_length),       // 接收数据长度
    .app_rx_port_num         (eth_port_num),          // 接收端口号
    
    // UDP应用层接口信号 - 发送侧（发送图像数据到网络）
    .udp_tx_ready            (eth_tx_ready),          // UDP发送就绪状态
    .app_tx_ack              (eth_tx_ack),           // 应用层发送应答
    
    .app_tx_data_request     (eth_tx_data_request),   // 应用层发送数据请求（由拍照模块控制）
    .app_tx_data_valid       (eth_tx_data_valid),     // 应用层发送数据有效（由数据读取逻辑控制）
    .app_tx_data             (eth_tx_data),           // 应用层发送数据（图像数据）
    .udp_data_length         (eth_tx_data_length)     // UDP数据长度（图像大小）
);  

// 以太网应用层接口信号
wire               eth_cmd_valid;         // 命令接收有效
wire [7:0]         eth_cmd_data;          // 接收到的命令数据
wire [15:0]        eth_data_length;        // 接收数据长度
wire [15:0]        eth_port_num;          // 接收端口号

wire               eth_tx_ready;          // 发送就绪状态
wire               eth_tx_ack;            // 发送应答

// 发送侧控制信号（需要连接到拍照模块和数据读取逻辑）
wire               eth_tx_data_request;   // 发送数据请求
wire               eth_tx_data_valid;     // 发送数据有效
wire [7:0]         eth_tx_data;           // 发送的数据
wire [15:0]        eth_tx_data_length;    // 发送数据长度

wire [2:0]         eth_leds;              // 以太网状态LED指示

wire        parser_cmd_valid;
wire [7:0]  parser_cmd_data;
wire        parser_sdram_wr_en;
wire [7:0]  parser_sdram_wr_data;
wire [23:0] parser_sdram_wr_addr;
wire        parser_image_start;
wire        parser_image_end;
wire [15:0] parser_image_data_count;
wire [2:0]  parser_state;
wire        parser_is_image_packet;

udp_data_parser u_udp_parser (
    // 系统时钟和复位
    .clk                    (clk),               // 50MHz系统时钟
    .rst_n                  (rst_n),            // 系统复位
    
    // UDP接收接口（连接以太网模块）
    .udp_rx_valid           (eth_cmd_valid),    // 来自以太网模块
    .udp_rx_data            (eth_cmd),          // 以太网接收数据
    .udp_rx_length         (eth_data_length),   // 数据包长度
    
    // 主控模块接口
    .cmd_valid             (parser_cmd_valid),     // 指令有效
    .cmd_data              (parser_cmd_data),      // 指令数据
    
    // SDRAM写入接口
    .sdram_wr_en           (parser_sdram_wr_en),  // SDRAM写使能
    .sdram_wr_data         (parser_sdram_wr_data), // 写入数据
    .sdram_wr_addr         (parser_sdram_wr_addr), // 写入地址
    .image_start           (parser_image_start),   // 图片开始
    .image_end             (parser_image_end),     // 图片结束
    .image_data_count      (parser_image_data_count), // 数据计数
    
    // 状态指示
    .parser_state          (parser_state),         // 解析器状态
    .is_image_packet       (parser_is_image_packet) // 包类型指示
);

main_control_new  u_main_control_new (
    .clk                        (clk),
    .rst_n                      (rst_n),
    .eth_cmd                    (parser_cmd_data),
    .eth_cmd_valid              (parser_cmd_valid),
    .state                      (state),
    .video_source_sel           (video_source_sel),
    .photo_trigger              (photo_trigger),        // 这是输出信号
    .sd_pic_display_en          (sd_pic_display_en)
);

// 实例化拍照控制模块
photo_picture u_photo_picture (
    .clk                        (clk),                    // 使用主时钟
    .rst_n                      (rst_n),                // 使用主复位
    .state_trigger              (photo_trigger), // 连接主控模块产生的触发信号
    .capture_led                (photo_led),
    .capture_req                (photo_capture_req),
    .capture_ack                (photo_capture_ack),
    .frame_base_addr            (current_frame_addr),
    .frame_valid                (frame_valid_signal),
    .image_width                (16'd800), 
    .image_height               (16'd480),
    .eth_send_start             (eth_send_start),
    .eth_frame_addr             (eth_send_frame_addr),
    .eth_image_size             (eth_send_image_size),
    .eth_send_busy              (eth_send_busy),
    .eth_send_done              (eth_send_done),
    .photo_busy                 (photo_busy_status),
    .photo_done                 (photo_done_signal),
    .capture_len                (capture_len),
    .capture_addr               (capture_addr)
);

// 实例化图像数据选择器
video_mux u_video_mux (
    // 输入：摄像头实时数据
    .cam_video_data             (cam_write_data_to_mux),      // 需要连接到摄像头实时数据
    .cam_video_de               (cam_write_en_to_mux),               // 摄像头数据有效信号
    
    // 输入：拍照捕获的数据  
    .photo_video_data           (video_read_data),     // 需要连接到拍照模块输出数据
    .photo_video_de             (video_read_en),           // 拍照数据有效信号
    
    // 输入：SD卡图片数据
    .sd_pic_video_data          (sd_pic_data),          // 需要连接到SD卡图片接收数据
    .sd_pic_video_de            (sd_pic_de),               // SD卡图片数据有效信号
    
    // 控制信号（来自主控模块）
    .sel                        (video_source_sel_to_mux),    // 视频源选择信号
    
    // 输出到显示接口
    .vga_data_out               (final_vga_data),            // 最终输出的RGB数据
    .vga_de_out                 (final_vga_de)                 // 最终输出的数据有效信号
);

endmodule 