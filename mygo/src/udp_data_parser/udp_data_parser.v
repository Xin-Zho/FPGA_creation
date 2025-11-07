module udp_data_parser (
    // 系统时钟和复位
    input               clk,                    // 系统时钟
    input               rst_n,                  // 异步复位，低电平有效
    
    // UDP接收接口（来自以太网模块）
    input               udp_rx_valid,          // UDP数据有效
    input [7:0]         udp_rx_data,           // UDP数据字节
    input [15:0]        udp_rx_length,         // UDP数据包长度

    
    // 主控模块接口（指令输出）
    output reg          cmd_valid,             // 指令有效信号
    output reg [7:0]    cmd_data,              // 指令数据（1字节）
    
    // SDRAM写入接口（图片数据输出）
    output reg          sdram_wr_en,           // SDRAM写使能
    output reg [7:0]    sdram_wr_data,         // SDRAM写数据
    output reg [23:0]   sdram_wr_addr,         // SDRAM写地址
    output reg          image_start,           // 图片开始标志
    output reg          image_end,             // 图片结束标志
    output reg [15:0]   image_data_count,      // 图片数据计数器
    
    // 状态指示
    output reg [2:0]    parser_state,          // 解析器状态
    output reg          is_image_packet        // 当前包是否为图片包
);

// 状态定义
localparam STATE_IDLE        = 3'd0;  //000 空闲状态
localparam STATE_HEADER      = 3'd1;  //001 解析包头
localparam STATE_CMD         = 3'd2;  //010 处理指令数据
localparam STATE_IMG_HEADER  = 3'd3;  //011 解析图片包头
localparam STATE_IMG_DATA    = 3'd4;  //100 处理图片数据
localparam STATE_WAIT_END    = 3'd5;  //101 等待包结束

// 包头定义
localparam MAGIC_NUMBER    = 16'h55AA;  // 魔数标识
localparam PKT_TYPE_CMD    = 8'h01;     // 指令包类型
localparam PKT_TYPE_IMG    = 8'h02;     // 图片包类型

// 包头结构寄存器 - 添加下一状态版本
reg [15:0] packet_magic, next_packet_magic;     // 魔数
reg [7:0]  packet_type, next_packet_type;       // 包类型
reg [15:0] packet_seq, next_packet_seq;         // 序列号
reg [15:0] packet_total, next_packet_total;     // 总包数
reg [15:0] packet_data_len, next_packet_data_len; // 数据长度

// 状态寄存器
reg [2:0] current_state, next_state;
reg [3:0] header_counter, next_header_counter;   // 包头字节计数器
reg [15:0] data_counter, next_data_counter;      // 数据字节计数器
reg [23:0] current_sdram_addr, next_sdram_addr;  // 当前SDRAM写地址

// 下一状态输出信号
reg next_cmd_valid;
reg [7:0] next_cmd_data;
reg next_sdram_wr_en;
reg [7:0] next_sdram_wr_data;
reg [23:0] next_sdram_wr_addr;
reg next_image_start;
reg next_image_end;
reg [15:0] next_image_data_count;
reg next_is_image_packet;

// ============================================================================
// [1] 时序逻辑部分：寄存器更新
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // [复位初始化] 系统启动或复位时的初始状态
        current_state <= STATE_IDLE;
        header_counter <= 4'b0;
        data_counter <= 16'b0;
        current_sdram_addr <= 24'h000000;
        
        // [包头寄存器复位]
        packet_magic <= 16'h0000;
        packet_type <= 8'h00;
        packet_seq <= 16'h0000;
        packet_total <= 16'h0000;
        packet_data_len <= 16'h0000;
        
        // [输出信号复位]
        cmd_valid <= 1'b0;
        cmd_data <= 8'h00;
        sdram_wr_en <= 1'b0;
        sdram_wr_data <= 8'h00;
        sdram_wr_addr <= 24'h000000;
        image_start <= 1'b0;
        image_end <= 1'b0;
        image_data_count <= 16'b0;
        is_image_packet <= 1'b0;
        parser_state <= STATE_IDLE;
    end else begin
        // [正常工作时序更新]
        current_state <= next_state;
        header_counter <= next_header_counter;
        data_counter <= next_data_counter;
        current_sdram_addr <= next_sdram_addr;
        
        // [包头寄存器更新]
        packet_magic <= next_packet_magic;
        packet_type <= next_packet_type;
        packet_seq <= next_packet_seq;
        packet_total <= next_packet_total;
        packet_data_len <= next_packet_data_len;
        
        // [输出寄存器更新]
        cmd_valid <= next_cmd_valid;
        cmd_data <= next_cmd_data;
        sdram_wr_en <= next_sdram_wr_en;
        sdram_wr_data <= next_sdram_wr_data;
        sdram_wr_addr <= next_sdram_wr_addr;
        image_start <= next_image_start;
        image_end <= next_image_end;
        image_data_count <= next_image_data_count;
        is_image_packet <= next_is_image_packet;
        parser_state <= current_state;  // 输出当前状态用于调试
    end
end

