
`ifndef PARAM_SIMD_LANE_DPATH_V
`define PARAM_SIMD_LANE_DPATH_V

`include "param-CoreDpathRegfile.v"
`include "param-CoreDpathAlu.v"

module param_SIMDLaneDpath
// #(
//   parameter P_NBITS = 4,
//   parameter C_N_OFF   = 8, //32/P_NBITS;
//   parameter C_OFFBITS = 3//$clog2(C_N_OFF);
// )
(

  input         clk,
  input         reset,

  // Register Interface with Mem
  input   [4:0] rega_addr_Rhl,
  input   [4:0] regb_addr_Rhl,
  input         wb_en_Xhl,
  input   [4:0] wb_addr_Xhl,

  // Gating for register reads (a_mux_sel_Rhl already exists)
  // input         a_read_temp_reg_Rhl,
  // input         b_mux_sel_Rhl,
  
  // ALU Inputs
  // input                 a_mux_sel_Rhl,
  input                 a_mux_sel_Xhl,
  input [3:0]   pc_plus4_mux_out_Xhl,
  input [3:0]   b_imm_Xhl,

  input                 b_mux_sel_Xhl,
  input [2:0] a_subword_off_Rhl,
  input [2:0] b_subword_off_Rhl,
  input [2:0] wb_subword_off_Xhl,

  input       addsub_fn_Xhl,
  input [1:0] logic_fn_Xhl,
  input [1:0] shift_fn_Xhl,
  input [1:0] alu_fn_type_Xhl,

  input         prop_carry_Xhl,
  input         carry_in_1_Xhl,
  input         last_uop_Xhl,
  input         flag_reg_en_Xhl,
  input         br_reg_en_Xhl,

  //TEMP: To be refactored out of here?
  input  [31:0] addr_reg_Xhl,


  // Memory outputs
  output [31:0] dmemreq_msg_addr,
  // Outputs to core
  output  [4:0] shamt_reg,
  // Outputs to PC logic
  output reg    b_use_imm_reg_Xhl,
  output reg [3:0] alu_mux_out_Xhl   // For use in addr_reg and proc2_cop


);

  localparam P_NBITS = 4;
  localparam C_N_OFF = 8;
  localparam C_OFFBITS = 3;


