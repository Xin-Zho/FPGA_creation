/************************************************************
**-----------------------------------------------------------
** file name        : led_defualt
** usage            : 灯默认状态
**-----------------------------------------------------------
************************************************************/
module led_defualt( 
    input sys_clk   ,                   //50mHz, system clock
    input rst_n     ,                   //reset sign ,1 then reset
    input vaild     ,                   //vaild sign ,1 then led begin flash
    
    output  reg [3:0]   led            //led output
);

always @(posedge sys_clk or negedge rst_n )begin
    if(!rst_n)
        led <= 4'b0;
    else if (vaild) begin  
        led <= 4'b0;
    end 
    else
        led <= 4'b0;
end


endmodule
