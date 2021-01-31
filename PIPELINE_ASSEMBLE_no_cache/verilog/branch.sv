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

assign misp[0] =  ( rob_packet_in[0].ex_take_branch != rob_packet_in[0].predict_take_branch || 
                 ( rob_packet_in[0].ex_take_branch && rob_packet_in[0].ex_take_branch == rob_packet_in[0].predict_take_branch && rob_packet_in[0].ex_target_pc != rob_packet_in[0].predict_target_pc) );
assign misp[1] =  (rob_packet_in[1].ex_take_branch != rob_packet_in[1].predict_take_branch ||
                 ( rob_packet_in[1].ex_take_branch && rob_packet_in[1].ex_take_branch == rob_packet_in[1].predict_take_branch && rob_packet_in[1].ex_target_pc != rob_packet_in[1].predict_target_pc) );

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

endmodule