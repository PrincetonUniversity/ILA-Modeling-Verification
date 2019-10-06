`ifndef PARAM_PC_COMPUTATION_V
`define PARAM_PC_COMPUTATION_V

// `include "param-PCPlus4.v"
`include "param-ClkEnBuf.v"
`include "param-ShiftDemux.v"
`include "param-DeserializedReg.v"

module param_PCComputation
// #(
//   parameter P_NBITS=4,
//   parameter C_N_OFF   = 8, //32/P_NBITS;
//   parameter C_OFFBITS = 3//$clog2(C_N_OFF);
// )
(
  input                 clk,
  input                 reset,
        
  input                 last_uop_Xhl,
  input                 pc_mux_sel_Xhl,
  input                 b_use_imm_reg_Xhl,
  input [3:0]   alu_mux_out_Xhl,

  input                 pc_plus4_mux_sel_Xhl,
  input                 a_mux_sel_Xhl,
  input                 shift_dir_sel_Xhl,
  input                 addr_reg_en_Xhl,
  output [3:0]  pc_plus4_mux_out_Xhl,

  output     [31:0]     addr_reg_Xhl,
  output reg [31:0]     pc
  
);
  localparam P_NBITS = 4;
  localparam C_N_OFF = 8;
  localparam C_OFFBITS = 3;


  // ------------------
  // PC and Selection
  // ------------------

  reg [31:0] pc_next;
  wire pc_reg_clk_en = !(last_uop_Xhl || reset);
  
  wire [31:0] pc_plus4_Xhl;

  // wire pc_reg_clk_gated = clk;
  wire pc_reg_clk_gated;
  param_ClkEnBuf pc_reg_clk_gate
  (
    .clk(pc_reg_clk_gated),
    .rclk(clk),
    .en_l(pc_reg_clk_en)
  );

  always @(posedge pc_reg_clk_gated) begin
    pc <= pc_next;
  end

  wire [31:0] pc_mux_out_Xhl = (pc_mux_sel_Xhl && b_use_imm_reg_Xhl) ? {alu_mux_out_Xhl, addr_reg_Xhl[(31-P_NBITS):0]} : pc_plus4_Xhl; 
  always @ (*)
  begin
    pc_next = pc;
    if(reset) begin
      pc_next = 32'h00080000;
    end else if (last_uop_Xhl ) begin
      pc_next = pc_mux_out_Xhl;
    end
  end

  // ---------------------------
  // Branch target calculation
  // ---------------------------
  // Address Deserializing Register 

  // Translating shift_dir_sel_Xhl and addr_reg_en_Xhl to 1-hot subword enable signal
  wire [C_OFFBITS-1:0] addr_reg_subword_en_idx_Xhl;
  param_ShiftDemux addr_demux
  (
    .reset     (reset),      
    .clk       (clk),  

    .direction (shift_dir_sel_Xhl),  
    .en        (addr_reg_en_Xhl), 

    .idx       (addr_reg_subword_en_idx_Xhl)  
  );

  param_DeserializedReg addr_reg
  (
    .reset          (reset),     
    .clk            (clk),
    .subword_en_idx (addr_reg_subword_en_idx_Xhl),
    .data_in        (alu_mux_out_Xhl),     

    .out            (addr_reg_Xhl)
  );

  // -------------------------------------------
  // PC+4 calculation and bit-serial interface
  // -------------------------------------------

  assign pc_plus4_Xhl = pc + 32'd4; // TODO Confirm this is not on critical path

  // ---------------------------------
  // PC ALU input shifting interface
  // ---------------------------------
  reg [31:0] pc_shift_reg_Xhl;
  reg [31:0] pc_shift_reg_Xhl_next;

  reg [31:0] pc_plus4_shift_reg_Xhl;
  reg [31:0] pc_plus4_shift_reg_Xhl_next;
  
  always @(*) begin
    pc_shift_reg_Xhl_next = pc;
    pc_plus4_shift_reg_Xhl_next = pc_plus4_Xhl;
    if (reset) begin
      pc_shift_reg_Xhl_next = 32'b0;
      pc_plus4_shift_reg_Xhl_next =32'b0;
    end else if (last_uop_Xhl) begin
      pc_shift_reg_Xhl_next = pc_next;
      pc_plus4_shift_reg_Xhl_next = pc_next + 32'd4; // TODO Check this isn't on critical path
    end else if (!pc_plus4_mux_sel_Xhl && a_mux_sel_Xhl) begin
      pc_shift_reg_Xhl_next = {pc_shift_reg_Xhl[P_NBITS-1:0], pc_shift_reg_Xhl[31:P_NBITS]};
      pc_plus4_shift_reg_Xhl_next = {pc_plus4_shift_reg_Xhl[P_NBITS-1:0], pc_plus4_shift_reg_Xhl[31:P_NBITS]};
    end
  end

  // Clock gating 
  // wire pc_shift_reg_gated = clk;
  wire pc_shift_reg_gated;
  wire pc_shift_gate_en = !(last_uop_Xhl || (!pc_plus4_mux_sel_Xhl && a_mux_sel_Xhl) || reset);
  param_ClkEnBuf pc_shift_enable
  (
    .clk (pc_shift_reg_gated),
    .rclk(clk),
    .en_l(pc_shift_gate_en)
  );

  always @(posedge pc_shift_reg_gated) begin
    pc_shift_reg_Xhl <= pc_shift_reg_Xhl_next;
    pc_plus4_shift_reg_Xhl <= pc_plus4_shift_reg_Xhl_next;
  end
  
  wire [P_NBITS-1:0] pc_bit_Xhl = pc_shift_reg_Xhl[P_NBITS-1:0];
  wire [P_NBITS-1:0] pc_plus4_bit_Xhl = pc_plus4_shift_reg_Xhl[P_NBITS-1:0];
  assign pc_plus4_mux_out_Xhl = pc_plus4_mux_sel_Xhl ? pc_plus4_bit_Xhl : pc_bit_Xhl;

endmodule
`endif