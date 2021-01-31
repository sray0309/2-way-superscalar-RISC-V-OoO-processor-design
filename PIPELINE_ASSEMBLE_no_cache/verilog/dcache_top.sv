module dcache_top(
    input clock,
    input reset,
    //FROM MEM
    input [$clog2(`NUM_MEM_TAGS)-1:0] mem2proc_response,
    input [`DATA_SIZE-1:0] mem2proc_data,
    input [$clog2(`NUM_MEM_TAGS)-1:0] mem2proc_tag,
    //FROM LSQ
    input [31:0] proc2Dcache_addr,
    input [31:0] proc2Dcache_data,
    input rd_mem,
    input wr_mem,
    input [2:0] proc2Dmem_size,
    input rollback,

    // TO MEM
    output BUS_COMMAND proc2mem_command,
    output logic [31:0] proc2mem_addr,
    output logic [`DATA_SIZE-1:0] proc2mem_data,
    output MEM_SIZE proc2Dmem_memsize,
    //TO LSQ
    output logic [31:0] data2lsq,
    output logic wr_valid_o,
    output logic rd_valid_o
);

    logic [`DATA_SIZE-1:0] cachemem_data;
    logic wr_valid_i;
    logic rd_valid_i;
    logic [`DATA_SIZE-1:0] evict_data;
    logic [31:0] evict_addr;
    logic evict_en;
    logic changed_data;

    logic rd_en;
    logic wr_en_mem;
    logic wr_en_lsq;
    logic offset;
    logic [`DCACHE_IDX_WIDTH-1:0] wr_idx;
    logic [`DCACHE_IDX_WIDTH-1:0] rd_idx;
    logic [`DCACHE_TAG_WIDTH-1:0] wr_tag;
    logic [`DCACHE_TAG_WIDTH-1:0] rd_tag;
    logic [`DATA_SIZE-1:0] wr_data;

    dcache_controller dcache_controller_0(
        .clock              (   clock               ),
        .reset              (   reset | rollback    ),
        //FROM MEM
        .mem2proc_response  (   mem2proc_response   ),
        .mem2proc_data      (   mem2proc_data       ),
        .mem2proc_tag       (   mem2proc_tag        ),
        //FROM LSQ
        .proc2Dcache_addr   (   proc2Dcache_addr    ),
        .proc2Dcache_data   (   proc2Dcache_data    ),
        .rd_mem             (   rd_mem              ),
        .wr_mem             (   wr_mem              ),
        .proc2Dmem_size     (   proc2Dmem_size      ),
        //FROM DCACHE
        .cachemem_data      (   cachemem_data       ),
        .wr_valid_i         (   wr_valid_i          ),
        .rd_valid_i         (   rd_valid_i          ),
        // TO MEM
        .proc2mem_command   (   proc2mem_command    ),
        .proc2mem_addr      (   proc2mem_addr       ),
        .proc2mem_data      (   proc2mem_data       ),
        .proc2Dmem_memsize  (   proc2Dmem_memsize   ),
        //TO LSQ
        .data2lsq           (   data2lsq            ),
        .wr_valid_o         (   wr_valid_o          ),
        .rd_valid_o         (   rd_valid_o          ),
        //TO DCACHE
        .rd_en              (   rd_en               ),
        .wr_en_mem          (   wr_en_mem           ),
        .wr_en_lsq          (   wr_en_lsq           ),
        .wr_idx             (   wr_idx              ),
        .rd_idx             (   rd_idx              ),
        .wr_tag             (   wr_tag              ),
        .rd_tag             (   rd_tag              ),
        .offset             (   offset              ),
        .wr_data            (   wr_data             )
    );

    dcache_mem dcache_mem_0(
        .clock              (   clock               ),
        .reset              (   reset               ),
        .rd_en              (   rd_en               ),
        .wr_en_mem          (   wr_en_mem           ),
        .wr_en_lsq          (   wr_en_lsq           ),
        .proc2Dmem_size     (   proc2Dmem_size      ),
        .offset             (   offset              ),
        .wr_idx             (   wr_idx              ),
        .wr_tag             (   wr_tag              ),
        .rd_idx             (   rd_idx              ),
        .rd_tag             (   rd_tag              ),
        .wr_data            (   wr_data             ),
        .dcache_rd_valid    (   rd_valid_i          ),
        .dcache_wr_valid    (   wr_valid_i          ),
        .rd_data            (   cachemem_data       )
    );

endmodule