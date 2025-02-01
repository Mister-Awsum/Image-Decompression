/*
COMPENG 3DQ5 Project Milestone 3
By: Brayden Roberts and Deyontae Patterson
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

//`include "define_state.h"


module S_Conversion (
    input logic CLOCK_50_I,                  // 50 MHz clock
    input logic resetn                      // Active-low reset
    input logic [15:0] SRAM_read_data,       // SRAM data
	input logic S_enable
    output logic [15:0] SRAM_write_data,
	output logic SRAM_we_n,
    output logic [17:0] SRAM_address, 		   // SRAM address
    output logic S_done
);

M2_state state;

// registers for YUV values from SRAM
logic [15:0] S, C;
    
// Intermediate storage for decompressed U and V components
logic [7:0] S_prime;

logic [15:0] pixel_pair_count;
logic [16:0] S_write_count;
logic [7:0] per_row_count;

logic [31:0] M1_op_1, M1_op_2, M2_op_1, M2_op_2, M3_op_1, M3_op_2, M1_result, M2_result, M3_result;
logic [63:0] M1_result_long, M2_result_long, M3_result_long;

assign M1_result_long = M1_op_1 * M1_op_2;
assign M1_result = M1_result_long[31:0];

assign M2_result_long = M2_op_1 * M2_op_2;
assign M2_result = M2_result_long[31:0];

assign M3_result_long = M3_op_1 * M3_op_2;
assign M3_result = M3_result_long[31:0];

// State machine for YUV to RGB conversion
always @(posedge CLOCK_50_I or negedge resetn) begin
	if (!resetn) begin
		state <= S_INIT_0;
		pixel_pair_count <= 0;
		per_row_count <= 0;
		S <= 0;
		S_prime <= 0;
		C <= 0;
		SRAM_we_n <= 1;

	end else begin
		case (state) 
		S_INIT_0: begin
			
			state <= S_INIT_1
		end
		
		S_INIT_1: begin
			
			state <= S_INIT_2;
		end
		
		S_INIT_2: begin
						
			state <= S_T2;
		end
		
		S_T2: begin
			// Read S'
			
			T[i][j] <= M1_result + M2_result + M3_result

			M1_op_1 <= S_prime[i][3]
			M1_op_2 <= C[3][j]

			M2_op_1 <= S_prime[i][4]
			M2_op_2 <= C[4][j]

			M3_op_1 <= S_prime[i][5]
			M3_op_2 <= C[5][j]

			state <= S_T5;
		end

		default: state <= S_INIT_0;
		endcase
	end
end
            
endmodule