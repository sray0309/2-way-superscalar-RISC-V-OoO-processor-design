module freelist
(
    input clock,
    input reset,
    input rollback_en,
    input wr_en0,wr_en1,
    input [`PREG_IDX_WIDTH-1:0] din0,
    input [`PREG_IDX_WIDTH-1:0] din1,

    input dp_stall,

    input rd_en0,rd_en1,
    output logic [`PREG_IDX_WIDTH-1:0] dout0,
    output logic [`PREG_IDX_WIDTH-1:0] dout1,
    output logic fl_empty,
    output logic fl_almost_empty
);


logic fl_full;
logic fl_almost_full;

logic [`FL_SIZE-1:0][`PREG_IDX_WIDTH-1:0] fl_table;

logic [`FL_IDX_WIDTH-1:0] head,tail;
logic [`FL_IDX_WIDTH-1:0] head_p1,tail_p1;
logic [`FL_IDX_WIDTH-1:0] next_head,next_tail;

logic [`FL_IDX_WIDTH:0] entry_cnt;
logic [`FL_IDX_WIDTH:0] next_entry_cnt;

//assign fl_empty  = (entry_cnt == `FL_SIZE);
//assign fl_almost_empty = (entry_cnt == `FL_SIZE-1);

//assign fl_full  = (entry_cnt == 0);
//assign fl_almost_full = (entry_cnt == 1);

logic dp_en0,dp_en1;
logic reti_en0,reti_en1;
assign dp_en0 = rd_en0 /*&& !fl_empty */&& !dp_stall;
assign dp_en1 = rd_en1 /*&& !fl_almost_empty*/ &&  !dp_stall ;
assign reti_en0 = wr_en0; //&& !fl_full;
assign reti_en1 = wr_en1; //&& !fl_almost_full;

assign head_p1 = head + 1;
assign tail_p1 = tail + 1;


always_ff @(posedge clock) begin
    if(reset) begin
        for(int i = 0 ;i< `FL_SIZE ; i=i+1) begin
            fl_table[i] <= `SD 32 + i;
        end
        head <= `SD {`FL_IDX_WIDTH{1'b0}};
        tail <= `SD {`FL_IDX_WIDTH{1'b0}};
        entry_cnt <= `SD 0;
    end else begin
        head <= `SD next_head;
        tail <= `SD next_tail;
        entry_cnt <= `SD next_entry_cnt;
        if(reti_en0 && reti_en1) begin
            fl_table[head]   <= `SD din0;
            fl_table[head_p1] <= `SD din1;  
        end else if(reti_en0 && !reti_en1) begin
            fl_table[head]   <= `SD din0;
            fl_table[head_p1] <= `SD fl_table[head_p1]; 
        end else if(!reti_en0 && reti_en1) begin
            fl_table[head]   <= `SD din1;
            fl_table[head_p1] <= `SD fl_table[head_p1]; 
        end else begin
            fl_table[head]   <= `SD fl_table[head];
            fl_table[head_p1] <= `SD fl_table[head_p1];
        end
    end
end

always_comb begin
    case({rd_en0,rd_en1})
        2'b00:begin
            dout0 = `ZERO_PREG;
            dout1 = `ZERO_PREG;
        end
        2'b01:begin
            dout0 = `ZERO_PREG;
            dout1 = fl_table[tail];
        end
        2'b10:begin
            dout0 = fl_table[tail];
            dout1 = `ZERO_PREG;
        end
        2'b11:begin
            dout0  = fl_table[tail];
            dout1  = fl_table[tail_p1];
        end
        default:begin
            dout0 = `ZERO_PREG;
            dout1 = `ZERO_PREG;
        end
    endcase
end

always_comb begin
    next_head = head;
    next_tail = tail;
    next_entry_cnt = entry_cnt;
    
    if(rollback_en) begin
        next_tail = head;
        next_head = head;
        next_entry_cnt = 0;
    end else begin
        case({dp_en0,dp_en1,reti_en0,reti_en1}) 
            4'b0010,4'b0001:begin  //reti_en0 == 1
                next_head = head + 1;
                next_entry_cnt = entry_cnt - 1;
            end
            4'b0011:begin  // reti_en0 = reti_en1 = 1
                next_head= head + 2;
                next_entry_cnt = entry_cnt - 2;
            end

            4'b1000,4'b0100:begin // dp_en0 = 1
                next_tail = tail + 1;
                next_entry_cnt = entry_cnt + 1;
            end
            4'b1100:begin // dp_en0 = dp_en1 = 1
                next_tail  = tail + 2;
                next_entry_cnt = entry_cnt + 2;
            end
            4'b1010,4'b1001,4'b0110,4'b0101:begin // dp_en0 = 1 , reti_en0= 1
                next_head = head + 1;
                next_tail = tail + 1;
                next_entry_cnt = entry_cnt;
            end
            4'b1011,4'b0111:begin //dp_en0 = 1, reti_en0 = reti_en1 = 1
                next_head = head + 2;
                next_tail = tail + 1;
                next_entry_cnt = entry_cnt -1;
            end
            4'b1110,4'b1101:begin //dp_en0 = dp_en1 = 1,reti_en0 = 1
                next_head = head + 1;
                next_tail = tail + 2;
                next_entry_cnt = entry_cnt + 1;
            end
            4'b1111:begin  // dp_en0 = dp_en1 = 1 , reti_en0 = reti_en1 = 1
                next_head = head + 2;
                next_tail = tail + 2;
                next_entry_cnt = entry_cnt;
            end
            default: begin
                next_head = head;
                next_tail = tail;
                next_entry_cnt = entry_cnt;
            end
        endcase
    end
end

endmodule

