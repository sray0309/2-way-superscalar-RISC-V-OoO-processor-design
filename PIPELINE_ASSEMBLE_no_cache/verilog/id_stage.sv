/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  id_stage.v                                          //
//                                                                     //
//  Description :  instruction decode (ID) stage of the pipeline;      // 
//                 decode the instruction fetch register operands, and // 
//                 compute immediate operand (if applicable)           // 
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`timescale 1ns/100ps


  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
module decoder(

	//input [31:0] inst,
	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	input IF_ID_PACKET if_packet,
	
	output ALU_OPA_SELECT opa_select,
	output ALU_OPB_SELECT opb_select,
	output DEST_REG_SEL   dest_reg, // mux selects
	output ALU_FUNC       alu_func,
	output logic rd_mem, wr_mem, cond_branch, uncond_branch,
	output logic csr_op,    // used for CSR operations, we only used this as 
	                        //a cheap way to get the return code out
	output logic halt,      // non-zero on a halt
	output logic illegal,    // non-zero on an illegal instruction
	output logic valid_inst  // for counting valid instructions executed
	                        // and for making the fetch stage die on halts/
	                        // keeping track of when to allow the next
	                        // instruction out of fetch
	                        // 0 for HALT and illegal instructions (die on halt)

);

	INST inst;
	logic valid_inst_in;
	
	assign inst          = if_packet.inst;
	assign valid_inst_in = if_packet.valid;
	assign valid_inst    = valid_inst_in & ~illegal;
	
	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		opa_select = OPA_IS_RS1;
		opb_select = OPB_IS_RS2;
		alu_func = ALU_ADD;
		dest_reg = DEST_NONE;
		csr_op = `FALSE;
		rd_mem = `FALSE;
		wr_mem = `FALSE;
		cond_branch = `FALSE;
		uncond_branch = `FALSE;
		halt = `FALSE;
		illegal = `FALSE;
		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_ZERO;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_AUIPC: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_PC;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_JAL: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_PC;
					opb_select    = OPB_IS_J_IMM;
					uncond_branch = `TRUE;
				end
				`RV32_JALR: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_RS1;
					opb_select    = OPB_IS_I_IMM;
					uncond_branch = `TRUE;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
					cond_branch = `TRUE;
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					rd_mem     = `TRUE;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					opb_select = OPB_IS_S_IMM;
					wr_mem     = `TRUE;
				end
				`RV32_ADDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
				end
				`RV32_SLTI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLT;
				end
				`RV32_SLTIU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLTU;
				end
				`RV32_ANDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_AND;
				end
				`RV32_ORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_OR;
				end
				`RV32_XORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_XOR;
				end
				`RV32_SLLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLL;
				end
				`RV32_SRLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRL;
				end
				`RV32_SRAI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRA;
				end
				`RV32_ADD: begin
					dest_reg   = DEST_RD;
				end
				`RV32_SUB: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SUB;
				end
				`RV32_SLT: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLT;
				end
				`RV32_SLTU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLTU;
				end
				`RV32_AND: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_AND;
				end
				`RV32_OR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_OR;
				end
				`RV32_XOR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_XOR;
				end
				`RV32_SLL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLL;
				end
				`RV32_SRL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRL;
				end
				`RV32_SRA: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRA;
				end
				`RV32_MUL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MUL;
				end
				`RV32_MULH: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULH;
				end
				`RV32_MULHSU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHSU;
				end
				`RV32_MULHU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_MULHU;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					csr_op = `TRUE;
				end
				`WFI: begin
					halt = `TRUE;
				end
				default: illegal = `TRUE;

		endcase // casez (inst)
		end // if(valid_inst_in)
	end // always
endmodule // decoder


module id_stage(         
	input         clock,              // system clock
	input         reset,              // system reset
//	input         wb_reg_wr_en_out,    // Reg write enable from WB Stage
//	input  [4:0] wb_reg_wr_idx_out,  // Reg write index from WB Stage
//	input  [`XLEN-1:0] wb_reg_wr_data_out,  // Reg write data from WB Stage
	input  IF_ID_PACKET [1:0] if_id_packet_in,
	
	output ID_RN_PACKET [1:0] id_packet_out
);

    assign id_packet_out[0].inst = if_id_packet_in[0].inst;
	assign id_packet_out[1].inst = if_id_packet_in[1].inst;

    assign id_packet_out[0].NPC  = if_id_packet_in[0].NPC;
	assign id_packet_out[1].NPC  = if_id_packet_in[1].NPC;

    assign id_packet_out[0].PC   = if_id_packet_in[0].PC;
	assign id_packet_out[1].PC   = if_id_packet_in[1].PC;

	assign id_packet_out[0].predict_take_branch = if_id_packet_in[0].predict_take_branch;
	assign id_packet_out[1].predict_take_branch = if_id_packet_in[1].predict_take_branch;

	assign id_packet_out[0].predict_target_pc = if_id_packet_in[0].predict_target_pc;
	assign id_packet_out[1].predict_target_pc = if_id_packet_in[1].predict_target_pc;
	
	DEST_REG_SEL [1:0] dest_reg_select; 

	assign id_packet_out[0].arega_idx = if_id_packet_in[0].inst.r.rs1;
	assign id_packet_out[1].arega_idx = if_id_packet_in[1].inst.r.rs1;

	assign id_packet_out[0].aregb_idx = if_id_packet_in[0].inst.r.rs2;
	assign id_packet_out[1].aregb_idx = if_id_packet_in[1].inst.r.rs2;



	// instantiate the instruction decoder
	decoder decoder_0 (
		.if_packet(if_id_packet_in[0]),	 
		// Outputs
		.opa_select(id_packet_out[0].opa_select),
		.opb_select(id_packet_out[0].opb_select),
		.alu_func(id_packet_out[0].alu_func),
		.dest_reg(dest_reg_select[0]),
		.rd_mem(id_packet_out[0].rd_mem),
		.wr_mem(id_packet_out[0].wr_mem),
		.cond_branch(id_packet_out[0].cond_branch),
		.uncond_branch(id_packet_out[0].uncond_branch),
		.csr_op(id_packet_out[0].csr_op),
		.halt(id_packet_out[0].halt),
		.illegal(id_packet_out[0].illegal),
		.valid_inst(id_packet_out[0].valid)
	);


	decoder decoder_1 (
		.if_packet(if_id_packet_in[1]),	 
		// Outputs
		.opa_select(id_packet_out[1].opa_select),
		.opb_select(id_packet_out[1].opb_select),
		.alu_func(id_packet_out[1].alu_func),
		.dest_reg(dest_reg_select[1]),
		.rd_mem(id_packet_out[1].rd_mem),
		.wr_mem(id_packet_out[1].wr_mem),
		.cond_branch(id_packet_out[1].cond_branch),
		.uncond_branch(id_packet_out[1].uncond_branch),
		.csr_op(id_packet_out[1].csr_op),
		.halt(id_packet_out[1].halt),
		.illegal(id_packet_out[1].illegal),
		.valid_inst(id_packet_out[1].valid)
	);
	// mux to generate dest_reg_idx based on
	// the dest_reg_select output from decoder
	always_comb begin
		case (dest_reg_select[0])
			DEST_RD:    id_packet_out[0].adest_idx = if_id_packet_in[0].inst.r.rd;
			DEST_NONE:  id_packet_out[0].adest_idx = `ZERO_REG;
			default:    id_packet_out[0].adest_idx = `ZERO_REG; 
		endcase
	end
   
	always_comb begin
		case (dest_reg_select[1])
			DEST_RD:    id_packet_out[1].adest_idx = if_id_packet_in[1].inst.r.rd;
			DEST_NONE:  id_packet_out[1].adest_idx = `ZERO_REG;
			default:    id_packet_out[1].adest_idx = `ZERO_REG; 
		endcase
	end

endmodule // module id_stage
