`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

module pipeline (

	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,      // Address sent to memory
	output logic [63:0] proc2mem_data,      // Data sent to memory
	output MEM_SIZE proc2mem_size,          // data size sent to memory

	output logic [1:0][3:0]  pipeline_completed_insts,
	output EXCEPTION_CODE   pipeline_error_status,
	output logic [1:0][`PREG_IDX_WIDTH-1:0]  pipeline_commit_wr_idx,
	output logic [1:0][`XLEN-1:0] pipeline_commit_wr_data,
	output logic [1:0]       pipeline_commit_wr_en,
	output logic [1:0][`XLEN-1:0] pipeline_commit_NPC,
	
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory
	
	
	// Outputs from IF-Stage 
	output logic [1:0][`XLEN-1:0] if_NPC_out,
	output logic [1:0][31:0]      if_IR_out,
	output logic [1:0]            if_valid_inst_out,
	
	// Outputs from IF/ID Pipeline Register
	output logic [1:0][`XLEN-1:0] if_id_NPC,
	output logic [1:0][31:0] if_id_IR,
	output logic [1:0]       if_id_valid_inst,
	
	
	// Outputs from ID/RN Pipeline Register
	output logic [1:0][`XLEN-1:0] id_rn_NPC,
	output logic [1:0][31:0] id_rn_IR,
	output logic [1:0]       id_rn_valid_inst,
	
	// Outputs from RN/DP Pipeline Register
	output logic [1:0][`XLEN-1:0] rn_dp_NPC,
	output logic [1:0][31:0] rn_dp_IR,
	output logic [1:0]       rn_dp_valid_inst,

	// Outputs from IS/EX Pipeline Register
	output logic [1:0][`XLEN-1:0] is_ex_NPC,
	output logic [1:0][31:0] is_ex_IR,
	output logic [1:0]       is_ex_valid_inst,

	// Outputs from EX/CM Pipeline Register
	output logic [1:0][`XLEN-1:0] ex_cm_NPC,
	output logic [1:0][31:0] ex_cm_IR,
	output logic [1:0]       ex_cm_valid_inst
	
	
	// Outputs from CM/RT Pipeline Register
	// output logic [`XLEN-1:0] cm_rt_NPC,
	// output logic [31:0] cm_rt_IR,
	// output logic        cm_rt_valid_inst

);

	// Pipeline register enables
	logic   if_id_enable, id_rn_enable, rn_dp_enable, is_ex_enable, ex_cm_enable;
	
	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	IF_ID_PACKET [1:0] if_packet;

	// Outputs from IF/ID Pipeline Register
	IF_ID_PACKET [1:0] if_id_packet;

	// Outputs from ID stage
	ID_RN_PACKET [1:0] id_packet;

	// Outputs from ID/RN Pipeline Register
	ID_RN_PACKET [1:0] id_rn_packet;

	// Outputs from RN stage
	RN_DP_PACKET [1:0] rn_dp_packet;

	// Outputs from DP_IS stage
	IS_EX_PACKET [1:0] is_packet;
	ROB_PACKET   [1:0] rob_packet;
	logic [1:0] rs_full;
	logic rob_almost_full;
	logic rob_full;
	logic head_retire_rdy;
	logic head_p1_retire_rdy;

	logic dp_is_stall;
	logic rollback_en;
	logic [`XLEN-1:0] target_pc;

	// Outputs from IS/EX Pipeline Register
    IS_EX_PACKET [1:0] is_ex_packet;

    
    // Outputs from EX stage
	EX_CM_PACKET [1:0] ex_packet;

	// Outputs from EX/CM Pipeline Register
	EX_CM_PACKET [1:0] ex_cm_packet;

	// Outputs from CM stage
    logic [1:0] [`XLEN-1:0]  cdb_value;
	CDB_PACKET [1:0] cdb_packet;



	// // Outputs from MEM-Stage
	// logic [`XLEN-1:0] mem_result_out;
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	//logic [1:0]  proc2Dmem_command;
	MEM_SIZE proc2Dmem_size;



	// // Outputs from MEM/WB Pipeline Register
	// logic        mem_wb_halt;
	// logic        mem_wb_illegal;
	// logic  [4:0] mem_wb_dest_reg_idx;
	// logic [`XLEN-1:0] mem_wb_result;
	// logic        mem_wb_take_branch;
	
	// // Outputs from WB-Stage  (These loop back to the register file in ID)
	// logic [`XLEN-1:0] wb_reg_wr_data_out;
	// logic  [4:0] wb_reg_wr_idx_out;
	// logic        wb_reg_wr_en_out;


	//Memory Interface
	logic  [`XLEN-1:0] proc2Imem_addr;
  	BUS_COMMAND  proc2Dmem_command, proc2Imem_command;
  	logic  [3:0] Imem2proc_response, Dmem2proc_response;
	logic  [63:0] proc2Icache_addr;
	logic  [63:0] Icache_data_out;
	logic  Icache_valid_out;
	
	// assign pipeline_completed_insts = {3'b0, mem_wb_valid_inst};
	assign pipeline_error_status =  (rob_packet[1].illegal | rob_packet[0].illegal) ? ILLEGAL_INST :
	                                ( rob_packet[1].halt && head_retire_rdy) | (rob_packet[0].halt) ? HALTED_ON_WFI :
	                               //(mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
	                                NO_ERROR;
	
	// assign pipeline_commit_wr_idx = wb_reg_wr_idx_out;
	// assign pipeline_commit_wr_data = wb_reg_wr_data_out;
	// assign pipeline_commit_wr_en = wb_reg_wr_en_out;
	// assign pipeline_commit_NPC = mem_wb_NPC;
    assign pipeline_completed_insts = { {3'b0, ex_cm_valid_inst[1]},{3'b0, ex_cm_valid_inst[0]} };
    assign pipeline_commit_wr_idx   = { cdb_packet[1].cdb_tag,cdb_packet[0].cdb_tag};
    assign pipeline_commit_wr_data = {cdb_value[1],cdb_value[0]};
    assign pipeline_commit_wr_en = {cdb_packet[1].cdb_valid,cdb_packet[0].cdb_valid};
    assign pipeline_commit_NPC = {ex_cm_packet[1].NPC,ex_cm_packet[0].NPC};
	
	assign proc2Dmem_command = BUS_NONE;
	assign proc2mem_command = (proc2Dmem_command == BUS_NONE) ? proc2Imem_command : proc2Dmem_command;
	assign proc2mem_addr    = (proc2Dmem_command == BUS_NONE) ? proc2Imem_addr : proc2Dmem_addr;
	//if it's an instruction, then load a double word (64 bits)
	assign proc2mem_size    =     (proc2Dmem_command == BUS_NONE) ? DOUBLE : proc2Dmem_size;
	assign proc2mem_data    = {32'b0, proc2Dmem_data};


	assign Imem2proc_response	= (proc2Dmem_command==BUS_NONE) ? mem2proc_response : 0;
	assign Dmem2proc_response   = (proc2Dmem_command==BUS_NONE) ? 0 : mem2proc_response;

icache icache_0 (
	.clock(clock),
	.reset(reset),

	//input
	.Imem2proc_response(Imem2proc_response),
	.Imem2proc_data(mem2proc_data),
	.Imem2proc_tag(mem2proc_tag),
	.proc2Icache_addr(proc2Icache_addr),
	.branch_taken(rollback_en),
	.icache_stall(0),

	//output
	.proc2Imem_command(proc2Imem_command),
	.proc2Imem_addr(proc2Imem_addr),

	.Icache_data_out(Icache_data_out),
	.Icache_valid_out(Icache_valid_out)
);

//   logic [63:0] cachemem_data;
//   logic        cachemem_valid;
//   logic  [`ICACHE_IDX_WIDTH-1:0] Icache_rd_idx;
//   logic [`ICACHE_TAG_WIDTH-1:0] Icache_rd_tag;
//   logic  [`ICACHE_IDX_WIDTH-1:0] Icache_wr_idx;
//   logic [`ICACHE_TAG_WIDTH-1:0] Icache_wr_tag;
//   logic        Icache_wr_en;
//   cachemem128x64 cachememory (// inputs
//                               .clock(clock),
//                               .reset(reset),
//                               .wr1_en(Icache_wr_en),
//                               .wr1_idx(Icache_wr_idx),
//                               .wr1_tag(Icache_wr_tag),
//                               .wr1_data(mem2proc_data),
                              
