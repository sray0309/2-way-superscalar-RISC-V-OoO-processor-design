`define LOAD_BUFFER_NUM 8

`define SD #1
typedef struct packed {
  logic                         done;
  logic [31:0]             result;
  logic [1:0]   pdest_idx;  // 7
  logic [1:0]    rob_idx; // Dest idx,7
  logic [1:0]    SQ_idx;  // come all the way from RS in dispatch stage 
  logic [1:0]    LQ_idx;  // same
  logic [2:0]                   mem_size;
} FU_LQ_PACKET;

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
    output logic empty
);

FU_LQ_PACKET [`LOAD_BUFFER_NUM-1:0] entry;
logic [`LOAD_BUFFER_NUM-1:0] valid_buffer;
logic [`LOAD_BUFFER_NUM-1:0] value_buffer;
logic [$clog2(`LOAD_BUFFER_NUM)-1:0] head, next_head, tail, next_tail, sent, next_sent;

assign empty = (head == tail);
assign dout = (rd_en && valid_buffer[head]) ? entry[head] : 0;
assign value_o = (rd_en && valid_buffer[head]) ? value_buffer[head] : 0;
assign valid_o = (rd_en && valid_buffer[head]);

assign rd_cache = !empty;
assign addr = rd_cache ? entry[sent].result : 0;
assign mem_size = rd_cache? entry[sent].mem_size : 0;

always_comb begin
    next_tail = tail;
    next_head = head;
    next_sent = sent;
    case({wr_en2, wr_en1})
        2'b00: next_tail = tail;
        2'b01: next_tail = tail + 1'b1;
        2'b10: next_tail = tail + 1'b1;
        2'b11: next_tail = tail + 2'b10;
    endcase
    if (rd_en && valid_buffer[head]) begin
        next_head = head + 1'b1;
    end
    if (cache_valid) begin
        next_sent = sent + 1'b1;
    end
end

always_ff @(posedge clock) begin
    if (reset) begin
        entry <= `SD 0;
        head  <= `SD 0;
        tail  <= `SD 0;
        sent  <= `SD 0;
        valid_buffer <= `SD 0;
        value_buffer <= `SD 0;
    end else begin
        tail <= `SD next_tail;
        head <= `SD next_head;
        sent <= `SD next_sent;
        case({wr_en2, wr_en1})
            2'b00: begin
                entry[tail] <= `SD entry[tail];
            end
            2'b01: begin
                entry[tail] <= `SD din1;
            end
            2'b10: begin
                entry[tail] <= `SD din2;
            end
            2'b11: begin
                entry[tail] <= `SD din1;
                entry[tail+1'b1] <= `SD din2;
            end
        endcase
        if (cache_valid) begin
            valid_buffer[sent] = 1'b1;
            value_buffer[sent] = cache_data;
        end
    end
end


endmodule