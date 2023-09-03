`include "defines.v"

module videogen(
    input clock,
    input VideoMode videoMode,
    input [11:0] counterX,
    input [11:0] counterY,
    input [`RESLINE_SIZE-1:0] resolution_line,
    input [`LAGLINE_SIZE-1:0] lagdisplay_line,
    input state,
    input textgen_trigger,
    input button_trigger,
    output reg starttrigger,
    output reg video_preamble,
    output reg video_guard,
    output reg video_period,
    output reg [23:0] video_data
);
    parameter WHITE_PIXEL = 24'hFF_FF_FF;

    /* video period markers */
    always @(posedge clock) begin
        video_preamble <= counterX >= videoMode.h_total - 10 && counterX < videoMode.h_total - 2 && (counterY == (state ? videoMode.v_total_2 : videoMode.v_total_1) - 1 || counterY < videoMode.v_active - 1);
        video_guard <= counterX >= videoMode.h_total - 2 && counterX < videoMode.h_total && (counterY == (state ? videoMode.v_total_2 : videoMode.v_total_1) - 1 || counterY < videoMode.v_active - 1);
        video_period <= counterX < videoMode.h_active && counterY < videoMode.v_active;
    end

    reg [5:0] frameCounter = 0;
    reg displayFields = 0;
    reg [2:0] metaCounter = 0;

    /* frame counter */
    always @(posedge clock) begin
        if (counterX == 0 && counterY == 0) begin
            if (frameCounter < `FRAME_COUNTER - 1 + metaCounter) begin
                frameCounter <= frameCounter + 1'b1;
            end else begin
                frameCounter <= 0;
            end

            if (frameCounter == 0) begin
                starttrigger <= 1;
                displayFields <= 1;
            end else if (frameCounter > `FRAME_ON_COUNT - 1) begin
                displayFields <= 0;
            end

            metaCounter <= metaCounter + 1'b1;
        end else begin
            starttrigger <= 0;
        end
    end

    // toggle between test area and text report
    reg test_area_active = 1;
    always @(posedge clock) begin
        if (button_trigger) begin
            test_area_active <= 1;
        end else if (textgen_trigger && test_area_active) begin
            test_area_active <= 0;
        end
    end

    wire [11:0] xpos;
    wire [11:0] ypos;
    reg [11:0] resolution_hpos;
    reg [11:0] lagdisplay_hpos1 /* synthesis syn_keep=1 */;
    reg [11:0] lagdisplay_hpos2 /* synthesis syn_keep=1 */;
    reg [11:0] lagdisplay_hpos3 /* synthesis syn_keep=1 */;
    reg [11:0] lagdisplay_hpos4;

    reg test_area;
    reg text_area1;
    reg text_area2;
    reg text_area3;
    reg text_area4;
    reg res_area;
    reg rpos;
    reg pos1;
    reg pos2;
    reg pos3;
    reg pos4;

    assign xpos = counterX;
    assign ypos = counterY;
    always @(posedge clock) begin


        test_area <= (displayFields && 
                   (xpos >= videoMode.h_field_start && xpos < videoMode.h_field_end && 
                   (
                    (ypos >= videoMode.v_field1_start && ypos < videoMode.v_field1_end)
                 || (ypos >= videoMode.v_field2_start && ypos < videoMode.v_field2_end)
                 || (ypos >= videoMode.v_field3_start && ypos < videoMode.v_field3_end)
                )));

         res_area <= (ypos < (12'd16 << videoMode.v_res_divider) 
                    && (xpos >> videoMode.h_res_divider) >= videoMode.h_res_start);

         text_area1 <= (ypos >= videoMode.v_lag_start
            && ypos < videoMode.v_lag_start + (12'd16 << videoMode.v_lag_divider)
            && (xpos >> videoMode.h_lag_divider) >= videoMode.h_lag_start
            && (xpos >> videoMode.h_lag_divider) < videoMode.h_lag_start + 80);
        
         text_area2 <= (ypos >= videoMode.v_lag_start + (12'd16 << videoMode.v_lag_divider)
            && ypos < videoMode.v_lag_start + (12'd32 << videoMode.v_lag_divider)
            && (xpos >> videoMode.h_lag_divider) >= videoMode.h_lag_start
            && (xpos >> videoMode.h_lag_divider) < videoMode.h_lag_start + 120);

          text_area3 <= (ypos >= videoMode.v_lag_start + (12'd32 << videoMode.v_lag_divider)
            && ypos < videoMode.v_lag_start + (12'd48 << videoMode.v_lag_divider)
            && (xpos >> videoMode.h_lag_divider) >= videoMode.h_lag_start
            && (xpos >> videoMode.h_lag_divider) < videoMode.h_lag_start + 192);

           text_area4 <=  (ypos >= videoMode.v_lag_start + (12'd48 << videoMode.v_lag_divider)
            && ypos < videoMode.v_lag_start + (12'd64 << videoMode.v_lag_divider)
            && (xpos >> videoMode.h_lag_divider) >= videoMode.h_lag_start
            && (xpos >> videoMode.h_lag_divider) < videoMode.h_lag_start + 120);

     resolution_hpos <= ((`RESLINE_SIZE - 1) - ((counterX >> videoMode.h_res_divider) - videoMode.h_res_start));
     lagdisplay_hpos1 <= ((`LAGLINE_SIZE - 1) - ((counterX >> videoMode.h_lag_divider) - videoMode.h_lag_start));
     lagdisplay_hpos2 <= ((`LAGLINE_SIZE - 1) - ((counterX >> videoMode.h_lag_divider) - videoMode.h_lag_start))-80;
     lagdisplay_hpos3 <= ((`LAGLINE_SIZE - 1) - ((counterX >> videoMode.h_lag_divider) - videoMode.h_lag_start))-200;
     lagdisplay_hpos4 <= ((`LAGLINE_SIZE - 1) - ((counterX >> videoMode.h_lag_divider) - videoMode.h_lag_start))-392;
     rpos <= resolution_line[resolution_hpos];
     pos1 <= lagdisplay_line[lagdisplay_hpos1];
     pos2 <= lagdisplay_line[lagdisplay_hpos2];
     pos3 <= lagdisplay_line[lagdisplay_hpos3];
     pos4 <= lagdisplay_line[lagdisplay_hpos4];
        
    end

    always @(posedge clock) begin
        // if (test_area_active)
        // begin
            if (test_area) begin
                video_data <= WHITE_PIXEL;
            end else
            //  begin
            //     video_data <= 0;
            // end
        // end else begin
            if (res_area)  begin // resolution info
                if (rpos) begin
                    video_data <= WHITE_PIXEL;
                end else begin
                    video_data <= 0;
                end
            end else if (text_area1) begin
                if (pos1) begin
                    video_data <= WHITE_PIXEL;
                end else begin
                    video_data <= 0;
                end
            end else if (text_area2) begin
                if (pos2) begin
                    video_data <= WHITE_PIXEL;
                end else begin
                    video_data <= 0;
                end
            end else if (text_area3) begin
                if (pos3) begin
                    video_data <= WHITE_PIXEL;
                end else begin
                    video_data <= 0;
                end
            end else if (text_area4) begin
                if (pos4) begin
                    video_data <= WHITE_PIXEL;
                end else begin
                    video_data <= 0;
                end
            end else begin
                video_data <= 0;
            end
        // end
    end
    
endmodule