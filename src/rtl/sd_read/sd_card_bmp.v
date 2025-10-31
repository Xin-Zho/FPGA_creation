module sd_card_bmp(
    input                       clk,               
    input                       rst,             
    input                       key,                // 按键开始查找BMP文件
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
    
    // SD卡接口
    output                      SD_nCS,             // SD卡片选 (SPI模式)
    output                      SD_DCLK,            // SD卡时钟
    output                      SD_MOSI,            // SD卡控制器数据输出
    input                       SD_MISO             // SD卡控制器数据输入
);

// 内部信号定义
wire button_negedge;
wire sd_sec_read;
wire [31:0] sd_sec_read_addr;
wire [7:0] sd_sec_read_data;
wire sd_sec_read_data_valid;
wire sd_sec_read_end;
wire sd_init_done;

// 按键消抖模块
ax_debounce ax_debounce_m0
(
    .clk             (clk),
    .rst             (rst),
    .button_in       (key),
    .button_posedge  (),
    .button_negedge  (button_negedge),
    .button_out      ()
);

// BMP UDP发送器模块
bmp_udp_sender bmp_udp_sender_m0(
    .clk                       (clk),
    .rst                       (rst),
    .ready                     (),                    // 可选的准备好信号
    .find                      (button_negedge),      // 按键触发查找和传输
    .sd_init_done              (sd_init_done),
    .state_code                (state_code),
    .bmp_width                 (bmp_width),
    
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
    .sd_sec_write              (1'b0),                // 禁用写功能
    .sd_sec_write_addr         (32'd0),               // 写地址置零
    .sd_sec_write_data         (),                    // 写数据未连接
    .sd_sec_write_data_req     (),                    // 写数据请求未连接
    .sd_sec_write_end          ()                     // 写结束未连接
);

endmodule