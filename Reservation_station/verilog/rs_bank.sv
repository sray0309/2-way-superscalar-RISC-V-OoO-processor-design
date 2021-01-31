module rs_bank(
    input clock,
    input reset,

    //input [`NUM_RS_ENTRIES-1:0] entry_clear,
    input rsbank_enable, //can dispatch when enable is high
    input [`PREG_IDX_WIDTH-1:0] prega_idx_in, //physical regfile tag from RAT
    input [`PREG_IDX_WIDTH-1:0] pregb_idx_in, //from RAT
    input [`PREG_IDX_WIDTH-1:0] pdest_idx_in, //from freelist
    input prega_ready_in,   //from RAT, indicating if the value is ready
    input pregb_ready_in,   // from RAT, 
    input ALU_FUNC alu_func, //alu_op
    input INST inst_in, 
    input rd_mem,
    input wr_mem,
    input [`SCALAR_WIDTH-1:0] cdb_valid,  //indicating if cdb data is valid 
    input [`SCALAR_WIDTH-1:0][`PREG_IDX_WIDTH-1:0] cdb_tag, //cdb data

    output INST inst_out, //instruction being issued
    output ALU_FUNC alu_func_out,
    output logic [`PREG_IDX_WIDTH-1:0] prega_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pregb_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pdest_idx_out,
    output logic rd_mem_out,
    output logic wr_mem_out,
    output logic ALU_ready, //which FU send to 
    output logic LSQ_ready,
    output logic MULT_ready,
    //output logic BR_ready,
    output logic rs_full  // indicating if rs is full
);

logic [$clog2(`NUM_RS_ENTRIES)-1:0] entry_issue_idx;

logic [`NUM_RS_ENTRIES-1:0] entry_en, entry_busy;

logic [`NUM_RS_ENTRIES-1:0] entry_ALU_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_ALU_sel;

logic [`NUM_RS_ENTRIES-1:0] entry_LSQ_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_LSQ_sel;

logic [`NUM_RS_ENTRIES-1:0] entry_MULT_ready;
logic [`NUM_RS_ENTRIES-1:0] entry_MULT_sel;

logic [`NUM_RS_ENTRIES-1:0] entry_sel;

