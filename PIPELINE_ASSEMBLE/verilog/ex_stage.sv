//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  ex_stage.v                                           //
//                                                                      //
//  Description :  instruction execute (EX) stage of the pipeline;      //
//                 given the instruction command code CMD, select the   //
//                 proper input A and B for the ALU, compute the result,// 
//                 and compute the condition for branches, and pass all //
//                 the results down the pipeline. MWB                   // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////


`ifndef __EX_STAGE_V__
`define __EX_STAGE_V__

`timescale 1ns/100ps
//
// The ALU
//
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
//
// This module is purely combinational
//
module alu(
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	ALU_FUNC     func,

	output logic [`XLEN-1:0] result
);
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	assign signed_opa = opa;
	assign signed_opb = opb;

	always_comb begin
		case (func)
			ALU_ADD:      result = opa + opb;
			ALU_SUB:      result = opa - opb;
			ALU_AND:      result = opa & opb;
			ALU_SLT:      result = signed_opa < signed_opb;
			ALU_SLTU:     result = opa < opb;
			ALU_OR:       result = opa | opb;
			ALU_XOR:      result = opa ^ opb;
			ALU_SRL:      result = opa >> opb[4:0];
			ALU_SLL:      result = opa << opb[4:0];
			ALU_SRA:      result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
			// ALU_MUL:      result = signed_mul[`XLEN-1:0];
			// ALU_MULH:     result = signed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHSU:   result = mixed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHU:    result = unsigned_mul[2*`XLEN-1:`XLEN];

			default:      result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end
endmodule // alu

