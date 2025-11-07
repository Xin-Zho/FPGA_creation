module ethernet(
    input sys_clk,
    input rst_n,
    
    // eth接口信号
    input               phy1_rgmii_rx_clk,   // RGMII接收时钟
    input               phy1_rgmii_rx_ctl,   // RGMII接收控制
    input [3:0]         phy1_rgmii_rx_data,  // RGMII接收数据
    output wire         phy1_rgmii_tx_clk,   // RGMII发送时钟
    output wire         phy1_rgmii_tx_ctl,   // RGMII发送控制
    output wire [3:0]   phy1_rgmii_tx_data,   // RGMII发送数据
    
    output              udp_tx_ready,          // UDP发送就绪
    output              app_tx_ack,            // 应用层发送应答
    output              eth_send_done_to_pho,         // 新增：以太网发送完成信号（单周期脉冲）

    input               app_tx_data_request,   // 应用层发送数据请求
    input               app_tx_data_valid,     // 应用层发送数据有效
    input [7:0]         app_tx_data,           // 应用层发送数据
    input [15:0]        udp_data_length,       // UDP数据长度
    
    output      reg        last,

    
    // 外部数据接口
    // 主控模块接口（指令输出）
    output          cmd_valid,             // 指令有效信号
    output [7:0]    cmd_data,              // 指令数据（1字节）
    
    // SDRAM写出接口（图片数据输出）
    output              fifo_full,
    output [31:0]       sdram_data_out,     // 输出到SDRAM的32bit数据
    output              sdram_valid_out    // 输出数据有效（高有效）
    
 );
 
wire app_rx_data_valid;     // 应用层接收数据有效     
wire app_rx_data;           // 应用层接收数据       
wire app_rx_data_length;    // 应用层接收数据长度     
wire app_rx_port_num;       // 应用层接收端口号      
                                                             



always@(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)
        last <= 1'b0;
    else if(app_rx_data_valid == 1'b1)
        last <= 1'b1;
    else
        last <= last;
        
end

ethernet_trans eth_trans (
    // 系统时钟和复位
    .clk_50                  (sys_clk),                    // 50MHz系统时钟
    .sys_rst_n               (rst_n),                 // 系统复位，低电平有效
    
    // PHY1 RGMII接口信号
    .phy1_rgmii_rx_clk       (phy1_rgmii_rx_clk),     // RGMII接收时钟（需要从PHY芯片输入）
    .phy1_rgmii_rx_ctl       (phy1_rgmii_rx_ctl),     // RGMII接收控制（需要从PHY芯片输入）
    .phy1_rgmii_rx_data      (phy1_rgmii_rx_data),    // RGMII接收数据（需要从PHY芯片输入）
    .phy1_rgmii_tx_clk       (phy1_rgmii_tx_clk),     // RGMII发送时钟（输出到PHY芯片）
    .phy1_rgmii_tx_ctl       (phy1_rgmii_tx_ctl),     // RGMII发送控制（输出到PHY芯片）
    .phy1_rgmii_tx_data      (phy1_rgmii_tx_data),    // RGMII发送数据（输出到PHY芯片）
    
    //.led                     (eth_leds),              // LED状态指示（可连接到实际LED）
    
    // UDP应用层接口信号 - 接收侧（从网络接收命令）
    .app_rx_data_valid       (app_rx_data_valid),         // 连接到主控模块的命令有效信号
    .app_rx_data             (app_rx_data),         // 接收到的命令数据
    .app_rx_data_length      (app_rx_data_length),       // 接收数据长度
    .app_rx_port_num         (app_rx_port_num),          // 接收端口号
    
    // UDP应用层接口信号 - 发送侧（发送图像数据到网络）
    .udp_tx_ready            (udp_tx_ready),          // UDP发送就绪状态
    .app_tx_ack              (app_tx_ack),           // 应用层发送应答
    .eth_send_done           (eth_send_done_to_pho),
    
    .app_tx_data_request     (app_send_req),            // 应用层发送数据请求（由拍照模块控制）
    .app_tx_data_valid       (app_tx_data_valid),     // 应用层发送数据有效（由数据读取逻辑控制）
    .app_tx_data             (app_tx_data),           // 应用层发送数据（图像数据）
    .udp_data_length         (udp_tx_data_length)     // UDP数据长度（图像大小）
    
);  

wire sdram_wr_en;
wire sdram_wr_data;

udp_data_parser u_udp_data_parser (
    // 系统时钟和复位
    .clk            (sys_clk),
    .rst_n          (rst_n),
    
    // UDP接收接口（来自以太网模块）
    .udp_rx_valid   (app_rx_data_valid),
    .udp_rx_data    (app_rx_data),
    .udp_rx_length  (app_rx_data_length),
    
    // 主控模块接口（指令输出）
    .cmd_valid      (cmd_valid),
    .cmd_data       (cmd_data),
    
    // SDRAM写入接口（图片数据输出）
    .sdram_wr_en    (sdram_wr_en),
    .sdram_wr_data  (sdram_wr_data)
    
    // 状态指示
//    .parser_state   (parser_state),
//    .is_image_packet(is_image_packet)
);



picture_read trans_picture (
    
    .clk_wr      (sys_clk),
    .rst_n       (rst_n),
    
    // 写侧（以太网）
    .data_in     (sdram_wr_data),
    .valid_in    (sdram_wr_en),
    
    // 读侧（SDRAM）
    .data_out    (sdram_data_out),
    .valid_out   (sdram_valid_out),
    
    // FIFO状态
    .fifo_full   (fifo_full)
);



endmodule