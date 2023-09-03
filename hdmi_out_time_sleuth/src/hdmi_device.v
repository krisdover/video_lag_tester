/*
my_hdmi_device 

Copyright (C) 2021  Hirosh Dabui <hirosh@dabui.de>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/
module hdmi_device(
    input wire I_clk,
    input wire I_serial_clk, /* 5 times faster of I_clk */
    input wire I_rst_n,

    input wire I_vsync,
    input wire I_hsync,

    input wire I_video_preamble,
    input wire I_video_guard,
    input wire I_video_period,         /* a.k.a Video Data Enable (DE) in DVI */
    input wire [23:0] I_video_data,
    
    input wire I_data_preamble,
    input wire I_data_guard,
    input wire I_data_period,
    input wire [8:0] I_packet_data,
    input wire I_packet_start,

    output wire        O_tmds_clk_p,
    output wire        O_tmds_clk_n,
    output wire [2:0]  O_tmds_data_p,
    output wire [2:0]  O_tmds_data_n
);

localparam OUT_TMDS_MSB = 1;

wire [2:0] out_tmds_data;
wire out_tmds_clk;
wire [9:0] tmds_red;
wire [9:0] tmds_green;
wire [9:0] tmds_blue;

reg [2:0] mode = 3'd1;
reg [23:0] video_data = 24'd0;
reg [5:0] control_data = 6'd0;
reg [11:0] data_island_data = 12'd0;
wire [29:0] tmds_internal;

assign tmds_red = tmds_internal[29:20];
assign tmds_green = tmds_internal[19:10];
assign tmds_blue = tmds_internal[9:0];

always @(posedge I_clk)
begin
    if (!I_rst_n)
    begin
        mode <= 3'd0;
        video_data <= 24'd0;
        control_data <= 6'd0;
        data_island_data <= 12'd0;
    end else begin
        mode <= I_data_guard ? 3'd4 : I_data_period ? 3'd3 : I_video_guard ? 3'd2 : I_video_period ? 3'd1 : 3'd0;
        video_data <= I_video_data;
        control_data <=  {{1'b0, I_data_preamble}, {1'b0, I_video_preamble || I_data_preamble}, {I_vsync, I_hsync}}; // ctrl3, ctrl2, ctrl1, ctrl0, vsync, hsync
        data_island_data[11:4] <= I_packet_data[8:1];
        data_island_data[3] <= I_packet_start;
        data_island_data[2] <= I_packet_data[0];
        data_island_data[1:0] <= {I_vsync, I_hsync};
    end
end

genvar i;
generate
    // TMDS code production.
    for (i = 0; i < 3; i++)
    begin: tmds_gen
        tmds_channel #(.CN(i)) tmds_channel (.clk_pixel(I_clk), .video_data(video_data[i*8+7:i*8]), .data_island_data(data_island_data[i*4+3:i*4]), .control_data(control_data[i*2+1:i*2]), .mode(mode), .tmds(tmds_internal[i*10+9:i*10]));
    end
endgenerate


wire [9:0] tmds_clk = 10'b00000_11111;

OSER10 #(
    .GSREN("false"),
    .LSREN("true")
) oser10_i [3:0] (
    .Q({out_tmds_clk, out_tmds_data}),
    .D0({tmds_clk[0], tmds_red[0], tmds_green[0], tmds_blue[0]}),
    .D1({tmds_clk[1], tmds_red[1], tmds_green[1], tmds_blue[1]}),
    .D2({tmds_clk[2], tmds_red[2], tmds_green[2], tmds_blue[2]}),
    .D3({tmds_clk[3], tmds_red[3], tmds_green[3], tmds_blue[3]}),
    .D4({tmds_clk[4], tmds_red[4], tmds_green[4], tmds_blue[4]}),
    .D5({tmds_clk[5], tmds_red[5], tmds_green[5], tmds_blue[5]}),
    .D6({tmds_clk[6], tmds_red[6], tmds_green[6], tmds_blue[6]}),
    .D7({tmds_clk[7], tmds_red[7], tmds_green[7], tmds_blue[7]}),
    .D8({tmds_clk[8], tmds_red[8], tmds_green[8], tmds_blue[8]}),
    .D9({tmds_clk[9], tmds_red[9], tmds_green[9], tmds_blue[9]}),
    .PCLK(I_clk),
    .FCLK(I_serial_clk),
    .RESET(~I_rst_n)
);

TLVDS_OBUF tlvds_obuf_i[3:0] (
    .O({O_tmds_clk_p,O_tmds_data_p}),
    .OB({O_tmds_clk_n,O_tmds_data_n}),
    .I({out_tmds_clk, out_tmds_data})
);


endmodule
