module superrs_tb;

logic clock, reset;

//input
DP_RS_PACKET [`SCALAR_WIDTH-1:0] rs_packet_in;
logic [`SCALAR_WIDTH-1:0] cdb_valid;
logic [`SCALAR_WIDTH-1:0] [`PREG_IDX_WIDTH-1:0] cdb_tag;
 
//output
RS_IS_PACKET [`SCALAR_WIDTH-1:0] rs_packet_out;
logic [`SCALAR_WIDTH-1:0] rs_full;

rs_super DUT(
    .clock(clock),
    .reset(reset),

    //input
    .rs_packet_in(rs_packet_in),
    .cdb_valid( cdb_valid),
    .cdb_tag( cdb_tag),

    //output
    .rs_packet_out(rs_packet_out),
    .rs_full( rs_full)
);


////////////////////////////////////////////////////// clock generation /////////////////////////////////////////////////////////////
always #5 clock = ~clock;

///////////////////////////////////////////////////// reset trigger /////////////////////////////////////////////////////////////
initial begin
    reset = 0;
    @(negedge clock); 
    reset = 1;
    rs_packet_in = 0;
    cdb_valid = 0;
    cdb_tag = 0;
    @(negedge clock); 
    reset = 0;
    @(posedge clock);
    $display("######## Time:%0t RESET information: ########\n\
 prega_idx_out[0]:%0d prega_idx_out[1]:%0d\n\
 pregb_idx_out[0]:%0d pregb_idx_out[1]:%0d\n\
 pdest_idx_out[0]:%0d pdest_idx_out[1]:%0d\n\
 wr_mem_out[0]:%0d    wr_mem_out[1]:%0d\n\
 rd_mem_out[0]:%0d    rd_mem_out[1]:%0d\n\
 ALU_ready[0]:%0d     ALU_ready[1]:%0d\n\
 MULT_ready[0]:%0d    MULT_ready[1]:%0d\n\
 LSQ_ready[0]:%0d     LSQ_ready[1]:%0d\n\
 alu_func_out[0]:%0d  alu_func_out[1]:%0d\n\
 inst_out[0]:%0d      inst_out[1]:%0d\n\
 rs_full[0]:%0d       rs_full[1]:%0d\n\
#########################################################\n \
                ",$time, rs_packet_out[0].prega_idx,rs_packet_out[1].prega_idx, 
                         rs_packet_out[0].pregb_idx,rs_packet_out[1].pregb_idx,
                         rs_packet_out[0].pdest_idx,rs_packet_out[1].pdest_idx,
                         rs_packet_out[0].wr_mem,rs_packet_out[1].wr_mem,
                         rs_packet_out[0].rd_mem,rs_packet_out[1].rd_mem,
                         rs_packet_out[0].ALU_ready,rs_packet_out[1].ALU_ready, 
                         rs_packet_out[0].MULT_ready,rs_packet_out[1].MULT_ready,
                         rs_packet_out[0].LSQ_ready,rs_packet_out[1].LSQ_ready, 
                         rs_packet_out[0].alu_func,rs_packet_out[1].alu_func,
                         rs_packet_out[0].inst,rs_packet_out[1].inst,
                         rs_full[0],rs_full[1]);
     $display("###########  Finish reset ###############\n");
end

task trigger_reset();
    @(negedge clock);
    reset = 1;
    @(negedge clock);
    @(negedge clock);
    reset = 0;
endtask

