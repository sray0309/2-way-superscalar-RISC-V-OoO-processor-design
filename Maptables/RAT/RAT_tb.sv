module RAT_tb();

    parameter numOfRequests = 2;
    parameter numOfEntries = 32;

    logic clock;
    logic reset;

    RAT_READ_INPACKET  [ 2*numOfRequests   - 1 : 0 ]   rat_read_packet;
    RAT_WRITE_INPACKET [ numOfRequests     - 1 : 0 ]   rat_write_packet;

    RAT_READ_OUTPACKET [ 2*numOfRequests  - 1 : 0 ]   rat_packet;
    RAT_READ_OUTPACKET [ 2*numOfRequests  - 1 : 0 ]   correct_packet;

    CDB_PACKET    [numOfRequests-1:0]             cdb_packet;

    RAT #(.numOfEntries(numOfEntries), .numOfRequests(numOfRequests)) rat(
        .clock(clock),
        .reset(reset),
        .cdb_packet(cdb_packet),

        .rat_read_packet(rat_read_packet),
        .rat_write_packet(rat_write_packet),
        .rat_packet(rat_packet)
    );

  task check_result;
    input RAT_READ_OUTPACKET [2*numOfRequests-1:0] read_packets;
    input RAT_READ_OUTPACKET [2*numOfRequests-1:0] correct_packet;

    integer i;
  
    for (i=0; i<2*numOfRequests; i++) begin
      if (read_packets[i].tag == correct_packet[i].tag && read_packets[i].preg_ready == correct_packet[i].preg_ready) begin
      end else begin
        $display("@@@ Incorrect result at TIME: %.4f", $time);
        $display("read packet, tag: %h, preg_ready: %b", read_packets[i].tag, read_packets[i].preg_ready);
        $display("correct packet, tag: %h, preg_ready: %b", correct_packet[i].tag, correct_packet[i].preg_ready);
        $display("@@@ Failed");
        $finish;
      end
        
    end
  endtask;


    always #5 clock = ~clock;

    initial begin
        clock = 0;
        reset = 1;

        rat_read_packet = 'b0;
        rat_write_packet = 'b0;
        cdb_packet = 'b0;

        // check initial values in RAT
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        rat_read_packet[0].addr = 'd0;
        rat_read_packet[1].addr = 'd5;
        rat_read_packet[2].addr = 'd7;
        rat_read_packet[3].addr = 'd12;

        rat_read_packet[0].read_en = 1;
        rat_read_packet[1].read_en = 1;
        rat_read_packet[2].read_en = 1;
        rat_read_packet[3].read_en = 1;

        correct_packet[0].tag = 'd0;
        correct_packet[1].tag = 'd5;
        correct_packet[2].tag = 'd7;
        correct_packet[3].tag = 'd12;
        correct_packet[0].preg_ready = 1;
        correct_packet[1].preg_ready = 1;
        correct_packet[2].preg_ready = 1;
        correct_packet[3].preg_ready = 1;
        #1
        check_result(rat_packet, correct_packet);

        
        // ###########################
        // rat_write_packet[0] write enable triggered
        @(negedge clock);
        rat_write_packet[0].addr = 'd0;
        rat_write_packet[0].tag = 'd4;
        rat_write_packet[0].write_en = 1;

        rat_write_packet[1].addr = 'd12;
        rat_write_packet[1].tag = 'd31;
        rat_write_packet[1].write_en = 0;

        // check if rat_entries[rat_write_packet[0].addr] is updated
        @(negedge clock);
        rat_write_packet[0].write_en = 0;

        @(negedge clock);
        rat_read_packet[0].addr = 'd0;
        rat_read_packet[1].addr = 'd5;
        rat_read_packet[2].addr = 'd7;
        rat_read_packet[3].addr = 'd12;
     
        correct_packet[0].tag = 'd4;
        correct_packet[1].tag = 'd5;
        correct_packet[2].tag = 'd7;
        correct_packet[3].tag = 'd12;
        correct_packet[0].preg_ready = 0;
        correct_packet[1].preg_ready = 1;
        correct_packet[2].preg_ready = 1;
        correct_packet[3].preg_ready = 1;
        #1
        check_result(rat_packet, correct_packet);
        // #######################################




        // #######################################
        // rat_write_packet[1] and rat_write_packet[2] write enables triggered
        @(negedge clock);

        rat_write_packet[1].addr = 'd12;
        rat_write_packet[1].tag = 'd31;
        rat_write_packet[1].write_en = 1;

        // check if rat_entries[rat_write_packet[1].addr] and rat_entries[rat_write_packet[2].addr] are updated
        @(negedge clock);
        rat_write_packet[1].write_en = 0;

        @(negedge clock);
        rat_read_packet[0].addr = 'd0;
        rat_read_packet[1].addr = 'd5;
        rat_read_packet[2].addr = 'd7;
        rat_read_packet[3].addr = 'd12;
        
        correct_packet[0].tag = 'd4;
        correct_packet[1].tag = 'd5;
        correct_packet[2].tag = 'd7;
        correct_packet[3].tag = 'd31;
        correct_packet[0].preg_ready = 0;
        correct_packet[1].preg_ready = 1;
        correct_packet[2].preg_ready = 1;
        correct_packet[3].preg_ready = 0;
        #1
        check_result(rat_packet, correct_packet);


        // check cdb_packet updates
        @(negedge clock);
        cdb_packet[0].cdb_valid = 1;
        cdb_packet[0].tag   = 'd4;

        cdb_packet[1].cdb_valid = 1;
        cdb_packet[1].tag   = 'd31;

        correct_packet[0].tag = 'd4;
        correct_packet[1].tag = 'd5;
        correct_packet[2].tag = 'd7;
        correct_packet[3].tag = 'd31;
        correct_packet[0].preg_ready = 0;
        correct_packet[1].preg_ready = 1;
        correct_packet[2].preg_ready = 1;
        correct_packet[3].preg_ready = 0;
        #1
        check_result(rat_packet, correct_packet);


        @(negedge clock);
        correct_packet[0].tag = 'd4;
        correct_packet[1].tag = 'd5;
        correct_packet[2].tag = 'd7;
        correct_packet[3].tag = 'd31;
        correct_packet[0].preg_ready = 1;
        correct_packet[1].preg_ready = 1;
        correct_packet[2].preg_ready = 1;
        correct_packet[3].preg_ready = 1;
        #1
        check_result(rat_packet, correct_packet);

        @(negedge clock);
        reset = 1;
        repeat(2) @(negedge clock);
        reset = 0;
        @(negedge clock);
        ///// dispatch first inst
        rat_write_packet[0].addr = 'd0;
        rat_write_packet[0].tag = 'd12;
        rat_write_packet[0].write_en = 1;
        rat_read_packet[0].addr = 'd0;
        rat_read_packet[0].read_en = 1;
        rat_read_packet[1].addr = 'd1;
        rat_read_packet[1].read_en = 1;
        ///// dispatch second inst
        rat_write_packet[1].addr = 'd0;
        rat_write_packet[1].tag = 'd13;
        rat_write_packet[1].write_en = 1;
        rat_read_packet[2].addr = 'd0;
        rat_read_packet[2].read_en = 1;
        rat_read_packet[3].addr = 'd3;
        rat_read_packet[3].read_en = 1;

        correct_packet[0].preg_ready = 1;
        correct_packet[1].preg_ready = 1;
        correct_packet[2].preg_ready = 0;
        correct_packet[3].preg_ready = 1;
        correct_packet[0].tag = 'd0;
        correct_packet[1].tag = 'd1;
        correct_packet[2].tag = 'd12;
        correct_packet[3].tag = 'd3;
        #1
        check_result(rat_packet, correct_packet);

        @(negedge clock);
        rat_write_packet[0].write_en = 0;
        rat_write_packet[1].write_en = 0;

        correct_packet[0].preg_ready = 0;
        correct_packet[1].preg_ready = 1;
        correct_packet[2].preg_ready = 0;
        correct_packet[3].preg_ready = 1;
        correct_packet[0].tag = 'd13;
        correct_packet[1].tag = 'd1;
        correct_packet[2].tag = 'd13;
        correct_packet[3].tag = 'd3;
        #1
        check_result(rat_packet, correct_packet);
        
        #200
        $display("@@@ Correct");
        $finish;

    end




endmodule
