`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__

//ADDED
`define PREG_IDX_WIDTH 5
`define NUM_RS_ENTRIES 8
`define SCALAR_WIDTH 2
`define ZERO_PREG ({`PREG_IDX_WIDTH{1'b0}})

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to DP stage
//
//////////////////////////////////////////////
typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

//	logic [4:0] rega_idx;    // reg A value                                  
//	logic [4:0] regb_idx;    // reg B value                                  
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)

	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} ID_DP_PACKET;

//////////////////////////////////////////////
// RS Packets:
//////////////////////////////////////////////
typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

    logic [`PREG_IDX_WIDTH-1:0] prega_idx;                               
    logic [`PREG_IDX_WIDTH-1:0] pregb_idx; 
	logic prega_ready;
	logic pregb_ready;       
	logic [`PREG_IDX_WIDTH-1:0] pdest_idx;  // destination (writeback) register index                          
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} DP_RS_PACKET;

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

    logic [`PREG_IDX_WIDTH-1:0] prega_idx;                                 
    logic [`PREG_IDX_WIDTH-1:0] pregb_idx;   	
	logic [`PREG_IDX_WIDTH-1:0] pdest_idx;  // destination (writeback) register index                        
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	logic ALU_ready;
	logic LSQ_ready;
	logic MULT_ready;
	
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} RS_IS_PACKET;