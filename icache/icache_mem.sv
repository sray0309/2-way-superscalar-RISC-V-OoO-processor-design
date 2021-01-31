// cachemem32x64

`timescale 1ns/100ps

module cache(
    // synopsys template
        input clock, reset, wr1_en,
        input  [`ICACHE_IDX_WIDTH:0] wr1_idx, rd1_idx, //direct mapped
        input  [`ICACHE_TAG_WIDTH:0] wr1_tag, rd1_tag,
        input [`DATA_SIZE:0] wr1_data, 

        output [`DATA_SIZE:0] rd1_data,
        output rd1_valid
        
      );



  logic [`ICACHE_LINE_NUM:0] [`DATA_SIZE       :0] data  ;
  logic [`ICACHE_LINE_NUM:0] [`ICACHE_TAG_WIDTH:0] tags  ; 
  logic [`ICACHE_LINE_NUM:0]                       valids;

  assign rd1_data = data[rd1_idx];
  assign rd1_valid = valids[rd1_idx] && (tags[rd1_idx] == rd1_tag);

  always_ff @(posedge clock) begin
    if(reset)
      valids <= `SD 31'b0;
    else if(wr1_en) 
      valids[wr1_idx] <= `SD 1;
  end
  
  always_ff @(posedge clock) begin
    if(wr1_en) begin
      data[wr1_idx] <= `SD wr1_data;
      tags[wr1_idx] <= `SD wr1_tag;
    end
  end

endmodule
