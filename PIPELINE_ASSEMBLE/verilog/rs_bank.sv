`timescale 1ns/100ps

module rs_bank(
    input clock,
    input reset,

    //input [`NUM_RS_ENTRIES-1:0] entry_clear,
    input rsbank_enable, //can dispatch when enable is high
    input is_stall,      //issue stall 

    input ld_issue_stall_i,

    input [`XLEN-1:0] NPC,
    input [`XLEN-1:0] PC,  

    input [`ROB_IDX_WIDTH-1:0]  rob_idx,

    input [`LSQ_IDX_WIDTH-1:0] sq_idx,lq_idx,

    input [`PREG_IDX_WIDTH-1:0] prega_idx_in, //physical regfile tag from RAT
    input [`PREG_IDX_WIDTH-1:0] pregb_idx_in, //from RAT
    input [`PREG_IDX_WIDTH-1:0] pdest_idx_in, //from freelist
    input prega_ready_in,   //from RAT, indicating if the value is ready
    input pregb_ready_in,   // from RAT, 

    input ALU_OPA_SELECT opa_select,
    input ALU_OPB_SELECT opb_select,
    input INST inst_in,
    input ALU_FUNC alu_func, //alu_op
    input rd_mem,
    input wr_mem,
	input cond_branch,   
	input uncond_branch, 
	input halt,          
	input illegal,  
	input csr_op,
	input valid,

    input [1:0] cdb_valid,  //indicating if cdb data is valid 
    input [1:0][`PREG_IDX_WIDTH-1:0] cdb_tag, //cdb data

    output logic [`XLEN-1:0] NPC_out,
    output logic [`XLEN-1:0] PC_out, 
    output logic [`ROB_IDX_WIDTH-1:0]  rob_idx_out,

    output logic [`LSQ_IDX_WIDTH-1:0]  sq_idx_out,lq_idx_out,

    output logic [`PREG_IDX_WIDTH-1:0] prega_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pregb_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pdest_idx_out, 
    output ALU_OPA_SELECT opa_select_out,
    output ALU_OPB_SELECT opb_select_out,
    output INST inst_out, //instruction being issued
    output ALU_FUNC alu_func_out,
    output logic rd_mem_out,
    output logic wr_mem_out,
    output logic cond_branch_out,   
	output logic uncond_branch_out, 
	output logic halt_out,          
	output logic illegal_out,  
	output logic csr_op_out,
	output logic valid_out,

    output logic ALU_ready, //which FU send to 

    output logic STORE_ready,
    output logic LOAD_ready,
    //output logic LSQ_ready,

    output logic MULT_ready,
    output logic BR_ready,

    output logic ld_issue_stall_o,
    output logic rs_full  // indicating if rs is full
);

logic [$clog2(`NUM_RS_ENTRIES)-1:0] entry_issue_idx;

logic [`NUM_RS_ENTRIES-1:0] entry_en, entry_busy;

logic [`NUM_RS_ENTRIES-1:0] entry_ALU_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_ALU_sel;

// logic [`NUM_RS_ENTRIES-1:0] entry_LSQ_ready;
// logic [`NUM_RS_ENTRIES-1:0] entry_LSQ_sel;
logic [`NUM_RS_ENTRIES-1:0] entry_STORE_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_STORE_sel;
logic [`NUM_RS_ENTRIES-1:0] entry_LOAD_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_LOAD_sel;

logic [`NUM_RS_ENTRIES-1:0] entry_MULT_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_MULT_sel;

logic [`NUM_RS_ENTRIES-1:0] entry_BR_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_BR_sel;


logic [`NUM_RS_ENTRIES-1:0] entry_sel; //entries for select
logic [`NUM_RS_ENTRIES-1:0] entry_issue; //entries for issue

logic [`NUM_RS_ENTRIES-1:0][`XLEN-1:0] NPC_file,PC_file;
logic [`NUM_RS_ENTRIES-1:0][`ROB_IDX_WIDTH-1:0]  rob_idx_file;
logic [`NUM_RS_ENTRIES-1:0][`PREG_IDX_WIDTH-1:0] prega_idx_file,pregb_idx_file,pdest_idx_file; 

logic [`NUM_RS_ENTRIES-1:0][`LSQ_IDX_WIDTH-1:0]  sq_idx_file,lq_idx_file;

