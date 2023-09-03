
module sync_data_cross(
    input clkIn,
    input clkOut,
    input [WIDTH-1:0] dataIn,
    output wire [WIDTH-1:0] dataOut
);
    parameter WIDTH = 24;
    
    reg [WIDTH-1:0] dataIn_reg = 0;
    reg [WIDTH-1:0] dataOut_reg = 0;

    always @(posedge clkOut) begin
        dataIn_reg <= dataIn;
        dataOut_reg <= dataIn_reg;
    end

    assign dataOut = dataOut_reg;
endmodule