//                               .rd1_idx(Icache_rd_idx),
//                               .rd1_tag(Icache_rd_tag),

//                               // outputs
//                               .rd1_data(cachemem_data),
//                               .rd1_valid(cachemem_valid)
//                              );

// 	 icache_ctrl icache_0(// inputs 
//                   .clock(clock),
//                   .reset(reset),

//                   .Imem2proc_response(Imem2proc_response),
//                   .Imem2proc_data(mem2proc_data),
//                   .Imem2proc_tag(mem2proc_tag),

//                   .proc2Icache_addr(proc2Icache_addr),
//                   .cachemem_data(cachemem_data),
//                   .cachemem_valid(cachemem_valid),

//                 //   .stall_icache(proc2Dmem_command != BUS_NONE),
// 				  .stall_icache(1'b0),
//                    // outputs
//                   .proc2Imem_command(proc2Imem_command),
//                   .proc2Imem_addr(proc2Imem_addr),

//                   .Icache_data_out(Icache_data_out),
//                   .Icache_valid_out(Icache_valid_out),
//                   .current_index(Icache_rd_idx),
//                   .current_tag(Icache_rd_tag),
//                   .last_index(Icache_wr_idx),
//                   .last_tag(Icache_wr_tag),
//                   .data_write_enable(Icache_wr_en)
//                  );



