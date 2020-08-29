module QLM_w4q0(
    input [7:0] x,
    input [7:0] y,
    output [15:0] p
    );
    // X branch 
    
    // First complement 
    wire [7:0] x_abs;
    assign x_abs = x ^ {8{x[7]}};

    // LOD + Priority Encoder
    wire [7:0] k_x0;
    wire zero_x0;
    wire [2:0] k_x0_enc;

    LOD8 lod_x0(
        .data_i(x_abs),
        .zero_o(zero_x0),
        .data_o(k_x0),
        .data_enc(k_x0_enc));

    // LBarrel 
    wire [2:0] x_shift;

    LBarrel Lshift_x0(
        .data_i(x_abs),
        .shift_i(k_x0),
        .data_o(x_shift));

    // Y branch 
    
    // First complement 
    wire [7:0] y_abs;
    assign y_abs = y ^ {8{y[7]}};
    
    // LOD + Priority Encoder
    wire [7:0] k_y0;
    wire zero_y0;
    wire [2:0] k_y0_enc;
    
    LOD8 lod_y0(
        .data_i(y_abs),
        .zero_o(zero_y0),
        .data_o(k_y0),
        .data_enc(k_y0_enc));
      
    // LBarrel 
    wire [2:0] y_shift;
    
    LBarrel Lshift_y0(
        .data_i(y_abs),
        .shift_i(k_y0),
        .data_o(y_shift));

    // Addition 
    wire [6:0] x_log;
    wire [6:0] y_log;
    wire [6:0] p_log;
    
    assign x_log = {1'b0,k_x0_enc,x_shift};
    assign y_log = {1'b0,k_y0_enc,y_shift};
   
    assign p_log = x_log + y_log;


    // Antilogarithm stage
    wire [11:0] p_l1b;
    wire [3:0] l1_input;
    
    assign l1_input = {1'b1,p_log[2:0]};

    L1Barrel L1shift_plog(
        .data_i(l1_input),
        .shift_i(p_log[5:3]),
        .data_o(p_l1b));
    
    // Low part of product 
    wire [4:0] p_low;
    wire not_k_l5 = ~p_log[6];
    
    assign p_low = p_l1b[7:3] & {4{not_k_l5}};

    // Medium part of product 
    wire [3:0] p_med;

    assign p_med = p_log[6] ? p_l1b[3:0] : p_l1b[10:8];

    // High part of product 
    wire [6:0] p_high;
    assign p_high = p_l1b[10:4] & {7{p_log[6]}};

    // Final product
    
    wire [15:0] PP_abs;
    assign PP_abs = {p_high,p_med,p_low};

    // Sign conversion 
    wire p_sign;
    wire [15:0] PP_temp;
 
    assign p_sign = x[7] ^ y[7];
    assign PP_temp = PP_abs ^ {16{p_sign}};

    //Zero mux0
    wire notZeroA, notZeroB, notZeroD;
    assign notZeroA = ~zero_x0 ;
    assign notZeroB = ~zero_y0 ;
    assign notZeroD = notZeroA & notZeroB;
    
    assign p = notZeroD? PP_temp : 16'b0;

endmodule

module LOD8(
    input [7:0] data_i,
    output zero_o,
    output [7:0] data_o,
    output [2:0] data_enc
    );
	
    wire [7:0] z;
    wire [1:0] zdet;
    wire [1:0] select;
    //*****************************************
    // Zero detection logic:
    //*****************************************
    assign zdet[1] = |(data_i[7:4]) ;
    assign zdet[0] = |(data_i[3:0]);
    assign zero_o = ~( zdet[1] | zdet[0]);
    //*****************************************
    // LODs:
    //*****************************************
    LOD4 lod2_1 (
        .data_i(data_i[7:4]), 
        .data_o(z[7:4])
        );
    LOD4 lod2_0 (
        .data_i(data_i[3:0]), 
        .data_o(z[3:0])
        );
    //*****************************************
    // Select signals
    //*****************************************    
    LOD2 Middle(
        .data_i(zdet), 
        .data_o(select)       
    );

	 //*****************************************
	 // Multiplexers :
	 //*****************************************
	wire [7:0] tmp_out;
	

	Muxes2in1Array4 Inst_MUX214_1 (
        .data_i(z[7:4]), 
        .select_i(select[1]), 
        .data_o(tmp_out[7:4])
    );

    Muxes2in1Array4 Inst_MUX214_0 (
        .data_i(z[3:0]), 
        .select_i(select[0]), 
        .data_o(tmp_out[3:0])
    );

    // Enconding
    wire [2:0] low_enc; 
    assign low_enc = tmp_out[3:1] | tmp_out[7:5] ;


    assign data_enc[2] = select[1];
    assign data_enc[1] = low_enc[2] | low_enc[1];
    assign data_enc[0] = low_enc[2] | low_enc[0];


    // One hot
    assign data_o = tmp_out;

    
endmodule

module LOD4(
    input [3:0] data_i,
    output [3:0] data_o
    );
	 
    
    wire mux0;
    wire mux1;
    wire mux2;
    
    // multiplexers:
    assign mux2 = (data_i[3]==1) ? 1'b0 : 1'b1;
    assign mux1 = (data_i[2]==1) ? 1'b0 : mux2;
    assign mux0 = (data_i[1]==1) ? 1'b0 : mux1;
    
    //gates and IO assignments:
    assign data_o[3] = data_i[3];
    assign data_o[2] =(mux2 & data_i[2]);
    assign data_o[1] =(mux1 & data_i[1]);
    assign data_o[0] =(mux0 & data_i[0]);

endmodule

module LOD2(
    input [1:0] data_i,
    output [1:0] data_o
    );
	 
    assign data_o[1] = data_i[1];
    assign data_o[0] = ~data_i[1] & data_i[0];

endmodule

module Muxes2in1Array4(
    input [3:0] data_i,
    input select_i,
    output [3:0] data_o
    );

	assign data_o[3] = select_i ? data_i[3] : 1'b0;
	assign data_o[2] = select_i ? data_i[2] : 1'b0;
	assign data_o[1] = select_i ? data_i[1] : 1'b0;
	assign data_o[0] = select_i ? data_i[0] : 1'b0;
	
endmodule

module LBarrel(
    input  [7:0] data_i,
    input  [7:0] shift_i,
    output [2:0] data_o);
    
    assign data_o[2] = |(data_i[5:0] & shift_i[6:1]);

    assign data_o[1] = |(data_i[4:0] & shift_i[6:2]);
    
    assign data_o[0] = |(data_i[3:0] & shift_i[6:3]);

endmodule

module L1Barrel(
    input [3:0] data_i,
    input [2:0] shift_i,
    output reg [11:0] data_o);
    always @*
        case (shift_i)
           4'b0000: data_o = data_i;
           4'b0001: data_o = data_i << 1;
           4'b0010: data_o = data_i << 2;
           4'b0011: data_o = data_i << 3;
           4'b0100: data_o = data_i << 4;
           4'b0101: data_o = data_i << 5;
           4'b0110: data_o = data_i << 6;
           default: data_o = data_i << 7;
        endcase
endmodule