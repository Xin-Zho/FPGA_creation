module demo1( 
       input sys_clk,
       input rst,
       output [3:0] led
 );
 
    reg [15:0] period_cnt;
    reg [15:0] duty_cycle;
    reg flag;
    
    assign led[0] = (period_cnt >= duty_cycle)? 1'b1 : 1'b0;
    assign led[1] = (period_cnt >= duty_cycle)? 1'b1 : 1'b0;
    assign led[2] = (period_cnt >= duty_cycle)? 1'b1 : 1'b0;
    assign led[3] = (period_cnt >= duty_cycle)? 1'b1 : 1'b0;

    always @(posedge sys_clk or negedge rst) begin
        if(!rst)
            period_cnt <= 16'd0;
        else if(period_cnt == 16'd50000)
            period_cnt <= 16'd0;
        else
            period_cnt <= period_cnt + 1'b1 ;
    end

    always @(posedge sys_clk or negedge rst) begin
        if(!rst)begin
            duty_cycle <= 16'd0;
            flag <= 1'b0;
        end
        else begin
            if (period_cnt == 16'd50000 )begin
                if(flag == 1'b0)begin
                    if(duty_cycle == 16'd50000)
                        flag <= 1'b1;
                    else
                        duty_cycle =duty_cycle + 16'd25;
                end
                else begin
                    if (duty_cycle == 16'd0)
                        flag <= 1'b0;
                    else
                        duty_cycle =duty_cycle - 16'd25;
                end
            end
        end
    end

endmodule
