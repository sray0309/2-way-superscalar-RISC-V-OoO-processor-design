`timescale 1ns/100ps
module icache_controller(
    //synopsys template
    input   clock,
    input   reset,
    input   [3:0] Imem2proc_response,        // FROM MEM
    input  [`DATA_SIZE-1:0] Imem2proc_data,  // FROM MEM
    input   [3:0] Imem2proc_tag,             // FROM MEM

    input  [63:0] proc2Icache_addr,          // FROM IF
    input  [`DATA_SIZE-1:0] cachemem_data,   // FROM CACHE MEM
    input   cachemem_valid,                  // FROM CACHE MEM

    output BUS_COMMAND proc2Imem_command,    // TO MEM
    output logic [63:0] proc2Imem_addr,      // TO MEM

    output logic [`DATA_SIZE-1:0] Icache_data_out, // TO IF value is memory[proc2Icache_addr]
    output logic  Icache_valid_out,              // TO IF  when this is high

    output logic  [`ICACHE_IDX_WIDTH-1:0] current_index, // TO CACHE MEM
    output logic  [`ICACHE_TAG_WIDTH-1:0] current_tag,   // TO CACHE MEM
    output logic  [`ICACHE_IDX_WIDTH-1:0] last_index,    // TO CACHE MEM
    output logic  [`ICACHE_TAG_WIDTH-1:0] last_tag,      // TO CACHE MEM
    output logic  data_write_enable                      // TO CACHE MEM
  
  );

  logic [3:0] current_mem_tag;

  logic miss_outstanding;

  wire changed_addr = (current_index != last_index) || (current_tag != last_tag); // if this cycle addr is diff from last cycle addr

  assign {current_tag, current_index} = proc2Icache_addr[31:3];  // get this current cache tag and idx from  this cycle addr

  assign Icache_data_out = cachemem_data;  // output the data from Icache mem to IF

  assign Icache_valid_out = cachemem_valid; // output the valid bit from Icache mem to IF

  assign proc2Imem_addr = {proc2Icache_addr[63:3],3'b0};  // output the addr to MEM
  assign proc2Imem_command = (miss_outstanding && !changed_addr) ?  BUS_LOAD : BUS_NONE;// to MEM command, if the last cycle cache missed or unanswered, then send out LOAD this cycle

  assign data_write_enable =  (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0); // 1 if received correct data from MEM and data can be written into the cache

  wire update_mem_tag = changed_addr || miss_outstanding || data_write_enable; // changed_addr and data_write_enable is used to clear the current_mem_tag

  wire unanswered_miss = changed_addr ? !Icache_valid_out : // 1 if Icache is missed
                                        miss_outstanding && (Imem2proc_response == 0); // cache miss request sent but not responsed correctly

  // synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if(reset) begin
      last_index       <= `SD -1;   // These are -1 to get ball rolling when
      last_tag         <= `SD -1;   // reset goes low because addr "changes"
      current_mem_tag  <= `SD 0;              
      miss_outstanding <= `SD 0;
    end else begin
      last_index       <= `SD current_index;
      last_tag         <= `SD current_tag;
      miss_outstanding <= `SD unanswered_miss;
      
      if(update_mem_tag)
        current_mem_tag <= `SD Imem2proc_response;
    end
  end

endmodule

