module timingsgen(
    input clock,
    input VideoMode videoMode,
    output reg [11:0] counterX,
    output reg [11:0] counterY,
    output reg hsync,
    output reg vsync,
    output reg state
);
    /*
        Timing layout:
        H_BACK_PORCH H_SYNC H_FRONT_PORCH  H_ACTIVE
        V_BACK_PORCH V_SYNC V_FRONT_PORCH  V_ACTIVE
    */

    /* generate counter */
    always @(posedge clock) begin
        if (counterX < videoMode.h_total - 1) begin
            counterX <= counterX + 1'b1;
        end else begin
            counterX <= 0;
            if (counterY < (state ? videoMode.v_total_2 : videoMode.v_total_1) - 1) begin
                counterY <= counterY + 1'b1;
            end else begin
                counterY <= 0;
                state <= ~state;
            end
        end
    end

    /* generate hsync & vsync control timings */
    always @(posedge clock) begin
        hsync <= (~videoMode.h_sync_pol) ^ (counterX >= videoMode.h_active + videoMode.h_front_porch && counterX < videoMode.h_active + videoMode.h_front_porch + videoMode.h_sync);
        // vsync pulses should begin and end at the start of hsync, so special
        // handling is required for the lines on which vsync starts and ends
        // See VESA-DMT Spec Section 3.5
        if (counterY == (videoMode.v_active + videoMode.v_front_porch - 1)) begin
            vsync <= (~videoMode.v_sync_pol) ^ (counterX >= videoMode.h_active + videoMode.h_front_porch);
        end else if (counterY == (videoMode.v_active + videoMode.v_front_porch + videoMode.v_sync - 1)) begin
            vsync <= (~videoMode.v_sync_pol) ^ (counterX < videoMode.h_active + videoMode.h_front_porch);
        end else begin
            vsync <= (~videoMode.v_sync_pol) ^ (counterY >= videoMode.v_active + videoMode.v_front_porch && counterY < videoMode.v_active + videoMode.v_front_porch + videoMode.v_sync);
        end
    end
endmodule