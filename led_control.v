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

wire [7:0] valids;
wire [3:0] led0, led1, led2, led3, led4, led5, led6, led7;

led_default l_d (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[0]), .led(led0) );
led_flash   l_f (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[1]), .led(led1) );
led_run     l_r (.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[2]), .led(led2) );
led_breath  l_br(.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[3]), .led(led3) );
led_default l_d4(.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[4]), .led(led4) );
led_default l_d5(.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[5]), .led(led5) );
led_default l_d6(.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[6]), .led(led6) );
led_default l_d7(.sys_clk(sys_clk), .rst_n(rst_n), .valid(valids[7]), .led(led7) );

assign valids[0] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //000
assign valids[1] = ~cntl[2] & ~cntl[1] &  cntl[0] ; //001
assign valids[2] = ~cntl[2] &  cntl[1] & ~cntl[0] ; //010
assign valids[3] = ~cntl[2] &  cntl[1] &  cntl[0] ; //011
assign valids[4] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //100
assign valids[5] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //101
assign valids[6] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //110
assign valids[7] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //111

assign led = valids[0] ? led0 :
             valids[1] ? led1 :
             valids[2] ? led2 :
             valids[3] ? led3 :
             valids[4] ? led4 :
             valids[5] ? led5 :
             valids[6] ? led6 :
             led7;

endmodule
