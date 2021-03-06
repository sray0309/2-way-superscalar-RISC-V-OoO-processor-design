`timescale 1ns/100ps

module rs_super(
    input clock,
    input reset,

    input dp_stall,
    input [1:0] is_stall,

    input [1:0][`ROB_IDX_WIDTH-1:0] rob_idx,

    input [1:0][`LSQ_IDX_WIDTH-1:0] sq_idx,lq_idx,
    
    input RN_DP_PACKET [1:0] rn_dp_packet_in,
    input CDB_PACKET   [1:0] cdb_packet_in, 

    output IS_EX_PACKET [1:0] rs_packet_out,
    output logic [1:0] rs_full
);

logic [1:0] rs_enable;

logic [1:0] cdb_valid;
logic [1:0][`PREG_IDX_WIDTH-1:0] cdb_tag;

logic [1:0] ld_issue_stall;

assign cdb_valid = {cdb_packet_in[1].cdb_valid,cdb_packet_in[0].cdb_valid};
assign cdb_tag   = {cdb_packet_in[1].cdb_tag,cdb_packet_in[0].cdb_tag};


assign rs_enable[0] = rn_dp_packet_in[0].valid & (~rs_full[0]) & !dp_stall;
assign rs_enable[1] = rn_dp_packet_in[1].valid & (~rs_full[1]) & !dp_stall;

rs_bank rs_bank_0(
    .clock(clock),
    .reset(reset),

    .rsbank_enable(rs_enable[0]),
    .is_stall(is_stall[0]),

    .ld_issue_stall_i(ld_issue_stall[1]),

    .NPC(rn_dp_packet_in[0].NPC),
    .PC(rn_dp_packet_in[0].PC),
    .rob_idx(rob_idx[0]),

    .sq_idx(sq_idx[0]),
    .lq_idx(lq_idx[0]),

    .prega_idx_in(rn_dp_packet_in[0].prega_idx),
    .pregb_idx_in(rn_dp_packet_in[0].pregb_idx),
    .pdest_idx_in(rn_dp_packet_in[0].pdest_idx),
    .prega_ready_in(rn_dp_packet_in[0].prega_ready),
    .pregb_ready_in(rn_dp_packet_in[0].pregb_ready),
    .opa_select(rn_dp_packet_in[0].opa_select),
    .opb_select(rn_dp_packet_in[0].opb_select),
    .inst_in(rn_dp_packet_in[0].inst),
    .alu_func(rn_dp_packet_in[0].alu_func),
    .rd_mem(rn_dp_packet_in[0].rd_mem),
    .wr_mem(rn_dp_packet_in[0].wr_mem),
    .cond_branch(rn_dp_packet_in[0].cond_branch),
    .uncond_branch(rn_dp_packet_in[0].uncond_branch),
    .halt(rn_dp_packet_in[0].halt),
    .illegal(rn_dp_packet_in[0].illegal),
    .csr_op(rn_dp_packet_in[0].csr_op),
    .valid(rn_dp_packet_in[0].valid),

    .cdb_valid(cdb_valid),
    .cdb_tag(cdb_tag),

    .NPC_out(rs_packet_out[0].NPC),
    .PC_out(rs_packet_out[0].PC), 
    .rob_idx_out(rs_packet_out[0].rob_idx),

    .sq_idx_out(rs_packet_out[0].sq_idx),
    .lq_idx_out(rs_packet_out[0].lq_idx),

    .prega_idx_out(rs_packet_out[0].prega_idx),
    .pregb_idx_out(rs_packet_out[0].pregb_idx),
    .pdest_idx_out(rs_packet_out[0].pdest_idx),
    .opa_select_out(rs_packet_out[0].opa_select),
    .opb_select_out(rs_packet_out[0].opb_select),
    .inst_out(rs_packet_out[0].inst),
    .alu_func_out(rs_packet_out[0].alu_func),
    .rd_mem_out(rs_packet_out[0].rd_mem),
    .wr_mem_out(rs_packet_out[0].wr_mem),
    .cond_branch_out(rs_packet_out[0].cond_branch),   
	.uncond_branch_out(rs_packet_out[0].uncond_branch), 
	.halt_out(rs_packet_out[0].halt),          
	.illegal_out(rs_packet_out[0].illegal),  
	.csr_op_out(rs_packet_out[0].csr_op),
	.valid_out(rs_packet_out[0].valid),

    .ALU_ready(rs_packet_out[0].ALU_ready),
    .STORE_ready(rs_packet_out[0].STORE_ready),
    .LOAD_ready(rs_packet_out[0].LOAD_ready),

    .MULT_ready(rs_packet_out[0].MULT_ready),
    .BR_ready(rs_packet_out[0].BR_ready),

    .ld_issue_stall_o(ld_issue_stall[0]),

    .rs_full(rs_full[0])
);

