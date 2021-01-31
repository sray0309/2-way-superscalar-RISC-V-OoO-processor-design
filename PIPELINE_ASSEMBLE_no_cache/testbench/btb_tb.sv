module btb_tb;

logic clock;
logic reset;
logic [1:0] wr_en;
logic [1:0][`XLEN-1:0] wr_addr;
logic [1:0][`XLEN-1:0] wr_target_pc;

logic [1:0][`XLEN-1:0] rd_addr;
logic [1:0][`XLEN-1:0] rd_target_pc;
logic [1:0] rd_valid;

logic [`BTB_SIZE-1:0][`XLEN-1:0] tag;
logic [`BTB_SIZE-1:0][`XLEN-1:0] data;

branch_target_buffer btb_dut(
    .clock(clock),
    .reset(reset),
    .wr_addr(wr_addr),
    .wr_en(wr_en),
    .wr_target_pc(wr_target_pc),
    .rd_addr(rd_addr),
    .rd_target_pc(rd_target_pc),
    .rd_valid(rd_valid),
    .tag(tag),
    .data(data)
);

always #5 clock  =  ~clock; 

initial begin
    clock = 0;
    reset = 0;
    wr_addr = 0;
    wr_target_pc = 0;
    wr_en = 0;
    @(negedge clock);
    reset = 1;
    @(negedge clock);
    reset = 0;
    wr_en = 2'b11;
    wr_target_pc[0] = 12;
    wr_target_pc[1] = 13;
    wr_addr[0] = 78;
    wr_addr[1] = 231;
    @(negedge clock);
    for (int i = 0;i<`BTB_SIZE;i=i+1) begin
        $display("index: [%4d] -- tag:%4d data:%4d",i,tag[i],data[i]);
    end
    @(negedge clock);
    $finish;
end

endmodule