`timescale 1ns / 1ps

// UDP回环模式定义
`define UDP_LOOP_BACK

module ethernet_trans_control(
    // 系统时钟和复位
    input  clk_50,           // 50MHz系统时钟
    input  sys_rst_n,        // 系统复位信号，低电平有效
    
    // PHY1 RGMII接口信号
    input               phy1_rgmii_rx_clk,   // RGMII接收时钟
    input               phy1_rgmii_rx_ctl,   // RGMII接收控制
    input [3:0]         phy1_rgmii_rx_data,  // RGMII接收数据
    output wire         phy1_rgmii_tx_clk,   // RGMII发送时钟
    output wire         phy1_rgmii_tx_ctl,   // RGMII发送控制
    output wire [3:0]   phy1_rgmii_tx_data,   // RGMII发送数据
    
    output [2:0]        led ,                 // LED状态指示
    
    
    // UDP应用层接口信号
    output               app_rx_data_valid,     // 应用层接收数据有效
    output [7:0]         app_rx_data,           // 应用层接收数据
    output [15:0]        app_rx_data_length,    // 应用层接收数据长度
    output [15:0]        app_rx_port_num,       // 应用层接收端口号
    
    output               udp_tx_ready,          // UDP发送就绪
    output               app_tx_ack,            // 应用层发送应答

    input               app_tx_data_request,   // 应用层发送数据请求
    input               app_tx_data_valid,     // 应用层发送数据有效
    input [7:0]         app_tx_data,           // 应用层发送数据
    input [15:0]        udp_data_length        // UDP数据长度

//      //loopback信号
//    input app_clk,              // 应用层接收时钟
//    input udp_wrusedw,          // UDP FIFO写使用字数
//    input [23:0] input_data,    // 应用层接收数据（图像数据）
//    output input_vaild,         // 应用层接收数据有效
//    output full_flag           // 写满标志
    
);

// ========================= 参数定义 =========================
parameter  DEVICE             = "EG4";              // 设备类型："PH1","EG4"
parameter  LOCAL_UDP_PORT_NUM = 16'h0001;           // 本地UDP端口号
parameter  LOCAL_IP_ADDRESS   = 32'hc0a8f001;       // 本地IP地址：192.168.240.1
parameter  LOCAL_MAC_ADDRESS  = 48'h0123456789ab;   // 本地MAC地址
parameter  DST_UDP_PORT_NUM   = 16'h0002;           // 目标UDP端口号
parameter  DST_IP_ADDRESS     = 32'hc0a8f002;       // 目标IP地址：192.168.240.2

// ========================= 复位定义 =========================
//系统二级复位控制
reg                sys_rst_n_1, sys_rst_n_2; // 系统复位同步寄存器

