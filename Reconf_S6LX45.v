module RECONF_S6LX45
(
	input 		 RESET,
	input			 CLK,
	input			 START,		// H = Reconfigulation start
	input [23:0] BSADRi		// Bitstream Address (SPI-Flash)
);
`define DEVID	32'h04008093	// for S6LX45 (IDCODE[27:0])

reg [23:0] BSADR;
function [15:0] ReconfSeq (input [3:0] A);
`define	OPC 8'h0B	// SPI-Flash OpCode: Read data array
	case(A)
	4'h0: ReconfSeq = 16'hFFFF;	// Sync 0
	4'h1: ReconfSeq = 16'hAA99;	// Sync 1
	4'h2: ReconfSeq = 16'h5566;	// Sync 2

	4'h3: ReconfSeq = 16'h3261;	// type 1, write to GENERAL_1 reg. (Golden BitStream)
	4'h4: ReconfSeq = BSADR[15:0];
	4'h5: ReconfSeq = 16'h3281;	// type 1, write to GENERAL_2 reg. (Golden BitStream)
	4'h6: ReconfSeq = {`OPC,BSADR[23:16]};

	4'h7: ReconfSeq = 16'h32A1;	// type 1, write to GENERAL_3 reg. (Fallback Bitstream)
	4'h8: ReconfSeq = BSADR[15:0];
	4'h9: ReconfSeq = 16'h32C1;	// type 1, write to GENERAL_4 reg. (Fallback BitStream)
	4'hA: ReconfSeq = {`OPC,BSADR[23:16]};
	
	4'hB: ReconfSeq = 16'h30A1;	// type 1, write to CMD reg.
	4'hC: ReconfSeq = 16'h000E;	// cmd IPROG
	4'hD: ReconfSeq = 16'h2000;	// type 1, nop

	default: ReconfSeq = 16'h2000;
	endcase
endfunction

reg        ACTIVE = 0;
reg		  RCENB = 0;
reg [ 3:0] RCADR = 0;
reg [15:0] RCSEQ = 0;
always @(negedge CLK or posedge RESET) begin
	if (RESET) begin
		ACTIVE <= 0;
		 RCADR <= 0;
		 RCSEQ <= 0;
		 RCENB <= 0;
	end
	else begin
		if (ACTIVE) begin
			RCSEQ <= ReconfSeq(RCADR);
			RCADR <= (RCADR!=15) ? (RCADR+1) : RCADR;
			RCENB <= (RCADR!=15);
		end
		else if (START) begin
			ACTIVE <= 1'b1;
			BSADR  <= BSADRi;
		end
	end
end
wire [15:0] RCSQD = {
	RCSEQ[ 8],RCSEQ[ 9],RCSEQ[10],RCSEQ[11],RCSEQ[12],RCSEQ[13],RCSEQ[14],RCSEQ[15],
	RCSEQ[ 0],RCSEQ[ 1],RCSEQ[ 2],RCSEQ[ 3],RCSEQ[ 4],RCSEQ[ 5],RCSEQ[ 6],RCSEQ[ 7]
};


ICAP_SPARTAN6 #(
	.DEVICE_ID(`DEVID)
)
reconf (
	.BUSY(),			// 1-bit output: Busy/Ready output
	.O(), 			// 16-bit output: Configuartion data output bus
	.CE(~RCENB),	// 1-bit input: Active-Low ICAP Enable input
	.CLK(CLK),		// 1-bit input: Clock input
	.I(RCSQD),		// 16-bit input: Configuration data input bus
	.WRITE(1'b0)	// 1-bit input: Read/Write control input
);

endmodule
