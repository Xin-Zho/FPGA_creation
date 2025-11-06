//`define TEST_STATE

module Mujica_top( 
    // 系统时钟和复位
    input  sys_clk,           // 50MHz系统时钟
    input  rst_n,        // 系统复位信号，低电平有效
    
    //转换信号
    input wire start_power,      // 开始开机，低电平有效
    input wire start_save,       // 开始存照片，低电平有效
    input wire start_fetch,      // 开始读照片，低电平有效
    
    // PHY1 RGMII接口信号
    input               phy1_rgmii_rx_clk,   // RGMII接收时钟
    input               phy1_rgmii_rx_ctl,   // RGMII接收控制
    input [3:0]         phy1_rgmii_rx_data,  // RGMII接收数据
    output wire         phy1_rgmii_tx_clk,   // RGMII发送时钟
    output wire         phy1_rgmii_tx_ctl,   // RGMII发送控制
    output wire [3:0]   phy1_rgmii_tx_data,  // RGMII发送数据
    
    output [3:0]        led,                  // LED状态指示
    
    
    //开始更改
    // SD 接口信号
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso
    //更改结束
);

// 状态定义
localparam IDLE_STATUS        = 3'b000;  // 不工作
localparam POWER_CONTROL      = 3'b001;  // 准备开机
localparam POWER_CONTROL_WORK = 3'b101;  // 执行开机操作
localparam SNAP_SAVE          = 3'b010;  // 准备存照片
localparam SNAP_SAVE_WORK     = 3'b110;  // 执行存照片操作
localparam SNAP_FETCH         = 3'b011;  // 准备读照片
localparam SNAP_FETCH_WORK    = 3'b111;  // 执行读照片操作
           

//==========================状态重置==========================
// 状态寄存器
reg [2:0] current_state;
reg [2:0] next_state;

// 重置
always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE_STATUS;
    end else begin
//        if (send_working)
//            current_state <= current_state;
//        else
        current_state <= next_state;
    end
end

//==========================状态输入=========================
//同步待机输入至时钟逻辑
reg [1:0] input_state;  //待机输入暂存
reg idle_flag;

always@(posedge sys_clk or negedge rst_n )begin
    if(!rst_n )begin
    
        input_state <= 2'b00;
//        led_debug <= 4'b0000;
    end
    else if(idle_flag)begin
    
    //确保输入安全，优先级 power > save > read
        if (~start_power)begin
            input_state <= 2'b01;
//            led_debug <= 4'b0001;
        end
        else if (~start_save && start_power)begin
//            led_debug <= 4'b0010;
            input_state <= 2'b10;
        end
        else if (~start_fetch && start_save && start_power)begin
            input_state <= 2'b11;
//            led_debug <= 4'b0011;
        end
        else begin
            input_state <= input_state;
//            led_debug <= led_debug;
        end
       
    end        
    else begin
        //非待机状态忽略所有输入
        input_state <= 2'b00;
       // led_debug <= 4'b0000;
    end
end

//同步读取输入至时钟逻辑
reg  send_working;

reg return_idle;//读取输入暂存
reg fetch_flag;
reg idle_back;

always@(posedge sys_clk or negedge rst_n )begin
    if(!rst_n )
    
        return_idle <= 1'b0;
        
    else if(fetch_flag)begin
  
        if (~start_fetch && ~send_working)
            return_idle <= 1'b1;
         
    end       
    else
        //非读取状态忽略所有输入
        return_idle <= 1'b0;
end

reg change_pic;
 
 always@(posedge sys_clk or negedge rst_n )begin
    if(!rst_n )
    
        change_pic <= 1'b0;
        
    else if(fetch_flag)begin
    
        if(send_working) 
            change_pic <= 1'b0;
        else if(~start_save)
            change_pic <= 1'b1;
        else
            change_pic <= change_pic;
       
    end       
    else
        //非读取状态忽略所有输入
         change_pic <= 1'b0;
end