//////////////////////////////////////// dispatch instruction(driver) ///////////////////////////////////////////////
task dispatch_0();
    input dp_inst_valid;
    input dp_prega_ready_in;
    input [`PREG_IDX_WIDTH-1:0] dp_prega_idx_in;
    input dp_pregb_ready_in;
    input [`PREG_IDX_WIDTH-1:0] dp_pregb_idx_in;
    input [`PREG_IDX_WIDTH-1:0] dp_pdest_idx_in;
    input dp_wr_mem;
    input dp_rd_mem;
    input ALU_FUNC dp_alu_func;
    input INST dp_inst;
    input dp_rs_full;
    // if(dp_rs_full) fork
    //     @(posedge clock)
    //     $display("######## Time:%0t RS is full ########\n", $time);
    // join_none
    // else 
    begin
        rs_packet_in[0].valid = dp_inst_valid;
        rs_packet_in[0].prega_idx = dp_prega_idx_in;
        rs_packet_in[0].pregb_idx = dp_pregb_idx_in;
        rs_packet_in[0].pdest_idx = dp_pdest_idx_in;
        rs_packet_in[0].prega_ready = dp_prega_ready_in;
        rs_packet_in[0].pregb_ready = dp_pregb_ready_in;
        rs_packet_in[0].wr_mem = dp_wr_mem;
        rs_packet_in[0].rd_mem = dp_rd_mem;
        rs_packet_in[0].inst = dp_inst;
        rs_packet_in[0].alu_func = dp_alu_func;
        fork
        @(posedge clock) begin
        $display("######## Time:%0t Dispatch instruction to RS[0] information: ########\n\
 inst_valid[0]:%0d\n\
 prega_ready_in[0]:%0d  prega_idx_in[0]:%0d\n\
 pregb_ready_in[0]:%0d  pregb_idx_in[0]:%0d\n\
 pdest_idx_in[0]:%0d\n\
 wr_mem_in[0]:%0d\n\
 rd_mem_in[0]:%0d\n\
 alu_func_in[0]:%0d\n\
 inst_in[0]:%0d\n\
 rs_full[0]:%0d\n\
##########################################################\n\
                ",$time,
                rs_packet_in[0].valid,
                rs_packet_in[0].prega_ready,rs_packet_in[0].prega_idx,
                rs_packet_in[0].pregb_ready,rs_packet_in[0].pregb_idx,
                rs_packet_in[0].pdest_idx,
                rs_packet_in[0].wr_mem,
                rs_packet_in[0].rd_mem,
                rs_packet_in[0].alu_func,
                rs_packet_in[0].inst,
                rs_full[0]);
        end
        join_none
    end
endtask

task dispatch_1();
    input dp_inst_valid;
    input dp_prega_ready_in;
    input [`PREG_IDX_WIDTH-1:0] dp_prega_idx_in;
    input dp_pregb_ready_in;
    input [`PREG_IDX_WIDTH-1:0] dp_pregb_idx_in;
    input [`PREG_IDX_WIDTH-1:0] dp_pdest_idx_in;
    input dp_wr_mem;
    input dp_rd_mem;
    input ALU_FUNC dp_alu_func;
    input INST dp_inst;
    input dp_rs_full;
    // if(dp_rs_full) fork
    //     @(posedge clock)
    //     $display("######## Time:%0t RS is full ########\n", $time);
    // join_none
    // else 
    begin
        rs_packet_in[1].valid = dp_inst_valid;
        rs_packet_in[1].prega_idx = dp_prega_idx_in;
        rs_packet_in[1].pregb_idx = dp_pregb_idx_in;
        rs_packet_in[1].pdest_idx = dp_pdest_idx_in;
        rs_packet_in[1].prega_ready = dp_prega_ready_in;
        rs_packet_in[1].pregb_ready = dp_pregb_ready_in;
        rs_packet_in[1].wr_mem = dp_wr_mem;
        rs_packet_in[1].rd_mem = dp_rd_mem;
        rs_packet_in[1].inst = dp_inst;
        rs_packet_in[1].alu_func = dp_alu_func;
        fork
        @(posedge clock) begin
        $display("######## Time:%0t Dispatch instruction to RS[1] information: ########\n\
 inst_valid[1]:%0d\n\
 prega_ready_in[1]:%0d  prega_idx_in[1]:%0d\n\
 pregb_ready_in[1]:%0d  pregb_idx_in[1]:%0d\n\
 pdest_idx_in[1]:%0d\n\
 wr_mem_in[1]:%0d\n\
 rd_mem_in[1]:%0d\n\
 alu_func_in[1]:%0d\n\
 inst_in[1]:%0d\n\
 rs_full[1]:%0d\n\
##########################################################\n\
                ",$time,
                rs_packet_in[1].valid,
                rs_packet_in[1].prega_ready,rs_packet_in[1].prega_idx,
                rs_packet_in[1].pregb_ready,rs_packet_in[1].pregb_idx,
                rs_packet_in[1].pdest_idx,
                rs_packet_in[1].wr_mem,
                rs_packet_in[1].rd_mem,
                rs_packet_in[1].alu_func,
                rs_packet_in[1].inst,
                rs_full[1]);
        end
        join_none
    end
endtask


//////////////////////////////////////////// complete stage CDB signal ///////////////////////////////////////////
task complete_0();
    input cp_cdb_valid;
    input [`PREG_IDX_WIDTH-1:0] cp_cdb_tag;
    begin
        cdb_valid[0] = cp_cdb_valid;
        cdb_tag[0] = cp_cdb_tag;
        fork
        @(posedge clock)
        $display("######## Time:%0t CDB[0] broadcast information: ########\n\
 cdb_valid[0]:%0d\n\
 cdb_tag[0]:%0d\n\
##########################################################\n \
                ",$time, cdb_valid[0],cdb_tag[0]);
        join_none
    end
endtask

task complete_1();
    input cp_cdb_valid;
    input [`PREG_IDX_WIDTH-1:0] cp_cdb_tag;
    begin
        cdb_valid[1] = cp_cdb_valid;
        cdb_tag[1] = cp_cdb_tag;
        fork
        @(posedge clock)
        $display("######## Time:%0t CDB[1] broadcast information: ########\n\
 cdb_valid[1]:%0d\n\
 cdb_tag[1]:%0d\n\
##########################################################\n \
                ",$time, cdb_valid[1],cdb_tag[1]);
        join_none
    end
