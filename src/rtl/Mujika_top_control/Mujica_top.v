module Mujica_top( 
    // 系统时钟和复位
    input  sys_clk,           // 50MHz系统时钟
    input  rst_n,        // 系统复位信号，低电平有效
    
    //转换信号
    input wire start_power,      // 开始开机，高电平有效
    input wire start_save,       // 开始存照片，高电平有效
    input wire start_fetch,      // 开始读照片，高电平有效
    input wire finish_fetch,     // 结束读照片，高电平有效
    
    // PHY1 RGMII接口信号
    input               phy1_rgmii_rx_clk,   // RGMII接收时钟
    input               phy1_rgmii_rx_ctl,   // RGMII接收控制
    input [3:0]         phy1_rgmii_rx_data,  // RGMII接收数据
    output wire         phy1_rgmii_tx_clk,   // RGMII发送时钟
    output wire         phy1_rgmii_tx_ctl,   // RGMII发送控制
    output wire [3:0]   phy1_rgmii_tx_data,  // RGMII发送数据
    
    output [2:0]        led,                  // LED状态指示
    
    
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

// 重置
always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE_STATUS;
    end else begin
        current_state <= next_state;
    end
end

//==========================状态输入=========================
//同步待机输入至时钟逻辑
reg [1:0] input_state;  //待机输入暂存

always@(posedge start_power,start_save,start_fetch,sys_clk or negedge rst_n )begin
    if(!rst_n )
    
        input_state <= 2'b00;
        
    else if(current_state == IDLE_STATUS )begin
    
    //确保输入安全，优先级 power > save > read
        if (start_power)
            input_state <= 2'b01;
        else if (start_save && ~start_power)
            input_state <= 2'b10;
        else if (start_fetch && ~start_save && ~start_power)
            input_state <= 2'b11;
       
    end        
    else
        //非待机状态忽略所有输入
        input_state <= 2'b00;
end

//同步读取输入至时钟逻辑
reg return_idle;//读取输入暂存

always@(posedge finish_fetch,sys_clk or negedge rst_n )begin
    if(!rst_n )
    
        return_idle <= 1'b0;
        
    else if(current_state == SNAP_FETCH_WORK )begin
  
        if (finish_fetch && ~send_working)
            return_idle <= 1'b1;
         
    end       
    else
        //非读取状态忽略所有输入
        return_idle <= 1'b0;
end

reg change_pic;
wire key1;
assign key1 = change_pic |  eth_tx_pic_en;
 
 always@(posedge start_fetch,sys_clk or negedge rst_n )begin
    if(!rst_n )
    
        change_pic <= 1'b0;
        
    else if(current_state == SNAP_FETCH_WORK )begin
    
        if (send_finish)
            change_pic <= 1'b0;
        else if(start_fetch)
            change_pic <= 1'b1;
         
    end       
    else
        //非读取状态忽略所有输入
         change_pic <= 1'b0;
end

//=======================状态选择===========================

// 状态寄存器
reg [2:0] current_state;
reg [2:0] next_state;


// 状态机实现
always @(posedge sys_clk,send_finish or negedge rst_n) begin    
    //发送完成校验状态机
    if(send_finish)begin
    
        case (current_state)
        
            // 等待外部触发信号
            IDLE_STATUS: begin
                
                case(input_state)
                    2'b00:next_state <= IDLE_STATUS;
                    2'b01:next_state <= POWER_CONTROL;
                    2'b10:next_state <= SNAP_SAVE;
                    2'b11:next_state <= SNAP_FETCH;
                endcase
                
            end
            
            //开机工作流
            POWER_CONTROL:
                next_state <= POWER_CONTROL_WORK;
            POWER_CONTROL_WORK:
                next_state <= IDLE_STATUS;
            
            //拍照工作流
            SNAP_SAVE:
                next_state <= SNAP_SAVE_WORK;
            SNAP_SAVE_WORK:
                next_state <= IDLE_STATUS;
            
            //读取工作流
            SNAP_FETCH: 
                next_state <= SNAP_FETCH_WORK;
            SNAP_FETCH_WORK: begin
                // 等待读操作完成信号
                if (return_idle) begin
                    next_state <= IDLE_STATUS;
                end else begin
                    next_state <= SNAP_FETCH_WORK;
                end
            end
            
            default: next_state <= IDLE_STATUS;
            
        endcase
    
    
    end
   
end
    
//=================管理发射状态=====================

reg [1:0] eth_tx_data; // 以太网发送数
reg eth_tx_en;         // 以太网发送cmd使能 
reg eth_tx_pic_en;     // 以太网发送pic使能

reg  send_working;
    
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
wire    cmd_vaild  ;
assign  cmd_vaild = eth_tx_en;

wire [1:0]  cmd_in ;
assign      cmd_in = eth_tx_data;

//pic
//输入状态

//pic发射器控制器

//To 毛毛虫：在此实现sd，sdram，udp的连接
//如果你对接口有任何疑问请询问我
//top,发送，loop
//进行封装
// ==============================
// BMP传输封装模块实例化
// ==============================

// 状态信号
wire transfer_busy;
wire transfer_done;
wire [3:0] status_code;

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


//记录输出状态
reg  send_finish;   //发送状态管理器

always @(posedge sys_clk or negedge rst_n)begin
    if (!rst_n)
        send_finish <= 1'b0;
    else if(transfer_done == 1'b1)
        send_finish <= 1'b1;
    else if(send_finish == 1'b1)
        send_finish <= 1'b0;
end
                   
endmodule
