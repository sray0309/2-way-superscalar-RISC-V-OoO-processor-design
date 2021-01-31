module rs_tb;

logic clock, reset;

//input
logic rs_enable, prega_ready_in, pregb_ready_in, rd_mem, wr_mem, cdb_valid;
ALU_FUNC alu_func;
INST inst_in;
logic [`PREG_IDX_WIDTH-1:0] prega_idx_in, pregb_idx_in, pdest_idx_in, cdb_tag;

//output
INST inst_out;
ALU_FUNC alu_func_out;
logic rd_mem_out, wr_mem_out, ALU_ready, MULT_ready, LSQ_ready, rs_full;
logic [`PREG_IDX_WIDTH-1:0] prega_idx_out, pregb_idx_out, pdest_idx_out;


//DEBUG signal
logic [`NUM_RS_ENTRIES-1:0] debug_entry_busy;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_sel;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_en;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_ALU_ready;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_LSQ_ready;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_MULT_ready;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_ALU_sel;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_LSQ_sel;
logic [`NUM_RS_ENTRIES-1:0] debug_entry_MULT_sel;
logic [`NUM_RS_ENTRIES-1:0] debug_prega_ready;
logic [`NUM_RS_ENTRIES-1:0] debug_pregb_ready;
logic [`NUM_RS_ENTRIES-1:0] debug_cdb_prega_ready;
logic [`NUM_RS_ENTRIES-1:0] debug_cdb_pregb_ready;

rs DUT(
    .clock(clock),
    .reset(reset),

    //input
    .rs_enable( rs_enable),
    .prega_idx_in( prega_idx_in),
    .pregb_idx_in( pregb_idx_in),
    .pdest_idx_in( pdest_idx_in),
    .prega_ready_in( prega_ready_in),
    .pregb_ready_in( pregb_ready_in),
    .alu_func( alu_func),
    .inst_in( inst_in),
    .rd_mem( rd_mem),
    .wr_mem( wr_mem),
    .cdb_valid( cdb_valid),
    .cdb_tag( cdb_tag),

    //output
    .inst_out( inst_out),
    .alu_func_out( alu_func_out),
    .prega_idx_out( prega_idx_out),
    .pregb_idx_out( pregb_idx_out),
    .pdest_idx_out(  pdest_idx_out),
    .rd_mem_out(  rd_mem_out),
    .wr_mem_out(  wr_mem_out),
    .ALU_ready(  ALU_ready),
    .LSQ_ready( LSQ_ready),
    .MULT_ready( MULT_ready),
    .rs_full( rs_full)

    `ifdef DEBUG
    ,
    .debug_entry_busy(debug_entry_busy),
    .debug_entry_en(debug_entry_en),
    .debug_entry_sel(debug_entry_sel),

    .debug_entry_ALU_ready(debug_entry_ALU_ready),
    .debug_entry_LSQ_ready(debug_entry_LSQ_ready),
    .debug_entry_MULT_ready(debug_entry_MULT_ready),

    .debug_entry_ALU_sel(debug_entry_ALU_sel),
    .debug_entry_LSQ_sel(debug_entry_LSQ_sel),
    .debug_entry_MULT_sel(debug_entry_MULT_sel),

    .debug_prega_ready(debug_prega_ready),
    .debug_pregb_ready(debug_pregb_ready),
    .debug_cdb_prega_ready(debug_cdb_prega_ready),
    .debug_cdb_pregb_ready(debug_cdb_pregb_ready)
    `endif
);


////////////////////////////////////////////////////// clock generation /////////////////////////////////////////////////////////////
always #5 clock = ~clock;

