module bmp_transfer_wrapper(
    // ==============================
    // 系统接口
    // ==============================
    input               sys_clk,
    input               rst_n,
    
    input  [1:0]    cmd_in,         // 2位命令输入
    input           cmd_valid,      // 命令有效信号（新增）
    
    
    // ==============================
    // 控制接口（对Mujica_top暴露）
    // ==============================
    input               start_transfer,      // 开始传输（唯一触发信号）
    output              transfer_busy,       // 传输进行中
    output              transfer_done,       // 传输完成
    output [3:0]        status_code,         // 状态码
    
    // ==============================
    // 物理层接口
    // ==============================
    input               phy1_rgmii_rx_clk,   // RGMII接收时钟
    input               phy1_rgmii_rx_ctl,   // RGMII接收控制
    input [3:0]         phy1_rgmii_rx_data,  // RGMII接收数据
    output              phy1_rgmii_tx_clk,   // RGMII发送时钟
    output              phy1_rgmii_tx_ctl,   // RGMII发送控制
    output [3:0]        phy1_rgmii_tx_data,  // RGMII发送数据
    
    // ==============================
    // SD卡接口
    // ==============================
    output              sd_ncs,
    output              sd_dclk,
    output              sd_mosi,
    input               sd_miso
);

// ==============================
// 内部信号定义
// ==============================

// UDP应用层接口信号
wire                app1_tx_data_request;
wire                app1_tx_data_valid;
wire [7:0]          app1_tx_data;
wire [15:0]         udp1_data_length;




wire                app2_tx_data_request;
wire                app2_tx_data_valid;
wire [7:0]          app2_tx_data;
wire [15:0]         udp2_data_length;




wire                app_tx_data_request;
wire                app_tx_data_valid;
wire [7:0]          app_tx_data;
wire [15:0]         udp_data_length;



assign app_tx_data_request  = cmd_valid? app2_tx_data_request    :app1_tx_data_request   ;
assign app_tx_data_valid    = cmd_valid? app2_tx_data_valid      :app1_tx_data_valid    ;
assign app_tx_data          = cmd_valid? app2_tx_data            :app1_tx_data     ;
assign udp_data_length      = cmd_valid? udp2_data_length        :udp1_data_length    ;


wire transfer_done_1 ;
wire transfer_done_2 ;
assign transfer_done      = cmd_valid? transfer_done_2:transfer_done_1;

// top状态信号
wire [3:0]          top_state_code;

// ==============================
// 完整系统实例化
// ==============================
top your_top_inst(
    .clk                        (sys_clk),
    .rst_n                      (rst_n),
    .key1                       (start_transfer),    // 直接使用start_transfer触发
    
    // UDP应用层接口
    .eth_app_tx_data_request    (app1_tx_data_request),
    .eth_app_tx_data_valid      (app1_tx_data_valid),
    .eth_app_tx_data            (app1_tx_data),
    .eth_udp_data_length        (udp1_data_length),
    .eth_udp_tx_ready           (udp_tx_ready),
    .eth_app_tx_ack             (app_tx_ack),
    
    // SD卡接口
    .sd_ncs                     (sd_ncs),
    .sd_dclk                    (sd_dclk),
    .sd_mosi                    (sd_mosi),
    .sd_miso                    (sd_miso)
);

state_sender sender_cmd(
     // 系统接口
    .clk_50          (sys_clk),         // 50MHz系统时钟输入
    .sys_rst_n       (sys_rst_n),      // 全局复位，低电平有效
    
    // 交互接口
    .cmd_in          (cmd_in),         // 2位命令输入
    .cmd_valid       (cmd_vaild),      // 命令有效信号
    .tx_done         (transfer_done_2),        // 发送完成信号输出
    
    .app_rx_data_valid   (app_rx_data_valid),
    .app_rx_data         (app_rx_data),
    .app_rx_data_length  (app_rx_data_length),
    .app_rx_port_num     (app_rx_port_num),
    
    .udp_tx_ready        (udp_tx_ready),
    .app_tx_ack          (app_tx_ack),
    
    .app_tx_data_request (app2_tx_data_request),
    .app_tx_data_valid   (app2_tx_data_valid),
    .app_tx_data         (app2_tx_data),
    .udp_data_length     (udp2_data_length)
    
    
);

// ==============================
// 以太网传输控制实例化
// ==============================
ethernet_trans_control eth_control_inst(
    // 系统时钟和复位
    .clk_50              (sys_clk),
    .sys_rst_n           (sys_rst_n),
    
    // PHY1 RGMII接口信号（连接到实际的PHY芯片）
    .phy1_rgmii_rx_clk   (phy1_rgmii_rx_clk),        // 根据实际连接
    .phy1_rgmii_rx_ctl   (phy1_rgmii_rx_ctl),        // 根据实际连接
    .phy1_rgmii_rx_data  (phy1_rgmii_rx_data),        // 根据实际连接
    .phy1_rgmii_tx_clk   (phy1_rgmii_tx_clk),            // 输出到PHY
    .phy1_rgmii_tx_ctl   (phy1_rgmii_tx_ctl),            // 输出到PHY
    .phy1_rgmii_tx_data  (phy1_rgmii_tx_data),            // 输出到PHY
    
    .led                 (),            // LED状态指示（可选）
    
    // UDP应用层接口信号 - 连接到本模块的状态机
    .app_rx_data_valid   (app_rx_data_valid),
    .app_rx_data         (app_rx_data),
    .app_rx_data_length  (app_rx_data_length),
    .app_rx_port_num     (app_rx_port_num),
    
    .udp_tx_ready        (udp_tx_ready),
    .app_tx_ack          (app_tx_ack),
    
    .app_tx_data_request (app_tx_data_request),
    .app_tx_data_valid   (app_tx_data_valid),
    .app_tx_data         (app_tx_data),
    .udp_data_length     (udp_data_length)
);

// ==============================
// 状态信号处理
// ==============================

// 状态信号转换
assign transfer_busy = (top_state_code != 4'd0);  // 非空闲表示忙
//assign transfer_done = (top_state_code == 4'd0);  // 空闲表示完成
assign status_code = top_state_code;              // 透传状态码

endmodule