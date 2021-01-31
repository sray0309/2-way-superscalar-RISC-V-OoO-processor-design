// `timescale 1ns/100ps

// `include "../sys_defs.svh"

module freelist_test;
    //inputs
  logic                                    clock;               // system clock
  logic                                    reset;               // system reset
  logic [`SCALAR_WIDTH-1:0]                dispatch_en;
  logic                                    rollback_en;
  logic [`SCALAR_WIDTH-1:0]                retire_en;
//   logic [$clog2(`NUM_FL_ENTRIES)-1:0]                       FL_rollback_idx;
  logic [`SCALAR_WIDTH-1:0][4:0] 			                decoder_FL_out_dest_idx;
  logic [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0]    ROB_FL_out_Told_idx;
  logic [$clog2(`NUM_PR_ENTRIES)-1:0]                       ROB_FL_out_T_idx;
  // debug outputs
  logic [`NUM_FL_ENTRIES-1:0][$clog2(`NUM_PR_ENTRIES)-1:0]  FL_table, next_FL_table;
  logic [$clog2(`NUM_FL_ENTRIES)-1:0]                       head, next_head;
  logic [$clog2(`NUM_FL_ENTRIES)-1:0]                       tail, next_tail;
  // outputs
  logic [`SCALAR_WIDTH-1:0]                FL_valid;
  logic [`SCALAR_WIDTH-1:0][$clog2(`NUM_PR_ENTRIES)-1:0]    T_idx;
  logic [`SCALAR_WIDTH-1:0][$clog2(`NUM_FL_ENTRIES)-1:0]    FL_idx;

  logic [`NUM_FL_ENTRIES-1:0][$clog2(`NUM_PR_ENTRIES)-1:0]  debug_table_out;  // debug testbench parameter
  logic   [$clog2(`NUM_FL_ENTRIES)-1:0]                 		FL_rollback_idx;
  freelist fl(.*);
//   freelist DUT(
//     .clock(clock),
//     .reset(reset),
//     .dispatch_en(dispatch_en),
//     .rollback_en(rollback_en),
//     .retire_en(retire_en),
//     .FL_rollback_idx(FL_rollback_idx),
//     .decoder_FL_out_dest_idx(decoder_FL_out_dest_idx),
//     .ROB_FL_out_Told_idx(ROB_FL_out_Told_idx),
// `ifdef DEBUG
//     .FL_table(FL_table),
//     .next_FL_table(next_FL_table),
//     .head(head),
//     .next_head(next_head),
//     .tail(tail),
//     .next_tail(next_tail),
// `endif
//     .FL_valid(FL_valid),
//     .T_idx(T_idx),
//     .FL_idx(FL_idx)
//   );


//////////////////////////////////////////////////////////////////// clock generation ////////////////////////////////////////////////////////////////////////
  always begin
    #5
    clock = ~clock;
  end

/////////////////////////////////////////////////////////////////// trigger reset ////////////////////////////////////////////////////////////////////////////

initial begin
    reset = 0;
    @(negedge clock);
        reset = 1;
        dispatch_en = 0;
        rollback_en = 0;
        ROB_FL_out_T_idx = 0;
        retire_en = 0;
        decoder_FL_out_dest_idx = 0;
        ROB_FL_out_Told_idx = 0;
    @(negedge clock);
        reset = 0;
    @(posedge clock);
    $display("############## Time:%0t RESET information: ###############\n\
 rollback_en : %0d                       ROB_FL_out_T_idx : %0d\n \
 dispatch_en[0]:%0d                      dispatch_en[1]:%0d\n\
 retire_en[0]:%0d                        retire_en[1]:%0d\n\
 decoder_FL_out_dest_idx[0]:%0d          decoder_FL_out_dest_idx[1]:%0d\n\
 ROB_FL_out_Told_idx[0]:%0d              ROB_FL_out_Told_idx[1]:%0d\n\
 FL_valid[0]:%0d                      FL_valid[1]:%0d\n\
 T_idx[0]:%0d                         T_idx[1]:%0d\n\
#########################################################\n \
                ",$time, rollback_en,ROB_FL_out_T_idx,
                         dispatch_en[0],dispatch_en[1], 
                         retire_en[0],retire_en[1],
                         decoder_FL_out_dest_idx[0],decoder_FL_out_dest_idx[1],
                         ROB_FL_out_Told_idx[0],ROB_FL_out_Told_idx[1],
                         FL_valid[0],FL_valid[1], 
                         T_idx[0],T_idx[1]);
    `ifdef DEBUG
    $display("######### DEBUG information ##########\n\
head:%0d next_head:%0d\n\
tail:%0d next_tail:%0d\n\
                    ",  head, next_head,
                        tail, next_tail);
	for (int i = 0; i < `NUM_FL_ENTRIES; i++) begin
        $display("FL_table[%0d] %d", i,FL_table[i]);
    end
    $display("#########################################################\n");
    `endif
end

task trigger_reset;
    @(negedge clock);
        reset = 1;
    @(negedge clock);
    @(negedge clock);
        reset = 0;
endtask


//////////////////////////////////////////////////////////////////////////////////////// driver ///////////////////////////////////////////////////////////////////////////////////
mailbox #(logic [$clog2(`NUM_PR_ENTRIES)-1:0]) T_mb1;
mailbox #(logic [$clog2(`NUM_PR_ENTRIES)-1:0]) T_mb2;
task drive;
    input rb_en;
    input [$clog2(`NUM_PR_ENTRIES)-1:0]    ROB2FL_out_T_idx;
    input dr_dispatch_en1, dr_dispatch_en2;
    input [4:0] dr_archdestreg1, dr_archdestreg2;
    input dr_retire_en1, dr_retire_en2;
    logic [$clog2(`NUM_PR_ENTRIES)-1:0] dr_retire_t1, dr_retire_t2;
    @(negedge clock) begin
        rollback_en = rb_en;
        ROB_FL_out_T_idx = ROB2FL_out_T_idx;
        dispatch_en[0] = dr_dispatch_en1;
        dispatch_en[1] = dr_dispatch_en2;
        decoder_FL_out_dest_idx[0] = dr_archdestreg1;
        decoder_FL_out_dest_idx[1] = dr_archdestreg2;
        retire_en[0] = dr_retire_en1;
        retire_en[1] = dr_retire_en2;
        if (retire_en[0]) T_mb1.try_get(dr_retire_t1);
        if (retire_en[1]) T_mb2.try_get(dr_retire_t2);
        ROB_FL_out_Told_idx[0] = dr_retire_t1;
        ROB_FL_out_Told_idx[1] = dr_retire_t2;
        if (dispatch_en[0]) T_mb1.put(T_idx[0]);
        if (dispatch_en[1]) T_mb2.put(T_idx[1]);
    end
    fork
        @(posedge clock) begin
        $display("############# Time:%0t input information: #############\n\
 rollback_en : %0d                       ROB_FL_out_T_idx : %0d\n \
 dispatch_en[0]:%0d                      dispatch_en[1]:%0d\n\
 retire_en[0]:%0d                        retire_en[1]:%0d\n\
 decoder_FL_out_dest_idx[0]:%0d          decoder_FL_out_dest_idx[1]:%0d\n\
 ROB_FL_out_Told_idx[0]:%0d              ROB_FL_out_Told_idx[1]:%0d\n\
#########################################################\n \
                ",$time, rollback_en, ROB_FL_out_T_idx,
                         dispatch_en[0],dispatch_en[1], 
                         retire_en[0],retire_en[1],
                         decoder_FL_out_dest_idx[0],decoder_FL_out_dest_idx[1],
                         ROB_FL_out_Told_idx[0],ROB_FL_out_Told_idx[1]);
        end
        @(posedge clock) $display("666",T_mb1.num(),T_mb2.num());
        @(posedge clock) begin
        $display("############# Time:%0t output information: #############\n\
 FL_valid[0]:%0d                      FL_valid[1]:%0d\n\
 T_idx[0]:%0d                         T_idx[1]:%0d\n\
#########################################################\n \
                ",$time, FL_valid[0],FL_valid[1], 
                         T_idx[0],T_idx[1]);
        end

    `ifdef DEBUG
    @(posedge clock) 
    $display("######### DEBUG information ##########\n\
head:%0d next_head:%0d\n\
tail:%0d next_tail:%0d\n\
                    ",  head, next_head,
                        tail, next_tail);
	for (int i = 0; i < `NUM_FL_ENTRIES; i++) begin
        $display("FL_table[%0d] %d", i,FL_table[i]);
    end
    $display("#########################################################\n");
    `endif

    join_none
endtask

  initial begin
    clock = 0;
    T_mb1 = new();
    T_mb2 = new();
    repeat (3) @(negedge clock);
    drive(0,0,1,1,1,2,0,0);
    drive(0,0,1,1,3,4,0,0);
    drive(0,0,1,0,5,6,0,0);
    drive(0,0,0,1,7,8,0,0);

    drive(0,0,1,1,9,10,1,1);
    drive(0,0,0,1,11,12,1,1);
    drive(0,0,1,0,13,14,1,1);
    drive(1,35,1,1,15,16,1,1);
    drive(1,38,1,1,19,15,1,1);
    // drive(0,0,1,1,9,10,0,0);
    // drive(0,0,1,1,9,10,0,0);
    
    @(negedge clock);

    @(negedge clock);
    $finish;

  end



endmodule

