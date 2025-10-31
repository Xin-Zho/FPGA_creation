module top(
    input                       clk,
    input                       rst_n,
    input                       key1,
    
    // SD卡接口
    output                      sd_ncs,            // SD卡片选 (SPI模式)
    output                      sd_dclk,           // SD卡时钟
    output                      sd_mosi,           // SD卡控制器数据输出
    input                       sd_miso,           // SD卡控制器数据输入
    
    // UDP以太网接口 
    input                       eth_app_tx_data_request,
    output                      eth_app_tx_data_valid,
    output [7:0]                eth_app_tx_data,
    output [15:0]               eth_udp_data_length,
    input                       eth_udp_tx_ready,
    input                       eth_app_tx_ack
);

// ==============================
// 参数定义
// ==============================
parameter MEM_DATA_BITS  = 32;  // 外部存储器用户接口数据宽度
parameter ADDR_BITS      = 21;  // 外部存储器用户接口地址宽度
parameter BUSRT_BITS     = 10;  // 外部存储器用户接口突发宽度

// ==============================
// 时钟生成模块
// ==============================

// 时钟信号定义
wire                            sd_card_clk;       // SD卡控制器时钟
wire                            ext_mem_clk;       // 外部存储器时钟
wire                            ext_mem_clk_sft;   // 外部存储器时钟相移

