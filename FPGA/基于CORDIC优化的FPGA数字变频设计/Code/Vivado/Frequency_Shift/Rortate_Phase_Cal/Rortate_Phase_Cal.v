`timescale 1ns/1ps
`default_nettype none

module Rortate_Phase_Cal (
    input  wire                         Clk                        ,
    input  wire                         Rst                        ,

    input  wire                         IQ_tvalid_Reg              ,
    input  wire          [  31: 0]      Sample_Rate_Reg            ,
    input  wire          [  31: 0]      F_Shift_Reg                ,

    output reg                          Rotate_Phase_Val           ,
    output reg           [  31: 0]      Rotate_Phase               
);


wire               [  63: 0]        Div_Result                  ;
wire                                Div_Result_Val              ;

Freqency_Shift_Div u_Freqency_Shift_Div (
    .aclk                               (Clk                       ),// input wire aclk
    .s_axis_divisor_tvalid              (IQ_tvalid_Reg             ),// input wire s_axis_divisor_tvalid
    .s_axis_divisor_tdata               (Sample_Rate_Reg           ),// input wire [31 : 0] s_axis_divisor_tdata
    .s_axis_dividend_tvalid             (IQ_tvalid_Reg             ),// input wire s_axis_dividend_tvalid
    .s_axis_dividend_tdata              (F_Shift_Reg               ),// input wire [31 : 0] s_axis_dividend_tdata
    .m_axis_dout_tvalid                 (Div_Result_Val            ),// output wire m_axis_dout_tvalid
    .m_axis_dout_tdata                  (Div_Result                ) // output wire [63 : 0] m_axis_dout_tdata
);


localparam             signed       PI_MUL_2_Q16                    = 20'b0110_0100_1000_0111_1111;     //2Pi的二进制补码，小数位16位

reg                                 Rortate_w_Val               ;
reg     signed       [  50: 0]      Rortate_w                   ;// Fractional Width 47
reg                                 Rortate_w_Val_Reg           ;
reg     signed       [  50: 0]      Rortate_w_Reg               ;// Fractional Width 47

always @(posedge Clk) begin
    if (Rst) begin
        Rortate_w_Val <= 'b0;
    end
    else begin
        Rortate_w_Val <= Div_Result_Val;
    end
end

always @(posedge Clk) begin
    if (Div_Result_Val) begin
        Rortate_w <= PI_MUL_2_Q16*$signed(Div_Result[31:0]);
    end
    else begin
        Rortate_w <= 'd0;
    end
end

always @(posedge Clk) begin
    Rortate_w_Val_Reg <= Rortate_w_Val;
end

always @(posedge Clk) begin
    Rortate_w_Reg <= Rortate_w;
end


localparam           signed         PI_A                        = 51'h1_921f_b544_42d2;   //Pi的二进制补码 Fractional Width 47
localparam           signed         PI_B                        = -(51'h1_921f_b544_42d2);	//－Pi的二进制补码 Fractional Width 47
localparam           signed         PI_MUL_2_Q47                = 51'h3_243F_6A88_85A3;   //2Pi的二进制补码，Fractional Width 47

reg                                 Rotate_Accumulate_Val       ;
reg     signed     [  51: 0]        Rotate_Accumulate         ='d0 ;//Fractional Width 47

always @(posedge Clk) begin
    if (Rst) begin
        Rotate_Accumulate_Val <= 'b0;
    end
    else begin
        Rotate_Accumulate_Val <= Rortate_w_Val_Reg;
    end
end

always @(posedge Clk) begin
    if (Rortate_w_Val_Reg) begin
        if ((Rotate_Accumulate + Rortate_w_Reg) > PI_A) begin
            Rotate_Accumulate <= Rotate_Accumulate + Rortate_w_Reg - PI_MUL_2_Q47;
        end
        else if ((Rotate_Accumulate + Rortate_w_Reg) < PI_B) begin
            Rotate_Accumulate <= Rotate_Accumulate + Rortate_w_Reg + PI_MUL_2_Q47;
        end
        else begin
            Rotate_Accumulate <= Rotate_Accumulate + Rortate_w_Reg;
        end
    end
end

always @(posedge Clk) begin
    Rotate_Phase_Val <= Rotate_Accumulate_Val;
end

always @(posedge Clk) begin
    Rotate_Phase <= Rotate_Accumulate[49:18];
end


endmodule

`default_nettype wire