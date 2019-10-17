

`include "tinyrv2-InstMsg.v"



module param_Ctrl
(
      
  input        clk,
  input        reset,
       
  output       imemreq_val,
  input        imemreq_rdy,
  input [31:0] imemresp_msg_data,
  input        imemresp_val,
  output       imemresp_rdy,

      // Data Memory Port
  output       dmemreq_msg_rw,
  output [1:0] dmemreq_msg_len,
  output reg   dmemreq_val,
  input        dmemreq_rdy,
  input        dmemresp_val,

  // ctrl -> dpath
  // --------------
  output reg        pc_mux_sel_Xhl,
  output reg        pc_plus4_mux_sel_Xhl,

  // Register Interface with Mem
  output reg [4:0]  rega_addr_Rhl,
  output reg [4:0]  regb_addr_Rhl,
   
  output reg [4:0]  wb_addr_Xhl,
  output reg        mem_access_Xhl,
  output reg        wb_en_Xhl,
  // output reg        wb_to_temp_Xhl,
 
  // ALU Inputs 
  // output reg        a_read_temp_reg_Xhl,
  // output reg        a_mux_sel_Rhl,
  output reg        a_mux_sel_Xhl,
  output reg [3:0]  b_imm_Xhl,

  output reg        b_mux_sel_Xhl,
 
  output reg [2:0]  a_subword_off_Rhl,
  output reg [2:0]  b_subword_off_Rhl,
  output reg [2:0]  wb_subword_off_Xhl,


  output reg        addsub_fn_Xhl,
  output reg [1:0]  logic_fn_Xhl,
  output reg [1:0]  shift_fn_Xhl,
  output reg [1:0]  alu_fn_type_Xhl,


  output reg        prop_carry_Xhl,
  output reg        carry_in_1_Xhl,
  output reg        flag_reg_en_Xhl,
       
  output reg        shift_dir_sel_Xhl,
  output reg        addr_reg_en_Xhl,

  output reg        last_uop_Xhl,
  output reg        br_reg_en_Xhl,

  input             b_use_imm_reg_Xhl,
  input      [4:0]  shamt_reg,
  input      [31:0] proc2cop_data_Xhl,

  output reg [31:0] cp0_status

);


// RISCV Architectural Registers
  reg  [31:0] ir;
  wire [4:0]  rs1;
  wire [4:0]  rs2;
  wire [4:0]  rd;
  wire [4:0]  uop_repeat_Dhl;

  assign rs1 = ir[19:15];
  assign rs2 = ir[24:20];
  assign rd  = ir[11:7];

  // ------------------------
  // Instruction Fetch Logic
  // ------------------------
  reg new_instr_req;
  reg instr_req_pending;
  reg [4:0] repeat_ctr_reg;
  reg [9:0] uop_idx;
  
  // We are always ready to accept a new instruction
  // because we only request when we are ready
  assign imemreq_val = new_instr_req;
  assign imemresp_rdy = instr_req_pending;

  // Set up micr-op repeat logic
  reg dmemreq_pending_next;                  // logic below
  wire stall_dmemreq = dmemreq_pending_next; // rename for convenience

  reg first_cycle_of_uop;
  wire [4:0] repeat_mux_out = first_cycle_of_uop ? uop_repeat_Dhl : (repeat_ctr_reg - 1);
  wire repeat_ctr_reg_en = (!stall_dmemreq) && (first_cycle_of_uop || (repeat_ctr_reg != 5'b0)); // Load new value into counter as long as you're not... 
  wire [4:0] repeat_ctr_next = repeat_ctr_reg_en ? repeat_mux_out : repeat_ctr_reg;              // waiting on memory to respond

  // Indicate when a new instruction fetch is being handled by the instruction memory.
  reg instr_req_pending_next;
  always @(*) begin
    instr_req_pending_next = instr_req_pending;
    if (imemresp_val && imemresp_rdy) begin
      instr_req_pending_next = 1'b0; 
    end else if (imemreq_val && imemreq_rdy) begin
      instr_req_pending_next = 1'b1;
    end
  end

  // Update uop index on a new instruction fetch or when repeat counter hits 0.
  reg [9:0] uop_idx_next;
  always @(*) begin
    uop_idx_next = uop_idx;
    if ((imemreq_val && imemreq_rdy) || (imemresp_val && imemresp_rdy)) begin
      uop_idx_next = 10'b0;
    end
    else if (repeat_mux_out == 5'b0 && !stall_dmemreq) begin
      uop_idx_next = uop_idx + 10'b1;
    end
  end

  // Indicate first cycle of a (possibly) repeated uop. 
  // This is when there's a newly-fetched instruction or the uop repeat counter hits 0
  reg first_cycle_of_uop_next;
  always @(*) 
  begin
    first_cycle_of_uop_next = first_cycle_of_uop;
    if (imemresp_val && imemresp_rdy) begin
      first_cycle_of_uop_next = 1'b1;
    end else begin
      first_cycle_of_uop_next = (repeat_mux_out == 5'b0);
    end
  end

  // IUpdate IR when imem responds with a valid instruction
  reg [31:0] ir_next;
  wire        last_uop_Dhl;
  always @(*)
  begin
    ir_next = ir;
    if (imemresp_val && imemresp_rdy) begin
      ir_next = imemresp_msg_data;
    end 
  end

  // Indicate when done fetching/decoding and to switch to default control signal
  // Clear when a new fetch request is sent to memory.
  reg done_fetch;
  reg done_fetch_next;
  always @ (*) 
  begin
    done_fetch_next = done_fetch;
    if (!new_instr_req && last_uop_Dhl) begin
      done_fetch_next = 1'b1;
    end else if (new_instr_req) begin
      done_fetch_next = 1'b0;
    end
  end


  // Indicate when to fetch the next instruction
  // Must be when current instruction's last uop is in the X stage
  reg new_instr_req_next;
  always @(*)
  begin
    new_instr_req_next = new_instr_req;
    if (imemreq_val && imemreq_rdy) begin
      new_instr_req_next = 1'b0;
    end else if (last_uop_Xhl) begin
      new_instr_req_next = 1'b1;
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      // Upon a reset, prepare to request a new instruction
      new_instr_req <= 1'b1;
      instr_req_pending <= 1'b0;
      ir <= 32'b0;
      uop_idx <= 10'b0;
      repeat_ctr_reg <= 5'b0;
      done_fetch <= 1'b0;
    end else begin
      // Update sequential state
      instr_req_pending <= instr_req_pending_next;
      uop_idx <= uop_idx_next;
      first_cycle_of_uop <= first_cycle_of_uop_next;
      ir <= ir_next;
      repeat_ctr_reg <= repeat_ctr_next;
      new_instr_req <= new_instr_req_next;
      done_fetch <=  done_fetch_next;
    end
  end
  localparam cs_sz        = 58;

  localparam rep_const    = 2'b00; // Repeat uop as defined in microcode
  localparam rep_reg      = 2'b01; // Repeat uop as defined in temp_reg[5:0] for register-based shifts
  localparam rep_imm      = 2'b10; // Repeat uop as defined in shamt section of IR for imm. shifts

  localparam pc_x         = 1'b0;   //x;       
  localparam pc_n         = 1'b0;   // Indicate take next PC (= PC+4) 
  localparam pc_b         = 1'b1;   // Indicate to take calculated PC (shift register) if a branch is taken

  localparam am_r         = 2'b00;  // Indicate to use A as input
  localparam am_p         = 2'b01;  // Indicate to use PC as the A input
  localparam am_pcp       = 2'b11;  // Indicate to use PC+4 as A input

  localparam addr_x       = 5'b0;   // Invalid register address; default to 0
  localparam r0           = 5'h0;
  localparam r31          = 5'h1f;
  localparam n            = 1'b0;         
  localparam y            = 1'b1;

  localparam immed_type_i = 3'b000;
  localparam immed_type_s = 3'b001;
  localparam immed_type_b = 3'b010;
  localparam immed_type_u = 3'b011;
  localparam immed_type_j = 3'b100;
  localparam immed_type_x = 3'b111;  // Does not correspond to a particular type

  localparam b_imm_shft   = 1'b0;
  localparam b_imm_load   = 1'b1;
  localparam b_imm_x      = 1'b0;    //x;
  localparam bm_imm       = 1'b0;

  localparam bm_reg       = 1'b1;

  localparam fn_add       = 1'b0;
  localparam fn_sub       = 1'b1;
  localparam fn_and       = 2'b11;
  localparam fn_or        = 2'b10;
  localparam fn_xor       = 2'b00;
  localparam fn_shift_zero= 2'b00; // TODO: Add this functionality

  localparam carry_msb    = 2'b11; // Propagate old MSB to new carry-in signal
  localparam carry_prop   = 2'b10; // Propagate old carry out to new carry in
  localparam carry_in_1   = 2'b01; // Set carry in of Addsub to 1 
  localparam carry_in_0   = 2'b00; // Set carry in of addsub to 0

  localparam fn_type_arith= 2'b00;
  localparam fn_type_jalr = 2'b11; // Corner case for & fffe for JARL sum
  localparam fn_type_logic= 2'b01;
  localparam fn_type_shift= 2'b10;
  localparam fn_type_x    = 2'b00;   //x;

  localparam fn_x         = 8'b0;    //x;
  localparam fn_zero      = 8'b0;
  localparam shift_left   = 1'b0;
  localparam shift_right  = 1'b1;  
  localparam zero         = 1'b0;


  // Functions are truth tables counting from 000 to 111 for abc
  // 8'b(!a!b!c)(!a!bc)(!ab!c)...                         

  wire [cs_sz-1:0] lui_microcode[2:0];

assign lui_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, r0, addr_x, rd, n, y, y, b_imm_load, immed_type_u, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, n};
assign lui_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, r0, addr_x, rd, n, y, y, b_imm_shft, immed_type_u, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, n};
assign lui_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, r0, addr_x, rd, n, y, y, b_imm_shft, immed_type_u, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, y};


  wire [cs_sz-1:0] auipc_microcode[2:0];

assign auipc_microcode[0] = { rep_const, 5'd0, n, pc_x, am_p, addr_x, addr_x, rd, n, y, y, b_imm_load, immed_type_u, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign auipc_microcode[1] = { rep_const, 5'd5, n, pc_x, am_p, addr_x, addr_x, rd, n, y, y, b_imm_shft, immed_type_u, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign auipc_microcode[2] = { rep_const, 5'd0, n, pc_n, am_p, addr_x, addr_x, rd, n, y, y, b_imm_shft, immed_type_u, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, y};



  wire [cs_sz-1:0] jalr_microcode[3:0];
assign jalr_microcode[0] = { rep_const, 5'd7, n, pc_x, am_pcp, addr_x, addr_x, rd, n, y, n, b_imm_x, immed_type_i, y, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign jalr_microcode[1] = { rep_const, 5'd0, n, pc_x, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_load, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_jalr, y, shift_right, y, n, n};
assign jalr_microcode[2] = { rep_const, 5'd5, n, pc_x, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, y, n, n};
assign jalr_microcode[3] = { rep_const, 5'd0, n, pc_b, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, y, n, y};


wire [cs_sz-1:0] bne_microcode[5:0];
assign bne_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, addr_x, n, n, n, b_imm_x, immed_type_x, y, bm_reg, fn_add, carry_in_0, fn_xor, fn_shift_zero, fn_type_logic, y, shift_right, n, n, n};
assign bne_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, rs2, addr_x, n, n, n, b_imm_x, immed_type_x, y, bm_reg, fn_add, carry_prop, fn_xor, fn_shift_zero, fn_type_logic, y, shift_right, n, n, n};
assign bne_microcode[2] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, addr_x, n, n, n, b_imm_x, immed_type_x, y, bm_reg, fn_add, carry_prop, fn_xor, fn_shift_zero, fn_type_logic, y, shift_right, n, y, n};
assign bne_microcode[3] = { rep_const, 5'd0, n, pc_x, am_p, addr_x, addr_x, addr_x, n, n, y, b_imm_load, immed_type_b, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, y, n, n};
assign bne_microcode[4] = { rep_const, 5'd5, n, pc_x, am_p, addr_x, addr_x, addr_x, n, n, y, b_imm_shft, immed_type_b, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, y, n, n};
assign bne_microcode[5] = { rep_const, 5'd0, n, pc_b, am_p, addr_x, addr_x, addr_x, n, n, y, b_imm_shft, immed_type_b, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, y, n, y};

                                  
  wire [cs_sz-1:0] addi_microcode[2:0];

assign addi_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_load, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign addi_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign addi_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, y};


 wire [cs_sz-1:0] xori_microcode[2:0];

assign xori_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_load, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_xor, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign xori_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_xor, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign xori_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_xor, fn_shift_zero, fn_type_logic, n, shift_right, n, n, y};



 wire [cs_sz-1:0] ori_microcode[2:0];

assign ori_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_load, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_or, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign ori_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_or, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign ori_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_or, fn_shift_zero, fn_type_logic, n, shift_right, n, n, y};


 wire [cs_sz-1:0] andi_microcode[2:0];

assign andi_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_load, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign andi_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign andi_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, addr_x, rd, n, y, y, b_imm_shft, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_logic, n, shift_right, n, n, y};


  wire [cs_sz-1:0] add_microcode[2:0];

assign add_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign add_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign add_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, y};



  wire [cs_sz-1:0] sub_microcode[2:0];

assign sub_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_sub, carry_in_1, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign sub_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_sub, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign sub_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_sub, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, y};



  wire [cs_sz-1:0] slt_microcode[5:0];

assign slt_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, addr_x, n, n, n, b_imm_x, immed_type_x, n, bm_reg, fn_sub, carry_in_1, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign slt_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, rs2, addr_x, n, n, n, b_imm_x, immed_type_x, n, bm_reg, fn_sub, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign slt_microcode[2] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, addr_x, n, n, n, b_imm_x, immed_type_x, n, bm_reg, fn_sub, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign slt_microcode[3] = { rep_const, 5'd0, n, pc_x, am_r, r0, addr_x, rd, n, y, n, b_imm_x, immed_type_x, y, bm_imm, fn_add, carry_msb, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, n};
assign slt_microcode[4] = { rep_const, 5'd5, n, pc_x, am_r, r0, addr_x, rd, n, y, n, b_imm_x, immed_type_x, y, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, n};
assign slt_microcode[5] = { rep_const, 5'd0, n, pc_n, am_r, r0, addr_x, rd, n, y, n, b_imm_x, immed_type_x, y, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, y};



 wire [cs_sz-1:0] slti_microcode[5:0];

assign slti_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_load, immed_type_i, n, bm_imm, fn_sub, carry_in_1, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign slti_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_shft, immed_type_i, n, bm_imm, fn_sub, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign slti_microcode[2] = { rep_const, 5'd0, n, pc_x, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_shft, immed_type_i, n, bm_imm, fn_sub, carry_prop, fn_and, fn_shift_zero, fn_type_arith, y, shift_right, n, n, n};
assign slti_microcode[3] = { rep_const, 5'd0, n, pc_x, am_r, r0, addr_x, rd, n, y, n, b_imm_x, immed_type_x, y, bm_imm, fn_add, carry_msb, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, n};
assign slti_microcode[4] = { rep_const, 5'd5, n, pc_x, am_r, r0, addr_x, rd, n, y, n, b_imm_x, immed_type_x, y, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, n};
assign slti_microcode[5] = { rep_const, 5'd0, n, pc_n, am_r, r0, addr_x, rd, n, y, n, b_imm_x, immed_type_x, y, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, n, n, y};


 wire [cs_sz-1:0] xor_microcode[2:0];

assign xor_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_xor, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign xor_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_xor, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign xor_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_xor, fn_shift_zero, fn_type_logic, n, shift_right, n, n, y};



 wire [cs_sz-1:0] or_microcode[2:0];

assign or_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_or, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign or_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_or, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign or_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_or, fn_shift_zero, fn_type_logic, n, shift_right, n, n, y};


 wire [cs_sz-1:0] and_microcode[2:0];

assign and_microcode[0] = { rep_const, 5'd0, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign and_microcode[1] = { rep_const, 5'd5, n, pc_x, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_logic, n, shift_right, n, n, n};
assign and_microcode[2] = { rep_const, 5'd0, n, pc_n, am_r, rs1, rs2, rd, n, y, n, b_imm_x, immed_type_x, n, bm_reg, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_logic, n, shift_right, n, n, y};






wire [cs_sz-1:0] csrw_microcode[5:0];
assign csrw_microcode[0] = { rep_const, 5'd6, n, pc_x, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_x, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, y, n, n};
assign csrw_microcode[1] = { rep_const, 5'd0, y, pc_n, am_r, rs1, addr_x, addr_x, n, n, y, b_imm_x, immed_type_i, n, bm_imm, fn_add, carry_in_0, fn_and, fn_shift_zero, fn_type_arith, n, shift_right, y, n, y};


  wire [cs_sz-1:0] nop_microcode;
  // NOTE: It takes 8 cycles to calculate pc+4, so each NOP needs to be at least 8 (-3??) cycles long. Be safe with 8.
  // TODO: Confirm this actually works and doesn't end after 1 cycle.
                    //                     repeat, cp0_wen, pc_sel, amux_sel, addr_a, addr_b, addr_wb, mem_acc, wb_en, b_imm_en,  b_imm_sel,   b_imm_type, b_imm_zero,  bm_sel, addsub, ！carry_in_0, logic,         shift, flag_en, shift_en, br_reg_en,       new_isnt 
  assign nop_microcode =        { rep_const, 5'd7,       n,   pc_x,     am_p, addr_x, addr_x,  addr_x,       n,     n,        n,    b_imm_x, immed_type_x,          y,  bm_imm, fn_add,   carry_in_0, fn_and, fn_shift_zero,       n,        n,         n,           y };
  

  wire [cs_sz-1:0] cs_default = { rep_const, 5'd0,       n,   pc_x,     am_p, addr_x, addr_x,  addr_x,       n,     n,        n,    b_imm_x, immed_type_x,          y,  bm_imm, fn_add,   carry_in_0, fn_and, fn_shift_zero,fn_type_arith,     y, shift_right, n, n,   n };
                    
 


  wire [cs_sz-1:0] cs_mux_out;



reg [cs_sz-1:0] selected_uop;

always @ (*) begin
  casez ( ir )
  //   `TINYRV2_INST_MSG_NOP  : selected_uop = nop_microcode[uop_idx];
    `TINYRV2_INST_MSG_ADD  : selected_uop = add_microcode[uop_idx];
    `TINYRV2_INST_MSG_SUB  : selected_uop = sub_microcode[uop_idx];
    `TINYRV2_INST_MSG_AND  : selected_uop = and_microcode[uop_idx];
    `TINYRV2_INST_MSG_OR   : selected_uop = or_microcode[uop_idx];
    `TINYRV2_INST_MSG_XOR  : selected_uop = xor_microcode[uop_idx];
    `TINYRV2_INST_MSG_SLT  : selected_uop = slt_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SLTU : selected_uop = sltu_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SRA  : selected_uop = sra_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SRL  : selected_uop = srl_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SLL  : selected_uop = sll_microcode[uop_idx];
    // `TINYRV2_INST_MSG_MUL  : selected_uop = mul_microcode[uop_idx];
    `TINYRV2_INST_MSG_ADDI : selected_uop = addi_microcode[uop_idx];
    `TINYRV2_INST_MSG_ANDI : selected_uop = andi_microcode[uop_idx];
    `TINYRV2_INST_MSG_ORI  : selected_uop = ori_microcode[uop_idx];
    `TINYRV2_INST_MSG_XORI : selected_uop = xori_microcode[uop_idx];
    `TINYRV2_INST_MSG_SLTI : selected_uop = slti_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SLTIU: selected_uop = sltiu_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SRAI : selected_uop = srai_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SRLI : selected_uop = srli_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SLLI : selected_uop = slli_microcode[uop_idx];
    `TINYRV2_INST_MSG_LUI  : selected_uop = lui_microcode[uop_idx];
    `TINYRV2_INST_MSG_AUIPC: selected_uop = auipc_microcode[uop_idx];
    // `TINYRV2_INST_MSG_LW   : selected_uop = lw_microcode[uop_idx];
    // `TINYRV2_INST_MSG_SW   : selected_uop = sw_microcode[uop_idx];
    // `TINYRV2_INST_MSG_JAL  : selected_uop = jal_microcode[uop_idx];
    `TINYRV2_INST_MSG_JALR : selected_uop = jalr_microcode[uop_idx];
    // `TINYRV2_INST_MSG_BEQ  : selected_uop = beq_microcode[uop_idx];
    `TINYRV2_INST_MSG_BNE  : selected_uop = bne_microcode[uop_idx];
    // `TINYRV2_INST_MSG_BLT  : selected_uop = blt_microcode[uop_idx];
    // `TINYRV2_INST_MSG_BGE  : selected_uop = bge_microcode[uop_idx];
    // `TINYRV2_INST_MSG_BLTU : selected_uop = bltu_microcode[uop_idx];
    // `TINYRV2_INST_MSG_BGEU : selected_uop = bgeu_microcode[uop_idx];
    // // `TINYRV2_INST_MSG_CS: selected_uop = csrr_microcode[uop_idx];
    `TINYRV2_INST_MSG_CSRW : selected_uop = csrw_microcode[uop_idx];

    //default to nop
    default                : selected_uop = nop_microcode[uop_idx];
  endcase

end


 assign cs_mux_out = (new_instr_req || instr_req_pending || done_fetch) ? cs_default : selected_uop;


  //---------------------------
  // Decode Stage
  //---------------------------

  // Parse control signals from ROM

  wire [1:0] uop_repeat_mux_sel_Dhl = cs_mux_out[48:47];
  wire [4:0] uop_repeat_const_Dhl = cs_mux_out[46:42];

  wire [4:0] uop_repeat_mux_out_Dhl = (uop_repeat_mux_sel_Dhl == rep_reg) ? shamt_reg :
                                     ((uop_repeat_mux_sel_Dhl == rep_imm) ? rs2 :  // TODO: Fix shifts! This line assumes 1bit/cycle
                                       uop_repeat_const_Dhl);


  assign     uop_repeat_Dhl       = uop_repeat_mux_out_Dhl;
  wire       cp0_wen_Dhl          = cs_mux_out[41];
  wire       pc_mux_sel_Dhl       = cs_mux_out[40];
  wire       pc_plus4_mux_sel_Dhl = cs_mux_out[39]; // 1 -> PC+4, 0 -> PC. Part of a_mux_sel python
  wire       a_mux_sel_Dhl        = cs_mux_out[38]; // 1 indicates using PC or PC+4
 
  // Register Interface with Mem
  wire [4:0] rega_addr_Dhl        = cs_mux_out[37:33]; 
  wire [4:0] regb_addr_Dhl        = cs_mux_out[32:28]; 
  wire [4:0] wb_addr_Dhl          = cs_mux_out[27:23];


  wire       mem_access_Dhl       = cs_mux_out[22];

  wire       wb_en_Dhl;
  assign     wb_en_Dhl            = cs_mux_out[21];
        
  // ALU Inputs
  // Immediate handling
  wire       b_imm_reg_en_Dhl     = cs_mux_out[20];
  wire       b_imm_reg_sel_Dhl    = cs_mux_out[19];
  wire [2:0] b_imm_type_Dhl       = cs_mux_out[18:16];
  wire       b_imm_zero_Dhl       = cs_mux_out[15];
  wire       b_mux_sel_Dhl        = cs_mux_out[14];

  wire       addsub_fn_Dhl        = cs_mux_out[13];
  wire       prop_carry_Dhl       = cs_mux_out[12];
  wire       carry_in_1_Dhl       = cs_mux_out[11]; //no
  wire [1:0] logic_fn_Dhl         = cs_mux_out[10:9];
  wire [1:0] shift_fn_Dhl         = cs_mux_out[8:7];

  wire [1:0] alu_fn_type_Dhl      =cs_mux_out[6:5];

  wire       flag_reg_en_Dhl      = cs_mux_out[4];
  wire       shift_dir_sel_Dhl    = cs_mux_out[3];
  wire       addr_reg_en_Dhl      = cs_mux_out[2];
  wire       br_reg_en_Dhl        = cs_mux_out[1];
  assign     last_uop_Dhl         = cs_mux_out[0];

  // Old Control signals (currently unused)     
  // wire       wb_to_temp_Dhl       = cs_mux_out[29];
  // wire       a_read_temp_reg_Dhl   = cs_mux_out[28];

  // Process immediate value from IR as necesssary
  reg  [31:0] immed_Dhl;
  reg  [31:0] immed_Rhl;
  wire [31:0] immed_shift_mux_out_Dhl;

  wire [31:0] i_immed = {{21{ir[31]}}, ir[30:25], ir[24:21], ir[20]};
  wire [31:0] s_immed = {{21{ir[31]}}, ir[30:25], ir[11:8], ir[7]};
  wire [31:0] b_immed = {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0};
  wire [31:0] u_immed = {ir[31:12], 12'b0};
  wire [31:0] j_immed = {{12{ir[31]}}, ir[19:12], ir[20], ir[30:25], ir[24:21], 1'b0};

  reg [31:0] immed_type_out_Dhl;
  always @(*) begin
    case (b_imm_type_Dhl)
      immed_type_i: immed_type_out_Dhl = i_immed;
      immed_type_s: immed_type_out_Dhl = s_immed;
      immed_type_b: immed_type_out_Dhl = b_immed;
      immed_type_u: immed_type_out_Dhl = u_immed;
      immed_type_j: immed_type_out_Dhl = j_immed;
      default: immed_type_out_Dhl = 32'b0;
    endcase
  end

  assign immed_shift_mux_out_Dhl = (b_imm_reg_sel_Dhl) ? immed_type_out_Dhl : (immed_Rhl >> 4);

  always @(*)begin
    immed_Dhl = immed_Rhl;
    if (b_imm_reg_en_Dhl) begin
      immed_Dhl = immed_shift_mux_out_Dhl;
    end
  end

  always @ (posedge clk) begin
    if (reset) begin
      immed_Rhl <= 32'b0;
    end else begin
      immed_Rhl <= immed_Dhl;
    end
  end

  // Calculate sub-word offset to be used
  // Logic: Keep incrementing whenever nonzero register is being accessed.
  // Reset when zero is accessed. This assumes all non-r0 reg accesses occur
  // on word-aligned accesses.
  reg [2:0] a_subword_off_Dhl ;
  reg [2:0] b_subword_off_Dhl ;
  reg [2:0] wb_subword_off_Dhl;
  reg [2:0] wb_subword_off_Rhl;
      

// Reg A
always @ (*) begin
  if (reset || rega_addr_Dhl == 5'b0 || rega_addr_Dhl != rega_addr_Rhl)
    a_subword_off_Dhl = 3'b0;
  else begin
     a_subword_off_Dhl = a_subword_off_Rhl + 3'b1;
  end
end

// Reg B
always @ (*) begin
  if (reset || regb_addr_Dhl == 5'b0  || regb_addr_Dhl != regb_addr_Rhl)
    b_subword_off_Dhl = 3'b0;
  else begin
     b_subword_off_Dhl = b_subword_off_Rhl + 3'b1;
  end
end

// Writeback Reg
reg  [4:0] wb_addr_Rhl;
always @ (*) begin
  if (reset || wb_addr_Dhl == 5'b0 || wb_addr_Dhl != wb_addr_Rhl)
    wb_subword_off_Dhl = 3'b0;
  else begin
     wb_subword_off_Dhl = wb_subword_off_Rhl + 3'b1;
  end
end


  // Extract coprocessor info from IR
  wire [11:0] cp0_addr_Dhl = ir[31:20]; // Defined in RISC-V manual

  //----------------------
  // Register Read Stage
  //----------------------

  reg       pc_mux_sel_Rhl;
  reg       pc_plus4_mux_sel_Rhl;

  reg       mem_access_Rhl;
  reg       wb_en_Rhl;
  // reg       wb_to_temp_Rhl;
  reg       a_mux_sel_Rhl;
 


  // reg       a_read_temp_reg_Rhl;
  reg       b_imm_zero_Rhl; 
  reg       b_mux_sel_Rhl;


  reg       addsub_fn_Rhl;
  reg       prop_carry_Rhl;
  reg       carry_in_1_Rhl;
  reg [1:0] logic_fn_Rhl ;
  reg [1:0] shift_fn_Rhl ;

  reg [1:0] alu_fn_type_Rhl;

  reg       flag_reg_en_Rhl;
  reg       shift_dir_sel_Rhl;
  reg       addr_reg_en_Rhl;
  reg       last_uop_Rhl;
  reg       br_reg_en_Rhl;
  reg       cp0_wen_Rhl;
  reg [11:0]cp0_addr_Rhl;



  always @ (posedge clk) begin
    pc_mux_sel_Rhl       <= pc_mux_sel_Dhl;
    pc_plus4_mux_sel_Rhl <= pc_plus4_mux_sel_Dhl;
    rega_addr_Rhl        <= rega_addr_Dhl;
    regb_addr_Rhl        <= regb_addr_Dhl;
    wb_addr_Rhl          <= wb_addr_Dhl;
    mem_access_Rhl       <= mem_access_Dhl;
    wb_en_Rhl            <= wb_en_Dhl;
    // wb_to_temp_Rhl       <= wb_to_temp_Dhl;
    a_mux_sel_Rhl        <= a_mux_sel_Dhl;
    // a_read_temp_reg_Rhl   <= a_read_temp_reg_Dhl;
    b_imm_zero_Rhl       <= b_imm_zero_Dhl;
    b_mux_sel_Rhl        <= b_mux_sel_Dhl;

    a_subword_off_Rhl    <= a_subword_off_Dhl;
    // b_subword_off_Rhl    <= a_subword_off_Dhl; //bug
    b_subword_off_Rhl    <= b_subword_off_Dhl;
    wb_subword_off_Rhl   <= wb_subword_off_Dhl;

    addsub_fn_Rhl        <= addsub_fn_Dhl;
    prop_carry_Rhl       <= prop_carry_Dhl;
    carry_in_1_Rhl       <= carry_in_1_Dhl;
    logic_fn_Rhl         <= logic_fn_Dhl ;
    shift_fn_Rhl         <= shift_fn_Dhl ;
    alu_fn_type_Rhl      <= alu_fn_type_Dhl;

    flag_reg_en_Rhl      <= flag_reg_en_Dhl;
    shift_dir_sel_Rhl    <= shift_dir_sel_Dhl;
    addr_reg_en_Rhl      <= addr_reg_en_Dhl;
    last_uop_Rhl         <= last_uop_Dhl;
    br_reg_en_Rhl        <= br_reg_en_Dhl;
    cp0_wen_Rhl          <= cp0_wen_Dhl;
    cp0_addr_Rhl          <= cp0_addr_Dhl;
  end

  //---------------------------
  // Execute stage (X)
  //---------------------------
  reg        cp0_wen_Xhl;
  reg [11:0] cp0_addr_Xhl;
  always @ (posedge clk) begin
    pc_mux_sel_Xhl       <= pc_mux_sel_Rhl;
    pc_plus4_mux_sel_Xhl <= pc_plus4_mux_sel_Rhl;
    wb_addr_Xhl          <= wb_addr_Rhl;
    wb_subword_off_Xhl   <= wb_subword_off_Rhl;
    mem_access_Xhl       <= mem_access_Rhl;
    wb_en_Xhl            <= wb_en_Rhl;
    // wb_to_temp_Xhl       <= wb_to_temp_Rhl;
    a_mux_sel_Xhl        <= a_mux_sel_Rhl;
    // a_read_temp_reg_Xhl   <= a_read_temp_reg_Rhl;
    b_imm_Xhl            <= b_imm_zero_Rhl ? 1'b0 : immed_Rhl[3:0];

    b_mux_sel_Xhl        <= b_mux_sel_Rhl;

    addsub_fn_Xhl        <= addsub_fn_Rhl;
    prop_carry_Xhl       <= prop_carry_Rhl;
    carry_in_1_Xhl       <= carry_in_1_Rhl;
    logic_fn_Xhl         <= logic_fn_Rhl;
    shift_fn_Xhl         <= shift_fn_Rhl;
    alu_fn_type_Xhl      <= alu_fn_type_Rhl;
    flag_reg_en_Xhl      <= flag_reg_en_Rhl;
    shift_dir_sel_Xhl    <= shift_dir_sel_Rhl;

    addr_reg_en_Xhl      <= addr_reg_en_Rhl;
    last_uop_Xhl         <= last_uop_Rhl;
    br_reg_en_Xhl        <= br_reg_en_Rhl;
    cp0_wen_Xhl          <= cp0_wen_Rhl;
    cp0_addr_Xhl         <= cp0_addr_Rhl;
  end
  



// Coprocessor0
  reg        cp0_stats;

  reg [31:0] cp0_status_next;
  reg        cp0_stats_next;

  always @ (*) begin
    cp0_status_next = cp0_status;
    cp0_stats_next = cp0_stats;
    if (cp0_wen_Xhl && (cp0_addr_Xhl == 12'h7c0)) begin
      cp0_status_next = proc2cop_data_Xhl;
    end else if (cp0_wen_Xhl && (cp0_addr_Xhl == 12'h7c1)) begin
      cp0_stats_next = proc2cop_data_Xhl[0];
    end
  end

    // Handle dmem request/response signals

  // load=0 store=1; constant = opcode[6:0] for all stores taken from risc-v manual.
  assign dmemreq_msg_rw = (ir[6:0] == 7'b0100011);
  // 1 = 1B, 2 = 2B, 3 = 3B, 0 = 4B
  // In risc-v, all Byte have [13:12] == 00, Half = 01, Word = 10
  assign dmemreq_msg_len = (ir[13:12] == 00) ? 2'b01 :
                          ((ir[13:12] == 01) ? 2'b10 :
                          ((ir[13:12] == 10) ? 2'b00 :
                            2'b00));


  reg dmemreq_val_next;

  always @(*) begin
    dmemreq_val_next = dmemreq_val;
    if (dmemreq_val && dmemreq_rdy) begin
      dmemreq_val_next = 1'b0;
    end else if (mem_access_Xhl) begin
      dmemreq_val_next = 1'b1;
    end
  end

  reg dmemreq_pending;
  always @ (*)
  begin
    dmemreq_pending_next = dmemreq_pending;
    // If a dmem request is not pending and the instruction in X indicates it's ready to access memory
    if (dmemresp_val) begin // dmemresp rdy is always 1
      dmemreq_pending_next = 1'b0;
    end else if (mem_access_Xhl) begin
      dmemreq_pending_next = 1'b1;
    end
  end

  always @ (posedge clk) begin
    if (reset) begin
      cp0_status <= 32'b0;
      cp0_stats <= 1'b0;
      dmemreq_val <= 1'b0;
      dmemreq_pending <= 1'b0;
    end else begin
      cp0_status <= cp0_status_next;
      cp0_stats <= cp0_stats_next;
      dmemreq_val <= dmemreq_val_next;
      dmemreq_pending <= dmemreq_pending_next;
    end
  end

  // always @ ( posedge clk ) begin
  //   if ( cp0_wen_Xhl ) begin
  //     case ( cp0_addr )
  //       12'h7c0 : cp0_status <= proc2cop_data_Xhl;
  //       12'h7c1 : cp0_stats  <= proc2cop_data_Xhl[0];  
  //       // 5'd10 : cp0_stats  <= proc2cop_data_Xhl[0];
  //       // 5'd21 : cp0_status <= proc2cop_data_Xhl;
  //     endcase
  //   end
  // end
endmodule