//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

	//these are debug signals that are now included in the packet,
	//breaking them out to support the legacy debug modes
	assign if_NPC_out        = {if_packet[1].NPC,if_packet[0].NPC};
	assign if_IR_out         = {if_packet[1].inst,if_packet[0].inst};
	assign if_valid_inst_out = {if_packet[1].valid,if_packet[0].valid};

	if_stage if_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
	//  .mem_wb_valid_inst(mem_wb_valid_inst),
	//	.ex_mem_take_branch(ex_mem_packet.take_branch),
		.ex_cm_take_branch(rollback_en),
		.ex_cm_target_pc(target_pc),
		.Icache_valid(Icache_valid_out),
		.hazard_stall(dp_is_stall),

	//	.ex_mem_target_pc(ex_mem_packet.alu_result),
		.Imem2proc_data(Icache_data_out),
		
		// Outputs
		.proc2Imem_addr(proc2Icache_addr),
		.if_packet_out(if_packet)
	);

//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign if_id_NPC        = {if_id_packet[1].NPC,if_id_packet[0].NPC};
	assign if_id_IR         = {if_id_packet[1].inst,if_id_packet[0].inst};
	assign if_id_valid_inst = {if_id_packet[1].valid,if_id_packet[0].valid};
	assign if_id_enable = !dp_is_stall; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin 
			if_id_packet[0].inst  <= `SD `NOP;
			if_id_packet[0].valid <= `SD `FALSE;
            if_id_packet[0].NPC   <= `SD 0;
            if_id_packet[0].PC    <= `SD 0;

			if_id_packet[1].inst  <= `SD `NOP;
			if_id_packet[1].valid <= `SD `FALSE;
            if_id_packet[1].NPC   <= `SD 0;
            if_id_packet[1].PC    <= `SD 0;
		end else begin// if (reset)
			if (if_id_enable) begin
				if_id_packet <= `SD if_packet; 
			end // if (if_id_enable)	
		end
	end // always

//////////////////////////////////////////////////
//                                              //
//                  ID-Stage                    //
//                                              //
//////////////////////////////////////////////////
	
	id_stage id_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),
		.if_id_packet_in(if_id_packet),

		// Outputs
		.id_packet_out(id_packet)
	);

//////////////////////////////////////////////////
//                                              //
//            ID/RN Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign id_rn_NPC        = {id_rn_packet[1].NPC,id_rn_packet[0].NPC};
	assign id_rn_IR         = {id_rn_packet[1].inst,id_rn_packet[0].inst};
	assign id_rn_valid_inst = {id_rn_packet[1].valid,id_rn_packet[0].inst};

	assign id_rn_enable = !dp_is_stall; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			id_rn_packet[0] <= `SD '{{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				`ZERO_REG, 
				`ZERO_REG, 
				`ZERO_REG, 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0 //valid
			}; 

			id_rn_packet[1] <= `SD '{{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				`ZERO_REG, 
				`ZERO_REG, 
				`ZERO_REG, 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0 //valid
			}; 
		end else begin // if (reset)
			if (id_rn_enable) begin
				id_rn_packet <= `SD id_packet;
			end // if
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                  RN-Stage                    //
//                                              //
//////////////////////////////////////////////////
RRAT_WRITE_INPACKET [1:0] rrat_write_packet_in;
assign rrat_write_packet_in[0] = {head_retire_rdy && rob_packet[0].T_new!=`ZERO_PREG,
								rob_packet[0].inst.r.rd,
								rob_packet[0].T_new};
