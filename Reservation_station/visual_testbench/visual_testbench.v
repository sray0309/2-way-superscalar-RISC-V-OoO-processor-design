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

extern void initcurses(int,int,int,int);
extern void flushpipe();
extern void waitforresponse();
extern void initmem();
extern int get_instr_at_pc(int);
extern int not_valid_pc(int);

module testbench();

	logic [31:0] clock_count;

    // Testbench parameters
    parameter VERILOG_CLOCK_PERIOD      = 5;

    // Registers and wires used in the testbench
    logic clock, reset;

    //input
    logic [`SCALAR_WIDTH-1:0] prega_ready_in, pregb_ready_in, rd_mem, wr_mem, cdb_valid, inst_valid;
    ALU_FUNC [`SCALAR_WIDTH-1:0] alu_func;
    INST [`SCALAR_WIDTH-1:0] inst_in;
    logic [`SCALAR_WIDTH-1:0] [`PREG_IDX_WIDTH-1:0] prega_idx_in, pregb_idx_in, pdest_idx_in, cdb_tag;

    //output
    INST [`SCALAR_WIDTH-1:0] inst_out;
    ALU_FUNC [`SCALAR_WIDTH-1:0] alu_func_out;
    logic [`SCALAR_WIDTH-1:0] rd_mem_out, wr_mem_out, ALU_ready, MULT_ready, LSQ_ready, rs_full;
    logic [`SCALAR_WIDTH-1:0] [`PREG_IDX_WIDTH-1:0] prega_idx_out, pregb_idx_out, pdest_idx_out;

    //counter used for when pipeline infinite loops, forces termination
    logic [63:0] debug_counter;
	// Instantiate the Pipeline
    rs_super DUT(
        .clock(clock),
        .reset(reset),

        //input
        .prega_idx_in( prega_idx_in),
        .pregb_idx_in( pregb_idx_in),
        .pdest_idx_in( pdest_idx_in),
        .prega_ready_in( prega_ready_in),
        .pregb_ready_in( pregb_ready_in),
        .alu_func( alu_func),
        .inst_in( inst_in),
        .inst_valid(inst_valid),
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

    );

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
        begin
            inst_valid[0] = dp_inst_valid;
            prega_idx_in[0] = dp_prega_idx_in;
            pregb_idx_in[0] = dp_pregb_idx_in;
            pdest_idx_in[0] = dp_pdest_idx_in;
            prega_ready_in[0] = dp_prega_ready_in;
            pregb_ready_in[0] = dp_pregb_ready_in;
            wr_mem[0] = dp_wr_mem;
            rd_mem[0] = dp_rd_mem;
            inst_in[0] = dp_inst;
            alu_func[0] = dp_alu_func;
            fork
            @(posedge clock) begin
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
        begin
            inst_valid[1] = dp_inst_valid;
            prega_idx_in[1] = dp_prega_idx_in;
            pregb_idx_in[1] = dp_pregb_idx_in;
            pdest_idx_in[1] = dp_pdest_idx_in;
            prega_ready_in[1] = dp_prega_ready_in;
            pregb_ready_in[1] = dp_pregb_ready_in;
            wr_mem[1] = dp_wr_mem;
            rd_mem[1] = dp_rd_mem;
            inst_in[1] = dp_inst;
            alu_func[1] = dp_alu_func;
            fork
            @(posedge clock);
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
            @(posedge clock);
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
            @(posedge clock);
            join_none
        end
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
                dispatch_0(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
                dispatch_1(1,a_ready,pra_t,b_ready,prb_t,1,0,0,alu_func_t,inst_t,rs_full);
            end
        end
        @(negedge clock);
    endtask

    task full_test();
        fully_insert(0,1);
        if(rs_full) trigger_reset();
        else begin
        end
        fully_insert(1,0);
        if(rs_full) trigger_reset();
        else begin
        end
        fully_insert(0,0);
        if(rs_full) trigger_reset();
        else begin
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
                end
                i++;
            end
            repeat(`NUM_RS_ENTRIES) begin
                i--;
                @(negedge clock);
                begin
                dispatch_0(0,0,0,0,0,0,0,0,0,0,rs_full);
                dispatch_1(0,0,0,0,0,0,0,0,0,0,rs_full);
                complete_0(1,i);
                complete_1(1,i);
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
                end
            end
        end
    endtask


    // Generate System Clock
    always
    begin
        #(VERILOG_CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    // Count the number of posedges and number of instructions completed
    // till simulation ends
    always @(posedge clock)
    begin
        if(reset)
        begin
        clock_count <= `SD 0;
        end
        else
        begin
        clock_count <= `SD (clock_count + 1);
        end
    end  

    initial
    begin
        clock = 0;
        reset = 0;

        // Call to initialize visual debugger
        // *Note that after this, all stdout output goes to visual debugger*
        // each argument is number of registers/signals for the group
        // (IF, IF/ID, ID, ID/EX, EX, EX/MEM, MEM, MEM/WB, WB, Misc)
        //
        // (Input, Output)
        initcurses(10,10,9,9);

        // Pulse the reset signal
        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);

        @(posedge clock);
        @(posedge clock);
        `SD;
        // This reset is at an odd time to avoid the pos & neg clock edges

        prega_idx_in = 0;
        pregb_idx_in = 0;
        pdest_idx_in = 0;
        prega_ready_in = 0;
        pregb_ready_in = 0;
        alu_func = 0;
        inst_in = 0;
        inst_valid = 0;
        rd_mem = 0;
        wr_mem = 0;
        cdb_valid = 0;
        cdb_tag = 0;
        reset = 0;
        @(posedge clock);


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

    always @(negedge clock)
    begin
        if(!reset)
        begin
        `SD;
        `SD;

        // deal with any halting conditions
        //if(pipeline_error_status!=NO_ERROR)
        //begin
        #100
        $display("\nDONE\n");
        waitforresponse();
        flushpipe();
        $finish;
        //end

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
        
        // Dump interesting register/signal contents onto stdout
        // format is "<reg group prefix><name> <width in hex chars>:<data>"
        // Current register groups (and prefixes) are:
        // f: IF   d: ID   e: EX   m: MEM    w: WB  v: misc. reg
        // g: IF/ID   h: ID/EX  i: EX/MEM  j: MEM/WB

        // Input signals (24) - prefix 'i'
        $display("iprega_idx_in[0] 5:%h",        prega_idx_in[0]);
        $display("ipregb_idx_in[0] 5:%h",        pregb_idx_in[0]);
        $display("ipdest_idx_in[0] 5:%h",        pdest_idx_in[0]);
        $display("iprega_ready_in[0] 1:%h",      prega_ready_in[0]);
        $display("ipregb_ready_in[0] 1:%h",      pregb_ready_in[0]);
        //$display("ialu_func_0 1:%h",            alu_func[0]);
        //$display("iinst_in_0 1:%h",             inst_in[0]);
        $display("iinst_valid[0] 1:%h",          inst_valid[0]);
        $display("ird_mem[0] 1:%h",              rd_mem[0]);
        $display("iwr_mem[0] 1:%h",              wr_mem[0]);
        $display("icdb_valid[0] 1:%h",           cdb_valid[0]);
        $display("icdb_tag[0] 5:%h",             cdb_tag[0]);

        $display("kprega_idx_in[1] 5:%h",        prega_idx_in[1]);
        $display("kpregb_idx_in[1] 5:%h",        pregb_idx_in[1]);
        $display("kpdest_idx_in[1] 5:%h",        pdest_idx_in[1]);
        $display("kprega_ready_in[1] 1:%h",      prega_ready_in[1]);
        $display("kpregb_ready_in[1] 1:%h",      pregb_ready_in[1]);
        //$display("ialu_func_1 1:%h",            alu_func[1]);
        //$display("iinst_in_1 1:%h",             inst_in[1]);
        $display("kinst_valid[1] 1:%h",          inst_valid[1]);
        $display("krd_mem[1] 1:%h",              rd_mem[1]);
        $display("kwr_mem[1] 1:%h",              wr_mem[1]);
        $display("kcdb_valid[1] 1:%h",           cdb_valid[1]);
        $display("kcdb_tag[1] 5:%h",             cdb_tag[1]);

        
        // Output signals (22) - prefix 'o'
        //$display("oinst_out",                   prega_idx_in[0]);
        //$display("oalu_func_out",               pregb_idx_in[0]);
        $display("oprega_idx_out[0] 5:%h",       pdest_idx_out[0]);
        $display("opregb_idx_out[0] 5:%h",       prega_idx_out[0]);
        $display("opdest_idx_out[0] 5:%h",       pregb_idx_out[0]);
        $display("ord_mem_out[0] 1:%h"   ,       rd_mem_out[0]);
        $display("owr_mem_out[0] 1:%h"   ,       wr_mem_out[0]);
        $display("oALU_ready[0] 1:%h"    ,       ALU_ready[0]);
        $display("oLSQ_ready[0] 1:%h"    ,       LSQ_ready[0]);
        $display("oMULT_ready[0] 1:%h"   ,       MULT_ready[0]);
        $display("ors_full[0] 1:%h"      ,       rs_full[0]);

        //$display("oinst_out",                   prega_idx_in[1]);
        //$display("oalu_func_out",               pregb_idx_in[1]);
        $display("lprega_idx_out[1] 5:%h",       pdest_idx_out[1]);
        $display("lpregb_idx_out[1] 5:%h",       prega_idx_out[1]);
        $display("lpdest_idx_out[1] 5:%h",       pregb_idx_out[1]);
        $display("lrd_mem_out[1] 1:%h"   ,       rd_mem_out[1]);
        $display("lwr_mem_out[1] 1:%h"   ,       wr_mem_out[1]);
        $display("lALU_ready[1] 1:%h"    ,       ALU_ready[1]);
        $display("lLSQ_ready[1] 1:%h"    ,       LSQ_ready[1]);
        $display("lMULT_ready[1] 1:%h"   ,       MULT_ready[1]);
        $display("lrs_full[1] 1:%h"      ,       rs_full[1]);

        // must come last
        $display("break");

        // This is a blocking call to allow the debugger to control when we
        // advance the simulation
        waitforresponse();
    end
endmodule