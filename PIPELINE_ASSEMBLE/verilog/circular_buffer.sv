`timescale 1ns/100ps

module circular_buffer #(
    //synopsys template
    parameter CB_SIZE = 64,
    parameter CB_IDX_WIDTH = $clog2(CB_SIZE)
)(
    input clock,
    input reset,
    input ROB_PACKET din1,din2,
    input wr_en1,wr_en2,
    input rd_en1,rd_en2,
    input CDB_PACKET   [1:0] cdb_packet_in,
    input EX_CM_PACKET [1:0] ex_packet_in,

    input  SQ_FU_PACKET [1:0] sq_fu_packet_in,

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


logic [CB_IDX_WIDTH-1:0] tail_p1;
logic [CB_IDX_WIDTH-1:0] head_p1;


logic [CB_IDX_WIDTH-1:0] next_head,next_tail;
ROB_PACKET   next_data1,next_data2;

logic cb_empty,cb_almost_empty;

ROB_PACKET [CB_SIZE-1:0] data;

logic [CB_SIZE-1:0] retire_tag;
logic [CB_SIZE-1:0] n_retire_tag;
logic [CB_SIZE-1:0] retire_rdy_indicator;

logic [CB_IDX_WIDTH:0] entry_cnt;
logic [CB_IDX_WIDTH:0] next_entry_cnt;

logic dp_en1,dp_en2;
logic reti_en1,reti_en2;

assign cb_full = (entry_cnt == CB_SIZE);
assign cb_almost_full =  ( entry_cnt == (CB_SIZE - 1) );

assign cb_empty = entry_cnt == 0;
assign cb_almost_empty = entry_cnt == 1;

assign tail_p1  = tail + 1;
assign head_p1  = head + 1;

//synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if(reset) begin
        head <= `SD {CB_IDX_WIDTH{1'b0}};
        tail <= `SD {CB_IDX_WIDTH{1'b0}};
        data <= `SD 0;
        entry_cnt <= `SD 0;
    end else begin
        head <= `SD next_head;
        tail <= `SD next_tail;

        data[tail] <= `SD next_data1;
        data[tail_p1] <= `SD next_data2;

        if(ex_packet_in[0].branch_done && data[ex_packet_in[0].rob_idx].is_branch) begin
            data[ex_packet_in[0].rob_idx].ex_take_branch <= `SD ex_packet_in[0].take_branch;
            if(ex_packet_in[0].take_branch) begin 
                data[ex_packet_in[0].rob_idx].ex_target_pc   <= `SD ex_packet_in[0].result;
            end else begin
                data[ex_packet_in[0].rob_idx].ex_target_pc   <= `SD ex_packet_in[0].NPC;
            end
        end
        if(ex_packet_in[1].branch_done && data[ex_packet_in[1].rob_idx].is_branch) begin
            data[ex_packet_in[1].rob_idx].ex_take_branch <= `SD ex_packet_in[1].take_branch;
            if(ex_packet_in[1].take_branch) begin 
                data[ex_packet_in[1].rob_idx].ex_target_pc   <= `SD ex_packet_in[1].result;
            end else begin
                data[ex_packet_in[1].rob_idx].ex_target_pc   <= `SD ex_packet_in[1].NPC;
            end
        end

        if(sq_fu_packet_in[0].done && data[sq_fu_packet_in[0].ld_rob_idx].rd_mem) begin
            data[sq_fu_packet_in[0].ld_rob_idx].rd_mem_violation <= `SD sq_fu_packet_in[0].mem_violation;
        end

        if(sq_fu_packet_in[1].done && data[sq_fu_packet_in[1].ld_rob_idx].rd_mem) begin
            data[sq_fu_packet_in[1].ld_rob_idx].rd_mem_violation <= `SD sq_fu_packet_in[1].mem_violation;
        end

        if(reti_en1) begin
            data[head] <= `SD 0;
            if(reti_en2) begin
                data[head_p1] <= `SD 0;
            end
        end
        entry_cnt <= `SD next_entry_cnt;
    end
end 

assign dp_en1 = wr_en1 && !cb_full;
assign dp_en2 = wr_en2 && !cb_almost_full;
assign reti_en1 = rd_en1 && !cb_empty;
assign reti_en2 = rd_en2 && !cb_almost_empty;
always_comb begin
    dout1 = data[head];
    dout2 = data[head_p1];
    next_head = head;
    next_tail = tail;
    next_data1 = data[tail];
    next_data2 = data[tail_p1];
    next_entry_cnt = entry_cnt;
    case ({dp_en1,dp_en2,reti_en1,reti_en2})
        4'b0010:begin  //reti_en1 == 1
            next_head = head + 1;
            next_entry_cnt = entry_cnt - 1;
        end
        4'b0011:begin  // reti_en1 = reti_en2 = 1
            next_head= head + 2;
            next_entry_cnt = entry_cnt - 2;
        end
        4'b1000:begin // dp_en1 = 1
            next_tail = tail + 1;
            next_data1 = din1;
            next_entry_cnt = entry_cnt + 1;
        end
        4'b1100:begin // dp_en1 = dp_en2 = 1
            next_tail  = tail + 2;
            next_data1 = din1;
            next_data2 = din2;
            next_entry_cnt = entry_cnt + 2;
        end
        4'b1010:begin // dp_en1 = 1 , reti_en1= 1
            next_head = head + 1;
            next_tail = tail + 1;
            next_data1 = din1;
            next_entry_cnt = entry_cnt;
        end
        4'b1011:begin //dp_en1 = 1, reti_en1 = reti_en2 = 1
            next_head = head + 2;
            next_tail = tail + 1;
            next_data1 = din1;
            next_entry_cnt = entry_cnt -1;
        end
        4'b1110:begin //dp_en1 = dp_en2 = 1,reti_en1 = 1
            next_head = head + 1;
            next_tail = tail + 2;
            next_data1 = din1;
            next_data2 = din2;
            next_entry_cnt = entry_cnt + 1;
        end
        4'b1111:begin  // dp_en1 = dp_en2 = 1 , reti_en1 = reti_en2 = 1
            next_head = head + 2;
            next_tail = tail + 2;
            next_data1 = din1;
            next_data2 = din2;
            next_entry_cnt = entry_cnt;
        end
        default: begin
            next_head = head;
            next_tail = tail;
            next_data1 = data[tail];
            next_data2 = data[tail_p1];
            next_entry_cnt = entry_cnt;
        end
    endcase
end

// deal with head retirement
//synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if(reset) begin
        retire_tag <= `SD {CB_SIZE{1'b0}};
    end else begin
        retire_tag <= `SD n_retire_tag;
    end

end

always_comb begin
    for(int i = 0;i<CB_SIZE;i=i+1) begin
        //if( (data[i].T_new == cdb_packet_in[0].cdb_tag && cdb_packet_in[0].cdb_valid) || (data[i].T_new == cdb_packet_in[1].cdb_tag && cdb_packet_in[1].cdb_valid) ) begin
        if( ( i == cdb_packet_in[0].cdb_rob_idx && cdb_packet_in[0].cdb_valid && data[i].valid) || (i == cdb_packet_in[1].cdb_rob_idx && cdb_packet_in[1].cdb_valid && data[i].valid) )  begin
            retire_rdy_indicator[i] = 1;
        end
        else retire_rdy_indicator[i] = 0;
    end
end

always_comb begin
    n_retire_tag = retire_tag | retire_rdy_indicator;
    if(retire_tag[head] == 1'b1 || retire_rdy_indicator[head] == 1'b1) begin
        head_retire_rdy = 1'b1;
        n_retire_tag[head] = 1'b0;
        if(retire_tag[head_p1] == 1'b1 || retire_rdy_indicator[head_p1] == 1'b1) begin
            head_p1_retire_rdy = 1'b1;
            n_retire_tag[head_p1] = 1'b0;
        end else begin
            head_p1_retire_rdy = 1'b0;
        end
    end else begin
        head_retire_rdy = 1'b0;
        head_p1_retire_rdy = 1'b0;
    end
end

endmodule