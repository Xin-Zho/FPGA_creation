module bmp_udp_receiver(
    input                       clk,                    // 时钟信号
    input                       rst,                    // 复位信号，高电平有效
    output                      ready,                  // 模块就绪信号
    input                       find,                   // 开始接收BMP文件信号
    input                       sd_init_done,           // SD卡初始化完成标志
    output reg[3:0]             state_code,             // 状态指示编码
    input[15:0]                 bmp_width,              // 预期的BMP图像宽度（用于验证）
    
    output                      receiver_finish,
    
    // SD卡写入接口
    output reg                  sd_sec_write,           // SD卡扇区写入使能
    output reg[31:0]            sd_sec_write_addr,      // SD卡扇区写入地址
    output reg[7:0]             sd_sec_write_data,      // SD卡扇区写入数据
    input                       sd_sec_write_data_req,  // SD卡写入数据请求
    input                       sd_sec_write_end,       // SD卡扇区写入结束标志
    
    // UDP应用层接收接口
    input                       app_rx_data_valid,      // 应用层接收数据有效
    input [7:0]                 app_rx_data,            // 应用层接收数据
    input [15:0]                app_rx_data_length,     // 应用层接收数据长度
    input [15:0]                app_rx_port_num         // 应用层接收端口号
);

// ==============================
// 状态定义
// ==============================
localparam S_IDLE         = 0;
localparam S_WAIT_RX      = 1;
localparam S_RECEIVE      = 2;
localparam S_WRITE_SD     = 3;
localparam S_END          = 4;

localparam HEADER_SIZE    = 54;
localparam UDP_PACKET_SIZE = 1472;

// ==============================
// 内部寄存器定义
// ==============================
reg[3:0]         state;
reg[15:0]        rx_data_cnt;
reg[31:0]        total_rx_bytes;
reg[31:0]        file_size;
reg[31:0]        bmp_width_rx;
reg              header_received;
reg              file_valid;

reg             finish;
assign receiver_finish = finish ;

// 数据缓冲区
(* ram_style = "block" *) reg [7:0] data_buffer [0:UDP_PACKET_SIZE-1];
reg [10:0]       buffer_wr_addr;
reg [10:0]       buffer_rd_addr;
reg [15:0]       current_pkt_length;

// BMP文件头验证相关
reg [7:0]        bmp_header [0:53];

// ==============================
// 连续赋值语句
// ==============================
assign ready = (state == S_IDLE);

