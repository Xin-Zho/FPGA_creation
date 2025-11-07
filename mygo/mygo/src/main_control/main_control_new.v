module main_control_new (
    input wire clk, // 系统主时钟
    input wire rst_n, // 系统复位，低有效
    // 以太网指令输入
    input wire [7:0] eth_cmd, // 从eth_cmd_parser来的指令信号(0,1,2,3)
    input wire eth_cmd_valid, // 指令有效信号
    // 输出到各个模块的控制信号
    output reg [1:0] state, // 当前状态机状态，可输出用于调试
    output reg [1:0] video_source_sel, // 图像数据选择器控制
    output reg sd_pic_display_en, // 使能SD卡图片显示
    output reg photo_trigger
);

// 状态定义
localparam STATE_IDLE = 2'b00; // 待机
localparam STATE_LIVE = 2'b01; // 实时显示
localparam STATE_PHOTO = 2'b10; // 拍照传输
localparam STATE_SDVIEW = 2'b11; // 查看SD卡

// 状态寄存器
reg [1:0] current_state, next_state;

// 状态转移逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        current_state <= STATE_IDLE;
    else 
        current_state <= next_state;
end

// 状态转移与输出逻辑
always @(*) begin
    // 默认值
    next_state = current_state;
    video_source_sel = 2'b00;
    sd_pic_display_en = 1'b0;
    photo_trigger=1'b0;

    case (current_state)
        STATE_IDLE: begin
            video_source_sel = 2'b00; // 可显示黑屏或默认画面
            if (eth_cmd_valid && eth_cmd == 8'b0000_0001) // 只接收信号1
                next_state = STATE_LIVE;
        end

        STATE_LIVE: begin
            video_source_sel = 2'b01; // 选择摄像头实时数据
            if (eth_cmd_valid) begin
                case (eth_cmd)
                    8'b0000_0001: next_state = STATE_IDLE; // 收到1，返回待机
                    8'b0000_0010: next_state = STATE_PHOTO; // 收到2，进入拍照
                    8'b0000_0011: next_state = STATE_SDVIEW; // 收到3，查看SD卡
                    default: ; // 忽略其他信号
                endcase
            end
        end

        STATE_PHOTO: begin
            video_source_sel = 2'b10; // 选择从SDRAM读出的拍照数据
            photo_trigger=1'b1;
        end
        STATE_SDVIEW: begin
            video_source_sel = 2'b11; // 选择从以太网接收的SD图片数据
            sd_pic_display_en = 1'b1;
            if (eth_cmd_valid && eth_cmd == 8'b0000_0000) // 收到0，返回实时显示
                next_state = STATE_LIVE;
            // 忽略信号1和2
        end

        default: next_state = STATE_IDLE;
    endcase
end

always @(*)begin
    state = current_state; // 输出当前状态，可选用于调试
end

endmodule