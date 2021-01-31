`timescale 1ns/100ps

module rob #(
    parameter ROB_SIZE = 64,
    parameter ROB_IDX_WIDTH = $clog2(ROB_SIZE)
)(
    input clock,
    input reset,

    input dp_stall,
    input RN_DP_PACKET [1:0] rn_dp_packet_in,
    input CDB_PACKET   [1:0] cdb_packet_in,
    input EX_CM_PACKET [1:0] ex_packet_in,

    input  SQ_FU_PACKET [1:0] sq_fu_packet_in,

    output ROB_PACKET [1:0] rob_packet_out,
    output logic rob_full,rob_almost_full,

    output logic [$clog2(ROB_SIZE)-1:0] head, 
    output logic [$clog2(ROB_SIZE)-1:0] tail,

    output logic head_retire_rdy,head_p1_retire_rdy
    `ifdef DEBUG
        ,output logic [ROB_SIZE-1:0] retire_tag
        ,output ROB_PACKET [ROB_SIZE-1:0] data
        ,output logic [ROB_SIZE-1:0] retire_rdy_indicator
        ,output logic [$clog2(ROB_SIZE):0] entry_cnt
    `endif
);


ROB_PACKET [1:0] rob_entry;

logic wr_en1;
logic wr_en2;
logic rd_en1;
logic rd_en2;
ROB_PACKET dout1,dout2;

generate 
    genvar i;
    for(i=0;i<2;i=i+1) begin
        //assign rob_entry[i].NPC   =  rn_dp_packet_in[i].NPC;
        assign rob_entry[i].PC    =  rn_dp_packet_in[i].PC;

        assign rob_entry[i].T_new     =  rn_dp_packet_in[i].pdest_idx;
        assign rob_entry[i].T_old     =  rn_dp_packet_in[i].pdest_old;

        assign rob_entry[i].inst      =  rn_dp_packet_in[i].inst;
        // assign rob_entry[i].opa_select =  rn_dp_packet_in[i].opa_select;
        // assign rob_entry[i].opb_select =  rn_dp_packet_in[i].opb_select;
        // assign rob_entry[i].alu_func =  rn_dp_packet_in[i].alu_func;
        assign rob_entry[i].rd_mem =  rn_dp_packet_in[i].rd_mem;
        assign rob_entry[i].wr_mem =  rn_dp_packet_in[i].wr_mem;
        // assign rob_entry[i].cond_branch =  rn_dp_packet_in[i].cond_branch;
        // assign rob_entry[i].uncond_branch =  rn_dp_packet_in[i].uncond_branch;
        assign rob_entry[i].is_branch    =  rn_dp_packet_in[i].uncond_branch | rn_dp_packet_in[i].cond_branch;
        assign rob_entry[i].ex_take_branch  = 1'b0;
        assign rob_entry[i].ex_target_pc = {`XLEN{1'b0}};
        
        assign rob_entry[i].predict_take_branch  = rn_dp_packet_in[i].predict_take_branch;
        assign rob_entry[i].predict_target_pc    = rn_dp_packet_in[i].predict_target_pc;

        //--------------------debug use-----------------//
        assign rob_entry[i].cdb_value  = 0;
        assign rob_entry[i].adest = rn_dp_packet_in[i].adest_idx;
        //--------------------debug use-----------------//

        assign rob_entry[i].rd_mem_violation  = 1'b0;

        assign rob_entry[i].rob_idx   =  tail + i;
        assign rob_entry[i].halt      =  rn_dp_packet_in[i].halt;
        assign rob_entry[i].illegal   =  rn_dp_packet_in[i].illegal;
        // assign rob_entry[i].csr_op =  rn_dp_packet_in[i].csr_op;
        assign rob_entry[i].valid =  rn_dp_packet_in[i].valid;
    end
endgenerate

assign wr_en1 = rob_entry[0].valid && !rob_full & !dp_stall;
assign wr_en2 = rob_entry[1].valid && !rob_almost_full & !dp_stall;
assign rd_en1 = head_retire_rdy;
assign rd_en2 = head_retire_rdy && head_p1_retire_rdy;

circular_buffer #(.CB_SIZE(ROB_SIZE)) cb(
    .clock(clock),
    .reset(reset),

    .din1(rob_entry[0]),
    .din2(rob_entry[1]),
    .wr_en1(wr_en1),
    .wr_en2(wr_en2),
    .rd_en1(rd_en1),
    .rd_en2(rd_en2),
    .cdb_packet_in(cdb_packet_in),
    .ex_packet_in(ex_packet_in),

    .sq_fu_packet_in(sq_fu_packet_in),
    
    .dout1(rob_packet_out[0]),
    .dout2(rob_packet_out[1]),
    .head(head),
    .tail(tail),
    .cb_full(rob_full),
    .cb_almost_full(rob_almost_full),
    .head_retire_rdy(head_retire_rdy),
    .head_p1_retire_rdy(head_p1_retire_rdy)
 );

endmodule 




