`define LOAD_BUFFER_NUM 32
module load_buffer (
    input clock,
    input reset,
    input FU_LQ_PACKET din1,din2,
    input wr_en1,wr_en2,
    input rd_en,
    //from cache
    input cache_valid,
    input [31:0] cache_data,
    
    //to cache
    output rd_cache,
    output [31:0] addr,
    output [2:0] mem_size,
    
    output FU_LQ_PACKET   dout,
    output logic [31:0] value_o,
    output logic valid_o,
    output logic empty,
    output logic full
);

FU_LQ_PACKET [`LOAD_BUFFER_NUM-1:0] entry;
logic [`LOAD_BUFFER_NUM-1:0] valid_buffer;
logic [`LOAD_BUFFER_NUM-1:0] occupied;
logic [`LOAD_BUFFER_NUM-1:0] [31:0] value_buffer;
logic [$clog2(`LOAD_BUFFER_NUM)-1:0] head, next_head, tail, next_tail, sent, next_sent;

logic [$clog2(`LOAD_BUFFER_NUM)-1:0] tail_p1;

assign tail_p1 = tail + 1;

assign empty = ! (|occupied);
assign full  = (& occupied);

assign dout = entry[head];
assign value_o = value_buffer[head];
assign valid_o = valid_buffer[head];
assign sent = head;
assign next_sent = next_head;

// assign rd_cache =  !empty && !valid_buffer[sent] && occupied[sent];
assign rd_cache = !valid_buffer[sent] && occupied[sent];

assign addr = rd_cache ? entry[sent].result : 0;
assign mem_size = rd_cache? entry[sent].mem_size : 0;

always_comb begin
    next_tail = tail;
    next_head = head;
    // next_sent = sent;
    case({wr_en2, wr_en1})
        2'b00: next_tail = tail;
        2'b01: next_tail = tail + 1;
        2'b10: next_tail = tail + 1;
        2'b11: next_tail = tail + 2;
    endcase
    if (rd_en) begin
        next_head = head + 1;
    end
end

always_ff @(posedge clock) begin
    if (reset) begin
        entry <= `SD 0;
        head  <= `SD 0;
        tail  <= `SD 0;
        valid_buffer <= `SD 0;
        value_buffer <= `SD 0;
        occupied     <= `SD 0;
    end else begin
        tail <= `SD next_tail;
        head <= `SD next_head;
        if(rd_en) begin
            valid_buffer[head] <= `SD 1'b0;
            value_buffer[head] <= `SD 32'b0;
            entry[head]        <= `SD 0;
            occupied[head]     <= `SD 0;
        end
        case({wr_en2, wr_en1})
            2'b00: begin
                entry[tail] <= `SD entry[tail];
                occupied[tail]    <= `SD occupied[tail];
            end
            2'b01: begin
                entry[tail] <= `SD din1;
                occupied[tail] <= `SD 1;
            end
            2'b10: begin
                entry[tail] <= `SD din2;
                occupied[tail] <= `SD 1;
            end
            2'b11: begin
                entry[tail] <= `SD din1;
                entry[tail_p1] <= `SD din2;
                occupied[tail]  <= `SD 1;
                occupied[tail_p1] <= `SD 1;
            end
        endcase
        if (cache_valid && occupied[sent]) begin
            valid_buffer[sent] <= `SD 1'b1;
            value_buffer[sent] <= `SD cache_data;
        end
    end
end


endmodule