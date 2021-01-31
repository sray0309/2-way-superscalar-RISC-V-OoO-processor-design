`timescale 1ns/100ps

module rn_stage(
    input         clock,              // system clock
	input         reset,              // system reset

    input rn_stall,
    input rollback_en,

    input CDB_PACKET    [1:0]  cdb_packet_in,
    input ID_RN_PACKET  [1:0]  id_rn_packet_in,
    input RRAT_WRITE_INPACKET [1:0] rrat_write_packet_in,
    input ROB_PACKET [1:0] rob_retire_in,
    input                  retire1, retire2,
    output RN_DP_PACKET [1:0] rn_packet_out

);

RAT_READ_INPACKET  [3:0] rat_read_packet;
RAT_WRITE_INPACKET [1:0] rat_write_packet;
RAT_READ_OUTPACKET [3:0] rat_packet;
logic [1:0] [`PREG_IDX_WIDTH-1:0]  T_idx;
logic [1:0] [`PREG_IDX_WIDTH-1:0]  T_old;

logic [3:0] [`PREG_IDX_WIDTH-1:0] rn_preg;
logic [3:0] rn_preg_ready;

logic [1:0] dispatch_en;
logic [1:0] retire_en;

logic [1:0][`PREG_IDX_WIDTH-1:0] retire_T_old;



assign dispatch_en[0] = id_rn_packet_in[0].valid && id_rn_packet_in[0].adest_idx != `ZERO_REG;
assign dispatch_en[1] = id_rn_packet_in[1].valid && id_rn_packet_in[1].adest_idx != `ZERO_REG;

assign retire_en[0] = retire1 && rob_retire_in[0].T_old != `ZERO_PREG && !rob_retire_in[0].rd_mem_violation;
assign retire_en[1] = retire2 && rob_retire_in[1].T_old != `ZERO_PREG && !rob_retire_in[1].rd_mem_violation && !rob_retire_in[0].rd_mem_violation && !(rollback_en && !rob_retire_in[1].is_branch);


assign rat_read_packet[0] = {id_rn_packet_in[0].valid,
                             id_rn_packet_in[0].arega_idx};

assign rat_read_packet[1] = {id_rn_packet_in[0].valid,
                             id_rn_packet_in[0].aregb_idx};

assign rat_read_packet[2] = {id_rn_packet_in[1].valid,
                             id_rn_packet_in[1].arega_idx};

assign rat_read_packet[3] = {id_rn_packet_in[1].valid,
                             id_rn_packet_in[1].aregb_idx};

assign rat_write_packet[0] = {id_rn_packet_in[0].valid,
                              id_rn_packet_in[0].adest_idx,
                              T_idx[0]};
assign rat_write_packet[1] = {id_rn_packet_in[1].valid,
                              id_rn_packet_in[1].adest_idx,
                              T_idx[1]};

assign rn_preg_ready[0] = (id_rn_packet_in[0].halt || id_rn_packet_in[0].illegal /*|| id_rn_packet_in[0].opa_select != OPA_IS_RS1*/) ? 1'b1:rat_packet[0].preg_ready;
assign rn_preg_ready[1] = (id_rn_packet_in[0].halt || id_rn_packet_in[0].illegal /*|| id_rn_packet_in[0].opb_select != OPB_IS_RS2*/) ? 1'b1:rat_packet[1].preg_ready;
assign rn_preg_ready[2] = (id_rn_packet_in[1].halt || id_rn_packet_in[1].illegal /*|| id_rn_packet_in[1].opa_select != OPA_IS_RS1*/) ? 1'b1:rat_packet[2].preg_ready;
assign rn_preg_ready[3] = (id_rn_packet_in[1].halt || id_rn_packet_in[1].illegal /*|| id_rn_packet_in[1].opb_select != OPB_IS_RS2*/) ? 1'b1:rat_packet[3].preg_ready;

assign rn_preg[0] = (id_rn_packet_in[0].halt || id_rn_packet_in[0].illegal /*|| id_rn_packet_in[0].opa_select != OPA_IS_RS1*/) ? 0:rat_packet[0].tag;
assign rn_preg[1] = (id_rn_packet_in[0].halt || id_rn_packet_in[0].illegal /*|| id_rn_packet_in[0].opb_select != OPB_IS_RS2*/) ? 0:rat_packet[1].tag;
assign rn_preg[2] = (id_rn_packet_in[1].halt || id_rn_packet_in[1].illegal /*|| id_rn_packet_in[1].opa_select != OPA_IS_RS1*/) ? 0:rat_packet[2].tag;
assign rn_preg[3] = (id_rn_packet_in[1].halt || id_rn_packet_in[1].illegal /*|| id_rn_packet_in[1].opb_select != OPB_IS_RS2*/) ? 0:rat_packet[3].tag;

assign rn_packet_out[0] = {
    id_rn_packet_in[0].NPC,
    id_rn_packet_in[0].PC,
    id_rn_packet_in[0].predict_take_branch,
    id_rn_packet_in[0].predict_target_pc,
    rn_preg[0],
    rn_preg[1],
    T_idx[0],
    T_old[0],
    rn_preg_ready[0],
    rn_preg_ready[1],
    id_rn_packet_in[0].opa_select,
    id_rn_packet_in[0].opb_select,
    id_rn_packet_in[0].inst,
    id_rn_packet_in[0].alu_func,
    id_rn_packet_in[0].rd_mem,
    id_rn_packet_in[0].wr_mem,
    id_rn_packet_in[0].cond_branch,
    id_rn_packet_in[0].uncond_branch,
    id_rn_packet_in[0].halt,
    id_rn_packet_in[0].illegal,
    id_rn_packet_in[0].csr_op,
    id_rn_packet_in[0].valid
};


assign rn_packet_out[1] = {
    id_rn_packet_in[1].NPC,
    id_rn_packet_in[1].PC,
    id_rn_packet_in[1].predict_take_branch,
    id_rn_packet_in[1].predict_target_pc,
    rn_preg[2],
    rn_preg[3],
    T_idx[1],
    T_old[1],
    rn_preg_ready[2],
    rn_preg_ready[3],
    id_rn_packet_in[1].opa_select,
    id_rn_packet_in[1].opb_select,
    id_rn_packet_in[1].inst,
    id_rn_packet_in[1].alu_func,
    id_rn_packet_in[1].rd_mem,
    id_rn_packet_in[1].wr_mem,
    id_rn_packet_in[1].cond_branch,
    id_rn_packet_in[1].uncond_branch,
    id_rn_packet_in[1].halt,
    id_rn_packet_in[1].illegal,
    id_rn_packet_in[1].csr_op,
    id_rn_packet_in[1].valid
};

maptables maptables_0(
    .clock(clock),
    .reset(reset),

    //input
    .stall(rn_stall),
    .rollback(rollback_en),
    .cdb_packet(cdb_packet_in),
    .rat_read_packet(rat_read_packet),
    .rat_write_packet(rat_write_packet),
    .rrat_write_packet(rrat_write_packet_in),
    //output
    .rat_packet(rat_packet),
    .T_old(T_old)
);



// freelist freelist_0(
//     .clock(clock),
//     .reset(reset),
    
//     //input
//     .stall(rn_stall),
//     .rollback_en(rollback_en),
//     .dispatch_en(dispatch_valid),
//     .retire_en({retire2,retire1}),
//     .decoder_FL_out_dest_idx({id_rn_packet_in[1].adest_idx,id_rn_packet_in[0].adest_idx}),
//     .ROB_FL_out_Told_idx({rob_retire_in[1].T_old,rob_retire_in[0].T_old}), // from retire rob
//     // .ROB_FL_out_T_idx(rob_retire_in.Tnew),    // from retire rob
//     .ROB_FL_out_T_idx(branch_T_old),
//     //output
//     .FL_valid(),
//     .T_idx(T_idx)
// );

// always_comb begin
//     branch_T_old = 0;
//     if(rob_retire_in[0].is_branch && rob_retire_in[1].is_branch) begin
//         branch_T_old = rob_retire_in[0].T_old;
//     end

//     if(rob_retire_in[0].is_branch) begin
//         branch_T_old = rob_retire_in[0].T_old;
//     end

//     if(rob_retire_in[1].is_branch) begin
//         branch_T_old = rob_retire_in[1].T_old;
//     end
// end

freelist freelist_0(
    .clock(clock),
    .reset(reset),
    .rollback_en(rollback_en),

    .wr_en0(retire_en[0]),
    .wr_en1(retire_en[1]),
    .din0(rob_retire_in[0].T_old),
    .din1(rob_retire_in[1].T_old),
    .dp_stall(rn_stall),
    .rd_en0(dispatch_en[0]),
    .rd_en1(dispatch_en[1]),
    .dout0(T_idx[0]),
    .dout1(T_idx[1]),
    .fl_empty(),
    .fl_almost_empty()
);

endmodule
