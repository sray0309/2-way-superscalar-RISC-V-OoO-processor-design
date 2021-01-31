module branch_target_buffer(
    input clock,
    input reset,

    input [1:0] wr_en,
    input [1:0][`XLEN-1:0] wr_addr,
    input [1:0][`XLEN-1:0] wr_target_pc,

    input [1:0][`XLEN-1:0] rd_addr,
    output logic [1:0][`XLEN-1:0] rd_target_pc,
    output logic [1:0] rd_valid
);

logic [`BTB_SIZE-1:0][`XLEN-1:0] tag ;
logic [`BTB_SIZE-1:0][`XLEN-1:0] data; 

assign rd_valid[0] = tag[rd_addr[0][(`BTB_IDX_WIDTH-1+2):2]] == rd_addr[0];
assign rd_valid[1] = tag[rd_addr[1][(`BTB_IDX_WIDTH-1+2):2]] == rd_addr[1];

always_comb begin
    rd_target_pc[0] = data[rd_addr[0][(`BTB_IDX_WIDTH-1+2):2]];
end

always_comb begin
    rd_target_pc[1] = data[rd_addr[1][(`BTB_IDX_WIDTH-1+2):2]];
end

always_ff @(posedge clock) begin
    if(reset) begin
        for(int i = 0 ;i<`BTB_SIZE;i=i+1) begin
            tag[i]  <= `SD {`XLEN{1'b0}};
            data[i] <= `SD {`XLEN{1'b0}};
        end
    end else begin
        if(wr_en[0]) begin
            tag[wr_addr[0][(`BTB_IDX_WIDTH-1+2):2]]  <= `SD wr_addr[0];
            data[wr_addr[0][(`BTB_IDX_WIDTH-1+2):2]] <= `SD wr_target_pc[0];
        end 

        if(wr_en[1]) begin
            tag[wr_addr[1][(`BTB_IDX_WIDTH-1+2):2]]  <= `SD wr_addr[1];
            data[wr_addr[1][(`BTB_IDX_WIDTH-1+2):2]] <= `SD wr_target_pc[1];
        end
    end
end

endmodule

//////////////////////////////////////////////
//
// Global or per-PC Pattern History Table
//
//////////////////////////////////////////////
module pattern_history_table( 
    input clock,
    input reset,

    input [1:0][`PHT_IDX_WIDTH-1:0]  rd_pc,    // horizontal length       
    input [1:0][`PHT_IDX_WIDTH-1:0]  rd_idx,   // vertial length
 
    input [1:0][`PHT_IDX_WIDTH-1:0]  wr_pc,  
    input [1:0][`PHT_IDX_WIDTH-1:0]  wr_idx,
    input [1:0]                      wr_t,
    input [1:0]                      wr_en,

    output logic [1:0] rd_t
);

parameter S_NTAKEN = 2'b00;
parameter NTAKEN   = 2'b01;

parameter TAKEN    = 2'b10;
parameter S_TAKEN  = 2'b11;

logic [`PHT_SIZE-1:0][`PHT_SIZE-1:0][1:0] state;

logic [1:0] p1;
logic [1:0] m1;


assign p1[0] = (~& state[wr_pc[0]][wr_idx[0]]);
assign m1[0] = (|  state[wr_pc[0]][wr_idx[0]]);

assign p1[1] = (~& state[wr_pc[1]][wr_idx[1]]);
assign m1[1] = (|  state[wr_pc[1]][wr_idx[1]]);

always_comb begin
    rd_t[0] = state[rd_pc[0]][rd_idx[0]][1];
end

always_comb begin
    rd_t[1] = state[rd_pc[1]][rd_idx[1]][1];
end

always_ff @(posedge clock) begin
    if(reset) begin
        for(int i=0;i<`PHT_SIZE;i=i+1) begin
            for(int j=0;j<`PHT_SIZE;j=j+1) begin
                state[i][j] <= `SD 2'b01;
            end
        end
    end else begin
        if(wr_en[0]) begin
            state[wr_pc[0]][wr_idx[0]] <= `SD state[wr_pc[0]][wr_idx[0]] + ( wr_t[0] & p1[0] ) - (~wr_t[0] & m1[0]);
        end
        if(wr_en[1]) begin
            state[wr_pc[1]][wr_idx[1]] <= `SD state[wr_pc[1]][wr_idx[1]] + ( wr_t[1] & p1[1] ) - (~wr_t[1] & m1[1]);
        end
    end
end

endmodule

//////////////////////////////////////////////
//
// per-PC Branch History Table
//
//////////////////////////////////////////////
// module branch_history_table( 
//     input clock,
//     input reset,

//     input [1:0][`BHT_IDX_WIDTH-1:0] rd_idx.



//     input [1:0][`BHT_IDX_WIDTH-1:0] wr_idx,
//     input [1:0] wr_in,
//     input [1:0] wr_en,

//     output logic [1:0][`PHT_IDX_WIDTH-1:0] rd_out,

// );

// logic [`BHT_SIZE-1:0][`PHT_IDX_WIDTH-1:0] data;

// always_comb begin
//     rd_out[0] = data[rd_idx[0]];
// end

// always_comb begin
//     rd_out[1] = data[rd_idx[1]];
// end

// always_ff @(posedge clock) begin
//     if(reset) begin
//         for(int i= 0 ;i<`BHT_SIZE;i=i+1) begin
//             data[i] <= `SD {`PHT_IDX_WDITH{1'b0}};
//         end
//     end else begin
//         if(wr_en[0]) begin
//             data[wr_idx[0]] <= `SD  {(data[wr_idx[0]] << 1) | { {`PHT_IDX_WIDTH-1{1'b0}},wr_in[0] };
//         end
//         if(wr_en[1]) begin
//             data[wr_idx[1]] <= `SD  {(data[wr_idx[1]] << 1) | { {`PHT_IDX_WIDTH-1{1'b0}},wr_in[1] };
//         end
//     end
// end 

// endmodule


//////////////////////////////////////////////
//
// Global History Table
//
//////////////////////////////////////////////
module branch_history_table(
    input clock,
    input reset,

    input [1:0] wr_in,
    input [1:0] wr_en,

    output logic [`PHT_IDX_WIDTH-1:0] rd_out

);

logic [`PHT_IDX_WIDTH-1:0] data;

assign rd_out = data;

always_ff @(posedge clock) begin
    if(reset) begin
        data <= `SD {`PHT_IDX_WIDTH{1'b0}};
    end else begin
        if(wr_en[0] & wr_en[1]) begin
            data <= `SD   (data << 2) | { {(`PHT_IDX_WIDTH-2){1'b0}},wr_in[0],wr_in[1] };
        end else if(wr_en[0]) begin
            data <= `SD   (data << 1) | { {(`PHT_IDX_WIDTH-1){1'b0}},wr_in[0] };
        end else if (wr_en[1]) begin
            data <= `SD   (data << 1) | { {(`PHT_IDX_WIDTH-1){1'b0}},wr_in[1] };   
        end else begin
            data <= `SD  data;
        end
    end
end 

endmodule

//////////////////////////////////////////////
//
// gshare-style direction predictor
//
//////////////////////////////////////////////
module DIRP(   
    input clock,
    input reset,
    input  [1:0][`XLEN-1:0] if_pc,
    input  [1:0] is_br,

    input  [1:0][`XLEN-1:0] rt_pc,
    input  [1:0] rt_br_valid,
    input  [1:0] rt_take_branch,

    output [1:0] predict_take_branch

);
    logic [`PHT_IDX_WIDTH-1:0] br_hist;

    //pht signal
    logic [1:0][`PHT_IDX_WIDTH-1:0] rd_pc;
    logic [1:0][`PHT_IDX_WIDTH-1:0] rd_idx;
    logic [1:0] rd_t;

    logic [1:0][`PHT_IDX_WIDTH-1:0] wr_pc;
    logic [1:0][`PHT_IDX_WIDTH-1:0] wr_idx;

    assign wr_pc  = {rt_pc[1][`PHT_IDX_WIDTH-1:0],rt_pc[0][`PHT_IDX_WIDTH-1:0]};
    assign wr_idx = {wr_pc[1] ^ br_hist, wr_pc[0] ^ br_hist};

    assign rd_pc  =  {if_pc[1][`PHT_IDX_WIDTH-1:0],if_pc[0][`PHT_IDX_WIDTH-1:0]};
    assign rd_idx =  {rd_pc[1] ^ br_hist, rd_pc[0] ^ br_hist};
    assign predict_take_branch = is_br & rd_t;

    branch_history_table bht_0(
        .clock(clock),
        .reset(reset),

        //input
        .wr_en(rt_br_valid),
        .wr_in(rt_take_branch),

        //output 
        .rd_out(br_hist)
    );

    pattern_history_table pht_0(
        .clock(clock),
        .reset(reset),

        //input 
        .wr_en(rt_br_valid),
        .wr_idx(wr_idx),
        .wr_pc(wr_pc),
        .wr_t(rt_take_branch),

        .rd_pc(rd_pc),
        .rd_idx(rd_idx),

        //output
        .rd_t(rd_t)
    );

endmodule

module RAS(
    input clock,
    input reset,

    input [1:0] is_call,
    input [1:0] is_ret,
    input [1:0][`XLEN-1:0] call_NPC,

    output logic [1:0][`XLEN-1:0] ret_NPC,
//    output logic [16-1:0][`XLEN-1:0] ras_debug,
//    output logic [4-1:0] tail,
//    output logic empty,
    output logic ras_full
);

parameter RAS_SIZE = 16;
parameter RAS_IDX_WIDTH = $clog2(RAS_SIZE);

logic [RAS_SIZE-1:0][`XLEN-1:0] ras;
logic [RAS_IDX_WIDTH-1:0] tail,next_tail;
logic empty, next_empty;

assign ras_full = ( next_tail == {RAS_IDX_WIDTH{1'b1}} ) ?  1'b1:1'b0;

always_comb begin
    next_empty = empty;
    next_tail  = tail;
    ret_NPC    = 0;
    casez({is_call,is_ret}) 
        {2'b11,2'b00}:begin
            if(empty) begin
                next_empty = 0;
                next_tail  = tail + 1;
            end else  begin
                next_tail = tail + 2;
            end
        end
        {2'b00,2'b11}:begin
            ret_NPC[0] = ras[tail];
            ret_NPC[1] = ras[tail+1];
            if(empty) begin
                next_tail = tail;
                next_empty = empty;
            end
            else if(tail==1) begin
                next_tail = 0;
                next_empty  = 1;
            end else begin
                next_tail = tail -2;
            end
        end
        {2'b10,2'b01}: begin
            if(empty) begin
                next_tail = tail;
                next_empty  = empty ;
            end else begin
                ret_NPC[0] = ras[tail];
            end
        end

        {2'b01,2'b10}:begin
            ret_NPC[1] = call_NPC[0];
        end

        {2'b00,2'b01}: begin
            if(tail==0) begin
                next_tail = tail;
                next_empty = 1;
                ret_NPC[0] = ras[tail];
            end else begin
                next_tail = tail -1;
                ret_NPC[0] = ras[tail];
            end
        end

        {2'b00,2'b10}: begin
            if(empty) begin
                next_tail = tail;
                next_empty =  1 ;
            end else begin
                if(tail==0) begin
                    next_tail = tail;
                    next_empty = 1;  
                end else begin
                    next_tail = tail -1;
                    ret_NPC[1] = ras[tail];
                end
            end
        end

        {2'b01,2'b00},{2'b01,2'b00}: begin
            if(empty) begin
                next_tail = tail;
                next_empty =  0 ;
            end else begin
                next_tail = tail + 1; 
            end
        end
        default:begin
            next_empty = empty;
            next_tail  = tail;
            ret_NPC    = 0 ;
        end
    endcase
end

always_ff @(posedge clock) begin
    if(reset) begin
        tail  <= `SD 0;
        empty <= `SD 1'b1;
        ras   <= `SD 0;
    end else if (is_call[0] && is_call[1]) begin
        tail  <= `SD next_tail;
        empty <= `SD next_empty;
        ras[next_tail-1] <= `SD call_NPC[0];
        ras[next_tail]   <= `SD call_NPC[1];
    end else if(is_call[0] && !is_call[1] && !is_ret[1]) begin
        tail  <= `SD next_tail;
        empty <= `SD next_empty;
        ras[next_tail] <= `SD call_NPC[0];
    end else if(!is_call[0] && is_call[1]) begin
        tail  <= `SD next_tail;
        empty <= `SD next_empty;
        ras[next_tail] <= `SD call_NPC[1];
    end else begin
        tail  <= `SD next_tail;
        empty <= `SD next_empty;
    end
end

endmodule


module predecoder (
    input clock,
    input reset,

    input IF_ID_PACKET if_packet,
    output logic is_br,
    output logic is_call,
    output logic is_ret
);

	INST inst;
	logic valid_inst_in;
	
	assign inst          = if_packet.inst;
	assign valid_inst_in = if_packet.valid;

	always_comb begin
        is_br =   `FALSE;
        is_ret =  `FALSE;
        is_call = `FALSE;
        if(valid_inst_in) begin
            casez (inst) 
				`RV32_JAL: begin
                    is_br   =  `TRUE;
                    is_call =  `TRUE;     
				end
				`RV32_JALR: begin
					is_br   = `TRUE;
                    is_ret  = `TRUE;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
                    is_br   = `TRUE;
                end
                default: begin
                    is_br   = `FALSE;
                    is_ret  = `FALSE;
                    is_call = `FALSE;
                end
            endcase
        end
    end
endmodule 



//////////////////////////////////////////////
//
// branch predictor
//
//////////////////////////////////////////////
module branch_predictor(
    input clock,
    input reset,

    input IF_ID_PACKET [1:0] if_packet,
    input ROB_PACKET   [1:0] rob_packet,
    input head_retire_rdy,
    input head_p1_retire_rdy,

    output logic [1:0] predict_take_branch,
    output logic [1:0][`XLEN-1:0] predict_target_pc,
    output logic ras_full
);

    //predecoder output
    logic [1:0] is_br;
    logic [1:0] is_call;
    logic [1:0] is_ret;

    //DIRP signals
    logic [1:0][`XLEN-1:0] if_pc;
    logic [1:0] dirp_br_valid;
    logic [1:0][`XLEN-1:0] rt_pc;
    logic [1:0] rt_br_valid;    
    logic [1:0] rt_take_branch;
    logic [1:0] predict_direction;


    // branch target buffer signals
    logic [1:0] wr_en;
    logic [1:0][`XLEN-1:0] wr_addr;
    logic [1:0][`XLEN-1:0] wr_target_pc;

    logic [1:0][`XLEN-1:0] rd_addr;
    logic [1:0][`XLEN-1:0] rd_target_pc;
    logic [1:0] rd_valid;

    //ras signal
    logic [1:0][`XLEN-1:0] call_NPC;
    logic [1:0][`XLEN-1:0] ret_NPC;
    assign call_NPC = {if_packet[1].NPC, if_packet[0].NPC};
    //branch target buffer assignments
    assign wr_en        = { head_p1_retire_rdy && rob_packet[1].is_branch, head_retire_rdy && rob_packet[0].is_branch };
    assign wr_addr      = { rob_packet[1].PC,rob_packet[0].PC};
    assign wr_target_pc = { rob_packet[1].ex_target_pc, rob_packet[0].ex_target_pc};
    assign rd_addr      = { if_packet[1].PC, if_packet[0].PC};

    //DIRP assignments
    assign if_pc = {if_packet[1].PC, if_packet[0].PC}; 
    assign dirp_br_valid = is_br & rd_valid;
    assign rt_pc = { rob_packet[1].PC,rob_packet[0].PC};
    assign rt_br_valid = { head_p1_retire_rdy && rob_packet[1].is_branch, head_retire_rdy && rob_packet[0].is_branch };
    assign rt_take_branch = { rob_packet[1].ex_take_branch, rob_packet[0].ex_take_branch };

    //output assignments
    assign predict_target_pc[0] = /*is_ret[0]? ret_NPC[0]:*/
                          rd_valid[0]? rd_target_pc[0]:if_packet[0].NPC;
    assign predict_target_pc[1] = /*is_ret[1]? ret_NPC[1]:*/
                          rd_valid[1]? rd_target_pc[1]:if_packet[1].NPC;

    assign predict_take_branch[0] = /*is_ret[0]? 1'b1:*/
                                    rd_valid[0]? predict_direction[0]:1'b0;
    assign predict_take_branch[1] = /*is_ret[1]? 1'b1:*/
                                    rd_valid[1]? predict_direction[1]:1'b0;

    // assign predict_take_branch[0] = 1'b0;
    // assign predict_take_branch[1] = 1'b0;                         
                                 
    DIRP dirp_0 (
        .clock(clock),
        .reset(reset),
        //input
        .if_pc(if_pc),
        .is_br(dirp_br_valid),

        .rt_pc(rt_pc),
        .rt_br_valid(rt_br_valid),
        .rt_take_branch(rt_take_branch),

        //input
        .predict_take_branch(predict_direction)
    ); 

    branch_target_buffer btb_0(
        .clock(clock),
        .reset(reset),

        //input
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_target_pc(wr_target_pc),

        .rd_addr(rd_addr),
        //output
        .rd_target_pc(rd_target_pc),
        .rd_valid(rd_valid)
    );

    predecoder predecoder_0(
        .clock(clock),
        .reset(reset),
        .if_packet(if_packet[0]),

        .is_br(is_br[0]),
        .is_call(is_call[0]),
        .is_ret(is_ret[0])
    );

    predecoder predecoder_1(
        .clock(clock),
        .reset(reset),
        .if_packet(if_packet[1]),

        .is_br(is_br[1]),
        .is_call(is_call[1]),
        .is_ret(is_ret[1])
    );


    RAS ras_0 (
        .clock(clock),
        .reset(reset),
        //input 
        .is_call(is_call),
        .is_ret(is_ret),

        .call_NPC(call_NPC),

        //output 
        .ret_NPC(ret_NPC),
        .ras_full(ras_full)
    );

endmodule