rs_bank rs_bank_1(
    .clock(clock),
    .reset(reset),

    .rsbank_enable(rs_enable[1]),
    .is_stall(is_stall[1]),

    .ld_issue_stall_i(ld_issue_stall[0]),

    .NPC(rn_dp_packet_in[1].NPC),
    .PC(rn_dp_packet_in[1].PC),
    .rob_idx(rob_idx[1]),

    .sq_idx(sq_idx[1]),
    .lq_idx(lq_idx[1]),

    .prega_idx_in(rn_dp_packet_in[1].prega_idx),
    .pregb_idx_in(rn_dp_packet_in[1].pregb_idx),
    .pdest_idx_in(rn_dp_packet_in[1].pdest_idx),
    .prega_ready_in(rn_dp_packet_in[1].prega_ready),
    .pregb_ready_in(rn_dp_packet_in[1].pregb_ready),
    .opa_select(rn_dp_packet_in[1].opa_select),
    .opb_select(rn_dp_packet_in[1].opb_select),
    .inst_in(rn_dp_packet_in[1].inst),
    .alu_func(rn_dp_packet_in[1].alu_func),
    .rd_mem(rn_dp_packet_in[1].rd_mem),
    .wr_mem(rn_dp_packet_in[1].wr_mem),
    .cond_branch(rn_dp_packet_in[1].cond_branch),
    .uncond_branch(rn_dp_packet_in[1].uncond_branch),
    .halt(rn_dp_packet_in[1].halt),
    .illegal(rn_dp_packet_in[1].illegal),
    .csr_op(rn_dp_packet_in[1].csr_op),
    .valid(rn_dp_packet_in[1].valid),

    .cdb_valid(cdb_valid),
    .cdb_tag(cdb_tag),

    .NPC_out(rs_packet_out[1].NPC),
    .PC_out(rs_packet_out[1].PC), 
    .rob_idx_out(rs_packet_out[1].rob_idx),

    .sq_idx_out(rs_packet_out[1].sq_idx),
    .lq_idx_out(rs_packet_out[1].lq_idx),

    .prega_idx_out(rs_packet_out[1].prega_idx),
    .pregb_idx_out(rs_packet_out[1].pregb_idx),
    .pdest_idx_out(rs_packet_out[1].pdest_idx),
    .opa_select_out(rs_packet_out[1].opa_select),
    .opb_select_out(rs_packet_out[1].opb_select),   
    .inst_out(rs_packet_out[1].inst),
    .alu_func_out(rs_packet_out[1].alu_func),
    .rd_mem_out(rs_packet_out[1].rd_mem),
    .wr_mem_out(rs_packet_out[1].wr_mem),
    .cond_branch_out(rs_packet_out[1].cond_branch),   
	.uncond_branch_out(rs_packet_out[1].uncond_branch), 
	.halt_out(rs_packet_out[1].halt),          
	.illegal_out(rs_packet_out[1].illegal),  
	.csr_op_out(rs_packet_out[1].csr_op),
	.valid_out(rs_packet_out[1].valid),

    .ALU_ready(rs_packet_out[1].ALU_ready),
    .STORE_ready(rs_packet_out[1].STORE_ready),
    .LOAD_ready(rs_packet_out[1].LOAD_ready),

    .MULT_ready(rs_packet_out[1].MULT_ready),
    .BR_ready(rs_packet_out[1].BR_ready),

    .ld_issue_stall_o(ld_issue_stall[1]),
    
    .rs_full(rs_full[1])
);

endmodule