//-------------------------
  // Register Read Stage (R)
  //-------------------------
  // Declarations
  wire [P_NBITS-1:0] a_data_Rhl;
  wire [P_NBITS-1:0] b_data_Rhl;
  // Temp result register;
  wire [31:0] temp_reg_Xhl;

  // Regfile
  param_CoreDpathRegfile rfile
  (
    .clk     (clk),
    // Register read (R)
    .raddr0_Rhl  (rega_addr_Rhl),
    .roff0_Rhl   (a_subword_off_Rhl),
    .rdata0_Rhl  (a_data_Rhl),

    .raddr1_Rhl  (regb_addr_Rhl),
    .roff1_Rhl   (b_subword_off_Rhl),
    .rdata1_Rhl  (b_data_Rhl),

    // Register write (W)
    .wen_Xhl     (wb_en_Xhl),
    .waddr_Xhl   (wb_addr_Xhl),
    .woffset_Xhl (wb_subword_off_Xhl),
    .wdata_Xhl   (alu_mux_out_Xhl)
  );

  //-------------------
  // Execute Stage (X)
  //-------------------
  reg [P_NBITS-1:0] a_data_Xhl;
  reg [P_NBITS-1:0] b_data_Xhl;

  always @ (posedge clk) begin
    a_data_Xhl <= a_data_Rhl;
    b_data_Xhl <= b_data_Rhl;
  end

  // wire a_bit_Xhl = a_data_Xhl; // Only used when !a_read_temp_reg_Xhl && !a_mux_sel_Xhl
  // wire b_bit_Xhl = b_data_Xhl; // Only used when b_mux_sel_Xhl high

  // Temp result register;
  // wire temp_reg_out_Xhl = temp_reg_Xhl[0]; 
  // wire a_reg_mux_out_Xhl = a_read_temp_reg_Xhl ? temp_reg_out_Xhl : a_bit_Xhl;// No longer needed bc no deserialization
  // wire a_reg_mux_out_Xhl = a_bit_Xhl;

  wire [P_NBITS-1:0] a_mux_out_Xhl = a_mux_sel_Xhl ? pc_plus4_mux_out_Xhl : a_data_Xhl;

  wire [P_NBITS-1:0] b_imm_mux_out_Xhl = b_use_imm_reg_Xhl ? b_imm_Xhl : {P_NBITS{1'b0}}; 
  wire [P_NBITS-1:0] b_mux_out_Xhl = b_mux_sel_Xhl ? b_data_Xhl : b_imm_mux_out_Xhl;

  
  reg carry_out_reg_Xhl;
  reg msb_reg_Xhl;
  // Microcode sets prop_carry high if it propagates either the MSB (carry_in_1=1) or carry out (carry_in_1=0) 
  wire cmp_flag_type_Xhl = carry_in_1_Xhl; 
  wire cmp_flag_mux_out_Xhl = cmp_flag_type_Xhl ? msb_reg_Xhl : carry_out_reg_Xhl;
  // Otherwise, carry-in is set constant. Use that constant.
  wire carry_in_Xhl = prop_carry_Xhl ? cmp_flag_mux_out_Xhl : carry_in_1_Xhl;
  
  // ALU
  wire [P_NBITS-1:0] sum_out_Xhl;
  wire carry_out_Xhl;
  wire a_b_not_eq_Xhl;
  wire [P_NBITS-1:0] fn_out_Xhl;

  param_CoreDpathAlu  
  // #(
  //   .P_NBITS(P_NBITS)
  // )
  alu
  (
    .in_a         (a_mux_out_Xhl),
    .in_b         (b_mux_out_Xhl),      
    .in_c         (carry_in_Xhl),
    .addsub_fn    (addsub_fn_Xhl),
    .logic_fn     (logic_fn_Xhl),
    .shift_fn     (shift_fn_Xhl),

    .sum_out      (sum_out_Xhl),     
    .carry_out    (carry_out_Xhl),
    .a_b_not_eq   (a_b_not_eq_Xhl),
    .fn_out       (fn_out_Xhl)
  );


localparam INST_ARITH = 2'b00;
localparam INST_JALR  = 2'b11;
localparam INST_LOGIC = 2'b01;
localparam INST_SHIFT = 2'b10;


always @ (*) begin
  alu_mux_out_Xhl = sum_out_Xhl;
  case (alu_fn_type_Xhl)
    INST_ARITH: alu_mux_out_Xhl = sum_out_Xhl;
    INST_JALR:  alu_mux_out_Xhl = sum_out_Xhl & {{(P_NBITS-1){1'b1}}, 1'b0}; // Bitwize and with fffe for jalr.
    INST_LOGIC: alu_mux_out_Xhl = fn_out_Xhl;
    //INST_SHIFT: 
    default:    alu_mux_out_Xhl = sum_out_Xhl;
  endcase
end


// Carry-in/out flag register
reg carry_out_reg_Xhl_next;
always @ (*)
begin
  carry_out_reg_Xhl_next = carry_out_reg_Xhl;
  if (reset) begin
    carry_out_reg_Xhl_next = 1'b0;
  end else if (flag_reg_en_Xhl) begin
    carry_out_reg_Xhl_next = carry_out_Xhl;
  end
end

always @(posedge clk) begin
  carry_out_reg_Xhl <= carry_out_reg_Xhl_next;
end
// MSB flag register for doing less-than comparisons
// Account for underflow
// Also don't forget b gets inverted
reg msb_reg_Xhl_next;
always @ (*)
begin
  msb_reg_Xhl_next = msb_reg_Xhl;
  if (reset) begin
    msb_reg_Xhl_next = 1'b0;
  end else if (flag_reg_en_Xhl) begin
  // Less than function: Adding 2's complement numbers A is less than B if A[msb]=1B[msb]=0. A>B if A[msb]=0B[msb]=1. 
  // If both numbers are positive, we can't have underflow.
  // Less than function: (A!B) || [!(!AB)&&(A^B^C)] = (A!B) || !(!AB) && MSB = 1
  // msb_reg_Xhl_next = sum_out_Xhl[P_NBITS-1];
    msb_reg_Xhl_next = (!(!a_mux_out_Xhl[P_NBITS-1] && b_mux_out_Xhl[P_NBITS-1]) && sum_out_Xhl[P_NBITS-1]) || (a_mux_out_Xhl[P_NBITS-1] && !b_mux_out_Xhl[P_NBITS-1]);
  end
end

always @(posedge clk) begin
  msb_reg_Xhl <= msb_reg_Xhl_next;
end
// Equality flag state register
reg eq_flag_reg_Xhl_next;
reg eq_flag_reg_Xhl;
always @(*)
begin
  eq_flag_reg_Xhl_next = eq_flag_reg_Xhl;
  if (reset) begin
    eq_flag_reg_Xhl_next = 1'b0;

  end else if (flag_reg_en_Xhl) begin
    eq_flag_reg_Xhl_next =  prop_carry_Xhl ? (a_b_not_eq_Xhl || eq_flag_reg_Xhl) 
                          :(carry_in_1_Xhl ? 1'b1 : a_b_not_eq_Xhl); // If 0, base signal only on current inputs. // Setting to 1 may be undefined
  end
end

always @(posedge clk)
begin
  eq_flag_reg_Xhl <= eq_flag_reg_Xhl_next;
end

// B immediate select register
//   used in branch result calculations
reg b_use_imm_reg_Xhl_next;
always @(*) 
begin
  b_use_imm_reg_Xhl_next = b_use_imm_reg_Xhl;
  if (reset) begin
    b_use_imm_reg_Xhl_next = 1'b1;
  end else if (last_uop_Xhl) begin // Set to use immediates by default every instruction
    b_use_imm_reg_Xhl_next = 1'b1; 
  end else if (br_reg_en_Xhl) begin // Set b_imm_mux_out_Xhl to 0 if branch is not taken.
    b_use_imm_reg_Xhl_next = a_b_not_eq_Xhl || eq_flag_reg_Xhl;
  end  
end

always @(posedge clk) begin
  b_use_imm_reg_Xhl <= b_use_imm_reg_Xhl_next;
end
  


wire [31:0] temp_reg_Xhl_next;
assign temp_reg_Xhl = 32'b0;



  //-------------------
  // Memory interface
  //-------------------

  assign dmemreq_msg_addr = addr_reg_Xhl;
  //assign dmemreq_msg_data = temp_reg_Xhl; // TEMP:to fix

  // Shifting interface
  // Shifts broken by removal of deserialization registers.
  // TODO: Fix shifts in microcode. Also maybe add memory operations?
  // assign shamt_reg = addr_reg_Xhl[4:0];
  assign shamt_reg = 5'b0; 

endmodule
`endif