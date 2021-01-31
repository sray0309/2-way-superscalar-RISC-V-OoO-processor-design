/////////////////////////////////////////////////////////////////////////////
//                                                                         //
//                                                                         //
//                          freelist.sv                                     //
//                                                                         //
//                                                                         //
/////////////////////////////////////////////////////////////////////////////

module freelist(
	//inputs
	input 																clock,
	input 																reset,
	input 																rollback_en,
	input 		[`SCALAR_WIDTH-1:0]										dispatch_en,
	input 		[`SCALAR_WIDTH-1:0] 									retire_en,
	input 		[`SCALAR_WIDTH-1:0][4:0] 								decoder_FL_out_dest_idx,
	input 		[`SCALAR_WIDTH-1:0][`PREG_IDX_WIDTH-1:0] 				ROB_FL_out_Told_idx,		// Told index
	input 		[`PREG_IDX_WIDTH-1:0] 									ROB_FL_out_T_idx,		// to fl_cam index the FL_rollback_idx signal

	`ifdef DEBUG
	output logic   [`NUM_FL_ENTRIES-1:0][$clog2(`NUM_PR_ENTRIES)-1:0]   FL_table, next_FL_table,
	output logic   [$clog2(`NUM_FL_ENTRIES)-1:0]                 		FL_rollback_idx,
	output logic   [$clog2(`NUM_FL_ENTRIES)-1:0]                 		head, next_head,
	output logic   [$clog2(`NUM_FL_ENTRIES)-1:0]                 		tail, next_tail,
	output logic   [`SCALAR_WIDTH-1:0][$clog2(`NUM_FL_ENTRIES)-1:0] 	FL_idx,		 		// the position of tail in freelist
	`endif
	output logic   [`SCALAR_WIDTH-1:0]                                  FL_valid,
	output logic   [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0] 	T_idx			//destination register
	// output logic   [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0] 	FL_ROB_out_idx  
	// output logic   [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0] 	FL_RS_out_idx    
	// output logic   [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0] 	FL_RAT_out_idx
	);

	`ifndef DEBUG
	logic [`SCALAR_WIDTH-1:0][$clog2(`NUM_FL_ENTRIES)-1:0] 	FL_idx;	
	logic [$clog2(`NUM_FL_ENTRIES)-1:0]                 head, next_head;	// write, indicate where the tag should be retired in the freelist
	logic [$clog2(`NUM_FL_ENTRIES)-1:0]                 tail, next_tail;  	// read, indicate where the tag should be dispatched in the freelist
	logic [$clog2(`NUM_FL_ENTRIES)-1:0]                 		FL_rollback_idx;
	logic [`NUM_FL_ENTRIES-1:0][$clog2(`NUM_PR_ENTRIES)-1:0]    FL_table, next_FL_table;
	`endif
	logic [$clog2(`NUM_FL_ENTRIES)-1:0]                 	head_plus_one, head_plus_two;		// specify the num of bits
	logic [$clog2(`NUM_FL_ENTRIES)-1:0]                 	tail_plus_one, tail_plus_two;
	logic [$clog2(`NUM_FL_ENTRIES)-1:0]                 	dispatch_tail;		// next tail position when dispatch is enabled, virtually
	logic [$clog2(`NUM_FL_ENTRIES)-1:0]                 	retire_head;		// next head position when retire is enabled
	
	logic empty, full, almost_full;
	logic first_dest_rd;
	logic second_dest_rd;
	logic first_Told_rd;
	logic second_Told_rd;
	// logic [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0] 	T_idx; 			// Freelist output, Tags of target physical reg 

	// assign FL_ROB_out_idx = T_idx;
	// assign FL_RAT_out_idx = T_idx;
	// assign FL_RS_out_idx = T_idx;

	assign first_dest_rd = (decoder_FL_out_dest_idx[0] != `ZERO_REG);
	assign second_dest_rd = (decoder_FL_out_dest_idx[1] != `ZERO_REG);
	
	assign first_Told_rd	= (ROB_FL_out_Told_idx[0] != `ZERO_PREG);
	assign second_Told_rd	= (ROB_FL_out_Told_idx[1] != `ZERO_PREG);

	assign next_head =  (retire_en[0] || retire_en[1]) ? retire_head : head;	// head postion after retire stage
	assign next_tail =  rollback_en ? FL_rollback_idx :
                        (dispatch_en[0] || dispatch_en[1]) ? dispatch_tail    : tail;
	
	assign tail_plus_one = tail + 1;
	assign tail_plus_two = tail + 2;
	assign head_plus_one = head + 1;
	assign head_plus_two = head + 2;

	assign FL_valid = 	(next_head == tail)? 2'b00:		// empty, no preg available
						(next_head == tail_plus_one) ? 2'b01:	// only one preg away from empty
						2'b11;						// both spots availale



 	// dispatch logic
	always_comb begin
		unique if (first_dest_rd && second_dest_rd && (dispatch_en==2'b11)) begin
			dispatch_tail = tail_plus_two;
			T_idx = {next_FL_table[tail_plus_one], next_FL_table[tail]};
			FL_idx = {tail_plus_two, tail_plus_one};
		end else if (first_dest_rd && (dispatch_en==2'b01)) begin
			dispatch_tail = tail_plus_one;
			T_idx = {`ZERO_PREG, next_FL_table[tail]};
			FL_idx = {tail_plus_one, tail_plus_one};
		end else if (second_dest_rd && (dispatch_en==2'b10)) begin
			dispatch_tail = tail_plus_one;
			T_idx = {next_FL_table[tail], `ZERO_PREG};
			FL_idx = {tail_plus_one, tail};
		end else begin
			dispatch_tail = tail;
			T_idx 		 = {`ZERO_PREG, `ZERO_PREG};
			FL_idx 		 = {tail, tail};
		end
	end

	// retire logic
	always_comb begin
		next_FL_table = FL_table;
		unique if (first_Told_rd && second_Told_rd && (retire_en==2'b11)) begin
			next_FL_table[head] = ROB_FL_out_Told_idx[0];
			next_FL_table[head_plus_one] = ROB_FL_out_Told_idx[1];
			retire_head = head_plus_two;
		end else if (first_Told_rd  && (retire_en==2'b01)) begin
			next_FL_table[head] = ROB_FL_out_Told_idx[0];
			retire_head = head_plus_one;
		end else if (second_Told_rd && (retire_en==2'b10)) begin
			next_FL_table[head] = ROB_FL_out_Told_idx[1];
			retire_head = head_plus_one;
		end else begin
			retire_head = head;
			next_FL_table = FL_table;
		end
	end


	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			head <= `SD {$clog2(`NUM_FL_ENTRIES){1'b0}};
			tail <= `SD 1'b1;
			for (int i=1; i<`NUM_FL_ENTRIES; i++) begin
				FL_table[i] <= `SD i + `NUM_RF_ENTRIES; 	// initialize freelist to index [32:63] physical register file
			end

		end else begin
			head <= `SD next_head;
			tail <= `SD next_tail;
			FL_table <= `SD next_FL_table;
		end
	end

	// fl_cam freelist_cam(.*);
	fl_cam freelist_cam(
		.clock(clock),
		.reset(reset),
		.ROB_FL_out_T_idx(ROB_FL_out_T_idx),
		.T_idx(T_idx),
		.FL_idx(FL_idx),
		.FL_rollback_idx(FL_rollback_idx)
	);

endmodule

module fl_cam(
    //inputs
    input   clock, reset,
	// input 	rollback_en,
    input   [$clog2(`NUM_PR_ENTRIES)-1:0]                       ROB_FL_out_T_idx,
	input   [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0] 	T_idx,				//destination register
	input   [`SCALAR_WIDTH-1:0][$clog2(`NUM_FL_ENTRIES)-1:0]    FL_idx,

    //outputs
    output logic    [$clog2(`NUM_FL_ENTRIES)-1:0]       FL_rollback_idx
);
    logic [`NUM_PR_ENTRIES-1:0][$clog2(`NUM_FL_ENTRIES)-1:0]  FL_CAM_table, next_FL_CAM_table;
// assign the cam table according to FL_idx signal, clean the blocks that contain the same T_idx
    always_comb begin
        next_FL_CAM_table = FL_CAM_table;
        
        next_FL_CAM_table[T_idx[0]] = FL_idx[0];
        next_FL_CAM_table[T_idx[1]] = FL_idx[1];
    end

    assign FL_rollback_idx = FL_CAM_table[ROB_FL_out_T_idx];
    // always_comb begin
    //     FL_rollback_idx = 0;
    //     for(int i=0; i<`NUM_PR_ENTRIES; i++) begin
    //         if(i==ROB_FL_out_T_idx)
    //         FL_rollback_idx = FL_CAM_table[i];
    //     end
    // end

    always_ff @(posedge clock) begin
        if (reset) begin    
			for (int i=1; i<`NUM_PR_ENTRIES; i++) begin
				FL_CAM_table[i] <= `SD 0; 	// initialize freelist CAM table to 0
			end
        end else begin
            FL_CAM_table <= `SD next_FL_CAM_table;
        end
    end
endmodule
