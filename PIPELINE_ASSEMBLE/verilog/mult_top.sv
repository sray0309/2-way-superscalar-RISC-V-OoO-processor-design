`timescale 1ns/100ps

module mult_top(
    input clock, reset,
    input [`XLEN-1:0] mcand, mplier,
    input start,
    input ALU_FUNC alu_func,
    input EX_MULT_PACKET ex_mult_packet_in,

    output EX_MULT_PACKET ex_mult_packet_out,
    output logic [`XLEN-1:0] product,
    output logic done
);

    logic [2*`XLEN-1:0] mcand_in, mplier_in;
    logic [2*`XLEN-1:0] product_out;
    logic [1:0] sign;

    ALU_FUNC _alu_func;

    always_comb begin
        case(alu_func)
            ALU_MUL:    sign = 2'b11;
            ALU_MULH:   sign = 2'b11;
            ALU_MULHSU: sign = 2'b10;
            ALU_MULHU:  sign = 2'b00;
            default:    sign = 2'b00;
        endcase
    end

    always_comb begin
        case (_alu_func)
            ALU_MUL:    product = product_out[`XLEN-1:0];
            ALU_MULH:   product = product_out[2*`XLEN-1:`XLEN];
            ALU_MULHSU: product = product_out[2*`XLEN-1:`XLEN];
            ALU_MULHU:  product = product_out[2*`XLEN-1:`XLEN];
            default:    product = product_out[`XLEN-1:0];
        endcase
    end

    assign mcand_in  = sign[0] ? {{`XLEN{mcand[`XLEN-1]}}, mcand} : {{`XLEN{1'b0}}, mcand} ;
    assign mplier_in = sign[1] ? {{`XLEN{mplier[`XLEN-1]}}, mplier} : {{`XLEN{1'b0}}, mplier};
    
    delay_chain #(.INPUT_BITS_NUM(5), .NUM_DELAY_CYCLE(8)) alu_func_delay(clock, reset, 1'b1, alu_func, _alu_func);
    delay_chain #(.INPUT_BITS_NUM(`XLEN), .NUM_DELAY_CYCLE(8)) NPC_delay(clock, reset, 1'b1, ex_mult_packet_in.NPC, ex_mult_packet_out.NPC);
    delay_chain #(.INPUT_BITS_NUM(`XLEN), .NUM_DELAY_CYCLE(8)) inst_delay(clock, reset, 1'b1, ex_mult_packet_in.inst, ex_mult_packet_out.inst);
    delay_chain #(.INPUT_BITS_NUM(`ROB_IDX_WIDTH), .NUM_DELAY_CYCLE(8)) rob_idx_delay(clock, reset, 1'b1, ex_mult_packet_in.rob_idx, ex_mult_packet_out.rob_idx);
    delay_chain #(.INPUT_BITS_NUM(`PREG_IDX_WIDTH), .NUM_DELAY_CYCLE(8)) pdest_delay(clock, reset, 1'b1, ex_mult_packet_in.pdest_idx, ex_mult_packet_out.pdest_idx);
    delay_chain #(.INPUT_BITS_NUM(1), .NUM_DELAY_CYCLE(8)) halt_delay(clock, reset, 1'b1, ex_mult_packet_in.halt, ex_mult_packet_out.halt);
    delay_chain #(.INPUT_BITS_NUM(1), .NUM_DELAY_CYCLE(8)) illegal_delay(clock, reset, 1'b1, ex_mult_packet_in.illegal, ex_mult_packet_out.illegal);
    delay_chain #(.INPUT_BITS_NUM(1), .NUM_DELAY_CYCLE(8)) csr_op_delay(clock, reset, 1'b1, ex_mult_packet_in.csr_op, ex_mult_packet_out.csr_op);
    delay_chain #(.INPUT_BITS_NUM(1), .NUM_DELAY_CYCLE(8)) valid_delay(clock, reset, 1'b1, ex_mult_packet_in.valid, ex_mult_packet_out.valid);
    delay_chain #(.INPUT_BITS_NUM(1), .NUM_DELAY_CYCLE(8)) take_branch_delay(clock, reset, 1'b1, ex_mult_packet_in.take_branch, ex_mult_packet_out.take_branch);
    delay_chain #(.INPUT_BITS_NUM(`XLEN), .NUM_DELAY_CYCLE(8)) regb_value_delay(clock, reset, 1'b1, ex_mult_packet_in.regb_value, ex_mult_packet_out.regb_value);
    delay_chain #(.INPUT_BITS_NUM(1), .NUM_DELAY_CYCLE(8)) rd_mem_delay(clock, reset, 1'b1, ex_mult_packet_in.rd_mem, ex_mult_packet_out.rd_mem);
    delay_chain #(.INPUT_BITS_NUM(1), .NUM_DELAY_CYCLE(8)) wr_mem_delay(clock, reset, 1'b1, ex_mult_packet_in.wr_mem, ex_mult_packet_out.wr_mem);
    delay_chain #(.INPUT_BITS_NUM(3), .NUM_DELAY_CYCLE(8)) mem_size_delay(clock, reset, 1'b1, ex_mult_packet_in.mem_size, ex_mult_packet_out.mem_size);
    
    mult mult_0(
        .clock(clock), 
        .reset(reset),
        .mcand(mcand_in), 
        .mplier(mplier_in),
        .start(start),
        
        .product(product_out),
        .done(done_reg)
    );

    assign done = done_reg;

endmodule