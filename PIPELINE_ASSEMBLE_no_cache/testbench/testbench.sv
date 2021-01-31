/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                                       int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
                                          int proc2mem_addr_hi, int proc2mem_addr_lo,
						 			     int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void print_close();


module testbench;

	// variables used in the testbench
	logic        clock;
	logic        reset;
	logic [31:0] clock_count;
	logic [31:0] instr_count;
	int          wb_fileno;
	
	logic [1:0]  proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0] proc2mem_data;
	logic  [3:0] mem2proc_response;
	logic [63:0] mem2proc_data;
	logic  [3:0] mem2proc_tag;
`ifndef CACHE_MODE
	MEM_SIZE     proc2mem_size;
`endif
	logic [1:0] [3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic [1:0] [4:0] pipeline_commit_wr_idx;
	logic [1:0] [`XLEN-1:0] pipeline_commit_wr_data;
	logic [1:0]       pipeline_commit_wr_en;
	logic [1:0] [`XLEN-1:0] pipeline_commit_NPC;
	
	
	logic [1:0] [`XLEN-1:0] if_NPC_out;
	logic [1:0] [31:0] if_IR_out;
	logic [1:0]        if_valid_inst_out;
	logic [1:0] [`XLEN-1:0] if_id_NPC;
	logic [1:0] [31:0] if_id_IR;
	logic [1:0]        if_id_valid_inst;
	logic [1:0] [`XLEN-1:0] id_rn_NPC;
	logic [1:0] [31:0] id_rn_IR;
	logic [1:0]        id_rn_valid_inst;
	logic [1:0] [`XLEN-1:0] rn_dp_NPC;
	logic [1:0] [31:0] rn_dp_IR;
	logic [1:0]        rn_dp_valid_inst;
	logic [1:0] [`XLEN-1:0] is_ex_NPC;
	logic [1:0] [31:0] is_ex_IR;
	logic [1:0]        is_ex_valid_inst;
    logic [1:0] [`XLEN-1:0] ex_cm_NPC;
	logic [1:0] [31:0] ex_cm_IR;
	logic [1:0]        ex_cm_valid_inst;

    //counter used for when pipeline infinite loops, forces termination
    logic [63:0] debug_counter;
	// Instantiate the Pipeline
	pipeline core(
		// Inputs
		.clock             (clock),
		.reset             (reset),
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag),
		
		
		// Outputs
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
		.proc2mem_size     (proc2mem_size),
		
		.pipeline_completed_insts(pipeline_completed_insts),
		.pipeline_error_status(pipeline_error_status),
		.pipeline_commit_wr_data(pipeline_commit_wr_data),
		.pipeline_commit_wr_idx(pipeline_commit_wr_idx),
		.pipeline_commit_wr_en(pipeline_commit_wr_en),
		.pipeline_commit_NPC(pipeline_commit_NPC),
		
		.if_NPC_out(if_NPC_out),
		.if_IR_out(if_IR_out),
		.if_valid_inst_out(if_valid_inst_out),
		.if_id_NPC(if_id_NPC),
		.if_id_IR(if_id_IR),
		.if_id_valid_inst(if_id_valid_inst),
		.id_rn_NPC(id_rn_NPC),
		.id_rn_IR(id_rn_IR),
		.id_rn_valid_inst(id_rn_valid_inst),
		.rn_dp_NPC(rn_dp_NPC),
		.rn_dp_IR(rn_dp_IR),
		.rn_dp_valid_inst(rn_dp_valid_inst),
		.is_ex_NPC(is_ex_NPC),
		.is_ex_IR(is_ex_IR),
		.is_ex_valid_inst(is_ex_valid_inst),
        .ex_cm_NPC(ex_cm_NPC),
        .ex_cm_IR(ex_cm_IR),
        .ex_cm_valid_inst(ex_cm_valid_inst)
	);
	
	
	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size     (proc2mem_size),
