module top (
    input  wire a,
    input  wire b,
    output wire y,
    output wire z
);
  wire shared;
  assign shared = a & b;
  assign y = shared;
  assign z = a & b;
endmodule
