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

task display_debug();
    $display("time: %0t  FL_idx: %0d, %0d   FL_rollback_idx: %0d", $time, FL_idx[1], FL_idx[0], FL_rollback_idx);
    for (int i = 0; i < `NUM_PR_ENTRIES; i++) begin
        $display("FL_CAM_table[%0d] %d", i,FL_CAM_table[i]);
    end
    $display("#########################################################\n", FL_CAM_table[38], ROB_FL_out_T_idx,$clog2(`NUM_PR_ENTRIES),`PREG_IDX_WIDTH);
endtask

initial begin
    fork 
        #65 display_debug();
        #85 display_debug();
        #95 display_debug();
        #105 display_debug();
        #115 display_debug();
        #125 display_debug();
    join_none
end
endmodule
        
