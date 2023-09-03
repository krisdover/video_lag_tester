module CEC_Transmitter #(
  	parameter int CLK_KHZ = 27000, // 27MHz
	parameter int MAX_RETRIES = 1
)
(
    input wire clk,
    input wire rst,
    input wire data_ready,
    input wire [7:0] data_out,
    input wire data_eom,
    input wire data_broadcast,
    input wire cec_in,
    output reg cec_send,
    output reg cec_out,
    output reg data_acknowledged,
  	output reg data_rejected
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        ACKNOWLEDGE,
        RETRANSMIT,
        NEXT_FRAME
    } state_t;

    state_t state;
  
    logic [3:0] bit_count;
    logic [8:0] current_frame;
    logic [16:0] bit_timer;
    logic [16:0] bit_high_time;
    logic is_bit_high_time;
  	logic acknowledge_bit;
    logic sampled_acknowledge_bit;
    logic [2:0] retries;

    // Constants for bit timing
    localparam START_BIT_TIME =     $rtoi(3.7 * CLK_KHZ); // 3.7ms
    localparam START_BIT_DURATION = $rtoi(4.5 * CLK_KHZ); // 4.5ms
    localparam LOGIC_0_TIME =       $rtoi(1.5 * CLK_KHZ); // 1.5ms
    localparam LOGIC_1_TIME =       $rtoi(0.6 * CLK_KHZ); // 0.6ms
    localparam DATA_BIT_DURATION =  $rtoi(2.4 * CLK_KHZ); // 2.4ms
    localparam NOMINAL_SAMPLE_TIME = $rtoi(1.0 * CLK_KHZ);// 1ms

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            current_frame <= 9'h00;
            bit_timer <= 0;
            bit_high_time <= 0;
            bit_count <= 0;
            sampled_acknowledge_bit <= 0;
          	data_acknowledged <= 0;
          	data_rejected <= 0;
            retries <= MAX_RETRIES;
        end else begin
            case (state)
                IDLE: begin
                  	data_acknowledged <= 0;
                  	data_rejected <= 0;
                    if (data_ready) begin
                        state <= START_BIT;
                        bit_timer <= START_BIT_DURATION;
                        bit_high_time <= START_BIT_DURATION - START_BIT_TIME;
                        current_frame <= {data_out, data_eom}; // Data bits + EOM bit
                        bit_count <= 0;
                        retries <= MAX_RETRIES;
                    end
                end
                NEXT_FRAME: begin
                  	data_acknowledged <= 0;
                    if (data_ready) begin
                        state <= DATA_BITS;
                        current_frame <= {data_out, data_eom}; // Data bits + EOM bit
                        bit_count <= 0;
                        retries <= MAX_RETRIES;
                    end
                end
                START_BIT: begin
                    if (bit_timer == 0) begin
                        state <= DATA_BITS;
                    end
                end
                DATA_BITS: begin
                    if (bit_timer == 0) begin
                        bit_timer <= DATA_BIT_DURATION;
                        if (bit_count < 4'd9) begin
                            bit_high_time <= current_frame[4'd8 - bit_count] ? 
                                (DATA_BIT_DURATION - LOGIC_1_TIME) : (DATA_BIT_DURATION - LOGIC_0_TIME);
                            bit_count <= bit_count + 1;
                        end else begin
                            state <= ACKNOWLEDGE;
                            bit_high_time <= DATA_BIT_DURATION - LOGIC_1_TIME; // ACK sent as logic 1
                            bit_count <= 0;
                        end
                    end
                end
                ACKNOWLEDGE: begin
                    if (bit_timer == (DATA_BIT_DURATION - NOMINAL_SAMPLE_TIME)) begin
                        sampled_acknowledge_bit <= acknowledge_bit;
                        if (!acknowledge_bit && retries > 0) begin
                            state <= RETRANSMIT;
                        end
                    end else if (bit_timer == 0) begin
                        state <= sampled_acknowledge_bit && !current_frame[0] /* ACK && !EOM */ ? NEXT_FRAME : IDLE;
                        bit_high_time <= 0;
                        data_acknowledged <= sampled_acknowledge_bit;
                        data_rejected <= ~sampled_acknowledge_bit;
                    end
                end
                RETRANSMIT: begin
                    if (bit_timer == 0) begin
                        state <= DATA_BITS;
                        bit_count <= 0;
                        retries <= retries - 1;
                    end
                end
                default: state <= IDLE;
            endcase
            if (bit_timer > 0) begin
                bit_timer <= bit_timer - 1;
            end
        end
    end

    assign is_bit_high_time = bit_high_time > 0 && bit_timer <= bit_high_time;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cec_out <= 1'b1;
            cec_send <= 1'b1;
        end else begin
            case (state)
                IDLE, NEXT_FRAME, RETRANSMIT: begin
                    cec_send <= 1'b1;
                    cec_out <= 1'b1;
                end
                START_BIT, DATA_BITS: begin
                    cec_out <= is_bit_high_time;
                end
                ACKNOWLEDGE: begin
                    cec_out <= is_bit_high_time;
                    if (is_bit_high_time) begin
                        cec_send <= 1'b0; // switch to read cec_in
                    end
                end
            endcase
        end
    end

    assign acknowledge_bit =
        state == ACKNOWLEDGE && 
        is_bit_high_time && 
        cec_in == (data_broadcast ? 1'b1 : 1'b0); // Detect acknowledge condition

endmodule

