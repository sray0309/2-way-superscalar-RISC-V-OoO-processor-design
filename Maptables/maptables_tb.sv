module maptables_tb();

    parameter RAT_ENTRIES       = 32;
    parameter SCALAR            = 2;


    logic clock;
    logic reset;

    logic rollback;

    //RAT packets
    CDB_PACKET            [SCALAR  -1:0]   cdb_packet;
    RAT_READ_INPACKET     [2*SCALAR-1:0]   rat_read_packet;
    RAT_WRITE_INPACKET    [SCALAR  -1:0]   rat_write_packet;
    RAT_READ_OUTPACKET   [2*SCALAR-1:0]   rat_packet;

    //RRAT packets
    RRAT_WRITE_INPACKET   [SCALAR-1:0]      rrat_write_packet;

    maptables #(
        .RAT_ENTRIES(RAT_ENTRIES),
        .SCALAR(SCALAR)
    ) mt(
        .clock(clock),
        .reset(reset),
        .rollback(rollback),
        .cdb_packet(cdb_packet),
        .rat_read_packet(rat_read_packet),
        .rat_write_packet(rat_write_packet),
        .rat_packet(rat_packet),

        .rrat_write_packet(rrat_write_packet)        
    );

    always #5 clock = ~clock;

    initial begin
        clock = 0;
        reset = 1;
        rollback = 0;

        cdb_packet = 0;
        rat_read_packet = 0;
        rat_write_packet = 0;
        rrat_write_packet = 0;

        @(negedge clock);
        reset = 0;

        //RAT test
        @(negedge clock);
        rat_write_packet[0].addr = 'd0;
        rat_write_packet[0].tag = 'd4;
        rat_write_packet[0].write_en = 1;

        rat_write_packet[1].addr = 'd6;
        rat_write_packet[1].tag = 'd10;
        rat_write_packet[1].write_en = 1;

        @(negedge clock);
        rat_write_packet[0].write_en = 0;
        rat_write_packet[1].write_en = 0;

        @(negedge clock);
        @(negedge clock);
        cdb_packet[0].cdb_valid = 1;
        cdb_packet[0].tag   = 'd4;

        cdb_packet[1].cdb_valid = 1;
        cdb_packet[1].tag   = 'd10;

        @(negedge clock);
        cdb_packet[0].cdb_valid = 0;
        cdb_packet[1].cdb_valid = 0;

        //RAT test - read test
        rat_read_packet[0].addr = 'd0;
        rat_read_packet[0].read_en = 1;
        rat_read_packet[1].addr = 'd1;
        rat_read_packet[1].read_en = 1;
        rat_read_packet[2].addr = 'd4;
        rat_read_packet[2].read_en = 1;
        rat_read_packet[3].addr = 'd6;
        rat_read_packet[3].read_en = 1;

        //RRAT test
        @(negedge clock);
        rrat_write_packet[0].addr = 'd0;
        rrat_write_packet[0].tag = 'd4;
        rrat_write_packet[0].write_en = 1;

        rrat_write_packet[1].addr = 'd6;
        rrat_write_packet[1].tag = 'd10;
        rrat_write_packet[1].write_en = 0;

        //RRAT test - update 'd0 in RAT
        rat_write_packet[0].addr = 'd0;
        rat_write_packet[0].tag = 'd5;
        rat_write_packet[0].write_en = 1;

        @(negedge clock);
        //rollback to RRAT precise state
        rollback = 1;

        @(negedge clock);
        @(negedge clock);
        $finish;


    end



endmodule