// ==============================
// 数据存储处理 - 只处理数据写入和文件头数据存储
// ==============================
always@(posedge clk or posedge rst)
begin
    if(rst == 1'b1)
    begin
        // 只复位数据相关的寄存器
        file_size <= 32'd0;
        bmp_width_rx <= 32'd0;
    end
    else if(state == S_RECEIVE && app_rx_data_valid == 1'b1)
    begin
        // 存储接收到的数据到缓冲区
        if(buffer_wr_addr < UDP_PACKET_SIZE)
        begin
            data_buffer[buffer_wr_addr] <= app_rx_data;
            
            // 解析BMP文件头信息 - 只存储数据，不设置标志
            if(buffer_wr_addr < HEADER_SIZE)
            begin
                bmp_header[buffer_wr_addr] <= app_rx_data;
                
                // 解析文件大小（偏移2-5字节）
                if(buffer_wr_addr == 2) file_size[7:0] <= app_rx_data;
                if(buffer_wr_addr == 3) file_size[15:8] <= app_rx_data;
                if(buffer_wr_addr == 4) file_size[23:16] <= app_rx_data;
                if(buffer_wr_addr == 5) file_size[31:24] <= app_rx_data;
                
                // 解析图像宽度（偏移18-21字节）
                if(buffer_wr_addr == 18) bmp_width_rx[7:0] <= app_rx_data;
                if(buffer_wr_addr == 19) bmp_width_rx[15:8] <= app_rx_data;
                if(buffer_wr_addr == 20) bmp_width_rx[23:16] <= app_rx_data;
                if(buffer_wr_addr == 21) bmp_width_rx[31:24] <= app_rx_data;
            end
        end
    end
end

// ==============================
// 总接收字节计数
// ==============================
always@(posedge clk or posedge rst)
begin
    if(rst == 1'b1)
        total_rx_bytes <= 32'd0;
    else if(state == S_RECEIVE && app_rx_data_valid == 1'b1)
        total_rx_bytes <= total_rx_bytes + 32'd1;
    else if(state == S_IDLE)
        total_rx_bytes <= 32'd0;
end

// ==============================
// 主状态机 - 统一驱动所有控制信号和计数器
// ==============================
always@(posedge clk or posedge rst)
begin
    if(rst == 1'b1)
    begin
        // 复位所有控制信号
        state <= S_IDLE;
        sd_sec_write <= 1'b0;
        sd_sec_write_addr <= 32'd21000;
        sd_sec_write_data <= 8'd0;
        state_code <= 4'd0;
        
        rx_data_cnt <= 16'd0;
        header_received <= 1'b0;
        file_valid <= 1'b0;
        buffer_wr_addr <= 11'd0;
        buffer_rd_addr <= 11'd0;
        current_pkt_length <= 16'd0;
    end
    else if(sd_init_done == 1'b0)
    begin
        state <= S_IDLE;
        state_code <= 4'd0;
        rx_data_cnt <= 16'd0;
        header_received <= 1'b0;
        file_valid <= 1'b0;
        buffer_wr_addr <= 11'd0;
        buffer_rd_addr <= 11'd0;
        current_pkt_length <= 16'd0;
    end
    else
        case(state)
            S_IDLE:
            begin
                finish <= 1'b0;
            
                state_code <= 4'd1;
                header_received <= 1'b0;
                file_valid <= 1'b0;
                buffer_wr_addr <= 11'd0;
                rx_data_cnt <= 16'd0;
                buffer_rd_addr <= 11'd0;
                current_pkt_length <= 16'd0;
                sd_sec_write <= 1'b0;           // **确保写入使能复位**
                sd_sec_write_data <= 8'd0;      // **确保写入数据复位**
                
                if(find == 1'b1)
                begin
                    state <= S_WAIT_RX;
                    sd_sec_write_addr <= 32'd21000;
                end
            end
            
            S_WAIT_RX:
            begin
                state_code <= 4'd2;
                sd_sec_write <= 1'b0;           // **确保写入使能复位**
                if(app_rx_data_valid == 1'b1)
                begin
                    state <= S_RECEIVE;
                    rx_data_cnt <= 16'd0;
                    buffer_wr_addr <= 11'd0;
                end
            end
            
            S_RECEIVE:
            begin
                // 递增计数器
                if (app_rx_data_valid == 1'b1) begin
                    rx_data_cnt <= rx_data_cnt + 1'b1;
                    // 递增写地址
                    if(buffer_wr_addr < UDP_PACKET_SIZE) begin
                        buffer_wr_addr <= buffer_wr_addr + 1'b1;
                    end
                end
                
                // 检查文件头是否接收完成并验证
                if (buffer_wr_addr >= HEADER_SIZE && !header_received) begin
                    header_received <= 1'b1;
                    // 验证BMP文件头和宽度
                    if(bmp_header[0] == "B" && bmp_header[1] == "M" && 
                       bmp_width_rx[15:0] == bmp_width)
                    begin
                        file_valid <= 1'b1;
                    end
                    else
                    begin
                        file_valid <= 1'b0;
                    end
                end
            
                // 设置状态码
                if (header_received) begin
                    if (file_valid) begin
                        state_code <= 4'd2;  // 正在接收有效BMP数据
                    end else begin
                        state_code <= 4'd5;  // 文件格式错误
                    end
                end else begin
                    state_code <= 4'd2;      // 正在接收UDP数据
                end
                
                sd_sec_write <= 1'b0;        // **确保在接收状态不使能写入**
                
                // 检查数据包接收完成条件
                if((rx_data_cnt >= app_rx_data_length && app_rx_data_length > 0) || 
                   buffer_wr_addr >= UDP_PACKET_SIZE)
                begin
                    if (file_valid || !header_received) begin
                        state <= S_WRITE_SD;
                        buffer_rd_addr <= 11'd0;
                        current_pkt_length <= (app_rx_data_length > 0) ? app_rx_data_length : buffer_wr_addr;
                    end else begin
                        state <= S_IDLE;
                    end
                end
            end
            
            S_WRITE_SD:
            begin
                state_code <= 4'd3;
                sd_sec_write <= 1'b1;        // **只在写入状态使能写入**
                
                // 响应SD卡写入数据请求
                if(sd_sec_write_data_req == 1'b1 && buffer_rd_addr < current_pkt_length)
                begin
                    sd_sec_write_data <= data_buffer[buffer_rd_addr];
                    buffer_rd_addr <= buffer_rd_addr + 1'b1;
                end
                else
                begin
                    sd_sec_write_data <= 8'd0;  // **默认写入0**
                end
                
                // SD卡扇区写入完成
                if(sd_sec_write_end == 1'b1)
                begin
                    sd_sec_write <= 1'b0;
                    sd_sec_write_addr <= sd_sec_write_addr + 32'd1;
                    
                    // 检查文件是否接收完成
                    if(total_rx_bytes >= file_size && file_size > 0 && file_valid)
                    begin
                        state <= S_END;
                    end
                    else if (!file_valid && header_received) begin
                        state <= S_IDLE;
                    end
                    else
                    begin
                        state <= S_WAIT_RX;
                        buffer_wr_addr <= 11'd0;
                        rx_data_cnt <= 16'd0;
                    end
                end
            end
            
            S_END:
            begin
                finish <= 1'b0;
            
                state_code <= 4'd4;
                sd_sec_write <= 1'b0;        // **确保写入使能复位**
                #10 state <= S_IDLE;
            end
            
            default:
                state <= S_IDLE;
        endcase
end

endmodule