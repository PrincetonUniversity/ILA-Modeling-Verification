

// `include "param-PCComputation.v"
// `include "param-SIMDLaneDpath.v"

module param_Dpath
// #(
//   parameter P_NBITS = 4,
//   parameter C_N_OFF   = 8, //32/P_NBITS;
//   parameter C_OFFBITS = 3//$clog2(C_N_OFF);
// )
(

  input                  clk,
  input                  reset,

  output [31:0]          imemreq_msg_addr,

  output [31:0]          dmemreq_msg_addr,
  output [31:0]          dmemreq_msg_data, // TODO: Address this. Maybe mem accesses are vectorized somehow?
  input  [31:0]          dmemresp_msg_data,// TODO: Address this. Maybe mem accesses are vectorized somehow?
  input                  dmemresp_val_Xhl, // TODO: Address this. Maybe mem accesses are vectorized somehow?

  // ctrl -> dpath
  // --------------
  input                  pc_mux_sel_Xhl,
  input                  pc_plus4_mux_sel_Xhl,
  // Register Interface with Mem
  input   [4:0]          rega_addr_Rhl,
  input   [4:0]          regb_addr_Rhl,
  
  input   [4:0]          wb_addr_Xhl,
  input                  mem_access_Xhl, // TODO: Address this. Figure out what it was used for in dpath.
  input                  wb_en_Xhl,
  // input         wb_to_temp_Xhl,  // TODO: Address this

  // ALU Inputs
  // input                  a_mux_sel_Rhl, // Used to control/enable pc+4 module and pc bs-shifter and gate input A register
  input                  a_mux_sel_Xhl,
  input [3:0]    b_imm_Xhl,
  input                  b_mux_sel_Xhl,

  input [2:0]  a_subword_off_Rhl,
  input [2:0]  b_subword_off_Rhl,
  input [2:0]  wb_subword_off_Xhl,

  input                  addsub_fn_Xhl,
  input [1:0]            logic_fn_Xhl,
  input [1:0]            shift_fn_Xhl,
  input [1:0]            alu_fn_type_Xhl,
  
  input                  prop_carry_Xhl,
  input                  carry_in_1_Xhl,    
  input                  flag_reg_en_Xhl,

  input                  shift_dir_sel_Xhl,
  input                  addr_reg_en_Xhl,
  
  input                  last_uop_Xhl,
  input                  br_reg_en_Xhl,

  output  [4:0]          shamt_reg,
  output                 b_use_imm_reg_Xhl, // Branch register indicates if branch is taken (1) or not taken (0).
  output [31:0]          proc2cop_data_Xhl //TODO: Add this functionality

);
  
  localparam P_NBITS = 4;
  localparam C_N_OFF = 8;
  localparam C_OFFBITS = 3;


  assign dmemreq_msg_data = 32'b0;// TEMP

  //----------------
  // proc2cop logic
  // ---------------
  wire [P_NBITS-1:0] alu_mux_out_Xhl;
  wire [31:0]        addr_reg_Xhl;
  assign proc2cop_data_Xhl = {alu_mux_out_Xhl, addr_reg_Xhl[31-P_NBITS:0]};

  //---------------
  // All PC Logic
  //---------------

  wire [P_NBITS-1:0] pc_plus4_mux_out_Xhl;
  wire [31:0]        pc;

  param_PCComputation 
  // #(
  //   .P_NBITS(P_NBITS),
  //   .C_N_OFF(C_N_OFF),
  //   .C_OFFBITS(C_OFFBITS)
  // )
  pc_logic
  (
    .clk                        (clk),
    .reset                      (reset),
    .last_uop_Xhl               (last_uop_Xhl),
    .pc_mux_sel_Xhl             (pc_mux_sel_Xhl),
    .b_use_imm_reg_Xhl          (b_use_imm_reg_Xhl),
    .alu_mux_out_Xhl            (alu_mux_out_Xhl),
    .pc_plus4_mux_sel_Xhl       (pc_plus4_mux_sel_Xhl),
    // .a_mux_sel_Rhl              (a_mux_sel_Rhl),
    .a_mux_sel_Xhl              (a_mux_sel_Xhl),
    .shift_dir_sel_Xhl          (shift_dir_sel_Xhl),
    .addr_reg_en_Xhl            (addr_reg_en_Xhl),
    .pc_plus4_mux_out_Xhl       (pc_plus4_mux_out_Xhl),
    .addr_reg_Xhl               (addr_reg_Xhl),
    .pc                         (pc)
  );
  assign imemreq_msg_addr = pc;

  
  param_SIMDLaneDpath 
  // #(
  //   .P_NBITS(P_NBITS),
  //   .C_N_OFF(C_N_OFF),
  //   .C_OFFBITS(C_OFFBITS)
  // )
  lane_0
  (
    .clk                   (clk),
    .reset                 (reset),
    .rega_addr_Rhl         (rega_addr_Rhl),
    .regb_addr_Rhl         (regb_addr_Rhl),
    .wb_en_Xhl             (wb_en_Xhl),
    .wb_addr_Xhl           (wb_addr_Xhl),

    // .a_mux_sel_Rhl         (a_mux_sel_Rhl),
    .a_mux_sel_Xhl         (a_mux_sel_Xhl),
    .pc_plus4_mux_out_Xhl  (pc_plus4_mux_out_Xhl),
    .b_imm_Xhl             (b_imm_Xhl),
    .b_mux_sel_Xhl         (b_mux_sel_Xhl),

    .a_subword_off_Rhl     (a_subword_off_Rhl),
    .b_subword_off_Rhl     (b_subword_off_Rhl),
    .wb_subword_off_Xhl    (wb_subword_off_Xhl),

    .addsub_fn_Xhl         (addsub_fn_Xhl),
    .logic_fn_Xhl          (logic_fn_Xhl),
    .shift_fn_Xhl          (shift_fn_Xhl),
    .alu_fn_type_Xhl       (alu_fn_type_Xhl),

    .prop_carry_Xhl        (prop_carry_Xhl),
    .carry_in_1_Xhl        (carry_in_1_Xhl),
    .last_uop_Xhl          (last_uop_Xhl),
    .flag_reg_en_Xhl       (flag_reg_en_Xhl),
    .br_reg_en_Xhl         (br_reg_en_Xhl),
    .addr_reg_Xhl          (addr_reg_Xhl),

    .dmemreq_msg_addr      (dmemreq_msg_addr),
    .shamt_reg             (shamt_reg),
    .b_use_imm_reg_Xhl     (b_use_imm_reg_Xhl),
    .alu_mux_out_Xhl       (alu_mux_out_Xhl)
  );

endmodule