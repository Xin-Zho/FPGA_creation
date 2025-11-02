module sd_card_bmp(
    input                       clk,               
    input                       rst,             
    input                       key,                // 按键开始查找BMP文件
    input                       key2,               // 按键开始接收BMP文件
    
    output                      finish,
    
    output [3:0]                state_code,	        // 状态指示编码
    // 0:SD卡正在初始化
    // 1:等待按键按下
    // 2:正在查找BMP文件  
    // 3:正在读取数据
    // 4:正在通过UDP传输
    input [15:0]                bmp_width,	        // 查找的BMP图像宽度
    
    // UDP应用层发送接口
    input                       app_tx_data_request,   // 应用层发送数据请求
    output                      app_tx_data_valid,     // 应用层发送数据有效
    output [7:0]                app_tx_data,           // 应用层发送数据
    output [15:0]               udp_data_length,       // UDP数据长度
    output                      udp_tx_ready,          // UDP发送就绪
    output                      app_tx_ack,            // 应用层发送应答
    
    // UDP应用层接收接口
    input                       app_rx_data_valid,             // 应用层接收数据有效
    input [7:0]                 app_rx_data,                   // 应用层接收数据
    input [15:0]                app_rx_data_length,            // 应用层接收数据长度
    input [15:0]                app_rx_port_num,               // 应用层接收端口号(不同)
    
    // SD卡接口
    output                      SD_nCS,             // SD卡片选 (SPI模式)
    output                      SD_DCLK,            // SD卡时钟
    output                      SD_MOSI,            // SD卡控制器数据输出
    input                       SD_MISO,             // SD卡控制器数据输入
    
    //写入接口
    output                      sd_sec_write,              //SD card sector write
	output [31:0]               sd_sec_write_addr,         //SD card sector write address
	output [7:0]                sd_sec_write_data,         //SD card sector write data
	input                       sd_sec_write_data_req,     //SD card sector write data next clock is valid
	input                       sd_sec_write_end           //SD card sector write end
);

// 内部信号定义
wire button_negedge;
wire button_negedge2;
wire sd_sec_read;
wire [31:0] sd_sec_read_addr;
wire [7:0] sd_sec_read_data;
wire sd_sec_read_data_valid;
wire sd_sec_read_end;
wire sd_init_done;

// 状态信号
wire [3:0] send_state_code;                 // 发送状态码
wire [3:0] recv_state_code;                 // 接收状态码

// 内部连线信号 - 用于连接接收器输出
wire sd_sec_write_int;
wire [31:0] sd_sec_write_addr_int;
wire [7:0] sd_sec_write_data_int;

// 按键消抖模块 — 发送
ax_debounce ax_debounce_m0
(
    .clk             (clk),
    .rst             (rst),
    .button_in       (key),
    .button_posedge  (),
    .button_negedge  (button_negedge),
    //接收器按钮
    .button_out      ()
);

// 按键消抖模块 - 接收
ax_debounce ax_debounce_m1
(
    .clk             (clk),
    .rst             (rst),
    .button_in       (key2),
    .button_posedge  (),
    .button_negedge  (button_negedge2),
    .button_out      ()
);

// BMP UDP发送器模块
wire send_finish;
wire receiver_finish;
assign finish = send_finish | receiver_finish;

bmp_udp_sender bmp_udp_sender_m0(
    .clk                       (clk),
    .rst                       (rst),
    .ready                     (),                    // 可选的准备好信号
    .find                      (button_negedge),      // 按键触发查找和传输
    .sd_init_done              (sd_init_done),
    .state_code                (send_state_code), 
    .bmp_width                 (bmp_width),
    
     .send_finish               (send_finish),
    
    // SD卡接口
    .sd_sec_read               (sd_sec_read),
    .sd_sec_read_addr          (sd_sec_read_addr),
    .sd_sec_read_data          (sd_sec_read_data),
    .sd_sec_read_data_valid    (sd_sec_read_data_valid),
    .sd_sec_read_end           (sd_sec_read_end),
    
    // UDP应用层发送接口
    .app_tx_data_request       (app_tx_data_request),
    .app_tx_data_valid         (app_tx_data_valid),
    .app_tx_data               (app_tx_data),
    .udp_data_length           (udp_data_length),
    .udp_tx_ready              (udp_tx_ready),
    .app_tx_ack                (app_tx_ack)
);

//BMP UDP接收器模块
bmp_udp_receiver bmp_udp_receiver_m0(
    .clk                       (clk),
    .rst                       (rst),
    .ready                     (),                    // 可选的准备好信号
    .find                      (button_negedge2),     // 按键触发接收
    .sd_init_done              (sd_init_done),
    .state_code                (recv_state_code),     // 接收状态码
    .bmp_width                 (bmp_width),           // 用于验证接收的BMP文件
    
    .receiver_finish           (receiver_finish),
    // SD卡写入接口
    .sd_sec_write              (sd_sec_write_int),
    .sd_sec_write_addr         (sd_sec_write_addr_int),
    .sd_sec_write_data         (sd_sec_write_data_int),
    .sd_sec_write_data_req     (sd_sec_write_data_req),
    .sd_sec_write_end          (sd_sec_write_end),
    
    // UDP应用层接收接口
    .app_rx_data_valid         (app_rx_data_valid),
    .app_rx_data               (app_rx_data),
    .app_rx_data_length        (app_rx_data_length),
    .app_rx_port_num           (app_rx_port_num)
);

// SD卡控制器顶层模块
sd_card_top sd_card_top_m0(
    .clk                       (clk),
    .rst                       (rst),
    .SD_nCS                    (SD_nCS),
    .SD_DCLK                   (SD_DCLK),
    .SD_MOSI                   (SD_MOSI),
    .SD_MISO                   (SD_MISO),
    .sd_init_done              (sd_init_done),
    .sd_sec_read               (sd_sec_read),
    .sd_sec_read_addr          (sd_sec_read_addr),
    .sd_sec_read_data          (sd_sec_read_data),
    .sd_sec_read_data_valid    (sd_sec_read_data_valid),
    .sd_sec_read_end           (sd_sec_read_end),
    
    // SD卡写入接口
    .sd_sec_write              (sd_sec_write),           // 连接写入使能
    .sd_sec_write_addr         (sd_sec_write_addr),      // 连接写入地址
    .sd_sec_write_data         (sd_sec_write_data),      // 连接写入数据
    .sd_sec_write_data_req     (sd_sec_write_data_req),  // 连接写入请求
    .sd_sec_write_end          (sd_sec_write_end)        // 连接写入结束
    
//    .sd_sec_write              (1'b0),                // 禁用写功能
//    .sd_sec_write_addr         (32'd0),               // 写地址置零
//    .sd_sec_write_data         (),                    // 写数据未连接
//    .sd_sec_write_data_req     (),                    // 写数据请求未连接
//    .sd_sec_write_end          ()                     // 写结束未连接
);

// 状态码选择：优先显示接收状态，无接收时显示发送状态
assign state_code = (button_negedge2 || recv_state_code != 4'd0) ? recv_state_code : send_state_code;

// 输出信号连接
assign sd_sec_write = sd_sec_write_int;
assign sd_sec_write_addr = sd_sec_write_addr_int;
assign sd_sec_write_data = sd_sec_write_data_int;

endmodule