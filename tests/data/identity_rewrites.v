module top (
    input wire a,
    input wire b,
    output wire y,
    output wire z
);
  assign y = (a & 1'b1) | 1'b0;
  assign z = b ^ 1'b0;
endmodule
