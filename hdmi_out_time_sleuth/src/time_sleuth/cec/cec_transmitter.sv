module CEC_Transmitter (
    input wire clk,
    input wire rst,
    input wire [7:0] data_out,
    input wire data_eom,
    input wire data_broadcast,
    input wire cec_in,
    output wire cec_send,
    output wire cec_out,
    output wire byte_acknowledged
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        ACKNOWLEDGE
    } state_t;

    state_t state;

    logic [3:0] bit_count;
    logic [8:0] current_byte;
    logic is_bit_duration;
    logic [16:0] bit_timer;

    // Constants for bit timing @27MHz
    localparam START_BIT_TIME =     17'd99_900;  // 3.7ms
    localparam START_BIT_DURATION = 17'd21_600;  // 0.8ms
    localparam LOGIC_0_TIME =       17'd40_500;  // 1.5ms
    localparam LOGIC_0_DURATION =   17'd24_300;  // 0.9ms
    localparam LOGIC_1_TIME =       17'd16_200;  // 0.6ms
    localparam LOGIC_1_DURATION =   17'd48_600;  // 1.8ms

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            next_state <= IDLE;
            bit_count <= 0;
            current_byte <= 0;
            is_bit_duration <= 0;
            bit_timer <= 0;
        end else begin
            case (state)
                IDLE: begin
                    state <= START_BIT;
                    bit_count <= 0;
                    bit_timer <= START_BIT_TIME;
                    is_bit_duration <= 0;
                end
                START_BIT: begin
                    if (bit_timer == 0) begin
                        if (!is_bit_duration) begin
                            bit_timer <= START_BIT_DURATION;
                            bit_count <= 0;
                            current_byte <= {data_out, data_eom}; // Data bits + EOM bit
                            is_bit_duration <= 1;
                        end else begin
                            state <= DATA_BITS;
                            bit_timer <= current_byte[4'd7 - bit_count] ? LOGIC_1_TIME : LOGIC_0_TIME;
                            bit_count <= bit_count + 1;
                            is_bit_duration <= 0;
                        end;
                    end
                end
                DATA_BITS: begin
                    if (bit_timer == 0) begin
                        if (bit_count < 4'd8) begin
                            if (!is_bit_duration) begin
                                bit_timer <= current_byte[4'd7 - bit_count] ? LOGIC_1_DURATION : LOGIC_0_DURATION;
                                bit_count <= bit_count + 1;
                                is_bit_duration <= 1;
                            end else begin
                                bit_timer <= current_byte[4'd7 - bit_count] ? LOGIC_1_TIME : LOGIC_0_TIME;
                                is_bit_duration <= 0;
                            end;
                        end else begin
                            state <= ACKNOWLEDGE;
                            is_bit_duration <= 0;
                            bit_timer <= LOGIC_1_TIME; // Always send a logic 1 acknowledge bit
                            bit_count <= 0;
                        end
                    end
                end
                ACKNOWLEDGE: begin
                    if (bit_timer == 0) begin
                        if (!is_bit_duration) begin
                            bit_timer <= LOGIC_1_DURATION;
                            is_bit_duration <= 1;
                        end else begin
                            state <= IDLE;
                            is_bit_duration <= 0;
                        end;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cec_out <= 1'b1;
            cec_send <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    cec_send <= 1'b1;
                    cec_out <= 1'b1;
                end
                START_BIT, DATA_BITS: begin
                    cec_out <= is_bit_duration ? 1'b1 : 1'b0;
                end
                ACKNOWLEDGE:
                    if (!is_bit_duration) begin
                        cec_out <= 1'b0;
                    end else begin
                        cec_out <= 1'b1;
                        cec_send <= 1'b0; // switch to read cec_in
                    end
            endcase
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_timer <= 0;
        end else if (bit_timer > 0) begin
            bit_timer <= bit_timer - 1;
        end
    end

    assign byte_acknowledged =
        state == ACKNOWLEDGE && 
        is_bit_duration && 
        cec_in == (data_broadcast ? 1'b1 : 1'b0); // Detect acknowledge condition

endmodule
