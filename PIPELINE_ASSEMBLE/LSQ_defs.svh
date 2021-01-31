`include "sys_defs.svh"
`ifndef __LSQ_DEFS_VH__
`define __LSQ_DEFS_VH__

`define SQ_ENTRY_RESET {32'h0, `FALSE, 32'hdeadbeef, {`LSQ_IDX_WIDTH{1'b0}},3'b0}
`define SQ_RESET '{`LSQ_SIZE{`SQ_ENTRY_RESET}}

`define LQ_ENTRY_RESET {32'h0, `FALSE, {`ROB_IDX_WIDTH{1'b0}}, {`LSQ_IDX_WIDTH{1'b0}}, 3'b0, {`XLEN{1'b0}}}
`define LQ_RESET '{`LSQ_SIZE{`LQ_ENTRY_RESET}}

typedef struct packed {
    logic   [`XLEN-1:0]         addr;
    logic                       valid;
    logic   [`XLEN-1:0]         value;
    logic   [`LSQ_IDX_WIDTH-1:0] LQ_idx;  //use this  which actually from FU directly
    logic   [2:0]               mem_size;
} SQ_ENTRY_PACKET;

typedef struct packed {
    logic [`XLEN-1:0]            addr;
    logic                        valid;
    logic [`ROB_IDX_WIDTH-1:0]   rob_idx;
    logic [`LSQ_IDX_WIDTH-1:0]   SQ_idx;
    logic   [2:0]                mem_size;
    logic [`XLEN-1:0] PC;
} LQ_ENTRY_PACKET;

typedef struct packed {
  logic        rd_en;     // LSQ has the valid address to read from cache, LOAD
  logic [`XLEN-1:0] addr;
  logic [2:0]  mem_size;
} LQ_D_CACHE_PACKET;

typedef struct packed {
  logic        wr_en;     // LSQ has the valid address&data to write in Cache
  logic [`XLEN-1:0] addr;
  logic [`XLEN-1:0] value;
  logic [2:0] mem_size;
} SQ_D_CACHE_PACKET;

typedef struct packed {
  //store queue sent back to LQ with forwarding value and hit signal
    logic [1:0]                  hit;
    logic [1:0][`XLEN-1:0]       value;

  //store inst sent to load queue checking for memoery vioaltion
    logic [`LSQ_IDX_WIDTH-1:0]   LQ_idx; 
    logic [`XLEN-1:0]            addr;
} SQ_LQ_PACKET;

typedef struct packed {
  //load inst sent to SQ check for forwarding 
    logic [`LSQ_IDX_WIDTH-1:0] SQ_idx;   
    logic [`XLEN-1:0]          addr;

  //load queue sent to store inst with memory vioalation(hit) and corresponding load rob_idx
    logic [`ROB_IDX_WIDTH-1:0] ld_rob_idx;
    logic hit;
} LQ_SQ_PACKET;

//LSQ PACKET and define
typedef struct packed {
  logic                         done;
  logic [`XLEN-1:0]             result; //addr
  logic [`PREG_IDX_WIDTH-1:0]   pdest_idx;
  logic [`ROB_IDX_WIDTH-1:0]    rob_idx; // Dest idx
  logic [`LSQ_IDX_WIDTH-1:0]    SQ_idx;  // come all the way from RS in dispatch stage 
  logic [`LSQ_IDX_WIDTH-1:0]    LQ_idx;  // same
  logic [`XLEN-1:0]             regb_value;       //value to be stored
  logic [2:0]                   mem_size;
} FU_SQ_PACKET;

typedef struct packed {
  logic                        done;
  logic [`ROB_IDX_WIDTH-1:0]   rob_idx; // Dest idx

  logic [`ROB_IDX_WIDTH-1:0]   ld_rob_idx;
  logic                        mem_violation;

} SQ_FU_PACKET;

typedef struct packed {
  logic                         done;
  INST                          inst;
  logic [`XLEN-1:0]             result;
  logic [`PREG_IDX_WIDTH-1:0]   pdest_idx;  // 7
  logic [`ROB_IDX_WIDTH-1:0]    rob_idx; // Dest idx,7
  logic [`LSQ_IDX_WIDTH-1:0]    SQ_idx;  // come all the way from RS in dispatch stage 
  logic [`LSQ_IDX_WIDTH-1:0]    LQ_idx;  // same
  logic [2:0]                   mem_size;
} FU_LQ_PACKET;

typedef struct packed {
  logic                        done;
  INST                         inst;
  logic [`XLEN-1:0]            result; // load value
  logic [`PREG_IDX_WIDTH-1:0]  pdest_idx;
  logic [`ROB_IDX_WIDTH-1:0]   rob_idx; // Dest idx
  logic [2:0]       mem_size;
} LQ_FU_PACKET;






`endif 
