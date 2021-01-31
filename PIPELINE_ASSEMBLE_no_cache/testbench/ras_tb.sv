module ras_tb;
logic clock;
logic reset;
logic [1:0] is_call;
logic [1:0] is_ret;
logic [1:0][`XLEN-1:0] call_NPC;
logic [1:0][`XLEN-1:0] ret_NPC;
logic ras_full;
logic [16-1:0][`XLEN-1:0] ras;

logic [3:0] tail;
logic empty;

RAS ras_dut(
    .clock(clock),
    .reset(reset),

    .is_call(is_call),
    .is_ret(is_ret),
    .call_NPC(call_NPC),
    .ret_NPC(ret_NPC),
    .ras_debug(ras),
    .ras_full(ras_full),
    .tail(tail),
    .empty(empty)
);

always #5 clock  =  ~clock;

task display;
    `SD;
    $display("Ras table at time:%4d tail = %2d ret_NPC[1]=%4d ret_NPC[0]=%4d  empty=%2d",
            $time,tail,ret_NPC[1],ret_NPC[0],empty);
    $display("is_call = %2b is_ret=%2b",is_call,is_ret);
    for(int i=0;i<16;i=i+1) begin
        $display("[%4d]:%d",i,ras[i]);
    end
    $display("------------------");
endtask


initial begin
    clock = 0;
    reset = 1;

    @(negedge clock);
    reset= 0;
    is_call = 2'b11;
    is_ret  = 2'b00;
    call_NPC = {32'd12,32'd11};
    display();

    @(negedge clock);
    is_call = 2'b11;
    is_ret  = 2'b00;
    call_NPC = {32'd14,32'd13};
    display();

    @(negedge clock);
    is_call = 2'b11;
    is_ret  = 2'b00;
    call_NPC = {32'd16,32'd15};
    display();


    @(negedge clock);
    is_call = 2'b00;
    is_ret  = 2'b01;
    call_NPC = {32'd16,32'd15};
    display();

    @(negedge clock);
    is_call = 2'b00;
    is_ret  = 2'b01;
    call_NPC = {32'd16,32'd15};
    display();

    @(negedge clock);
    is_call = 2'b00;
    is_ret  = 2'b01;
    call_NPC = {32'd16,32'd15};
    display();

    @(negedge clock);
    is_call = 2'b00;
    is_ret  = 2'b10;
    call_NPC = {32'd16,32'd15};
    display();

    @(negedge clock);
    is_call = 2'b00;
    is_ret  = 2'b10;
    call_NPC = {32'd16,32'd15};
    display();

    @(negedge clock);
    is_call = 2'b10;
    is_ret  = 2'b01;
    call_NPC = {32'd33,32'd32};
    display();

    @(negedge clock);
    is_call = 2'b01;
    is_ret  = 2'b10;
    call_NPC = {32'd33,32'd32};
    display();

    @(negedge clock);
    is_call = 2'b00;
    is_ret  = 2'b01;
    call_NPC = {32'd33,32'd32};
    display();

    @(negedge clock);
    is_call = 2'b10;  // if empty and return first, then call is invalid
    is_ret  = 2'b01;
    call_NPC = {32'd43,32'd42};
    display();

    @(negedge clock);
    is_call = 2'b00;
    is_ret  = 2'b00;
    call_NPC = {32'd43,32'd42};
    display();

    $finish;
end
endmodule