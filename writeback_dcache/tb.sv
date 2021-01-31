module dcache_tb;

    logic clock;
    logic reset;
    //FROM MEM
    logic [$clog2(`NUM_MEM_TAGS)-1:0] mem2proc_response;
    logic [`DATA_SIZE-1:0] mem2proc_data;
    logic [$clog2(`NUM_MEM_TAGS)-1:0] mem2proc_tag;
    //FROM LSQ
    logic [31:0] proc2Dcache_addr;
    logic [`DATA_SIZE-1:0] proc2Dcache_data;
    logic rd_mem;
    logic wr_mem;
    logic [2:0] proc2Dmem_size;

    // TO MEM
    BUS_COMMAND proc2mem_command;
    logic [31:0] proc2mem_addr;
    logic [`DATA_SIZE-1:0] proc2mem_data;
    //TO LSQ
    logic [31:0] data2lsq;
    logic wr_valid_o;
    logic rd_valid_o;
    
    dcache_top DUT(
        .clock(clock),
        .reset(reset),
        .mem2proc_response(mem2proc_response),
        .mem2proc_data(mem2proc_data),
        .mem2proc_tag(mem2proc_tag),
        .proc2Dmem_size(proc2Dmem_size),
        .proc2Dcache_addr(proc2Dcache_addr),
        .proc2Dcache_data(proc2Dcache_data),
        .rd_mem(rd_mem),
        .wr_mem(wr_mem),
        .proc2mem_command(proc2mem_command),
        .proc2mem_addr(proc2mem_addr),
        .proc2mem_data(proc2mem_data),
        .data2lsq(data2lsq),
        .wr_valid_o(wr_valid_o),
        .rd_valid_o(rd_valid_o)
    );

    ///////////////////////////////////////////////////////// clock generation /////////////////////////////////////////////////////////
    always #5 clock = ~clock;
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////// reset trigger //////////////////////////////////////////////////////////
    initial begin 
        reset = 0;
        @(negedge clock);
        reset = 1;
        mem2proc_response = 0;
        mem2proc_data = 0;
        mem2proc_tag = 0;
        proc2Dcache_addr = 0;
        proc2Dcache_data = 0;
        rd_mem = 0;
        wr_mem = 0;
        proc2Dmem_size = 0;
        @(negedge clock);
        reset = 0;
        $display("############## Time:%0t RESET information: ##############\n\
 mem2proc_response:%0d      mem2proc_data:%0d      mem2proc_tag:%0d\n\
 proc2Dcache_addr:%0d       proc2Dcache_data:%0d\n\
 rd_mem:%0d                 wr_mem:%0d\n\
 proc2Dmem_size:%0d\n\
 proc2mem_command:%0d       proc2mem_addr:%0d      proc2mem_data:%0d\n\
 data2lsq:%0d\n\
 wr_valid_o:%0d              rd_valid_o:%0d\n\
#########################################################\n \
                ",$time, mem2proc_response, mem2proc_data,mem2proc_tag,
                proc2Dcache_addr, proc2Dcache_data,
                rd_mem, wr_mem,
                proc2Dmem_size,
                proc2mem_command, proc2mem_addr,proc2mem_data,
                data2lsq,
                wr_valid_o, rd_valid_o);
     $display("###########  Finish reset ###############\n");
    end

    task trigger_reset();
        @(negedge clock) reset = 1;
        @(negedge clock);
        @(negedge clock) reset = 0;
    endtask
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////// request from lsq ///////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////// response from mem ///////////////////////////////////////////////////////////


    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    initial begin
        clock = 0;
        repeat(3) @(negedge clock);
        @(negedge clock);
        
        @(negedge clock);
        $finish;
    end


endmodule