`timescale 1ns/100ps

module maptables #(
    parameter RAT_ENTRIES       = 32,
    parameter SCALAR            = 2
)(
    input logic clock,
    input logic reset,

    input logic stall,
    input logic rollback,
    //RAT packets
    input CDB_PACKET            [SCALAR  -1:0]   cdb_packet,
    input RAT_READ_INPACKET     [2*SCALAR-1:0]   rat_read_packet,
    input RAT_WRITE_INPACKET    [SCALAR  -1:0]   rat_write_packet,

    output RAT_READ_OUTPACKET   [2*SCALAR-1:0]   rat_packet,
    output [1:0] [`PREG_IDX_WIDTH-1:0]  T_old,

    //RRAT packets
    input   RRAT_WRITE_INPACKET   [SCALAR-1:0]      rrat_write_packet //write_en == retire_en
);

    RRAT_ENTRY  [RAT_ENTRIES-1:0]  rrat_copy_packet;

    RAT #(
        .numOfEntries(RAT_ENTRIES),
        .SCALAR(SCALAR)
    ) rat(
        .clock(clock),
        .reset(reset),

        .stall(stall),
        .rollback(rollback),

        //FIXME
        .rrat_write_packet(rrat_write_packet),

        //RAT operational packets
        .cdb_packet(cdb_packet),
        .rat_read_packet(rat_read_packet),
        .rat_write_packet(rat_write_packet),

        //packets from RRAT, for rollback
        .rrat_copy_packet(rrat_copy_packet),

        //RAT otuput packets
        .rat_packet(rat_packet),
        .T_old(T_old)

    );

    RRAT #(
        .SCALAR(SCALAR),
        .NUM_ENTRIES(RAT_ENTRIES),
        .PREG_IDX_WIDTH(5)
    ) rrat (
        .clock(clock),
        .reset(reset),
        .rollback(rollback),
        
        .rrat_write_packet(rrat_write_packet),
        .rrat_copy_packet(rrat_copy_packet)
    );

endmodule
