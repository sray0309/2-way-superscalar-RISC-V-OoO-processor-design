`timescale 1ns/100ps

module dp_is_stage(
    input clock,
    input reset,

    input  dp_stall,
    input  [1:0] is_stall,

    input  RN_DP_PACKET [1:0]   rn_dp_packet_in,
    input  CDB_PACKET   [1:0]   cdb_packet_in,

    input  EX_CM_PACKET  [1:0]  ex_packet_in, //use for branch 

    input  SQ_FU_PACKET [1:0] sq_fu_packet_in, //use for memory vioalation

    input  [1:0][`LSQ_IDX_WIDTH-1:0] sq_idx,lq_idx,
    
    output IS_EX_PACKET [1:0]   is_packet_out, //issue packet

    output logic [1:0][`ROB_IDX_WIDTH-1:0] rob_idx,
    output logic [1:0] rs_full,

    output ROB_PACKET [1:0] rob_packet_out,
    output logic rob_full,
    output logic rob_almost_full,
    output logic head_retire_rdy,
    output logic head_p1_retire_rdy
);

logic [`ROB_IDX_WIDTH-1:0] head;
logic [`ROB_IDX_WIDTH-1:0] tail;

logic [1:0][`ROB_IDX_WIDTH-1:0] dp_rob_idx;

logic [1:0][`LSQ_IDX_WIDTH-1:0] dp_sq_idx,dp_lq_idx;

assign dp_rob_idx[0] =  tail;
assign dp_rob_idx[1] =  tail  + 1;

assign rob_idx = dp_rob_idx;

assign dp_sq_idx[0] = sq_idx[0];
assign dp_sq_idx[1] = sq_idx[1];

assign dp_lq_idx[0] = lq_idx[0];
assign dp_lq_idx[1] = lq_idx[1];

rs_super rs_super_0(
    .clock(clock),
    .reset(reset),

    //input
    .dp_stall(dp_stall),
    .is_stall(is_stall),

    .rob_idx(dp_rob_idx),

    .sq_idx(dp_sq_idx),
    .lq_idx(dp_lq_idx),

    .rn_dp_packet_in(rn_dp_packet_in),
    .cdb_packet_in(cdb_packet_in),

    //output
    .rs_packet_out(is_packet_out),
    .rs_full(rs_full)
);

rob #(
    .ROB_SIZE(`ROB_SIZE)
) rob_0(
    .clock(clock),
    .reset(reset),
    //input
    .dp_stall(dp_stall),
    .rn_dp_packet_in(rn_dp_packet_in),
    .cdb_packet_in(cdb_packet_in),

    .ex_packet_in(ex_packet_in),

    .sq_fu_packet_in(sq_fu_packet_in),
    //output
    .rob_packet_out(rob_packet_out),
    .rob_full(rob_full),
    .rob_almost_full(rob_almost_full),

    .head(head),
    .tail(tail),
    .head_retire_rdy(head_retire_rdy),
    .head_p1_retire_rdy(head_p1_retire_rdy)
);


endmodule