ALU_OPA_SELECT [`NUM_RS_ENTRIES-1:0] opa_select_file;
ALU_OPB_SELECT [`NUM_RS_ENTRIES-1:0] opb_select_file;
INST [`NUM_RS_ENTRIES-1:0] inst_file;
ALU_FUNC [`NUM_RS_ENTRIES-1:0] alu_func_file;
logic [`NUM_RS_ENTRIES-1:0] rd_mem_file,wr_mem_file,cond_branch_file,uncond_branch_file,halt_file,illegal_file,csr_op_file,valid_file;

logic [`NUM_RS_ENTRIES-1:0] prega_tag,pregb_tag;

logic issue_flag;

ps #(.NUM_BITS(`NUM_RS_ENTRIES)) alu_select(.req(entry_ALU_ready),.en(!is_stall),.gnt(entry_ALU_sel));

ps #(.NUM_BITS(`NUM_RS_ENTRIES)) store_select(.req(entry_STORE_ready),.en(!is_stall),.gnt(entry_STORE_sel));
ps #(.NUM_BITS(`NUM_RS_ENTRIES)) load_select(.req(entry_LOAD_ready),.en(!is_stall && !ld_issue_stall_i),.gnt(entry_LOAD_sel));

ps #(.NUM_BITS(`NUM_RS_ENTRIES)) mult_select(.req(entry_MULT_ready),.en(!is_stall),.gnt(entry_MULT_sel));
ps #(.NUM_BITS(`NUM_RS_ENTRIES)) branch_select(.req(entry_BR_ready),.en(!is_stall),.gnt(entry_BR_sel));

ps #(.NUM_BITS(`NUM_RS_ENTRIES)) sel2issue(.req(entry_sel),.en(!is_stall),.gnt(entry_issue));

ps #(.NUM_BITS(`NUM_RS_ENTRIES)) dispatch_select(.req(~entry_busy),.en(rsbank_enable),.gnt(entry_en));

pe #(.IN_WIDTH(`NUM_RS_ENTRIES)) issue_select(.gnt(entry_issue),.enc(entry_issue_idx));

//entries for select
assign entry_sel = entry_ALU_sel | entry_MULT_sel | entry_BR_sel | entry_LOAD_sel | entry_STORE_sel; // | entry_LSQ_sel

assign issue_flag = | entry_issue; // indicating anything is ready to issue;