endtask

//////////////////////////////////////// monite issue stage(monitor) /////////////////////////////////////////////////////////

task rs_out_monitor();
    fork
    @(posedge clock) begin
    $display("######## Time:%0t Issue information: ########\n\
 prega_idx_out[0]:%0d prega_idx_out[1]:%0d\n\
 pregb_idx_out[0]:%0d pregb_idx_out[1]:%0d\n\
 pdest_idx_out[0]:%0d pdest_idx_out[1]:%0d\n\
 wr_mem_out[0]:%0d    wr_mem_out[1]:%0d\n\
 rd_mem_out[0]:%0d    rd_mem_out[1]:%0d\n\
 ALU_ready[0]:%0d     ALU_ready[1]:%0d\n\
 MULT_ready[0]:%0d    MULT_ready[1]:%0d\n\
 LSQ_ready[0]:%0d     LSQ_ready[1]:%0d\n\
 alu_func_out[0]:%0d  alu_func_out[1]:%0d\n\
 inst_out[0]:%0d      inst_out[1]:%0d\n\
 rs_full[0]:%0d       rs_full[1]:%0d\n\
#########################################################\n \
                ",$time, rs_packet_out[0].prega_idx,rs_packet_out[1].prega_idx, 
                         rs_packet_out[0].pregb_idx,rs_packet_out[1].pregb_idx,
                         rs_packet_out[0].pdest_idx,rs_packet_out[1].pdest_idx,
                         rs_packet_out[0].wr_mem,rs_packet_out[1].wr_mem,
                         rs_packet_out[0].rd_mem,rs_packet_out[1].rd_mem,
                         rs_packet_out[0].ALU_ready,rs_packet_out[1].ALU_ready, 
                         rs_packet_out[0].MULT_ready,rs_packet_out[1].MULT_ready,
                         rs_packet_out[0].LSQ_ready,rs_packet_out[1].LSQ_ready, 
                         rs_packet_out[0].alu_func,rs_packet_out[1].alu_func,
                         rs_packet_out[0].inst,rs_packet_out[1].inst,
                         rs_full[0],rs_full[1]);
    end
    join_none
endtask

/////////////////////////////////////////////////// test case //////////////////////////////////////////////////////////////
/* 
Dispatch order: rs_enable, prega_ready_in, prega_idx_in, pregb_ready_in, pregb_idx_in,pdest_idx_in, wr_mem, rd_mem, alu_func, inst_in, dp_rs_full 
Complete order: cdb_valid, cdb_tag
Issue order: mon_prega_idx_out, mon_pregb_idx_out, mon_pdest_idx_out, mon_wr_mem, mon_rd_mem,mon_ALU_ready, mon_MULT_ready, mon_LSQ_ready, mon_alu_func, mon_inst, mon_rs_full
*/