`endif

		// Outputs

		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);

	logic [`DCACHE_IDX_WIDTH-1:0] cache_idx;
	logic [`DCACHE_TAG_WIDTH-1:0] cache_tag;
	logic [63:0] cache_data;
	
	// Generate System Clock
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
	
	// Task to display # of elapsed clock edges
	task show_clk_count;
		real cpi;
		
		begin
			cpi = (clock_count + 1.0) / instr_count;
			$display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
			          clock_count+1, instr_count, cpi);
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`VERILOG_CLOCK_PERIOD);
		end
	endtask  // task show_clk_count 


    logic [`DCACHE_SET_NUM-1:0] [`DCACHE_WAY_NUM-1:0] [`DCACHE_TAG_WIDTH-1:0] tag_from_dcache;
    logic [`DCACHE_SET_NUM-1:0] [`DCACHE_WAY_NUM-1:0] [`DATA_SIZE-1:0]        data_from_dcache;
	logic [`DCACHE_SET_NUM-1:0] [`DCACHE_WAY_NUM-1:0]                         valid_from_dcache;

    // genvar s,t;
    // generate
    // for (s=0;s<`DCACHE_SET_NUM;s++) begin
    //     for (t=0;t<`DCACHE_WAY_NUM;t++) begin
    //         assign tag_from_dcache[s][t] = core.dcache_0.dcache_mem_0.cacheset_gen[s].dcache_set.tag[t];
    //         assign data_from_dcache[s][t] = core.dcache_0.dcache_mem_0.cacheset_gen[s].dcache_set.data[t];
	// 		assign valid_from_dcache[s][t] = core.dcache_0.dcache_mem_0.cacheset_gen[s].dcache_set.validbit[t];
    //     end
    // end
    // endgenerate
	
	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;

		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1) begin
                if (memory.unified_memory[k] != 0) begin
					$display("@@@ from memory: mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
				                                            memory.unified_memory[k]);
					showing_data=1;
				end 
			end
			// for (int q=start_addr; q<=end_addr; q=q+1) begin
			// 	{cache_tag,cache_idx} = q[31:3];
            //     for (int m=0;m<`DCACHE_WAY_NUM;m++) begin
            //         if (m == cache_idx) begin
            //             for (int n=0;n<`DCACHE_SET_NUM;n++) begin
			// 	            if (tag_from_dcache[m][n] == cache_tag && valid_from_dcache[m][n] && q[2:0] == 3'b000 && data_from_dcache[m][n] != 64'b0) begin
			// 	            	$display("@@@ from cache: mem[%5d] = %x : %0d  cache_idx is %0d, cache_tag is %0h", q, data_from_dcache[m][n], 
			// 	                                                        data_from_dcache[m][n], cache_idx, cache_tag);
			// 	            end
            //             end
            //         end
            //     end
			// end
            if(showing_data) begin
				$display("@@@");
			end
			$display("@@@");
		end
	endtask  // task show_mem_with_decimal


	
	initial begin
		// $dumpvars;
	
		clock = 1'b0;
		reset = 1'b0;
		
		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);
		
		$readmemh("program.mem", memory.unified_memory);
		
		@(posedge clock);
		@(posedge clock);
		`SD;
		// This reset is at an odd time to avoid the pos & neg clock edges
		
		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);
		
		wb_fileno = $fopen("writeback.out");
		
		//Open header AFTER throwing the reset otherwise the reset state is displayed
		print_header("                                                                            D-MEM Bus &\n");
		print_header("Cycle:      IF      |     ID      |     EX      |     MEM     |     WB      Reg Result");
	end


	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + pipeline_completed_insts[1] + pipeline_completed_insts[0]);
		end
	end  
	
	
	always @(negedge clock) begin
        if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
            debug_counter <= 0;
        end else begin
			`SD;
			`SD;
			
			 // print the piepline stuff via c code to the pipeline.out
			 print_cycles();
			 print_stage(" ", if_IR_out, if_NPC_out[31:0], {31'b0,if_valid_inst_out});
			 print_stage("|", if_id_IR, if_id_NPC[31:0], {31'b0,if_id_valid_inst});
			 print_stage("|", id_rn_IR, id_rn_NPC[31:0], {31'b0,id_rn_valid_inst});
			 print_stage("|", rn_dp_IR, rn_dp_NPC[31:0], {31'b0,rn_dp_valid_inst});
			 print_stage("|", is_ex_IR, is_ex_NPC[31:0], {31'b0,is_ex_valid_inst});
             print_stage("|", ex_cm_IR, ex_cm_NPC[31:0], {31'b0,ex_cm_valid_inst});
			 print_reg(32'b0, pipeline_commit_wr_data[31:0],
				{27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
			 print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
				32'b0, proc2mem_addr[31:0],
				proc2mem_data[63:32], proc2mem_data[31:0]);
			
			
			 // print the writeback information to writeback.out
			if(pipeline_completed_insts[0]>0) begin
                if(pipeline_commit_wr_en[0])
					// $fdisplay(wb_fileno, "%f PC=%x, REG[%d]=%x", $time,
                    $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_NPC[0]-4,
						pipeline_commit_wr_idx[0],
						pipeline_commit_wr_data[0]);
                else $fdisplay(wb_fileno, "PC=%x, ---",
                        pipeline_commit_NPC[0]-4);
			end

			if(pipeline_completed_insts[1]>0) begin
                if(pipeline_commit_wr_en[1])
					// $fdisplay(wb_fileno, "%f PC=%x, REG[%d]=%x", $time,
                    $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_NPC[1]-4,
						pipeline_commit_wr_idx[1],
						pipeline_commit_wr_data[1]);
                else $fdisplay(wb_fileno, "PC=%x, ---",
                        pipeline_commit_NPC[1]-4);
			end
			
			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
				// 8Bytes per line, 16kB total
				
				$display("@@  %t : System halted\n@@", $realtime);
				
				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:  
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:          
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default: 
						$display("@@@ System halted on unknown error code %x", 
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				@(negedge clock);
				show_clk_count;
				print_close(); // close the pipe_print output file
				$fclose(wb_fileno);
				#100 $finish;
			end
            debug_counter <= debug_counter + 1;
		end  // if(reset)   
	end 

endmodule  // module testbench
