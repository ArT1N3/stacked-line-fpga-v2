module blink_led
(
 
    input sys_clk50m, 
    output[3:0] led 
);
 
 
//  wire sys_clk50m;
//  GW_OSC osc_inst ( .oscout(sys_clk50m)) ;
 
 
localparam clk500ms = 50_000_000;  
reg[31:0] clk_count;
 
always @(posedge sys_clk50m)
begin
    if( clk_count ==clk500ms)
        clk_count <=0;
    else 
        clk_count <= clk_count + 1'd1;
end
 
wire led_temp;
assign led_temp =( clk_count> clk500ms[31:1]) ? 1'b0: 1'b1;
 
assign led= {led_temp,~led_temp,led_temp,~led_temp};
 
//assign led =1'b0;
 
endmodule
 
