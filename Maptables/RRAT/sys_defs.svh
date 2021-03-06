`define PREG_IDX_WIDTH 5

typedef struct packed {
    logic [`PREG_IDX_WIDTH-1:0] rrat_tag;
} RRAT_ENTRY;

typedef struct packed {
    logic write_en;
    logic [4:0] addr;
    logic [`PREG_IDX_WIDTH-1:0] tag;
} RRAT_WRITE_INPACKET;

typedef struct packed {
    logic [`PREG_IDX_WIDTH-1:0] tag;
} RRAT_READ_OUTPACKET;

