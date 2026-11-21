module Shift_reg #(
    parameters WIDTH = 8
) (
    input wire clk, rst, mode, load, shift_en,   // mode: 0 = SIPO  and 1 =  PISO
    input wire [WIDTH-1:0] parallel_in,
    input wire serial_in,
    output wire [WIDTH-1:0] parallel_out,
    output wire         serial_out
);

    reg [WIDTH-1:0] sr;
    wire [WIDTH-1:0] shifted, held_or_shifted, loaded, sr_next;
    wire load_en;


    assign load_en = mode & load; // loas enable is only for mode = 1 : PISO
    assign shifted = {sr[WIDTH-2:0], serial_in & ~mode};
    assign held_or_shifted = shift_en ? shifted       : sr;
    assign loaded          = load_en  ? parallel_in   : held_or_shifted;
    assign sr_next         = rst      ? {WIDTH{1'b0}} : loaded;

    always @(posedge clk ) begin
        assign parallel_out = sr;
        assign serial_out   = sr[WIDTH-1];
    end
endmodule