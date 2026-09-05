module top (
    input wire a,
    input wire b,
    input wire clk,
    output wire y,
    output reg q
);
  wire and0 = a & b;
  wire and1 = a & b;
  assign y = and0 ^ and1;
  always @(posedge clk)
    q <= y;
endmodule
