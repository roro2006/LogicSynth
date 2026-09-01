module top (
    input wire a,
    input wire b,
    output wire y,
    output wire z
);
  assign y = a & b;
  assign z = b & a;
endmodule
