/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mem_stage.v                                         //
//                                                                     //
//  Description :  memory access (MEM) stage of the pipeline;          //
//                 this stage accesses memory for stores and loads,    // 
//                 and selects the proper next PC value for branches   // 
//                 based on the branch condition computed in the       //
//                 previous stage.                                     // 
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __MEM_STAGE_V__
`define __MEM_STAGE_V__

`timescale 1ns/100ps

module mem_stage(
	input         clock,              // system clock
	input         reset,              // system reset
	input         wr_mem,
    input         rd_mem,
    input  [`XLEN-1:0] data_in,
    input  [`XLEN-1:0] addr_in,
    input  [2:0]    mem_size,
	input  [`XLEN-1:0] Dmem2proc_data,
	
	output logic [`XLEN-1:0] mem_result_out,      // outgoing instruction result (to MEM/WB)
	output logic [1:0] proc2Dmem_command,
	output MEM_SIZE proc2Dmem_size,
	output logic [`XLEN-1:0] proc2Dmem_addr,      // Address sent to data-memory
	output logic [`XLEN-1:0] proc2Dmem_data      // Data sent to data-memory
);



	// Determine the command that must be sent to mem
	assign proc2Dmem_command =
	                        wr_mem ? BUS_STORE :
							rd_mem ? BUS_LOAD :
	                        BUS_NONE;

	assign proc2Dmem_size = MEM_SIZE'(mem_size[1:0]);	//only the 2 LSB to determine the size;
	


	// The memory address is calculated by the ALU
	assign proc2Dmem_data = data_in;

	assign proc2Dmem_addr = addr_in;	
	// Assign the result-out for next stage
	always_comb begin
		mem_result_out = data_in;
		if (rd_mem) begin
			if (mem_size[2]) begin //is this an signed/unsigned load?
				if (mem_size[1:0] == 2'b0)
					mem_result_out = {{(`XLEN-8){Dmem2proc_data[7]}}, Dmem2proc_data[7:0]};
				else if  (mem_size[1:0] == 2'b01) 
					mem_result_out = {{(`XLEN-16){Dmem2proc_data[15]}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end else begin
				if (mem_size[1:0] == 2'b0)
					mem_result_out = {{(`XLEN-8){1'b0}}, Dmem2proc_data[7:0]};
				else if  (mem_size[1:0] == 2'b01)
					mem_result_out = {{(`XLEN-16){1'b0}}, Dmem2proc_data[15:0]};
				else mem_result_out = Dmem2proc_data;
			end
		end
	end
	//if we are in 32 bit mode, then we should never load a double word sized data
	assert property (@(negedge clock) (`XLEN == 32) && rd_mem |-> proc2Dmem_size != DOUBLE);

endmodule // module mem_stage
`endif // __MEM_STAGE_V__
