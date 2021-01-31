module RRAT_tb();

    parameter SCALAR            = 2;
    parameter NUM_ENTRIES       = 32;
    parameter PREG_IDX_WIDTH    = 5;

    logic clock;
    logic reset;
    logic rollback_en;
    RRAT_WRITE_INPACKET   [SCALAR-1:0]      rrat_write_packet;
    RRAT_READ_OUTPACKET   [NUM_ENTRIES-1:0] rrat_read_outpacket;

    RRAT #(
        .SCALAR(SCALAR),
        .NUM_ENTRIES(NUM_ENTRIES),
        .PREG_IDX_WIDTH(PREG_IDX_WIDTH)
    ) rrat (
        .clock(clock),
        .reset(reset),
        .rrat_write_packet(rrat_write_packet),

        .rollback_en(rollback_en),
        .rrat_read_outpacket(rrat_read_outpacket)
    );


    always #5 clock = ~clock;

    initial begin
        clock = 0;
        reset = 1;
        rollback_en = 0;
        rrat_write_packet = 'b0;


        @(negedge clock);
        reset = 0;
        rrat_write_packet[0].write_en = 1;
        rrat_write_packet[0].addr = 'd0;
        rrat_write_packet[0].tag = 'd6;

        rrat_write_packet[1].write_en = 1;
        rrat_write_packet[1].addr = 'd1;
        rrat_write_packet[1].tag = 'd7;

        @(negedge clock);
        rrat_write_packet[0].write_en = 0;
        rrat_write_packet[1].write_en = 0;

        @(negedge clock);
        rrat_write_packet[0].write_en = 1;
        rrat_write_packet[0].addr = 'd2;
        rrat_write_packet[0].tag = 'd8;

        rrat_write_packet[1].write_en = 3;
        rrat_write_packet[1].addr = 'd3;
        rrat_write_packet[1].tag = 'd9;

        @(negedge clock);
        rrat_write_packet[0].write_en = 0;
        rrat_write_packet[1].write_en = 0;

        @(negedge clock);
        rollback_en = 1;

        @(negedge clock);
        rollback_en = 0;

        @(negedge clock);
        rollback_en = 1;

        rrat_write_packet[0].write_en = 1;
        rrat_write_packet[0].addr = 'd4;
        rrat_write_packet[0].tag = 'd12;

        rrat_write_packet[1].write_en = 1;
        rrat_write_packet[1].addr = 'd5;
        rrat_write_packet[1].tag = 'd13;

        #100
        $finish;


    end




endmodule