//
// BrCond module
//
// Given the instruction code, compute the proper condition for the
// instruction; for branches this condition will indicate whether the
// target is taken.
//
// This module is purely combinational
//
module brcond(// Inputs
	input [`XLEN-1:0] rs1,    // Value to check against condition
	input [`XLEN-1:0] rs2,
	input  [2:0] func,  // Specifies which condition to check

	output logic cond    // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		cond = 0;
		case (func)
			3'b000: cond = signed_rs1 == signed_rs2;  // BEQ
			3'b001: cond = signed_rs1 != signed_rs2;  // BNE
			3'b100: cond = signed_rs1 < signed_rs2;   // BLT
			3'b101: cond = signed_rs1 >= signed_rs2;  // BGE
			3'b110: cond = rs1 < rs2;                 // BLTU
			3'b111: cond = rs1 >= rs2;                // BGEU
		endcase
	end
	
endmodule // brcond

module ex_stage(
	input clock,               // system clock
	input reset,               // system reset


    input [1:0][`PREG_IDX_WIDTH-1:0] wb_idx,
    input [1:0] wb_en,
    input [1:0][`XLEN-1:0] wb_data,
	input  IS_EX_PACKET   [1:0] is_ex_packet_in,

	input  SQ_FU_PACKET   [1:0] sq_fu_packet_in,
	input  LQ_FU_PACKET   [1:0] lq_fu_packet_in,

	output FU_SQ_PACKET   [1:0] fu_sq_packet_out,
	output FU_LQ_PACKET   [1:0] fu_lq_packet_out,

	output EX_CM_PACKET   [1:0] ex_packet_out,
	output logic [1:0]    ex_stall,
	output logic rd_ld_buffer_stall
);

logic [1:0][`XLEN-1:0] rega_value;
logic [1:0][`XLEN-1:0] regb_value;

logic [1:0][`XLEN-1:0] opa_mux_out;
logic [1:0][`XLEN-1:0] opb_mux_out;

logic [1:0] brcond_result;
logic [1:0] mult_en;
logic [1:0][31:0] mult_result;
logic [1:0] mult_done;

logic [1:0][`XLEN-1:0] alu_result;
logic [1:0] take_branch;
EX_MULT_PACKET [1:0] ex_mult_packet_in;
EX_MULT_PACKET [1:0] ex_mult_packet_out;

//packet sent to lsq
assign fu_sq_packet_out[0].done       = is_ex_packet_in[0].STORE_ready;
assign fu_sq_packet_out[0].result     = alu_result[0];
assign fu_sq_packet_out[0].pdest_idx  = is_ex_packet_in[0].pdest_idx;
assign fu_sq_packet_out[0].rob_idx    = is_ex_packet_in[0].rob_idx;
assign fu_sq_packet_out[0].SQ_idx     = is_ex_packet_in[0].sq_idx;
assign fu_sq_packet_out[0].LQ_idx     = is_ex_packet_in[0].lq_idx;
assign fu_sq_packet_out[0].regb_value = regb_value[0];
assign fu_sq_packet_out[0].mem_size   = is_ex_packet_in[0].inst.r.funct3;

assign fu_sq_packet_out[1].done       = is_ex_packet_in[1].STORE_ready;
assign fu_sq_packet_out[1].result     = alu_result[1];
assign fu_sq_packet_out[1].pdest_idx  = is_ex_packet_in[1].pdest_idx;
assign fu_sq_packet_out[1].rob_idx    = is_ex_packet_in[1].rob_idx;
assign fu_sq_packet_out[1].SQ_idx     = is_ex_packet_in[1].sq_idx;
assign fu_sq_packet_out[1].LQ_idx     = is_ex_packet_in[1].lq_idx;
assign fu_sq_packet_out[1].regb_value = regb_value[1];
assign fu_sq_packet_out[1].mem_size   = is_ex_packet_in[1].inst.r.funct3;

assign fu_lq_packet_out[0].done      = is_ex_packet_in[0].LOAD_ready;
assign fu_lq_packet_out[0].inst      = is_ex_packet_in[0].inst;
assign fu_lq_packet_out[0].result    = alu_result[0];
assign fu_lq_packet_out[0].pdest_idx = is_ex_packet_in[0].pdest_idx;
assign fu_lq_packet_out[0].rob_idx   = is_ex_packet_in[0].rob_idx;
assign fu_lq_packet_out[0].SQ_idx    = is_ex_packet_in[0].sq_idx;
assign fu_lq_packet_out[0].LQ_idx    = is_ex_packet_in[0].lq_idx;
assign fu_lq_packet_out[0].mem_size  = is_ex_packet_in[0].inst.r.funct3;

assign fu_lq_packet_out[1].done      = is_ex_packet_in[1].LOAD_ready;
assign fu_lq_packet_out[1].inst      = is_ex_packet_in[1].inst;
assign fu_lq_packet_out[1].result    = alu_result[1];
assign fu_lq_packet_out[1].pdest_idx = is_ex_packet_in[1].pdest_idx;
assign fu_lq_packet_out[1].rob_idx   = is_ex_packet_in[1].rob_idx;
assign fu_lq_packet_out[1].SQ_idx    = is_ex_packet_in[1].sq_idx;
assign fu_lq_packet_out[1].LQ_idx    = is_ex_packet_in[1].lq_idx;
assign fu_lq_packet_out[1].mem_size  = is_ex_packet_in[1].inst.r.funct3;
//

//packet sent to mult
assign ex_mult_packet_in[1].NPC         = is_ex_packet_in[1].NPC;
assign ex_mult_packet_in[1].inst        = is_ex_packet_in[1].inst;
assign ex_mult_packet_in[1].rob_idx     = is_ex_packet_in[1].rob_idx;
assign ex_mult_packet_in[1].pdest_idx   = is_ex_packet_in[1].pdest_idx;
assign ex_mult_packet_in[1].halt        = is_ex_packet_in[1].halt;
assign ex_mult_packet_in[1].illegal     = is_ex_packet_in[1].illegal;
assign ex_mult_packet_in[1].csr_op      = is_ex_packet_in[1].csr_op;
assign ex_mult_packet_in[1].valid       = is_ex_packet_in[1].valid;
assign ex_mult_packet_in[1].take_branch = take_branch[1];
assign ex_mult_packet_in[1].regb_value  = regb_value[1];
assign ex_mult_packet_in[1].rd_mem      = is_ex_packet_in[1].rd_mem;
assign ex_mult_packet_in[1].wr_mem      = is_ex_packet_in[1].wr_mem;
assign ex_mult_packet_in[1].mem_size    = is_ex_packet_in[1].inst.r.funct3;

assign ex_mult_packet_in[0].NPC         = is_ex_packet_in[0].NPC;
assign ex_mult_packet_in[0].inst        = is_ex_packet_in[0].inst;
assign ex_mult_packet_in[0].rob_idx     = is_ex_packet_in[0].rob_idx;
assign ex_mult_packet_in[0].pdest_idx   = is_ex_packet_in[0].pdest_idx;
assign ex_mult_packet_in[0].halt        = is_ex_packet_in[0].halt;
assign ex_mult_packet_in[0].illegal     = is_ex_packet_in[0].illegal;
assign ex_mult_packet_in[0].csr_op      = is_ex_packet_in[0].csr_op;
assign ex_mult_packet_in[0].valid       = is_ex_packet_in[0].valid;
assign ex_mult_packet_in[0].take_branch = take_branch[0];
assign ex_mult_packet_in[0].regb_value  = regb_value[0];
assign ex_mult_packet_in[0].rd_mem      = is_ex_packet_in[0].rd_mem;
assign ex_mult_packet_in[0].wr_mem      = is_ex_packet_in[0].wr_mem;
assign ex_mult_packet_in[0].mem_size    = is_ex_packet_in[0].inst.r.funct3;
//

assign ex_packet_out[0].mult_done = mult_done[0];
assign ex_packet_out[1].mult_done = mult_done[1];

assign ex_packet_out[0].alu_done = mult_done[0] || lq_fu_packet_in[0].done ? 1'b0:is_ex_packet_in[0].ALU_ready ;
assign ex_packet_out[1].alu_done = mult_done[1] || lq_fu_packet_in[1].done ? 1'b0:is_ex_packet_in[1].ALU_ready ;

assign ex_packet_out[0].branch_done = mult_done[0] || lq_fu_packet_in[0].done  ? 1'b0:is_ex_packet_in[0].BR_ready;
assign ex_packet_out[1].branch_done = mult_done[1] || lq_fu_packet_in[1].done  ? 1'b0:is_ex_packet_in[1].BR_ready;

assign ex_packet_out[0].store_done = mult_done[0] ? 1'b0:sq_fu_packet_in[0].done;
assign ex_packet_out[1].store_done = mult_done[1] ? 1'b0:sq_fu_packet_in[1].done;

assign ex_packet_out[0].load_done = mult_done[0] ? 1'b0:lq_fu_packet_in[0].done;
assign ex_packet_out[1].load_done = mult_done[1] ? 1'b0:lq_fu_packet_in[1].done;


regfile regfile_0(
    .rda_idx({is_ex_packet_in[1].prega_idx,is_ex_packet_in[0].prega_idx}),
    .rdb_idx({is_ex_packet_in[1].pregb_idx,is_ex_packet_in[0].pregb_idx}),
    .rda_out(rega_value), 
    .rdb_out(regb_value),

    .wr_clk(clock),
    .wr_en(wb_en),
    .wr_idx(wb_idx),
    .wr_data(wb_data)
);

	//
	// ALU opA_0 mux
	//
	always_comb begin
		opa_mux_out[0] =  `XLEN'hdeadfbac;
		case (is_ex_packet_in[0].opa_select)
			OPA_IS_RS1:  opa_mux_out[0] = rega_value[0];
			OPA_IS_NPC:  opa_mux_out[0] = is_ex_packet_in[0].NPC;
			OPA_IS_PC:   opa_mux_out[0] = is_ex_packet_in[0].PC;
			OPA_IS_ZERO: opa_mux_out[0] = 0;
		endcase
	end

    //
	// ALU opA_1 mux
	//
	always_comb begin
		opa_mux_out[1] =  `XLEN'hdeadfbac;
		case (is_ex_packet_in[1].opa_select)
			OPA_IS_RS1:  opa_mux_out[1] = rega_value[1];
			OPA_IS_NPC:  opa_mux_out[1] = is_ex_packet_in[1].NPC;
			OPA_IS_PC:   opa_mux_out[1] = is_ex_packet_in[1].PC;
			OPA_IS_ZERO: opa_mux_out[1] = 0;
		endcase
	end

	 //
	 // ALU opB_0 mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out[0] = `XLEN'hfacefeed;
		case (is_ex_packet_in[0].opb_select)
			OPB_IS_RS2:   opb_mux_out[0] = regb_value[0];
			OPB_IS_I_IMM: opb_mux_out[0] = `RV32_signext_Iimm(is_ex_packet_in[0].inst);
			OPB_IS_S_IMM: opb_mux_out[0] = `RV32_signext_Simm(is_ex_packet_in[0].inst);
			OPB_IS_B_IMM: opb_mux_out[0] = `RV32_signext_Bimm(is_ex_packet_in[0].inst);
			OPB_IS_U_IMM: opb_mux_out[0] = `RV32_signext_Uimm(is_ex_packet_in[0].inst);
			OPB_IS_J_IMM: opb_mux_out[0] = `RV32_signext_Jimm(is_ex_packet_in[0].inst);
		endcase 
	end

    //
	 // ALU opB_1 mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out[1] = `XLEN'hfacefeed;
		case (is_ex_packet_in[1].opb_select)
			OPB_IS_RS2:   opb_mux_out[1] = regb_value[1];
			OPB_IS_I_IMM: opb_mux_out[1] = `RV32_signext_Iimm(is_ex_packet_in[1].inst);
			OPB_IS_S_IMM: opb_mux_out[1] = `RV32_signext_Simm(is_ex_packet_in[1].inst);
			OPB_IS_B_IMM: opb_mux_out[1] = `RV32_signext_Bimm(is_ex_packet_in[1].inst);
			OPB_IS_U_IMM: opb_mux_out[1] = `RV32_signext_Uimm(is_ex_packet_in[1].inst);
			OPB_IS_J_IMM: opb_mux_out[1] = `RV32_signext_Jimm(is_ex_packet_in[1].inst);
		endcase 
	end


	always_comb begin
		if(is_ex_packet_in[0].MULT_ready) 
			mult_en[0] = 1'b1;
		else 
			mult_en[0] = 1'b0;
	end

	always_comb begin
		if(is_ex_packet_in[1].MULT_ready) 
			mult_en[1] = 1'b1; 
		else
			mult_en[1] = 1'b0; 
	end

	//ex_packet_out assignment for cdb broadcast
	always_comb begin
		ex_stall[0] = 1'b0;
		rd_ld_buffer_stall = 1'b0;
		if(mult_done[0]) begin
			ex_packet_out[0].result      = mult_result[0];
			ex_packet_out[0].NPC         = ex_mult_packet_out[0].NPC;
			ex_packet_out[0].inst        = ex_mult_packet_out[0].inst;
			ex_packet_out[0].rob_idx     = ex_mult_packet_out[0].rob_idx;
			ex_packet_out[0].pdest_idx   = ex_mult_packet_out[0].pdest_idx;
			ex_packet_out[0].halt        = ex_mult_packet_out[0].halt;
			ex_packet_out[0].illegal     = ex_mult_packet_out[0].illegal;
			ex_packet_out[0].csr_op      = ex_mult_packet_out[0].csr_op;
			ex_packet_out[0].valid       = ex_mult_packet_out[0].valid;
			ex_packet_out[0].take_branch = 1'b0;//ex_mult_packet_out[0].take_branch;
			ex_packet_out[0].regb_value  = ex_mult_packet_out[0].regb_value;
			ex_packet_out[0].rd_mem      = ex_mult_packet_out[0].rd_mem;
			ex_packet_out[0].wr_mem      = ex_mult_packet_out[0].wr_mem;
			ex_packet_out[0].mem_size    = ex_mult_packet_out[0].mem_size;
			if( !mult_en[0] && (is_ex_packet_in[0].valid || lq_fu_packet_in[0].done) ) ex_stall[0] = 1'b1;	
			
			if(lq_fu_packet_in[0].done && is_ex_packet_in[0].rob_idx !=lq_fu_packet_in[0].rob_idx) rd_ld_buffer_stall = 1'b1;	   
		end
		else if(lq_fu_packet_in[0].done)begin
			ex_packet_out[0].result      = lq_fu_packet_in[0].result;
			ex_packet_out[0].rob_idx     = lq_fu_packet_in[0].rob_idx;
			ex_packet_out[0].pdest_idx   = lq_fu_packet_in[0].pdest_idx;
			ex_packet_out[0].inst        = lq_fu_packet_in[0].inst;
			ex_packet_out[0].halt        = 1'b0;
			ex_packet_out[0].illegal     = 1'b0;
			ex_packet_out[0].csr_op      = 1'b0;
			ex_packet_out[0].valid       = 1'b1;
			ex_packet_out[0].take_branch = 1'b0;
			ex_packet_out[0].rd_mem      = 1'b1;
			ex_packet_out[0].wr_mem      = 1'b0;
			if(is_ex_packet_in[0].valid && (is_ex_packet_in[0].rob_idx !=lq_fu_packet_in[0].rob_idx) ) ex_stall[0] = 1'b1;  
		end else if (is_ex_packet_in[0].ALU_ready | is_ex_packet_in[0].BR_ready | is_ex_packet_in[0].STORE_ready )begin
			ex_packet_out[0].result      = alu_result[0];
			ex_packet_out[0].NPC         = is_ex_packet_in[0].NPC;
			ex_packet_out[0].inst        = is_ex_packet_in[0].inst;
			ex_packet_out[0].rob_idx     = is_ex_packet_in[0].rob_idx;
			ex_packet_out[0].pdest_idx   = is_ex_packet_in[0].pdest_idx;
			ex_packet_out[0].halt        = is_ex_packet_in[0].halt;
			ex_packet_out[0].illegal     = is_ex_packet_in[0].illegal;
			ex_packet_out[0].csr_op      = is_ex_packet_in[0].csr_op;
			ex_packet_out[0].valid       = is_ex_packet_in[0].valid;
			ex_packet_out[0].take_branch = take_branch[0];
			ex_packet_out[0].regb_value  = regb_value[0];
			ex_packet_out[0].rd_mem      = is_ex_packet_in[0].rd_mem;
			ex_packet_out[0].wr_mem      = is_ex_packet_in[0].wr_mem;
			ex_packet_out[0].mem_size    = is_ex_packet_in[0].inst.r.funct3;
        end else begin
            ex_packet_out[0].result      = 0;
			ex_packet_out[0].NPC         = 0;
			ex_packet_out[0].inst        = `NOP;
			ex_packet_out[0].rob_idx     = 0;
			ex_packet_out[0].pdest_idx   = 0;
			ex_packet_out[0].halt        = 0;
			ex_packet_out[0].illegal     = 0;
			ex_packet_out[0].csr_op      = 0;
			ex_packet_out[0].valid       = 0;
			ex_packet_out[0].take_branch = 0;
			ex_packet_out[0].regb_value  = 0;
			ex_packet_out[0].rd_mem      = 0;
			ex_packet_out[0].wr_mem      = 0;
			ex_packet_out[0].mem_size    = 0;
        end
	end

	always_comb begin
		ex_stall[1] = 1'b0;
		if(mult_done[1]) begin
			ex_packet_out[1].result      = mult_result[1];
			ex_packet_out[1].NPC         = ex_mult_packet_out[1].NPC;
			ex_packet_out[1].inst        = ex_mult_packet_out[1].inst;
			ex_packet_out[1].rob_idx     = ex_mult_packet_out[1].rob_idx;	
			ex_packet_out[1].pdest_idx   = ex_mult_packet_out[1].pdest_idx;
			ex_packet_out[1].halt        = ex_mult_packet_out[1].halt;
			ex_packet_out[1].illegal     = ex_mult_packet_out[1].illegal;
			ex_packet_out[1].csr_op      = ex_mult_packet_out[1].csr_op;
			ex_packet_out[1].valid       = ex_mult_packet_out[1].valid;
			ex_packet_out[1].take_branch = 1'b0;//ex_mult_packet_out[1].take_branch;
			ex_packet_out[1].regb_value  = ex_mult_packet_out[1].regb_value;
			ex_packet_out[1].rd_mem      = ex_mult_packet_out[1].rd_mem;
			ex_packet_out[1].wr_mem      = ex_mult_packet_out[1].wr_mem;
			ex_packet_out[1].mem_size    = ex_mult_packet_out[1].mem_size;
			if( !mult_en[1] && is_ex_packet_in[1].valid) ex_stall[1] = 1'b1;		   
		end
		else if(lq_fu_packet_in[1].done) begin
			ex_packet_out[1].result      = lq_fu_packet_in[1].result;
			ex_packet_out[1].rob_idx     = lq_fu_packet_in[1].rob_idx;
			ex_packet_out[1].pdest_idx   = lq_fu_packet_in[1].pdest_idx;
			ex_packet_out[1].halt        = 1'b0;
			ex_packet_out[1].illegal     = 1'b0;
			ex_packet_out[1].csr_op      = 1'b0;
			ex_packet_out[1].valid       = 1'b1;
			ex_packet_out[1].take_branch = 1'b0;
			ex_packet_out[1].rd_mem      = 1'b1;
			ex_packet_out[1].wr_mem      = 1'b0;
			//if(is_ex_packet_in[1].valid) ex_stall[1] = 1'b1;  
		end else if (is_ex_packet_in[1].ALU_ready | is_ex_packet_in[1].BR_ready | is_ex_packet_in[1].STORE_ready) begin
			ex_packet_out[1].result      = alu_result[1];
			ex_packet_out[1].NPC         = is_ex_packet_in[1].NPC;
			ex_packet_out[1].inst        = is_ex_packet_in[1].inst;
			ex_packet_out[1].rob_idx     = is_ex_packet_in[1].rob_idx;
			ex_packet_out[1].pdest_idx   = is_ex_packet_in[1].pdest_idx;
			ex_packet_out[1].halt        = is_ex_packet_in[1].halt;
			ex_packet_out[1].illegal     = is_ex_packet_in[1].illegal;
			ex_packet_out[1].csr_op      = is_ex_packet_in[1].csr_op;
			ex_packet_out[1].valid       = is_ex_packet_in[1].valid;
			ex_packet_out[1].take_branch = take_branch[1];
			ex_packet_out[1].regb_value  = regb_value[1];
			ex_packet_out[1].rd_mem      = is_ex_packet_in[1].rd_mem;
			ex_packet_out[1].wr_mem      = is_ex_packet_in[1].wr_mem;
			ex_packet_out[1].mem_size    = is_ex_packet_in[1].inst.r.funct3;
        end else begin
            ex_packet_out[1].result      = 0;
			ex_packet_out[1].NPC         = 0;
			ex_packet_out[1].inst        = `NOP;
			ex_packet_out[1].rob_idx     = 0;
			ex_packet_out[1].pdest_idx   = 0;
			ex_packet_out[1].halt        = 0;
			ex_packet_out[1].illegal     = 0;
			ex_packet_out[1].csr_op      = 0;
			ex_packet_out[1].valid       = 0;
			ex_packet_out[1].take_branch = 0;
			ex_packet_out[1].regb_value  = 0;
			ex_packet_out[1].rd_mem      = 0;
			ex_packet_out[1].wr_mem      = 0;
			ex_packet_out[1].mem_size    = 0;
        end
	end
	    
alu alu_0 (// Inputs
    .opa(opa_mux_out[0]),
    .opb(opb_mux_out[0]),
    .func(is_ex_packet_in[0].alu_func),

    // Output
    .result(alu_result[0])
);

alu alu_1 (// Inputs
    .opa(opa_mux_out[1]),
    .opb(opb_mux_out[1]),
    .func(is_ex_packet_in[1].alu_func),

    // Output
    .result(alu_result[1])
);

mult_top mult_0(
	.clock(clock),
	.reset(reset),
	.mcand(opa_mux_out[0]),
	.mplier(opb_mux_out[0]),
	.start(mult_en[0]),
	.alu_func(is_ex_packet_in[0].alu_func),
	.ex_mult_packet_in(ex_mult_packet_in[0]),

	.ex_mult_packet_out(ex_mult_packet_out[0]),
	.product(mult_result[0]),
	.done(mult_done[0])
);

mult_top mult_1(
	.clock(clock),
	.reset(reset),
	.mcand(opa_mux_out[1]),
	.mplier(opb_mux_out[1]),
	.start(mult_en[1]),
	.alu_func(is_ex_packet_in[1].alu_func),
	.ex_mult_packet_in(ex_mult_packet_in[1]),

	.ex_mult_packet_out(ex_mult_packet_out[1]),
	.product(mult_result[1]),
	.done(mult_done[1])
);

brcond brcond_0 (// Inputs
    .rs1(rega_value[0]), 
    .rs2(regb_value[0]),
    .func(is_ex_packet_in[0].inst.b.funct3), // inst bits to determine check

    // Output
    .cond(brcond_result[0])
);

brcond brcond_1 (// Inputs
    .rs1(rega_value[1]), 
    .rs2(regb_value[1]),
    .func(is_ex_packet_in[1].inst.b.funct3), // inst bits to determine check

    // Output
    .cond(brcond_result[1])
);

	 // ultimate "take branch" signal:
	 //	unconditional, or conditional and the condition is true
	assign take_branch[0] = is_ex_packet_in[0].uncond_branch
		                          | (is_ex_packet_in[0].cond_branch & brcond_result[0]);

	assign take_branch[1] = is_ex_packet_in[1].uncond_branch
		                          | (is_ex_packet_in[1].cond_branch & brcond_result[1]);


endmodule
`endif




