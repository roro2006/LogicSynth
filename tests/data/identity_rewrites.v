module top (
    input wire a,
    input wire b,
    output wire y,
    output wire z,
    output wire w
);
  assign y = (a & 1'b1) | 1'b0;
  assign z = b ^ 1'b0;
  assign w = b ~^ 1'b1;
endmodule
