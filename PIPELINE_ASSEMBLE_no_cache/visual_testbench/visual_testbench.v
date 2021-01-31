/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  visual_testbench.v                                  //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline        //
//                   for the visual debugger                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

extern void initcurses(int,int,int,int,int,int);
extern void flushpipe();
extern void waitforresponse();
extern void initmem();
extern int get_instr_at_pc(int);
extern int not_valid_pc(int);

module testbench();

  // Registers and wires used in the testbench
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
	logic  [1:0][3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic  [1:0][4:0] pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic  [1:0]     pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;
	
	
	logic [`XLEN-1:0] if_NPC_out;
	logic [31:0] if_IR_out;
	logic        if_valid_inst_out;
	logic [`XLEN-1:0] if_id_NPC;
	logic [31:0] if_id_IR;
	logic        if_id_valid_inst;
	logic [`XLEN-1:0] id_ex_NPC;
	logic [31:0] id_ex_IR;
	logic        id_ex_valid_inst;
	logic [`XLEN-1:0] ex_mem_NPC;
	logic [31:0] ex_mem_IR;
	logic        ex_mem_valid_inst;
	logic [`XLEN-1:0] mem_wb_NPC;
	logic [31:0] mem_wb_IR;
	logic        mem_wb_valid_inst;

    IS_EX_PACKET [1:0] is_packet;

  //counter used for when pipeline infinite loops, forces termination
  logic [63:0] debug_counter;
	// Instantiate the Pipeline
	pipeline pipeline_0(
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
        .is_packet(is_packet),
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

  // Generate System Clock
  always
  begin
    #(`VERILOG_CLOCK_PERIOD/2.0);
    clock = ~clock;
  end

  // Count the number of posedges and number of instructions completed
  // till simulation ends
  always @(posedge clock)
  begin
    if(reset)
    begin
      clock_count <= `SD 0;
      instr_count <= `SD 0;
    end
    else
    begin
      clock_count <= `SD (clock_count + 1);
      instr_count <= `SD (instr_count + pipeline_completed_insts[0]+pipeline_completed_insts[1]);
    end
  end  


  logic [15:0] [63:0] cache_data;
  genvar iter0, iter1;
  generate;
  for (iter0=0; iter0<4; iter0++) begin
    for (iter1=0; iter1<4; iter1++) begin
      assign cache_data[iter0*4+iter1] = pipeline_0.dcache_0.dcache_mem_0.cacheset_gen[iter0].dcache_set.data[iter1];
    end
  end
  endgenerate

  initial
  begin
    clock = 0;
    reset = 0;

    // Call to initialize visual debugger
    // *Note that after this, all stdout output goes to visual debugger*
    // each argument is number of registers/signals for the group
    // (IF, IF/ID, ID, ID/EX, EX, EX/MEM, MEM, MEM/WB, WB, Misc)
    // initcurses(6,4,13,17,4,14,5,9,3,2);
    initcurses(6,6,6,6,6,6);
    // Pulse the reset signal
    reset = 1'b1;
    @(posedge clock);
    @(posedge clock);

    // Read program contents into memory array
    $readmemh("program.mem", memory.unified_memory);

    @(posedge clock);
    @(posedge clock);
    `SD;
    // This reset is at an odd time to avoid the pos & neg clock edges
    reset = 1'b0;
  end

  always @(negedge clock)
  begin
    if(!reset)
    begin
      `SD;
      `SD;

      // deal with any halting conditions
      if(pipeline_error_status!=NO_ERROR)
      begin
        #100
        $display("\nDONE\n");
        waitforresponse();
        flushpipe();
        $finish;
      end

    end
  end 
  

  // This block is where we dump all of the signals that we care about to
  // the visual debugger.  Notice this happens at *every* clock edge.
  always @(clock) begin
    #2;

    // Dump clock and time onto stdout
    $display("c%h%7.0d",clock,clock_count);
    $display("t%8.0f",$time);
    $display("z%h",reset);


    // dump ROB contents
    $write("a");
    for(int i = 0; i < 32; i=i+1)
    begin
      $write("%h%h%h%h%h%h%h%h%h%h%h%h%h%h%h%h%h ", 
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].rob_idx, //2
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].T_new, //2
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].T_old, //2
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].inst,  //8
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].valid,
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].is_branch, //1
            pipeline_0.dp_is_stage_0.rob_0.head==i,  //1
            pipeline_0.dp_is_stage_0.rob_0.tail==i,
            pipeline_0.head_retire_rdy,
            pipeline_0.head_p1_retire_rdy,
         //   pipeline_0.dp_is_stage_0.rob_0.head_retire_rdy, //1
         //   pipeline_0.dp_is_stage_0.rob_0.head_p1_retire_rdy,
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].PC,
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].ex_target_pc,
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].ex_take_branch,
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].predict_target_pc,
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].predict_take_branch,
            pipeline_0.dp_is_stage_0.rob_0.cb.retire_tag[i],
            pipeline_0.dp_is_stage_0.rob_0.cb.data[i].rd_mem_violation);
    end
    $display("");

    //dump CDB contents
    $write("w");
    for(int i = 0; i < 2; i=i+1)
    begin
      $write("%h%h%h%h", 
        pipeline_0.cdb_packet[i].cdb_tag,
        pipeline_0.cdb_packet[i].cdb_rob_idx,
        pipeline_0.cdb_packet[i].cdb_value,
        pipeline_0.cdb_packet[i].cdb_valid);
    end
    $display("");

    // logic  cdb_valid;
	// logic [`PREG_IDX_WIDTH-1:0] cdb_tag;
	// logic [`ROB_IDX_WIDTH-1:0]  cdb_rob_idx;
	// logic [`XLEN-1:0]           cdb_value;


    //dump GHT contents
    $display("o%b", pipeline_0.bp_0.dirp_0.bht_0.data);


    // // dump PRF contents
    // $write("r");
    // for(int i = 0; i < 65; i=i+1)
    // begin
    //   $write("%h", pipeline_0.ex_stage_0.regfile_0.registers[i]);
    // end
    // $display("");


    // dump Dcache contents
    $write("r");
    for(int i = 0; i < 16; i=i+1)
    begin
      $write("%h", cache_data[i]);
    end
    $display("");

    // dump Map Table contents
    $write("y");
    for(int i = 0; i < 32; i=i+1)
    begin
      $write("%h%h", 
        pipeline_0.rn_stage_0.maptables_0.rat.rat_entries[i].rat_tag,
        pipeline_0.rn_stage_0.maptables_0.rat.rat_entries[i].preg_ready | 
        pipeline_0.rn_stage_0.maptables_0.rat.rat_entries[i].rat_tag == pipeline_0.rn_stage_0.maptables_0.rat.cdb_packet[0].cdb_tag |
        pipeline_0.rn_stage_0.maptables_0.rat.rat_entries[i].rat_tag == pipeline_0.rn_stage_0.maptables_0.rat.cdb_packet[1].cdb_tag);
    end
    $display("");

    // dump Arch. Map Table contents
    $write("u");
    for(int i = 0; i < 32; i=i+1)
    begin
      $write("%h", pipeline_0.rn_stage_0.maptables_0.rrat.rrat_entries[i].rrat_tag);
    end
    $display("");

    // dump Freelist contents
    $write("v");
    for(int i = 0; i < 32; i=i+1)
    begin
      $write("%h%h%h", 
        pipeline_0.rn_stage_0.freelist_0.fl_table[i],
        pipeline_0.rn_stage_0.freelist_0.head == i,
        pipeline_0.rn_stage_0.freelist_0.tail == i);
    end
    $display("");


    // dump Load Queue contents
    $write("h");
    for(int i = 0; i < 8; i=i+1)
    begin
      $write("%h%h%h%h%h%h%h%h", 
        pipeline_0.LSQ_0.lq_0.lq[i].addr,
        pipeline_0.LSQ_0.lq_0.lq[i].valid,
        pipeline_0.LSQ_0.lq_0.lq[i].rob_idx,
        pipeline_0.LSQ_0.lq_0.lq[i].SQ_idx,
        pipeline_0.LSQ_0.lq_0.head == i,
        pipeline_0.LSQ_0.lq_0.tail == i,
        pipeline_0.LSQ_0.lq_0.ld_hit[0],
        pipeline_0.LSQ_0.lq_0.ld_hit[1]);
    end
    $display("");

    // dump Store Queue contents
    $write("j");
    for(int i = 0; i < 8; i=i+1)
    begin
      $write("%h%h%h%h%h%h%h%h", 
        pipeline_0.LSQ_0.sq_0.sq[i].addr,
        pipeline_0.LSQ_0.sq_0.sq[i].valid,
        pipeline_0.LSQ_0.sq_0.sq[i].value,
        pipeline_0.LSQ_0.sq_0.sq[i].LQ_idx,
        pipeline_0.LSQ_0.sq_0.head == i,
        pipeline_0.LSQ_0.sq_0.tail == i,
        pipeline_0.LSQ_0.sq_0.st_hit[0],
        pipeline_0.LSQ_0.sq_0.st_hit[1]);
    end
    $display("");


    // dump Load Queue Buffer contents
    $write("1");
    for(int i = 0; i < 8; i=i+1)
    begin
      $write("%h%h%h%h%h%d", 
        pipeline_0.LSQ_0.lq_0.lmb_0.value_buffer[i],
        pipeline_0.LSQ_0.lq_0.lmb_0.valid_buffer[i],
        pipeline_0.LSQ_0.lq_0.lmb_0.head == i,
        pipeline_0.LSQ_0.lq_0.lmb_0.tail == i,
        pipeline_0.LSQ_0.lq_0.lmb_0.entry[i].result,
        pipeline_0.LSQ_0.lq_0.lmb_0.entry[i].rob_idx);
    end
    $display("");

    // dump Retire Store Buffer contents
    $write("2");
    for(int i = 0; i < 8; i=i+1)
    begin
      $write("%h%h%h%h", 
        pipeline_0.LSQ_0.sq_0.rtb_0.entry[i].value,
        pipeline_0.LSQ_0.sq_0.rtb_0.valid[i],
        pipeline_0.LSQ_0.sq_0.rtb_0.pointer,
        pipeline_0.LSQ_0.sq_0.rtb_0.entry[i].addr);
    end
    $display("");


    // dump IR information so we can see which instruction
    // is in each stage
    $write("p");
    $write("%h%h%h%h%h%h%h%h%h%h%h%h%h%h ",
            pipeline_0.if_IR_out[0],  pipeline_0.if_valid_inst_out[0],
            pipeline_0.if_id_IR[0],  pipeline_0.if_id_valid_inst[0],
            pipeline_0.id_rn_IR[0],  pipeline_0.id_rn_valid_inst[0],
            pipeline_0.rn_dp_IR[0], pipeline_0.rn_dp_valid_inst[0],
            pipeline_0.is_packet[0].inst, pipeline_0.is_packet[0].valid,
            pipeline_0.is_ex_IR[0], pipeline_0.is_ex_valid_inst[0],
            pipeline_0.ex_cm_IR[0], pipeline_0.ex_cm_valid_inst[0]);
    $display("");

    $write("l");
    $write("%h%h%h%h%h%h%h%h%h%h%h%h%h%h ",
            pipeline_0.if_IR_out[1],  pipeline_0.if_valid_inst_out[1],
            pipeline_0.if_id_IR[1],  pipeline_0.if_id_valid_inst[1],
            pipeline_0.id_rn_IR[1],  pipeline_0.id_rn_valid_inst[1],
            pipeline_0.rn_dp_IR[1], pipeline_0.rn_dp_valid_inst[1],
            pipeline_0.is_packet[1].inst, pipeline_0.is_packet[1].valid,
            pipeline_0.is_ex_IR[1], pipeline_0.is_ex_valid_inst[1],
            pipeline_0.ex_cm_IR[1], pipeline_0.ex_cm_valid_inst[1]);
    $display("");


    // dump RS1 contents
    $write("s");
    for(int i = 0; i < 8; i=i+1)
    begin
      $write("%h%h%h%h%h%h%h%h%h%h%h%h%h%h%h%h ", 
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.inst_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.entry_busy[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.prega_idx_file[i], 
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.pregb_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.pdest_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.opa_select_file[i] == 2'h0,
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.opb_select_file[i] == 4'h0,
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.prega_tag[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.pregb_tag[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.entry_ALU_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.lq_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.entry_LOAD_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.sq_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.entry_STORE_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.entry_MULT_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.entry_BR_ready[i]);
    end
    $display("");

    // dump RS2 contents
    $write("x");
    for(int i = 0; i < 8; i=i+1)
    begin
      $write("%h%h%h%h%h%h%h%h%h%h%h%h%h%h%h%h ", 
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.inst_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.entry_busy[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.prega_idx_file[i], 
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.pregb_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.pdest_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.opa_select_file[i] == 2'h0,
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.opb_select_file[i] == 4'h0,
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.prega_tag[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.pregb_tag[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.entry_ALU_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.lq_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.entry_LOAD_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_0.sq_idx_file[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.entry_STORE_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.entry_MULT_ready[i],
        pipeline_0.dp_is_stage_0.rs_super_0.rs_bank_1.entry_BR_ready[i]);
    end
    $display("");
    
    // Dump interesting register/signal contents onto stdout
    // format is "<reg group prefix><name> <width in hex chars>:<data>"
    // Current register groups (and prefixes) are:
    // f: IF   d: ID   e: EX   m: MEM    w: WB  v: misc. reg
    // g: IF/ID   h: ID/EX  i: EX/MEM  j: MEM/WB

    // IF signals (6) - prefix 'f'
    // $display("fif_NPC_out[0] 32:%h",          pipeline_0.if_NPC_out[0]);
    // $display("fif_IR_out[0] 32:%h",            pipeline_0.if_IR_out[0]);
    // $display("fif_valid_inst_out[0] 1:%h",    pipeline_0.if_valid_inst_out[0]);
    // $display("fif_NPC_out[1] 32:%h",          pipeline_0.if_NPC_out[1]);
    // $display("fif_IR_out[1] 32:%h",            pipeline_0.if_IR_out[1]);
    // $display("fif_valid_inst_out[1] 1:%h",    pipeline_0.if_valid_inst_out[1]);
    // $display("frob_next_data2 32:%h",     pipeline_0.dp_is_stage_0.rob_0.cb.next_data2.inst);
    // $display("frob_next_condition 4:%b", {pipeline_0.dp_is_stage_0.rob_0.cb.dp_en1,pipeline_0.dp_is_stage_0.rob_0.cb.dp_en2,pipeline_0.dp_is_stage_0.rob_0.cb.reti_en1,pipeline_0.dp_is_stage_0.rob_0.cb.reti_en2});
    // $display("ffl_next_condition 4:%b", {pipeline_0.rn_stage_0.freelist_0.dp_en0,pipeline_0.rn_stage_0.freelist_0.dp_en1,pipeline_0.rn_stage_0.freelist_0.reti_en0,pipeline_0.rn_stage_0.freelist_0.reti_en1});
    // $display("fdin0 5:%h",   pipeline_0.rn_stage_0.freelist_0.din0);
    // $display("fdin1 5:%h",   pipeline_0.rn_stage_0.freelist_0.din1);
    $display("finstr_cnt 32:%d", instr_count);
    $display("fex[0]_regb 32:%h",      pipeline_0.ex_cm_packet[0].regb_value);
    $display("fex[1]_regb 32:%h",      pipeline_0.ex_cm_packet[1].regb_value);
    // $display("frn_rollback 1:%h",          pipeline_0.rn_stage_0.rollback_en);
    $display("fmem2proc_response 2:%d",          pipeline_0.dcache_0.dcache_controller_0.mem2proc_response);
    $display("fmem2proc_tag 2:%d",           pipeline_0.dcache_0.dcache_controller_0.mem2proc_tag);
    $display("fproc2mem_command 2:%d",    pipeline_0.dcache_0.dcache_controller_0.proc2mem_command);
    // $display("fwaiting_memtag 2:%d",          pipeline_0.dcache_0.dcache_controller_0.waiting_memtag);



    // IF/ID signals (6) - prefix 'g'
    $display("gif_id_NPC[0] 32:%h",         pipeline_0.if_id_NPC[0]);
    $display("gif_id_IR[0] 32:%h",          pipeline_0.if_id_IR[0]);
    $display("gif_id_valid_inst[0] 1:%h",   pipeline_0.if_id_valid_inst[0]);
    $display("gif_id_NPC[1] 32:%h",         pipeline_0.if_id_NPC[1]);
    $display("gif_id_IR[1] 32:%h",          pipeline_0.if_id_IR[1]);
    $display("gif_id_valid_inst[1] 1:%h",   pipeline_0.if_id_valid_inst[1]);

    // ID/RN signals (6) - prefix 'd'
    $display("did_rn_NPC[0] 32:%h",             pipeline_0.id_rn_NPC[0]);
    $display("did_rn_IR[0] 32:%h",              pipeline_0.id_rn_IR[0]);
    $display("did_rn_valid_inst[0] 1:%h",       pipeline_0.id_rn_valid_inst[0]);
    $display("did_rn_NPC[1] 32:%h",             pipeline_0.id_rn_NPC[1]);
    $display("did_rn_IR[1] 32:%h",              pipeline_0.id_rn_IR[1]);
    $display("did_rn_valid_inst[1] 1:%h",       pipeline_0.id_rn_valid_inst[1]);

    // RN/DP signals (6) - prefix 'e'
    $display("ern_dp_NPC[0] 32:%h",        pipeline_0.rn_dp_NPC[0]);
    $display("ern_dp_IR[0] 32:%h",          pipeline_0.rn_dp_IR[0]); 
    $display("ern_dp_valid_inst[0] 1:%h",            pipeline_0.rn_dp_valid_inst[0]); 
    $display("ern_dp_NPC[1] 32:%h",        pipeline_0.rn_dp_NPC[1]);
    $display("ern_dp_IR[1] 32:%h",          pipeline_0.rn_dp_IR[1]); 
    $display("ern_dp_valid_inst[1] 1:%h",            pipeline_0.rn_dp_valid_inst[1]); 

    // IS/EX  signals (6) - prefix 'i'
    $display("iis_ex_NPC[0] 32:%h",      pipeline_0.is_ex_NPC[0]);
    $display("iis_ex_IR[0] 32:%h",      pipeline_0.is_ex_IR[0]);
    $display("iis_ex_valid_inst[0] 1:%h",   pipeline_0.is_ex_valid_inst[0]);
    $display("iis_ex_NPC[1] 32:%h",      pipeline_0.is_ex_NPC[1]);
    $display("iis_ex_IR[1] 32:%h",      pipeline_0.is_ex_IR[1]);
    $display("iis_ex_valid_inst[1] 1:%h",   pipeline_0.is_ex_valid_inst[1]);


    // EX/CM signals (6) - prefix 'm'
    $display("mex_cm_NPC[0] 32:%h",        pipeline_0.ex_cm_NPC[0]);
    $display("mex_cm_IR[0] 32:%h",          pipeline_0.ex_cm_IR[0]);
    $display("mex_cm_valid_inst[0] 1:%h",            pipeline_0.ex_cm_valid_inst[0]);
    $display("mex_cm_NPC[1] 32:%h",        pipeline_0.ex_cm_NPC[1]);
    $display("mex_cm_IR[1] 32:%h",          pipeline_0.ex_cm_IR[1]);
    $display("mex_cm_valid_inst[1] 1:%h",            pipeline_0.ex_cm_valid_inst[1]);


    // must come last
    $display("break");

    // This is a blocking call to allow the debugger to control when we
    // advance the simulation
    waitforresponse();
  end
endmodule
