module rob #(
    parameter ROB_SIZE = 64,
    parameter ROB_IDX_WIDTH = $clog2(ROB_SIZE)
)(
    input clock,
    input reset,

    input ID_PACKET [1:0] id_packet_in,
    input CDB_PACKET cdb_packet_in,
    input [1:0][`PREG_IDX_WIDTH-1:0] freelist_pdest_new,
    input [1:0][`PREG_IDX_WIDTH-1:0] rat_pdest_old,
    output ROB_PACKET [1:0] rob_packet_out,
    output logic rob_full,rob_almost_full
    `ifdef DEBUG
        ,output logic [ROB_SIZE-1:0] retire_tag
        ,output ROB_PACKET [ROB_SIZE-1:0] data
        ,output logic [$clog2(ROB_SIZE)-1:0] head, tail
        ,output logic [ROB_SIZE-1:0] retire_rdy_indicator
        ,output logic [$clog2(ROB_SIZE):0] entry_cnt
        ,output logic head_retire_rdy,head_p1_retire_rdy
    `endif
);


ROB_PACKET [1:0] rob_entry;

logic wr_en1;
logic wr_en2;
logic rd_en1;
logic rd_en2;
logic head_retire_rdy;
logic head_p1_retire_rdy;
logic [$clog2(ROB_SIZE)-1:0] head, tail;
ROB_PACKET dout1,dout2;

generate 
    genvar i;
    for(i=0;i<2;i=i+1) begin
        assign rob_entry[i].NPC   =  id_packet_in[i].NPC;
        assign rob_entry[i].PC    =  id_packet_in[i].PC;

        assign rob_entry[i].T_new =  freelist_pdest_new[i];
        assign rob_entry[i].T_old =  rat_pdest_old[i];

        assign rob_entry[i].inst  =  id_packet_in[i].inst;
        assign rob_entry[i].opa_select =  id_packet_in[i].opa_select;
        assign rob_entry[i].opb_select =  id_packet_in[i].opb_select;
        assign rob_entry[i].alu_func =  id_packet_in[i].alu_func;
        assign rob_entry[i].rd_mem =  id_packet_in[i].rd_mem;
        assign rob_entry[i].wr_mem =  id_packet_in[i].wr_mem;
        assign rob_entry[i].cond_branch =  id_packet_in[i].cond_branch;
        assign rob_entry[i].uncond_branch =  id_packet_in[i].uncond_branch;
        assign rob_entry[i].halt =  id_packet_in[i].halt;
        assign rob_entry[i].illegal =  id_packet_in[i].illegal;
        assign rob_entry[i].csr_op =  id_packet_in[i].csr_op;
        assign rob_entry[i].valid =  id_packet_in[i].valid;
    end
endgenerate

assign wr_en1 = rob_entry[0].valid && !rob_full;
assign wr_en2 = rob_entry[1].valid && !rob_almost_full;
assign rd_en1 = head_retire_rdy;
assign rd_en2 = head_retire_rdy && head_p1_retire_rdy;

<<<<<<< HEAD
circular_buffer #(.CB_SIZE(ROB_SIZE)) circular_buffer_0(
=======
circular_buffer #(.CB_SIZE(ROB_SIZE)) cb(
>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c
    .clock(clock),
    .reset(reset),

    .din1(rob_entry[0]),
    .din2(rob_entry[1]),
    .wr_en1(wr_en1),
    .wr_en2(wr_en2),
    .rd_en1(rd_en1),
    .rd_en2(rd_en2),
    .cdb_packet_in(cdb_packet_in),
    .dout1(rob_packet_out[0]),
    .dout2(rob_packet_out[1]),
    .head(head),
    .tail(tail),
    .cb_full(rob_full),
    .cb_almost_full(rob_almost_full),
    .head_retire_rdy(head_retire_rdy),
    .head_p1_retire_rdy(head_p1_retire_rdy)
    `ifdef DEBUG
        ,.retire_tag(retire_tag)
        ,.data(data)
        ,.retire_rdy_indicator(retire_rdy_indicator)
        ,.entry_cnt(entry_cnt)
    `endif
 );

endmodule 




