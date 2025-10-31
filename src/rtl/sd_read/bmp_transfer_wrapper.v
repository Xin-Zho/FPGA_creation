module bmp_transfer_wrapper(
    // ==============================
    // 系统接口
    // ==============================
    input               sys_clk,
    input               rst_n,
    
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
wire                app_tx_data_request;
wire                app_tx_data_valid;
wire [7:0]          app_tx_data;
wire [15:0]         udp_data_length;
wire                udp_tx_ready;
wire                app_tx_ack;

// 您的top状态信号
wire [3:0]          top_state_code;

// ==============================
// 您的完整系统实例化
// ==============================
top your_top_inst(
    .clk                        (sys_clk),
    .rst_n                      (rst_n),
    .key1                       (start_transfer),    // 直接使用start_transfer触发
    
    // UDP应用层接口
    .eth_app_tx_data_request    (app_tx_data_request),
    .eth_app_tx_data_valid      (app_tx_data_valid),
    .eth_app_tx_data            (app_tx_data),
    .eth_udp_data_length        (udp_data_length),
    .eth_udp_tx_ready           (udp_tx_ready),
    .eth_app_tx_ack             (app_tx_ack),
    
    // SD卡接口
    .sd_ncs                     (sd_ncs),
    .sd_dclk                    (sd_dclk),
    .sd_mosi                    (sd_mosi),
    .sd_miso                    (sd_miso)
);

// ==============================
// 以太网传输控制实例化
// ==============================
ethernet_trans_control eth_control_inst(
    .clk_50                     (sys_clk),
    .sys_rst_n                  (rst_n),
    
    // PHY物理接口
    .phy1_rgmii_rx_clk          (phy1_rgmii_rx_clk),
    .phy1_rgmii_rx_ctl          (phy1_rgmii_rx_ctl),
    .phy1_rgmii_rx_data         (phy1_rgmii_rx_data),
    .phy1_rgmii_tx_clk          (phy1_rgmii_tx_clk),
    .phy1_rgmii_tx_ctl          (phy1_rgmii_tx_ctl),
    .phy1_rgmii_tx_data         (phy1_rgmii_tx_data),
    
    // UDP应用层接口（连接您的top）
    .app_tx_data_request        (app_tx_data_request),
    .app_tx_data_valid          (app_tx_data_valid),
    .app_tx_data                (app_tx_data),
    .udp_data_length            (udp_data_length),
    .udp_tx_ready               (udp_tx_ready),
    .app_tx_ack                 (app_tx_ack),
    
    // 接收接口（悬空，因为只发送）
    .app_rx_data_valid          (),
    .app_rx_data                (),
    .app_rx_data_length         (),
    .app_rx_port_num            (),
    
    .led                        ()  // LED状态指示（可选）
);

// ==============================
// 状态信号处理
// ==============================

// 状态信号转换
assign transfer_busy = (top_state_code != 4'd0);  // 非空闲表示忙
assign transfer_done = (top_state_code == 4'd0);  // 空闲表示完成
assign status_code = top_state_code;              // 透传状态码

endmodule