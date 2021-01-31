`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

module pipeline (

	input         clock,                    // System clock
	input         reset,                    // System reset
	input [3:0]   mem2proc_response,        // Tag from memory about current request
	input [63:0]  mem2proc_data,            // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output BUS_COMMAND  proc2mem_command,    // command sent to memory
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


	output IS_EX_PACKET [1:0] is_packet,
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
	logic   [1:0] if_id_enable, id_rn_enable, rn_dp_enable, is_ex_enable, ex_cm_enable;
	
	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	IF_ID_PACKET [1:0] if_packet;

	logic [1:0] predict_take_branch;
	logic [1:0][`XLEN-1:0] predict_target_pc;
	logic ras_full;

	IF_ID_PACKET [1:0] if_bp_packet; // if stage branch predict packet out 

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

	logic dp_stall;
	logic mispredict;
	logic [`XLEN-1:0] mispredict_target_pc;

	// Outputs from IS/EX Pipeline Register
    IS_EX_PACKET [1:0] is_ex_packet;

    // Outputs from EX stage
	FU_SQ_PACKET [1:0] fu_sq_packet;
	FU_LQ_PACKET [1:0] fu_lq_packet;
	
	EX_CM_PACKET [1:0] ex_packet;
	logic [1:0] ex_stall;

	logic rd_ld_buffer_stall; // ex stage stall related

	// Outputs from EX/CM Pipeline Register
	EX_CM_PACKET [1:0] ex_cm_packet;

	// Outputs from CM stage
	CDB_PACKET [1:0] cdb_packet;
	logic [1:0] wb_en;


	//--------------Memory Interface-------------//
	//logic  [`XLEN-1:0] proc2Imem_addr;
  	BUS_COMMAND  proc2Dmem_command, proc2Imem_command;
  	logic  [3:0] Imem2proc_response, Dmem2proc_response;
	logic  [31:0] proc2Icache_addr;
	logic  [63:0] Icache_data_out;
	logic  Icache_valid_out;
	
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [2*`XLEN-1:0] proc2Dmem_data;
	MEM_SIZE proc2Dmem_size;


	//---------------- LSQ signals-----------------//
	// input of LSQ
	FU_SQ_PACKET    [1:0]   FU_SQ_out; // address & data &done signal from FU 
    FU_LQ_PACKET    [1:0]   FU_LQ_out;

    logic           [1:0]   dispatch_SQ_wr_mem;   // dispatch stage, indicate if it is a wr_mem (Store) instruction. 
    logic           [1:0]   dispatch_LQ_rd_mem;   // dispatch stage, indicate if it is a rd_mem (Load) instruction
	logic			[1:0]	dispatch_en;

    logic           [1:0]   ROB_SQ_wr_mem;       // retire stage. 
    logic           [1:0]   ROB_SQ_retire_rdy;   
    logic           [1:0]   ROB_LQ_retire_rdy;
	logic           [1:0]   ROB_LQ_rd_mem;  

	logic  [1:0][`ROB_IDX_WIDTH-1:0]    rob_idx;
	logic                               D_cache_SQ_out_valid;    // is D_cache ready for the Store instruction?
    logic                               D_cache_LQ_out_valid;  // hit in cache, data valid
    logic  [`XLEN-1:0]                  D_cache_LQ_out_value;    // value in cache when hit
	
	// output from LSQ
    logic                               LSQ_dispatch_valid;       //dispatch_valid
    SQ_D_CACHE_PACKET                   SQ_D_cache_out;
    LQ_D_CACHE_PACKET                   LQ_D_cache_out;
	SQ_FU_PACKET    [1:0]   SQ_FU_out;
    LQ_FU_PACKET    [1:0]   LQ_FU_out;
	logic [`XLEN-1:0] ld_rollback_pc;
	logic ld_rollback; // load violation rollback at retire stage
	logic system_halt;
	logic retire_buf_empty;
    logic load_buf_full;

	//------------------------------------------//

	
	// inst count variable//
	logic [1:0] inst_cnt;
	assign inst_cnt[0] = rob_packet[0].valid & head_retire_rdy & !rob_packet[0].rd_mem_violation;
	assign inst_cnt[1] = rob_packet[1].valid & head_p1_retire_rdy & !rob_packet[1].rd_mem_violation
						 && (rob_packet[0].ex_take_branch == rob_packet[0].predict_take_branch) && !(rob_packet[0].halt & head_retire_rdy);

	//-------------------//
	assign pipeline_error_status =  (ex_cm_packet[1].illegal | ex_cm_packet[0].illegal) ? ILLEGAL_INST :
	                                system_halt && retire_buf_empty? HALTED_ON_WFI :
	                                //(mem2proc_response==4'h0)  ? LOAD_ACCESS_FAULT :
	                                NO_ERROR;
									
	// assign pipeline_completed_insts = {3'b0, mem_wb_valid_inst};
	// assign pipeline_commit_wr_idx = wb_reg_wr_idx_out;
	// assign pipeline_commit_wr_data = wb_reg_wr_data_out;
	// assign pipeline_commit_wr_en = wb_reg_wr_en_out;
	// assign pipeline_commit_NPC = mem_wb_NPC;

