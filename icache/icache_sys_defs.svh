`define SD #1
`define ICACHE_TAG_WIDTH 8
`define ICACHE_LINE_NUM 32
`define ICACHE_IDX_WIDTH $clog2(`ICACHE_LINE_NUM)
`define DATA_SIZE 64

typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

`define NUM_MEM_TAGS 15