wire               key1 = sys_rst_n;      // 复位按键1
wire               key2;                  // 复位按键2
assign             key2 = sys_rst_n_2;
wire               reset, reset_reg;      // 复位信号
assign             reset = ~key1 || reset_reg || (soft_reset_cnt != 'd0); // 总体复位信号

always @(posedge clk_50 or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        sys_rst_n_1 <= 1'b0;
        sys_rst_n_2 <= 1'b0;
    end else begin
        sys_rst_n_1 <= sys_rst_n;
        sys_rst_n_2 <= sys_rst_n_1;
    end
end

wire rst_n;  // 同步后的复位信号
assign rst_n = sys_rst_n_2;

//PHY复位控制
reg [7:0]          phy_reset_cnt = 'd0;   // PHY复位计数器

always @(posedge clk_50_out or negedge key1) begin
    if(~key1)
        phy_reset_cnt <= 'd0;
    else if(phy_reset_cnt < 255)
        phy_reset_cnt <= phy_reset_cnt + 1;
    else
        phy_reset_cnt <= phy_reset_cnt;
end

wire phy_reset;  // PHY复位信号
assign phy_reset = phy_reset_cnt[7];

//软复位控制
reg [7:0]          soft_reset_cnt = 8'hff;// 软复位计数器

always @(posedge udp_clk or negedge key1) begin
    if(~key1)
        soft_reset_cnt <= 8'hff;
    else if(soft_reset_cnt > 0)
        soft_reset_cnt <= soft_reset_cnt - 1;
    else
        soft_reset_cnt <= soft_reset_cnt;
end

// ========================= 时钟定义 =========================

//RGMII接收时钟PLL
wire phy1_rgmii_rx_clk_0;   // RGMII接收时钟0度
wire phy1_rgmii_rx_clk_90;  // RGMII接收时钟90度

rx_pll clk_rx_pll(
    .refclk     (phy1_rgmii_rx_clk),  // 参考时钟
    .reset      (1'b0),               // 复位
    .clk0_out   (phy1_rgmii_rx_clk_0), // 0度时钟输出
    .clk1_out   (phy1_rgmii_rx_clk_90) // 90度时钟输出
 ); 

//TEMAC和UDP协议栈时钟
wire               temac_clk;             // TEMAC时钟
wire               temac_clk90;           // TEMAC 90度相移时钟
wire               clk_125_out;           // 125MHz时钟输出
wire               clk_12_5_out;          // 12.5MHz时钟输出
wire               clk_1_25_out;          // 1.25MHz时钟输出

wire               clk_50_out;            // 25MHz时钟输出 ？

clk_gen_rst_gen #(.DEVICE (DEVICE)  // 设备类型参数
    ) clk_eth_gen (
    .reset         (~key1),        // 复位输入
    .clk_in        (clk_50),       // 时钟输入
    .rst_out       (reset_reg),    // 复位输出
    
    .clk_125_out0  (temac_clk),    // 125MHz时钟输出0
    .clk_125_out1  (clk_125_out),  // 125MHz时钟输出1
    .clk_125_out2  (temac_clk90),  // 125MHz 90度相移时钟
    .clk_12_5_out  (clk_12_5_out), // 12.5MHz时钟输出
    .clk_1_25_out  (clk_1_25_out), // 1.25MHz时钟输出
    
    .clk_25_out    (clk_50_out)    // 25MHz时钟输出
);

//UDP时钟
wire               udp_clk;               // UDP时钟

wire [1:0]         TRI_speed;             // 三速以太网速度设置
assign TRI_speed = 2'b10;//千兆2'b10 百兆2'b01 十兆2'b00
 
udp_clk_gen #(
    .DEVICE (DEVICE)  // 设备类型参数
)   clk_temac_gen (           
    .reset                (~key1),          // 复位
    .tri_speed            (TRI_speed),      // 三速设置
    .clk_125_in           (clk_125_out),    // 125MHz时钟输入
    .clk_12_5_in          (clk_12_5_out),   // 12.5MHz时钟输入
    .clk_1_25_in          (clk_1_25_out),   // 1.25MHz时钟输入
    .udp_clk_out          (udp_clk)         // UDP时钟输出
);  

// ========================= TEMAC定义 =========================
// TEMAC接口信号
// TEMAC-FIFO接口信号
 //内部时钟
wire               rx_clk_int;            // 内部接收时钟
wire               rx_clk_en_int;         // 内部接收时钟使能
wire               tx_clk_int;            // 内部发送时钟
wire               tx_clk_en_int;         // 内部发送时钟使能

wire               rx_valid;              // 接收有效
wire [7:0]         rx_data;               // 接收数据

wire [7:0]         tx_data;               // 发送数据
wire               tx_valid;              // 发送有效
wire               tx_rdy;                // 发送就绪
wire               tx_collision;          // 发送冲突
wire               tx_retransmit;         // 发送重传

 //流程控制
wire               tx_stop;               // 发送停止
wire [7:0]         tx_ifg_val;            // 发送帧间隔值
wire               pause_req;             // 暂停请求
wire [15:0]        pause_val;             // 暂停值
wire [47:0]        pause_source_addr;     // 暂停源地址
 // TEMAC配置信号
assign tx_stop           = 1'b0;           // 发送停止控制
assign tx_ifg_val        = 8'h00;          // 发送帧间隔值
assign pause_req         = 1'b0;           // 暂停请求
assign pause_val         = 16'h0;          // 暂停值
assign pause_source_addr = 48'h5af1f2f3f4f5; // 暂停源地址

 //接收反馈信号
wire               rx_correct_frame;      // 正确接收帧
wire               rx_error_frame;        // 错误接收帧

//PHY-MAC
 //地址配置
wire [47:0]        unicast_address;       // 单播地址
assign unicast_address   = {  // MAC地址格式转换（字节序调整） 
    LOCAL_MAC_ADDRESS[7:0],
    LOCAL_MAC_ADDRESS[15:8],
    LOCAL_MAC_ADDRESS[23:16],
    LOCAL_MAC_ADDRESS[31:24],
    LOCAL_MAC_ADDRESS[39:32],
    LOCAL_MAC_ADDRESS[47:40]
};
wire [19:0]        mac_cfg_vector;        // MAC配置向量
assign mac_cfg_vector = {1'b0, 2'b00, TRI_speed, 8'b00000010, 7'b0000010};//地址过滤模式、流控配置、速度配置、接收器配置、发送器配置


//TEMAC模块 
temac_block #(.DEVICE (DEVICE)  // 设备类型参数
    ) trans_TEMAC (
    //全局
    .reset                (reset),                   // 复位
    .gtx_clk              (clk_125_out),            // 全局发送时钟125MHz
    .gtx_clk_90           (temac_clk90),            // 全局发送时钟90度125MHz
    
  //FIFO互传  
    //接收
    .rx_clk               (rx_clk_int),             // 接收时钟
    .rx_clk_en            (rx_clk_en_int),          // 接收时钟使能
        //数据通路 - 接收侧
    .rx_data              (rx_data),                // 接收数据
    .rx_data_valid        (rx_valid),               // 接收数据有效
    .rx_correct_frame     (rx_correct_frame),       // 正确接收帧
    .rx_error_frame       (rx_error_frame),         // 错误接收帧
    .rx_status_vector     (),                       // 接收状态向量
    .rx_status_vld        (),                       // 接收状态有效
    
    //发送
    .tx_clk               (tx_clk_int),             // 发送时钟
    .tx_clk_en            (tx_clk_en_int),          // 发送时钟使能
        //数据通路 - 发送侧
    .tx_data              (tx_data),                // 发送数据
    .tx_data_en           (tx_valid),               // 发送数据使能
        //状态
    .tx_rdy               (tx_rdy),                 // 发送就绪
    .tx_collision         (tx_collision),           // 发送冲突
    .tx_retransmit        (tx_retransmit),          // 发送重传
        //状态
    .tx_stop              (tx_stop),                // 发送停止
    .tx_ifg_val           (tx_ifg_val),             // 发送帧间隔值
    .pause_req            (pause_req),              // 暂停请求
    .pause_val            (pause_val),              // 暂停值
    .pause_source_addr    (pause_source_addr),      // 暂停源地址
    
    .tx_status_vector     (),                       // 发送状态向量
    .tx_status_vld        (),                       // 发送状态有效
    
  //PHY互传  
    //地址配置
    .unicast_address      (unicast_address),        // 单播地址
    .mac_cfg_vector       (mac_cfg_vector),         // MAC配置向量
    
    //RGMII物理接口
    .rgmii_txd            (phy1_rgmii_tx_data),     // RGMII发送数据
    .rgmii_tx_ctl         (phy1_rgmii_tx_ctl),      // RGMII发送控制
    .rgmii_txc            (phy1_rgmii_tx_clk),      // RGMII发送时钟
    .rgmii_rxd            (phy1_rgmii_rx_data),     // RGMII接收数据
    .rgmii_rx_ctl         (phy1_rgmii_rx_ctl),      // RGMII接收控制
    .rgmii_rxc            (phy1_rgmii_rx_clk_90),   // RGMII接收时钟
    
    .inband_link_status   (),                       // 带内链路状态
    .inband_clock_speed   (),                       // 带内时钟速度
    .inband_duplex_status ()                        // 带内双工状态
);


