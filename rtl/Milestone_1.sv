/*
COMPENG 3DQ5 Project Milestone 1
By: Brayden Roberts and Deyontae Patterson
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

module YUVtoRGB (
	input logic CLOCK_50_I,                  // 50 MHz clock
	input logic resetn,                      // Active-low reset
	input logic [15:0] SRAM_read_data,       // SRAM data
	input logic YUV_enable,
	output logic [15:0] SRAM_write_data,
	output logic SRAM_we_n,
   output logic [17:0] SRAM_address, 		   // SRAM address
	output logic YUV_done
);

M1_state_type state;

// registers for YUV values from SRAM
logic [15:0] Y, U, V;
    
logic [7:0] U_inter_data [5:0];
logic [7:0] V_inter_data [5:0];
	
logic initialize_flag;

// registers for storing colour results
logic signed [31:0] R, G, B, B_odd_buf;
logic [7:0] red_write, green_write, blue_write;

always_comb begin
	if (R[31] == 1'b1) red_write = 8'h00;
	else if (R[31:24] == 8'h00) red_write = R[23:16];
	else red_write = 8'hFF;

	if (G[31] == 1'b1) green_write = 8'h00;
	else if (G[31:24] == 8'h00) green_write = G[23:16];
	else green_write = 8'hFF;

	if (B[31] == 1'b1) blue_write = 8'h00;
	else if (B[31:24] == 8'h00) blue_write = B[23:16];
	else blue_write = 8'hFF;

end
// Intermediate storage for decompressed U and V components
logic signed [31:0] U_prime, V_prime;

logic [15:0] pixel_pair_count;
logic [16:0] rgb_write_count;
logic [7:0] per_row_count;

logic signed [31:0] M1_op_1, M1_op_2, M2_op_1, M2_op_2, M3_op_1, M3_op_2, M1_result, M2_result, M3_result;
logic signed [63:0] M1_result_long, M2_result_long, M3_result_long;

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
		pixel_pair_count <= 16'b0;
		per_row_count <= 8'b0;
		rgb_write_count <= 17'b0;
		initialize_flag <= 1'b0;
		Y <= 8'b0;
		U <= 8'b0;
		V <= 8'b0;
		R <= 32'b0;
		G <= 32'b0;
		B <= 32'b0;
		B_odd_buf <= 8'd0;
		U_prime <= 32'b0;
		V_prime <= 32'b0;
		SRAM_we_n <= 1'b1;
		SRAM_write_data <= 16'd0;
		SRAM_address <= 18'd0;
		
	end else begin
		case (state) 
		S_INIT_0: begin
			SRAM_we_n <= 1'b1;
			if(pixel_pair_count == 16'd38400) begin
				YUV_done <= 1'b1;
			end
			if(YUV_enable == 1'b1) begin
				if (initialize_flag == 1'b0)
					SRAM_address <= pixel_pair_count + U_BASE_ADDRESS;
				else
					SRAM_address <= pixel_pair_count[15:1] + U_BASE_ADDRESS;
				state <= S_INIT_1;
			end
		end
		
		S_INIT_1: begin
			if (initialize_flag == 1'b0)
				SRAM_address <= pixel_pair_count + V_BASE_ADDRESS;
			else
				SRAM_address <= pixel_pair_count[15:1] + V_BASE_ADDRESS;
			state <= S_INIT_2;
		end
		
		S_INIT_2: begin
			SRAM_address <= pixel_pair_count;
			pixel_pair_count <= pixel_pair_count + 1'b1;
			per_row_count <= per_row_count + 1'b1;
			
			state <= S_INIT_3;
		end
		
		S_INIT_3: begin
			if (initialize_flag == 1'b0)
				SRAM_address <= pixel_pair_count + U_BASE_ADDRESS;
			else
				SRAM_address <= pixel_pair_count[15:1] + 2'd1 + U_BASE_ADDRESS;
			
			U_inter_data[0] <= SRAM_read_data[15:8];
			U_inter_data[1] <= SRAM_read_data[15:8];
			U_inter_data[2] <= SRAM_read_data[15:8];
			U_inter_data[3] <= SRAM_read_data[7:0];
			
			state <= S_INIT_4;
		end
		
		S_INIT_4: begin
			if (initialize_flag == 1'b0)
				SRAM_address <= pixel_pair_count + V_BASE_ADDRESS;
			else
				SRAM_address <= pixel_pair_count[15:1] + 2'd1 + V_BASE_ADDRESS;
			
			V_inter_data[0] <= SRAM_read_data[15:8];
			V_inter_data[1] <= SRAM_read_data[15:8];
			V_inter_data[2] <= SRAM_read_data[15:8];
			V_inter_data[3] <= SRAM_read_data[7:0];
			
			state <= S_INIT_5;
		end
		
		S_INIT_5: begin
			Y <= SRAM_read_data;
			
			state <= S_INIT_6;
		end
		
		S_INIT_6: begin
			U_inter_data[4] <= SRAM_read_data[15:8];
			U_inter_data[5] <= SRAM_read_data[7:0];
			
			state <= S_INIT_7;
		end
		
		S_INIT_7: begin
			V_inter_data[4] <= SRAM_read_data[15:8];
			V_inter_data[5] <= SRAM_read_data[7:0];
			M1_op_1 <= (Y[15:8] - 5'd16);
			M1_op_2 <= 17'd76284;
			M2_op_1 <= (V_inter_data[2] - 8'd128);
			M2_op_2 <= 17'd104595;
			M3_op_1 <= (U_inter_data[2] - 8'd128);
			M3_op_2 <= 15'd25624;
			
			initialize_flag <= 1'b1;
			state <= S_CONVERT_RGB_0;
		end
		
		S_CONVERT_RGB_0: begin
			SRAM_we_n <= 1'b1;
			if (pixel_pair_count[0] == 1'b1)
				SRAM_address <= pixel_pair_count[15:1] + 2'd2 + U_BASE_ADDRESS;
			
			R <= M1_result + M2_result;
			G <= M1_result - M3_result;
			B <= M1_result;
			M1_op_1 <= (V_inter_data[2] - 8'd128);
			M1_op_2 <= 16'd53281;
			M2_op_1 <= (U_inter_data[2] - 8'd128);
			M2_op_2 <= 18'd132251;
			
			state <= S_CONVERT_RGB_1;
		end
		
		S_CONVERT_RGB_1: begin
			if (pixel_pair_count[0] == 1'b1)
				SRAM_address <= pixel_pair_count[15:1] + 2'd2 + V_BASE_ADDRESS;
			G <= G - M1_result;
			B <= B + M2_result;
			M1_op_1 <= (V_inter_data[0] + V_inter_data[5]);
			M1_op_2 <= 5'd21;
			M2_op_1 <= (V_inter_data[1] + V_inter_data[4]);
			M2_op_2 <= 6'd52;
			M3_op_1 <= (V_inter_data[2] + V_inter_data[3]);
			M3_op_2 <= 8'd159;
			
			state <= S_CALC_U;
		end
		
		S_CALC_U: begin
			SRAM_address <= pixel_pair_count;	
			V_prime <= M1_result - M2_result + M3_result + 128;
			M1_op_1 <= (U_inter_data[0] + U_inter_data[5]);
			M1_op_2 <= 5'd21;
			M2_op_1 <= (U_inter_data[1] + U_inter_data[4]);
			M2_op_2 <= 6'd52;
			M3_op_1 <= (U_inter_data[2] + U_inter_data[3]);
			M3_op_2 <= 8'd159;
			
			if (per_row_count < 8'd157)
				state <= S_CALC_V;
			else
				state <= S_LEAD_OUT_0;
		end
		
      	S_CALC_V: begin
			if (pixel_pair_count[0] == 1'b1) begin
				U <= SRAM_read_data[7:0];
				
				U_inter_data[0] <= U_inter_data[1];
				U_inter_data[1] <= U_inter_data[2];
				U_inter_data[2] <= U_inter_data[3];
				U_inter_data[3] <= U_inter_data[4];
				U_inter_data[4] <= U_inter_data[5];
				U_inter_data[5] <= SRAM_read_data[15:8];
			end
			
			else begin
				U_inter_data[0] <= U_inter_data[1];
				U_inter_data[1] <= U_inter_data[2];
				U_inter_data[2] <= U_inter_data[3];
				U_inter_data[3] <= U_inter_data[4];
				U_inter_data[4] <= U_inter_data[5];
				U_inter_data[5] <= U[7:0];
			end
			
			SRAM_we_n <= 1'b0;
			SRAM_address <= RGB_BASE_ADDRESS + rgb_write_count;
			SRAM_write_data <= {red_write, green_write};
			rgb_write_count <= rgb_write_count + 1'b1;
			
			U_prime <= M1_result - M2_result + M3_result + 128;
			
			M1_op_1 <= (Y[7:0] - 5'd16);
			M1_op_2 <= 17'd76284;
			M2_op_1 <= (V_prime[31:8] - 8'd128);
			M2_op_2 <= 17'd104595;
			M3_op_1 <= (V_prime[31:8] - 8'd128);
			M3_op_2 <= 16'd53281;
			
			
			
			state <= S_CONVERT_RGB_2;
		end
		
      	S_CONVERT_RGB_2: begin
			if (pixel_pair_count[0] == 1'b1) begin
				V <= SRAM_read_data[7:0];
				V_inter_data[0] <= V_inter_data[1];
				V_inter_data[1] <= V_inter_data[2];
				V_inter_data[2] <= V_inter_data[3];
				V_inter_data[3] <= V_inter_data[4];
				V_inter_data[4] <= V_inter_data[5];
				V_inter_data[5] <= SRAM_read_data[15:8];
			end
			
			else begin
				V_inter_data[0] <= V_inter_data[1];
				V_inter_data[1] <= V_inter_data[2];
				V_inter_data[2] <= V_inter_data[3];
				V_inter_data[3] <= V_inter_data[4];
				V_inter_data[4] <= V_inter_data[5];
				V_inter_data[5] <= V[7:0];
			end
			
			SRAM_we_n <= 1'b1;
			
			R <= M1_result + M2_result;
			G <= M1_result - M3_result;
			B_odd_buf <= M1_result;
			
			M1_op_1 <= (U_prime[31:8] - 8'd128);
			M1_op_2 <= 15'd25624;
			M2_op_1 <= (U_prime[31:8] - 8'd128);
			M2_op_2 <= 18'd132251;
			
			state <= S_CONVERT_RGB_3;
		end
		
      	S_CONVERT_RGB_3: begin
			Y = SRAM_read_data;
			pixel_pair_count <= pixel_pair_count + 1'b1;
			per_row_count <= per_row_count + 1'b1;
			SRAM_we_n <= 1'b0;
			SRAM_address <= RGB_BASE_ADDRESS + rgb_write_count;
			SRAM_write_data <= {blue_write, red_write};
			rgb_write_count <= rgb_write_count + 1'b1;
			G <= G - M1_result;
			B <= B_odd_buf + M2_result;
			
			state <= S_NEXT_PIXEL;
		end
		
		S_NEXT_PIXEL: begin
			SRAM_address <= RGB_BASE_ADDRESS + rgb_write_count;
			SRAM_write_data <= {green_write, blue_write};
			rgb_write_count <= rgb_write_count + 1'b1;
			M1_op_1 <= (Y[15:8] - 5'd16);
			M1_op_2 <= 17'd76284;
			M2_op_1 <= (V_inter_data[2] - 8'd128);
			M2_op_2 <= 17'd104595;
			M3_op_1 <= (U_inter_data[2] - 8'd128);
			M3_op_2 <= 15'd25624;
			
			if(per_row_count < 8'd161)
				state <= S_CONVERT_RGB_0;
			else begin
				state <= S_INIT_0;
				per_row_count <= 1'b0;
				pixel_pair_count <= pixel_pair_count - 1'b1;
			end
		end
		
      	S_LEAD_OUT_0: begin
			U_inter_data[0] <= U_inter_data[1];
			U_inter_data[1] <= U_inter_data[2];
			U_inter_data[2] <= U_inter_data[3];
			U_inter_data[3] <= U_inter_data[4];
			U_inter_data[4] <= U_inter_data[5];
			
			SRAM_we_n <= 1'b0;
			SRAM_address <= RGB_BASE_ADDRESS + rgb_write_count;
			SRAM_write_data <= {red_write, green_write};
			rgb_write_count <= rgb_write_count + 1'b1;
			U_prime <= M1_result - M2_result + M3_result + 128;
			
			M1_op_1 <= (Y[7:0] - 5'd16);
			M1_op_2 <= 17'd76284;
			M2_op_1 <= (V_prime[31:8] - 8'd128);
			M2_op_2 <= 17'd104595;
			M3_op_1 <= (V_prime[31:8] - 8'd128);
			M3_op_2 <= 16'd53281;
			
			
			state <= S_LEAD_OUT_1;
		end
		
		S_LEAD_OUT_1: begin
			V_inter_data[0] <= V_inter_data[1];
			V_inter_data[1] <= V_inter_data[2];
			V_inter_data[2] <= V_inter_data[3];
			V_inter_data[3] <= V_inter_data[4];
			V_inter_data[4] <= V_inter_data[5];
			
			SRAM_address <= pixel_pair_count;
			SRAM_we_n <= 1'b1;
			
			R <= M1_result + M2_result;
			G <= M1_result - M3_result;
			B_odd_buf <= M1_result;
			
			M1_op_1 <= (U_prime[31:8] - 8'd128);
			M1_op_2 <= 15'd25624;
			M2_op_1 <= (U_prime[31:8] - 8'd128);
			M2_op_2 <= 18'd132251;
			
			state <= S_CONVERT_RGB_3;
		end
		default: state <= S_INIT_0;
		endcase
	end
end
            
endmodule
