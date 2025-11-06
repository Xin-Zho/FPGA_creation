//`timescale 1ns / 1ps

module state_sender(
    // 系统接口
    input           clk_50,         // 50MHz系统时钟
    input           sys_rst_n,      // 全局复位，低电平有效
    
    // 交互
    input  [1:0]    cmd_in,         // 2位命令输入
    input           cmd_valid,      // 命令有效信号（新增）
    output reg      tx_done,        // 发送完成信号
    
    input               app_rx_data_valid,     // 应用层接收数据有效
    input [7:0]         app_rx_data,           // 应用层接收数据
    input [15:0]        app_rx_data_length,    // 应用层接收数据长度
    input [15:0]        app_rx_port_num,       // 应用层接收端口号
    
    input               udp_tx_ready,          // UDP发送就绪
    input               app_tx_ack,            // 应用层发送应答

    output               app_tx_data_request,   // 应用层发送数据请求
    output               app_tx_data_valid,     // 应用层发送数据有效
    output [7:0]         app_tx_data,           // 应用层发送数据
    output [15:0]        udp_data_length        // UDP数据长度

    
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
assign app_tx_data_request = app_tx_data_request_reg;

reg app_tx_data_valid_reg;
assign app_tx_data_valid = app_tx_data_valid_reg;

reg [7:0] app_tx_data_reg;
assign  app_tx_data = app_tx_data_reg;

reg [15:0] udp_data_length_reg;
assign  udp_data_length = udp_data_length_reg;


// 以太网传输模块接口信号

// ========================= 命令发送状态机 =========================
// state_sender 模块中新增延时计数器
reg [15:0] ack_timeout_cnt;  // 8位计数器，最大延时255个时钟周期（足够UDP发送1字节）
localparam ACK_TIMEOUT_MAX = 16'd60000;  // 1.2ms超时（可根据实际调整）

reg [15:0] udp_timeout_cnt;  // 8位计数器，最大延时255个时钟周期（足够UDP发送1字节）
localparam UDP_TIMEOUT_MAX = 16'd60000;  // 1.2ms超时（可根据实际调整）

reg [2:0] data_hold_cnt;

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
                ack_timeout_cnt <= 16'd0;  // 清零超时计数器
                
                // 检测到新的有效命令（边沿检测，避免重复触发）
                if (cmd_valid && !cmd_valid_reg) begin
                    cmd_reg <= cmd_in;
                    cmd_valid_reg <= 1'b1;
                    state <= REQUEST;
                end
            end
            
            REQUEST: begin
                // 超时计数器累加
                udp_timeout_cnt <= udp_timeout_cnt + 1'b1;
                
                // 等待UDP发送就绪，就绪后发起数据请求
                if (udp_tx_ready || udp_timeout_cnt >= UDP_TIMEOUT_MAX) begin
                    udp_timeout_cnt <= 16'b0;
                    app_tx_data_request_reg <= 1'b1;  // 向应用层请求发送数据
                    state <= SEND_CMD;                // 直接进入发送命令状态
                end
            end
            
            SEND_CMD: begin
                app_tx_data_valid_reg <= 1'b1;
                app_tx_data_reg <= {6'b000000, cmd_reg};
                app_tx_data_request_reg <= 1'b0;
                
                // 保持数据有效至少几个周期
                if (data_hold_cnt >= 3'd3) begin
                    state <= WAIT_ACK;
                end else begin
                    data_hold_cnt <= data_hold_cnt + 1'b1;
                end
           end
            
            WAIT_ACK: begin
                // 超时计数器累加
                ack_timeout_cnt <= ack_timeout_cnt + 1'b1;
                
                
                // 两种情况退出WAIT_ACK：1)收到ack 2)超时
                if (app_tx_ack || ack_timeout_cnt >= ACK_TIMEOUT_MAX) begin
                    app_tx_data_valid_reg <= 1'b0;  // 关闭数据有效信号
                    ack_timeout_cnt <= 16'd0;       // 清零超时计数器
                     state <= DONE;                  // 进入完成状态
                end
                
               
            end
            
            DONE: begin
                tx_done <= 1'b1;             // 置位发送完成信号
                            
                cmd_valid_reg <= 1'b0;       // 清除命令有效标记
                state <= IDLE;               // 返回空闲状态，等待下一个命令
            
            end
            
            default: state <= IDLE;
        endcase
    end
end


// ========================= 以太网传输模块实例化 =========================

    // 注意：loopback信号已被注释，不需要连接

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