// SD卡控制器时钟和SDRAM控制器时钟生成
sys_pll sys_pll_m0(
    .refclk                     (clk),              // 参考时钟
    .clk0_out                   (sd_card_clk),      // SD卡时钟输出
    .clk1_out                   (ext_mem_clk),      // 外部存储器时钟输出
    .clk2_out                   (ext_mem_clk_sft),  // 外部存储器时钟相移输出
    .reset                      (1'b0)              // 复位
);

// SDRAM时钟分配
assign sdram_clk = ext_mem_clk;

// ==============================
// SD卡BMP文件读取模块
// ==============================

// SD卡BMP读取状态信号
wire [3:0]                      state_code;        // 状态指示编码

// SD卡BMP文件读取模块
sd_card_bmp sd_card_bmp_m0(
    .clk                        (sd_card_clk),          // SD卡时钟
    .rst                        (~rst_n),               // 复位信号
    .key                        (key1),                 // 按键触发
    .state_code                 (state_code),           // 状态指示编码
    .bmp_width                  (16'd640),              // 图像宽度
    
    // UDP应用层发送接口
    .app_tx_data_request        (eth_app_tx_data_request),
    .app_tx_data_valid          (eth_app_tx_data_valid),
    .app_tx_data                (eth_app_tx_data),
    .udp_data_length            (eth_udp_data_length),
    .udp_tx_ready               (eth_udp_tx_ready),
    .app_tx_ack                 (eth_app_tx_ack),
    
    // SD卡接口
    .SD_nCS                     (sd_ncs),
    .SD_DCLK                    (sd_dclk),
    .SD_MOSI                    (sd_mosi),
    .SD_MISO                    (sd_miso)
);

// ==============================
// SDRAM控制器模块
// ==============================

// SDRAM控制信号定义
wire                            Sdr_init_done;     // SDRAM初始化完成
wire                            Sdr_init_ref_vld;  // SDRAM刷新有效
wire                            Sdr_busy;          // SDRAM忙标志

// SDRAM应用层接口信号
wire                            App_rd_en;             // 应用读使能
wire [ADDR_BITS-1:0]            App_rd_addr;           // 应用读地址
wire                            Sdr_rd_en;             // SDRAM读使能
wire [MEM_DATA_BITS-1:0]        Sdr_rd_dout;           // SDRAM读数据

wire                            App_wr_en;             // 应用写使能
wire [ADDR_BITS-1:0]            App_wr_addr;           // 应用写地址
wire [MEM_DATA_BITS-1:0]        App_wr_din;            // 应用写数据
wire [3:0]                      App_wr_dm;             // 应用数据掩码

// SDRAM控制器模块
sdram U3(
    .Clk                        (ext_mem_clk),          // 时钟
    .Clk_sft                    (ext_mem_clk_sft),      // 时钟相移
    .Rst                        (~rst_n),               // 复位
    
    // SDRAM状态信号
    .Sdr_init_done              (Sdr_init_done),        // 初始化完成
    .Sdr_init_ref_vld           (Sdr_init_ref_vld),     // 刷新有效
    .Sdr_busy                   (Sdr_busy),             // 忙标志
    
    // 写接口
    .App_wr_en                  (App_wr_en),            // 应用写使能
    .App_wr_addr                (App_wr_addr),          // 应用写地址
    .App_wr_dm                  (App_wr_dm),            // 应用数据掩码
    .App_wr_din                 (App_wr_din),           // 应用写数据
    
    // 读接口
    .App_rd_en                  (App_rd_en),            // 应用读使能（数据请求）
    .App_rd_addr                (App_rd_addr),          // 应用读地址
    .Sdr_rd_en                  (Sdr_rd_en),            // SDRAM读使能（数据有效）
    .Sdr_rd_dout                (Sdr_rd_dout)           // SDRAM读数据
);

// ==============================
// 视频帧数据读写控制模块
// ==============================

// 存储器读写控制信号
wire                            read_req;          // 读请求
wire                            read_req_ack;      // 读请求应答
wire                            read_en;           // 读使能
wire                            write_en;          // 写使能
wire                            write_req;         // 写请求
wire                            write_req_ack;     // 写请求应答

wire                            write_clk;         // 写时钟
wire                            read_clk;          // 读时钟

// SD卡写入信号定义
wire                            sd_card_write_en;      // SD卡写使能
wire [31:0]                     sd_card_write_data;    // SD卡写数据
wire                            sd_card_write_req;     // SD卡写请求
wire                            sd_card_write_req_ack; // SD卡写请求应答

wire                            video_rd_en;           // 视频读使能
wire                            sd_card_wr_en;         // SD卡写使能

wire                            Rd_state_end;          // 读状态结束

// 视频帧数据读写控制模块
frame_read_write frame_read_write_m0(
    .mem_clk                    (ext_mem_clk),          // 存储器时钟
    .rst                        (~rst_n),               // 复位
    
    // SDRAM状态信号
    .Sdr_init_done              (Sdr_init_done),        // SDRAM初始化完成
    .Sdr_init_ref_vld           (Sdr_init_ref_vld),     // SDRAM刷新有效
    .Sdr_busy                   (Sdr_busy),             // SDRAM忙标志
    
    // SDRAM读接口
    .App_rd_en                  (App_rd_en),            // 应用读使能
    .App_rd_addr                (App_rd_addr),          // 应用读地址
    .Sdr_rd_en                  (Sdr_rd_en),            // SDRAM读使能
    .Sdr_rd_dout                (Sdr_rd_dout),          // SDRAM读数据
    
    // 视频读接口（保留接口但实际不使用）
    .read_clk                   (1'b0),                 // 读时钟（不使用）
    .read_req                   (1'b0),                 // 读请求（不使用）
    .read_req_ack               (),                     // 读请求应答
    .read_finish                (),                     // 读完成
    .read_addr_0                (24'd0),                // 读地址0
    .read_addr_1                (24'd0),                // 读地址1
    .read_addr_2                (24'd0),                // 读地址2
    .read_addr_3                (24'd0),                // 读地址3
    .read_addr_index            (2'd0),                 // 读地址索引
    .read_len                   (24'd0),                // 读长度（不使用）
    .read_en                    (),                     // 读使能
    .read_data                  (),                     // 读数据
    
    // SDRAM写接口
    .App_wr_en                  (App_wr_en),            // 应用写使能
    .App_wr_addr                (App_wr_addr),          // 应用写地址
    .App_wr_din                 (App_wr_din),           // 应用写数据
    .App_wr_dm                  (App_wr_dm),            // 应用数据掩码
    
    // SD卡写接口
    .write_clk                  (sd_card_clk),          // 写时钟
    .write_req                  (sd_card_write_req),    // 写请求
    .write_req_ack              (sd_card_write_req_ack),// 写请求应答
    .write_finish               (),                     // 写完成
    .write_addr_0               (24'd0),                // 写地址0
    .write_addr_1               (24'd0),                // 写地址1
    .write_addr_2               (24'd0),                // 写地址2
    .write_addr_3               (24'd0),                // 写地址3
    .write_addr_index           (2'd0),                 // 写地址索引（仅使用write_addr_0）
    .write_len                  (24'd307200),           // 写长度（帧大小）
    .write_en                   (sd_card_write_en),     // 写使能
    .write_data                 (sd_card_write_data)    // 写数据
);

endmodule