bit [`PREG_IDX_WIDTH-1:0] pra_t, prb_t, pd_t;
INST inst_t;
ALU_FUNC alu_func_t;
task constant_test(input integer entry_idx);
     $display("##################################################################################\n\
################ constantly dispatch and issue for entry %0d #####################\n\
##################################################################################\n",entry_idx);
    repeat(10) begin
        pra_t = $urandom_range(0,32);
        prb_t = $urandom_range(0,32);
        pd_t = $urandom_range(0,32);
        inst_t = $urandom_range(0,5000);
        alu_func_t = $urandom_range(0,11);
        @(negedge clock);
        begin
            complete_0(0,0);
            complete_1(0,0);
            rs_out_monitor();
            dispatch_0(1,1,pra_t,1,prb_t,pd_t,0,0,alu_func_t,inst_t,rs_full);
            dispatch_1(1,1,pra_t,1,prb_t,pd_t,0,0,alu_func_t,inst_t,rs_full);
        end
    end
endtask

task fully_insert(input a_ready, input b_ready);
    repeat(`NUM_RS_ENTRIES) begin
        pra_t = $urandom_range(0,32);
        prb_t = $urandom_range(0,32);
        pd_t = $urandom_range(0,32);
        inst_t = $urandom_range(0,5000);
        alu_func_t = $urandom_range(0,11);
        @(negedge clock);
        begin
            complete_0(0,0);
            complete_1(0,0);
            rs_out_monitor();
            dispatch_0(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            dispatch_1(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
        end
    end
    @(negedge clock);
endtask

task full_test();
$display("############################################################################\n\
################ test if PR1 or PR2 can fill up the RS #####################\n\
############################################################################\n");
    fully_insert(0,1);
    if(rs_full) trigger_reset();
    else begin
        $error("############ Tims:%0t: Insert %0d insts with pr1 NOT ready while RS is not full ##############",$time,`NUM_RS_ENTRIES);
    end
    fully_insert(1,0);
    if(rs_full) trigger_reset();
    else begin
        $error("############ Tims:%0t: Insert %0d insts with pr2 NOT ready while RS is not full ##############",$time,`NUM_RS_ENTRIES);
    end
    fully_insert(0,0);
    if(rs_full) trigger_reset();
    else begin
        $error("############ Tims:%0t: Insert %0d insts with both pr1 and pr2 NOT ready while RS is not full ##############",$time,`NUM_RS_ENTRIES);
    end
endtask

task insert_unvalid_inst_0();
    input a_ready;
    input b_ready;
    @(negedge clock);
    begin
        complete_0(0,0);
        dispatch_0(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
    end
endtask

task insert_unvalid_inst_1();
    input a_ready;
    input b_ready;
    @(negedge clock);
    begin
        complete_1(0,0);
        dispatch_1(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
    end
endtask

integer i,k;
task test_every_entry();
    i = 0;
    repeat(`NUM_RS_ENTRIES) begin
    constant_test(i);
    insert_unvalid_inst_0(0,0);
    insert_unvalid_inst_1(0,0);
    i++;
    end
    trigger_reset();
endtask

task cdb_test(input a_ready, input b_ready);
    if (a_ready | b_ready) begin
        i=1;
        repeat(`NUM_RS_ENTRIES) begin
        @(negedge clock);
            pra_t = i;
            prb_t = $urandom_range(0,31);
            pd_t = $urandom_range(0,31);
            inst_t = $urandom_range(0,5000);
            alu_func_t = $urandom_range(0,11);
            begin
            dispatch_0(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            dispatch_1(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            complete_0(0,0);
            complete_1(0,0);
            rs_out_monitor();
            end
            i++;
        end
        repeat(`NUM_RS_ENTRIES) begin
            i--;
            @(negedge clock);
            begin
            dispatch_0(0,0,0,0,0,0,0,0,0,0,rs_full);
            dispatch_1(0,0,0,0,0,0,0,0,0,0,rs_full);
            $display("rui%0d",i);
            complete_0(1,i);
            complete_1(1,i);
            rs_out_monitor();
            end
        end
    end
    else begin
        i=1;k=10;
        repeat(`NUM_RS_ENTRIES) begin
        @(negedge clock);
            pra_t = i;
            prb_t = k;
            pd_t = $urandom_range(0,31);
            inst_t = $urandom_range(0,5000);
            alu_func_t = $urandom_range(0,11);
            begin
            dispatch_0(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            dispatch_1(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            complete_0(0,0);
            complete_1(0,0);
            rs_out_monitor();
            end
            i++;k++;
        end
        repeat(`NUM_RS_ENTRIES) begin
            i--;
            @(negedge clock);
            begin
            dispatch_0(0,0,0,0,0,0,0,0,0,0,rs_full);
            dispatch_1(0,0,0,0,0,0,0,0,0,0,rs_full);
            complete_0(1,i);
            complete_1(1,i);
            rs_out_monitor();
            end
        end
        repeat(`NUM_RS_ENTRIES) begin
            k--;
            @(negedge clock);
            begin
            dispatch_0(0,0,0,0,0,0,0,0,0,0,rs_full);
            dispatch_1(0,0,0,0,0,0,0,0,0,0,rs_full);
            complete_0(1,k);
            complete_1(1,k);
            rs_out_monitor();
            end
        end
    end
endtask

/////////////////////////////////////////// testbench /////////////////////////////////////////////////////////////
initial begin
    $display("########### Start RS testing ############");
    clock = 0;
    repeat(3) @(negedge clock);
    constant_test(1);
    repeat(20) begin
    test_every_entry();
    trigger_reset();
    full_test();
    trigger_reset();
    cdb_test(0,1);
    trigger_reset();
    cdb_test(1,0);
    trigger_reset();
    cdb_test(0,0);
    end
    @(negedge clock);
    $finish;
end


endmodule