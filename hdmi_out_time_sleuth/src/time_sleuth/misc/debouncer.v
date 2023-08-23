module debouncer(
    input i_clk,
    input i_switch,
    output reg o_switch,
    output o_switch_trigger
);
  reg tmp_state = 0;
  reg tmp_prev_state = 0;
  wire tmp_trigger;
  
  reg [19:0] cnt = 0;
  reg prev_state = 0;
  
  initial begin
  	o_switch = 0;
  end
  
  assign tmp_trigger = tmp_prev_state ^ tmp_state;
  
  always @(posedge i_clk) begin
    tmp_state <= ~i_switch;
    tmp_prev_state <= tmp_state;
    
    // reset counter when switch changes
    if (tmp_trigger) begin
    	cnt <= 0;
    end else begin
      // debounce over timeout (1ms typical, 6.5ms max)
      // 2^19 ~= 524k counts in 7ms @ i_clk = 74.25Mhz
      if (~cnt[19]) begin
        cnt <= cnt + 20'd1;
      end else begin
        o_switch <= tmp_state;
        prev_state <= o_switch;
      end
    end
  end
  
  assign o_switch_trigger = ~prev_state && o_switch;
endmodule