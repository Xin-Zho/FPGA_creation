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
localparam STATE_IDLE        = 3'd0;  // 空闲状态
localparam STATE_HEADER      = 3'd1;  // 解析包头
localparam STATE_CMD         = 3'd2;  // 处理指令数据
localparam STATE_IMG_HEADER  = 3'd3;  // 解析图片包头
localparam STATE_IMG_DATA    = 3'd4;  // 处理图片数据
localparam STATE_WAIT_END    = 3'd5;  // 等待包结束

// 包头定义
localparam MAGIC_NUMBER    = 16'h55AA;  // 魔数标识
localparam PKT_TYPE_CMD    = 8'h01;     // 指令包类型
localparam PKT_TYPE_IMG    = 8'h02;     // 图片包类型

// 包头结构
reg [15:0] packet_magic;     // 魔数
reg [7:0]  packet_type;     // 包类型
reg [15:0] packet_seq;      // 序列号
reg [15:0] packet_total;    // 总包数
reg [15:0] packet_data_len; // 数据长度

// 状态寄存器
reg [2:0] current_state, next_state;
reg [3:0] header_counter;   // 包头字节计数器
reg [15:0] data_counter;     // 数据字节计数器
reg [23:0] current_sdram_addr; // 当前SDRAM写地址

// 状态转移逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= STATE_IDLE;
        header_counter <= 0;
        data_counter <= 0;
        current_sdram_addr <= 21'h600000;
    end else begin
        current_state <= next_state;
        
        case (current_state)
            STATE_IDLE: begin
                header_counter <= 0;
                data_counter <= 0;
                if (udp_rx_valid ) begin
                    next_state <= STATE_HEADER;
                end
            end
            
            STATE_HEADER: begin
                if (udp_rx_valid) begin
                    if (header_counter < 9) begin  // 9字节包头
                        header_counter <= header_counter + 1;
                        
                        // 组装包头
                        case (header_counter)
                            0: packet_magic[15:8] <= udp_rx_data;
                            1: packet_magic[7:0] <= udp_rx_data;
                            2: packet_type <= udp_rx_data;
                            3: packet_seq[15:8] <= udp_rx_data;
                            4: packet_seq[7:0] <= udp_rx_data;
                            5: packet_total[15:8] <= udp_rx_data;
                            6: packet_total[7:0] <= udp_rx_data;
                            7: packet_data_len[15:8] <= udp_rx_data;
                            8: begin
                                packet_data_len[7:0] <= udp_rx_data;
                                header_counter <= 0;
                                
                                // 验证魔数并判断包类型
                                if (packet_magic == MAGIC_NUMBER) begin
                                    if (packet_type == PKT_TYPE_CMD) begin
                                        next_state <= STATE_CMD;
                                        is_image_packet <= 1'b0;
                                    end else if (packet_type == PKT_TYPE_IMG) begin
                                        next_state <= STATE_IMG_HEADER;
                                        is_image_packet <= 1'b1;
                                        image_start <= (packet_seq == 0);  // 第一个包
                                        image_end <= (packet_seq == packet_total - 1); // 最后一个包
                                    end
                                end else begin
                                    next_state <= STATE_WAIT_END;  // 魔数错误
                                end
                            end
                        endcase
                    end
                end
            end
            
            STATE_CMD: begin
                if (udp_rx_valid) begin
                    if (data_counter < packet_data_len) begin
                        // 指令数据（只有1字节）
                        if (data_counter == 0) begin
                            cmd_valid <= 1'b1;
                            cmd_data <= udp_rx_data;
                        end else begin
                            cmd_valid <= 1'b0;  // 忽略多余字节
                        end
                        data_counter <= data_counter + 1;
                    end else begin
                        cmd_valid <= 1'b0;
                        next_state <= STATE_IDLE;
                    end
                end
            end
            
            STATE_IMG_HEADER: begin
                // 可以在这里解析图片特有的头部信息（如格式、尺寸等）
                if (udp_rx_valid) begin
                    if (data_counter < 4) begin  // 假设图片头4字节
                        // 解析图片头信息
                        data_counter <= data_counter + 1;
                    end else begin
                        data_counter <= 0;
                        next_state <= STATE_IMG_DATA;
                    end
                end
            end
            
            STATE_IMG_DATA: begin
                if (udp_rx_valid) begin
                    if (data_counter < packet_data_len - 4) begin  // 减去图片头
                        sdram_wr_en <= 1'b1;
                        sdram_wr_data <= udp_rx_data;
                        sdram_wr_addr <= current_sdram_addr;
                        image_data_count <= data_counter;
                        
                        current_sdram_addr <= current_sdram_addr + 1;
                        data_counter <= data_counter + 1;
                    end else begin
                        sdram_wr_en <= 1'b0;
                        next_state <= STATE_IDLE;
                    end
                end
            end
            
            STATE_WAIT_END: begin
                // 等待错误包结束
                if (udp_rx_valid ) begin
                    next_state <= STATE_IDLE;
                end
            end
            
            default: next_state <= STATE_IDLE;
        endcase
    end
end

// 输出状态指示
always @(*) begin
    parser_state = current_state;
end
endmodule