// ========================= 收发FIFO ===============================
// phi <-> mac <-> rx/tx <-> mac_rx/mac_tx(udp) 

wire               temac_tx_ready;        // TEMAC发送就绪
wire               temac_tx_valid;        // TEMAC发送有效
wire [7:0]         temac_tx_data;         // TEMAC发送数据
wire               temac_tx_sof;          // TEMAC发送帧开始
wire               temac_tx_eof;          // TEMAC发送帧结束

wire               temac_rx_ready;        // TEMAC接收就绪
wire               temac_rx_valid;        // TEMAC接收有效
wire [7:0]         temac_rx_data;         // TEMAC接收数据
wire               temac_rx_sof;          // TEMAC接收帧开始
wire               temac_rx_eof;          // TEMAC接收帧结束

tx_client_fifo #(
    .DEVICE (DEVICE)  // 设备类型参数
) trans_tx_fifo (
    .rd_clk               (tx_clk_int),         // 读时钟
    .rd_sreset            (reset),             // 读同步复位
    .rd_enable            (tx_clk_en_int),      // 读使能
    .tx_data              (tx_data),            // 发送数据
    .tx_data_valid        (tx_valid),           // 发送数据有效
    .tx_ack               (tx_rdy),             // 发送应答
    .tx_collision         (tx_collision),       // 发送冲突
    .tx_retransmit        (tx_retransmit),      // 发送重传
    .overflow             (),                   // 溢出指示
                            
    .wr_clk               (udp_clk),            // 写时钟
    .wr_sreset            (reset),             // 写同步复位
    .wr_data              (temac_tx_data),      // 写数据
    .wr_sof_n             (temac_tx_sof),       // 写帧开始（低有效）
    .wr_eof_n             (temac_tx_eof),       // 写帧结束（低有效）
    .wr_src_rdy_n         (temac_tx_valid),     // 写源就绪（低有效）
    .wr_dst_rdy_n         (temac_tx_ready),     // 写目标就绪（低有效）
    .wr_fifo_status       ()                    // 写FIFO状态
);