assign NPC_out           = issue_flag? NPC_file[entry_issue_idx] :{`XLEN{1'b0}};
assign PC_out            = issue_flag? PC_file[entry_issue_idx]  :{`XLEN{1'b0}};
assign rob_idx_out       = issue_flag? rob_idx_file[entry_issue_idx]   :{`ROB_IDX_WIDTH{1'b0}};

assign sq_idx_out        = issue_flag? sq_idx_file[entry_issue_idx]   :{`LSQ_IDX_WIDTH{1'b0}};
assign lq_idx_out        = issue_flag? lq_idx_file[entry_issue_idx]   :{`LSQ_IDX_WIDTH{1'b0}};

assign prega_idx_out     = issue_flag? prega_idx_file[entry_issue_idx] :`ZERO_PREG;
assign pregb_idx_out     = issue_flag? pregb_idx_file[entry_issue_idx] :`ZERO_PREG;
assign pdest_idx_out     = issue_flag? pdest_idx_file[entry_issue_idx] :`ZERO_PREG;
assign opa_select_out    = issue_flag? opa_select_file[entry_issue_idx]:OPA_IS_RS1;
assign opb_select_out    = issue_flag? opb_select_file[entry_issue_idx]:OPB_IS_RS2;
assign inst_out          = issue_flag? inst_file[entry_issue_idx]      :`NOP;
assign alu_func_out      = issue_flag? alu_func_file[entry_issue_idx]  :ALU_ADD;
assign rd_mem_out        = issue_flag? rd_mem_file[entry_issue_idx]    :1'b0;
assign wr_mem_out        = issue_flag? wr_mem_file[entry_issue_idx]    :1'b0;
assign cond_branch_out   = issue_flag? cond_branch_file[entry_issue_idx]  :1'b0;
assign uncond_branch_out = issue_flag? uncond_branch_file[entry_issue_idx]:1'b0;
assign halt_out          = issue_flag? halt_file[entry_issue_idx]         :1'b0;
assign illegal_out       = issue_flag? illegal_file[entry_issue_idx]      :1'b0;
assign csr_op_out        = issue_flag? csr_op_file[entry_issue_idx]       :1'b0;
assign valid_out         = issue_flag? valid_file[entry_issue_idx]        :1'b0;

assign ALU_ready    = issue_flag? entry_ALU_ready[entry_issue_idx]:1'b1;//| entry_ALU_ready;
assign STORE_ready  = issue_flag? entry_STORE_ready[entry_issue_idx]:1'b0;
assign LOAD_ready   = issue_flag? entry_LOAD_ready[entry_issue_idx]:1'b0;

assign MULT_ready   = issue_flag? entry_MULT_ready[entry_issue_idx]:1'b0;//| entry_MULT_ready;
assign BR_ready     = issue_flag? entry_BR_ready[entry_issue_idx]:1'b0;
assign rs_full      = & entry_busy;


always_comb begin
    ld_issue_stall_o = 1'b0;
    if(issue_flag) begin
        if(wr_mem_out == 1'b1 ) begin
             ld_issue_stall_o = 1'b1;
        end
    end
end

generate 
    genvar i;
    for(i=0;i<`NUM_RS_ENTRIES;i=i+1) begin:rs_gen
        rs_entry rs_entry_0(
            .clock(clock),
            .reset(reset),

            //input
            .NPC(NPC),
            .PC(PC),
            .rob_idx(rob_idx),

            .sq_idx(sq_idx),
            .lq_idx(lq_idx),

            .prega_idx_in(prega_idx_in),
            .pregb_idx_in(pregb_idx_in),
            .pdest_idx_in(pdest_idx_in),
            .prega_ready_in(prega_ready_in),
            .pregb_ready_in(pregb_ready_in),
            .opa_select(opa_select),
            .opb_select(opb_select),
            .inst_in(inst_in),
            .alu_func(alu_func),
            .rd_mem(rd_mem),
            .wr_mem(wr_mem),
            .cond_branch(cond_branch),
            .uncond_branch(uncond_branch),
            .halt(halt),
            .illegal(illegal),
            .csr_op(csr_op),
            .valid(valid),

            .cdb_valid(cdb_valid),
            .cdb_tag(cdb_tag),

            .enable(entry_en[i]),
            .select(entry_issue[i]),

            //output
            .NPC_out(NPC_file[i]),
            .PC_out(PC_file[i]),
            .rob_idx_out(rob_idx_file[i]),

            .sq_idx_out(sq_idx_file[i]),
            .lq_idx_out(lq_idx_file[i]),

            .prega_idx_out(prega_idx_file[i]),
            .pregb_idx_out(pregb_idx_file[i]),
            .pdest_idx_out(pdest_idx_file[i]),
            .opa_select_out(opa_select_file[i]),
            .opb_select_out(opb_select_file[i]),
            .inst_out(inst_file[i]),
            .alu_func_out(alu_func_file[i]),
            .rd_mem_out(rd_mem_file[i]),
            .wr_mem_out(wr_mem_file[i]),
            .cond_branch_out(cond_branch_file[i]),
            .uncond_branch_out(uncond_branch_file[i]),
            .halt_out(halt_file[i]),
            .illegal_out(illegal_file[i]),
            .csr_op_out(csr_op_file[i]),
            .valid_out(valid_file[i]),

            .prega_tag(prega_tag[i]),
            .pregb_tag(pregb_tag[i]),

            .ALU_ready(entry_ALU_ready[i]),
            //.LSQ_ready(entry_LSQ_ready[i]),
            .STORE_ready(entry_STORE_ready[i]),
            .LOAD_ready(entry_LOAD_ready[i]),

            .MULT_ready(entry_MULT_ready[i]),
            .BR_ready(entry_BR_ready[i]),
            .busy(entry_busy[i])
        );
    end
endgenerate

endmodule 


module rs_entry(
    //System signal
    input clock, 
    input reset,

    input [`XLEN-1:0] NPC,
    input [`XLEN-1:0] PC,

    input [`ROB_IDX_WIDTH-1:0]  rob_idx,
    input [`LSQ_IDX_WIDTH-1:0]  sq_idx,lq_idx,

    input [`PREG_IDX_WIDTH-1:0] prega_idx_in,
    input [`PREG_IDX_WIDTH-1:0] pregb_idx_in,
    input [`PREG_IDX_WIDTH-1:0] pdest_idx_in,
    input prega_ready_in,
    input pregb_ready_in,

    input ALU_OPA_SELECT opa_select,
    input ALU_OPB_SELECT opb_select, 
    input INST inst_in,
    input ALU_FUNC alu_func,
    input rd_mem,
    input wr_mem,
	input cond_branch, 
	input uncond_branch, 
	input halt,          
	input illegal,      
	input csr_op,       
	input valid,  

    input [1:0] cdb_valid,
    input [1:0][`PREG_IDX_WIDTH-1:0] cdb_tag,

    input enable, //being allocated
    input select,

    output logic [`XLEN-1:0] NPC_out,
    output logic [`XLEN-1:0] PC_out,

    output logic [`ROB_IDX_WIDTH-1:0]  rob_idx_out,
    output logic [`LSQ_IDX_WIDTH-1:0]  sq_idx_out,lq_idx_out,

    output logic [`PREG_IDX_WIDTH-1:0] prega_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pregb_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pdest_idx_out,

    output ALU_OPA_SELECT opa_select_out,
    output ALU_OPB_SELECT opb_select_out,
    output INST inst_out,
    output ALU_FUNC alu_func_out,
    output logic rd_mem_out,
    output logic wr_mem_out,
    output logic cond_branch_out,
    output logic uncond_branch_out,
    output logic halt_out,
    output logic illegal_out,
    output logic csr_op_out,
    output logic valid_out,


    output logic prega_tag,
    output logic pregb_tag,

    output logic ALU_ready,
    output logic STORE_ready,
    output logic LOAD_ready,
    output logic MULT_ready,
    output logic BR_ready,
    output logic busy  
);



logic prega_ready;
logic pregb_ready;
logic n_prega_ready;
logic n_pregb_ready;
logic n_busy;

logic [`XLEN-1:0] n_NPC;
logic [`XLEN-1:0] n_PC;
logic [`ROB_IDX_WIDTH-1:0] n_rob_idx;

logic [`LSQ_IDX_WIDTH-1:0] n_sq_idx,n_lq_idx;

logic [`PREG_IDX_WIDTH-1:0] n_prega_idx,n_pregb_idx,n_pdest_idx;



ALU_OPA_SELECT n_opa_select;
ALU_OPB_SELECT n_opb_select;
INST n_inst_out;
ALU_FUNC n_alu_func_out;
logic n_rd_mem_out;
logic n_wr_mem_out;
logic n_cond_branch;
logic n_uncond_branch;
logic n_halt;
logic n_illegal;
logic n_csr_op;
logic n_valid;


logic cdb_prega_ready;
logic cdb_pregb_ready;
logic preg_ready;

assign cdb_prega_ready = ( cdb_valid[0] && (cdb_tag[0] == prega_idx_out)) || 
                         ( cdb_valid[1] && (cdb_tag[1] == prega_idx_out));

assign cdb_pregb_ready = ( cdb_valid[0] && (cdb_tag[0] == pregb_idx_out)) || 
                         ( cdb_valid[1] && (cdb_tag[1] == pregb_idx_out));


assign prega_tag = (prega_ready || cdb_prega_ready );
assign pregb_tag = (pregb_ready || cdb_pregb_ready) ;

assign preg_ready = prega_tag &&  pregb_tag;

//assign LSQ_ready  =  busy && preg_ready && (rd_mem_out | wr_mem_out);

assign STORE_ready  =  busy && preg_ready &&  wr_mem_out;
assign LOAD_ready   =  busy && preg_ready &&  rd_mem_out;
assign MULT_ready =  busy && preg_ready &&  
                     (alu_func_out == ALU_MUL    || alu_func_out == ALU_MULH || 
                      alu_func_out == ALU_MULHSU || alu_func_out == ALU_MULHU);

assign BR_ready   =  busy && preg_ready && (cond_branch_out || uncond_branch_out);

assign ALU_ready  =  busy && preg_ready && !STORE_ready && !LOAD_ready && !MULT_ready && !BR_ready;


//synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if(reset) begin
        NPC_out             <= `SD {`XLEN{1'b0}};
        PC_out              <= `SD {`XLEN{1'b0}};
        rob_idx_out         <= `SD {`ROB_IDX_WIDTH{1'b0}};

        sq_idx_out          <= `SD {`LSQ_IDX_WIDTH{1'b0}};
        lq_idx_out          <= `SD {`LSQ_IDX_WIDTH{1'b0}};

        prega_idx_out       <= `SD `ZERO_PREG;
        pregb_idx_out       <= `SD `ZERO_PREG;  
        pdest_idx_out       <= `SD `ZERO_PREG; 
        opa_select_out      <= `SD OPA_IS_RS1;
        opb_select_out      <= `SD OPB_IS_RS2;
        inst_out            <= `SD `NOP; 
        alu_func_out        <= `SD ALU_ADD;
        rd_mem_out          <= `SD 1'b0;
        wr_mem_out          <= `SD 1'b0;
        cond_branch_out     <= `SD 1'b0;
        uncond_branch_out   <= `SD 1'b0;
        halt_out            <= `SD 1'b0;
        illegal_out         <= `SD 1'b0;
        csr_op_out          <= `SD 1'b0;
        valid_out           <= `SD 1'b0;

        prega_ready         <= `SD 1'b0;
        pregb_ready         <= `SD 1'b0;
        busy                <= `SD 1'b0;
    end else begin
        NPC_out             <= `SD n_NPC;
        PC_out              <= `SD n_PC;
        rob_idx_out         <= `SD n_rob_idx;

        sq_idx_out          <= `SD n_sq_idx;
        lq_idx_out          <= `SD n_lq_idx;

        prega_idx_out       <= `SD n_prega_idx;
        pregb_idx_out       <= `SD n_pregb_idx;
        pdest_idx_out       <= `SD n_pdest_idx;
        opa_select_out      <= `SD n_opa_select;
        opb_select_out      <= `SD n_opb_select;
        inst_out            <= `SD n_inst_out;
        alu_func_out        <= `SD n_alu_func_out;
        rd_mem_out          <= `SD n_rd_mem_out;
        wr_mem_out          <= `SD n_wr_mem_out;
        cond_branch_out     <= `SD n_cond_branch;
        uncond_branch_out   <= `SD n_uncond_branch;
        halt_out            <= `SD n_halt;
        illegal_out         <= `SD n_illegal;
        csr_op_out          <= `SD n_csr_op;
        valid_out           <= `SD n_valid;

        prega_ready         <= `SD n_prega_ready;
        pregb_ready         <= `SD n_pregb_ready;
        busy                <= `SD n_busy;   
    end
end

always_comb begin
    unique if(enable && !busy) begin
        n_NPC           = NPC;
        n_PC            = PC;
        n_rob_idx       = rob_idx;

        n_sq_idx        = sq_idx;
        n_lq_idx        = lq_idx;

        n_prega_idx     = prega_idx_in;
        n_pregb_idx     = pregb_idx_in;
        n_pdest_idx     = pdest_idx_in;
        n_opa_select    = opa_select;
        n_opb_select    = opb_select;
        n_inst_out      = inst_in;
        n_alu_func_out  = alu_func;
        n_rd_mem_out    = rd_mem;
        n_wr_mem_out    = wr_mem;
        n_cond_branch   = cond_branch;
        n_uncond_branch = uncond_branch;
        n_halt          = halt;
        n_illegal       = illegal;
        n_csr_op        = csr_op;
        n_valid         = valid;

        n_prega_ready   = prega_ready_in;
        n_pregb_ready   = pregb_ready_in;
        n_busy          = 1'b1;
    end else if(busy && !enable) begin
        n_NPC           = NPC_out;
        n_PC            = PC_out;
        n_rob_idx       = rob_idx_out;

        n_sq_idx        = sq_idx_out;
        n_lq_idx        = lq_idx_out;

        n_prega_idx     = prega_idx_out;
        n_pregb_idx     = pregb_idx_out;
        n_pdest_idx     = pdest_idx_out;
        n_opa_select    = opa_select_out;
        n_opb_select    = opb_select_out;
        n_inst_out      = inst_out;
        n_alu_func_out  = alu_func_out;
        n_rd_mem_out    = rd_mem_out;
        n_wr_mem_out    = wr_mem_out;
        n_cond_branch   = cond_branch_out;
        n_uncond_branch = uncond_branch_out;
        n_halt          = halt_out;
        n_illegal       = illegal_out;
        n_csr_op        = csr_op_out;
        n_valid         = valid_out;

        n_prega_ready   = prega_ready | cdb_prega_ready;
        n_pregb_ready   = pregb_ready | cdb_pregb_ready;
        n_busy          = 1'b1;
        if(select) begin
            n_busy = 1'b0;
        end else begin
            n_busy = 1'b1;
        end
    end else begin
        n_NPC           = NPC_out;
        n_PC            = PC_out;
        n_rob_idx       = rob_idx_out;

        n_sq_idx        = sq_idx_out;
        n_lq_idx        = lq_idx_out;

        n_prega_idx     = prega_idx_out;
        n_pregb_idx     = pregb_idx_out;
        n_pdest_idx     = pdest_idx_out;
        n_opa_select    = opa_select_out;
        n_opb_select    = opb_select_out;
        n_inst_out      = inst_out;
        n_alu_func_out  = alu_func_out;
        n_rd_mem_out    = rd_mem_out;
        n_wr_mem_out    = wr_mem_out;
        n_cond_branch   = cond_branch_out;
        n_uncond_branch = uncond_branch_out;
        n_halt          = halt_out;
        n_illegal       = illegal_out;
        n_csr_op        = csr_op_out;
        n_valid         = valid_out;

        n_prega_ready   = prega_ready;
        n_pregb_ready   = pregb_ready;
        n_busy          = busy;
    end
end

endmodule

module pe(gnt,enc);
        //synopsys template
        // parameter OUT_WIDTH=4;
        // parameter IN_WIDTH=1<<OUT_WIDTH;
        parameter IN_WIDTH = 8;
        parameter OUT_WIDTH = $clog2(IN_WIDTH);

	input  [IN_WIDTH-1:0] gnt;

	output [OUT_WIDTH-1:0] enc;
    wor    [OUT_WIDTH-1:0] enc;
        
    genvar i,j;
    generate
        for(i=0;i<OUT_WIDTH;i=i+1)
        begin : foo
            for(j=1;j<IN_WIDTH;j=j+1)
            begin : bar
                if (j[i])
                assign enc[i] = gnt[j];
            end
        end
    endgenerate
endmodule

module ps (req, en, gnt, req_up);
//synopsys template
parameter NUM_BITS = 8;

  input  [NUM_BITS-1:0] req;
  input                 en;

  output [NUM_BITS-1:0] gnt;
  output                req_up;
        
  wire   [NUM_BITS-2:0] req_ups;
  wire   [NUM_BITS-2:0] enables;
        
  assign req_up = req_ups[NUM_BITS-2];
  assign enables[NUM_BITS-2] = en;
        
  genvar i,j;
  generate
    if ( NUM_BITS == 2 )
    begin
      ps2 single (.req(req),.en(en),.gnt(gnt),.req_up(req_up));
    end
    else
    begin
      for(i=0;i<NUM_BITS/2;i=i+1)
      begin : foo
        ps2 base ( .req(req[2*i+1:2*i]), 
                   .en(enables[i]),
                   .gnt(gnt[2*i+1:2*i]),
                   .req_up(req_ups[i])
        );
      end

      for(j=NUM_BITS/2;j<=NUM_BITS-2;j=j+1)
      begin : bar
        ps2 top ( .req(req_ups[2*j-NUM_BITS+1:2*j-NUM_BITS]),
                  .en(enables[j]),
                  .gnt(enables[2*j-NUM_BITS+1:2*j-NUM_BITS]),
                  .req_up(req_ups[j])
        );
      end
    end
  endgenerate
endmodule

module ps2(req, en, gnt, req_up);

  input     [1:0] req;
  input           en;
  
  output    [1:0] gnt;
  output          req_up;
  
  assign gnt[1] = en & req[1];
  assign gnt[0] = en & req[0] & !req[1];
  
  assign req_up = req[1] | req[0];

endmodule