//    assign pipeline_completed_insts = { {3'b0, ex_cm_valid_inst[1]},{3'b0, ex_cm_valid_inst[0]} };
	assign pipeline_completed_insts = { {3'b0, cdb_packet[1].cdb_valid /*!ld_rollback*/},{3'b0, cdb_packet[0].cdb_valid} };
    assign pipeline_commit_wr_idx   = { cdb_packet[1].cdb_tag,cdb_packet[0].cdb_tag};
    assign pipeline_commit_wr_data = {cdb_packet[1].cdb_value,cdb_packet[0].cdb_value};
    assign pipeline_commit_wr_en = wb_en;
    assign pipeline_commit_NPC = {ex_cm_packet[1].NPC,ex_cm_packet[0].NPC};
	
	// assign proc2mem_command = (proc2Dmem_command == BUS_NONE) ? proc2Imem_command : proc2Dmem_command;
	// assign proc2mem_addr    = (proc2Dmem_command == BUS_NONE) ? proc2Imem_addr : proc2Dmem_addr;
	// //if it's an instruction, then load a double word (64 bits)
	// // assign proc2mem_size    = (proc2Dmem_command == BUS_NONE) ? DOUBLE : proc2Dmem_size;
	// assign proc2mem_size    = DOUBLE;
	// assign proc2mem_data    = proc2Dmem_data;

	// assign Imem2proc_response	= (proc2Dmem_command==BUS_NONE) ? mem2proc_response : 0;
	// assign Dmem2proc_response   = (proc2Dmem_command==BUS_NONE) ? 0 : mem2proc_response;

    assign proc2mem_command =
	     (proc2Dmem_command == BUS_NONE) ? BUS_LOAD : proc2Dmem_command;
	assign proc2mem_addr =
	     (proc2Dmem_command == BUS_NONE) ? proc2Imem_addr : proc2Dmem_addr;
	//if it's an instruction, then load a double word (64 bits)
	assign proc2mem_size =
	     (proc2Dmem_command == BUS_NONE) ? DOUBLE : proc2Dmem_size;
	assign proc2mem_data = {32'b0, proc2Dmem_data};

	always @(posedge clock) begin
		if(reset) begin
			system_halt <= 1'b0;
		end else begin
			if( (rob_packet[1].halt && head_p1_retire_rdy && !mispredict && !ld_rollback) | (rob_packet[0].halt && head_retire_rdy) ) begin
				system_halt <= 1'b1;
			end else begin
				system_halt <= system_halt;
			end
		end
	end

	// icache icache_0 (
	// .clock(clock),
	// .reset(reset),

	// //input
	// .Imem2proc_response(Imem2proc_response),
	// .Imem2proc_data(mem2proc_data),
	// .Imem2proc_tag(mem2proc_tag),
	// .proc2Icache_addr(proc2Icache_addr),
	// // .branch_taken( mispredict | ld_rollback),
	// // .icache_stall(proc2Dmem_command != BUS_NONE),s

	// //output
	// .proc2Imem_command(proc2Imem_command),
	// .proc2Imem_addr(proc2Imem_addr),

	// .Icache_data_out(Icache_data_out),
	// .Icache_valid_out(Icache_valid_out)
	// );


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
		.predict_take_branch(predict_take_branch),
		.predict_target_pc(predict_target_pc),

		.mispredict(mispredict),
		.mispredict_target_pc(mispredict_target_pc),

		.ld_rollback(ld_rollback),
		.ld_rollback_pc(ld_rollback_pc),

		.Icache_valid(proc2Dmem_command == BUS_NONE),
		.hazard_stall(dp_stall),
		.Imem2proc_data(mem2proc_data),
		
		// Outputs
		.proc2Imem_addr(proc2Imem_addr),
		.if_packet_out(if_packet)
	);


	branch_predictor bp_0(
		.clock(clock),
		.reset(reset),

		.if_packet(if_packet),
		.rob_packet(rob_packet),
		.head_retire_rdy(head_retire_rdy),
		.head_p1_retire_rdy(head_p1_retire_rdy),

		.predict_take_branch(predict_take_branch),
		.predict_target_pc(predict_target_pc),
		.ras_full(ras_full)
	);

	assign if_bp_packet[0] = {
		if_packet[0].valid,
		if_packet[0].inst,
		if_packet[0].NPC,
		if_packet[0].PC,
		predict_take_branch[0],
		predict_target_pc[0]
	};

	assign if_bp_packet[1] = {
		if_packet[1].valid,
		if_packet[1].inst,
		if_packet[1].NPC,
		if_packet[1].PC,
		predict_take_branch[1],
		predict_target_pc[1]
	};

//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign if_id_NPC        = {if_id_packet[1].NPC,if_id_packet[0].NPC};
	assign if_id_IR         = {if_id_packet[1].inst,if_id_packet[0].inst};
	assign if_id_valid_inst = {if_id_packet[1].valid,if_id_packet[0].valid};

	assign if_id_enable[0] = !dp_stall; 
	assign if_id_enable[1] = !dp_stall; 
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | mispredict | ld_rollback) begin 
			if_id_packet[0].inst  <= `SD `NOP;
			if_id_packet[0].valid <= `SD `FALSE;
            if_id_packet[0].NPC   <= `SD 0;
            if_id_packet[0].PC    <= `SD 0;

			if_id_packet[0].predict_take_branch <= `SD `FALSE;
			if_id_packet[0].predict_target_pc   <= `SD {`XLEN{1'b0}};

			if_id_packet[1].inst  <= `SD `NOP;
			if_id_packet[1].valid <= `SD `FALSE;
            if_id_packet[1].NPC   <= `SD 0;
            if_id_packet[1].PC    <= `SD 0;

			if_id_packet[1].predict_take_branch <= `SD `FALSE;
			if_id_packet[1].predict_target_pc   <= `SD {`XLEN{1'b0}};

		end else begin// if (reset)
			if (if_id_enable[0]) begin
				if_id_packet[0] <= `SD if_bp_packet[0]; 
			end // if (if_id_enable)

			if (if_id_enable[1]) begin
				if_id_packet[1] <= `SD if_bp_packet[1]; 
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

	assign id_rn_enable[0] = !dp_stall; // always enabled
	assign id_rn_enable[1] = !dp_stall; // always enabled
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | mispredict  | ld_rollback) begin
			id_rn_packet[0] <= `SD '{{`XLEN{1'b0}}, //NPC
				{`XLEN{1'b0}},  //PC
				1'b0,           //predict_take_branch
				{`XLEN{1'b0}},	//predict_target_pc
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

			id_rn_packet[1] <= `SD '{{`XLEN{1'b0}}, //NPC
				{`XLEN{1'b0}},	//PC
				1'b0,           //predict_take_branch
				{`XLEN{1'b0}},	//predict_target_pc
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
			if (id_rn_enable[0]) begin
				id_rn_packet[0] <= `SD id_packet[0];
			end // if

			if (id_rn_enable[1]) begin
				id_rn_packet[1] <= `SD id_packet[1];
			end // if
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                  RN-Stage                    //
//                                              //
//////////////////////////////////////////////////
RRAT_WRITE_INPACKET [1:0] rrat_write_packet_in;
assign rrat_write_packet_in[0] = {head_retire_rdy && rob_packet[0].T_new!=`ZERO_PREG && !rob_packet[0].rd_mem_violation,
								rob_packet[0].inst.r.rd,
								rob_packet[0].T_new};
assign rrat_write_packet_in[1] = {head_p1_retire_rdy && rob_packet[1].T_new!=`ZERO_PREG && !rob_packet[1].rd_mem_violation && !rob_packet[0].rd_mem_violation && !(mispredict && !rob_packet[1].is_branch),
								rob_packet[1].inst.r.rd,
								rob_packet[1].T_new};
	rn_stage rn_stage_0(
		// Inputs
		.clock(clock),
		.reset(reset),

		.rn_stall(dp_stall),
		.rollback_en(mispredict | ld_rollback),
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
	assign dp_stall = rs_full[0] | rs_full[1] | rob_full | rob_almost_full; 
	logic h1_retire_rdy ; 
	logic h1_p1_retire_rdy ; 


    logic            [1:0][`LSQ_IDX_WIDTH-1:0]            dp_sq_idx;     
    logic            [1:0][`LSQ_IDX_WIDTH-1:0]            dp_lq_idx;  
	logic            [1:0][`ROB_IDX_WIDTH-1:0]            dp_rob_idx;
	assign head_retire_rdy = h1_retire_rdy;
	assign head_p1_retire_rdy = h1_p1_retire_rdy && rob_packet[0].ex_take_branch == rob_packet[0].predict_take_branch;

	assign ld_rollback = ( (rob_packet[0].rd_mem && head_retire_rdy && rob_packet[0].rd_mem_violation) | 
						 ( head_retire_rdy && head_p1_retire_rdy && rob_packet[1].rd_mem && rob_packet[1].rd_mem_violation) ); //FIXME

	always_comb begin
		ld_rollback_pc = {`XLEN{1'b0}};
		if(ld_rollback) begin
			if(rob_packet[0].rd_mem_violation && head_retire_rdy) begin
			 	ld_rollback_pc = rob_packet[0].PC;
			end else if(rob_packet[1].rd_mem_violation && head_p1_retire_rdy)begin
				ld_rollback_pc = rob_packet[1].PC;
			end
		end
	end

	dp_is_stage dp_is_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset | mispredict | ld_rollback ),

		.dp_stall(dp_stall),
		.is_stall(ex_stall | {load_buf_full,load_buf_full}),

		.rn_dp_packet_in(rn_dp_packet),
		.cdb_packet_in(cdb_packet),

		.ex_packet_in(ex_packet),

		.sq_idx(dp_sq_idx),
		.lq_idx(dp_lq_idx),

		.sq_fu_packet_in(SQ_FU_out), //FIXME

		// Outputs
		.is_packet_out(is_packet),

		.rs_full(rs_full),

		.rob_idx(dp_rob_idx),

		.rob_packet_out(rob_packet),
		.rob_full(rob_full),
		.rob_almost_full(rob_almost_full),
		.head_retire_rdy(h1_retire_rdy),
		.head_p1_retire_rdy(h1_p1_retire_rdy)
	);

	branch branch_0(
		.clock(clock),
		.reset(reset),

		.rob_packet_in(rob_packet),
		.head_retire_rdy(head_retire_rdy),
		.head_p1_retire_rdy(head_p1_retire_rdy),
		.mispredict(mispredict),
		.mispredict_target_pc(mispredict_target_pc)
	);

	// 	branch branch_0(
	// 	.clock(clock),
	// 	.reset(reset | mispredict),

	// 	.rob_packet_in(rob_packet),
	// 	.head_retire_rdy(head_retire_rdy),
	// 	.head_p1_retire_rdy(head_p1_retire_rdy),
	// 	.ex_packet_in(ex_packet),
	// 	.take_branch_out(mispredict),
	// 	.target_pc_out(mispredict_target_pc)
	// );

//////////////////////////////////////////////////
//                                              //
//            IS/EX Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign is_ex_NPC        = {is_ex_packet[1].NPC,is_ex_packet[0].NPC};
	assign is_ex_IR         = {is_ex_packet[1].inst,is_ex_packet[0].inst};
	assign is_ex_valid_inst = {is_ex_packet[1].valid,is_ex_packet[0].inst};

	assign is_ex_enable[0] = !( ex_stall[0] | load_buf_full ); // always enabled
	assign is_ex_enable[1] = !(ex_stall[1] | load_buf_full); // always enabled

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | mispredict | ld_rollback) begin
			is_ex_packet[0] <= `SD '{{`XLEN{1'b0}}, //NPC
				{`XLEN{1'b0}},                      //PC
				{`ROB_IDX_WIDTH{1'b0}},             //rob_idx

				{`LSQ_IDX_WIDTH{1'b0}},        //sq_idx
				{`LSQ_IDX_WIDTH{1'b0}},        //lq_idx

				`ZERO_PREG,  //prega_idx
				`ZERO_PREG,  //pregb_idx
				`ZERO_PREG,  //pdest_idx
				1'b0, //ALU_ready
				1'b0, //STORE_ready
				1'b0, //LOAD_ready
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
				{`ROB_IDX_WIDTH{1'b0}},             //rob_idx

				{`LSQ_IDX_WIDTH{1'b0}},        //sq_idx
				{`LSQ_IDX_WIDTH{1'b0}},        //lq_idx

				`ZERO_PREG,  //prega_idx
				`ZERO_PREG,  //pregb_idx
				`ZERO_PREG,  //pdest_idx
				1'b0, //ALU_ready
				1'b0, //STORE_ready
				1'b0, //LOAD_ready
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
			if (is_ex_enable[0]) begin
				is_ex_packet[0] <= `SD is_packet[0];
			end // if

			if (is_ex_enable[1]) begin
				is_ex_packet[1] <= `SD is_packet[1];
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
        .reset(reset | mispredict |ld_rollback),

        .wb_idx({cdb_packet[1].cdb_tag,cdb_packet[0].cdb_tag}),
		.wb_en(wb_en),
		.wb_data({cdb_packet[1].cdb_value,cdb_packet[0].cdb_value}),
        .is_ex_packet_in(is_ex_packet),

		.sq_fu_packet_in(SQ_FU_out),//FIXME
		.lq_fu_packet_in(LQ_FU_out),//FIXME

		.fu_sq_packet_out(fu_sq_packet),
		.fu_lq_packet_out(fu_lq_packet),

        .ex_packet_out(ex_packet),
		.ex_stall(ex_stall),

		.rd_ld_buffer_stall(rd_ld_buffer_stall)
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
		if (reset | mispredict) begin
			ex_cm_packet[0] <= `SD '{{`XLEN{1'b0}},
				`NOP,
				{`ROB_IDX_WIDTH{1'b0}},             //rob_idx
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
				1'b0, //branch_done
				1'b0,  // store_done
				1'b0  // load_done
			}; 

			ex_cm_packet[1] <= `SD '{{`XLEN{1'b0}},
				`NOP,
				{`ROB_IDX_WIDTH{1'b0}},             //rob_idx
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
				1'b0, // mult_done
				1'b0, // alu_done
				1'b0, // branch_done
				1'b0,  //store_done
				1'b0  //load_done
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

	assign wb_en[0] = cdb_packet[0].cdb_valid & cdb_packet[0].cdb_tag != `ZERO_PREG;
	assign wb_en[1] = cdb_packet[1].cdb_valid & cdb_packet[1].cdb_tag != `ZERO_PREG;
	cm_stage cm_stage_0 (
        .clock(clock),
        .reset(reset | mispredict | ld_rollback),
		.ex_cm_packet_in(ex_cm_packet),
		
		.cdb_packet_out(cdb_packet)
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


//////////////////////////////////////////////////
//                                              //
//                 LSQ	 Dcache                 //
//                                              //
//////////////////////////////////////////////////

	assign dispatch_SQ_wr_mem = {rn_dp_packet[1].wr_mem,rn_dp_packet[0].wr_mem};
	assign dispatch_LQ_rd_mem = {rn_dp_packet[1].rd_mem,rn_dp_packet[0].rd_mem};

	assign dispatch_en[0] = !dp_stall &&  rn_dp_packet[0].valid;	
	assign dispatch_en[1] = !dp_stall &&  rn_dp_packet[1].valid;
    
	assign FU_SQ_out[1] = {
		fu_sq_packet[1].done,
		fu_sq_packet[1].result,
		fu_sq_packet[1].pdest_idx,
		fu_sq_packet[1].rob_idx,
		fu_sq_packet[1].SQ_idx,	
		fu_sq_packet[1].LQ_idx,	
		fu_sq_packet[1].regb_value,
		fu_sq_packet[1].mem_size
	};

	assign FU_SQ_out[0] ={
		fu_sq_packet[0].done,
		fu_sq_packet[0].result,
		fu_sq_packet[0].pdest_idx,
		fu_sq_packet[0].rob_idx,
		fu_sq_packet[0].SQ_idx,	
		fu_sq_packet[0].LQ_idx,	
		fu_sq_packet[0].regb_value,
		fu_sq_packet[0].mem_size
	};

	assign FU_LQ_out[1] = {
		fu_lq_packet[1].done,
		fu_lq_packet[1].inst,
		fu_lq_packet[1].result,
		fu_lq_packet[1].pdest_idx,
		fu_lq_packet[1].rob_idx,
		fu_lq_packet[1].SQ_idx,	
		fu_lq_packet[1].LQ_idx,	
		fu_lq_packet[1].mem_size
	};

	assign FU_LQ_out[0] = {
		fu_lq_packet[0].done,
		fu_lq_packet[0].inst,
		fu_lq_packet[0].result,
		fu_lq_packet[0].pdest_idx,
		fu_lq_packet[0].rob_idx,
		fu_lq_packet[0].SQ_idx,	
		fu_lq_packet[0].LQ_idx,	
		fu_lq_packet[0].mem_size
	};

	assign ROB_SQ_wr_mem = {rob_packet[1].wr_mem, rob_packet[0].wr_mem};	
	assign ROB_SQ_retire_rdy = {head_p1_retire_rdy, head_retire_rdy};	
	assign ROB_LQ_retire_rdy = {head_p1_retire_rdy, head_retire_rdy};	
	assign ROB_LQ_rd_mem = {rob_packet[1].rd_mem,rob_packet[0].rd_mem};	
	
	assign rob_idx = {dp_rob_idx[1], dp_rob_idx[0]};

	LSQ LSQ_0(
		// input
		.clock(clock),
		.reset(reset),
	
		.rollback(mispredict | ld_rollback),

		.dispatch_en(dispatch_en), 

		.rd_ld_buffer_stall(rd_ld_buffer_stall),

		.rob_idx(rob_idx),	// tail of rob

		.dispatch_SQ_wr_mem(dispatch_SQ_wr_mem),
		.dispatch_LQ_rd_mem(dispatch_LQ_rd_mem),

		.D_cache_SQ_out_valid(D_cache_SQ_out_valid),
		.D_cache_LQ_out_valid(D_cache_LQ_out_valid),
		.D_cache_LQ_out_value(D_cache_LQ_out_value),

		.FU_SQ_out(FU_SQ_out),
		.FU_LQ_out(FU_LQ_out),

		.ROB_SQ_wr_mem(ROB_SQ_wr_mem), // retire
		.ROB_SQ_retire_rdy(ROB_SQ_retire_rdy),
		.ROB_LQ_retire_rdy(ROB_LQ_retire_rdy),
		.ROB_LQ_rd_mem(ROB_LQ_rd_mem),

		// output

        .load_buf_full(load_buf_full),

		.LSQ_dispatch_valid(LSQ_dispatch_valid),      

		.retire_buf_empty(retire_buf_empty),
		
		.SQ_idx(dp_sq_idx),     // rs input
		.LQ_idx(dp_lq_idx),     
		
		.SQ_FU_out(SQ_FU_out),
		.LQ_FU_out(LQ_FU_out),
        
		.SQ_D_cache_out(SQ_D_cache_out),
		.LQ_D_cache_out(LQ_D_cache_out)
	);

	logic [`XLEN-1:0] dcache_addr;
	logic [`XLEN-1:0] dcache_data;
	logic [2:0]       dcache_memsize;

	assign dcache_addr = SQ_D_cache_out.wr_en ? SQ_D_cache_out.addr :
						 LQ_D_cache_out.rd_en ? LQ_D_cache_out.addr :
						 0;

	assign dcache_memsize = SQ_D_cache_out.wr_en ? SQ_D_cache_out.mem_size :
						    LQ_D_cache_out.rd_en ? LQ_D_cache_out.mem_size :
						    0;

	// dcache_top dcache_0(
	// 	.clock(clock),
	// 	.reset(reset),
	// 	.mem2proc_response(Dmem2proc_response),
	// 	.mem2proc_data(mem2proc_data),
	// 	.mem2proc_tag(mem2proc_tag),

	// 	.proc2Dcache_addr(dcache_addr),
	// 	.proc2Dcache_data(SQ_D_cache_out.value),
	// 	.rd_mem(LQ_D_cache_out.rd_en),
	// 	.wr_mem(SQ_D_cache_out.wr_en),
	// 	.proc2Dmem_size(dcache_memsize),
	// 	.rollback(ld_rollback),
		
	// 	.proc2mem_command(proc2Dmem_command),
	// 	.proc2mem_addr(proc2Dmem_addr),
	// 	.proc2mem_data(proc2Dmem_data),
		
	// 	.data2lsq(D_cache_LQ_out_value),
	// 	.wr_valid_o(D_cache_SQ_out_valid),
	// 	.rd_valid_o(D_cache_LQ_out_valid)
	// );

    assign D_cache_LQ_out_valid = (proc2Dmem_command == BUS_LOAD);
    assign D_cache_SQ_out_valid = (proc2Dmem_command == BUS_STORE);
    mem_stage mem_intf(
        .clock (clock),
        .reset(reset),
        .wr_mem(SQ_D_cache_out.wr_en),
        .rd_mem(LQ_D_cache_out.rd_en && !SQ_D_cache_out.wr_en),
        .data_in(SQ_D_cache_out.value),
        .addr_in(dcache_addr),
        .mem_size(dcache_memsize),
        .Dmem2proc_data(mem2proc_data),
        .mem_result_out(D_cache_LQ_out_value),
        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_size(proc2Dmem_size),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data)
    );

endmodule
`endif // __PIPELINE_V__