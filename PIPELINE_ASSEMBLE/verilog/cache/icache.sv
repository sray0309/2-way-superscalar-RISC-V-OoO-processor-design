
// blocking cache: if miss is unresolved, the addr will keep constant
`timescale 1ns/100ps
module icache(
    input clock,
    input reset,

    input [3:0]  Imem2proc_response,         // from mem
    input [63:0] Imem2proc_data,             // data coming back from mem
    input [3:0]  Imem2proc_tag,              // from mem

    input [63:0] proc2Icache_addr,           // addr from IF stage

    output BUS_COMMAND  proc2Imem_command,   // to mem
    output logic [63:0] proc2Imem_addr,      // addr to mem

    output logic [63:0] Icache_data_out,     // data to IF stage
    output logic        Icache_valid_out     // to IF stage

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
    .last_index        (   Icache_wr_idx       ),
    .last_tag          (   Icache_wr_tag       ),
    .data_write_enable (   Icache_wr_en        )
);

icache_mem cache_mem_0(
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