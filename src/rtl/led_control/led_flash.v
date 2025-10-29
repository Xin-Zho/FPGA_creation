/************************************************************
**-----------------------------------------------------------
** file name        : led_flash
** usage            : 0.2s周期闪光灯
**-----------------------------------------------------------
************************************************************/
module led_flash( 
    input sys_clk   ,                   //50mHz, system clock
    input rst_n     ,                   //reset sign ,1 then reset
    input valid     ,              //vaild sign ,1 then led begin flash
    
    output  reg  [3:0]   led     //led output
);

localparam LED_PREIOD = 24'd9_999_999;       //led preiod 

reg     [23:0]      cnt;        //0.1s counter, unit :1ns 

always @(posedge sys_clk or negedge rst_n )begin
    if(!rst_n)
        cnt <= 24'd0;
    else if(valid)begin
        if (cnt < LED_PREIOD)
            cnt <= cnt + 1'b1;
        else
            cnt <= 24'd0;
    end
    else
        cnt <= 24'd0;
end


always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)
        led[3:0] = 4'b0000;
    else if(valid) begin
        if(cnt == LED_PREIOD)begin
            led[0] <= ~led[0];
            led[1] <= ~led[1];
            led[2] <= ~led[2];
            led[3] <= ~led[3];
       end
    end
    else led[3:0] <= 4'b0000;   
end

endmodule