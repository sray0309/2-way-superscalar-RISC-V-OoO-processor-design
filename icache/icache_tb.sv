module icache_tb;

    logic clock, reset;
    logic [$clog2(`NUM_MEM_TAGS)-1:0]  Imem2proc_response;
    logic [63:0] Imem2proc_data;
    logic [$clog2(`NUM_MEM_TAGS)-1:0]  Imem2proc_tag;

    logic [63:0] proc2Icache_addr;
    logic branch_taken;

    BUS_COMMAND proc2Imem_command;
    logic [63:0] proc2Imem_addr;
    logic [63:0] Icache_data_out;
    logic        Icache_valid_out;

    `ifdef DEBUG
        logic [$clog2(`NUM_MEM_TAGS)-1:0] current_mem_tag;
        logic changed_addr, Icache_wr_en, cachemem_valid, waiting_valid;
        logic [`NUM_MEM_TAGS-1:0] [$clog2(`NUM_MEM_TAGS)-1:0] addr_waiting_tag;
        logic [`NUM_MEM_TAGS-1:0] [63:0] addr_waiting;
        logic [$clog2(`NUM_MEM_TAGS)-1:0] head;
        logic [$clog2(`NUM_MEM_TAGS)-1:0] tail ;    
        string s;
        integer entry_idx;
    `endif

    icache DUT(
        .clock(clock),
        .reset(reset),
        .Imem2proc_data(Imem2proc_data),
        .Imem2proc_response(Imem2proc_response),
        .Imem2proc_tag(Imem2proc_tag),
        
        .proc2Icache_addr(proc2Icache_addr),
        .proc2Imem_command(proc2Imem_command),
        .proc2Imem_addr(proc2Imem_addr),
        .Icache_data_out(Icache_data_out),
        .Icache_valid_out(Icache_valid_out),
        .branch_taken(0)
        `ifdef DEBUG
            ,.current_mem_tag(current_mem_tag)
            ,.changed_addr(changed_addr)
            ,.Icache_wr_en(Icache_wr_en)
            ,.cachemem_valid(cachemem_valid)
            ,.addr_waiting_tag(addr_waiting_tag)
            ,.head(head)
            ,.tail(tail)
            ,.waiting_valid(waiting_valid)
            ,.addr_waiting(addr_waiting)
        `endif
    );

////////////////////////////////////////// clock generation /////////////////////////////////////// 
    always #5 clock = ~clock;

///////////////////////////////////////// reset trigger ///////////////////////////////////////////
initial begin
    reset = 0;
    @(negedge clock); reset = 1;
    @(negedge clock); reset = 0;
    Imem2proc_data = 0;
    Imem2proc_response = 0;
    Imem2proc_tag = 0;
    proc2Icache_addr = 0;
    @(posedge clock);
    $display("################ Timd:%0t icache reset information ###################\n\
 Imem2proc_response:%0d    Imem2proc_data:%0d    Imem2proc_tag:%0d\n\
 proc2Icache_addr:%0d\n\
 proc2Imem_command:%0d    proc2Imem_addr:%0d\n\
 Icache_data_out:%0d    Icache_valid_out:%0d\n\
###################################################################\n",
 $time, Imem2proc_response, Imem2proc_data, Imem2proc_tag,
        proc2Icache_addr,
        proc2Imem_command,proc2Imem_addr,
        Icache_data_out,Icache_valid_out);
        `ifdef DEBUG
        $display("################ Timd:%0t icache DEBUG information ###################\n\
 current_mem_tag:%0d\n\
 changed_addr:%0d\n\
 Icache_wr_en:%0d\n\
 cachemem_valid:%0d\n\
 waiting_valid:%0d\n\
###################################################################\n",
 $time, current_mem_tag,
 changed_addr,
 Icache_wr_en,
 cachemem_valid,
 waiting_valid);    

 s = {s, $sformatf("############# Time:%0t waiting tag ##############\n",$time)};
 s = {s, $sformatf("head:%0d   tail:%0d\n",head, tail)};
 for (entry_idx = 0; entry_idx <= `NUM_MEM_TAGS-1; entry_idx++) begin
     s = {s, $sformatf("addr_waiting[%0d]:%0d   addr_waiting_tag[%0d]:%0d\n",entry_idx, addr_waiting[entry_idx],entry_idx,addr_waiting_tag[entry_idx])};
 end
 s = {s, $sformatf("#################################################\n")};
 $display(s);
        `endif
end

task trigger_reset;
    @(negedge clock);
        reset = 1;
    @(negedge clock);
    @(negedge clock);
        reset = 0;
endtask
//////////////////////////////////// driver ////////////////////////////////////////////////////////
task driver;
    input [3:0] dr_response;
    input [63:0] dr_data;
    input [3:0] dr_tag;

    input [63:0] dr_addr;
    @(negedge clock) begin
        Imem2proc_response = dr_response;
        Imem2proc_data = dr_data;
        Imem2proc_tag = dr_tag;
        proc2Icache_addr = dr_addr;
    end
    fork
        @(posedge clock) begin
        $display("################ Timd:%0t icache data information ###################\n\
 Imem2proc_response:%0d    Imem2proc_data:%0d    Imem2proc_tag:%0d\n\
 proc2Icache_addr:%0d\n\
 proc2Imem_command:%0d    proc2Imem_addr:%0d\n\
 Icache_data_out:%0d    Icache_valid_out:%0d\n\
###################################################################\n",
 $time, Imem2proc_response, Imem2proc_data, Imem2proc_tag,
        proc2Icache_addr,
        proc2Imem_command,proc2Imem_addr,
        Icache_data_out,Icache_valid_out);   

        `ifdef DEBUG
        $display("################ Timd:%0t icache DEBUG information ###################\n\
 current_mem_tag:%0d\n\
 changed_addr:%0d\n\
 Icache_wr_en:%0d\n\
 cachemem_valid:%0d\n\
 waiting_valid:%0d\n\
###################################################################\n",
 $time, current_mem_tag,
 changed_addr,
 Icache_wr_en,
 cachemem_valid,
 waiting_valid);    
 s = "";
 s = {s, $sformatf("############# Time:%0t waiting tag ##############\n",$time)};
 s = {s, $sformatf("head:%0d   tail:%0d\n",head, tail)};
 for (entry_idx = 0; entry_idx <= `NUM_MEM_TAGS-1; entry_idx++) begin
     s = {s, $sformatf("addr_waiting[%0d]:%0d   addr_waiting_tag[%0d]:%0d\n",entry_idx, addr_waiting[entry_idx],entry_idx,addr_waiting_tag[entry_idx])};
 end
 s = {s, $sformatf("#################################################\n")};
 $display(s);
        `endif
        end
    join_none
endtask


/////////////////////////////////////////////// test bench /////////////////////////////////////////
initial begin
    clock = 0;
    repeat (3) @(negedge clock);

    driver(1,0,0,8);
    driver(2,0,0,8);
    driver(3,0,0,8);
    driver(4,0,0,8);
    driver(5,20,1,8);
    driver(6,21,2,16);
    driver(7,22,3,24);
    driver(8,23,4,24);
    driver(9,24,5,24);
    driver(10,25,6,48);
    // driver(11,26,7,24);
    // driver(12,27,8,8);
    // driver(13,28,9,8);
    // driver(14,29,10,8);
    // driver(15,30,11,8);
    // driver(1,31,12,8);
    // driver(2,32,13,16);
    // driver(3,33,14,24);
    // driver(4,34,15,24);
    // driver(5,35,1,24);
    // driver(6,36,2,24);
    // driver(7,37,2,24);
    driver(0,0,0,0);

    @(negedge clock);
    $finish;
end

endmodule