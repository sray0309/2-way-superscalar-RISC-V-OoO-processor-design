module SQ(
    input clock, reset,
    input rollback,
    input [1:0]     dispatch_en,
    input [1:0]     dispatch_SQ_wr_mem,         // from decoder, in dispatch stage

    input [1:0]     ROB_SQ_wr_mem,         // in retire stage
    input [1:0]     ROB_SQ_retire_rdy,      // retire ready indicator

    input                                   D_cache_SQ_out_valid,    // used as valid signal for retire, 1 means Cache ready for retire 
    input FU_SQ_PACKET    [1:0]             FU_SQ_out,     // address & data &done signal from FU 
    input LQ_SQ_PACKET    [1:0]             LQ_SQ_out,    //load sent in for forwading  check in store queue

    output logic                                     dispatch_valid, // valid when not full
    output logic                                     retire_buf_empty,

    output logic  [1:0][`LSQ_IDX_WIDTH-1:0]          SQ_idx,     //to RS, saved as SQ pos

    output SQ_FU_PACKET    [1:0]                     SQ_FU_out, // store queue packet with memory violation bit sent back to exs
    output SQ_LQ_PACKET    [1:0]                     SQ_LQ_out, // store inst sent to load queue for memory violation check
    output SQ_D_CACHE_PACKET                         SQ_D_cache_out
);

    SQ_ENTRY_PACKET  [`LSQ_SIZE-1:0]                 sq,next_sq;

    logic       [`LSQ_IDX_WIDTH-1:0]                 head,tail;
    logic       [`LSQ_IDX_WIDTH-1:0]                 next_head, next_tail, dispatch_tail;
    logic       [`LSQ_IDX_WIDTH-1:0]                 tail_plus_one, tail_plus_two, head_plus_one, head_plus_two;

    logic       [1:0][`LSQ_IDX_WIDTH-1:0]                  head_map_idx;
    logic       [1:0][`LSQ_SIZE-1:0][`LSQ_IDX_WIDTH-1:0]   sq_map_idx;
    logic       [1:0]                       st_hit;
    logic       [1:0][`LSQ_IDX_WIDTH-1:0]   st_idx, SQ_idx_minus_one;

    assign tail_plus_one       = tail + 1;
    assign tail_plus_two       = tail + 2;
    assign head_plus_one       = head + 1;
    assign head_plus_two       = head + 2;

    assign SQ_idx_minus_one[0] =  FU_SQ_out[0].SQ_idx - 1;
    assign SQ_idx_minus_one[1] =  FU_SQ_out[1].SQ_idx - 1;

    // ------------Execute on Store, send store information to lq for checking memory violation-----------
    always_comb begin
      for (int i = 0; i < 2; i++) begin
        SQ_LQ_out[i].LQ_idx = FU_SQ_out[i].LQ_idx;   
        SQ_LQ_out[i].addr   = FU_SQ_out[i].result;
      end
    end

    // sent back violation information
    always_comb begin
      for (int i = 0; i < 2; i++) begin
          SQ_FU_out[i].done      = FU_SQ_out[i].done;      // value should be saved immediately at EX
          SQ_FU_out[i].rob_idx   = FU_SQ_out[i].rob_idx;
          
          // violation information from load queue age logic
          SQ_FU_out[i].ld_rob_idx =    LQ_SQ_out[i].ld_rob_idx;
          SQ_FU_out[i].mem_violation = LQ_SQ_out[i].hit;
        end
    end

    always_comb begin
      next_sq = sq;

      // Dispatch, allocate entry at SQ tail, only move the tail pointer and reset the entry
      if (dispatch_en) begin
          case(dispatch_SQ_wr_mem)
              2'b01, 2'b10: next_sq[tail] = `SQ_ENTRY_RESET;
              2'b11: begin
                  next_sq[tail]           = `SQ_ENTRY_RESET;
                  next_sq[tail_plus_one]  = `SQ_ENTRY_RESET;
              end
              default: next_sq = sq;
          endcase
      end

    // --------Execute----------
    // Execute, write address and data into corresponding SQ slot, Store operation
      for (int i = 0; i < 2; i++) begin
          if (FU_SQ_out[i].done) begin
              next_sq[SQ_idx_minus_one[i]] = '{FU_SQ_out[i].result, 
                                              `TRUE,      // valid bit set to TRUE in execute
                                              FU_SQ_out[i].regb_value, 
                                              FU_SQ_out[i].LQ_idx,
                                              FU_SQ_out[i].mem_size};
          end
      end
    end

    // -----Dispatch-------
    always_comb begin
        // tail pointer, valid signal, and record the current SQ tail index as "load position"(2 way)
        case(dispatch_SQ_wr_mem)
            2'b00: begin
                dispatch_tail  = tail;
                dispatch_valid = `TRUE;     // always true because no store required, ready signal
                SQ_idx         = '{tail, tail};
            end
            2'b01: begin
                dispatch_tail  = tail_plus_one;
                dispatch_valid = tail_plus_one != head;
                SQ_idx         = '{tail_plus_one, tail_plus_one};
            end
            2'b10: begin
                dispatch_tail  = tail_plus_one;
                dispatch_valid = tail_plus_one != head;
                SQ_idx         = '{tail_plus_one, tail};
            end
            2'b11: begin
                dispatch_tail  = tail_plus_two;
                dispatch_valid = tail_plus_one != head && tail_plus_two != head;    // valid when SQ is not full
                SQ_idx         = '{tail_plus_two, tail_plus_one};
            end
            default: begin
                dispatch_tail  = tail;
                dispatch_valid = `TRUE;     
                SQ_idx         = '{tail, tail};
            end
        endcase
    end
    assign next_tail = dispatch_en ? dispatch_tail : tail;



  // Age logic for Load operation
  // Map SQ idx
    always_comb begin
      for (int i = 0; i < 2; i++) begin
        for (int j = 0; j < `LSQ_SIZE; j++) begin
          sq_map_idx[i][j] = LQ_SQ_out[i].SQ_idx + j; // SQ_idx is supposed to be the Load pos in SQ, for the Load inst in execute
        end
      end
    end

    always_comb begin
      for (int i = 0; i < 2; i++) begin
        head_map_idx[i] = {`LSQ_IDX_WIDTH{1'b1}} - LQ_SQ_out[i].SQ_idx + head; // got the SQ_idx from FU, forward from LQ in original design
      end
    end

    always_comb begin
      st_hit = {2{`FALSE}};
      st_idx = {2{`FALSE}};
      for (int i = 0; i < 2; i++) begin
        for (int j = `LSQ_SIZE - 1; j >= 0; j--) begin
          if (LQ_SQ_out[i].addr == sq[sq_map_idx[i][j]].addr && sq[sq_map_idx[i][j]].valid && j > head_map_idx[i]) begin
            st_hit[i] = `TRUE;
            st_idx[i] = j;
            break;
          end
        end
      end
    end
    // Age logic for Load operation

    //FIXME
    SQ_ENTRY_PACKET retire_buffer_out;
    logic [1:0] load_hit_on_rtb;
    logic [1:0][`XLEN-1:0] load_hit_value_on_rtb;
    // forward the hit and value to LQ, Load operation also cam post retire buffer
    always_comb begin  //FIXME
        for (int i = 0; i < 2; i++) begin
            if(st_hit[i]) begin
              SQ_LQ_out[i].hit    = st_hit[i];
              SQ_LQ_out[i].value  = sq[sq_map_idx[i][st_idx[i]]].value;
            end else if(load_hit_on_rtb) begin
              SQ_LQ_out[i].hit    = load_hit_on_rtb[i];
              SQ_LQ_out[i].value  = load_hit_value_on_rtb[i];
            end else begin
              SQ_LQ_out[i].hit = 0;
              SQ_LQ_out[i].value = {`XLEN{1'b0}};
            end
        end
    end
    
    retire_store_buffer rtb_0(
      .clock(clock),
      .reset(reset),
      .din1(sq[head]),
      .din2(sq[head_plus_one]),
      .wr_en1(ROB_SQ_retire_rdy[0] && ROB_SQ_wr_mem[0] ),
      .wr_en2(ROB_SQ_retire_rdy[1] && ROB_SQ_wr_mem[1] ),
      .rd_en(D_cache_SQ_out_valid),

      .load_addr_i({LQ_SQ_out[1].addr,LQ_SQ_out[0].addr}),
      .load_value_valid(load_hit_on_rtb),
      .load_value_o(load_hit_value_on_rtb),

      .dout(retire_buffer_out),
      .empty(retire_buf_empty)
    );  

    assign SQ_D_cache_out.wr_en = retire_buf_empty? 1'b0:retire_buffer_out.valid;
    assign SQ_D_cache_out.addr  = retire_buffer_out.addr;
    assign SQ_D_cache_out.value = retire_buffer_out.value;
    assign SQ_D_cache_out.mem_size = retire_buffer_out.mem_size;

    // next head
    always_comb begin
        case(ROB_SQ_wr_mem & ROB_SQ_retire_rdy)
            2'b00: begin
                next_head = head;
            end
            2'b01: begin
                next_head = head_plus_one;
            end
            2'b10: begin
                next_head = head_plus_one;
            end
            2'b11: begin
                next_head = head_plus_two;
            end
        endcase
    end

  // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset | rollback) begin
            head      <= `SD {(`LSQ_IDX_WIDTH){1'b0}};
            tail      <= `SD {(`LSQ_IDX_WIDTH){1'b0}};
            sq        <= `SD `SQ_RESET;
        end else begin
            head      <= `SD next_head;
            tail      <= `SD next_tail;
            sq        <= `SD next_sq;
        end
    end
endmodule

module LQ (
    // Input
    input  logic                                                    clock, reset,
    input  logic            [1:0]                                   dispatch_en, 
    input  logic                                                    rd_ld_buffer_stall,
    input  logic            [1:0]                                   dispatch_LQ_rd_mem,   // dispatch
    input  logic            [1:0]                                   ROB_LQ_rd_mem,    // retire 

    input  logic            [1:0]                                   ROB_LQ_retire_rdy,
    input  logic            [1:0][`ROB_IDX_WIDTH-1:0]               rob_idx,    // the idx of ROB in dispatch stage
    input  logic            [1:0][`LSQ_IDX_WIDTH-1:0]               SQ_idx,     // the idx of SQ in dispatch stage
    input  logic                                                    D_cache_LQ_out_valid,  
    input  logic            [`XLEN-1:0]                             D_cache_LQ_out_value,  
    input  FU_LQ_PACKET     [1:0]                                   FU_LQ_out,
    input  SQ_LQ_PACKET     [1:0]                                   SQ_LQ_out,
    // Output

    output logic                                                    load_buf_full,

    output logic                                                    dispatch_valid, 
    output logic            [1:0][`LSQ_IDX_WIDTH-1:0]               LQ_idx,
    output LQ_SQ_PACKET [1:0]                                       LQ_SQ_out,
    output LQ_FU_PACKET [1:0]                                       LQ_FU_out,
    output LQ_D_CACHE_PACKET                                        LQ_D_cache_out
);  

    LQ_ENTRY_PACKET  [`LSQ_SIZE-1:0]                      lq,next_lq;

    logic            [`LSQ_IDX_WIDTH-1:0]                 head,tail;
    logic            [`LSQ_IDX_WIDTH-1:0]                 next_head, next_tail, dispatch_tail;
    logic            [`LSQ_IDX_WIDTH-1:0]                 head_plus_one, head_plus_two, tail_plus_one, tail_plus_two;

    logic            [1:0]                                  ld_hit;
    logic            [1:0][`LSQ_IDX_WIDTH-1:0]              LQ_idx_minus_one, ld_idx;
    logic            [1:0][`LSQ_IDX_WIDTH-1:0]                   tail_map_idx;
    logic            [1:0][`LSQ_SIZE-1:0][`LSQ_IDX_WIDTH-1:0]    lq_map_idx;

    assign tail_plus_one       = tail + 1;
    assign tail_plus_two       = tail + 2;
    assign head_plus_one       = head + 1;
    assign head_plus_two       = head + 2;
    assign LQ_idx_minus_one[0] = FU_LQ_out[0].LQ_idx - 1;
    assign LQ_idx_minus_one[1] = FU_LQ_out[1].LQ_idx - 1;

  // Dispatch valid
    always_comb begin
        // allocate entry and record the LQ_idx as position
        case(dispatch_LQ_rd_mem)
            2'b00: begin
                dispatch_tail  = tail;
                dispatch_valid = `TRUE;
                LQ_idx         = '{tail, tail};
            end
            2'b01: begin
                dispatch_tail  = tail_plus_one;
                dispatch_valid = tail_plus_one != head;
                LQ_idx         = '{tail_plus_one, tail_plus_one};
            end
            2'b10: begin
                dispatch_tail  = tail_plus_one;
                dispatch_valid = tail_plus_one != head;
                LQ_idx         = '{tail_plus_one, tail};
            end
            2'b11: begin
                dispatch_tail  = tail_plus_two;
                dispatch_valid = tail_plus_one != head && tail_plus_two != head;
                LQ_idx         = '{tail_plus_two, tail_plus_one};
            end
        endcase
    end

    assign next_tail = dispatch_en ? dispatch_tail : tail;

    always_comb begin
      //default
      next_lq = lq;
      //Execute on load
      case({FU_LQ_out[1].done,FU_LQ_out[0].done})    
        2'b00: begin
        end
        2'b01: begin
          next_lq[LQ_idx_minus_one[0]].addr  = FU_LQ_out[0].result;
          //next_lq[LQ_idx_minus_one[0]].valid = SQ_LQ_out[0].hit;
          next_lq[LQ_idx_minus_one[0]].valid = `TRUE;
        end
        2'b10: begin
          next_lq[LQ_idx_minus_one[1]].addr  = FU_LQ_out[1].result;
          //next_lq[LQ_idx_minus_one[1]].valid = SQ_LQ_out[1].hit;
          next_lq[LQ_idx_minus_one[1]].valid = `TRUE;
        end
        2'b11: begin
          next_lq[LQ_idx_minus_one[0]].addr  = FU_LQ_out[0].result;
          //next_lq[LQ_idx_minus_one[0]].valid = SQ_LQ_out[0].hit;
          next_lq[LQ_idx_minus_one[0]].valid = `TRUE;

          next_lq[LQ_idx_minus_one[1]].addr  = FU_LQ_out[1].result;
          //next_lq[LQ_idx_minus_one[1]].valid = SQ_LQ_out[1].hit;
          next_lq[LQ_idx_minus_one[1]].valid = `TRUE;
        end
      endcase

      //Dispatch
      if (dispatch_en) begin  
        case(dispatch_LQ_rd_mem)
          2'b01: begin
            next_lq[tail].addr    = {`XLEN{1'b0}};
            next_lq[tail].valid   = `FALSE;
            next_lq[tail].rob_idx = rob_idx[0];
            next_lq[tail].SQ_idx  = SQ_idx[0];
          end
          2'b10: begin
            next_lq[tail].addr    = {`XLEN{1'b0}};
            next_lq[tail].valid   = `FALSE;
            next_lq[tail].rob_idx = rob_idx[1];
            next_lq[tail].SQ_idx  = SQ_idx[1];
          end
          2'b11: begin
            next_lq[tail].addr             = {`XLEN{1'b0}};
            next_lq[tail].valid            = `FALSE;
            next_lq[tail].rob_idx          = rob_idx[0];
            next_lq[tail].SQ_idx           = SQ_idx[0];

            next_lq[tail_plus_one].addr    = {`XLEN{1'b0}};
            next_lq[tail_plus_one].valid   = `FALSE;
            next_lq[tail_plus_one].rob_idx = rob_idx[1];
            next_lq[tail_plus_one].SQ_idx  = SQ_idx[1];
          end
        endcase
      end
    end

  // -----Execute on Load-------
  // forward the Load position(which is SQ_idx) and address to SQ, if hit, signals would be sent to LQ from SQ as SQ_LQ_out
    always_comb begin
      for (int i = 0; i < 2; i++) begin
        LQ_SQ_out[i].SQ_idx = FU_LQ_out[i].SQ_idx;
        LQ_SQ_out[i].addr   = FU_LQ_out[i].result;
      end
    end

  //load buffer signal //FIXME
  logic wr_en1,wr_en2;
  logic rd_en;
  logic empty;
  logic load_buf_full;
  // logic rd_cache;
  // logic [`XLEN-1:0] rd_cache_addr;
  // logic [2:0] rd_cache_mem_size;

  FU_LQ_PACKET din1,din2;
  FU_LQ_PACKET dout;
  logic [`XLEN-1:0] dout_value;
  logic dout_valid;
  // give done signal to FU if hit on SQ or Cache
    always_comb begin
      rd_en  = 0;
      wr_en1 = 0;
      wr_en2 = 0;
      din1 = FU_LQ_out[0];
      din2 = FU_LQ_out[1];
      LQ_FU_out[0].done      = 1'b0;
      LQ_FU_out[0].inst      = `NOP;
      LQ_FU_out[0].result    = {`XLEN{1'b0}};
      LQ_FU_out[0].pdest_idx = {`PREG_IDX_WIDTH{1'b0}};
      LQ_FU_out[0].rob_idx   = {`ROB_IDX_WIDTH{1'b0}};
      LQ_FU_out[0].mem_size  = 3'b0;

      LQ_FU_out[1].done      = 1'b0;
      LQ_FU_out[1].inst      = `NOP;
      LQ_FU_out[1].result    = {`XLEN{1'b0}};
      LQ_FU_out[1].pdest_idx = {`PREG_IDX_WIDTH{1'b0}};
      LQ_FU_out[1].rob_idx   = {`ROB_IDX_WIDTH{1'b0}};
      LQ_FU_out[1].mem_size  = 3'b0;
        if(SQ_LQ_out[0].hit) begin
          LQ_FU_out[0].done      = FU_LQ_out[0].done;
          LQ_FU_out[0].inst      = FU_LQ_out[0].inst;
          LQ_FU_out[0].result    = SQ_LQ_out[0].value;
          LQ_FU_out[0].pdest_idx = FU_LQ_out[0].pdest_idx;
          LQ_FU_out[0].rob_idx   = FU_LQ_out[0].rob_idx;
          LQ_FU_out[0].mem_size  = FU_LQ_out[0].mem_size;
        end else if (dout_valid) begin
          LQ_FU_out[0].done      = dout_valid;
          LQ_FU_out[0].inst      = dout.inst;
          LQ_FU_out[0].result    = dout_value;
          LQ_FU_out[0].pdest_idx = dout.pdest_idx;
          LQ_FU_out[0].rob_idx   = dout.rob_idx;
          LQ_FU_out[0].mem_size  = dout.mem_size;
          if(FU_LQ_out[0].done) begin
            wr_en1 = !load_buf_full;
          end
          if(rd_ld_buffer_stall) begin
            rd_en = 0;
          end else begin
            rd_en = 1;
          end
        end else begin 
          LQ_FU_out[0].done      = 1'b0;
          LQ_FU_out[0].inst      = `NOP;
          LQ_FU_out[0].result    = {`XLEN{1'b0}};
          LQ_FU_out[0].pdest_idx = {`PREG_IDX_WIDTH{1'b0}};
          LQ_FU_out[0].rob_idx   = {`ROB_IDX_WIDTH{1'b0}};
          LQ_FU_out[0].mem_size  = 3'b0;
          if(FU_LQ_out[0].done) begin
              wr_en1 = !load_buf_full;
          end
        end

        if(SQ_LQ_out[1].hit) begin
          LQ_FU_out[1].done      = FU_LQ_out[1].done;
          LQ_FU_out[1].inst      = FU_LQ_out[1].inst;
          LQ_FU_out[1].result    = SQ_LQ_out[1].value;
          LQ_FU_out[1].pdest_idx = FU_LQ_out[1].pdest_idx;
          LQ_FU_out[1].rob_idx   = FU_LQ_out[1].rob_idx;
          LQ_FU_out[1].mem_size  = FU_LQ_out[1].mem_size;
        end else begin 
          LQ_FU_out[1].done      = 1'b0;
          LQ_FU_out[1].inst      = `NOP;
          LQ_FU_out[1].result    = {`XLEN{1'b0}};
          LQ_FU_out[1].pdest_idx = {`PREG_IDX_WIDTH{1'b0}};
          LQ_FU_out[1].rob_idx   = {`ROB_IDX_WIDTH{1'b0}};
          LQ_FU_out[1].mem_size  = 3'b0;
          if(FU_LQ_out[1].done) begin
              wr_en2 = !load_buf_full;
          end
        end
    end

    load_buffer lmb_0(
      .clock(clock),
      .reset(reset),
      .wr_en1(wr_en1),
      .wr_en2(wr_en2),
      .din1(din1),
      .din2(din2),
      .rd_en(rd_en),

      .cache_valid(D_cache_LQ_out_valid),
      .cache_data(D_cache_LQ_out_value),

      .rd_cache(LQ_D_cache_out.rd_en),
      .addr(LQ_D_cache_out.addr),
      .mem_size(LQ_D_cache_out.mem_size),

      .dout(dout),
      .value_o(dout_value),
      .valid_o(dout_valid),
      .empty(empty),
      .full(load_buf_full)
    );

  // Age logic for Store operation
  // Map LQ idx
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      for (int j = 0; j < `LSQ_SIZE; j++) begin
        lq_map_idx[i][j] = SQ_LQ_out[i].LQ_idx + j;
      end
    end
  end

  always_comb begin
    for (int i = 0; i < 2; i++) begin
      tail_map_idx[i] = tail - SQ_LQ_out[i].LQ_idx; // shift the LQ_idx to be compared with
    end
  end

  always_comb begin
    ld_hit = {2{`FALSE}};
    ld_idx = {{`LSQ_IDX_WIDTH{1'b0}},{`LSQ_IDX_WIDTH{1'b0}}};
    for (int i = 0; i < 2; i++) begin
      for (int j = 0; j < `LSQ_SIZE; j++) begin
          if (SQ_LQ_out[i].addr == lq[lq_map_idx[i][j]].addr && lq[lq_map_idx[i][j]].valid && j < tail_map_idx[i]) begin //FIXME maybe
            ld_hit[i] = `TRUE;
            ld_idx[i] = j;
            break;
          end
      end
    end
  end

  // Execute on store, if hit in SQ, it means violation, this load instruction need to be fixed by ssending the information to 
  always_comb begin
    for (int i = 0; i < 2; i++) begin
      LQ_SQ_out[i].ld_rob_idx    = lq[lq_map_idx[i][ld_idx[i]]].rob_idx;  // where we need to return to in ROB
      LQ_SQ_out[i].hit           = ld_hit[i];
    end
  end

  // Retire
  always_comb begin
    case(ROB_LQ_rd_mem & ROB_LQ_retire_rdy)
      2'b00: begin
        next_head = head;
      end
      2'b01: begin
        next_head = head_plus_one;
      end
      2'b10: begin
        next_head = head_plus_one;
      end
      2'b11: begin
        next_head = head_plus_two;
      end
    endcase
  end

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if (reset) begin
      head      <= `SD {(`LSQ_IDX_WIDTH){1'b0}};
      tail      <= `SD {(`LSQ_IDX_WIDTH){1'b0}};
      lq        <= `SD `LQ_RESET;
    end else begin
      head      <= `SD next_head;
      tail      <= `SD next_tail;
      lq        <= `SD next_lq;
    end
  end
endmodule

module LSQ (
    // Input
    input  logic                                                   clock, reset,
    input  logic                                                   rollback, // to SQ
    input  logic            [1:0]                                  dispatch_en,
    input  logic                                                   rd_ld_buffer_stall, // to LQ
    input  logic            [1:0][`ROB_IDX_WIDTH-1:0]              rob_idx,     // From ROB to LQ, when dispatch, indicating the instruction index in rob
    input  logic            [1:0]                                  dispatch_SQ_wr_mem,   // dispatch stage, indicate if it is a wr_mem (Store) instruction. (sent from decoder?)
    input  logic            [1:0]                                  dispatch_LQ_rd_mem,   // dispatch stage, indicate if it is a rd_mem (Load) instruction
    input  logic                                                   D_cache_SQ_out_valid,    // is D_cache ready for the Store instruction?
    input  logic                                                   D_cache_LQ_out_valid,  // hit in cache, data valid
    input  logic            [`XLEN-1:0]                            D_cache_LQ_out_value,    // value in cache when hit
    input  FU_SQ_PACKET     [1:0]                                  FU_SQ_out,     // address & data &done signal from FU 
    input  FU_LQ_PACKET     [1:0]                                  FU_LQ_out,
    input  logic            [1:0]                                  ROB_SQ_wr_mem,   // retire stage. A Store instruction?
    input  logic            [1:0]                                  ROB_SQ_retire_rdy,   // retire stage. Is there any instruction could be retired when not considering the stall condition from Store(DCache)?
    
    input  logic            [1:0]                                  ROB_LQ_rd_mem,   // retire stage. Is it a Load instruction?
    input  logic            [1:0]                                  ROB_LQ_retire_rdy, 
    // Output
    output logic                                                   LSQ_dispatch_valid,       //dispatch_valid
    
    output logic                                                   load_buf_full,
    output logic                                                   retire_buf_empty,

    output logic            [1:0][`LSQ_IDX_WIDTH-1:0]              SQ_idx,     // SQ to RS, saved as SQ pos along with others in RS, pass it to FU
    output logic            [1:0][`LSQ_IDX_WIDTH-1:0]              LQ_idx,     // LQ to RS, saved as LQ pos, pass it to FU
    
    output SQ_FU_PACKET    [1:0]                                   SQ_FU_out,
    output LQ_FU_PACKET    [1:0]                                   LQ_FU_out,
    
    output SQ_D_CACHE_PACKET                                       SQ_D_cache_out,
    output LQ_D_CACHE_PACKET                                       LQ_D_cache_out
);

  LQ_SQ_PACKET [1:0]      LQ_SQ_out;
  SQ_LQ_PACKET [1:0]      SQ_LQ_out;
  logic       SQ_dispatch_valid, LQ_dispatch_valid;

  // dispatch_valid means the LSQ has empty slot
  assign LSQ_dispatch_valid = SQ_dispatch_valid && LQ_dispatch_valid;

SQ  sq_0(
  // input
  .clock(clock),
  .reset(reset),

  .rollback(rollback),

  .dispatch_en(dispatch_en),
  .dispatch_SQ_wr_mem(dispatch_SQ_wr_mem),
  .ROB_SQ_wr_mem(ROB_SQ_wr_mem),
  .ROB_SQ_retire_rdy(ROB_SQ_retire_rdy),
  .FU_SQ_out(FU_SQ_out),
  .LQ_SQ_out(LQ_SQ_out),
  .D_cache_SQ_out_valid(D_cache_SQ_out_valid),

  // output
  .dispatch_valid(SQ_dispatch_valid),

  .retire_buf_empty(retire_buf_empty),

  .SQ_idx(SQ_idx),
  .SQ_FU_out(SQ_FU_out),
  .SQ_LQ_out(SQ_LQ_out),
  .SQ_D_cache_out(SQ_D_cache_out)
);

LQ  lq_0(
  // input
  .clock(clock),
  .reset(reset | rollback),
  .dispatch_en(dispatch_en),

  .rd_ld_buffer_stall(rd_ld_buffer_stall),

  .dispatch_LQ_rd_mem(dispatch_LQ_rd_mem),
  .ROB_LQ_rd_mem(ROB_LQ_rd_mem),
  .ROB_LQ_retire_rdy(ROB_LQ_retire_rdy),
  .rob_idx(rob_idx),
  .SQ_idx(SQ_idx),
  .D_cache_LQ_out_valid(D_cache_LQ_out_valid),
  .D_cache_LQ_out_value(D_cache_LQ_out_value),
  .FU_LQ_out(FU_LQ_out),
  .SQ_LQ_out(SQ_LQ_out), 

  .load_buf_full(load_buf_full),

  .dispatch_valid(LQ_dispatch_valid),
  .LQ_idx(LQ_idx),
  .LQ_SQ_out(LQ_SQ_out),
  .LQ_FU_out(LQ_FU_out),
  .LQ_D_cache_out(LQ_D_cache_out)
);

endmodule