// ============================================================================
// [2] 组合逻辑部分：下一状态和输出计算
// ============================================================================
always @(*) begin
    // ==========================================
    // [默认值设置] 防止锁存器生成
    // ==========================================
    next_state = current_state;
    next_header_counter = header_counter;
    next_data_counter = data_counter;
    next_sdram_addr = current_sdram_addr;
    
    // [包头寄存器默认值]
    next_packet_magic = packet_magic;
    next_packet_type = packet_type;
    next_packet_seq = packet_seq;
    next_packet_total = packet_total;
    next_packet_data_len = packet_data_len;
    
    // [输出信号默认值]
    next_cmd_valid = 1'b0;
    next_cmd_data = cmd_data;
    next_sdram_wr_en = 1'b0;
    next_sdram_wr_data = sdram_wr_data;
    next_sdram_wr_addr = sdram_wr_addr;
    next_image_start = 1'b0;
    next_image_end = 1'b0;
    next_image_data_count = image_data_count;
    next_is_image_packet = is_image_packet;
    
    // ==========================================
    // [状态机核心逻辑]
    // ==========================================
    case (current_state)
        // ======================================
        // 状态：STATE_IDLE - 空闲等待
        // ======================================
        STATE_IDLE: begin
            next_header_counter = 4'b0;
            next_data_counter = 16'b0;
            next_is_image_packet = 1'b0;
            
            // [复位包头寄存器]
            next_packet_magic = 16'h0000;
            next_packet_type = 8'h00;
            next_packet_seq = 16'h0000;
            next_packet_total = 16'h0000;
            next_packet_data_len = 16'h0000;
            
            if (udp_rx_valid) begin
                next_state = STATE_HEADER;
            end
        end
        
        // ======================================
        // 状态：STATE_HEADER - 解析包头
        // ======================================
        STATE_HEADER: begin
            if (udp_rx_valid) begin
                if (header_counter < 9) begin
                    next_header_counter = header_counter + 4'b1;
                    
                    // [修正] 使用下一状态寄存器而不是直接赋值
                    case (header_counter)
                        4'd0: next_packet_magic[15:8] = udp_rx_data;  // 魔数高字节
                        4'd1: next_packet_magic[7:0]  = udp_rx_data;  // 魔数低字节
                        4'd2: next_packet_type = udp_rx_data;         // 包类型
                        4'd3: next_packet_seq[15:8] = udp_rx_data;    // 序列号高字节
                        4'd4: next_packet_seq[7:0]  = udp_rx_data;    // 序列号低字节
                        4'd5: next_packet_total[15:8] = udp_rx_data;  // 总包数高字节
                        4'd6: next_packet_total[7:0]  = udp_rx_data;  // 总包数低字节
                        4'd7: next_packet_data_len[15:8] = udp_rx_data; // 数据长度高字节
                        4'd8: begin
                            next_packet_data_len[7:0] = udp_rx_data;  // 数据长度低字节
                            next_header_counter = 4'b0;
                            
                            // [包头验证] - 使用下一状态寄存器
                            if (next_packet_magic == MAGIC_NUMBER) begin
                                if (next_packet_type == PKT_TYPE_CMD) begin
                                    next_state = STATE_CMD;
                                    next_is_image_packet = 1'b0;
                                end else if (next_packet_type == PKT_TYPE_IMG) begin
                                    next_state = STATE_IMG_HEADER;
                                    next_is_image_packet = 1'b1;
                                    next_image_start = (next_packet_seq == 0);
                                    next_image_end = (next_packet_seq == next_packet_total - 1);
                                end else begin
                                    next_state = STATE_WAIT_END;  // 未知包类型
                                end
                            end else begin
                                next_state = STATE_WAIT_END;      // 魔数错误
                            end
                        end
                    endcase
                end
            end
        end
        
        // ======================================
        // 状态：STATE_CMD - 处理指令数据
        // ======================================
        STATE_CMD: begin
            if (udp_rx_valid) begin
                if (data_counter < packet_data_len) begin
                    if (data_counter == 0) begin
                        next_cmd_valid = 1'b1;
                        next_cmd_data = udp_rx_data;
                    end
                    next_data_counter = data_counter + 16'b1;
                end else begin
                    next_cmd_valid = 1'b0;
                    next_state = STATE_IDLE;
                end
            end
        end
        
        // ======================================
        // 状态：STATE_IMG_HEADER - 解析图片包头
        // ======================================
        STATE_IMG_HEADER: begin
            if (udp_rx_valid) begin
                if (data_counter < 4) begin  // 假设图片头4字节
                    // 这里可以解析图片特有的头部信息
                    next_data_counter = data_counter + 16'b1;
                end else begin
                    next_data_counter = 16'b0;
                    next_state = STATE_IMG_DATA;
                end
            end
        end
        
        // ======================================
        // 状态：STATE_IMG_DATA - 处理图片数据
        // ======================================
        STATE_IMG_DATA: begin
            if (udp_rx_valid) begin
                if (data_counter < (packet_data_len - 4)) begin  // 减去图片头4字节
                    next_sdram_wr_en = 1'b1;
                    next_sdram_wr_data = udp_rx_data;
                    next_sdram_wr_addr = current_sdram_addr;
                    next_image_data_count = data_counter;
                    
                    next_sdram_addr = current_sdram_addr + 24'b1;
                    next_data_counter = data_counter + 16'b1;
                end else begin
                    next_sdram_wr_en = 1'b0;
                    next_state = STATE_IDLE;
                end
            end
        end
        
        // ======================================
        // 状态：STATE_WAIT_END - 等待包结束
        // ======================================
        STATE_WAIT_END: begin
            // 等待错误包结束，直接丢弃数据
            if (!udp_rx_valid) begin
                next_state = STATE_IDLE;
            end
        end
        
        default: begin
            next_state = STATE_IDLE;
        end
    endcase
end

endmodule