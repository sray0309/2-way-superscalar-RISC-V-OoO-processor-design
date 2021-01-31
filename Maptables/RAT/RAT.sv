module RAT #(
    parameter numOfEntries      = 64,
    parameter SCALAR     = 2
)(
    input logic clock,
    input logic reset,
    input logic rollback,

    input CDB_PACKET            [SCALAR  -1:0]   cdb_packet,
    input RAT_READ_INPACKET     [2*SCALAR-1:0]   rat_read_packet,
    input RAT_WRITE_INPACKET    [SCALAR  -1:0]   rat_write_packet,

    input RRAT_ENTRY            [numOfEntries-1:0]  rrat_copy_packet,

    output RAT_READ_OUTPACKET   [2*SCALAR-1:0]   rat_packet
    output [1:0] [`PREG_IDX_WIDTH-1:0]  T_old;

);

    RAT_ENTRY [numOfEntries-1:0]    rat_entries;

    assign T_old[0] = rat_entries[rat_write_packet[0].addr];
    assign T_old[1] = rat_entries[rat_write_packet[1].addr];

    genvar i,j;
    generate;
    for (i=0; i<SCALAR; i++) begin: read_gen_inst
        for (j=0; j<2; j++) begin: read_gen_tag
            always_comb begin
                if(i == 1 && rat_write_packet[0].write_en && rat_read_packet[2*i+j].addr == rat_write_packet[0].addr) begin
                    rat_packet[2*i+j].tag = rat_write_packet[0].tag;
                    rat_packet[2*i+j].preg_ready = 0;
                end else if (rat_read_packet[2*i+j].read_en) begin
                    rat_packet[2*i+j].tag = rat_entries[rat_read_packet[2*i+j].addr].rat_tag;
                    rat_packet[2*i+j].preg_ready = rat_entries[rat_read_packet[2*i+j].addr].preg_ready;
                end else begin
                    rat_packet[2*i+j].tag = 0;
                    rat_packet[2*i+j].preg_ready = 0;
                end

                if (cdb_packet[0].cdb_valid && cdb_packet[0].tag == rat_packet[2*i+j].tag) begin
                    rat_packet[2*i+j].preg_ready = 1;
                end else if (cdb_packet[1].cdb_valid && cdb_packet[1].tag == rat_packet[2*i+j].tag) begin
                    rat_packet[2*i+j].preg_ready = 1;
                end
            end
        end
    end
    endgenerate

    always_ff @(posedge clock) begin
        if (reset) begin
            for (int d=0; d<numOfEntries; d++) begin
                rat_entries[d].preg_ready <= 1;
                rat_entries[d].rat_tag <= d;
            end
        end else if (rollback) begin
            for (int d=0; d<numOfEntries; d++) begin
                rat_entries[d].preg_ready <= 1;
                rat_entries[d].rat_tag <= rrat_copy_packet[d].rrat_tag;
            end
        end else begin
            for (int r=0; r<SCALAR; r++) begin
                if (rat_write_packet[r].write_en) begin
                    rat_entries[rat_write_packet[r].addr].rat_tag <= rat_write_packet[r].tag;
                    rat_entries[rat_write_packet[r].addr].preg_ready <= 0;
                end 
            end
               
            for (int d=0; d<numOfEntries; d++) begin
                for (int r=0; r<SCALAR; r++) begin
                    if (cdb_packet[r].cdb_valid && rat_entries[d].rat_tag == cdb_packet[r].tag) begin
                        rat_entries[d].preg_ready <= 1;
                    end else begin
                    end
                end
            end
        end     
    end

    
endmodule