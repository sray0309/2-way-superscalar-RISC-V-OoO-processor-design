`define SD #1
`define DCACHE_LINE_NUM  16
`define DCACHE_WAY_NUM   4
`define DCACHE_SET_NUM   (`DCACHE_LINE_NUM / `DCACHE_WAY_NUM)
`define DCACHE_IDX_WIDTH $clog2(`DCACHE_SET_NUM)
`define DCACHE_TAG_WIDTH 32-3-`DCACHE_IDX_WIDTH

`define NUM_MEM_TAGS     15
`define DATA_SIZE        64
`define XLEN             32

typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;