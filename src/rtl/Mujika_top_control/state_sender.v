`timescale 1ns / 1ps

module state_sender(
    // 系统接口
    input           clk_50,         // 50MHz系统时钟
    input           sys_rst_n,      // 全局复位，低电平有效
    
    // 交互
    input  [1:0]    cmd_in,         // 2位命令输入
    input           cmd_valid,      // 命令有效信号（新增）
    output reg      tx_done,         // 发送完成信号
    
    
    // PHY1 RGMII接口信号
    input               phy1_rgmii_rx_clk,   // RGMII接收时钟
    input               phy1_rgmii_rx_ctl,   // RGMII接收控制
    input [3:0]         phy1_rgmii_rx_data,  // RGMII接收数据
    output wire         phy1_rgmii_tx_clk,   // RGMII发送时钟
    output wire         phy1_rgmii_tx_ctl,   // RGMII发送控制
    output wire [3:0]   phy1_rgmii_tx_data   // RGMII发送数据
);

// ========================= 内部信号定义 =========================
// 命令发送状态机
reg [2:0] state;
localparam IDLE      = 3'b000;  // 空闲状态
localparam REQUEST   = 3'b001;  // 发送请求状态
localparam SEND_CMD  = 3'b010;  // 发送命令状态
localparam WAIT_ACK  = 3'b011;  // 等待应答状态
localparam DONE      = 3'b100;  // 完成状态

// 命令寄存器
reg [1:0] cmd_reg;
reg cmd_valid_reg;              // 内部命令有效寄存器

// 发送控制信号
reg app_tx_data_request_reg;
reg app_tx_data_valid_reg;
reg [7:0] app_tx_data_reg;
reg [15:0] udp_data_length_reg;

// 以太网传输模块接口信号
wire app_rx_data_valid;
wire [7:0] app_rx_data;
wire [15:0] app_rx_data_length;
wire [15:0] app_rx_port_num;

wire udp_tx_ready;
wire app_tx_ack;

// ========================= 命令发送状态机 =========================
always @(posedge clk_50 or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        state <= IDLE;
        cmd_reg <= 2'b00;
        cmd_valid_reg <= 1'b0;
        app_tx_data_request_reg <= 1'b0;
        app_tx_data_valid_reg <= 1'b0;
        app_tx_data_reg <= 8'h00;
        udp_data_length_reg <= 16'd1;  // 只发送1个字节
        tx_done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                tx_done <= 1'b0;
                app_tx_data_request_reg <= 1'b0;
                app_tx_data_valid_reg <= 1'b0;
                
                // 检测到有效命令输入
                if (cmd_valid && !cmd_valid_reg) begin
                    cmd_reg <= cmd_in;
                    cmd_valid_reg <= 1'b1;
                    state <= REQUEST;
                end
            end
            
            REQUEST: begin
                // 等待UDP发送就绪
                if (udp_tx_ready) begin
                    app_tx_data_request_reg <= 1'b1;
                    state <= SEND_CMD;
                end
            end
            
            SEND_CMD: begin
                // 发送命令数据
                if (app_tx_ack) begin
                    app_tx_data_request_reg <= 1'b0;
                    app_tx_data_valid_reg <= 1'b1;
                    // 将2位命令转换为8位数据（低2位有效，高6位补0）
                    app_tx_data_reg <= {6'b000000, cmd_reg};
                    state <= WAIT_ACK;
                end
            end
            
            WAIT_ACK: begin
                // 数据已经发送，等待传输完成
                app_tx_data_valid_reg <= 1'b0;
                
                // 检查是否发送完成
                if (udp_tx_ready) begin
                    state <= DONE;
                end
            end
            
            DONE: begin
                tx_done <= 1'b1;
                cmd_valid_reg <= 1'b0;
                // 短暂保持完成信号后返回空闲
                #5 state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end


// ========================= 以太网传输模块实例化 =========================
ethernet_trans_control trans_ethernet (
    // 系统时钟和复位
    .clk_50              (clk_50),
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
    
    .app_tx_data_request (app_tx_data_request_reg),
    .app_tx_data_valid   (app_tx_data_valid_reg),
    .app_tx_data         (app_tx_data_reg),
    .udp_data_length     (udp_data_length_reg)
    
    // 注意：loopback信号已被注释，不需要连接
);

// ========================= 可选：接收数据处理 =========================
// 如果需要处理来自下位机的响应，可以添加以下逻辑
/*
reg [7:0] rx_data_buffer;
reg rx_data_ready;

always @(posedge clk_50 or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        rx_data_buffer <= 8'h00;
        rx_data_ready <= 1'b0;
    end else if (app_rx_data_valid) begin
        // 存储接收到的数据
        rx_data_buffer <= app_rx_data;
        rx_data_ready <= 1'b1;
    end else begin
        rx_data_ready <= 1'b0;
    end
end
*/

endmodule