///////////////////////////////////////////////////// reset trigger /////////////////////////////////////////////////////////////
initial begin
    reset = 0;
    @(negedge clock); 
    reset = 1;
    @(negedge clock); 
    reset = 0;
    @(posedge clock);
    $display("######## Time:%0t RESET information: ########\n\
 prega_idx_out:%0d\n\
 pregb_idx_out:%0d\n\
 pdest_idx_out:%0d\n\
 wr_mem_out:%0d  rd_mem_out:%0d\n\
 ALU_ready:%0d MULT_ready:%0d LSQ_ready:%0d\n\
 alu_func_out:%0d\n\
 inst_out:%0d\n\
 rs_full:%0d\n\
#########################################################\n \
                ",$time, prega_idx_out, 
                         pregb_idx_out, 
                         pdest_idx_out, 
                         wr_mem_out, rd_mem_out,
                         ALU_ready, MULT_ready, LSQ_ready, 
                         alu_func_out, inst_out, rs_full);
    `ifdef DEBUG
     $display("######### DEBUG Reset information ##########\n\
entry_busy:%b entry_en:%b entry_sel:%b\n\
###########################################\n",debug_entry_busy,debug_entry_en,debug_entry_sel);
    `endif
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
task dispatch();
    input dp_rs_enable;
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
    if(dp_rs_full) fork
        @(posedge clock)
        $display("######## Time:%0t RS is full ########\n", $time);
    join_none
    else begin
        rs_enable = dp_rs_enable;
        prega_idx_in = dp_prega_idx_in;
        pregb_idx_in = dp_pregb_idx_in;
        pdest_idx_in = dp_pdest_idx_in;
        prega_ready_in = dp_prega_ready_in;
        pregb_ready_in = dp_pregb_ready_in;
        wr_mem = dp_wr_mem;
        rd_mem = dp_rd_mem;
        inst_in = dp_inst;
        alu_func = dp_alu_func;
        fork
        @(posedge clock) begin
        $display("######## Time:%0t Dispatch instruction information: ########\n\
 rs_enable:%0d\n\
 prega_ready_in:%0d  prega_idx_in:%0d\n\
 pregb_ready_in:%0d  pregb_idx_in:%0d\n\
 pdest_idx_in:%0d\n\
 wr_mem_in:%0d  rd_mem_in:%0d\n\
 alu_func_in:%0d\n\
 inst_in:%0d\n\
 rs_full:%0d\n\
##########################################################\n \
                ",$time, rs_enable, 
                        prega_ready_in, prega_idx_in, 
                        pregb_ready_in, pregb_idx_in,
                        pdest_idx_in, 
                        wr_mem, rd_mem, 
                        alu_func, 
                        inst_in, 
                        dp_rs_full
                        );
        `ifdef DEBUG
            $display("################## Time:%0t Dispatch debug ################\n\
 entry_busy:%b entry_en:%b entry_sel:%b\n\
############################################################\n",
        $time,debug_entry_busy,debug_entry_en,debug_entry_sel);
        `endif
        end
        join_none
    end
endtask


//////////////////////////////////////////// complete stage CBD signal ///////////////////////////////////////////
task complete();
    input cp_cdb_valid;
    input [`PREG_IDX_WIDTH] cp_cdb_tag;
    begin
        cdb_valid = cp_cdb_valid;
        cdb_tag = cp_cdb_tag;
        fork
        @(posedge clock)
        $display("######## Time:%0t Complete broadcast information: ########\n\
 cdb_valid:%0d\n\
 cdb_tag:%0d\n\
##########################################################\n \
                ",$time, cdb_valid, cdb_tag);
        join_none
    end
endtask

//////////////////////////////////////// monite issue stage(monitor) /////////////////////////////////////////////////////////
// typedef struct packed{
//     bit [`PREG_IDX_WIDTH] is_prega_idx_out;
//     bit [`PREG_IDX_WIDTH] is_pregb_idx_out;
//     bit [`PREG_IDX_WIDTH] is_pdest_idx_out;
//     INST is_inst;
//     ALU_FUNC is_alu_func;
//     bit is_rd_mem;
//     bit is_wr_mem;
//     bit is_ALU_ready;
//     bit is_MULT_ready;
//     bit is_LSQ_ready;
//     bit is_rs_full;
// } RS_OUT;

