
module icache_controller(
    // synopsys template
    input   clock,
    input   reset,
    input   [$clog2(`NUM_MEM_TAGS)-1:0] Imem2proc_response,        // FROM MEM
    input   [`DATA_SIZE-1:0] Imem2proc_data,  // FROM MEM
    input   [$clog2(`NUM_MEM_TAGS)-1:0] Imem2proc_tag,             // FROM MEM

    input  [63:0] proc2Icache_addr,          // FROM IF
    input  [`DATA_SIZE-1:0] cachemem_data,   // FROM CACHE MEM
    input   cachemem_valid,                  // FROM CACHE MEM

    input branch_taken,

    output BUS_COMMAND proc2Imem_command,    // TO MEM
    output logic [63:0] proc2Imem_addr,      // TO MEM

    output logic [`DATA_SIZE:0] Icache_data_out, // TO IF value is memory[proc2Icache_addr]
    output logic  Icache_valid_out,              // TO IF  when this is high

    output logic  [`ICACHE_IDX_WIDTH-1:0] current_index, // TO CACHE MEM
    output logic  [`ICACHE_TAG_WIDTH-1:0] current_tag,   // TO CACHE MEM
    output logic  [`ICACHE_IDX_WIDTH-1:0] wr_index,    // TO CACHE MEM
    output logic  [`ICACHE_TAG_WIDTH-1:0] wr_tag,      // TO CACHE MEM
    output logic  data_write_enable                      // TO CACHE MEM
    `ifdef DEBUG
        ,output [$clog2(`NUM_MEM_TAGS)-1:0] current_mem_tag
        ,output changed_addr, waiting_valid
        ,output [`NUM_MEM_TAGS-1:0] [$clog2(`NUM_MEM_TAGS)-1:0] addr_waiting_tag
        ,output [`NUM_MEM_TAGS-1:0] [63:0] addr_waiting
        ,output [$clog2(`NUM_MEM_TAGS)-1:0] head
        ,output [$clog2(`NUM_MEM_TAGS)-1:0] tail
    `endif
  
    );

    logic [`ICACHE_IDX_WIDTH-1:0] last_index;
    logic [`ICACHE_TAG_WIDTH-1:0] last_tag;

    // prefetch
    logic [`NUM_MEM_TAGS-1:0] [$clog2(`NUM_MEM_TAGS)-1:0] addr_waiting_tag;
    logic [`NUM_MEM_TAGS-1:0] [63:0] addr_waiting;
    logic [$clog2(`NUM_MEM_TAGS)-1:0] head, tail, n_head, n_tail;
    logic [`ICACHE_IDX_WIDTH-1:0] waiting_index;
    logic [`ICACHE_TAG_WIDTH-1:0] waiting_tag;
    logic waiting_valid;

    logic [63:0] requested_addr, next_addr;
    logic [$clog2(`NUM_MEM_TAGS)-1:0] current_mem_tag;
    
    assign requested_addr = proc2Imem_addr;

    assign current_mem_tag = addr_waiting_tag[head];
    assign n_tail = branch_taken ? 0 : (tail == `NUM_MEM_TAGS-1) ? 0 : (Imem2proc_response == 0) ? tail : tail + 1;
    assign n_head = branch_taken ? 0 : (head == `NUM_MEM_TAGS-1) ? 0 : (Imem2proc_tag == current_mem_tag & Imem2proc_tag != 0) ? head + 1 : head;

    assign {waiting_tag, waiting_index} = addr_waiting[head][31:3];
    assign waiting_valid = (waiting_tag == current_tag) & (waiting_index == current_index) & (Imem2proc_tag == current_mem_tag & Imem2proc_tag != 0);

    logic miss_outstanding;

    wire changed_addr = (current_index != last_index) || (current_tag != last_tag); // if this cycle addr is diff from last cycle addr

    assign {current_tag, current_index} = proc2Icache_addr[31:3];  // get this current cache tag and idx from  this cycle addr

    assign Icache_data_out = waiting_valid ? Imem2proc_data : cachemem_data;  // output the data from Icache mem to IF

    assign Icache_valid_out = waiting_valid | cachemem_valid; // output the valid bit from Icache mem to IF

    // assign proc2Imem_addr = {proc2Icache_addr[63:3],3'b0};  // output the addr to MEM
    assign proc2Imem_addr = (changed_addr && !Icache_valid_out) ? {proc2Icache_addr[63:3],3'b0} : next_addr;

    assign proc2Imem_command = (miss_outstanding && !changed_addr) ?  BUS_LOAD : BUS_NONE;// to MEM command, if the last cycle cache missed or unanswered, then send out LOAD this cycle

    assign data_write_enable =  (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0); // 1 if received correct data from MEM and data can be written into the cache
    assign wr_index = waiting_index;
    assign wr_tag = waiting_tag;

    // wire update_mem_tag = changed_addr || miss_outstanding || data_write_enable; // changed_addr and data_write_enable is used to clear the current_mem_tag

    wire unanswered_miss = changed_addr ? !Icache_valid_out : // 1 if Icache is missed
                                        miss_outstanding && (Imem2proc_response == 0); // cache miss request sent but not responsed correctly


  // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            last_index       <= `SD -1;   // These are -1 to get ball rolling when
            last_tag         <= `SD -1;   // reset goes low because addr "changes"
            // current_mem_tag  <= `SD 0;              
            miss_outstanding <= `SD 0;
            addr_waiting_tag <= `SD 0;
            addr_waiting     <= `SD 0;
            head             <= `SD 0;
            tail             <= `SD 0;
            next_addr <= `SD 0;
        end else begin      
            last_index       <= `SD current_index;
            last_tag         <= `SD current_tag;
            // wr_index         <= `SD waiting_index;
            // wr_tag           <= `SD waiting_tag;
            miss_outstanding <= `SD unanswered_miss | (Imem2proc_tag != current_mem_tag);

            head            <= `SD n_head;
            tail            <= `SD n_tail;

            if (Imem2proc_response != 0) begin
                next_addr <= `SD requested_addr + 8;
                addr_waiting_tag[tail] <= `SD Imem2proc_response;
                addr_waiting[tail]     <= `SD proc2Imem_addr;
            end
            else begin
                next_addr <= requested_addr;
                addr_waiting_tag[tail] <= `SD addr_waiting_tag[tail];
                addr_waiting[tail]     <= `SD addr_waiting[tail];
            end
      
        // if(update_mem_tag)
            // if (Imem2proc_tag != current_mem_tag) current_mem_tag <= `SD n_current_mem_tag;
            // else current_mem_tag <= `SD addr_waiting_tag[Imem2proc_response+1];
    end
  end

endmodule

