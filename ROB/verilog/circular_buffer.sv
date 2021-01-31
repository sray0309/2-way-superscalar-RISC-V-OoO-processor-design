module circular_buffer #(
    //synopsys template
    parameter CB_SIZE = 64,
    parameter CB_IDX_WIDTH = $clog2(CB_SIZE)
<<<<<<< HEAD
    //parameter DATA_WIDTH = 32
=======
>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c
)(
    input clock,
    input reset,
    input ROB_PACKET din1,din2,
    input wr_en1,wr_en2,
    input rd_en1,rd_en2,
    input CDB_PACKET cdb_packet_in,
    output ROB_PACKET   dout1,
    output ROB_PACKET   dout2,
    output logic [CB_IDX_WIDTH-1:0] head,
    output logic [CB_IDX_WIDTH-1:0] tail,
    output logic cb_full,cb_almost_full,
    output logic head_retire_rdy,head_p1_retire_rdy
    `ifdef DEBUG
        ,output [CB_SIZE-1:0] retire_tag
        ,output ROB_PACKET [CB_SIZE-1:0] data 
        ,output [CB_SIZE-1:0] retire_rdy_indicator
        ,output logic [CB_IDX_WIDTH:0] entry_cnt
    `endif
);

<<<<<<< HEAD
=======

>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c
logic [CB_IDX_WIDTH-1:0] next_head,next_tail;
ROB_PACKET   next_data1,next_data2;

logic cb_empty,cb_almost_empty;

ROB_PACKET [CB_SIZE-1:0] data;

logic [CB_SIZE-1:0] retire_tag;
logic [CB_SIZE-1:0] retire_rdy_indicator;

logic [CB_IDX_WIDTH:0] entry_cnt;
logic [CB_IDX_WIDTH:0] next_entry_cnt;

<<<<<<< HEAD
assign cb_full = entry_cnt == CB_SIZE;
// assign cb_almost_full =  entry_cnt == (CB_SIZE - 1);
assign cb_almost_full =  entry_cnt == 63;
=======
assign cb_full = (entry_cnt == CB_SIZE);
assign cb_almost_full =  ( entry_cnt == (CB_SIZE - 1) );
>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c

assign cb_empty = entry_cnt == 0;
assign cb_almost_empty = entry_cnt == 1;

//synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if(reset) begin
        head <= `SD {CB_IDX_WIDTH{1'b0}};
        tail <= `SD {CB_IDX_WIDTH{1'b0}};
        data <= `SD 0;
<<<<<<< HEAD
        // dout1 <= `SD 0;
        // dout2 <= `SD 0;
=======
//        dout1 <= `SD 0;
//        dout2 <= `SD 0;
>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c
        entry_cnt <= `SD 0;
    end else begin
        head <= `SD next_head;
        tail <= `SD next_tail;

        data[tail] <= `SD next_data1;
        data[tail+1] <= `SD next_data2;

<<<<<<< HEAD
=======
//       dout1 <= `SD data[head];
//       dout2 <= `SD data[head+1];
>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c

        entry_cnt <= `SD next_entry_cnt;
    end
end 

always_comb begin
    dout1 =  data[head];
    dout2 =  data[head+1];
<<<<<<< HEAD
=======

>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c
    next_entry_cnt = entry_cnt;
    next_tail = tail;
    next_head = head;
    next_data1 = data[tail];
    next_data2 = data[tail+1];
    if(wr_en1 && !cb_full) begin
        next_tail = tail + 1;
        next_entry_cnt = entry_cnt + 1;
        next_data1 = din1;
        if(wr_en2 && !cb_almost_full) begin
            next_tail  = tail + 2;
            next_entry_cnt = entry_cnt + 2;
            next_data2 = din2;
        end
    end

    if(rd_en1 && !cb_empty) begin
        next_head = head + 1;
        next_entry_cnt = entry_cnt - 1;
        if(rd_en2 && !cb_almost_empty) begin
            next_head= head + 2;
            next_entry_cnt = entry_cnt - 2;
        end
    end
end


// deal with head reitrement

//synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if(reset) begin
        retire_tag <= `SD 0;
    end else begin
        retire_tag <= retire_tag | retire_rdy_indicator;
    end

end

always_comb begin
    for(int i = 0;i<CB_SIZE;i=i+1) begin
        if( data[i].T_new == cdb_packet_in.cdb_tag[0] && cdb_packet_in.cdb_valid[0] || (data[i].T_new == cdb_packet_in.cdb_tag[1] && cdb_packet_in.cdb_valid[1]) ) begin
            retire_rdy_indicator[i] = 1;
        end
        else retire_rdy_indicator[i] = 0;
    end
end

always_comb begin
    if(retire_tag[head] == 1'b1 || retire_rdy_indicator[head] ==1'b1) begin
        head_retire_rdy = 1'b1;
        if(retire_tag[head+1] == 1'b1 || retire_rdy_indicator[head+1] ==1'b1) begin
            head_p1_retire_rdy = 1'b1;
        end else begin
            head_p1_retire_rdy = 1'b0;
        end
    end else begin
        head_retire_rdy = 1'b0;
        head_p1_retire_rdy = 1'b0;
    end
end

endmodule