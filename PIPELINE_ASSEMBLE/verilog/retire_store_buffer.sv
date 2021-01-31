`define RETIRE_BUFFER_NUM 32
/*
`define SD #1
typedef struct packed {
    logic   [31:0]         addr;
    logic                       valid;
    logic   [31:0]         value;
    logic   [3:0] LQ_idx;  //use this  which actually from FU directly
    logic   [2:0]               mem_size;
} SQ_ENTRY_PACKET;
*/

module retire_store_buffer(
    input clock,
    input reset,
    input SQ_ENTRY_PACKET din1,din2,
    input wr_en1,wr_en2,
    input rd_en,


    input [1:0] [31:0] load_addr_i,

    output logic [1:0] [31:0] load_value_o,
    output logic [1:0] load_value_valid,

    output SQ_ENTRY_PACKET   dout,
    output logic empty
);

SQ_ENTRY_PACKET [`RETIRE_BUFFER_NUM-1:0] entry;
logic [`RETIRE_BUFFER_NUM-1:0] valid;
logic [$clog2(`RETIRE_BUFFER_NUM)-1:0] pointer, next_pointer;
integer i,j,k;

assign empty = pointer == 0;
always_comb begin
    if (pointer == 0 && wr_en1 && !wr_en2 && rd_en) begin
        dout = din1;
    end else if (pointer == 0 && wr_en2 && !wr_en1 && rd_en) begin
        dout = din1;
    end else if (pointer == 0 && wr_en2 && wr_en1 && rd_en) begin
        dout = din1;
    end else begin
        dout = entry[0];
    end
end

always_comb begin
    next_pointer = pointer;
    case({wr_en1, wr_en2, rd_en})
        3'b000: next_pointer = pointer;
        3'b001: next_pointer = pointer - 1'b1;
        3'b010: next_pointer = pointer + 1'b1;
        3'b100: next_pointer = pointer + 1'b1;
        3'b011: next_pointer = pointer;
        3'b110: next_pointer = pointer + 2'b10;
        3'b101: next_pointer = pointer;
        3'b111: next_pointer = pointer + 1'b1;
    endcase
end

always_ff @(posedge clock) begin
    if (reset) begin
        entry   <= `SD 0;
        pointer <= `SD 0;
        valid   <= `SD 0;
    end
    else begin
        pointer <= `SD next_pointer;
        for (i=1; i<`RETIRE_BUFFER_NUM; i++) begin
            case({wr_en1, wr_en2, rd_en})
            3'b000: entry          <= `SD entry;
            3'b001: begin
                entry[i-1]     <= `SD entry[i];
                valid[pointer-1'b1] <= `SD 1'b0;
            end
            3'b010: begin
                entry[pointer] <= `SD din1;
                valid[pointer] <= `SD 1'b1;
            end
            3'b100: begin
                entry[pointer] <= `SD din1;
                valid[pointer] <= `SD 1'b1;
            end
            3'b011: begin
                if (pointer != 0)  begin
                    entry[pointer-1'b1] <= `SD din1;
                end
                if (i < pointer) begin
                    entry[i-1]     <= `SD entry[i];
                end
            end
            3'b110: begin
                    entry[pointer]        <= `SD din1;
                    entry[pointer + 1'b1] <= `SD din2;
                    valid[pointer]        <= `SD 1'b1;
                    valid[pointer + 1'b1] <= `SD 1'b1;
            end
            3'b101: begin
                if (pointer != 0)  begin
                    entry[pointer-1'b1] <= `SD din1;
                end
                if (i < pointer) begin
                    entry[i-1]     <= `SD entry[i];
                end
            end
            3'b111: begin
                if (pointer != 0) begin
                    entry[pointer]      <= `SD din2;
                    entry[pointer-1'b1] <= `SD din1;
                end
                else begin
                    entry[pointer] <= `SD din2;
                end
                valid[pointer]      <= `SD 1'b1;
                if (i < pointer) begin
                    entry[i-1]     <= `SD entry[i];
                end
            end
            endcase
        end
    end
end


always_comb begin
    for (k=0;k<2;k++) begin
        load_value_valid[k] = 1'b0;
        load_value_o[k] = 0;
        for (j=`RETIRE_BUFFER_NUM-1; j>0; j--) begin
            if (valid[j]) begin
                if (load_addr_i[k] == entry[j].addr) begin
                    load_value_o[k] = entry[j].value;
                    load_value_valid[k] = 1'b1;
                end
            end
        end
    end
end



endmodule
