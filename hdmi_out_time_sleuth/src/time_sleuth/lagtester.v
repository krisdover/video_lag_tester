`include "defines.v"
`include "video_timing.vh"


module lagtester(
    input clock,

    
    input SENSOR,

    input BUTTON,

    output wire        O_tmds_clk_p,
    output wire        O_tmds_clk_n,
    output wire [2:0]  O_tmds_data_p,
    output wire [2:0]  O_tmds_data_n,

    output wire LED,
    output wire VSYNC,
    output wire HSYNC,
    output wire VA,
    output wire VG,
    inout  wire CEC
);
    wire pixel_clock;
    
    wire sensor_out;
    wire sensor_trigger;

    wire button_out;
    wire button_trigger;
    wire button_trigger_crossed;

    wire config_changed;
    wire [7:0] config_data;

    wire starttrigger;
    wire reset_counter;
    wire [7:0] config_data_crossed;
    wire [79:0] bcdcount_crossed;
    wire [19:0] bcd_current;
    wire [19:0] bcd_minimum;
    wire [19:0] bcd_maximum;
    wire [19:0] bcd_average;
    wire avg_ready_trigger;
    wire avg_ready_trigger_crossed;

    wire tfp410_ready;
    wire hpd_detected;

    wire clk_serial;
    wire hdmi_rstn;

    wire [4:0] RES_CONFIG = 5'b00001 ;

    wire vsync;
    wire hsync;

    wire video_period;
    wire video_guard;
    wire video_preamble;
    wire [23:0] video_data;
    
    wire data_period;
    wire data_guard;
    wire data_preamble;
    wire [8:0] packet_data;
    wire packet_start;
    wire packet_state1;
    wire packet_state2;

    wire cec_send;
    wire cec_in;
    wire cec_out;

    ///////////////////////////////////////////
    // clocks

video_clock video_clock_inst (
  .clk27       (clock), 
  .clock_config(`PIXEL_CLOCK),
  .rstn        (1'b1),
  .hdmi_rstn_o (hdmi_rstn),
  .clk_serial  (clk_serial),
  .clk_pixel   (pixel_clock)
);

hdmi_device hdmi_device (
    .I_rst_n       (hdmi_rstn   ),
    .I_serial_clk  (clk_serial  ),
    .I_clk         (pixel_clock ),
    .I_vsync       (vsync       ),
    .I_hsync       (hsync       ),

    .I_video_preamble   (video_preamble ),
    .I_video_guard      (video_guard    ),
    .I_video_period     (video_period   ),
    .I_video_data       (video_data     ),

    .I_data_preamble      (data_preamble ),
    .I_data_guard         (data_guard    ),
    .I_data_period        (data_period   ),
    .I_packet_data        (packet_data   ),
    .I_packet_start       (packet_start  ),

    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),
    .O_tmds_data_n (O_tmds_data_n )
);
    ///////////////////////////////////////////
    // sensor
    sensor sensor(
        .clock(clock),
        .sensor(SENSOR),
        .sensor_out(sensor_out),
        .sensor_trigger(sensor_trigger)
    );

    ///////////////////////////////////////////
    // button debouncer
    debouncer button(
        .i_clk(pixel_clock),
        .i_switch(BUTTON),
        .o_switch(button_out),
        .o_switch_trigger(button_trigger)
    );

    ///////////////////////////////////////////
    // config
    configuration configuration(
        .clock(clock),
        .config_in(RES_CONFIG),
        .config_data(config_data),
        .config_changed(config_changed)
    );

    ///////////////////////////////////////////
    // measurement
    Flag_CrossDomain reset_control(
        .clkA(pixel_clock),
        .FlagIn_clkA(starttrigger),
        .clkB(clock),
        .FlagOut_clkB(reset_counter)
    );

    measure measure(
        .clock(clock),
        .reset_counter(reset_counter),
        .sensor_trigger(sensor_trigger),
        .reset_bcdoutput(config_changed),
        .bcd_current(bcd_current),
        .bcd_minimum(bcd_minimum),
        .bcd_maximum(bcd_maximum),
        .bcd_average(bcd_average),
        .avg_ready(avg_ready_trigger)
    );

    sync_data_cross #(
        .WIDTH(1)
    ) textgen_control(
        .clkIn(clock),
        .dataIn(avg_ready_trigger),
        .clkOut(pixel_clock),
        .dataOut(avg_ready_trigger_crossed)
    );

    ///////////////////////////////////////////
    // video generator
    data_cross #(
        .WIDTH(8)
    ) video_data_cross (
        .clkIn(clock),
        .clkOut(pixel_clock),
        .dataIn(config_data),
        .dataOut(config_data_crossed)
    );

    data_cross #(
        .WIDTH(80)
    ) bcdcounter_cross (
        .clkIn(clock),
        .clkOut(pixel_clock),
        .dataIn({ bcd_average, bcd_maximum, bcd_minimum, bcd_current }),
        .dataOut(bcdcount_crossed)
    );

    video video(
        .clock(pixel_clock),
        .config_data(config_data_crossed),
        .bcdcount(bcdcount_crossed),
        .textgen_trigger(avg_ready_trigger_crossed),
        .button_trigger(button_trigger),
        .starttrigger(starttrigger),
        .hsync(hsync),
        .vsync(vsync),
        .video_preamble(video_preamble),
        .video_guard(video_guard),
        .video_period(video_period),
        .video_data(video_data),
        .data_preamble(data_preamble),
        .data_guard(data_guard),
        .data_period(data_period),
        .packet_data(packet_data),
        .packet_start(packet_start),
        .packet_state1(packet_state1),
        .packet_state2(packet_state2)
    );
    ///////////////////////////////////////////




reg         vs_r;
reg  [9:0]  cnt_vs;


always@(posedge pixel_clock) begin
  vs_r <= vsync;
end
always@(posedge pixel_clock) begin
    if(vs_r && !vsync) //vs falling edge
        cnt_vs <= cnt_vs + 10'd1;
end

 //assign LED = cnt_vs[6];

 assign LED = sensor_out;
 //   assign TFP410_reset = 1'b1;

//  assign HSYNC = data_period;
//  assign VSYNC = packet_state1;
//  assign VA = packet_state2;
//  assign VG = data_guard;
//  assign VP = data_preamble;

//  assign HSYNC = packet_data[5];
//  assign VSYNC = packet_data[1];
//  assign VA = pixel_clock;
//  assign VG = packet_data[0];
//  assign VP = packet_state2;

assign CEC = cec_send ? 1'bZ : cec_out; // support tri-state inout
assign cec_in = CEC;

endmodule
