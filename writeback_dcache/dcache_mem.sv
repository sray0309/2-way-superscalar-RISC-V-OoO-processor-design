module dcache_mem(
    input clock,
    input reset,
    input rd_en,
    input wr_en_mem, wr_en_lsq,
    input [`DCACHE_IDX_WIDTH-1:0] wr_idx, rd_idx,
    input [`DCACHE_TAG_WIDTH-1:0] wr_tag, rd_tag,
    input [63:0] wr_data,
    input [2:0]  proc2Dmem_size,
    input offset,

    output logic dcache_rd_valid, dcache_wr_valid,
    output logic [63:0] rd_data,
    output logic [63:0] evict_data_out,
    output logic [31:0] evict_addr_out,
    output logic evict_en
);

    logic [`DCACHE_SET_NUM-1 : 0] set_rd_en;
    logic [`DCACHE_SET_NUM-1 : 0] set_wr_en_mem, set_wr_en_lsq;
    logic [`DCACHE_SET_NUM-1 : 0] set_rd_valid, set_wr_valid;
    logic [`DCACHE_SET_NUM-1 : 0] [`DCACHE_TAG_WIDTH-1 : 0] set_wr_tag, set_rd_tag;
    logic [`DCACHE_SET_NUM-1 : 0] [63                  : 0] set_wr_data, set_rd_data;
    logic [`DCACHE_SET_NUM-1 : 0] [63                  : 0] set_evict_data;
    logic [`DCACHE_SET_NUM-1 : 0] [`DCACHE_TAG_WIDTH-1 : 0] set_evict_tag;
    logic [`DCACHE_SET_NUM-1 : 0] set_evict_en;

    MEM_SIZE mem_size;
    assign mem_size = MEM_SIZE'(proc2Dmem_size[1:0]);

    genvar i;
    generate
        for (i=0; i<`DCACHE_SET_NUM; i++) begin
            dcache_set dcache_set(
                .clock          (   clock               ),
                .reset          (   reset               ),
                .mem_size       (   mem_size            ),
                .offset         (   offset              ),
                .rd_en          (   set_rd_en[i]        ),
                .wr_en_mem      (   set_wr_en_mem[i]    ),
                .wr_en_lsq      (   set_wr_en_lsq[i]    ),
                .wr_tag         (   set_wr_tag[i]       ),
                .wr_data        (   set_wr_data[i]      ),
                .wr_valid       (   set_wr_valid[i]     ),
                .rd_valid       (   set_rd_valid[i]     ),
                .rd_tag         (   set_rd_tag[i]       ),
                .rd_data        (   set_rd_data[i]      ),
                .evict_tag      (   set_evict_tag[i]    ),
                .evict_data     (   set_evict_data[i]   ),
                .evict_en       (   set_evict_en[i]     )
            );
        end
    endgenerate

    //input
    always_comb begin
        set_wr_en_mem[wr_idx] = wr_en_mem;
        set_wr_en_lsq[wr_idx] = wr_en_lsq;
        set_wr_tag[wr_idx] = wr_tag;
        set_wr_data[wr_idx] = wr_data;
        set_rd_tag[rd_idx] = rd_tag;
        set_rd_en[rd_idx] = rd_en;
    end
    
    
    //output
    always_comb begin
        dcache_rd_valid = set_rd_valid[rd_idx];
        dcache_wr_valid = set_wr_valid[wr_idx];
        rd_data = set_rd_data[rd_idx];
        evict_en = set_evict_en[wr_idx];
        evict_data_out = set_evict_data[wr_idx];
        evict_addr_out = {{(29-(`DCACHE_TAG_WIDTH)-`DCACHE_IDX_WIDTH){1'b0}},set_evict_tag[wr_idx],wr_idx,{3'b000}};
    end


endmodule


module dcache_set(
    input clock,
    input reset,
    input wr_en_mem, wr_en_lsq,
    input [`DCACHE_TAG_WIDTH-1:0] wr_tag, rd_tag,
    input [63:0] wr_data,
    input rd_en,
    input MEM_SIZE mem_size,
    input offset,

    output logic rd_valid, wr_valid,
    output logic [63:0] rd_data,
    output logic [63:0] evict_data,
    output logic [`DCACHE_TAG_WIDTH-1:0] evict_tag,
    output logic evict_en
);

    logic [`DCACHE_WAY_NUM-1 : 0] [7:0] [7:0]                     data;
    logic [`DCACHE_WAY_NUM-1 : 0] [`DCACHE_TAG_WIDTH-1       : 0] tag;
    logic [`DCACHE_WAY_NUM-1 : 0] [$clog2(`DCACHE_WAY_NUM)-1 : 0] flag_recent, n_flag_recent;
    logic [`DCACHE_WAY_NUM-1 : 0]                                 dirtybit;
    logic [`DCACHE_WAY_NUM-1 : 0]                                 read_hit_entry, write_hit_entry;

    logic read_hit, write_hit;

    logic [$clog2(`DCACHE_WAY_NUM)-1 : 0] wr_way, rd_way;

    integer i,j,k;

    //read logic
    always_comb begin
        if(rd_en && !wr_en_mem && !wr_en_lsq) begin
            for (i=0; i<`DCACHE_WAY_NUM; i++) begin
                if (rd_tag == tag[i]) begin
                    read_hit_entry[i] = 1;
                    rd_way = i;
                end else begin
                    read_hit_entry[i] = 0;
                end
            end
        end else begin
            rd_way = 0;
            read_hit_entry = 0;
        end
    end

    assign read_hit = |read_hit_entry;
    assign rd_valid = read_hit;
    assign rd_data = data[rd_way];

    //write logic
    always_comb begin
        if (wr_en_lsq & !wr_en_mem) begin
            for (j=0; j<`DCACHE_WAY_NUM; j++) begin
                if (wr_tag == tag[j]) begin
                    wr_way = j;
                    write_hit_entry[j] = 1;
                end else begin
                    write_hit_entry[j] = 0;
                end
            end
        end else if (!wr_en_lsq & wr_en_mem) begin
            write_hit_entry = 0;
            for (k=0; k<`DCACHE_WAY_NUM; k++) begin
                if (flag_recent[k] == {$clog2(`DCACHE_WAY_NUM){1'b0}}) begin
                    wr_way = k;
                end
            end
        end else begin
            write_hit_entry = 0;
            wr_way = 0;
        end
    end

    assign write_hit = |write_hit_entry;
    assign wr_valid = write_hit;

    integer a;
    // recent bit logic
    always_comb begin
        n_flag_recent = flag_recent;
        if (wr_en_mem & !write_hit) begin
            for (a=0; a<`DCACHE_WAY_NUM; a++) begin
                if (a == wr_way)
                    n_flag_recent[a] = {$clog2(`DCACHE_WAY_NUM){1'b1}};
                else
                    n_flag_recent[a] = (flag_recent[a] == 0)? 0 : flag_recent[a] - 1;
            end
        end
        else if (write_hit) begin
            if (flag_recent[wr_way] == {$clog2(`DCACHE_WAY_NUM){1'b1}}) begin
                n_flag_recent = flag_recent;
            end else begin
                for (a=0; a<`DCACHE_WAY_NUM; a++) begin
                    if (a == wr_way)
                        n_flag_recent[a] = {$clog2(`DCACHE_WAY_NUM){1'b1}};
                    else
                        n_flag_recent[a] = (flag_recent[a] == 0)? 0 : flag_recent[a] - 1;
                end
            end
        end
    end

    //evict logic
    always_comb begin
        evict_en = 0;
        evict_data = 0;
        evict_tag = 0;
        if (wr_en_mem && dirtybit[wr_way]) begin
            evict_en = 1;
            evict_data = data[wr_way];
            evict_tag = tag[wr_way];
        end
    end

    // write reg
    always_ff @(posedge clock) begin
        if (reset) begin
            flag_recent <= `SD 0;
            data        <= `SD 0;
            tag         <= `SD 0;
            dirtybit    <= `SD 0;
        end
        else begin
            flag_recent          <= `SD n_flag_recent;
            if (wr_en_mem & !write_hit) begin
                data[wr_way]     <= `SD wr_data;
                tag[wr_way]      <= `SD wr_tag;
                if (dirtybit[wr_way]) begin
                    dirtybit[wr_way] <= `SD 0;
                end else begin
                    dirtybit[wr_way] <= `SD dirtybit[wr_way];
                end
            end
            else if (write_hit & !wr_en_mem) begin
                if (offset) begin
                    if (mem_size == BYTE) begin
                        data[wr_way][4]        <= `SD wr_data[7:0];
                    end else if (mem_size == HALF) begin
                        data[wr_way][5:4]      <= `SD wr_data[15:0];
                    end else begin
                        data[wr_way][7:4]      <= `SD wr_data[31:0];
                    end
                end else begin
                    if (mem_size == BYTE) begin
                        data[wr_way][0]        <= `SD wr_data[7:0];
                    end else if (mem_size == HALF) begin
                        data[wr_way][1:0]      <= `SD wr_data[15:0];
                    end else begin
                        data[wr_way][3:0]      <= `SD wr_data[31:0];
                    end
                end
                dirtybit[wr_way]     <= `SD 1;
            end
            else begin
                data        <= `SD data;
                tag         <= `SD tag;
                dirtybit    <= `SD dirtybit;
            end
        end
    end

endmodule
