(* blackbox *)
module unknown_cell(input A, output Y);
endmodule

module top (
    input  wire a,
    input  wire clk,
    output reg  q
);
  wire unknown;
  unknown_cell u_unknown(.A(a), .Y(unknown));
  always @(posedge clk)
    q <= unknown;
endmodule
