/************************************************************
**-----------------------------------------------------------
** file name        : led_breath
** usage            : 4s周期呼吸灯
**-----------------------------------------------------------
************************************************************/
module led_breath( 
    input sys_clk   ,                   //50mHz, system clock
    input rst_n     ,                   //reset sign ,1 then reset
    input valid     ,                   //vaild sign ,1 then led begin breath
    
    output  reg [3:0]   led            //led output
 );

localparam LED_PREIOD = 16'd50_000;       // led preiod / 20
reg     [15:0]      cnt;                  // 0.001s counter, unit :1ns, 
reg     [15:0]      circle_cnt;           // 0.02s  conuter, unit :(+25 unit)/0.001s, until 2_000_000_000 unit 
reg     flag;                             // circle_cnt direction sign
                                                // 1，circle_cnt increase ; 0, circle_cnt decrease  
always @(posedge sys_clk or negedge rst_n )begin
    if(!rst_n)
        cnt <= 16'd0;
    else if (valid) begin  
        if (cnt <= LED_PREIOD)
            cnt <= cnt + 1'b1;
        else
            cnt <= 16'd0;
    end 
    else
        cnt <= 16'd0;
end

always @(posedge sys_clk or negedge rst_n )begin
    //changing per 0.001s, make led like breath
    if(!rst_n)
        led <= 4'b0;
    else if (valid)
        led <= (cnt >= circle_cnt)? 4'b1111 : 4'b0000;
    else
        led <= 4'b0;
end

always @(posedge sys_clk or negedge rst_n )begin
    if(!rst_n)begin
        flag <= 1'b1;
        circle_cnt <= 16'b0;
    end
    
    else if(valid)begin
    
        //changing per 0.001s
        if(cnt == LED_PREIOD)begin
            
            if(flag)begin//increase
            
                if(circle_cnt == LED_PREIOD)
                    flag <= ~flag;//reserve
                else
                    circle_cnt <= circle_cnt + 5'd25;
            
            end
            else begin//decrease
            
                if(circle_cnt == 16'b0)
                    flag <= ~flag;//reserve
                else
                    circle_cnt <= circle_cnt - 5'd25;
            
            end    
            
        end
        
    end
    
    else begin
        flag <= 1'b1;
        circle_cnt <= 16'b0;
    end
end

endmodule
