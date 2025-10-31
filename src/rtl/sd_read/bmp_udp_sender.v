module bmp_udp_sender(
    input                       clk,                    // 时钟信号
    input                       rst,                    // 复位信号，高电平有效
    output                      ready,                  // 模块就绪信号
    input                       find,                   // 开始查找和传输BMP文件信号
    input                       sd_init_done,           // SD卡初始化完成标志
    output reg[3:0]             state_code,             // 状态指示编码
    // 状态编码说明：
    // 0: SD卡正在初始化
    // 1: 等待开始信号
    // 2: 正在查找BMP文件
    // 3: 正在读取BMP数据
    // 4: 正在通过UDP传输数据
    input[15:0]                 bmp_width,              // 要查找的BMP图像宽度
    
    // SD卡接口
    output reg                  sd_sec_read,            // SD卡扇区读取使能
    output reg[31:0]            sd_sec_read_addr,       // SD卡扇区读取地址
    input[7:0]                  sd_sec_read_data,       // SD卡扇区读取数据（字节）
    input                       sd_sec_read_data_valid, // SD卡扇区数据有效标志
    input                       sd_sec_read_end,        // SD卡扇区读取结束标志
    
    // UDP应用层发送接口 (匹配接收端接口)
    input                       app_tx_data_request,    // 应用层发送数据请求
    output reg                  app_tx_data_valid,      // 应用层发送数据有效
    output reg [7:0]            app_tx_data,            // 应用层发送数据
    output reg [15:0]           udp_data_length,        // UDP数据长度
    output                      udp_tx_ready,           // UDP发送就绪
    output                      app_tx_ack              // 应用层发送应答
);

// ==============================
// 状态定义
// ==============================
localparam S_IDLE         = 0;  // 空闲状态，等待开始信号
localparam S_FIND         = 1;  // 查找BMP文件状态
localparam S_READ         = 2;  // 读取BMP数据状态
localparam S_UDP_TX       = 3;  // UDP传输状态
localparam S_END          = 4;  // 传输结束状态

localparam HEADER_SIZE    = 54; // BMP文件头大小（字节）
localparam UDP_PACKET_SIZE = 1472; // UDP数据包大小 (1500 - 20(IP头) - 8(UDP头))

// ==============================
// 内部寄存器定义
// ==============================
reg[3:0]         state;              // 主状态机状态寄存器
reg[9:0]         rd_cnt;             // 扇区读取长度计数器
reg[7:0]         header_0;           // BMP文件头第一个字节
reg[7:0]         header_1;           // BMP文件头第二个字节
reg[31:0]        file_len;           // BMP文件总长度
reg[31:0]        width;              // BMP图像宽度
reg[31:0]        bmp_len_cnt;        // BMP文件长度计数器
reg              found;              // BMP文件找到标志

// UDP传输相关寄存器
reg [10:0]       buffer_wr_addr;     // 数据缓冲区写地址
reg [10:0]       buffer_rd_addr;     // 数据缓冲区读地址
reg [15:0]       packet_data_length; // 当前数据包长度
reg [10:0]       packet_byte_cnt;    // 数据包字节计数器
reg              tx_in_progress;     // 传输进行中标志
reg [31:0]       udp_tx_cnt;         // UDP传输包计数器

// 数据缓冲区 (使用Block RAM存储UDP数据包)
(* ram_style = "block" *) reg [7:0] data_buffer [0:UDP_PACKET_SIZE-1];

// ==============================
// 连续赋值语句
// ==============================
assign ready = (state == S_IDLE);                    // 空闲状态时模块就绪
assign udp_tx_ready = (state == S_UDP_TX) && !tx_in_progress; // UDP发送就绪条件
assign app_tx_ack = 1'b1;                           // 简化应答，始终应答