task rs_out_monitor();
    fork
    @(posedge clock) begin
    $display("######## Time:%0t Issue instruction information: ########\n\
 prega_idx_out:%0d\n\
 pregb_idx_out:%0d\n\
 pdest_idx_out:%0d\n\
 wr_mem_out:%0d  rd_mem_out:%0d\n\
 ALU_ready:%0d MULT_ready:%0d LSQ_ready:%0d\n\
 alu_func_out:%0d\n\
 inst_out:%0d\n\
 rs_full:%0d\n\
#########################################################\n \
                ",$time, prega_idx_out, 
                         pregb_idx_out, 
                         pdest_idx_out, 
                         wr_mem, rd_mem,
                         ALU_ready, MULT_ready, LSQ_ready, 
                         alu_func, inst_out, rs_full);

    `ifdef DEBUG
            $display("#################### Time:%0t Issue debug ###################\n\
 entry_busy:%b entry_en:%b entry_sel:%b\n\
 entry_ALU_ready:%b entry_LSQ_ready:%b entry_MULT_ready:%b\n\
 entry_ALU_sel:%b entry_LSQ_sel:%b entry_MULT_sel:%b\n\
 prega_ready:%b pregb_ready:%b cdb_prega_ready:%b cdb_pregb_ready:%b\n\
############################################################\n",
        $time,
        debug_entry_busy,debug_entry_en,debug_entry_sel,
        debug_entry_ALU_ready,debug_entry_LSQ_ready,debug_entry_MULT_ready,
        debug_entry_ALU_sel,debug_entry_LSQ_sel,debug_entry_MULT_sel,
        debug_prega_ready,debug_pregb_ready,debug_cdb_prega_ready,debug_cdb_pregb_ready);
    `endif
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
    repeat(20) begin
        pra_t = $urandom_range(0,32);
        prb_t = $urandom_range(0,32);
        pd_t = $urandom_range(0,32);
        inst_t = $urandom_range(0,5000);
        alu_func_t = $urandom_range(0,11);
        @(negedge clock);
        begin
            complete(0,0);
            rs_out_monitor();
            dispatch(1,1,pra_t,1,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
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
            complete(0,0);
            rs_out_monitor();
            dispatch(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
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

task insert_unvalid_inst(input a_ready, input b_ready);
    @(negedge clock);
    begin
        complete(0,0);
        dispatch(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
    end
endtask

integer i,k;
task test_every_entry();
    i = 0;
    repeat(`NUM_RS_ENTRIES) begin
    constant_test(i);
    insert_unvalid_inst(0,0);
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
            dispatch(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            complete(0,0);
            rs_out_monitor();
            end
            i++;
        end
        repeat(`NUM_RS_ENTRIES) begin
            i--;
            @(negedge clock);
            begin
            dispatch(0,0,0,0,0,0,0,0,0,0,rs_full);
            complete(1,i);
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
            dispatch(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            complete(0,0);
            rs_out_monitor();
            end
            i++;k++;
        end
        repeat(`NUM_RS_ENTRIES) begin
            i--;
            @(negedge clock);
            begin
            dispatch(0,0,0,0,0,0,0,0,0,0,rs_full);
            complete(1,i);
            rs_out_monitor();
            end
        end
        repeat(`NUM_RS_ENTRIES) begin
            k--;
            @(negedge clock);
            begin
            dispatch(0,0,0,0,0,0,0,0,0,0,rs_full);
            complete(1,k);
            rs_out_monitor();
            end
        end
    end
endtask

/////////////////////////////////////////// testbench /////////////////////////////////////////////////////////////
initial begin
    $display("########### Start RS testing ############");
    clock = 0;
    rs_enable = 0;
    @(negedge clock);
    // test_every_entry();
    // trigger_reset();
    // full_test();
    // trigger_reset();
    cdb_test(0,1);
    // trigger_reset();
    // cdb_test(1,0);
    // trigger_reset();
    // cdb_test(0,0);
    @(negedge clock);
    $finish;
end


endmodule