rx_client_fifo #(
    .DEVICE (DEVICE)  // 设备类型参数
) trans_rx_fifo (                           
    .wr_clk               (rx_clk_int),         // 写时钟
    .wr_enable            (rx_clk_en_int),      // 写使能
    .wr_sreset            (reset),             // 写同步复位
    .rx_data              (rx_data),            // 接收数据
    .rx_data_valid        (rx_valid),           // 接收数据有效
    .rx_good_frame        (rx_correct_frame),   // 接收好帧
    .rx_bad_frame         (rx_error_frame),     // 接收坏帧
    .overflow             (),                   // 溢出指示
    
    .rd_clk               (udp_clk),            // 读时钟
    .rd_sreset            (reset),             // 读同步复位
    .rd_data_out          (temac_rx_data),      // 读数据输出
    .rd_sof_n             (temac_rx_sof),       // 读帧开始（低有效）
    .rd_eof_n             (temac_rx_eof),       // 读帧结束（低有效）
    .rd_src_rdy_n         (temac_rx_valid),     // 读源就绪（低有效）
    .rd_dst_rdy_n         (temac_rx_ready),     // 读目标就绪（低有效）
    .rx_fifo_status       ()                    // 接收FIFO状态
);
// ========================= 动态IP地址配置 =========================
// 计数器0：主计数器
reg [32:0] cnt0;

always @(posedge udp_clk or negedge sys_rst_n_2) begin
    if(!sys_rst_n_2) begin
        cnt0 <= 0;
    end else if(add_cnt0) begin
        if(end_cnt0)
            cnt0 <= 0;
        else
            cnt0 <= cnt0 + 1;
    end
