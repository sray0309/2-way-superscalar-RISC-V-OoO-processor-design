
// blocking cache: if miss is unresolved, the addr will keep constant

module icache(
    input clock,
    input reset,

    input [3:0]  Imem2proc_response,         // from mem
    input [63:0] Imem2proc_data,             // data coming back from mem
    input [3:0]  Imem2proc_tag,              // from mem

    input [63:0] proc2Icache_addr,           // addr from IF stage
    input branch_taken,

    output BUS_COMMAND  proc2Imem_command,   // to mem
    output logic [63:0] proc2Imem_addr,      // addr to mem

    output logic [63:0] Icache_data_out,     // data to IF stage
    output logic        Icache_valid_out     // to IF stage
    `ifdef DEBUG
        ,output logic [3:0] current_mem_tag
        ,output changed_addr, Icache_wr_en, cachemem_valid, waiting_valid
        ,output logic [`NUM_MEM_TAGS-1:0] [$clog2(`NUM_MEM_TAGS)-1:0] addr_waiting_tag
        ,output [`NUM_MEM_TAGS-1:0] [63:0] addr_waiting
        ,output logic [$clog2(`NUM_MEM_TAGS)-1:0] head
        ,output logic [$clog2(`NUM_MEM_TAGS)-1:0] tail        
    `endif

);

    logic [63:0] cachemem_data;
    logic cachemem_valid;
    logic [`ICACHE_IDX_WIDTH-1:0] Icache_rd_idx;
    logic [`ICACHE_IDX_WIDTH-1:0] Icache_wr_idx;
    logic [`ICACHE_TAG_WIDTH-1:0] Icache_rd_tag;
    logic [`ICACHE_TAG_WIDTH-1:0] Icache_wr_tag;
    logic Icache_wr_en;


icache_controller icache_controller_0(
    .clock             (   clock               ),
    .reset             (   reset               ),
    .Imem2proc_response(   Imem2proc_response  ),
    .Imem2proc_data    (   Imem2proc_data      ),
    .Imem2proc_tag     (   Imem2proc_tag       ),

    .proc2Icache_addr  (   proc2Icache_addr    ),
    .cachemem_data     (   cachemem_data       ),
    .cachemem_valid    (   cachemem_valid      ),

    .proc2Imem_command (   proc2Imem_command   ),
    .proc2Imem_addr    (   proc2Imem_addr      ),
    .Icache_data_out   (   Icache_data_out     ),
    .Icache_valid_out  (   Icache_valid_out    ),

    .current_index     (   Icache_rd_idx       ),
    .current_tag       (   Icache_rd_tag       ),
    .wr_index        (   Icache_wr_idx       ),
    .wr_tag          (   Icache_wr_tag       ),
    .data_write_enable (   Icache_wr_en        ),
    .branch_taken      (   branch_taken        )
    `ifdef DEBUG
        ,.current_mem_tag(current_mem_tag)
        ,.changed_addr(changed_addr)
        ,.addr_waiting_tag(addr_waiting_tag)
        ,.head(head)
        ,.tail(tail)
        ,.waiting_valid(waiting_valid)
        ,.addr_waiting(addr_waiting)
    `endif
);

cache cache_mem_0(
    .clock    (   clock            ),
    .reset    (   reset            ),
    .wr1_en   (   Icache_wr_en     ),
    .wr1_idx  (   Icache_wr_idx    ),
    .wr1_tag  (   Icache_wr_tag    ),
    .wr1_data (   Imem2proc_data   ),

    .rd1_idx  (   Icache_rd_idx    ),
    .rd1_tag  (   Icache_rd_tag    ),
    .rd1_data (   cachemem_data    ),
    .rd1_valid(   cachemem_valid   )
);


endmodule