assign rrat_write_packet_in[1] = {head_p1_retire_rdy && rob_packet[0].T_new!=`ZERO_PREG,
								rob_packet[1].inst.r.rd,
								rob_packet[1].T_new}; 
	rn_stage rn_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset),

		.rn_stall(dp_is_stall),
		.rollback_en(rollback_en),

		.rrat_write_packet_in(rrat_write_packet_in),
		.rob_retire_in(rob_packet),
		.retire1(head_retire_rdy),
		.retire2(head_p1_retire_rdy),

		.cdb_packet_in(cdb_packet),
		.id_rn_packet_in(id_rn_packet),
		// Outputs
		//.rn_packet_out(rn_packet)
		.rn_packet_out(rn_dp_packet)
	);

//////////////////////////////////////////////////
//                                              //
//            RN/DP Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	 assign rn_dp_NPC        = {rn_dp_packet[1].NPC,rn_dp_packet[0].NPC};
	 assign rn_dp_IR         = {rn_dp_packet[1].inst,rn_dp_packet[0].inst};
	 assign rn_dp_valid_inst = {rn_dp_packet[1].valid,rn_dp_packet[0].inst};

	// assign rn_dp_enable = 1'b1; // always enabled
	// // synopsys sync_set_reset "reset"
	// always_ff @(posedge clock) begin
	// 	if (reset) begin
	// 		rn_dp_packet[0] <= `SD '{{`XLEN{1'b0}},
	// 			{`XLEN{1'b0}},
	// 			`ZERO_PREG, 
	// 			`ZERO_PREG, 
	// 			`ZERO_PREG, 
	// 			`ZERO_PREG, 
	// 			1'b0, //prega_ready
	// 			1'b0, //pregb_ready
	// 			OPA_IS_RS1, 
	// 			OPB_IS_RS2, 
	// 			`NOP,
	// 			ALU_ADD, 
	// 			1'b0, //rd_mem
	// 			1'b0, //wr_mem
	// 			1'b0, //cond
	// 			1'b0, //uncond
	// 			1'b0, //halt
	// 			1'b0, //illegal
	// 			1'b0, //csr_op
	// 			1'b0 //valid
	// 		}; 

 	// 		rn_dp_packet[1] <= `SD '{{`XLEN{1'b0}},
	// 			{`XLEN{1'b0}},
	// 			`ZERO_PREG,  //prega_idx
	// 			`ZERO_PREG,  //pregb_idx
	// 			`ZERO_PREG,  //pdest_new
	// 			`ZERO_PREG,  //pdest_old
	// 			1'b0, //prega_ready
	// 			1'b0, //pregb_ready
	// 			OPA_IS_RS1, 
	// 			OPB_IS_RS2, 
	// 			`NOP,
	// 			ALU_ADD, 
	// 			1'b0, //rd_mem
	// 			1'b0, //wr_mem
	// 			1'b0, //cond
	// 			1'b0, //uncond
	// 			1'b0, //halt
	// 			1'b0, //illegal
	// 			1'b0, //csr_op
	// 			1'b0 //valid
	// 		}; 

	// 	end else begin // if (reset)
	// 		if (rn_dp_enable) begin
	// 			rn_dp_packet <= `SD rn_packet;
	// 		end // if
	// 	end // else: !if(reset)
	// end // always

//////////////////////////////////////////////////
//                                              //
//                  DP_IS-Stage                 //
//                                              //
//////////////////////////////////////////////////
	assign dp_is_stall = rs_full[0] | rs_full[1] | rob_full | rob_almost_full; 

	dp_is_stage dp_is_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset | rollback_en),

		.dp_stall(dp_is_stall),
		.rn_dp_packet_in(rn_dp_packet),
		.cdb_packet_in(cdb_packet),

		// Outputs
		.is_packet_out(is_packet),

		.rs_full(rs_full),
		.rob_packet_out(rob_packet),
		.rob_full(rob_full),
		.rob_almost_full(rob_almost_full),
		.head_retire_rdy(head_retire_rdy),
		.head_p1_retire_rdy(head_p1_retire_rdy)
	);

	branch branch_0(
		.clock(clock),
		.reset(reset),

		.rob_packet_in(rob_packet),
		.head_retire_rdy(head_retire_rdy),
		.head_p1_retire_rdy(head_p1_retire_rdy),
		.ex_packet_in(ex_packet),
		.take_branch_out(rollback_en),
		.target_pc_out(target_pc)
	);

