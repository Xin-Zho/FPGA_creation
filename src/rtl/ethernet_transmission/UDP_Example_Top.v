`timescale 1ns / 1ps
//********************************************************************** 
// -------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>Copyright Notice<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
// ------------------------------------------------------------------- 
//             /\ --------------- 
//            /  \ ------------- 
//           / /\ \ -----------
//          / /  \ \ ---------
//         / /    \ \ ------- 
//        / /      \ \ ----- `
//       / /_ _ _   \ \ --- 
//      /_ _ _ _ _\  \_\ -
//*********************************************************************** 
// Author: suluyang 
// Email:luyang.su@anlogic.com 
// Date:2020/11/17 
// Description: 
// 2022/03/10:  修改时钟结构
//              简化约束
//              添加 soft fifo 
//              添加 debug 功能
// 2023/02/16 :add dynamic_local_ip_address port
// 
// web：www.anlogic.com 
//------------------------------------------------------------------- 
//*********************************************************************/

// UDP回环模式定义
`define UDP_LOOP_BACK
// UDP调试模式定义（注释掉表示不启用）
// `define DEBUG_UDP

module UDP_Example_Top(
    // 系统时钟和复位
    input  clk_50,           // 50MHz系统时钟
    input  sys_rst_n,        // 系统复位信号，低电平有效
    
    input [23:0] app_data_output,
    
    // SD卡接口信号
    /*
    input  sd_reset_rd,      // SD卡读取复位
    input  sd_miso,          // SD卡主输入从输出（数据输入）
    output sd_clk,           // SD卡时钟
    output sd_cs,            // SD卡片选
    output sd_mosi,          // SD卡主输出从输入（数据输出）
    */
    
    // PHY1 RGMII接口信号
    input               phy1_rgmii_rx_clk,   // RGMII接收时钟
    input               phy1_rgmii_rx_ctl,   // RGMII接收控制
    input [3:0]         phy1_rgmii_rx_data,  // RGMII接收数据
    output wire         phy1_rgmii_tx_clk,   // RGMII发送时钟
    output wire         phy1_rgmii_tx_ctl,   // RGMII发送控制
    output wire [3:0]   phy1_rgmii_tx_data,  // RGMII发送数据
    
    // LED指示灯
    output [2:0]        led                  // LED状态指示
);

// ========================= 参数定义 =========================
parameter  DEVICE             = "EG4";              // 设备类型："PH1","EG4"
parameter  LOCAL_UDP_PORT_NUM = 16'h0001;           // 本地UDP端口号
parameter  LOCAL_IP_ADDRESS   = 32'hc0a8f001;       // 本地IP地址：192.168.240.1
parameter  LOCAL_MAC_ADDRESS  = 48'h0123456789ab;   // 本地MAC地址
parameter  DST_UDP_PORT_NUM   = 16'h0002;           // 目标UDP端口号
parameter  DST_IP_ADDRESS     = 32'hc0a8f002;       // 目标IP地址：192.168.240.2

// ========================= 信号定义 =========================
// UDP应用层接口信号
wire               app_rx_data_valid;     // 应用层接收数据有效
wire [7:0]         app_rx_data;           // 应用层接收数据
wire [15:0]        app_rx_data_length;    // 应用层接收数据长度
wire [15:0]        app_rx_port_num;       // 应用层接收端口号

wire               udp_tx_ready;          // UDP发送就绪
wire               app_tx_ack;            // 应用层发送应答
wire               app_tx_data_request;   // 应用层发送数据请求
wire               app_tx_data_valid;     // 应用层发送数据有效
wire [7:0]         app_tx_data;           // 应用层发送数据
wire [15:0]        udp_data_length;       // UDP数据长度

// 测试模式生成器信号
wire  [7:0]        tpg_data;              // 测试数据
wire               tpg_data_valid;        // 测试数据有效
wire  [15:0]       tpg_data_udp_length;   // 测试数据UDP长度

