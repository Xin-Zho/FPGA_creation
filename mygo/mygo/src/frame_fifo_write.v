`timescale 1ns/1ps
module frame_fifo_write
#
(
	parameter MEM_DATA_BITS          = 32,
	parameter ADDR_BITS              = 21,
	parameter BURST_BITS             = 9,
	parameter BURST_SIZE             = 128
    
    
)               
(
	input                            rst,                  
	input                            mem_clk,                    // external memory controller user interface clock
	input							 Sdr_init_done,
	input							 Sdr_init_ref_vld,
    input							 Sdr_busy,
	input							 App_rd_busy,
    output							 O_wr_busy,
	
	output 							 App_wr_en,
	output  [ADDR_BITS - 1:0]	 	App_wr_addr,
	/*
    output reg                       wr_burst_req,               // to external memory controller,send out a burst write request  
	output reg[BURST_BITS - 1:0]     wr_burst_len,               // to external memory controller,data length of the burst write request, not bytes 
	output reg[ADDR_BITS - 1:0]      wr_burst_addr,              // to external memory controller,base address of the burst write request 
	input                            wr_burst_data_req,          // from external memory controller,write data request ,before data 1 clock 
	input                            wr_burst_finish,            // from external memory controller,burst write finish
	*/
	input                            write_req,                  // data write module write request,keep '1' until read_req_ack = '1'
	output reg                       write_req_ack,              // data write module write request response
	output                           write_finish,               // data write module write request finish
	input[ADDR_BITS - 1:0]           write_addr_0,               // data write module write request base address 0, used when write_addr_index = 0
	input[ADDR_BITS - 1:0]           write_addr_1,               // data write module write request base address 1, used when write_addr_index = 1
	input[ADDR_BITS - 1:0]           write_addr_2,               // data write module write request base address 1, used when write_addr_index = 2
	input[ADDR_BITS - 1:0]           write_addr_3,               // data write module write request base address 1, used when write_addr_index = 3 
	input[ADDR_BITS - 1:0]           write_len,                  // data write module write request data length
	output reg                       fifo_aclr,                  // to fifo asynchronous clear
	input[9:0]                      rdusedw,                     // from fifo read used words
    
    input                           sel ,                         //主控给的指令
    
    output reg [1:0] current_region,    // 当前区域指示
    output reg addr_warning,            // 地址溢出警告
    output [ADDR_BITS-1:0] region_base_addr,  // 当前区域基地址
    output [ADDR_BITS-1:0] region_boundary_addr, // 当前区域边界
    
    input                            capture_req,          // 拍照请求信号
    output reg                       capture_ack,          // 拍照应答信号
    input [ADDR_BITS-1:0]           capture_src_addr,     // 要捕获的源帧地址（在区域1）
    input [ADDR_BITS-1:0]           capture_length,       // 要捕获的数据长度
    output reg                       capture_valid,        // 捕获数据有效信号
    output reg [ADDR_BITS-1:0]      capture_base_addr,    // 捕获数据存储基地址（在区域2）
    
    input           sdram_wr_en,           // SDRAM写使能
    input  [7:0]    sdram_wr_data,         // SDRAM写数据
    input  [23:0]   sdram_wr_addr,         // SDRAM写地址
    input           image_start,           // 图片开始标志
    input           image_end,             // 图片结束标志
    input  [15:0]   image_data_count,      // 图片数据计数器
    output reg [ADDR_BITS-1:0] image_storage_base_addr,    // 图片存储基地址
    output reg image_storage_active,                         // 图片存储激活标志
    output reg image_storage_complete                      // 图片存储完成标志

);
localparam ONE                       = 256'd1;                   //256 bit '1'   you can use ONE[n-1:0] for n bit '1'
localparam ZERO                      = 256'd0;                   //256 bit '0'
//write state machine code
localparam S_IDLE                    = 0;                        //idle state,waiting for write
localparam S_ACK                     = 1;                        //written request response
localparam S_CHECK_FIFO              = 2;                        //check the FIFO status, ensure that there is enough space to burst write
localparam S_WRITE_BURST             = 3;                        //begin a burst write
localparam S_WRITE_BURST_END         = 4;                        //a burst write complete
localparam S_END                     = 5;                        //a frame of data is written to complete

// 在状态定义区域添加拍照状态
localparam S_CAPTURE_REQ          = 6;  // 拍照请求状态
localparam S_CAPTURE_READ         = 7;  // 捕获数据读取状态  
localparam S_CAPTURE_WRITE        = 8;  // 捕获数据写入状态
localparam S_CAPTURE_FINISH       = 9;  // 拍照完成状态

// 在状态定义区域添加图片存储状态
localparam S_IMAGE_START      = 10;  // 图片开始状态
localparam S_IMAGE_WRITE      = 11;  // 图片写入状态  
localparam S_IMAGE_END        = 12;  // 图片结束状态

localparam TOTAL_SIZE         = 21'h800000;  // 总容量8MB (64Mb)

// 区域划分参数 - 基于8MB总容量
localparam REGION0_BASE       = 21'h000000;  // 区域0: 实时预览, 4MB
localparam REGION0_SIZE       = 21'h400000;
localparam REGION1_BASE       = 21'h400000;  // 区域1: 拍照存储, 2MB  
localparam REGION1_SIZE       = 21'h200000;
localparam REGION2_BASE       = 21'h600000;  // 区域2: SD卡图片, 2MB
localparam REGION2_SIZE       = 21'h200000;
localparam REGION3_BASE       = 21'h000000;  // 区域3: 备用（回退到区域0）
localparam REGION3_SIZE       = 21'h400000;



// 新增内部信号用于拍照功能
reg [ADDR_BITS-1:0] capture_read_addr;    // 捕获读地址
reg [ADDR_BITS-1:0] capture_write_addr;   // 捕获写地址
reg [ADDR_BITS-1:0] work_counter;        // 捕获数据计数器
reg capture_active;                       // 拍照激活标志
reg [1:0] work_sub_state;                 // 拍照子状态机
reg [1:0] capture_state;                 // 拍照子状态机
reg app_rd_en;
reg app_wr_en;

// 添加内部状态寄存器
reg [2:0] image_state;        // 图片存储子状态机
reg image_active;             // 图片存储激活标志

reg                                 write_req_d0;                //asynchronous write request, synchronize to 'mem_clk' clock domain,first beat
reg                                 write_req_d1;                //the second
reg                                 write_req_d2;                //third,Why do you need 3 ? Here's the design habit
reg[ADDR_BITS - 1:0]                write_len_d0;                //asynchronous write_len(write data length), synchronize to 'mem_clk' clock domain first
reg[ADDR_BITS - 1:0]                write_len_d1;                //second
reg[ADDR_BITS - 1:0]                write_len_latch;             //lock write data length
reg[ADDR_BITS - 1:0]                write_cnt;                   //write data counter
reg[3:0]                            state;                       //state machine
reg [ADDR_BITS - 1:0]	 App_wr_addr_r;

// 添加内部信号
reg [ADDR_BITS-1:0] current_base_addr;     // 当前区域基地址
reg [ADDR_BITS-1:0] current_region_size;    // 当前区域大小
reg [ADDR_BITS-1:0] region_boundary;        // 当前区域边界地址
wire addr_overflow;                         // 地址溢出检测

reg [BURST_BITS - 1:0]				burst_cnt;
wire								wr_burst_finish;

reg App_wr_en_r;
reg App_wr_en_d0;

wire into_burst;
assign into_burst = (((write_len_latch <= (rdusedw + write_cnt))||rdusedw > BURST_SIZE) && ~App_rd_busy);//当rd在突发时不会进入burst

assign App_wr_addr = {App_wr_addr_r[ADDR_BITS - 1:0]};
//assign O_wr_busy = (state != S_IDLE || (S_IDLE && write_req_d2));
assign O_wr_busy = (state == S_WRITE_BURST || (state == S_CHECK_FIFO && into_burst));//在突发，或者将要突发，则显示busy
assign wr_burst_finish = (burst_cnt >= BURST_SIZE);
assign write_finish = (state == S_END) ? 1'b1 : 1'b0;            //write finish at state 'S_END'
assign App_wr_en = App_wr_en_d0;

assign region_base_addr = current_base_addr;
assign region_boundary_addr = region_boundary;

always@(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		write_req_d0    <=  1'b0;
		write_req_d1    <=  1'b0;
		write_req_d2    <=  1'b0;
		write_len_d0    <=  ZERO[ADDR_BITS - 1:0];              //equivalent to write_len_d0 <= 0;
		write_len_d1    <=  ZERO[ADDR_BITS - 1:0];              //equivalent to write_len_d1 <= 0;

	end
	else
	begin
		write_req_d0    <=  write_req;
		write_req_d1    <=  write_req_d0;
		write_req_d2    <=  write_req_d1;
		write_len_d0    <=  write_len;
		write_len_d1    <=  write_len_d0;

	end 
end

always @(posedge mem_clk or posedge rst) begin
    if(rst == 1'b1) begin
        burst_cnt <= ZERO[BURST_BITS - 1:0];
        App_wr_addr_r <= ZERO[ADDR_BITS - 1:0];
        App_wr_en_d0 <= 1'b0;
    end else begin
        if(state == S_CHECK_FIFO)
            burst_cnt <= ZERO[BURST_BITS - 1:0];
        else if(App_wr_en)
            burst_cnt <= burst_cnt + 1'b1;
        else
            burst_cnt <= burst_cnt;
        
        // ========== 增强的地址管理逻辑 ==========
        if(state == S_ACK) begin
            // 在ACK状态已经设置了基地址，这里不需要重复设置
        end else if(App_wr_en) begin
            // 地址递增，并检查边界
            if(App_wr_addr_r < region_boundary - 1) begin
                App_wr_addr_r <= App_wr_addr_r + 1'b1;
            end else begin
                // 到达区域边界，回绕到基地址（循环写入）
                App_wr_addr_r <= current_base_addr;
            end
        end else begin
            App_wr_addr_r <= App_wr_addr_r;
        end
        
        // 原有的使能信号逻辑保持不变
        if(App_wr_en_r && burst_cnt + App_wr_en < BURST_SIZE && 
           (burst_cnt + write_cnt + App_wr_en < write_len_latch)) begin
            App_wr_en_d0 <= 1'b1;
        end else begin
            App_wr_en_d0 <= 1'b0;
        end
    end        
end
// 拍照功能状态机
always @(posedge mem_clk or posedge rst) begin
    if(rst) begin
        capture_active <= 1'b0;
        capture_ack <= 1'b0;
        capture_valid <= 1'b0;
        capture_read_addr <= ZERO[ADDR_BITS-1:0];
        capture_write_addr <= ZERO[ADDR_BITS-1:0];
        capture_base_addr <= REGION1_BASE; // 默认存到区域2
        work_counter <= ZERO[ADDR_BITS-1:0];
        work_sub_state <= 2'b00;
        app_rd_en <= 1'b0;
        app_wr_en <= 1'b0;
    end else begin
        app_rd_en <= 1'b0;
        app_wr_en <= 1'b0;
        case(capture_state)
            // 空闲状态，等待拍照请求
            2'b00: begin
                if(capture_req && !capture_active && state == S_IDLE) begin
                    capture_active <= 1'b1;
                    capture_ack <= 1'b1;          // 应答拍照请求
                    capture_read_addr <= capture_src_addr;  // 设置源地址
                    capture_write_addr <= REGION1_BASE;     // 设置目标地址
                    capture_state <= 2'b01;       // 转到准备状态
                    capture_valid <= 1'b0;
                end 
                else begin
                    capture_ack <= 1'b0;
                end
             end
            
            2'b01: begin
                capture_ack <= 1'b0;
                if(!Sdr_busy && !App_rd_busy) begin  // 等待SDRAM空闲
                    capture_state <= 2'b10;          // 转到读取状态
                    capture_valid <= 1'b1;           // 开始有效捕获
                    work_sub_state <=2'b00;
                    work_counter <= ZERO[ADDR_BITS-1:0];
                end
            end
            
            2'b10:begin
                case (work_sub_state)
                    2'b00:begin
                        if(!App_rd_busy) begin // 确保读端口空闲
                            app_rd_en <= 1'b1; // 发起读操作
                            work_sub_state <= 2'b01; // 跳到等待数据状态
                        end
                    end
                    2'b01: begin // 子状态1：等待读数据有效
                     
                            app_wr_en <= 1'b1; // 同时发起写操作
                            work_sub_state <= 2'b10;
                    end
                    2'b10: begin // 子状态2：完成一次读写操作
                        app_wr_en <= 1'b0; // 写使能只维持一个周期
                        // 更新地址和计数器
                        capture_read_addr <= capture_read_addr + 1'b1;
                        capture_write_addr <= capture_write_addr + 1'b1;
                        work_counter <= work_counter + 1'b1;
                        work_sub_state <= 2'b00; // 回到子状态0，准备下一次操作

                        // 检查是否完成所有数据的搬运（例如，达到一帧数据量 CAPTURE_SIZE）
                       
                    end
                    default: work_sub_state <= 2'b00;
                endcase
            end
            
            // 完成状态：清理并返回空闲
            2'b11: begin
                capture_active <= 1'b0;
                capture_state <= 2'b00;
                capture_base_addr <= capture_write_addr; // 输出最终的存储基地址
            end
            
            default: capture_state <= 2'b00;
        endcase
    end
end
// 图片存储状态机
always @(posedge mem_clk or posedge rst) begin
    if(rst) begin
        image_state <= 3'b000;
        image_active <= 1'b0;
        current_base_addr <= REGION0_BASE; // 默认区域
    end else begin
        case(image_state)
            // 空闲状态，等待图片开始信号
            3'b000: begin
                if(image_start && !image_active) begin
                    image_active <= 1'b1;
                    image_state <= 3'b001; // 转到准备状态
                    // 切换到区域3进行存储
                    current_base_addr <= REGION2_BASE;
                    current_region_size <= REGION2_SIZE;
                    region_boundary <= REGION2_BASE + REGION2_SIZE;
                    App_wr_addr_r <= REGION2_BASE; // 初始化写地址
                end
            end
            
            // 准备状态：初始化地址和计数器
            3'b001: begin
                if(!Sdr_busy) begin
                    image_state <= 3'b010; // 转到写入状态
                end
            end
            
            // 写入状态：接收并存储图片数据
            3'b010: begin
                if(sdram_wr_en && image_active) begin
                    // 地址递增，检查边界
                    if(App_wr_addr_r < region_boundary - 1) begin
                        App_wr_addr_r <= App_wr_addr_r + 1'b1;
                    end else begin
                        // 到达边界，回绕或停止（根据需求选择）
                        App_wr_addr_r <= REGION3_BASE;
                    end
                    
                    // 检查图片结束条件
                    if(image_end || image_data_count >= REGION3_SIZE) begin
                        image_state <= 3'b011; // 转到结束状态
                    end
                end
            end
            
            // 结束状态：清理并返回空闲
            3'b011: begin
                image_active <= 1'b0;
                image_state <= 3'b000;
                // 可选：返回到之前的区域
                current_base_addr <= REGION0_BASE;
            end
            
            default: image_state <= 3'b000;
        endcase
    end
end
always@(posedge mem_clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state <= S_IDLE;
		write_len_latch <= ZERO[ADDR_BITS - 1:0];
		
		//wr_burst_addr <= ZERO[ADDR_BITS - 1:0];
		//wr_burst_req <= 1'b0;
		App_wr_en_r <= 1'b0;
		
		write_cnt <= ZERO[ADDR_BITS - 1:0];
		fifo_aclr <= 1'b0;
		write_req_ack <= 1'b0;
		//wr_burst_len <= ZERO[BURST_BITS - 1:0];
		
		
	end
	else 
		case(state)
			//idle state,waiting for write write_req_d2 == '1' goto the 'S_ACK'
			S_IDLE:
			begin
                // sd>拍照>试试显示
                if(image_start && !image_active) begin
                    state <= S_IMAGE_START;
                end
                else if(capture_active && capture_state == 2'b10) begin
                    state <= S_CAPTURE_READ;
                end
				else if(write_req_d2 == 1'b1 && Sdr_init_done)
				begin
					state <= S_ACK;
				end
				write_req_ack <= 1'b0;
			end
            S_CAPTURE_REQ: 
            begin
                if(capture_active) begin
                    state <= S_CAPTURE_READ;
                end else begin
                    state <= S_IDLE;
                end
            end
            S_CAPTURE_READ: 
            begin
                // 实现从源地址读取数据的逻辑
                if(work_counter >= capture_length) begin
                    state <= S_CAPTURE_WRITE;
                end
            end
            
            S_CAPTURE_WRITE: 
            begin
                // 实现向目标地址写入数据的逻辑
                if(work_counter >= capture_length) begin
                    state <= S_CAPTURE_FINISH;
                end
            end
            
            S_CAPTURE_FINISH: 
            begin
                state <= S_IDLE;
            end
            // 图片存储相关状态
            S_IMAGE_START: begin
                if(image_active) begin
                    state <= S_IMAGE_WRITE;
                end else begin
                    state <= S_IDLE;
                end
            end
            
            S_IMAGE_WRITE: begin
                if(image_end || !image_active) begin
                    state <= S_IMAGE_END;
                end
                // 保持写入状态，直到图片传输完成
            end
            
            S_IMAGE_END: begin
                state <= S_IDLE;
            end
// 在 S_ACK 状态中添加区域选择逻辑
            S_ACK:
            begin
    //after write request revocation(write_req_d2 == '0'),goto 'S_CHECK_FIFO',write_req_ack goto '0'
                 if(write_req_d2 == 1'b0)
                begin
                    state <= S_CHECK_FIFO;
                    fifo_aclr <= 1'b0;
                    write_req_ack <= 1'b0;
                end
                else
                begin
        //write request response
                    write_req_ack <= 1'b1;
        //FIFO reset
                    fifo_aclr <= 1'b1;
        
        // ========== 新增：根据sel信号选择区域基地址 ==========
                    case(sel)
                        2'b00: begin // 状态0: 待机状态
                            current_base_addr <= REGION3_BASE;
                            current_region_size <= REGION3_SIZE;
                        end
                        2'b01: begin // 状态1: 实时显示 
                            current_base_addr <= REGION0_BASE;
                            current_region_size <= REGION0_SIZE;
                        end
                        2'b10: begin // 状态2: 拍照储存
                            current_base_addr <= REGION1_BASE;
                            current_region_size <= REGION1_SIZE;
                        end
                        2'b11: begin // 状态3: sd卡图片
                            current_base_addr <= REGION2_BASE;
                            current_region_size <= REGION2_SIZE;
                        end
                        default: begin // 默认回退到区域3
                            current_base_addr <= REGION3_BASE;
                            current_region_size <= REGION3_SIZE;
                        end
                    endcase
            
        // 计算区域边界
                    region_boundary <= current_base_addr + current_region_size;
        
        // 初始化写地址到当前区域基地址
                    App_wr_addr_r <= current_base_addr;
        
        //latch data length
                    write_len_latch <= write_len_d1;                    
                end
    //write data counter reset, write_cnt <= 0;
                write_cnt <= ZERO[ADDR_BITS - 1:0];
            end
			S_CHECK_FIFO:
			begin
				//if there is a write request at this time, enter the 'S_ACK' state
				if(write_req_d2 == 1'b1)
				begin
					state <= S_ACK;
				end
				//if the FIFO space is a burst write request, goto burst write state
				else if(into_burst)
				begin
					state <= S_WRITE_BURST;
					//wr_burst_len <= BURST_SIZE[BURST_BITS - 1:0];
					//wr_burst_req <= 1'b1;
					App_wr_en_r <= 1'b1;
				end
			end 
			
			S_WRITE_BURST:
			begin
				//burst finish
				if(wr_burst_finish == 1'b1)
				begin
					App_wr_en_r <= 1'b0;
					state <= S_WRITE_BURST_END;
					//write counter + burst length
					write_cnt <= write_cnt + BURST_SIZE[ADDR_BITS - 1:0];
					//the next burst write address is generated
					//wr_burst_addr <= wr_burst_addr + BURST_SIZE[ADDR_BITS - 1:0];
				end     
			end
			S_WRITE_BURST_END:
			begin
				//if there is a write request at this time, enter the 'S_ACK' state
				if(write_req_d2 == 1'b1)
				begin
					state <= S_ACK;
				end
				//if the write counter value is less than the frame length, continue writing,
				//otherwise the writing is complete
				else if(write_cnt < write_len_latch)
				begin
					state <= S_CHECK_FIFO;
				end
				else
				begin
					state <= S_END;
				end
			end
			S_END:
			begin
				state <= S_IDLE;
			end
			default:
				state <= S_IDLE;
		endcase
end
endmodule
