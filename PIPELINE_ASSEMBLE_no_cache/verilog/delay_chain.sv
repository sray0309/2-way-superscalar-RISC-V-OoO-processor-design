`timescale 1ns/100ps

module delay_chain 
	#(
		// synopsys template
		parameter INPUT_BITS_NUM = 16,
		parameter NUM_DELAY_CYCLE= 4
		)
	(
	input clock, reset, enable,
	input [INPUT_BITS_NUM-1:0] data_in,

	output logic [INPUT_BITS_NUM-1:0] data_out
	);
	logic [(NUM_DELAY_CYCLE-1)*INPUT_BITS_NUM-1:0] internal_wire;
	dff #(.INPUT_BITS_NUM(INPUT_BITS_NUM)) dff_chain [NUM_DELAY_CYCLE-1:0] (
		.clock(clock),
        .reset(reset),
        .enable(enable),
		.data_in({internal_wire,data_in}),
		.data_out({data_out,internal_wire})
		);
endmodule

module dff #(parameter INPUT_BITS_NUM=16)
	(
	input clock, reset, enable,
	input [INPUT_BITS_NUM-1:0] data_in,
	output logic [INPUT_BITS_NUM-1:0] data_out
	);

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			data_out 	<=	`SD 0;
        end else if (enable)
            data_out    <=  `SD data_in;
		else begin
			data_out 	<= 	`SD data_out;
		end
	end

endmodule