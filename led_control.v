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
    
    output  reg  [3:0]   led            //led output
);  

wire [7:0] valids;

led_defualt l_d (.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[0]), .led(led) );
led_flash   l_f (.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[1]), .led(led) );
led_run     l_r (.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[2]), .led(led) );
led_breath  l_br(.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[3]), .led(led) );
led_defualt l_d4(.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[4]), .led(led) );
led_defualt l_d5(.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[5]), .led(led) );
led_defualt l_d6(.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[6]), .led(led) );
led_defualt l_d7(.sys_clk(sys_clk), .rst_n(rst_n), .vaild(valids[7]), .led(led) );

assign valids[0] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //000
assign valids[1] = ~cntl[2] & ~cntl[1] &  cntl[0] ; //001
assign valids[2] = ~cntl[2] &  cntl[1] & ~cntl[0] ; //010
assign valids[3] = ~cntl[2] &  cntl[1] &  cntl[0] ; //011
assign valids[4] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //100
assign valids[5] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //101
assign valids[6] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //110
assign valids[7] = ~cntl[2] & ~cntl[1] & ~cntl[0] ; //111

endmodule
