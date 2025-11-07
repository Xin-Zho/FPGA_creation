module selector_screen( 
    
    input               image_en,
    input   [31:0]      image_data,
    
    input               video_en,
    input   [31:0]      video_data,
    
    input   key,
    
    output              screen_en,
    output  [31:0]      screen_data   

);

wire is_send_image;
assign is_send_image = ~key ;

wire is_send_video;
assign is_send_video = key  ;

assign screen_en = is_send_image | is_send_video;

assign screen_data = is_send_image ? image_data :
                     is_send_video ? video_data :
                     32'b0;


endmodule
