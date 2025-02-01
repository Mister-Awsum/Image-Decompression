/*
COMPENG 3DQ5 Project Milestone 2
By: Brayden Roberts and Deyontae Patterson
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

module S_Conversion (
    input logic CLOCK_50_I,                  // 50 MHz clock
    input logic resetn,                      // Active-low reset
    input logic [15:0] SRAM_read_data,       // SRAM data
    input logic S_enable,                    // Enable signal for S' fetching
    output logic [15:0] SRAM_write_data,     // Data to write back to SRAM
    output logic SRAM_we_n,                  // Write enable (active-low)
    output logic [17:0] SRAM_address,        // SRAM address
    output logic S_done                      // Indicates completion
);

// Finite State Machines
M2_state_type top_state;

M2_state_type l_fetch_state;
M2_state_type l_t_state;

M2_state_type fetch_state;
M2_state_type t_state;
M2_state_type s_state;
M2_state_type write_state;

M2_state_type e_s_state;
M2_state_type e_write_state;

// Indexing & Counter Variables
logic [4:0] rows, cols;
logic [5:0] rows_long;
logic [7:0] row_address, row_address_w;
logic [8:0] col_address, col_address_w;
logic [5:0] col_base, col_base_w;
logic [4:0] row_base, row_base_w;
logic [7:0] S_buf [1:0];

logic last_block_flag;

logic [7:0] data_count;
logic [5:0] data_count_long;
logic [5:0] write_count;
logic [5:0] write_count_1;

// Dual Port RAMs
logic [6:0] address_a [2:0], address_b [2:0];
logic signed [31:0] write_data_a [2:0];
logic signed [31:0] write_data_b [2:0];
logic write_enable_a [2:0];
logic write_enable_b [2:0];
logic signed [31:0] read_data_a [2:0];
logic signed [31:0] read_data_b [2:0];

dual_port_RAM0 RAM_inst0 (
	.address_a ( address_a[0] ),
	.address_b ( address_b[0] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[0] ),
	.data_b ( write_data_b[0] ),
	.wren_a ( write_enable_a[0] ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);

dual_port_RAM1 RAM_inst1 (
	.address_a ( address_a[1] ),
	.address_b ( address_b[1] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[1] ),
	.data_b ( write_data_b[1] ),
	.wren_a ( write_enable_a[1] ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);
	
dual_port_RAM2 RAM_inst2 (
	.address_a ( address_a[2] ),
	.address_b ( address_b[2] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[2] ),
	.data_b ( write_data_b[2] ),
	.wren_a ( write_enable_a[2] ),
	.wren_b ( write_enable_b[2] ),
	.q_a ( read_data_a[2] ),
	.q_b ( read_data_b[2] )
	);

// Multiplier signals
logic signed [31:0] M1_op_1, M1_op_2, M2_op_1, M2_op_2, M3_op_1, M3_op_2, M1_result, M2_result, M3_result;
logic signed [63:0] M1_result_long, M2_result_long, M3_result_long;

//Multiply 'N Accumulate
logic signed [31:0] Tmac;
logic signed [31:0] Smac_1,Smac_2,Smac_3, Smac_3_buf;

// Assign multiplier outputs
assign M1_result_long = M1_op_1 * M1_op_2;
assign M1_result = M1_result_long[31:0];

assign M2_result_long = M2_op_1 * M2_op_2;
assign M2_result = M2_result_long[31:0];

assign M3_result_long = M3_op_1 * M3_op_2;
assign M3_result = M3_result_long[31:0];

// Addressing / Indexing
assign rows = {data_count[7:5], data_count[1:0]};
assign cols = {data_count[4:2], data_count[1:0]};
assign rows_long = {3'b100 + data_count_long[2:0],data_count_long[5:3]};

assign row_address = {row_base, data_count_long[5:3]};
assign col_address = {col_base, data_count_long[2:0]};

assign row_address_w = {row_base_w, data_count_long[5:3]};
assign col_address_w = {col_base_w, data_count_long[1:0]};

// Top Level State Machine
always_ff @(posedge CLOCK_50_I or negedge resetn) begin
	if (!resetn) begin
		// Reset all signals
      top_state <= S_M2_INIT_0;
		l_fetch_state <= S_READ_0;
		fetch_state <= S_READ_0;
		l_t_state <= S_GET_T;
		t_state <= S_GET_T;
		s_state <= S_GET_S;
		e_s_state <= S_GET_S;
		write_state <= S_READ_0;
		e_write_state <= S_READ_0;
		S_done <= 1'b0;
		  
		SRAM_write_data <= 16'b0;
      SRAM_we_n <= 1'b1;
		SRAM_address <= 18'd0;
		  
		last_block_flag <= 1'b0;

		write_count <= 5'd0;
		write_count_1 <= 5'd0;
		data_count <= 7'd0;
		data_count_long <= 5'd0;
		Tmac <= 31'd0;
		Smac_1 <= 31'd0;
		Smac_2 <= 31'd0;
		Smac_3 <= 31'd0;
		Smac_3_buf <= 31'd0;
		col_base <= 6'd0;
		col_base_w <= 6'd0;
		row_base <= 5'd0;
		row_base_w <= 5'd0;
		S_buf[0] <= 8'd0;
		S_buf[1] <= 8'd0;
		
		address_a[0] <= 7'd0;
		address_b[0] <= 7'd0;
		write_data_a[0] <= 32'd0;
		write_data_b[0] <= 32'd0;
		write_enable_a[0] <= 1'b1;
		write_enable_b[0] <= 1'b1;
		
		address_a[1] <= 7'd0;
		address_b[1] <= 7'd0;
		write_data_a[1] <= 32'd0;
		write_data_b[1] <= 32'd0;
		write_enable_a[1] <= 1'b1;
		write_enable_b[1] <= 1'b1;
		
		address_a[2] <= 7'd0;
		address_b[2] <= 7'd0;
		write_data_a[2] <= 32'd0;
		write_data_b[2] <= 32'd0;
		write_enable_a[2] <= 1'b1;
		write_enable_b[2] <= 1'b1;
		
    end else begin
		case (top_state)

		// Lead In Fetch S'
		S_M2_INIT_0: begin
//			if (!resetn) begin
//				l_fetch_state <= S_READ_0;
//			end
            case(l_fetch_state)
            S_READ_0: begin
					if(S_enable == 1'b1) begin
						SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;
						data_count_long <= data_count_long + 6'b1;

						l_fetch_state <= S_IDLE_0;
					end
            end

            S_IDLE_0: begin
                SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;
                data_count_long <= data_count_long + 6'b1;

                l_fetch_state <= S_IDLE_1;
            end

            S_IDLE_1: begin
                SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;
                data_count_long <= data_count_long + 6'b1;

                l_fetch_state <= S_READ_STORE;
            end

            S_READ_STORE: begin
                // Store two address
					 if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					end

                // Read next value
                SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;

                if (data_count_long < 6'd63) begin                        
                    data_count_long <= data_count_long + 6'b1;
                end

                else begin
                    data_count_long <= 6'b0;

                    col_base <= col_base + 6'b1;

                    l_fetch_state <= S_IDLE_2;
                end
            end

            S_IDLE_2: begin
                if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					end

                l_fetch_state <= S_IDLE_3;
            end

            S_IDLE_3: begin
                if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					end

                l_fetch_state <= S_STORE_END;
            end

            S_STORE_END: begin
					if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
					end

					write_count <= 1'b0;
					
               l_t_state <= S_GET_T;
					top_state <= S_M2_INIT_1;
            end
            
            endcase
		end

        // Lead In Compute T
		S_M2_INIT_1: begin
            case(l_t_state)
            S_GET_T: begin
               write_enable_a[0] <= 1'b0;
					write_enable_b[0] <= 1'b0;
					write_enable_a[1] <= 1'b0;
					write_enable_b[1] <= 1'b0;
					 
					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols + 1'b1};
					data_count <= data_count + 1'b1;


               l_t_state <= S_IDLE_T0;
            end

            S_IDLE_T0: begin
					 
 					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols + 1'b1};
					data_count <= data_count + 2'd2;

					l_t_state <= S_IDLE_T1;
            end

            S_IDLE_T1: begin
				
					address_a[0] <= rows;
					
					address_a[1] <= {2'b01,cols};
					data_count <= data_count + 1'b1;
					
					M1_op_1 <= read_data_a[0][31:16];
					M1_op_2 <= read_data_a[1][31:16];
					M2_op_1 <= read_data_a[0][15:0];
					M2_op_2 <= read_data_a[1][15:0];
					M3_op_1 <= read_data_b[0][31:16];
					M3_op_2 <= read_data_b[1][31:16];
				
               l_t_state <= S_CALC_T0;
            end

				S_CALC_T0: begin
			
					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols + 1'b1};
					data_count <= data_count + 2'd2;
			
					Tmac <= M1_result + M2_result + M3_result;
			
					M1_op_1 <= read_data_a[0][15:0];
					M1_op_2 <= read_data_a[1][15:0];
					M2_op_1 <= read_data_a[0][31:16];
					M2_op_2 <= read_data_a[1][31:16];
					M3_op_1 <= read_data_b[0][15:0];
					M3_op_2 <= read_data_b[1][15:0];

               l_t_state <= S_CALC_T1;
				end
			
				S_CALC_T1: begin
				
					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols + 1'b1};
					data_count <= data_count + 1'b1;
					// Compute partial sum for T
               Tmac <= Tmac + M1_result + M2_result + M3_result;

               // Update multipliers for next set of computations
               M1_op_1 <= read_data_a[0][31:16];
               M1_op_2 <= read_data_a[1][31:16];
					 
               M2_op_1 <= read_data_a[0][15:0];
               M2_op_2 <= read_data_a[1][15:0];


               l_t_state <= S_CALC_T2;
				end
			
				S_CALC_T2: begin
					address_a[0] <= rows;
					address_a[1] <= {2'b01,cols};

					write_enable_b[0] <= 1'b1;
					address_b[0] <= {1'b1, write_count};
					write_data_b[0] <= Tmac + M1_result + M2_result;
					write_count <= write_count + 1'b1;

               M1_op_1 <= read_data_a[0][31:16];
					M1_op_2 <= read_data_a[1][31:16];
					M2_op_1 <= read_data_a[0][15:0];
					M2_op_2 <= read_data_a[1][15:0];
					M3_op_1 <= read_data_b[0][31:16];
					M3_op_2 <= read_data_b[1][31:16];
					
					if((write_count) < 6'd62) begin
						l_t_state <= S_CALC_T0;
					end
					else begin
						data_count <= 6'd0;
						l_t_state <= S_GET_T;
						top_state <= S_M2_COMMON_0;
					end
				end
            endcase
        end
			  
		S_M2_COMMON_0: begin
            // Common Fetch S'
            case(fetch_state)
				S_READ_0: begin
					write_enable_b[0] <= 1'b0;
					write_enable_b[2] <= 1'b0;
					write_count <= 1'b0;
			
               SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;
               data_count_long <= data_count_long + 6'b1;

					fetch_state <= S_IDLE_0;
            end

            S_IDLE_0: begin
                SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;
                data_count_long <= data_count_long + 6'b1;

                fetch_state <= S_IDLE_1;
            end

            S_IDLE_1: begin
                SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;
                data_count_long <= data_count_long + 6'b1;

                fetch_state <= S_READ_STORE;
            end

            S_READ_STORE: begin
                // Store two address
					 if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					end

                // Read next value
                SRAM_address <= {row_address, 8'b0} + {row_address, 6'b0} + col_address + S_PRIME_BASE_ADDRESS;

                if (data_count_long < 6'd63) begin                        
                    data_count_long <= data_count_long + 6'b1;
                end
                else begin
                  data_count_long <= 6'b0;
							if(col_base < 6'd39) begin
								col_base <= col_base + 6'b1;
							end
							else if (row_base < 5'd29) begin
								col_base <= 1'b0;
								row_base <= row_base + 1'b1;
							end 
							else begin
								last_block_flag <= 1'b1;
							end
                  fetch_state <= S_IDLE_2;
                end
            end

            S_IDLE_2: begin
                if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					end

                fetch_state <= S_IDLE_3;
            end

            S_IDLE_3: begin
                if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
						write_count <= write_count + 1'b1;
					end

                fetch_state <= S_STORE_END;
            end

            S_STORE_END: begin
					if (write_count[0] == 1'b0) begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][31:16] <= SRAM_read_data;
					 end
					 else begin
						address_a[0] <= write_count[5:1];
						write_enable_a[0] <= 1'b1;
						write_data_a[0][15:0] <= SRAM_read_data;
					end
					
					write_count <= 6'd0;
					data_count_long <= 6'd0;
            end
            
            endcase

            // Common Compute S
            case (s_state)
				
				S_GET_S: begin
               write_enable_a[0] <= 1'b0;
					write_enable_b[0] <= 1'b0;
					write_enable_a[1] <= 1'b0;
					write_enable_b[1] <= 1'b0;
					 
					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					data_count <= data_count + 3'b100;
					data_count_long <= data_count_long + 1'b1;


               s_state <= S_IDLE_S0;
            end

            S_IDLE_S0: begin
					 
					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					data_count <= data_count + 3'b100;
					data_count_long <= data_count_long + 1'b1;
					
					M1_op_1 <= 0;
					M1_op_2 <= 0;
					M2_op_1 <= 0;
					M2_op_2 <= 0;
					M3_op_1 <= 0;
					M3_op_2 <= 0;

					s_state <= S_CALC_S0;
            end

            S_CALC_S0: begin
				
					if(data_count_long[2:0] == 4'b1000) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_1[31:16];
						write_enable_b[2] <= 1'b1;
						address_b[2] <= write_count_1 + 1'b1;
						write_data_b[2] <= Smac_2[31:16];
						Smac_3_buf <= Smac_3;
						write_count_1 <= write_count_1 + 2'd2;
					end
					else if(data_count_long[2:0] == 4'b1001) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_3_buf[31:16];
						write_count_1 <= write_count_1 + 1'b1;
					end
				
					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					if(data_count_long[2:0] == 3'b111) begin
						data_count <= data_count + 3'b101;
						data_count_long <= data_count_long + 1'b1;
					end
					else begin
						data_count <= data_count + 3'b100;
						data_count_long <= data_count_long + 1'b1;
					end
					
					Smac_1 <= Smac_1 + M1_result;
					Smac_2 <= Smac_2 + M2_result;
					Smac_3 <= Smac_3 + M3_result;
					
					M1_op_1 <= read_data_b[0][31:8];
					M1_op_2 <= read_data_a[1][31:16];
					M2_op_1 <= read_data_b[0][31:8];
					M2_op_2 <= read_data_a[1][15:0];
					M3_op_1 <= read_data_b[0][31:8];
					M3_op_2 <= read_data_b[1][31:16];
					
					if(data_count_long[3:0] == 4'b0111) begin
						s_state <= S_CALC_S1;
					end
					else begin
						s_state <= S_CALC_S0;
					end
            end

				S_CALC_S1: begin
				
					if(data_count_long[2:0] == 3'b000) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_1[31:16];
						write_enable_b[2] <= 1'b1;
						address_b[2] <= write_count_1 + 1'b1;
						write_data_b[2] <= Smac_2[31:16];
						Smac_3_buf <= Smac_3;
						write_count_1 <= write_count_1 + 2'd2;
					end
					else if(data_count_long[2:0] == 3'b001) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_3_buf[31:16];
						write_count_1 <= write_count_1 + 1'b1;
					end

					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					if(data_count_long[2:0] == 3'b111) begin
						data_count <= data_count + 3'b110;
						data_count_long <= data_count_long + 1'b1;
					end
					else begin
						data_count <= data_count + 3'b100;
						data_count_long <= data_count_long + 1'b1;
					end
			
					Smac_1 <= Smac_1 + M1_result;
					Smac_2 <= Smac_2 + M2_result;
					Smac_3 <= Smac_3 + M3_result;
					
					M1_op_1 <= read_data_b[0][31:8];
					M1_op_2 <= read_data_a[1][15:0];
					M2_op_1 <= read_data_b[0][31:8];
					M2_op_2 <= read_data_a[1][31:16];
					M3_op_1 <= read_data_b[0][31:8];
					M3_op_2 <= read_data_b[1][15:0];

               if(data_count_long[3:0] == 4'b1111) begin
						s_state <= S_CALC_S2;
					end
					else begin
						s_state <= S_CALC_S1;
					end
				end
				
				S_CALC_S2: begin
				
					if(data_count_long[2:0] == 3'b000) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_1[31:16];
						write_enable_b[2] <= 1'b1;
						address_b[2] <= write_count_1 + 1'b1;
						write_data_b[2] <= Smac_2[31:16];
						Smac_3_buf <= Smac_3;
						write_count_1 <= write_count_1 + 2'd2;
					end
					else if(data_count_long[2:0] == 3'b001) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_3_buf[31:16];
						write_count_1 <= write_count_1 + 1'b1;
					end

					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					if(data_count_long[2:0] == 3'b111) begin
						data_count <= data_count + 3'b101;
						data_count_long <= data_count_long + 1'b1;
					end
					else begin
						data_count <= data_count + 3'b100;
						data_count_long <= data_count_long + 1'b1;
					end
			
					Smac_1 <= Smac_1 + M1_result;
					Smac_2 <= Smac_2 + M2_result;
					Smac_3 <= Smac_3 + M3_result;
					
					M1_op_1 <= read_data_b[0][31:8];
					M1_op_2 <= read_data_a[1][15:0];
					M2_op_1 <= read_data_b[0][31:8];
					M2_op_2 <= read_data_a[1][31:16];

               if(data_count_long[4:0] == 5'b10111) begin
						s_state <= S_CALC_S0;
					end
					else if(write_count_1 == 6'd63) begin
						s_state <= S_S_LEAD_OUT_0;
					end
					else begin
						s_state <= S_CALC_S2;
					end
				end
				
				S_S_LEAD_OUT_0: begin
				
					write_enable_a[2] <= 1'b1;
					address_a[2] <= write_count_1;
					write_data_a[2] <= Smac_1[31:16];
					write_enable_b[2] <= 1'b1;
					address_b[2] <= write_count_1 + 1'b1;
					write_data_b[2] <= Smac_2[31:16];
					write_count_1 <= write_count_1 + 2'd2;

					s_state <= S_S_LEAD_OUT_1;
				end
				
				S_S_LEAD_OUT_1: begin
				
					write_enable_a[2] <= 1'b1;
					address_a[2] <= write_count_1;
					write_data_a[2] <= Smac_3;
					write_count_1 <= write_count_1 + 1'b1;
				
				end            
            endcase

            if (fetch_state == S_STORE_END && s_state == S_S_LEAD_OUT_1) begin
					fetch_state <= S_READ_0;
					s_state <= S_GET_S;
               top_state <= S_M2_COMMON_1;
            end
		end
			  
		S_M2_COMMON_1: begin
            case (t_state)
				 S_GET_T: begin
               write_enable_a[0] <= 1'b0;
					write_enable_b[0] <= 1'b0;
					write_enable_a[1] <= 1'b0;
					write_enable_b[1] <= 1'b0;
					 
					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols} + 1'b1;
					data_count <= data_count + 1'b1;


               t_state <= S_IDLE_T0;
            end

            S_IDLE_T0: begin
					 
 					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols} + 1'b1;
					data_count <= data_count + 2'd2;

					t_state <= S_IDLE_T1;
            end

            S_IDLE_T1: begin
				
					address_a[0] <= rows;
					
					address_a[1] <= {2'b01,cols};
					data_count <= data_count + 1'b1;
					
					M1_op_1 <= read_data_a[0][31:16];
					M1_op_2 <= read_data_a[1][31:16];
					M2_op_1 <= read_data_a[0][15:0];
					M2_op_2 <= read_data_a[1][15:0];
					M3_op_1 <= read_data_b[0][31:16];
					M3_op_2 <= read_data_b[1][31:16];
				
               t_state <= S_CALC_T0;
            end

				S_CALC_T0: begin
			
					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols} + 1'b1;
					data_count <= data_count + 2'd2;
			
					Tmac <= M1_result + M2_result + M3_result;
			
					M1_op_1 <= read_data_a[0][15:0];
					M1_op_2 <= read_data_a[1][15:0];
					M2_op_1 <= read_data_a[0][31:16];
					M2_op_2 <= read_data_a[1][31:16];
					M3_op_1 <= read_data_b[0][15:0];
					M3_op_2 <= read_data_b[1][15:0];

               t_state <= S_CALC_T1;
				end
			
				S_CALC_T1: begin
				
					address_a[0] <= rows;
					address_b[0] <= rows + 1'b1;
					
					address_a[1] <= {2'b01,cols};
					address_b[1] <= {2'b01,cols} + 1'b1;
					data_count <= data_count + 1'b1;
					// Compute partial sum for T
               Tmac <= Tmac + M1_result + M2_result + M3_result;

               // Update multipliers for next set of computations
               M1_op_1 <= read_data_a[0][31:16];
               M1_op_2 <= read_data_a[1][31:16];
					 
               M2_op_1 <= read_data_a[0][15:0];
               M2_op_2 <= read_data_a[1][15:0];


               t_state <= S_CALC_T2;
				end
			
				S_CALC_T2: begin
					address_a[0] <= rows;
					address_a[1] <= {2'b01,cols};

					write_enable_b[0] <= 1'b1;
					address_b[0] <= {1'b1, write_count};
					write_data_b[0] <= Tmac + M1_result + M2_result;
					write_count <= write_count + 1'b1;

               M1_op_1 <= read_data_a[0][31:16];
					M1_op_2 <= read_data_a[1][31:16];
					M2_op_1 <= read_data_a[0][15:0];
					M2_op_2 <= read_data_a[1][15:0];
					M3_op_1 <= read_data_b[0][31:16];
					M3_op_2 <= read_data_b[1][31:16];
					
					if((write_count) < 6'd62) begin
						t_state <= S_CALC_T0;
					end
					else begin
						data_count <= 6'd0;
						t_state <= S_END_T;
					end
				end
				
				S_END_T: begin
				end
            endcase

            case (write_state)
				
				S_READ_0: begin
				
					write_enable_a[2] <= 1'b0;
					write_enable_b[2] <= 1'b0;
					 
					address_a[2] <= {data_count_long, 1'b0};
					address_b[2] <= {data_count_long, 1'b1};

					 
               write_state <= S_IDLE_0;
            end

            S_IDLE_0: begin
               write_state <= S_IDLE_1;
            end

            S_IDLE_1: begin	
					address_a[2] <= {data_count_long + 1'b1, 1'b0};
					address_b[2] <= {data_count_long + 1'b1, 1'b1};
					
					if(read_data_a[2] > 8'd255)
						S_buf[0] <= 8'd255;
					else if(read_data_a[2] < 8'd0)
						S_buf[0] <= 8'd0;
					else
						S_buf[0] <= read_data_a[2][7:0];
						
					if(read_data_b[2] > 8'd255)
						S_buf[1] <= 8'd255;
					else if(read_data_b[2] < 8'd0)
						S_buf[1] <= 8'd0;
					else
						S_buf[1] <= read_data_b[2][7:0];

               write_state <= S_READ_STORE;
            end

            S_READ_STORE: begin
				
					SRAM_address <= {row_address_w, 8'b0} + {row_address_w, 6'b0} + col_address_w;
					SRAM_we_n <= 1'b0;					
					
					SRAM_write_data <= {S_buf[0], S_buf[1]};


               if (data_count_long < 6'd31) begin                        
                  data_count_long <= data_count_long + 6'b1;
						write_state <= S_IDLE_1;
               end
               else begin
                  data_count <= 6'b0;
							if(col_base_w < 6'd39) begin
								col_base_w <= col_base_w + 6'b1;
							end
							else if (row_base_w < 5'd29) begin
								col_base_w <= 1'b0;
								row_base_w <= row_base_w + 1'b1;
							end
                  write_state <= S_IDLE_2;
                end
           end

           S_IDLE_2: begin
           end
			  
           endcase
			
            if (t_state == S_END_T && write_state == S_IDLE_2 ) begin
                t_state <= S_GET_T;
					 write_state <= S_READ_0;
					 top_state <= S_M2_COMMON_0;
            end
				if (last_block_flag == 1'b1) begin
					top_state <= S_M2_END_0;
				end
		end
			
		S_M2_END_0: begin
			case (e_s_state)
				S_GET_S: begin
               write_enable_a[0] <= 1'b0;
					write_enable_b[0] <= 1'b0;
					write_enable_a[1] <= 1'b0;
					write_enable_b[1] <= 1'b0;
					 
					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					data_count <= data_count + 3'b100;
					data_count_long <= data_count_long + 1'b1;


               e_s_state <= S_IDLE_S0;
            end

            S_IDLE_S0: begin
					 
					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					data_count <= data_count + 3'b100;
					data_count_long <= data_count_long + 1'b1;
					
					M1_op_1 <= 0;
					M1_op_2 <= 0;
					M2_op_1 <= 0;
					M2_op_2 <= 0;
					M3_op_1 <= 0;
					M3_op_2 <= 0;

					e_s_state <= S_CALC_S0;
            end

            S_CALC_S0: begin
				
					if(data_count_long[2:0] == 4'b1000) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_1[31:16];
						write_enable_b[2] <= 1'b1;
						address_b[2] <= write_count_1 + 1'b1;
						write_data_b[2] <= Smac_2[31:16];
						Smac_3_buf <= Smac_3;
						write_count_1 <= write_count_1 + 2'd2;
					end
					else if(data_count_long[2:0] == 4'b1001) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_3_buf[31:16];
						write_count_1 <= write_count_1 + 1'b1;
					end
				
					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					if(data_count_long[2:0] == 3'b111) begin
						data_count <= data_count + 3'b101;
						data_count_long <= data_count_long + 1'b1;
					end
					else begin
						data_count <= data_count + 3'b100;
						data_count_long <= data_count_long + 1'b1;
					end
					
					Smac_1 <= Smac_1 + M1_result;
					Smac_2 <= Smac_2 + M2_result;
					Smac_3 <= Smac_3 + M3_result;
					
					M1_op_1 <= read_data_b[0][31:8];
					M1_op_2 <= read_data_a[1][31:16];
					M2_op_1 <= read_data_b[0][31:8];
					M2_op_2 <= read_data_a[1][15:0];
					M3_op_1 <= read_data_b[0][31:8];
					M3_op_2 <= read_data_b[1][31:16];
					
					if(data_count_long[3:0] == 4'b0111) begin
						e_s_state <= S_CALC_S1;
					end
					else begin
						e_s_state <= S_CALC_S0;
					end
            end

				S_CALC_S1: begin
				
					if(data_count_long[2:0] == 3'b000) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_1[31:16];
						write_enable_b[2] <= 1'b1;
						address_b[2] <= write_count_1 + 1'b1;
						write_data_b[2] <= Smac_2[31:16];
						Smac_3_buf <= Smac_3;
						write_count_1 <= write_count_1 + 2'd2;
					end
					else if(data_count_long[2:0] == 3'b001) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_3_buf[31:16];
						write_count_1 <= write_count_1 + 1'b1;
					end

					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					if(data_count_long[2:0] == 3'b111) begin
						data_count <= data_count + 3'b110;
						data_count_long <= data_count_long + 1'b1;
					end
					else begin
						data_count <= data_count + 3'b100;
						data_count_long <= data_count_long + 1'b1;
					end
			
					Smac_1 <= Smac_1 + M1_result;
					Smac_2 <= Smac_2 + M2_result;
					Smac_3 <= Smac_3 + M3_result;
					
					M1_op_1 <= read_data_b[0][31:8];
					M1_op_2 <= read_data_a[1][15:0];
					M2_op_1 <= read_data_b[0][31:8];
					M2_op_2 <= read_data_a[1][31:16];
					M3_op_1 <= read_data_b[0][31:8];
					M3_op_2 <= read_data_b[1][15:0];

               if(data_count_long[3:0] == 4'b1111) begin
						e_s_state <= S_CALC_S2;
					end
					else begin
						e_s_state <= S_CALC_S1;
					end
				end
				
				S_CALC_S2: begin
				
					if(data_count_long[2:0] == 3'b000) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_1[31:16];
						write_enable_b[2] <= 1'b1;
						address_b[2] <= write_count_1 + 1'b1;
						write_data_b[2] <= Smac_2[31:16];
						Smac_3_buf <= Smac_3;
						write_count_1 <= write_count_1 + 2'd2;
					end
					else if(data_count_long[2:0] == 3'b001) begin
						write_enable_a[2] <= 1'b1;
						address_a[2] <= write_count_1;
						write_data_a[2] <= Smac_3_buf[31:16];
						write_count_1 <= write_count_1 + 1'b1;
					end

					address_b[0] <= rows_long;
					
					address_a[1] <= cols;
					address_b[1] <= cols + 1'b1;
					
					if(data_count_long[2:0] == 3'b111) begin
						data_count <= data_count + 3'b101;
						data_count_long <= data_count_long + 1'b1;
					end
					else begin
						data_count <= data_count + 3'b100;
						data_count_long <= data_count_long + 1'b1;
					end
			
					Smac_1 <= Smac_1 + M1_result;
					Smac_2 <= Smac_2 + M2_result;
					Smac_3 <= Smac_3 + M3_result;
					
					M1_op_1 <= read_data_b[0][31:8];
					M1_op_2 <= read_data_a[1][15:0];
					M2_op_1 <= read_data_b[0][31:8];
					M2_op_2 <= read_data_a[1][31:16];

               if(data_count_long[4:0] == 5'b10111) begin
						e_s_state <= S_CALC_S0;
					end
					else if(write_count_1 == 6'd63) begin
						e_s_state <= S_S_LEAD_OUT_0;
					end
					else begin
						e_s_state <= S_CALC_S2;
					end
				end
				
				S_S_LEAD_OUT_0: begin
				
					write_enable_a[2] <= 1'b1;
					address_a[2] <= write_count_1;
					write_data_a[2] <= Smac_1[31:16];
					write_enable_b[2] <= 1'b1;
					address_b[2] <= write_count_1 + 1'b1;
					write_data_b[2] <= Smac_2[31:16];
					write_count_1 <= write_count_1 + 2'd2;

					e_s_state <= S_S_LEAD_OUT_1;
				end
				
				S_S_LEAD_OUT_1: begin
				
					write_enable_a[2] <= 1'b1;
					address_a[2] <= write_count_1;
					write_data_a[2] <= Smac_3;
					write_count_1 <= write_count_1 + 1'b1;
				
				end       
         endcase
			
            if (e_s_state == S_S_LEAD_OUT_1) begin
			    top_state <= S_M2_END_1;
            end
		end

      S_M2_END_1: begin
			case (e_write_state)
				S_READ_0: begin
				
					write_enable_a[2] <= 1'b0;
					write_enable_b[2] <= 1'b0;
					 
					address_a[2] <= {data_count_long, 1'b0};
					address_b[2] <= {data_count_long, 1'b1};

					 
               e_write_state <= S_IDLE_0;
            end

            S_IDLE_0: begin
               e_write_state <= S_IDLE_1;
            end

            S_IDLE_1: begin	
					address_a[2] <= {data_count_long + 1'b1, 1'b0};
					address_b[2] <= {data_count_long + 1'b1, 1'b1};
					
					if(read_data_a[2] > 8'd255)
						S_buf[0] <= 8'd255;
					else if(read_data_a[2] < 8'd0)
						S_buf[0] <= 8'd0;
					else
						S_buf[0] <= read_data_a[2][7:0];
						
					if(read_data_b[2] > 8'd255)
						S_buf[1] <= 8'd255;
					else if(read_data_b[2] < 8'd0)
						S_buf[1] <= 8'd0;
					else
						S_buf[1] <= read_data_b[2][7:0];

               e_write_state <= S_READ_STORE;
            end

            S_READ_STORE: begin
				
					SRAM_address <= {row_address_w, 8'b0} + {row_address_w, 6'b0} + col_address_w;
					SRAM_we_n <= 1'b1;					
					
					SRAM_write_data <= {S_buf[0], S_buf[1]};


               if (data_count_long < 6'd31) begin                        
                  data_count_long <= data_count_long + 6'b1;
						e_write_state <= S_IDLE_1;
               end

               else begin
                  e_write_state <= S_IDLE_2;
               end
				end
				S_IDLE_2: begin
					S_done <= 1'b1;
				end
            endcase
			end
	   endcase
	end
end


endmodule
