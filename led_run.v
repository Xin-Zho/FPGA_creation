/************************************************************
**-----------------------------------------------------------
** file name        : led_run
** usage            : 0.8s周期流水灯
**-----------------------------------------------------------
************************************************************/
module led_run( 
    input sys_clk   ,                   //50Hz, system clock
    input rst_n     ,                   //reset sign ,1 then reset
    input vaild     ,                   //vaild sign ,1 then led begin flash
    
    output  reg  [3:0]   led            //led output
 );

localparam LED_PREIOD = 24'd9_999_999;       //led preiod / 8

reg     [23:0]      cnt;        //0.1s counter, unit :1ns

reg     [1:0]       led_state ; 

always @(posedge sys_clk or negedge rst_n )begin
    if(!rst_n)
        cnt <= 24'd0;
    else if (cnt < LED_PREIOD)
        cnt <= cnt + 1'b1;
    else
        cnt <= 24'd0;
end

always @(posedge sys_clk or negedge rst_n )begin
    if(!rst_n)
        led_state <= 2'd0;
    else if (vaild)begin
        if (cnt == LED_PREIOD )
            led_state <= led_state + 1'b1;
        else 
            led_state <= led_state;
    end
    else
        led_state <= 2'd0;
end


always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)
        led[3:0] <= 4'b0;
    else if(vaild) begin
        case (led_state)
            2'b00: led <= 4'b1000;
            2'b01: led <= 4'b0100;
            2'b10: led <= 4'b0010;
            2'b11: led <= 4'b0001;
            default: led <= 4'b0000;
        endcase 
    end
    else 
        led[3:0] <= 4'b0;   
end


endmodule
