// module branch(
//     input clock,
//     input reset,

//     input ROB_PACKET [1:0] rob_packet_in,
//     input head_retire_rdy,
//     input head_p1_retire_rdy,
//     input EX_CM_PACKET [1:0] ex_packet_in,
//     output logic take_branch_out,
//     output logic [`XLEN-1:0] target_pc_out
// );

// logic [`XLEN-1:0] n_target_pc;
// logic [`XLEN-1:0] target_pc;

// logic [`XLEN-1:0] NPC;
// logic [`XLEN-1:0] n_NPC;

// logic valid;
// logic n_valid;

// logic [`ROB_IDX_WIDTH-1:0] rob_idx;
// logic [`ROB_IDX_WIDTH-1:0] n_rob_idx;


// assign take_branch_out = (head_retire_rdy && rob_idx == rob_packet_in[0].rob_idx && rob_packet_in[0].valid && valid) ||
//                           (head_retire_rdy && head_p1_retire_rdy && rob_idx == rob_packet_in[1].rob_idx && rob_packet_in[1].valid && valid);
// assign target_pc_out   = target_pc;

// always_comb begin
//     n_target_pc   = target_pc;
//     n_NPC         = NPC;
//     n_rob_idx     = rob_idx;
//     n_valid       = valid;

//     if(take_branch_out) begin
//         n_valid = 1'b0;
//     end

//     if(ex_packet_in[0].take_branch && !ex_packet_in[1].take_branch) begin
//         if(ex_packet_in[0].NPC < NPC)  begin
//             n_target_pc   = ex_packet_in[0].result;
//             n_NPC         = ex_packet_in[0].NPC;
//             n_rob_idx     = ex_packet_in[0].rob_idx;
//             n_valid       = 1'b1;
//         end
//     end

//     if( ex_packet_in[1].take_branch && !ex_packet_in[0].take_branch) begin
//         if(ex_packet_in[1].NPC < NPC)  begin
//             n_target_pc   = ex_packet_in[1].result;
//             n_NPC         = ex_packet_in[1].NPC;
//             n_rob_idx     = ex_packet_in[1].rob_idx;
//             n_valid       = 1'b1;
//         end
//     end

//     if( ex_packet_in[0].take_branch && ex_packet_in[1].take_branch) begin
//         if( ex_packet_in[0].NPC > ex_packet_in[1].NPC &&  ex_packet_in[1].NPC < NPC ) begin
//             n_target_pc   = ex_packet_in[1].result; 
//             n_NPC         = ex_packet_in[1].NPC;
//             n_rob_idx     = ex_packet_in[1].rob_idx;
//             n_valid       = 1'b1;
//         end else if( ex_packet_in[0].NPC < ex_packet_in[1].NPC &&  ex_packet_in[0].NPC < NPC)begin
//             n_target_pc   = ex_packet_in[0].result; 
//             n_NPC         = ex_packet_in[0].NPC;
//             n_rob_idx     = ex_packet_in[0].rob_idx;
//             n_valid       = 1'b1;
//         end
//         else begin
//         end
//     end


// end

// always_ff @(posedge clock) begin
//     if(reset) begin 
//         target_pc        <= `SD 0;
//         NPC              <= `SD {`XLEN{1'b1}};
//         rob_idx          <= `SD {`ROB_IDX_WIDTH{1'b0}};
//         valid            <= `SD 1'b0;
//     end else begin
//         target_pc         <= `SD n_target_pc;
//         NPC               <= `SD n_NPC;
//         rob_idx           <= `SD n_rob_idx;
//         valid             <= `SD n_valid;
//     end
// end

// endmodule

module branch(
    input clock,
    input reset,

    input ROB_PACKET [1:0] rob_packet_in,
    input head_retire_rdy,
    input head_p1_retire_rdy,
    output logic mispredict,
    output logic [`XLEN-1:0] mispredict_target_pc
);

logic [1:0] br_valid;
logic [1:0] misp;


assign br_valid[0] = rob_packet_in[0].is_branch && head_retire_rdy;
assign br_valid[1] = rob_packet_in[1].is_branch && head_p1_retire_rdy && head_retire_rdy;

// assign misp[0] =  ( rob_packet_in[0].ex_take_branch != rob_packet_in[0].predict_take_branch || 
//                  (rob_packet_in[0].ex_take_branch == rob_packet_in[0].predict_take_branch && rob_packet_in[0].ex_target_pc != rob_packet_in[0].predict_target_pc) );
// assign misp[1] =  (rob_packet_in[1].ex_take_branch != rob_packet_in[1].predict_take_branch ||
//                  (rob_packet_in[1].ex_take_branch == rob_packet_in[1].predict_take_branch && rob_packet_in[1].ex_target_pc != rob_packet_in[1].predict_target_pc) );


assign misp[0] =  ( rob_packet_in[0].ex_take_branch != rob_packet_in[0].predict_take_branch
                 );
assign misp[1] =  (rob_packet_in[1].ex_take_branch != rob_packet_in[1].predict_take_branch
                 );

always_comb begin
    mispredict = 1'b0;
    mispredict_target_pc    = {`XLEN{1'b0}};
    casez(br_valid) 
        2'b01:begin
            if(misp[0]) begin
                mispredict = 1'b1;
                mispredict_target_pc    = rob_packet_in[0].ex_target_pc;
            end
        end
        2'b10:begin
            if(misp[1]) begin
                mispredict = 1'b1;
                mispredict_target_pc    = rob_packet_in[1].ex_target_pc;
            end
        end
        2'b11:begin
            if(misp[0]) begin
                mispredict = 1'b1;
                mispredict_target_pc    = rob_packet_in[0].ex_target_pc;
            end else if(misp[1]) begin
                mispredict = 1'b1;
                mispredict_target_pc    = rob_packet_in[1].ex_target_pc;
            end else begin
                mispredict = 1'b0;
                mispredict_target_pc    = 0;
            end
        end 
        default:begin
                mispredict = 1'b0;
                mispredict_target_pc    = 0;
        end           

    endcase
end


// always_comb begin
//     mispredict           = 1'b0;
//     mispredict_target_pc = 0;
//     if(br_valid[0]) begin
//         if(rob_packet_in[0].ex_take_branch) begin
//             mispredict = 1'b1;
//             mispredict_target_pc    = rob_packet_in[0].ex_target_pc;
//         end else if(br_valid[1]) begin
//             if(rob_packet_in[1].ex_take_branch) begin
//                 mispredict = 1'b1;
//                 mispredict_target_pc    = rob_packet_in[1].ex_target_pc;
//             end
//         end
//     end else if(br_valid[1]) begin
//         if(rob_packet_in[1].ex_take_branch) begin
//             mispredict = 1'b1;
//             mispredict_target_pc    = rob_packet_in[1].ex_target_pc;
//         end
//     end
// end

endmodule