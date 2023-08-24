module CEC_Transmitter (
    input wire clk,
    input wire rst,
    input wire data_ready,
    input wire [7:0] data_out,
    input wire data_eom,
    input wire data_broadcast,
    input wire cec_in,
    output reg cec_send,
    output reg cec_out,
    output reg byte_acknowledged
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        ACKNOWLEDGE
    } state_t;

    state_t state;
    state_t next_state;

    logic [3:0] bit_count;
    logic [8:0] current_byte;
    logic [16:0] bit_timer;
    logic [16:0] bit_high_time;
    logic is_bit_high_time;

    // Constants for bit timing @27MHz
    localparam START_BIT_TIME =     17'd99_900;  // 3.7ms
    localparam START_BIT_DURATION = 17'd121_500; // 4.5ms
    localparam LOGIC_0_TIME =       17'd40_500;  // 1.5ms
    localparam LOGIC_1_TIME =       17'd16_200;  // 0.6ms
    localparam DATA_BIT_DURATION =  17'd64_800;  // 2.4ms

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            next_state <= START_BIT;
            current_byte <= 0;
            bit_timer <= 0;
            bit_high_time <= 0;
            bit_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (data_ready) begin
                        state <= next_state;
                        bit_timer <= 0;
                        bit_high_time <= 0;
                        bit_count <= 0;
                    end
                end
                START_BIT: begin
                    if (bit_timer == 0) begin
                        if (next_state != DATA_BITS) begin
                            next_state <= DATA_BITS;
                            bit_timer <= START_BIT_DURATION;
                            bit_high_time <= START_BIT_DURATION - START_BIT_TIME;
                            current_byte <= {data_out, data_eom}; // Data bits + EOM bit
                        end else begin
                            state <= next_state;
                        end
                    end
                end
                DATA_BITS: begin
                    if (bit_timer == 0) begin
                        if (bit_count < 4'd9) begin
                            bit_timer <= DATA_BIT_DURATION;
                            bit_high_time <= current_byte[4'd8 - bit_count] ? 
                                (DATA_BIT_DURATION - LOGIC_1_TIME) : (DATA_BIT_DURATION - LOGIC_0_TIME);
                            bit_count <= bit_count + 1;
                        end else begin
                            state <= ACKNOWLEDGE;
                            bit_count <= 0;
                        end
                    end
                end
                ACKNOWLEDGE: begin
                    if (bit_timer == 0) begin
                        if (next_state != IDLE) begin
                            next_state <= IDLE;
                            bit_timer <= DATA_BIT_DURATION;
                            bit_high_time <= DATA_BIT_DURATION - LOGIC_1_TIME; // ACK sent as logic 1
                        end else begin
                            state <= next_state;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
        if (bit_timer > 0) begin
            bit_timer <= bit_timer - 1;
        end
    end

    assign is_bit_high_time = bit_high_time > 0 && bit_timer <= bit_high_time;

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
                    cec_out <= is_bit_high_time;
                end
                ACKNOWLEDGE:
                    cec_out <= is_bit_high_time;
                    if (is_bit_high_time) begin
                        cec_send <= 1'b0; // switch to read cec_in
                    end
            endcase
        end
    end

    assign byte_acknowledged =
        state == ACKNOWLEDGE && 
        is_bit_high_time && 
        cec_in == (data_broadcast ? 1'b1 : 1'b0); // Detect acknowledge condition

endmodule
