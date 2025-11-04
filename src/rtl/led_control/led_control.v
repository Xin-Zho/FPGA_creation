/************************************************************
**-----------------------------------------------------------
** file name        : led_control
** usage            : 灯光控制模块
**-----------------------------------------------------------
** cntl input: cntl信号 -> led模式
**      000 -> defualt, all unlight
**      001 -> led_flash
**      010 -> led_run
**      011 -> led_breath
**      otherwise -> defualt, all unlight
**-----------------------------------------------------------
************************************************************/
module led_control( 
    input sys_clk   ,                   //50mHz, system clock
    input rst_n     ,                   //reset sign  ,1 then reset
    input   [3:0]    cntl,              //contrl sign ,decide use which kind of led
    
    output  [3:0]   led            //led output
);  

wire [15:0]  valids;
wire [3:0]  led0,   //0000 default  
            led1,   //0001 normal
            led2,   //0010 flash
            led3,   //0011 breath
            led4,   //0100 flash breath/single breath
            led5,   //0101 run
            led6,   //0110 re run
            led7,   //0111 loop run
            led8,   //1000 default
            led9,   //1001 default
            led10,  //1010 default
            led11,  //1011 default
            led12,  //1100 default
            led13,  //1101 default
            led14,  //1110 default
            led15;  //1111 default

led_default l_d     (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[0]), .led(led0) );
led_normal  l_n     (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[1]), .led(led1) );
led_flash   l_f     (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[2]), .led(led2) );
led_breath  l_br    (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[3]), .led(led3) );
led_flashbr l_fbr   (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[4]), .led(led4) );
led_run     l_r     (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[5]), .led(led5) );
led_run_re  l_rr    (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[6]), .led(led6) );
led_run_lp  l_rl    (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[7]), .led(led7) );
led_default l_d8    (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[8]), .led(led8) );
led_default l_d9    (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[9]), .led(led9) );
led_default l_d10   (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[10]), .led(led10) );
led_default l_d11   (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[11]), .led(led11) );
led_default l_d12   (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[12]), .led(led12) );
led_default l_d13   (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[13]), .led(led13) );
led_default l_d14   (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[14]), .led(led14) );
led_default l_d15   (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[15]), .led(led15) );

assign valids[0] = ~cntl[3] & ~cntl[2] & ~cntl[1] & ~cntl[0] ; //0000
assign valids[1] = ~cntl[3] & ~cntl[2] & ~cntl[1] &  cntl[0] ; //0001
assign valids[2] = ~cntl[3] & ~cntl[2] &  cntl[1] & ~cntl[0] ; //0010
assign valids[3] = ~cntl[3] & ~cntl[2] &  cntl[1] &  cntl[0] ; //0011
assign valids[4] = ~cntl[3] &  cntl[2] & ~cntl[1] & ~cntl[0] ; //0100
assign valids[5] = ~cntl[3] &  cntl[2] & ~cntl[1] &  cntl[0] ; //0101
assign valids[6] = ~cntl[3] &  cntl[2] &  cntl[1] & ~cntl[0] ; //0110
assign valids[7] = ~cntl[3] &  cntl[2] &  cntl[1] &  cntl[0] ; //0111
assign valids[8] = 	cntl[3] & ~cntl[2] & ~cntl[1] & ~cntl[0] ; //1000
assign valids[9] = 	cntl[3] & ~cntl[2] & ~cntl[1] &  cntl[0] ; //1001
assign valids[10]= 	cntl[3] & ~cntl[2] &  cntl[1] & ~cntl[0] ; //1010
assign valids[11]= 	cntl[3] & ~cntl[2] &  cntl[1] &  cntl[0] ; //1011
assign valids[12]= 	cntl[3] &  cntl[2] & ~cntl[1] & ~cntl[0] ; //1100
assign valids[13]= 	cntl[3] &  cntl[2] & ~cntl[1] &  cntl[0] ; //1101
assign valids[14]= 	cntl[3] &  cntl[2] &  cntl[1] & ~cntl[0] ; //1110
assign valids[15]= 	cntl[3] &  cntl[2] &  cntl[1] &  cntl[0] ; //1111


assign led = valids[0] ? led0 :
             valids[1] ? led1 :
             valids[2] ? led2 :
             valids[3] ? led3 :
             valids[4] ? led4 :
             valids[5] ? led5 :
             valids[6] ? led6 :
             valids[7] ? led7 :
             valids[8] ? led8 :
             valids[9] ? led9 :
             valids[10] ? led10 :
             valids[11] ? led11 :
             valids[12] ? led12 :
             valids[13] ? led13 :           
             valids[14] ? led14 :
             led15 ;            
endmodule
