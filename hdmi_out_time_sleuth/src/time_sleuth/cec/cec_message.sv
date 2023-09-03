module CEC_Message #(
    parameter int PARAMS = 0,
  	parameter bit [7:0] OP_CODE = 8'h04,  // Image View On
    parameter bit [3:0] SRC_ADDR = 4'd14, // Free Use
    parameter bit [3:0] DSC_ADDR = 4'd0   // TV
)
(
    input wire clk,
    input wire rst,
    input logic trigger,
    input logic data_acknowledged,
    input logic data_rejected,
    output logic [7:0] data_out,
    output logic data_eom,
    output logic data_broadcast,
    output logic data_ready
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        SEND_HEADER,
        SEND_OP_CODE,
        SEND_PARAMS
    } state_t;

    state_t state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            data_out <= 8'h00;
            data_eom <= 1'b0;
          	data_broadcast <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (trigger) begin
                        state <= SEND_HEADER;
                        data_out <= {SRC_ADDR, DSC_ADDR};
                        data_eom <= 1'b0;
                        data_ready <= 1'b1;
                      	data_broadcast <= DSC_ADDR == 4'd15;
                    end
                end
                SEND_HEADER: begin
                    data_ready <= 1'b0;
                    if (data_acknowledged) begin
                        state <= SEND_OP_CODE;
                        data_out <= OP_CODE;
                        data_eom <= 1'b1;
                        data_ready <= 1'b1;
                    end else if (data_rejected) begin
                        state <= IDLE;
                    end
                end
                SEND_OP_CODE: begin
                    data_ready <= 1'b0;
                    if (data_acknowledged) begin
                        if (PARAMS == 0) begin
                            state <= IDLE;
                            data_out <= 8'h00;
                            data_eom <= 1'b0;
                            data_ready <= 1'b0;
                        end
                    end else if (data_rejected) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule