/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module if_stage(
	input         clock,                  // system clock
	input         reset,                  // system reset

	input         Icache_valid,
	input         hazard_stall,

	input  [1:0]       predict_take_branch,
	input  [1:0][`XLEN-1:0] predict_target_pc ,

	input  mispredict,
	input  [`XLEN-1:0] mispredict_target_pc,

	input ld_rollback,
	input [`XLEN-1:0] ld_rollback_pc,
	
	input  [63:0] Imem2proc_data,          // Data coming back from instruction-memory
	output logic [`XLEN-1:0] proc2Imem_addr,    // Address sent to Instruction memory
	output IF_ID_PACKET [1:0] if_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 
);


	logic    [`XLEN-1:0] PC_reg;             // PC we are currently fetching
	
	logic    [`XLEN-1:0] PC_plus_4;
	logic    [`XLEN-1:0] PC_plus_8;
	logic    [`XLEN-1:0] next_PC;
	logic           PC_enable;
	
	assign proc2Imem_addr = {PC_reg[`XLEN-1:3], 3'b0};
	
	// this mux is because the Imem gives us 64 bits not 32 bits
	//assign if_packet_out.inst = PC_reg[2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];
	assign if_packet_out[0].inst = PC_reg[2]? Imem2proc_data[63:32]:Imem2proc_data[31:0];
	assign if_packet_out[1].inst = PC_reg[2]? `NOP:Imem2proc_data[63:32];
	
	// default next PC value
	assign PC_plus_4 = PC_reg + 4;
	assign PC_plus_8 = PC_reg + 8;
	
	assign next_PC = mispredict?                               mispredict_target_pc:
					 ld_rollback?                              ld_rollback_pc:
					 predict_take_branch[0] ?                  predict_target_pc[0]:
					 (!PC_reg[2]) && predict_take_branch[1] ?  predict_target_pc[1]:
					 PC_reg[2]? 		                       PC_plus_4:PC_plus_8;

	// assign next_PC = 	mispredict?                            mispredict_target_pc:
	// 					PC_reg[2]? 		                       PC_plus_4:PC_plus_8;

	
	// The take-branch signal must override stalling (otherwise it may be lost)
	// assign PC_enable = if_packet_out[0].valid | if_packet_out[1].valid | ex_cm_take_branch;
	assign PC_enable = ld_rollback | mispredict | (Icache_valid && !hazard_stall);

	// Pass PC+4 down pipeline w/instruction
	assign if_packet_out[0].NPC = PC_plus_4;
	assign if_packet_out[1].NPC = PC_plus_8;

	assign if_packet_out[0].PC  = PC_reg;
	assign if_packet_out[1].PC  = PC_plus_4;

	assign if_packet_out[0].valid = Icache_valid &&	!mispredict && !ld_rollback;
	assign if_packet_out[1].valid = Icache_valid && !mispredict && !PC_reg[2] && !predict_take_branch[0] && !ld_rollback;
	// assign if_packet_out[0].valid = Icache_valid &&	!mispredict;
	// assign if_packet_out[1].valid = Icache_valid && !mispredict && !PC_reg[2];
	
	// This register holds the PC value
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			PC_reg <= `SD 0;       // initial PC value is 0
		else if(PC_enable)
			PC_reg <= `SD next_PC; // transition to next PC
	end  // always
	
	// This FF controls the stall signal that artificially forces
	// fetch to stall until the previous instruction has completed
	// This must be removed for Project 3
	// synopsys sync_set_reset "reset"
	// always_ff @(posedge clock) begin
	// 	if (reset)
	// 		if_packet_out.valid <= `SD 1;  // must start with something
	// 	else
	// 		if_packet_out.valid <= `SD mem_wb_valid_inst;
	// end
endmodule  // module if_stage