end

wire       add_cnt0;
assign     add_cnt0 = 1;
wire       end_cnt0;
assign     end_cnt0 = add_cnt0 && 0;

// 计数器1：IP地址变化计数器
reg [7:0]  cnt1;

always @(posedge udp_clk or negedge sys_rst_n_2) begin 
    if(!sys_rst_n_2) begin
        cnt1 <= 0;
    end else if(add_cnt1) begin
        if(end_cnt1)
            cnt1 <= 0;
        else
            cnt1 <= cnt1 + 1;
    end
end

wire       add_cnt1;
assign     add_cnt1 = end_cnt0;
wire       end_cnt1;
assign     end_cnt1 = add_cnt1 && cnt1 == 15;  

// 动态IP地址配置寄存器
reg [31:0]  input_local_ip_address;        // 输入本地IP地址
reg         input_local_ip_address_valid;  // 输入本地IP地址有效

always @(posedge udp_clk or posedge reset) begin
    if(reset) begin
        input_local_ip_address       <= LOCAL_IP_ADDRESS;
        input_local_ip_address_valid <= 1'b0;
    end else if(end_cnt0 == 1'b1) begin
        input_local_ip_address       <= {LOCAL_IP_ADDRESS[31:8], cnt1};
        input_local_ip_address_valid <= 1'b1;
    end else begin
        input_local_ip_address       <= input_local_ip_address;
        input_local_ip_address_valid <= 1'b1;
    end
end

// LED显示IP地址低4位
assign led = ~input_local_ip_address[3:0];

// 动态UDP端口配置
reg [15:0] input_local_udp_port_num;       // 输入本地UDP端口号
reg        input_local_udp_port_num_valid; // 输入本地UDP端口号有效

always @(posedge udp_clk or posedge reset) begin
    if(reset) begin
        input_local_udp_port_num       <= LOCAL_UDP_PORT_NUM;
        input_local_udp_port_num_valid <= 1'b0;
    end else begin
        input_local_udp_port_num       <= input_local_ip_address[3:0] + 3;
        input_local_udp_port_num_valid <= 1'b1;
    end
end

// UDP应用层接口信号
//wire               app_rx_data_valid;     // 应用层接收数据有效
//wire [7:0]         app_rx_data;           // 应用层接收数据
//wire [15:0]        app_rx_data_length;    // 应用层接收数据长度
//wire [15:0]        app_rx_port_num;       // 应用层接收端口号

//wire               udp_tx_ready;          // UDP发送就绪
//wire               app_tx_ack;            // 应用层发送应答
//wire               app_tx_data_request;   // 应用层发送数据请求
//wire               app_tx_data_valid;     // 应用层发送数据有效
//wire [7:0]         app_tx_data;           // 应用层发送数据
//wire [15:0]        udp_data_length;       // UDP数据长度

//UDP/IP协议栈
udp_ip_protocol_stack #(
    .DEVICE                 (DEVICE),                  // 设备类型
    .LOCAL_UDP_PORT_NUM     (LOCAL_UDP_PORT_NUM),      // 本地UDP端口号
    .LOCAL_IP_ADDRESS       (LOCAL_IP_ADDRESS),        // 本地IP地址
    .LOCAL_MAC_ADDRESS      (LOCAL_MAC_ADDRESS)        // 本地MAC地址
) 
    trans_udp_ip_stack (   
    .udp_rx_clk                 (udp_clk),                      // UDP接收时钟
    .udp_tx_clk                 (udp_clk),                      // UDP发送时钟
    .reset                      (reset),                       // 复位
    .udp2app_tx_ready           (udp_tx_ready),                // UDP到应用层发送就绪
    .udp2app_tx_ack             (app_tx_ack),                  // UDP到应用层发送应答
    .app_tx_request             (app_tx_data_request),         // 应用层发送请求
    .app_tx_data_valid          (app_tx_data_valid),           // 应用层发送数据有效
    .app_tx_data                (app_tx_data),                 // 应用层发送数据
    .app_tx_data_length         (udp_data_length),             // 应用层发送数据长度
    .app_tx_dst_port            (DST_UDP_PORT_NUM),            // 应用层发送目标端口
    .ip_tx_dst_address          (DST_IP_ADDRESS),              // IP发送目标地址
    
    // 动态配置接口
    .input_local_udp_port_num      (input_local_udp_port_num),      // 输入本地UDP端口号
    .input_local_udp_port_num_valid(input_local_udp_port_num_valid),// 输入本地UDP端口号有效
    .input_local_ip_address        (input_local_ip_address),        // 输入本地IP地址
    .input_local_ip_address_valid  (input_local_ip_address_valid),  // 输入本地IP地址有效
    
    // 应用层接收接口
    .app_rx_data_valid          (app_rx_data_valid),           // 应用层接收数据有效
    .app_rx_data                (app_rx_data),                 // 应用层接收数据
    .app_rx_data_length         (app_rx_data_length),          // 应用层接收数据长度
    .app_rx_port_num            (app_rx_port_num),             // 应用层接收端口号
    
    // TEMAC接口
    .temac_rx_ready             (temac_rx_ready),              // TEMAC接收就绪
    .temac_rx_valid             (!temac_rx_valid),             // TEMAC接收有效（取反）
    .temac_rx_data              (temac_rx_data),               // TEMAC接收数据
    .temac_rx_sof               (temac_rx_sof),                // TEMAC接收帧开始
    .temac_rx_eof               (temac_rx_eof),                // TEMAC接收帧结束
    
    .temac_tx_ready             (temac_tx_ready),              // TEMAC发送就绪
    .temac_tx_valid             (temac_tx_valid),              // TEMAC发送有效
    .temac_tx_data              (temac_tx_data),               // TEMAC发送数据
    .temac_tx_sof               (temac_tx_sof),                // TEMAC发送帧开始
    .temac_tx_eof               (temac_tx_eof),                // TEMAC发送帧结束
    
    /*
    `ifdef DEBUG_UDP
    .udp_debug_out              (udp_debug_out),               // UDP调试输出
    `endif
    */
    
    // 错误指示
    .ip_rx_error                (),                           // IP接收错误
    .arp_request_no_reply_error ()                            // ARP请求无应答错误
);