// TEMAC接口信号
wire               tx_stop;               // 发送停止
wire [7:0]         tx_ifg_val;            // 发送帧间隔值
wire               pause_req;             // 暂停请求
wire [15:0]        pause_val;             // 暂停值
wire [47:0]        pause_source_addr;     // 暂停源地址
wire [47:0]        unicast_address;       // 单播地址
wire [19:0]        mac_cfg_vector;        // MAC配置向量

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

wire               rx_correct_frame;      // 正确接收帧
wire               rx_error_frame;        // 错误接收帧
wire [1:0]         TRI_speed;             // 三速以太网速度设置

// 时钟信号
wire               rx_clk_int;            // 内部接收时钟
wire               rx_clk_en_int;         // 内部接收时钟使能
wire               tx_clk_int;            // 内部发送时钟
wire               tx_clk_en_int;         // 内部发送时钟使能

wire               temac_clk;             // TEMAC时钟
wire               udp_clk;               // UDP时钟
wire               temac_clk90;           // TEMAC 90度相移时钟
wire               clk_125_out;           // 125MHz时钟输出
wire               clk_12_5_out;          // 12.5MHz时钟输出
wire               clk_1_25_out;          // 1.25MHz时钟输出

// FIFO接口信号
wire               rx_valid;              // 接收有效
wire [7:0]         rx_data;               // 接收数据
wire [7:0]         tx_data;               // 发送数据
wire               tx_valid;              // 发送有效
wire               tx_rdy;                // 发送就绪
wire               tx_collision;          // 发送冲突
wire               tx_retransmit;         // 发送重传

// 复位和时钟管理
wire               reset, reset_reg;      // 复位信号
wire               clk_50_out;            // 50MHz时钟输出
reg [7:0]          phy_reset_cnt = 'd0;   // PHY复位计数器
reg [7:0]          soft_reset_cnt = 8'hff;// 软复位计数器
reg                sys_rst_n_1, sys_rst_n_2; // 系统复位同步寄存器
wire               key2;                  // 复位按键2
assign key2 = sys_rst_n_2;

