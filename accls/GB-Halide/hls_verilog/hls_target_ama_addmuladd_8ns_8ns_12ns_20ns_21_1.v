// ==============================================================
// File generated by Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC
// Version: 2015.3
// Copyright (C) 2015 Xilinx Inc. All rights reserved.
// 
// ==============================================================

`timescale 1 ns / 1 ps

module hls_target_ama_addmuladd_8ns_8ns_12ns_20ns_21_1_DSP48_13(
    input  [8 - 1:0] in0,
    input  [8 - 1:0] in1,
    input  [12 - 1:0] in2,
    input  [20 - 1:0] in3,
    output [21 - 1:0]  dout);

wire signed [18 - 1:0]     b;
wire signed [25 - 1:0]     a;
wire signed [25 - 1:0]     d;
wire signed [48 - 1:0]     c;
wire signed [43 - 1:0]     m;
wire signed [48 - 1:0]     p;
wire signed [25 - 1:0]    ad;

assign a = $unsigned(in0);
assign d = $unsigned(in1);
assign b = $unsigned(in2);
assign c = $unsigned(in3);

assign ad = a + d;
assign m  = ad * b;
assign p  = m + c;

assign dout = p;

endmodule

`timescale 1 ns / 1 ps
module hls_target_ama_addmuladd_8ns_8ns_12ns_20ns_21_1(
    din0,
    din1,
    din2,
    din3,
    dout);

parameter ID = 32'd1;
parameter NUM_STAGE = 32'd1;
parameter din0_WIDTH = 32'd1;
parameter din1_WIDTH = 32'd1;
parameter din2_WIDTH = 32'd1;
parameter din3_WIDTH = 32'd1;
parameter dout_WIDTH = 32'd1;
input[din0_WIDTH - 1:0] din0;
input[din1_WIDTH - 1:0] din1;
input[din2_WIDTH - 1:0] din2;
input[din3_WIDTH - 1:0] din3;
output[dout_WIDTH - 1:0] dout;



hls_target_ama_addmuladd_8ns_8ns_12ns_20ns_21_1_DSP48_13 hls_target_ama_addmuladd_8ns_8ns_12ns_20ns_21_1_DSP48_13_U(
    .in0( din0 ),
    .in1( din1 ),
    .in2( din2 ),
    .in3( din3 ),
    .dout( dout ));

endmodule

