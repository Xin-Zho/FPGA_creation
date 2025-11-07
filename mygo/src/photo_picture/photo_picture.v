module photo_picture (
    // 系统时钟和复位
    input wire clk,                  // 系统时钟(50MHz)
    input wire rst_n,               // 低电平复位
    
    input wire state_trigger,       // 主控状态机发出的拍照触发信号（当状态机=2时有效）
    output reg capture_led,                                                      // 拍照状态指示灯
    
    // 与frame_read_write模块的接口
    output reg capture_req,         // 拍照请求信号
    input wire capture_ack,         // 拍照应答信号
    input wire [23:0] frame_base_addr, // 当前帧在SDRAM中的基地址
    input wire frame_valid,         // 帧数据有效信号（指示当前帧是完整的）
    output reg [23:0] capture_addr, // 要捕获的帧地址
    output reg [15:0] capture_len , // 要捕获的数据长度
    input  wire photo_done,
    
    // 图像参数
    input wire [15:0] image_width,  // 图像宽度
    input wire [15:0] image_height, // 图像高度
    
    // 以太网发送接口
    output reg eth_send_start,      // 启动以太网发送（电平信号，持续有效）
    output reg eth_send_req,        // 以太网发送请求（脉冲信号，触发一次发送）
    output reg [31:0] eth_frame_addr, // 要发送的帧地址
    output reg [15:0] eth_data_length, // 发送数据长度（字节）
    input wire eth_send_ack,        // 以太网应答（确认收到发送请求）
    input wire eth_send_busy,       // 以太网忙信号
    input wire eth_send_done,       // 发送完成信号
    
    // 反馈给主控机
    output reg photo_busy          // 模块忙信号

);

// 状态机定义（新增S_ETH_WAIT_ACK状态处理握手）
localparam [2:0]
    S_IDLE        = 3'b000,  // 空闲状态
    S_WAIT_FRAME  = 3'b001,  // 等待一个完整的有效帧
    S_CAPTURE_REQ = 3'b010,  // 发出捕获请求
    S_ETH_REQ     = 3'b011,  // 发送以太网请求并等待应答
    S_ETH_SEND    = 3'b100,  // 等待以太网发送完成
    S_DONE        = 3'b101;  // 完成

reg [2:0] current_state, next_state;

reg [23:0] timeout_counter; // 超时计数器（约0.3秒 @50MHz）
localparam TIMEOUT_MAX = 24'd15_000_000; // 超时阈值

// 捕获到的帧地址寄存器
reg [23:0] captured_frame_addr;

// 计算图像数据大小（字节数）= 宽 * 高 * 3 (RGB888每个像素3字节)
// 注意：组合逻辑不能带复位，移到时序逻辑中
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        eth_data_length <= 16'b0;
    end else begin
        eth_data_length <= image_width * image_height * 3; 
    end
end

// 状态寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= S_IDLE;
    end else begin
        current_state <= next_state;
    end
end

// capture_addr 和 capture_len 的赋值逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        capture_addr <= 24'b0;
        capture_len <= 16'b0;
    end else begin
        if (current_state == S_WAIT_FRAME) begin
            capture_addr <= 1'b1;  // 捕获当前帧地址
            capture_len <= eth_data_length;   // 捕获长度=图像大小
        end
    end
end

// 状态转移逻辑（新增S_ETH_REQ处理req/ack握手）
always @(*) begin
    next_state = current_state;
    case (current_state)
        S_IDLE: begin
            if (state_trigger) begin
                next_state = S_WAIT_FRAME;
            end
        end
        
        S_WAIT_FRAME: begin
            if (frame_valid) begin          // 检测到有效帧
                next_state = S_CAPTURE_REQ;
            end else if (timeout_counter == TIMEOUT_MAX) begin  // 超时
                next_state = S_IDLE;
            end
        end
        
        S_CAPTURE_REQ: begin
            if (capture_ack) begin          // 收到捕获应答
                next_state = S_ETH_REQ;
            end else if (timeout_counter == TIMEOUT_MAX) begin  // 超时
                next_state = S_IDLE;
            end
        end
        
        S_ETH_REQ: begin
            if (eth_send_ack) begin         // 收到以太网应答
                next_state = S_ETH_SEND;
            end else if (timeout_counter == TIMEOUT_MAX) begin  // 超时
                next_state = S_IDLE;
            end
        end
        
        S_ETH_SEND: begin
            if (eth_send_done) begin        // 发送完成
                next_state = S_DONE;
            end else if (timeout_counter == TIMEOUT_MAX) begin  // 超时
                next_state = S_IDLE;
            end
        end
        
        S_DONE: begin
            next_state = S_IDLE;            // 一次流程结束
        end
        
        default: next_state = S_IDLE;
    endcase
end

// 超时计数器逻辑（覆盖新增的S_ETH_REQ和S_ETH_SEND状态）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_counter <= 24'd0;
    end else begin
        if (current_state != next_state) begin  // 状态变化时清零
            timeout_counter <= 24'd0;
        end else if (current_state == S_WAIT_FRAME || 
                   current_state == S_CAPTURE_REQ || 
                   current_state == S_ETH_REQ || 
                   current_state == S_ETH_SEND) begin  // 需要超时监控的状态
            if (timeout_counter < TIMEOUT_MAX) begin
                timeout_counter <= timeout_counter + 1'b1;
            end
        end else begin
            timeout_counter <= 24'd0;
        end
    end
end

// 输出逻辑（重点处理eth_send_req和eth_send_ack的握手）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        capture_req <= 1'b0;
        eth_send_start <= 1'b0;
        eth_send_req <= 1'b0;
        capture_led <= 1'b0;
        captured_frame_addr <= 24'b0;
        photo_busy <= 1'b0;
        eth_frame_addr <= 32'b0;
    end else begin
        // 默认值（避免 latch）
        capture_req <= 1'b0;
        eth_send_start <= 1'b0;
        eth_send_req <= 1'b0;
        eth_frame_addr <= eth_frame_addr;  // 保持不变
        
        case (current_state)
            S_IDLE: begin
                capture_led <= 1'b0;
                photo_busy <= 1'b0;
                captured_frame_addr <= 24'b0;
            end
            
            S_WAIT_FRAME: begin
                capture_led <= 1'b1;
                photo_busy <= 1'b1;
                captured_frame_addr <= frame_base_addr;  // 锁存当前帧地址
            end
            
            S_CAPTURE_REQ: begin
                capture_led <= 1'b1;
                photo_busy <= 1'b1;
                capture_req <= 1'b1;  // 持续发出捕获请求
            end
            
            S_ETH_REQ: begin  // 发送请求并等待应答
                capture_led <= 1'b1;
                photo_busy <= 1'b1;
                eth_send_start <= 1'b1;  // 持续指示发送状态
                eth_frame_addr <= captured_frame_addr;  // 锁存发送地址
                if (!eth_send_ack) begin  // 未收到应答时，发出请求脉冲
                    eth_send_req <= 1'b1;
                end else begin
                    eth_send_req <= 1'b0;  // 收到应答后，撤销请求
                end
            end
            
            S_ETH_SEND: begin  // 等待发送完成
                capture_led <= 1'b1;
                photo_busy <= 1'b1;
                eth_send_start <= 1'b1;  // 保持发送状态
            end
            
            S_DONE: begin
                capture_led <= 1'b0;
                photo_busy <= 1'b0;
            end
            
            default: begin
                capture_led <= 1'b0;
            end
        endcase
    end
end

endmodule