wire               locked;                // PLL锁定信号
wire               clk_50m;               // 50MHz时钟
wire               clk_50m_180deg;        // 50MHz 180度相移时钟
assign reset = ~key1 || reset_reg || (soft_reset_cnt != 'd0); // 总体复位信号

// 调试和其他信号
wire               abcdsfg;               // 调试信号
assign abcdsfg = 1;
wire               clk_sample;            // 采样时钟

// ========================= 时钟生成模块 =========================
pll_50 u_pll_50(
    .refclk     (clk_50),           // 参考时钟输入
    .reset      (!sys_rst_n_2),     // 复位输入
    .extlock    (locked),           // PLL锁定输出
    .clk0_out   (clk_50m),          // 50MHz时钟输出
    .clk1_out   (clk_50m_180deg),   // 50MHz 180度相移时钟输出
    .clk2_out   (clk_sample)        // 采样时钟输出
);

// ========================= 系统复位同步 =========================
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

// ========================= SD卡控制模块 =========================
/*
// SD卡接口信号
wire               sd_rd_start_en;        // SD卡读开始使能
wire [31:0]        sd_rd_sec_addr;        // SD卡读扇区地址
wire               sd_rd_busy;            // SD卡读忙信号
wire               sd_rd_val_en;          // SD卡读数据有效使能
wire [15:0]        sd_rd_val_data;        // SD卡读数据
wire               sd_init_done;          // SD卡初始化完成

// SD卡顶层控制模块
sd_ctrl_top t1_sd_ctrl_top(
    .clk_ref            (clk_50m),           // 参考时钟
    .clk_ref_180deg     (clk_50m_180deg),    // 180度相移参考时钟
    .rst_n              (rst_n),             // 复位信号
    // SD卡物理接口
    .sd_miso            (sd_miso),           // SD卡数据输入
    .sd_clk             (sd_clk),            // SD卡时钟
    .sd_cs              (sd_cs),             // SD卡片选
    .sd_mosi            (sd_mosi),           // SD卡数据输出
    // 用户读SD卡接口
    .rd_start_en        (sd_rd_start_en),    // 读开始使能
    .rd_sec_addr        (sd_rd_sec_addr),    // 读扇区地址
    .rd_busy            (sd_rd_busy),        // 读忙信号
    .rd_val_en          (sd_rd_val_en),      // 读数据有效使能
    .rd_val_data        (sd_rd_val_data),    // 读数据
    .sd_init_done       (sd_init_done)       // SD卡初始化完成
);
*/

// ========================= SD卡复位同步 =========================
/*
reg sd_reset_rd_d0, sd_reset_rd_d1;
always @(posedge clk_50 or negedge rst_n) begin
    if(!rst_n) begin
        sd_reset_rd_d0 <= 1'b0;
        sd_reset_rd_d1 <= 1'b0;
    end else begin
        sd_reset_rd_d0 <= sd_reset_rd;
        sd_reset_rd_d1 <= sd_reset_rd_d0;
    end
end

wire sd_reset_rd_flag;  // SD卡复位标志
assign sd_reset_rd_flag = ({sd_reset_rd_d0, sd_reset_rd_d1} == 2'b10) ? 1'b0 : 1'b1;
*/

// ========================= SDRAM控制模块 =========================
/*
wire               Sdr_init_done;         // SDRAM初始化完成
wire               full_flag_sdr;         // SDRAM写满标志

// SD卡图片读取模块
sd_read_photo t2_sd_read_photo(
    .clk                (clk_50m),           // 时钟
    .rst_n              (rst_n & Sdr_init_done & sd_init_done & sd_reset_rd_flag), // 复位
    .ddr_max_addr       (24'd307200),        // DDR最大地址
    .sd_sec_num         (16'd1801),          // SD卡扇区数
    .rd_busy            (sd_rd_busy),        // 读忙信号
    .sd_rd_val_en       (sd_rd_val_en),      // SD卡读数据有效
    .sd_rd_val_data     (sd_rd_val_data),    // SD卡读数据
    .rd_start_en        (sd_rd_start_en),    // 读开始使能
    .rd_sec_addr        (sd_rd_sec_addr),    // 读扇区地址
    .sdr_wr_en          (sdr_wr_en),         // SDRAM写使能
    .sdr_wr_data        (sdr_wr_data),       // SDRAM写数据
    .full_flag_sdr      (full_flag_sdr)      // SDRAM写满标志
);

// SDRAM接口信号
wire               Sdr_rd_en;             // SDRAM读使能
wire [23:0]        Sdr_rd_dout;           // SDRAM读数据
wire               sdr_clk;               // SDRAM时钟
wire               full_flag;             // 写满标志
wire [11:0]        udp_wrusedw;           // UDP FIFO写使用字数

// SDRAM顶层模块
sdram_top t3_sdram (
    .SYS_CLK            (clk_50m),           // 系统时钟
    .sdr_data_valid     (sdr_wr_en),         // SDRAM数据有效
    .sdr_data           (sdr_wr_data),       // SDRAM数据
    .rst_n              (rst_n & sd_reset_rd_flag), // 复位
    .sdr_clk            (sdr_clk),           // SDRAM时钟
    .Sdr_rd_en          (Sdr_rd_en),         // SDRAM读使能
    .Sdr_rd_dout        (Sdr_rd_dout),       // SDRAM读数据
    .Sdr_init_done      (Sdr_init_done),     // SDRAM初始化完成
    .full_flag          (full_flag),         // 写满标志
    .full_flag_sdr      (full_flag_sdr),     // SDRAM写满标志
    .udp_wrusedw        (udp_wrusedw)        // UDP FIFO写使用字数
);
*/

// ========================= PHY复位控制 =========================
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

// ========================= 软复位控制 =========================
always @(posedge udp_clk or negedge key1) begin
    if(~key1)
        soft_reset_cnt <= 8'hff;
    else if(soft_reset_cnt > 0)
        soft_reset_cnt <= soft_reset_cnt - 1;
    else
        soft_reset_cnt <= soft_reset_cnt;
end

// ========================= 调试模块 =========================
/*
`ifdef DEBUG_UDP
// 调试信号定义
reg       debug_app_rx_data_valid;    // 调试应用层接收数据有效
reg [7:0] debug_app_rx_data;          // 调试应用层接收数据
reg       debug_app_tx_data_valid;    // 调试应用层发送数据有效
reg [7:0] debug_app_tx_data;          // 调试应用层发送数据
reg       debug_temac_tx_valid;       // 调试TEMAC发送有效
reg [7:0] debug_temac_tx_data;        // 调试TEMAC发送数据
reg       debug_temac_rx_valid;       // 调试TEMAC接收有效
reg [7:0] debug_temac_rx_data;        // 调试TEMAC接收数据
reg       debug_rx_valid;             // 调试接收有效
reg [7:0] debug_rx_data;              // 调试接收数据
reg       debug_tx_valid;             // 调试发送有效
reg [7:0] debug_tx_data;              // 调试发送数据

// 调试帧计数器
reg [31:0] debug_frame_temac_cnt_rx;  // TEMAC接收帧计数
reg [31:0] debug_frame_app_cnt_rx;    // 应用层接收帧计数
reg [31:0] debug_frame_fifo_cnt_rx;   // FIFO接收帧计数
reg [31:0] debug_frame_temac_cnt_tx;  // TEMAC发送帧计数
reg [31:0] debug_frame_app_cnt_tx;    // 应用层发送帧计数
reg [31:0] debug_frame_fifo_cnt_tx;   // FIFO发送帧计数

wire udp_debug_out;  // UDP调试输出

// 调试信号同步寄存器
reg       debug_0, debug_0_d;
reg [7:0] debug_1, debug_1_d;
reg       debug_2, debug_2_d;
reg [7:0] debug_3, debug_3_d;
reg       debug_4, debug_4_d;
reg [7:0] debug_5, debug_5_d;
reg       debug_6, debug_6_d;
reg [7:0] debug_7, debug_7_d;
reg       debug_8, debug_8_d;
reg [7:0] debug_9, debug_9_d;
reg       debug_a, debug_a_d;
reg [7:0] debug_b, debug_b_d;

// 调试信号赋值
always @(posedge temac_clk or negedge key1) begin
    if(~key1) begin
        debug_0 <= 'd0; debug_1 <= 'd0; debug_2 <= 'd0; debug_3 <= 'd0;
        debug_4 <= 'd0; debug_5 <= 'd0; debug_6 <= 'd0; debug_7 <= 'd0;
        debug_8 <= 'd0; debug_9 <= 'd0; debug_a <= 'd0; debug_b <= 'd0;
    end else begin
        debug_0 <= app_rx_data_valid;   debug_1 <= app_rx_data;
        debug_2 <= app_tx_data_valid;   debug_3 <= app_tx_data;
        debug_4 <= !temac_tx_valid;     debug_5 <= temac_tx_data;
        debug_6 <= !temac_rx_valid;     debug_7 <= temac_rx_data;
        debug_8 <= rx_valid;            debug_9 <= rx_data;
        debug_a <= tx_valid;            debug_b <= tx_data;
    end
end

// 调试信号延迟
always @(posedge temac_clk or negedge key1) begin
    if(~key1) begin
        debug_0_d <= 'd0; debug_1_d <= 'd0; debug_2_d <= 'd0; debug_3_d <= 'd0;
        debug_4_d <= 'd0; debug_5_d <= 'd0; debug_6_d <= 'd0; debug_7_d <= 'd0;
        debug_8_d <= 'd0; debug_9_d <= 'd0; debug_a_d <= 'd0; debug_b_d <= 'd0;
    end else begin
        debug_0_d <= debug_0; debug_1_d <= debug_1; debug_2_d <= debug_2; debug_3_d <= debug_3;
        debug_4_d <= debug_4; debug_5_d <= debug_5; debug_6_d <= debug_6; debug_7_d <= debug_7;
        debug_8_d <= debug_8; debug_9_d <= debug_9; debug_a_d <= debug_a; debug_b_d <= debug_b;
    end
end

// 调试信号输出
always @(posedge temac_clk or negedge key1) begin
    if(~key1) begin
        debug_app_rx_data_valid <= 'd0; debug_app_rx_data <= 'd0;
        debug_app_tx_data_valid <= 'd0; debug_app_tx_data <= 'd0;
        debug_temac_tx_valid    <= 'd0; debug_temac_tx_data <= 'd0;
        debug_temac_rx_valid    <= 'd0; debug_temac_rx_data <= 'd0;
        debug_rx_valid          <= 'd0; debug_rx_data <= 'd0;
        debug_tx_valid          <= 'd0; debug_tx_data <= 'd0;
    end else begin
        debug_app_rx_data_valid <= debug_0_d; debug_app_rx_data <= debug_1_d;
        debug_app_tx_data_valid <= debug_2_d; debug_app_tx_data <= debug_3_d;
        debug_temac_tx_valid    <= debug_4_d; debug_temac_tx_data <= debug_5_d;
        debug_temac_rx_valid    <= debug_6_d; debug_temac_rx_data <= debug_7_d;
        debug_rx_valid          <= debug_8_d; debug_rx_data <= debug_9_d;
        debug_tx_valid          <= debug_a_d; debug_tx_data <= debug_b_d;
    end
end

// 帧计数器逻辑
always @(posedge temac_clk or negedge key1) begin
    if(~key1) begin
        debug_frame_fifo_cnt_rx <= 'd0;
    end else if(!debug_6_d && debug_6) begin
        debug_frame_fifo_cnt_rx <= debug_frame_fifo_cnt_rx + 'd1;
    end else begin
        debug_frame_fifo_cnt_rx <= debug_frame_fifo_cnt_rx;
    end
end

// 其他帧计数器类似...
`endif
*/


// ========================= 参数配置逻辑 =========================
// 三速以太网速度设置：千兆2'b10 百兆2'b01 十兆2'b00
assign TRI_speed = 2'b10;

// TEMAC配置信号
assign tx_stop           = 1'b0;           // 发送停止控制
assign tx_ifg_val        = 8'h00;          // 发送帧间隔值
assign pause_req         = 1'b0;           // 暂停请求
assign pause_val         = 16'h0;          // 暂停值
assign pause_source_addr = 48'h5af1f2f3f4f5; // 暂停源地址

// MAC地址格式转换（字节序调整）
assign unicast_address   = {   
    LOCAL_MAC_ADDRESS[7:0],
    LOCAL_MAC_ADDRESS[15:8],
    LOCAL_MAC_ADDRESS[23:16],
    LOCAL_MAC_ADDRESS[31:24],
    LOCAL_MAC_ADDRESS[39:32],
    LOCAL_MAC_ADDRESS[47:40]
};

// MAC配置向量：地址过滤模式、流控配置、速度配置、接收器配置、发送器配置
assign mac_cfg_vector = {1'b0, 2'b00, TRI_speed, 8'b00000010, 7'b0000010};

// ========================= 动态IP地址配置 =========================
// 计数器定义
reg [32:0] cnt0;
wire       end_cnt0;
wire       add_cnt0;
reg [7:0]  cnt1;
wire       end_cnt1;
wire       add_cnt1;

// 计数器0：主计数器
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
assign add_cnt0 = 1;
assign end_cnt0 = add_cnt0 && 0;

// 计数器1：IP地址变化计数器
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
assign add_cnt1 = end_cnt0;
assign end_cnt1 = add_cnt1 && cnt1 == 15;  

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

// ========================= 时钟生成和复位模块 =========================
clk_gen_rst_gen #(
    .DEVICE (DEVICE)  // 设备类型参数
) u_clk_gen (
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

// ========================= 测试模式生成器 =========================
/*
udp_data_tpg u1_udp_data_tpg(
    .clk                    (udp_clk),              // 时钟
    .reset                  (~key2),               // 复位
    .tpg_data               (tpg_data),            // 测试数据输出
    .tpg_data_valid         (tpg_data_valid),      // 测试数据有效
    .tpg_data_udp_length    (tpg_data_udp_length), // 测试数据UDP长度
    .tpg_data_done          (tpg_data_done),       // 测试数据完成
    .tpg_data_enable        (phy_reset),           // 测试数据使能
    .tpg_data_header0       (16'haabb),            // 帧头0
    .tpg_data_header1       (16'hccdd),            // 帧头1
    .tpg_data_type          (16'ha8b8),            // 数据帧类型
    .tpg_data_length        (16'h00ff),            // 数据长度
    .tpg_data_num           (16'h000a),            // 产生的帧个数
    .tpg_data_ifg           (8'd130)               // 帧间隔
);

// RGB转灰度计算（注释掉的版本）
// assign image_data = (Sdr_rd_dout[23:16] * 76 + Sdr_rd_dout[23:16] * 150 + Sdr_rd_dout[7:0] * 30) >> 8;
*/



// ========================= 输入数据处理 =========================
wire [23:0] input_data;  // 输入数据

assign input_data = app_data_output[23:0];  // 直接使用RGB数据

// ========================= UDP回环模块 =========================
udp_loopback #(
    .DEVICE(DEVICE)  // 设备类型参数
) u2_udp_loopback (
    .app_rx_clk             (sdr_clk),              // 应用层接收时钟
    .app_tx_clk             (udp_clk),              // 应用层发送时钟
    .reset                  (reset),               // 复位
    .udp_wrusedw            (udp_wrusedw),         // UDP FIFO写使用字数
    `ifdef UDP_LOOP_BACK    
    .app_rx_data            (input_data),          // 应用层接收数据（图像数据）
    .app_rx_data_valid      (Sdr_rd_en),           // 应用层接收数据有效
    .app_rx_data_length     (16'd3),               // 应用层接收数据长度
    `else   
    .app_rx_data            (tpg_data),            // 应用层接收数据（测试数据）
    .app_rx_data_valid      (tpg_data_valid),      // 应用层接收数据有效
    .app_rx_data_length     (tpg_data_udp_length), // 应用层接收数据长度
    `endif              
    .full_flag              (full_flag),           // 写满标志
    .udp_tx_ready           (udp_tx_ready),        // UDP发送就绪
    .app_tx_ack             (app_tx_ack),          // 应用层发送应答
    .app_tx_data            (app_tx_data),         // 应用层发送数据
    .app_tx_data_request    (app_tx_data_request), // 应用层发送数据请求
    .app_tx_data_valid      (app_tx_data_valid),   // 应用层发送数据有效
    .udp_data_length        (udp_data_length)      // UDP数据长度
);

// ========================= UDP/IP协议栈 =========================
udp_ip_protocol_stack #(
    .DEVICE                 (DEVICE),                  // 设备类型
    .LOCAL_UDP_PORT_NUM     (LOCAL_UDP_PORT_NUM),      // 本地UDP端口号
    .LOCAL_IP_ADDRESS       (LOCAL_IP_ADDRESS),        // 本地IP地址
    .LOCAL_MAC_ADDRESS      (LOCAL_MAC_ADDRESS)        // 本地MAC地址
) u3_udp_ip_protocol_stack (   
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
    
    `ifdef DEBUG_UDP
    .udp_debug_out              (udp_debug_out),               // UDP调试输出
    `endif
    
    // 错误指示
    .ip_rx_error                (),                           // IP接收错误
    .arp_request_no_reply_error ()                            // ARP请求无应答错误
);

// ========================= RGMII接收时钟PLL =========================
wire phy1_rgmii_rx_clk_0;   // RGMII接收时钟0度
wire phy1_rgmii_rx_clk_90;  // RGMII接收时钟90度

rx_pll u_rx_pll(
    .refclk     (phy1_rgmii_rx_clk),  // 参考时钟
    .reset      (1'b0),               // 复位
    .clk0_out   (phy1_rgmii_rx_clk_0), // 0度时钟输出
    .clk1_out   (phy1_rgmii_rx_clk_90) // 90度时钟输出
);

// ========================= TEMAC模块 =========================
temac_block #(
    .DEVICE (DEVICE)  // 设备类型参数
) u4_trimac_block (
    .reset                (reset),                   // 复位
    .gtx_clk              (clk_125_out),            // 全局发送时钟125MHz
    .gtx_clk_90           (temac_clk90),            // 全局发送时钟90度125MHz
    .rx_clk               (rx_clk_int),             // 接收时钟
    .rx_clk_en            (rx_clk_en_int),          // 接收时钟使能
    .rx_data              (rx_data),                // 接收数据
    .rx_data_valid        (rx_valid),               // 接收数据有效
    .rx_correct_frame     (rx_correct_frame),       // 正确接收帧
    .rx_error_frame       (rx_error_frame),         // 错误接收帧
    .rx_status_vector     (),                       // 接收状态向量
    .rx_status_vld        (),                       // 接收状态有效
    .tx_clk               (tx_clk_int),             // 发送时钟
    .tx_clk_en            (tx_clk_en_int),          // 发送时钟使能
    .tx_data              (tx_data),                // 发送数据
    .tx_data_en           (tx_valid),               // 发送数据使能
    .tx_rdy               (tx_rdy),                 // 发送就绪
    .tx_stop              (tx_stop),                // 发送停止
    .tx_collision         (tx_collision),           // 发送冲突
    .tx_retransmit        (tx_retransmit),          // 发送重传
    .tx_ifg_val           (tx_ifg_val),             // 发送帧间隔值
    .tx_status_vector     (),                       // 发送状态向量
    .tx_status_vld        (),                       // 发送状态有效
    .pause_req            (pause_req),              // 暂停请求
    .pause_val            (pause_val),              // 暂停值
    .pause_source_addr    (pause_source_addr),      // 暂停源地址
    .unicast_address      (unicast_address),        // 单播地址
    .mac_cfg_vector       (mac_cfg_vector),         // MAC配置向量
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

// ========================= UDP时钟生成 =========================
udp_clk_gen #(
    .DEVICE (DEVICE)  // 设备类型参数
) u5_temac_clk_gen (           
    .reset                (~key1),          // 复位
    .tri_speed            (TRI_speed),      // 三速设置
    .clk_125_in           (clk_125_out),    // 125MHz时钟输入
    .clk_12_5_in          (clk_12_5_out),   // 12.5MHz时钟输入
    .clk_1_25_in          (clk_1_25_out),   // 1.25MHz时钟输入
    .udp_clk_out          (udp_clk)         // UDP时钟输出
);

// ========================= 发送客户端FIFO =========================
tx_client_fifo #(
    .DEVICE (DEVICE)  // 设备类型参数
) u6_tx_fifo (
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

// ========================= 接收客户端FIFO =========================
rx_client_fifo #(
    .DEVICE (DEVICE)  // 设备类型参数
) u7_rx_fifo (                           
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

endmodule