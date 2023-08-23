`include "defines.v"
`include "config/video_modes.v"
import my_types::*;

module video(
    input clock,
    input [7:0] config_data,
    input [79:0] bcdcount,
    input textgen_trigger,
    input button_trigger,
    output hsync,
    output vsync,
    output video_preamble,
    output video_guard,
    output video_period,
    output [23:0] video_data,
    output data_preamble,
    output data_guard,
    output data_period,
    output [8:0] packet_data,
    output packet_start,
    output packet_state1,
    output packet_state2,
    output starttrigger
);
    wire [11:0] counterX;
    wire [11:0] counterY;
    wire [`RESLINE_SIZE-1:0] resolution_line;
    wire [`LAGLINE_SIZE-1:0] lagdisplay_line;
    wire state;
    VideoMode videoMode;

    // assign videoMode = VIDEO_MODE_1080P;
    assign videoMode = VIDEO_MODE_720P;
    // assign videoMode = VIDEO_MODE_480P;
/*
  always @(posedge clock) begin
        if (config_data[0])
            videoMode <= VIDEO_MODE_720P;
        else
            videoMode<= VIDEO_MODE_480P;
    end
*/
/*
    video_config video_config(
        .clock(clock),
        .data_in(`MODE_720p ),
        .videoMode(videoMode));
*/

/*
    video_config video_config(
        .clock(clock),
        .data_in(config_data),
        .videoMode(videoMode)
    );
*/
    timingsgen timingsgen(
        .clock(clock),
        .videoMode(videoMode),
        .counterX(counterX),
        .counterY(counterY),
        .hsync(hsync),
        .vsync(vsync),
        .state(state)
    );

    textgen textgen(
        .clock(clock),
        .videoMode(videoMode),
        .counterX(counterX),
        .counterY(counterY),
        .bcdcount(bcdcount),
        .resolution_line(resolution_line),
        .lagdisplay_line_out(lagdisplay_line)
    );

    videogen videogen(
        .clock(clock),
        .videoMode(videoMode),
        .counterX(counterX),
        .counterY(counterY),
        .resolution_line(resolution_line),
        .lagdisplay_line(lagdisplay_line),
        .state(state),
        .textgen_trigger(textgen_trigger),
        .button_trigger(button_trigger),
        .starttrigger(starttrigger),
        .video_preamble(video_preamble),
        .video_guard(video_guard),
        .video_period(video_period),
        .video_data(video_data)
    );

    datagen datagen(
        .clock(clock),
        .videoMode(videoMode),
        .counterX(counterX),
        .counterY(counterY),
        .data_preamble(data_preamble),
        .data_guard(data_guard),
        .data_period(data_period),
        .packet_data(packet_data),
        .packet_start(packet_start),
        .packet_state1(packet_state1),
        .packet_state2(packet_state2)
    );
endmodule