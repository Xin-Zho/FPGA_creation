/************************************************************
**-----------------------------------------------------------
** file name        : led_default
** usage            : 灯默认状态
**-----------------------------------------------------------
************************************************************/
module led_default( 
    input sys_clk   ,                   //50mHz, system clock
    input rst_n     ,                   //reset sign ,1 then reset
    input valid     ,                   //vaild sign ,1 then led begin nolight
    
    output  reg [3:0]   led            //led output
);

always @(posedge sys_clk or negedge rst_n )begin
    if(!rst_n)
        led <= 4'b0;
    else if (valid) begin  
        led <= 4'b0;
    end 
    else
        led <= 4'b0;
end


endmodule
