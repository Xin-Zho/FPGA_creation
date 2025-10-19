module demo2( 
    input sys_clk ,
    input sys_rst ,
    
    input [3:0] key,
    output reg [3:0] led
);

    reg [23:0] cnt;// counter
    reg [1:0] led_state;// led 4 stages

    //COUNTER
    always@(posedge sys_clk or negedge sys_rst)begin
        
         if(!sys_rst)
            cnt <= 24'd0;
         else if (cnt < 24'd9_999_999) 
            cnt <= 1'b1 + cnt;
         else
            cnt <= 24'd0;  
        
    end

    //LED STATE CHOOSER
    always@(posedge sys_clk or negedge sys_rst)begin
        
        if(!sys_rst)
            led_state <= 2'b00;
        else if (cnt == 24'd9_999_999) 
            led_state <= led_state + 1'b1;
        else
            led_state <= led_state;
            
    end
    
    //LED STATE ACTIVITY
    always@(posedge sys_clk or negedge sys_rst)begin
        
        if(!sys_rst)
            led[3:0] <= 4'b0000;
            
        else if(key[0]==0)
            case(led_state)
                2'b00   :led[3:0] <= 4'b1000;
                2'b01   :led[3:0] <= 4'b0100;
                2'b10   :led[3:0] <= 4'b0010;
                2'b11   :led[3:0] <= 4'b0001;
                default :led[3:0] <= 4'b0000;
            endcase
        else if(key[1]==0)
            case(led_state)
                2'b00   :led[3:0] <= 4'b0001;
                2'b01   :led[3:0] <= 4'b0010;
                2'b10   :led[3:0] <= 4'b0100;
                2'b11   :led[3:0] <= 4'b1000;
                default :led[3:0] <= 4'b0000;
            endcase
        else if(key[2]==0)
            case(led_state)
                2'b00   :led[3:0] <= 4'b1111;
                2'b01   :led[3:0] <= 4'b0000;
                2'b10   :led[3:0] <= 4'b1111;
                2'b11   :led[3:0] <= 4'b0000;
                default :led[3:0] <= 4'b0000;
            endcase
        else if(key[3]==0)
            led[3:0] <= 4'b1111;
        else
            led <= 4'b0000;
    end
endmodule
