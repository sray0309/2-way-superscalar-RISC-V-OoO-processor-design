
module cm_stage(
    input clock,
    input reset,
   // input rollback_en,                  //  reset CDB output
    input EX_CM_PACKET    [1:0]             ex_cm_packet_in,       //*pdest_reg, *gnt_reg

    output CDB_PACKET     [1:0]             cdb_packet_out
);
  assign cdb_packet_out[0].cdb_valid = /*ex_cm_packet_in[0].pdest_idx != `ZERO_PREG*/  ex_cm_packet_in[0].valid && (ex_cm_packet_in[0].mult_done || ex_cm_packet_in[0].alu_done || ex_cm_packet_in[0].branch_done || ex_cm_packet_in[0].store_done || ex_cm_packet_in[0].load_done);
  assign cdb_packet_out[1].cdb_valid = /*ex_cm_packet_in[1].pdest_idx != `ZERO_PREG*/  ex_cm_packet_in[1].valid && (ex_cm_packet_in[1].mult_done || ex_cm_packet_in[1].alu_done || ex_cm_packet_in[1].branch_done || ex_cm_packet_in[1].store_done || ex_cm_packet_in[1].load_done);

  assign cdb_packet_out[0].cdb_tag = ex_cm_packet_in[0].pdest_idx;
  assign cdb_packet_out[1].cdb_tag = ex_cm_packet_in[1].pdest_idx;

  assign cdb_packet_out[0].cdb_rob_idx = ex_cm_packet_in[0].rob_idx;
  assign cdb_packet_out[1].cdb_rob_idx = ex_cm_packet_in[1].rob_idx;

  //target pc comes from
  assign cdb_packet_out[0].cdb_value =  ex_cm_packet_in[0].take_branch? ex_cm_packet_in[0].NPC:ex_cm_packet_in[0].result;
  assign cdb_packet_out[1].cdb_value =  ex_cm_packet_in[1].take_branch? ex_cm_packet_in[1].NPC:ex_cm_packet_in[1].result;

endmodule