logic [`NUM_RS_ENTRIES-1:0] rd_mem_file,wr_mem_file;

logic [`NUM_RS_ENTRIES-1:0][`PREG_IDX_WIDTH-1:0] prega_idx_file; 
logic [`NUM_RS_ENTRIES-1:0][`PREG_IDX_WIDTH-1:0] pregb_idx_file;
logic [`NUM_RS_ENTRIES-1:0][`PREG_IDX_WIDTH-1:0] pdest_idx_file; 

ALU_FUNC [`NUM_RS_ENTRIES-1:0] alu_func_file;
INST [`NUM_RS_ENTRIES-1:0] inst_file;

logic issue_flag;


ps #(.NUM_BITS(`NUM_RS_ENTRIES)) alu_select(.req(entry_ALU_ready),.en(1'b1),.gnt(entry_ALU_sel));
ps #(.NUM_BITS(`NUM_RS_ENTRIES)) lsq_select(.req(entry_LSQ_ready),.en(1'b1),.gnt(entry_LSQ_sel));
ps #(.NUM_BITS(`NUM_RS_ENTRIES)) mult_select(.req(entry_MULT_ready),.en(1'b1),.gnt(entry_MULT_sel));
ps #(.NUM_BITS(`NUM_RS_ENTRIES)) dispatch_select(.req(~entry_busy),.en(rsbank_enable),.gnt(entry_en));
pe #(.IN_WIDTH(`NUM_RS_ENTRIES)) issue_select(.gnt(entry_sel),.enc(entry_issue_idx));

//entries for issuing 
assign entry_sel = entry_ALU_sel | entry_LSQ_sel | entry_MULT_sel ;
assign issue_flag = | entry_sel; // indicating anything is ready to issue;


assign inst_out     = inst_file[entry_issue_idx];
assign alu_func_out = alu_func_file[entry_issue_idx];
assign prega_idx_out= prega_idx_file[entry_issue_idx];
assign pregb_idx_out= pregb_idx_file[entry_issue_idx];
assign pdest_idx_out= pdest_idx_file[entry_issue_idx];
assign rd_mem_out   = rd_mem_file[entry_issue_idx];
assign wr_mem_out   = wr_mem_file[entry_issue_idx];

// assign inst_out     = issue_flag? inst_file[entry_issue_idx]:`NOP;
// assign alu_func_out = issue_flag? alu_func_file[entry_issue_idx]:ALU_ADD;
// assign prega_idx_out= issue_flag? prega_idx_file[entry_issue_idx]:`ZERO_PREG;
// assign pregb_idx_out= issue_flag? pregb_idx_file[entry_issue_idx]:`ZERO_PREG;
// assign pdest_idx_out= issue_flag? pdest_idx_file[entry_issue_idx]:`ZERO_PREG;
// assign rd_mem_out   = issue_flag? rd_mem_file[entry_issue_idx]:1'b0;
// assign wr_mem_out   = issue_flag? wr_mem_file[entry_issue_idx]:1'b0;
assign ALU_ready    = entry_ALU_ready[entry_issue_idx];//| entry_ALU_ready;
assign LSQ_ready    = entry_LSQ_ready[entry_issue_idx];//| entry_LSQ_ready;
assign MULT_ready   = entry_MULT_ready[entry_issue_idx];//| entry_MULT_ready;
assign rs_full      = & entry_busy;

generate 
    genvar i;
    for(i=0;i<`NUM_RS_ENTRIES;i=i+1) begin
        rs_entry rs_entry0(
            .clock(clock),
            .reset(reset),

            .prega_idx_in(prega_idx_in),
            .pregb_idx_in(pregb_idx_in),
            .pdest_idx_in(pdest_idx_in),
            .prega_ready_in(prega_ready_in),
            .pregb_ready_in(pregb_ready_in),
            .inst_in(inst_in),
            .alu_func(alu_func),
            .rd_mem(rd_mem),
            .wr_mem(wr_mem),
            .cdb_valid(cdb_valid),
            .cdb_tag(cdb_tag),
            .enable(entry_en[i]),
            .select(entry_sel[i]),

            .inst_out(inst_file[i]),
            .alu_func_out(alu_func_file[i]),
            .prega_idx_out(prega_idx_file[i]),
            .pregb_idx_out(pregb_idx_file[i]),
            .pdest_idx_out(pdest_idx_file[i]),
            .rd_mem_out(rd_mem_file[i]),
            .wr_mem_out(wr_mem_file[i]),
            .ALU_ready(entry_ALU_ready[i]),
            .LSQ_ready(entry_LSQ_ready[i]),
            .MULT_ready(entry_MULT_ready[i]),
            .busy(entry_busy[i])
        );
    end
endgenerate

endmodule 


module rs_entry(
    //System signal
    input clock, 
    input reset,

    //input ID_DP_PACKET id_dp_packet_in;
    input [`PREG_IDX_WIDTH-1:0] prega_idx_in,
    input [`PREG_IDX_WIDTH-1:0] pregb_idx_in,
    input [`PREG_IDX_WIDTH-1:0] pdest_idx_in,
    input prega_ready_in,
    input pregb_ready_in,

    input INST inst_in,
    //input inst_valid,
    //input [`XLEN-1:0] NPC,
    //input [`XLEN-1:0] PC,
    input ALU_FUNC alu_func,
    input rd_mem,
    input wr_mem,
    input [`SCALAR_WIDTH-1:0] cdb_valid,
    input [`SCALAR_WIDTH-1:0][`PREG_IDX_WIDTH-1:0] cdb_tag,

    input enable, //being allocated
    input select,

    output INST inst_out,
    output ALU_FUNC alu_func_out,
    output logic [`PREG_IDX_WIDTH-1:0] prega_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pregb_idx_out,
    output logic [`PREG_IDX_WIDTH-1:0] pdest_idx_out,
    output logic rd_mem_out,
    output logic wr_mem_out,
    output logic ALU_ready,
    output logic LSQ_ready,
    output logic MULT_ready,
    output logic busy  
);

logic [`PREG_IDX_WIDTH-1:0] n_prega_idx,n_pregb_idx,n_pdest_idx;

logic prega_ready;
logic pregb_ready;
logic n_prega_ready;
logic n_pregb_ready;
logic n_busy;

INST n_inst_out;
logic n_rd_mem_out;
logic n_wr_mem_out;
ALU_FUNC n_alu_func_out;


logic cdb_prega_ready;
logic cdb_pregb_ready;
logic preg_ready;

assign cdb_prega_ready = ( cdb_valid[0] && (cdb_tag[0] == prega_idx_out)) || 
                         ( cdb_valid[1] && (cdb_tag[1] == prega_idx_out));

assign cdb_pregb_ready = ( cdb_valid[0] && (cdb_tag[0] == pregb_idx_out)) || 
                         ( cdb_valid[1] && (cdb_tag[1] == pregb_idx_out));


assign preg_ready = (prega_ready || cdb_prega_ready ) && (pregb_ready || cdb_pregb_ready);
assign LSQ_ready  =  busy && preg_ready && (rd_mem_out | wr_mem_out);
assign MULT_ready =  busy && preg_ready &&  
                     (alu_func_out == ALU_MUL    || alu_func_out == ALU_MULH || 
                      alu_func_out == ALU_MULHSU || alu_func_out == ALU_MULHU);
assign ALU_ready  =  busy && preg_ready && !LSQ_ready && !MULT_ready;


//synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if(reset) begin
        prega_idx_out       <= `SD `ZERO_PREG;
        pregb_idx_out       <= `SD `ZERO_PREG;  
        pdest_idx_out       <= `SD `ZERO_PREG; 
        prega_ready         <= `SD 1'b0;
        pregb_ready         <= `SD 1'b0;
        busy                <= `SD 1'b0;

        inst_out            <= `SD `NOP; 
        alu_func_out        <= `SD ALU_ADD;
        rd_mem_out          <= `SD 1'b0;
        wr_mem_out          <= `SD 1'b0;

    end else begin
        prega_idx_out       <= `SD n_prega_idx;
        pregb_idx_out       <= `SD n_pregb_idx;
        pdest_idx_out       <= `SD n_pdest_idx;
        prega_ready         <= `SD n_prega_ready;
        pregb_ready         <= `SD n_pregb_ready;
        busy                <= `SD n_busy;

        inst_out            <= `SD n_inst_out;
        alu_func_out        <= `SD n_alu_func_out;
        rd_mem_out          <= `SD n_rd_mem_out;
        wr_mem_out          <= `SD n_wr_mem_out;
       
    end
end

always_comb begin
    unique if(enable && !busy) begin
        n_prega_idx     = prega_idx_in;
        n_pregb_idx     = pregb_idx_in;
        n_pdest_idx     = pdest_idx_in;
        n_prega_ready   = prega_ready_in;
        n_pregb_ready   = pregb_ready_in;
        n_inst_out      = inst_in;
        n_alu_func_out  = alu_func;
        n_rd_mem_out    = rd_mem;
        n_wr_mem_out    = wr_mem;
        n_busy          = 1'b1;
    end else if(busy && !enable) begin
        n_prega_idx     = prega_idx_out;
        n_pregb_idx     = pregb_idx_out;
        n_pdest_idx     = pdest_idx_out;
        n_prega_ready   = prega_ready | cdb_prega_ready;
        n_pregb_ready   = pregb_ready | cdb_pregb_ready;
        n_inst_out      = inst_out;
        n_alu_func_out  = alu_func_out;
        n_rd_mem_out    = rd_mem_out;
        n_wr_mem_out    = wr_mem_out;
        n_busy          = 1'b1;
        if(select) begin
            n_busy = 1'b0;
        end else begin
            n_busy = 1'b1;
        end
    end else begin
        n_prega_idx     = prega_idx_out;
        n_pregb_idx     = pregb_idx_out;
        n_pdest_idx     = pdest_idx_out;
        n_prega_ready   = prega_ready;
        n_pregb_ready   = pregb_ready;
        n_inst_out      = inst_out;
        n_alu_func_out  = alu_func_out;
        n_rd_mem_out    = rd_mem_out;
        n_wr_mem_out    = wr_mem_out;
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


