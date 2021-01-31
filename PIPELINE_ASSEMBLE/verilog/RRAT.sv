`timescale 1ns/100ps

module RRAT #(
    parameter SCALAR            = 2,
    parameter NUM_ENTRIES       = 32,
    parameter PREG_IDX_WIDTH    = 5
)(
    input   logic           clock,
    input   logic           reset,
    input   RRAT_WRITE_INPACKET   [SCALAR-1:0]      rrat_write_packet, //write_en == retire_en
    input   logic                                   rollback,    
    output  RRAT_READ_OUTPACKET   [NUM_ENTRIES-1:0] rrat_copy_packet

);

    RRAT_ENTRY  [NUM_ENTRIES    - 1 : 0] rrat_entries;

    always_comb begin
        if (rollback) begin
            for (int i=0; i<NUM_ENTRIES; i++) begin
                if (rrat_write_packet[0].write_en && rrat_write_packet[0].addr == i) begin
                    rrat_copy_packet[i].tag = rrat_write_packet[0].tag;
                end else if (rrat_write_packet[1].write_en && rrat_write_packet[1].addr == i) begin
                    rrat_copy_packet[i].tag = rrat_write_packet[1].tag;
                end else begin
                    rrat_copy_packet[i].tag = rrat_entries[i].rrat_tag;
                end
            end
        end else begin
            for (int i=0; i<NUM_ENTRIES; i++) begin
                rrat_copy_packet[i].tag = 0;
            end
        end
            
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            for(int i=0; i<NUM_ENTRIES; i++) begin: init_entries
                rrat_entries[i].rrat_tag <= `SD i;
            end
        end else begin
            for (int i=0; i<NUM_ENTRIES; i++) begin: write_entries
                for (int j=0; j<SCALAR; j++) begin: write_packet
                    if (rrat_write_packet[j].write_en && rrat_write_packet[j].addr == i) begin
                        rrat_entries[rrat_write_packet[j].addr].rrat_tag <= `SD rrat_write_packet[j].tag;
                    end else begin
                    end
                end
            end
        end
    end

    
    
endmodule
