module rob_tb;

<<<<<<< HEAD
parameter ROB_SIZE =8;
=======
parameter ROB_SIZE =64;
>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c
// parameter CB_IDX_WIDTH = $clog2(CB_SIZE);
parameter DATA_WIDTH = 32;

logic clock, reset;

//input
ID_PACKET [1:0] id_packet_in;
CDB_PACKET cdb_packet_in;
logic [1:0][`PREG_IDX_WIDTH-1:0] freelist_pdest_new, rat_pdest_old;
ROB_PACKET [ROB_SIZE-1:0] data;

//output
ROB_PACKET [1:0] rob_packet_out;
logic rob_full, rob_almost_full;

`ifdef DEBUG
    logic [ROB_SIZE-1:0] retire_tag;
    logic [ROB_SIZE-1:0] retire_rdy_indicator;
    logic [$clog2(ROB_SIZE)-1:0] head, tail;
    logic head_retire_rdy,head_p1_retire_rdy;
    logic [$clog2(ROB_SIZE):0] entry_cnt;
`endif

rob #(
    // .ROB_SIZE(ROB_SIZE)
)DUT(
    .clock(clock),
    .reset(reset),
    .id_packet_in(id_packet_in),
    .cdb_packet_in(cdb_packet_in),
    .freelist_pdest_new(freelist_pdest_new),
    .rat_pdest_old(rat_pdest_old),
    .rob_packet_out(rob_packet_out),
    .rob_full(rob_full),
    .rob_almost_full(rob_almost_full)
    `ifdef DEBUG
        ,.retire_tag(retire_tag)
        ,.data(data)
        ,.head(head)
        ,.tail(tail)
        ,.retire_rdy_indicator(retire_rdy_indicator)
        ,.head_p1_retire_rdy(head_p1_retire_rdy)
        ,.head_retire_rdy(head_retire_rdy)
        ,.entry_cnt(entry_cnt)
    `endif
);

integer data_cnt;
string s;
////////////////////////////////////////////// clock generation ///////////////////////////////////////////////////////////////
always #5 clock = ~clock;

////////////////////////////////////////////// reset trigger /////////////////////////////////////////////////////////////////
initial begin
    reset = 0;
    @(negedge clock); 
    reset = 1;
    id_packet_in = 0;
    cdb_packet_in = 0;
    freelist_pdest_new = 0;
    rat_pdest_old = 0;
    @(negedge clock); 
    reset = 0;
    @(posedge clock);
    $display("############## Time:%0t RESET information: ##############\n\
 id_packet_in:%0d\n\
 cdb_packet_in:%0d\n\
 freelist_pdest_new:%0d\n\
 rat_pdest_old:%0d\n\
 rob_packet_out:%0d\n\
 rob_full:%0d   rob_almost_full:%0d\n\
########################################################\n"
        ,$time, 
        id_packet_in,
        cdb_packet_in,
        freelist_pdest_new,
        rat_pdest_old,
        rob_packet_out, 
        rob_full,rob_almost_full);
`ifdef DEBUG
    s = {s, $sformatf("############# Time:%0t Reset Debug ##############\n",$time)};
    s = {s, $sformatf("head:%0d,   tail:%0d\n",head,tail)};
    s = {s, $sformatf("entry_cnt:%0d\n",entry_cnt)};
    s = {s, $sformatf("head_retire_rdy:%0d,   head_p1_retire_rdy:%0d\n",head_retire_rdy,head_p1_retire_rdy)};
    for (data_cnt = 0; data_cnt<ROB_SIZE; data_cnt++) begin
        s = {s, $sformatf("data[%0d]inst = %0d,  T_new=%0d,  T_old=%0d,  retire_tag[%0d] = %0d,  retire_indicator = %0d\n",data_cnt,data[data_cnt].inst,data[data_cnt].T_new,data[data_cnt].T_old,data_cnt,retire_tag[data_cnt],retire_rdy_indicator[data_cnt])};
    end
    s = {s, $sformatf("#################################################\n")};
    $display(s);
`endif
end


task trigger_reset;
    @(negedge clock);
        reset = 1;    
    @(negedge clock);
    @(negedge clock);
        reset = 0;
endtask
//////////////////////////////////////////////////////////////// driver /////////////////////////////////////////////////////////////////////////
mailbox #(INST) in_mb;
mailbox #(INST) out_mb;

task drive;
input logic dr_valid1, dr_valid2;
input INST dr_inst1, dr_inst2;
input [`PREG_IDX_WIDTH-1:0] dr_fl_pdest1, dr_fl_pdest2, dr_rat_pdest1, dr_rat_pdest2;
input logic dr_cdb_en1, dr_cdb_en2;
input logic [`PREG_IDX_WIDTH-1:0] dr_cdb_tag1, dr_cdb_tag2;
@(negedge clock) begin
    id_packet_in[0].valid = dr_valid1;
    id_packet_in[1].valid = dr_valid2;
    id_packet_in[0].inst = dr_inst1;
    id_packet_in[1].inst = dr_inst2;
    freelist_pdest_new[0] = dr_fl_pdest1;
    freelist_pdest_new[1] = dr_fl_pdest2;
    rat_pdest_old[0] = dr_rat_pdest1;
    rat_pdest_old[1] = dr_rat_pdest2;
    cdb_packet_in.cdb_valid[0] = dr_cdb_en1;
    cdb_packet_in.cdb_valid[1] = dr_cdb_en2;
    cdb_packet_in.cdb_tag[0] = dr_cdb_tag1;
    cdb_packet_in.cdb_tag[1] = dr_cdb_tag2;
    // if (dr_wr_en1 & dr_wr_en2) begin
        // in_mb.put(dr_inst1);
        // in_mb.put(dr_inst2);
    // end
    // else if (dr_wr_en1 & (!dr_wr_en2)) in_mb.put(dr_din1);
//     if (dr_rd_en1 & dr_rd_en2) begin
//         out_mb.put(dout1);
//         out_mb.put(dout2);
//         check();
//     end
//     else if (dr_rd_en1 & (!dr_rd_en2)) begin
//         out_mb.put(dout1);
//         check();
//     end
end
fork
    @(posedge clock) begin
    $display("############### Time:%0t input data information: ###############\n\
 inst1_valid:%0d         inst2_valid:%0d\n\
 inst1:%0d               inst2:%0d\n\
 freelist_pdest1:%0d     freelist_pdest2:%0d\n\
 rat_pdest1:%0d         rat_pdest2:%0d\n\
 cdb_valid1:%0d          cdb_valid2:%0d\n\
 cdb_tag1:%0d            cdb_tag2:%0d\n\
###############################################################\n"
        ,$time, 
        id_packet_in[0].valid,id_packet_in[1].valid,
        id_packet_in[0].inst,id_packet_in[1].inst,
        freelist_pdest_new[0],freelist_pdest_new[1],
        rat_pdest_old[0],rat_pdest_old[1],
        cdb_packet_in.cdb_valid[0],cdb_packet_in.cdb_valid[1],
        cdb_packet_in.cdb_tag[0],cdb_packet_in.cdb_tag[1]);
    end
    @(posedge clock) begin
        $display("############### Time:%0t output data information: ###############\n\
 rob_out_Tnew1:%0d         rob_out_Tnew2:%0d\n\
 rob_out_Told1:%0d         rob_out_Told2:%0d\n\
 rob_out_inst1:%0d         rob_out_inst2:%0d\n\
 rob_full:%0d              rob_almost_full:%0d\n\
###############################################################\n"
        ,$time, 
        rob_packet_out[0].T_new,rob_packet_out[1].T_new,
        rob_packet_out[0].T_old,rob_packet_out[1].T_old,
        rob_packet_out[0].inst,rob_packet_out[1].inst,
        rob_full,rob_almost_full);
    end
    `ifdef DEBUG
    @(posedge clock) begin
    s = "";
    s = {s, $sformatf("############# Time:%0t Debug information ##############\n",$time)};
    s = {s, $sformatf("head:%0d,   tail:%0d\n",head,tail)};
    s = {s, $sformatf("entry_cnt:%0d\n",entry_cnt)};
    s = {s, $sformatf("head_retire_rdy:%0d,   head_p1_retire_rdy:%0d\n",head_retire_rdy,head_p1_retire_rdy)};
    for (data_cnt = 0; data_cnt<ROB_SIZE; data_cnt++) begin
        s = {s, $sformatf("data[%0d]inst = %0d,  T_new=%0d,  T_old=%0d,  retire_tag[%0d] = %0d,  retire_indicator = %0d\n",data_cnt,data[data_cnt].inst,data[data_cnt].T_new,data[data_cnt].T_old,data_cnt,retire_tag[data_cnt],retire_rdy_indicator[data_cnt])};
    end
    s = {s, $sformatf("#################################################\n")};
    $display(s);
    end
    `endif
    
join_none

endtask

// //////////////////////////////////////////////////////////////// checker ////////////////////////////////////////////////////////////////////////
// task check;
// logic [DATA_WIDTH-1:0] ck_din1, ck_din2, ck_dout1, ck_dout2;
// fork
//     @(posedge clock) begin
//         if (rd_en1 & rd_en2) begin
//             if (in_mb.num() == 0 | out_mb.num() == 0) begin
//                 $display("################### mailbox is empty!! ###########################\n");
//                 $finish;
//             end 
//             else begin
//             in_mb.get(ck_din1);
//             out_mb.get(ck_dout1);
//             end
//             if (in_mb.num() == 0 | out_mb.num() == 0) begin
//                 $display("#################### mailbox is empty!! ##########################\n");
//                 $finish;
//             end 
//             else begin
//             in_mb.get(ck_din2);
//             out_mb.get(ck_dout2);
//             if (ck_din1 !== ck_dout1 || ck_din2 !== ck_dout2) begin
//                 $display("############ Time:%0t check data information: ############\n\
//  @@@failed\n\
//  ck_din1:%0d     ck_dout1:%0d\n\
//  ck_din2:%0d     ck_dout2:%0d\n\
// #########################################################\n"
//         ,$time, 
//         ck_din1,ck_dout1,
//         ck_din2,ck_dout2);
//         // $finish;
//                 end
//             end
//         end
//         else if (rd_en1) begin
//             if (in_mb.num() == 0 | out_mb.num() == 0) begin
//                 $display("#################### mailbox is empty!! ##########################\n");
//                 $finish;
//             end 
//             else begin
//             in_mb.get(ck_din1);
//             out_mb.get(ck_dout1);
//             if (ck_din1 !== ck_dout1) begin
//             $display("############ Time:%0t check data information: ############\n\
//  @@@failed\n\
//  ck_din1:%0d     ck_dout1:%0d\n\
// #########################################################\n"
//         ,$time, 
//         ck_din1,ck_dout1);
//         // $finish;
//                 end
//             end
//         end
//     end
// join_none
// endtask
// //////////////////////////////////////////////////////////////// test case //////////////////////////////////////////////////////////////////////
// task constant_drive;
//     logic [DATA_WIDTH-1] data1, data2;
//     repeat(100) begin
//     data1 = $urandom_range(0,4294967295);
//     data2 = $urandom_range(0,4294967295);
//     drive(1,1,data1,data2,0,0);
//     drive(0,0,0,0,1,1);
//     end
// endtask

// task full_drive;
//     logic [DATA_WIDTH-1] data1, data2;
//     repeat(CB_SIZE/2) begin
//     data1 = $urandom_range(0,4294967295);
//     data2 = $urandom_range(0,4294967295);
//     drive(1,1,data1,data2,0,0);
//     end
//     repeat(CB_SIZE/2) drive(0,0,0,0,1,1);
// endtask
//////////////////////////////////////////////////////////////// testbench //////////////////////////////////////////////////////////////////////
initial begin
    clock = 0;
    repeat(3) @(negedge clock);
<<<<<<< HEAD
    drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),32,33,0,1,0,0,0,0);
    drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),34,35,2,3,0,0,0,0);
    drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),36,37,4,5,0,0,0,0);
    // drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),38,39,6,7,0,0,0,0);
    // drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),40,41,8,9,0,0,0,0);
    // drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),40,41,8,9,0,0,0,0);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),42,43,10,11,1,1,32,33);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),44,45,12,13,1,1,34,35);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),46,47,14,15,1,1,36,37);
    
    
=======
    drive(1,0,$urandom_range(0,10000),$urandom_range(0,10000),32,33,0,1,0,0,0,0);
    drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),34,35,2,3,0,0,0,0);
    drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),36,37,4,5,0,0,0,0);
    drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),38,39,6,7,0,0,0,0);
    drive(1,1,$urandom_range(0,10000),$urandom_range(0,10000),40,41,8,9,0,0,0,0);
    // drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),40,41,8,9,0,0,0,0);

    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),46,47,14,15,1,1,36,37);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),44,45,12,13,1,1,34,35);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),42,43,10,11,1,1,32,33);
>>>>>>> 8b1f9a6a43214d9f0d8f8a932b12db9177f0826c
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),46,47,14,15,0,0,0,0);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),46,47,14,15,0,0,0,0);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),46,47,14,15,0,0,36,37);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),48,49,16,17,0,0,38,39);
    drive(0,0,$urandom_range(0,10000),$urandom_range(0,10000),50,51,18,19,0,0,40,41);

    @(negedge clock);
    $finish;
end

endmodule