//////////////////////////////////////////////////
//                                              //
//            IS/EX Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign is_ex_NPC        = {is_ex_packet[1].NPC,is_ex_packet[0].NPC};
	assign is_ex_IR         = {is_ex_packet[1].inst,is_ex_packet[0].inst};
	assign is_ex_valid_inst = {is_ex_packet[1].valid,is_ex_packet[0].inst};

	assign is_ex_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_packet[0] <= `SD '{{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				`ZERO_PREG,  //prega_idx
				`ZERO_PREG,  //pregb_idx
				`ZERO_PREG,  //pdest_idx
				1'b0, //ALU_ready
				1'b0, //LSQ_ready
				1'b0, //MULT_ready
				1'b0, //BR_ready
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0  //valid
			}; 

			is_ex_packet[1] <= `SD '{{`XLEN{1'b0}},
				{`XLEN{1'b0}},
				`ZERO_PREG,  //prega_idx
				`ZERO_PREG,  //pregb_idx
				`ZERO_PREG,  //pdest_idx
				1'b0, //ALU_ready
				1'b0, //LSQ_ready
				1'b0, //MULT_ready
				1'b0, //BR_ready
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0  //valid
			};  

		end else begin // if (reset)
			if (is_ex_enable) begin
				is_ex_packet <= `SD is_packet;
			end // if
		end // else: !if(reset)
	end // always



//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////

    ex_stage ex_stage_0 (
        .clock(clock),
        .reset(reset),


        .wb_idx({cdb_packet[1].cdb_tag,cdb_packet[0].cdb_tag}),
		.wb_en({cdb_packet[1].cdb_valid,cdb_packet[0].cdb_valid}),
		.wb_data(cdb_value),
        .is_ex_packet_in(is_ex_packet),
        .ex_packet_out(ex_packet)
    );


//////////////////////////////////////////////////
//                                              //
//            EX/CM Pipeline Register           //
//                                              //
//////////////////////////////////////////////////
assign ex_cm_NPC        = {ex_cm_packet[1].NPC,ex_cm_packet[0].NPC};
assign ex_cm_IR         = {ex_cm_packet[1].inst,ex_cm_packet[0].inst};
assign ex_cm_valid_inst = {ex_cm_packet[1].valid,ex_cm_packet[0].valid};

	assign ex_cm_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			ex_cm_packet[0] <= `SD '{{`XLEN{1'b0}},
				`NOP,
				`ZERO_PREG,  //pdest_idx
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
				1'b0,//take_branch
				{`XLEN{1'b0}}, //regb_value
				1'b0, //rd_mem
				1'b0, //wr_mem
				{`XLEN{1'b0}},//result
				3'b0, //mem_size
				1'b0, //mult_done
				1'b0, //alu_done
				1'b0  //branch_done
			}; 

			ex_cm_packet[1] <= `SD '{{`XLEN{1'b0}},
				`NOP,
				`ZERO_PREG,  //pdest_idx
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
				1'b0,//take_branch
				{`XLEN{1'b0}}, //regb_value
				1'b0, //rd_mem
				1'b0, //wr_mem
				{`XLEN{1'b0}},//result
				3'b0, //mem_size
				1'b0,  // mult_done
				1'b0, // alu_done
				1'b0  // branch_done
			};

		end else begin // if (reset)
			if (ex_cm_enable) begin
				ex_cm_packet <= `SD ex_packet;
			end // if
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                  CM-Stage                    //
//                                              //
//////////////////////////////////////////////////

	cm_stage cm_stage_0 (
        .clock(clock),
        .reset(reset),
		//.rollback_en(rollback_en),
		.ex_cm_packet_in(ex_cm_packet),
		
		.cdb_packet_out(cdb_packet),
		.cdb_value(cdb_value)
	);

//////////////////////////////////////////////////

//////////////////////////////////////////////////
//                                              //
//            CM/RT Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

//////////////////////////////////////////////////
//                                              //
//                  RT-Stage                    //
//                                              //
//////////////////////////////////////////////////

endmodule
`endif // __PIPELINE_V__