//// ========================= UDP回环模块 =========================
//udp_loopback #(
//    .DEVICE(DEVICE)  // 设备类型参数
//) u2_udp_loopback (
//    .app_rx_clk             (app_clk),              // 应用层接收时钟-
//    .app_tx_clk             (udp_clk),              // 应用层发送时钟
//    .reset                  (reset),                // 复位
//    .udp_wrusedw            (udp_wrusedw),          // UDP FIFO写使用字数-
//    `ifdef UDP_LOOP_BACK    
//    .app_rx_data            (input_data),           // 应用层接收数据（图像数据）-
//    .app_rx_data_valid      (input_vaild),          // 应用层接收数据有效-
//    .app_rx_data_length     (16'd3),                // 应用层接收数据长度
//    /*
//    `else   
//    .app_rx_data            (tpg_data),            // 应用层接收数据（测试数据）
//    .app_rx_data_valid      (tpg_data_valid),      // 应用层接收数据有效
//    .app_rx_data_length     (tpg_data_udp_length), // 应用层接收数据长度
//    */
//    `endif              
//    .full_flag              (full_flag),           // 写满标志-
//    .udp_tx_ready           (udp_tx_ready),        // UDP发送就绪
//    .app_tx_ack             (app_tx_ack),          // 应用层发送应答
//    .app_tx_data            (app_tx_data),         // 应用层发送数据
//    .app_tx_data_request    (app_tx_data_request), // 应用层发送数据请求
//    .app_tx_data_valid      (app_tx_data_valid),   // 应用层发送数据有效
//    .udp_data_length        (udp_data_length)      // UDP数据长度
//);


endmodule
