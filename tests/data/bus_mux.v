module top (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       sel,
    output wire [3:0] y
);
  wire [3:0] p = a & b;
  wire [3:0] q = b & a;
  assign y = sel ? p : q;
endmodule