// ==============================
// 扇区读取字节计数器
// ==============================
always@(posedge clk or posedge rst)
begin
    if(rst == 1'b1)
        rd_cnt <= 10'd0;
    else if(state == S_FIND)
    begin
        if(sd_sec_read_data_valid == 1'b1)
            rd_cnt <= rd_cnt + 10'd1;
        else if(sd_sec_read_end == 1'b1)
            rd_cnt <= 10'd0;
    end
    else
        rd_cnt <= 10'd0;
end

// ==============================
// BMP文件头解析逻辑
// ==============================
always@(posedge clk or posedge rst)
begin
    if(rst == 1'b1)
    begin
        header_0 <= 8'd0;
        header_1 <= 8'd0;
        file_len <= 32'd0;
        width <= 32'd0;
        found <= 1'b0;
    end
    else if(state == S_FIND && sd_sec_read_data_valid == 1'b1)
    begin
        // 解析BMP文件头
        if(rd_cnt == 10'd0)
            header_0 <= sd_sec_read_data;
        if(rd_cnt == 10'd1)
            header_1 <= sd_sec_read_data;
        if(rd_cnt == 10'd2)
            file_len[7:0] <= sd_sec_read_data;
        if(rd_cnt == 10'd3)
            file_len[15:8] <= sd_sec_read_data;
        if(rd_cnt == 10'd4)
            file_len[23:16] <= sd_sec_read_data;
        if(rd_cnt == 10'd5)
            file_len[31:24] <= sd_sec_read_data;
        if(rd_cnt == 10'd18)
            width[7:0] <= sd_sec_read_data;
        if(rd_cnt == 10'd19)
            width[15:8] <= sd_sec_read_data;
        if(rd_cnt == 10'd20)
            width[23:16] <= sd_sec_read_data;
        if(rd_cnt == 10'd21)
            width[31:24] <= sd_sec_read_data;
        
        // 检查文件头和图像宽度是否匹配
        if(rd_cnt == 10'd54 && header_0 == "B" && header_1 == "M" && width[15:0] == bmp_width)
            found <= 1'b1;
    end
    else if(state != S_FIND)
        found <= 1'b0;
end

// ==============================
// 数据缓冲区写入控制
// ==============================
always@(posedge clk or posedge rst)
begin
    if(rst == 1'b1)
    begin
        buffer_wr_addr <= 11'd0;
    end
    else if(state == S_READ)
    begin
        // 在读取状态下，将有效数据写入缓冲区
        if(sd_sec_read_data_valid == 1'b1 && buffer_wr_addr < UDP_PACKET_SIZE)
        begin
            data_buffer[buffer_wr_addr] <= sd_sec_read_data;
            buffer_wr_addr <= buffer_wr_addr + 1'b1;
        end
    end
    else if(state == S_UDP_TX && packet_byte_cnt == packet_data_length)
    begin
        // UDP传输完成后重置写地址
        buffer_wr_addr <= 11'd0;
    end
end

// ==============================
// 主状态机 - 支持UDP传输
// ==============================
always@(posedge clk or posedge rst)
begin
    if(rst == 1'b1)
    begin
        state <= S_IDLE;
        sd_sec_read <= 1'b0;
        sd_sec_read_addr <= 32'd18688;
        state_code <= 4'd0;
        
        // 复位BMP长度计数器
        bmp_len_cnt <= 32'd0;
        
        // UDP传输相关复位
        app_tx_data_valid <= 1'b0;
        app_tx_data <= 8'd0;
        udp_data_length <= 16'd0;
        tx_in_progress <= 1'b0;
        packet_byte_cnt <= 11'd0;
        buffer_rd_addr <= 11'd0;
        udp_tx_cnt <= 32'd0;
    end
    else if(sd_init_done == 1'b0)
    begin
        state <= S_IDLE;
    end
    else
        case(state)
            S_IDLE:
            begin
                state_code <= 4'd1;  // 状态码1: 等待开始信号
                if(find == 1'b1)
                    state <= S_FIND;
                // 地址8字节对齐
                sd_sec_read_addr <= {sd_sec_read_addr[31:3],3'd0};
                
                // 复位BMP长度计数器
                bmp_len_cnt <= 32'd0;
                
                // 复位UDP传输相关信号
                app_tx_data_valid <= 1'b0;
                tx_in_progress <= 1'b0;
            end
            
            S_FIND:
            begin
                state_code <= 4'd2;  // 状态码2: 正在查找BMP文件
                if(sd_sec_read_end == 1'b1)
                begin
                    if(found == 1'b1)
                    begin
                        // 找到匹配的BMP文件，进入读取状态
                        state <= S_READ;
                        sd_sec_read <= 1'b0;
                        state_code <= 4'd3;  // 状态码3: 正在读取数据
                        
                        // 重置BMP长度计数器，准备开始计数
                        bmp_len_cnt <= 32'd0;
                    end
                    else
                    begin
                        // 未找到，搜索下一个8扇区
                        sd_sec_read_addr <= sd_sec_read_addr + 32'd8;
                    end
                end
                else
                begin
                    sd_sec_read <= 1'b1;
                end
            end
            
            S_READ:
            begin
                state_code <= 4'd3;  // 状态码3: 正在读取数据
                
                // 数据读取计数 - 统一在这里更新bmp_len_cnt
                if(sd_sec_read_data_valid == 1'b1)
                    bmp_len_cnt <= bmp_len_cnt + 32'd1;
                
                if(sd_sec_read_end == 1'b1)
                begin
                    // 当前扇区读取完成
                    sd_sec_read_addr <= sd_sec_read_addr + 32'd1;
                    sd_sec_read <= 1'b0;
                    
                    if(bmp_len_cnt >= file_len)
                    begin
                        // 文件读取完成
                        if(buffer_wr_addr > 0)
                        begin
                            // 缓冲区还有数据，先发送
                            state <= S_UDP_TX;
                            packet_data_length <= buffer_wr_addr;
                        end
                        else
                        begin
                            // 所有数据已处理完成
                            state <= S_END;
                        end
                    end
                end
                else if(buffer_wr_addr >= UDP_PACKET_SIZE)
                begin
                    // 缓冲区已满，开始UDP传输
                    state <= S_UDP_TX;
                    packet_data_length <= UDP_PACKET_SIZE;
                    sd_sec_read <= 1'b0;
                end
                else
                begin
                    sd_sec_read <= 1'b1;
                end
            end
            
            S_UDP_TX:
            begin
                state_code <= 4'd4;  // 状态码4: 正在通过UDP传输数据
                
                if(app_tx_data_request && !tx_in_progress)
                begin
                    // 开始发送UDP数据包
                    tx_in_progress <= 1'b1;
                    buffer_rd_addr <= 11'd0;
                    packet_byte_cnt <= 11'd0;
                    udp_data_length <= packet_data_length;
                end
                
                if(tx_in_progress)
                begin
                    if(packet_byte_cnt < packet_data_length)
                    begin
                        // 发送数据
                        app_tx_data_valid <= 1'b1;
                        app_tx_data <= data_buffer[buffer_rd_addr];
                        buffer_rd_addr <= buffer_rd_addr + 1'b1;
                        packet_byte_cnt <= packet_byte_cnt + 1'b1;
                    end
                    else
                    begin
                        // 当前数据包发送完成
                        app_tx_data_valid <= 1'b0;
                        tx_in_progress <= 1'b0;
                        udp_tx_cnt <= udp_tx_cnt + 1'b1;
                        
                        // 判断下一步操作
                        if(bmp_len_cnt >= file_len)
                        begin
                            // 文件已读取完成
                            if(buffer_wr_addr == 0)
                            begin
                                // 所有数据已发送
                                state <= S_END;
                            end
                            else
                            begin
                                // 还有剩余数据要发送
                                state <= S_UDP_TX;
                                packet_data_length <= buffer_wr_addr;
                            end
                        end
                        else
                        begin
                            // 继续读取数据
                            state <= S_READ;
                            sd_sec_read <= 1'b1;
                        end
                    end
                end
            end
            
            S_END:
            begin
                // 传输完成，返回空闲状态
                state <= S_IDLE;
                bmp_len_cnt <= 32'd0;
                udp_tx_cnt <= 32'd0;
            end
            
            default:
                state <= S_IDLE;
        endcase
end

endmodule