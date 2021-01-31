/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.v                                           //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  // 
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __REGFILE_V__
`define __REGFILE_V__

`timescale 1ns/100ps

module regfile(
        input   [1:0][`PREG_IDX_WIDTH-1:0] rda_idx, rdb_idx,  wr_idx, // read/write index
        input   [1:0][`XLEN-1:0] wr_data,            // write data
        input   [1:0]      wr_en, 
        input    wr_clk,

        output logic [1:0][`XLEN-1:0] rda_out, rdb_out    // read data
         
      );
  
      parameter PREG_SIZE = 32;
  logic  [PREG_SIZE-1:0] [`XLEN-1:0] registers;   // 32, 64-bit Registers


  // wire   [`XLEN-1:0] rda_reg = registers[rda_idx];
  // wire   [`XLEN-1:0] rdb_reg = registers[rdb_idx];
  wire [1:0][`XLEN-1:0] rda_reg;
  wire [1:0][`XLEN-1:0] rdb_reg;
  assign rda_reg[0] = registers[rda_idx[0]];
  assign rda_reg[1] = registers[rda_idx[1]];
  assign rdb_reg[0] = registers[rdb_idx[0]];
  assign rdb_reg[1] = registers[rdb_idx[1]];


  always_comb begin
    //
    // Read port A0
    //
    if (rda_idx[0] == `ZERO_PREG)
      rda_out[0] = 0;
    else if (wr_en[0] && (wr_idx[0] == rda_idx[0]))
      rda_out[0] = wr_data[0];  // internal forwarding
    else if (wr_en[1] && (wr_idx[1] == rda_idx[0]))
      rda_out[0] = wr_data[1];
    else 
      rda_out[0] = rda_reg[0];

    //
    // Read port A1
    //
    if (rda_idx[1] == `ZERO_PREG)
      rda_out[1] = 0;
    else if (wr_en[0] && (wr_idx[0] == rda_idx[1]))
      rda_out[1] = wr_data[0];  // internal forwarding
    else if (wr_en[1] && (wr_idx[1] == rda_idx[1]))
      rda_out[1] = wr_data[1];  // internal forwarding
    else
      rda_out[1] = rda_reg[1];
  end
 


  always_comb begin
    //
    // Read port B0
    //
    if (rdb_idx[0] == `ZERO_PREG)
      rdb_out = 0;
    else if (wr_en[0] && (wr_idx[0] == rdb_idx[0]))
      rdb_out[0] = wr_data[0];  // internal forwarding
    else if (wr_en[0] && (wr_idx[1] == rdb_idx[0]))
      rdb_out[0] = wr_data[1];  
    else
      rdb_out[0] = rdb_reg[0];


    //
    // Read port B1
    //
    if (rdb_idx[1] == `ZERO_PREG)
      rdb_out[1] = 0;
    else if (wr_en[0] && (wr_idx[0] == rdb_idx[1]))
      rdb_out[1] = wr_data[0];  // internal forwarding
    else if (wr_en[1] && (wr_idx[1] == rdb_idx[1]))
      rdb_out[1] = wr_data[1];  // internal forwarding
    else
      rdb_out[1] = rdb_reg[1];
  end


  // Write port
  //
  always_ff @(posedge wr_clk) begin
    if (wr_en[0]) begin
      registers[wr_idx[0]] <= `SD wr_data[0];
    end
    if (wr_en[1]) begin
      registers[wr_idx[1]] <= `SD wr_data[1];
    end
  end

endmodule // regfile
`endif //__REGFILE_V__