//=======================状态选择===========================
// 状态机实现
always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n)begin
        next_state <= IDLE_STATUS;
        led_cmd <= 4'b0000;
        fetch_flag <= 1'b0;
        idle_flag <= 1'b0;
    end
    //发送完成校验状态机
    else if(send_finish)begin
    
        case (current_state)
        
            // 等待外部触发信号
            IDLE_STATUS: begin
                led_cmd <= 4'b0001;
                idle_flag <= (input_state == 2'b00) ;
                
                case(input_state)
                    2'b00:begin
//                        led_cmd <= 4'b0000;
                        next_state <= IDLE_STATUS;
                        end
                    2'b01:begin
//                        led_cmd <= 4'b0001;
                        next_state <= POWER_CONTROL;
                        end
                    2'b10:begin
//                        led_cmd <= 4'b0001;
                        next_state <= SNAP_SAVE;
                        end
                    2'b11:begin
//                        led_cmd <= 4'b0001;
                        next_state <= SNAP_FETCH;
                        end
                endcase
                      
            end
            
            //开机工作流
            POWER_CONTROL:begin
                led_cmd <= 4'b0010;  
                next_state <= POWER_CONTROL_WORK;
            end
            POWER_CONTROL_WORK:begin
                led_cmd <= 4'b0101; 
//                next_state <= POWER_CONTROL_WORK;
                next_state <= IDLE_STATUS;
            end
            
            //拍照工作流
            SNAP_SAVE:begin
                led_cmd <= 4'b0010;  
                next_state <= SNAP_SAVE_WORK;
            end
            SNAP_SAVE_WORK:begin
                led_cmd <= 4'b0110;
                next_state <= IDLE_STATUS;
            end
            
            //读取工作流
            SNAP_FETCH:begin
                led_cmd <= 4'b0010;
                next_state <= SNAP_FETCH_WORK;
            end
            SNAP_FETCH_WORK: begin
                // 等待读操作完成信号
               if (return_idle) begin
                    led_cmd <= 4'b0001;
                    fetch_flag <= 1'b0; 
                    next_state <= IDLE_STATUS;
                end 
                else if(change_pic) begin
                    led_cmd <= 4'b0101;
                    fetch_flag <= 1'b0; 
                    next_state <= SNAP_FETCH_WORK;
                end
                else begin
                    led_cmd <= 4'b0011;
                    fetch_flag <= 1'b1; 
                    next_state <= SNAP_FETCH_WORK;
                end
            end
            
        default: begin
            led_cmd = 4'b0001;
            next_state <= IDLE_STATUS;
      end
           
    endcase
    
    end
    else begin
       next_state <= next_state;
       led_cmd <= led_cmd;
    end 
end
    
//=================管理发射状态=====================

reg [1:0] eth_tx_data; // 以太网发送数
reg eth_tx_en;         // 以太网发送cmd使能 
reg eth_tx_pic_en;     // 以太网发送pic使能


    
// 以太网发送控制逻辑
always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        eth_tx_data <= 2'b00;
        eth_tx_en <= 1'b0;
        eth_tx_pic_en <= 1'b0;
        
        send_working <= 1'b0;
    end 
    else if (!send_working) begin
        case (current_state)
            // A状态：发送2bit状态给下位机
            IDLE_STATUS: begin
                
                eth_tx_data <= 2'b00;  // A: 00
                eth_tx_en <= 1'b1;     // 使能发送
                eth_tx_pic_en <= 1'b0; 
                
                send_working <= 1'b1;
            end
            
            POWER_CONTROL: begin
                    
                eth_tx_data <= 2'b01;  // A: 01
                eth_tx_en <= 1'b1;     // 使能发送
                //eth_tx_en <= 1'b0;
                eth_tx_pic_en <= 1'b0; 
                
                send_working <= 1'b1;
            end
            
            SNAP_SAVE: begin
            
                eth_tx_data <= 2'b10;  // A: 10
                eth_tx_en <= 1'b1;     // 使能发送
                eth_tx_pic_en <= 1'b0; 
                
                send_working <= 1'b1;
            end
            
            SNAP_FETCH: begin
            
                eth_tx_data <= 2'b11;  // A: 11
                eth_tx_en <= 1'b1;     // 使能发送
                eth_tx_pic_en <= 1'b0; 
                
                send_working <= 1'b1;
            end
            
            // B状态：根据状态发送对应数据
            POWER_CONTROL_WORK: begin
                
            
                eth_tx_pic_en <= 1'b1;     // 使能发送开机图片
                eth_tx_en <= 1'b0;
                
                send_working <= 1'b1;
            end
            
            SNAP_SAVE_WORK: begin
                eth_tx_pic_en <= 1'b1;     // 使能发送传入照片
                eth_tx_en <= 1'b0;
                
                send_working <= 1'b1;
            end
            
            SNAP_FETCH_WORK: begin
                if(change_pic)begin
                       // 使能发送传出照片
                    send_working <= 1'b1;
                     
                end 
                eth_tx_pic_en <= 1'b0;
                eth_tx_en <= 1'b0;
                
            end
            
            //没用，IDLE_STATUS就是默认的
//            default: begin
//                eth_tx_data <= 2'b00;
//                eth_tx_pic_en <= 1'b0;
//                eth_tx_en <= 1'b0;
//            end
        endcase
    end
    else begin
        //完成send时重置发射状态
        if(send_finish)begin
            send_working <= 1'b0;
        end      
    end
end

//=====================发送实现管理=========================

//cmd
//输入状态
wire    cmd_valid  ;
assign  cmd_valid = eth_tx_en;

wire [1:0]  cmd_in ;
assign      cmd_in = eth_tx_data;

//pic
//输入状态

//pic发射器控制器

//To 毛毛虫：在此实现sd，sdram，udp的连接
//如果你对接口有任何疑问请询问我

//进行封装
// ==============================
// BMP传输封装模块实例化
// ==============================

// 状态信号
wire transfer_busy;
wire transfer_done;
wire [3:0] status_code;

wire key1;
assign key1 = change_pic |  eth_tx_pic_en;

bmp_transfer_wrapper bmp_wrapper_inst(
    // 系统接口
    .sys_clk                (sys_clk),
    .rst_n                  (rst_n),
    
    .cmd_in(cmd_in),         // 2位命令输入
    .cmd_valid(cmd_valid),      // 命令有效信号（新增）
    
    // 控制接口
    .start_transfer         (key1),              // 使用key1触发所有功能
    .transfer_busy          (transfer_busy),
    .transfer_done          (transfer_done),
    .status_code            (status_code),
    
    // 物理层接口
    .phy1_rgmii_rx_clk      (phy1_rgmii_rx_clk),
    .phy1_rgmii_rx_ctl      (phy1_rgmii_rx_ctl),
    .phy1_rgmii_rx_data     (phy1_rgmii_rx_data),
    .phy1_rgmii_tx_clk      (phy1_rgmii_tx_clk),
    .phy1_rgmii_tx_ctl      (phy1_rgmii_tx_ctl),
    .phy1_rgmii_tx_data     (phy1_rgmii_tx_data),
    
    // SD卡接口
    .sd_ncs                 (sd_ncs),
    .sd_dclk                (sd_dclk),
    .sd_mosi                (sd_mosi),
    .sd_miso                (sd_miso)
);

//封装结束

//==================灯光===========================
wire [3:0] led_ctl;
reg  [3:0] led_cmd;
reg  [3:0] led_debug;

assign led_ctl = led_cmd;

//assign led_ctl = led_debug;

led_control control_led(
    
    .sys_clk(sys_clk) ,                    //50mHz, system clock
    .rst_n(rst_n)   ,                    //reset sign  ,1 then reset
    .cntl(led_ctl)    ,                          //contrl sign ,decide use which kind of led
    
    .led(led)                            //led output
);

//记录输出状态
reg  send_finish;   //发送状态管理器

localparam FETCH_PREIOD = 24'd9_999_999; 
reg [23:0] fetch_cnt;

always @(posedge sys_clk or negedge rst_n )begin
        if(!rst_n)
            fetch_cnt <= 24'd0;
        else if (fetch_cnt < FETCH_PREIOD && fetch_flag)
            fetch_cnt <= fetch_cnt + 1'b1;
        else
            fetch_cnt <= 24'd0;
end

`ifdef TEST_STATE

    localparam PIC_PREIOD = 64'd999_999_999;
    
    reg [63:0] pic_cnt ;
    
    localparam CMD_PREIOD = 32'd99_999_999; 
    
    reg [31:0] cmd_cnt ;
    
    always @(posedge sys_clk or negedge rst_n )begin
        if(!rst_n)
            pic_cnt <= 64'd0;
        else if (pic_cnt < PIC_PREIOD && eth_tx_pic_en)
            pic_cnt <= pic_cnt + 1'b1;
        else
            pic_cnt <= 64'd0;
    end
    
    always @(posedge sys_clk or negedge rst_n )begin
        if(!rst_n)
            cmd_cnt <= 32'd0;
        else if (cmd_cnt < CMD_PREIOD && eth_tx_en )
            cmd_cnt <= cmd_cnt + 1'b1;
        else
            cmd_cnt <= 32'd0;
    end
    
    always @(posedge sys_clk or negedge rst_n )begin
        if(!rst_n)
            send_finish <= 1'b0;
        else if (cmd_cnt == CMD_PREIOD)
            send_finish <= 1'b1;
        else if (pic_cnt == PIC_PREIOD)
            send_finish <= 1'b1;
        else if (fetch_cnt == FETCH_PREIOD)
            send_finish <= 1'b1;
        else
            send_finish <= 1'b0;
    end

`else

    reg [1:0] send_cnt;
    reg [1:0] send_finish_cnt;
    
    always @(posedge sys_clk or negedge rst_n)begin
        if (!rst_n) begin
            send_finish <= 1'b0;
            send_cnt <= 2'b00;
            send_finish_cnt <= 2'b0;
        end
        else if(transfer_done == 1'b1)begin
            send_finish <= 1'b1;
            send_finish_cnt <= send_finish_cnt + 1'b1;
        end
        else if (fetch_cnt == FETCH_PREIOD)begin
            send_finish <= 1'b1;
        end
        else if (send_working)begin
            send_finish <= 1'b0;
        end
        else if (send_finish) begin
            send_cnt <= send_cnt +1'b1 ;           
            if(send_cnt == 2'b11)begin
                send_cnt <= 2'b0;
                send_finish <= 1'b0;
            end
        end
        else
            send_finish <= send_finish;
        
    end
    
    always@(posedge sys_clk or negedge rst_n)begin
        if(!rst_n)
            led_debug <= 4'b0000;
        else if(send_finish_cnt == 2'b11)begin
            
            led_debug <= 4'b0001;
        end
        else
            led_debug <= led_debug;
    end

`endif

                   
endmodule 
