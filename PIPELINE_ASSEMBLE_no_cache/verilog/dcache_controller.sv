typedef enum{DIDLE, DREQUEST, DWAIT} DCACHE_STATE;

module dcache_controller(
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
    //FROM DCACHE
    input [`DATA_SIZE-1:0] cachemem_data,
    input wr_valid_i,
    input rd_valid_i,

    // TO MEM
    output BUS_COMMAND proc2mem_command,
    output logic [31:0] proc2mem_addr,
    output logic [`DATA_SIZE-1:0] proc2mem_data,
    output MEM_SIZE proc2Dmem_memsize,
    //TO LSQ
    output logic [31:0] data2lsq,
    output logic wr_valid_o,
    output logic rd_valid_o,
    //TO DCACHE
    output logic rd_en,
    output logic wr_en_mem,
    output logic wr_en_lsq,
    output logic [`DCACHE_IDX_WIDTH-1:0] wr_idx,
    output logic [`DCACHE_IDX_WIDTH-1:0] rd_idx,
    output logic offset,
    output logic [`DCACHE_TAG_WIDTH-1:0] wr_tag,
    output logic [`DCACHE_TAG_WIDTH-1:0] rd_tag,
    output logic [`DATA_SIZE-1:0] wr_data
);

    logic current_offset;
    logic [`DCACHE_IDX_WIDTH-1:0] current_idx;
    logic [`DCACHE_TAG_WIDTH-1:0] current_tag;
    logic [$clog2(`NUM_MEM_TAGS)-1:0] waiting_memtag;

    logic [31:0] sized_data;
    MEM_SIZE mem_size;

    assign mem_size = MEM_SIZE'(proc2Dmem_size[1:0]);

    assign {current_tag, current_idx} = proc2Dcache_addr[31:3];
    assign current_offset = proc2Dcache_addr[2];

    DCACHE_STATE state, next_state;

    always_ff @(posedge clock) begin
        if (reset) begin
            state           <= `SD DIDLE;
            waiting_memtag  <= `SD 0;
        end
        else begin
            state           <= `SD next_state;
            if (state == DREQUEST) begin
                waiting_memtag <= `SD mem2proc_response;
            end else begin
                waiting_memtag <= `SD waiting_memtag;
            end
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            DIDLE: begin
                if (wr_mem) begin
                    next_state = DIDLE;
                end else if (wr_mem == 0 && {rd_mem,rd_valid_i} == 2'b11) begin
                    next_state = DIDLE;
                end else if (wr_mem == 0 && {rd_mem,rd_valid_i} == 2'b10) begin
                    next_state = DREQUEST;
                end else begin
                    next_state = DIDLE;
                end
            end
            DREQUEST: begin
                if (mem2proc_response != 0) begin
                    next_state = DWAIT;
                end else begin
                    next_state = DREQUEST;
                end
            end
            DWAIT: begin
                if (mem2proc_tag != waiting_memtag) begin
                    next_state = DWAIT;
                end else begin
                    next_state = DIDLE;
                end
            end
        endcase
    end

    always_comb begin
        proc2mem_command = BUS_NONE;
        proc2mem_addr = 0;
        proc2mem_data = 0;
        rd_en = 0;
        wr_en_mem = 0;
        wr_en_lsq = 0;
        wr_idx = 0;
        rd_idx = 0;
        wr_tag = 0;
        rd_tag = 0;
        wr_data = 0;
        wr_valid_o = 0;
        rd_valid_o = 0;
        data2lsq = 0;
        offset = 0;
        case (state)
            DIDLE: begin
                if (wr_mem && !reset) begin
                    wr_en_lsq   = 1;
                    wr_idx      = current_idx;
                    wr_tag      = current_tag;
                    offset      = current_offset;
                    wr_data     = {32'b0,proc2Dcache_data};
                    wr_valid_o  = 1;
                    proc2mem_command = BUS_STORE;
                    proc2mem_addr = proc2Dcache_addr;
                    proc2mem_data = proc2Dcache_data;
                    proc2Dmem_memsize = mem_size;
                end
                if (rd_mem & !wr_mem) begin
                    rd_en  = 1;
                    rd_idx = current_idx;
                    rd_tag = current_tag;
                    rd_valid_o = rd_valid_i;
                    data2lsq = sized_data;
                end
            end
            DREQUEST: begin
                proc2mem_addr = {proc2Dcache_addr[31:3],3'b000};
                proc2mem_command = BUS_LOAD;
            end
            DWAIT: begin
                if (mem2proc_tag == waiting_memtag && !reset) begin
                    wr_en_mem   = 1;
                    wr_idx      = current_idx;
                    wr_tag      = current_tag;
                    if (rd_mem && !wr_mem) begin
                        wr_data     = mem2proc_data;
                        rd_valid_o  = 1;
                        data2lsq    = sized_data;
                    end
                end
            end
        endcase
    end


    always_comb begin
		sized_data = 0;
		if (state == DIDLE && rd_mem) begin
            if (current_offset) begin
			    if (~proc2Dmem_size[2]) begin //is this an signed/unsigned load?
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){cachemem_data[7]}}, cachemem_data[39:32]};
			    	else if  (mem_size == HALF) 
			    		sized_data = {{(`XLEN-16){cachemem_data[15]}}, cachemem_data[47:32]};
			    	else sized_data = cachemem_data[63:32];
			    end else begin
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){1'b0}}, cachemem_data[39:32]};
			    	else if  (mem_size == HALF)
			    		sized_data = {{(`XLEN-16){1'b0}}, cachemem_data[47:32]};
			    	else sized_data = cachemem_data[63:32];
			    end
            end else begin
                if (~proc2Dmem_size[2]) begin //is this an signed/unsigned load?
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){cachemem_data[7]}}, cachemem_data[7:0]};
			    	else if  (mem_size == HALF) 
			    		sized_data = {{(`XLEN-16){cachemem_data[15]}}, cachemem_data[15:0]};
			    	else sized_data = cachemem_data[31:0];
			    end else begin
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){1'b0}}, cachemem_data[7:0]};
			    	else if  (mem_size == HALF)
			    		sized_data = {{(`XLEN-16){1'b0}}, cachemem_data[15:0]};
			    	else sized_data = cachemem_data[31:0];
			    end
            end
		end
        else if (state == DWAIT && mem2proc_tag == waiting_memtag && rd_mem) begin
            if (offset) begin
                if (~proc2Dmem_size[2]) begin //is this an signed/unsigned load?
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){mem2proc_data[7]}}, mem2proc_data[39:32]};
			    	else if  (mem_size == HALF) 
			    		sized_data = {{(`XLEN-16){mem2proc_data[15]}}, mem2proc_data[47:32]};
			    	else sized_data = mem2proc_data[63:32];
			    end else begin
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){1'b0}}, mem2proc_data[39:32]};
			    	else if  (mem_size == HALF)
			    		sized_data = {{(`XLEN-16){1'b0}}, mem2proc_data[47:32]};
			    	else sized_data = mem2proc_data[63:32];
			    end
            end else begin
                if (~proc2Dmem_size[2]) begin //is this an signed/unsigned load?
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){mem2proc_data[7]}}, mem2proc_data[7:0]};
			    	else if  (mem_size == HALF) 
			    		sized_data = {{(`XLEN-16){mem2proc_data[15]}}, mem2proc_data[15:0]};
			    	else sized_data = mem2proc_data[31:0];
			    end else begin
			    	if (mem_size == BYTE)
			    		sized_data = {{(`XLEN-8){1'b0}}, mem2proc_data[7:0]};
			    	else if  (mem_size == HALF)
			    		sized_data = {{(`XLEN-16){1'b0}}, mem2proc_data[15:0]};
			    	else sized_data = mem2proc_data[31:0];
			    end
            end
        end
	end

endmodule