`include "defines.v"

module datagen(
    input clock,
    input VideoMode videoMode,
    input [11:0] counterX,
    input [11:0] counterY,
    output reg data_preamble,
    output reg data_guard,
    output reg data_period,
    output [8:0] packet_data,
    output reg packet_start
);

    /* data island calculations, as per HDMI-1.3 Spec Section 5.2.3.1 */
    reg [4:0] max_num_packets_alongside;
    reg [4:0] num_packets_alongside = 5'd0; // 5'd3;
    always @(posedge clock) begin
        max_num_packets_alongside = (videoMode.h_total - videoMode.h_active /* VD period */ - 2 /* V guard */ - 8 /* V preamble */ - 4 /* Min VI control period */ - 2 /* DI trailing guard */ - 2 /* DI leading guard */  - 8 /* DI premable */ - 4 /* Min data control period */) / 32;
        if (max_num_packets_alongside > 18) begin
            num_packets_alongside = 5'd18;
        end else begin
            num_packets_alongside = 5'(max_num_packets_alongside);
        end
    end

    // cutdown version of https://github.com/hdl-util/hdmi/blob/master/src/packet_picker.sv
    reg [1:0] packet_index = 2'd0; // we only support 3 here, null (0), AVI InfoFrame (1) & SPD InfoFrame (2)
    reg [23:0] headers [2:0];
    reg [55:0] subs [2:0] [3:0];

    // packet_type 5'h82
    auxiliary_video_information_info_frame auxiliary_video_information_info_frame(
        .header(headers[1]),
        .sub(subs[1])
    );
    // packet_type 5'h83
    source_product_description_info_frame #(
        .VENDOR_NAME({"Unknown", 8'h00}),
        .PRODUCT_DESCRIPTION({"FPGA", 96'd0}),
        .SOURCE_DEVICE_INFORMATION(8'h00)
    ) source_product_description_info_frame (
        .header(headers[2]),
        .sub(subs[2])
    );

    packet_assembler packet_assembler (
        .clk_pixel(clock),
        .reset(packet_enable),
        .data_island_period(data_period),
        .header(headers[packet_index]),
        .sub(subs[packet_index]),
        .packet_data(packet_data)
    );

    wire data_island_period_instantaneous;
    assign data_island_period_instantaneous = num_packets_alongside > 0 && counterX >= videoMode.h_active + 14 && counterX < videoMode.h_active + 14 + num_packets_alongside * 32;
    wire packet_enable;
    assign packet_enable = data_island_period_instantaneous && 5'(counterX + videoMode.h_active + 18) /* enable a packet every 32 pixels (mod 32) */ == 5'd0;
    wire video_field_end;
    assign video_field_end = counterX == videoMode.h_active - 1'b1 && counterY == videoMode.v_active - 1'b1;

    reg auxiliary_video_information_info_frame_sent = 1'b0;
    reg source_product_description_info_frame_sent = 1'b0;
    always @(posedge clock) begin
        if (video_field_end) begin
            auxiliary_video_information_info_frame_sent <= 1'b0;
            source_product_description_info_frame_sent <= 1'b0;
            packet_index <= 2'd0;
        end else if (packet_enable) begin
            if (auxiliary_video_information_info_frame_sent == 0) begin
                packet_index <= 2'd1;
                auxiliary_video_information_info_frame_sent <= 1'b1;
            end else if (source_product_description_info_frame_sent == 0) begin
                packet_index <= 2'd2;
                source_product_description_info_frame_sent <= 1'b1;
            end else begin
                // send null packet
                packet_index <= 2'd0;
            end
        end
    end

    /* data island period markers */
    always @(posedge clock) begin
        data_preamble <= num_packets_alongside > 0 && counterX >= videoMode.h_active + 4 && counterX < videoMode.h_active + 12;
        data_guard <= num_packets_alongside > 0 && (
            (counterX >= videoMode.h_active + 12 && counterX < videoMode.h_active + 14) /* leading guard */ 
         || (counterX >= videoMode.h_active + 14 + num_packets_alongside * 32 && counterX < videoMode.h_active + 16 + num_packets_alongside * 32) /* trailing guard */
        );
        data_period <= data_island_period_instantaneous;
        packet_start <= counterX == videoMode.h_active + 14 ? 1'b0 : 1'b1;
    end
endmodule