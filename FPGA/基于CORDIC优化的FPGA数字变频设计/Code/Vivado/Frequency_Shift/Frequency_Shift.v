`timescale 1ns/1ps
`default_nettype none

module Frequency_Shift #(
    parameter                           IQ_WIDTH                    = 'd16                 
) (
    input  wire                             Clk                        ,
    input  wire                             Rst                        ,

    input  wire                             IQ_tvalid                  ,    // 输入IQ有效
    input  wire          [2*IQ_WIDTH-1: 0]  IQ_tdata                   ,    // 输入IQ信号，低16位为I，高16位为Q
    input  wire          [  31: 0]          F_Shift                    ,    // 变频频率，单位Hz
    input  wire          [  31: 0]          Sample_Rate                ,    // IQ信号采样率，单位Hz

    output reg                              F_Shift_IQ_tvalid          ,    // 混频后信号有效
    output reg           [2*IQ_WIDTH-1: 0]  F_Shift_IQ_tdata                // 混频后IQ信号，低16位为I，高16位为Q
);


reg                                     IQ_tvalid_Reg               ;
reg                  [2*IQ_WIDTH-1: 0]  IQ_tdata_Reg                ;
reg                  [  31: 0]          F_Shift_Reg                 ;
reg                  [  31: 0]          Sample_Rate_Reg             ;

always @(posedge Clk) begin
    if (Rst) begin
        IQ_tvalid_Reg <= 'b0;
    end
    else begin
        IQ_tvalid_Reg <= IQ_tvalid;
    end
end

always @(posedge Clk) begin
    if (IQ_tvalid) begin
        IQ_tdata_Reg <= IQ_tdata;
        F_Shift_Reg <= F_Shift;
        Sample_Rate_Reg <= Sample_Rate;
    end
    else begin
        IQ_tdata_Reg <= 'd0;
        F_Shift_Reg <= 'd0;
        Sample_Rate_Reg <= 'd0;
    end
end


wire                                Rotate_Phase_Val            ;
wire                 [  31: 0]      Rotate_Phase                ;

// Latency = 44
Rortate_Phase_Cal u_Rortate_Phase_Cal (
    .Clk                                (Clk                       ),
    .Rst                                (Rst                       ),
    .IQ_tvalid_Reg                      (IQ_tvalid_Reg             ),
    .Sample_Rate_Reg                    (Sample_Rate_Reg           ),
    .F_Shift_Reg                        (F_Shift_Reg               ),
    .Rotate_Phase_Val                   (Rotate_Phase_Val          ),
    .Rotate_Phase                       (Rotate_Phase              ) 
);


wire                 [2*IQ_WIDTH-1: 0]IQ_tdata_Delay              ;

shiftreg #( 
    .WIDTH                              (2*IQ_WIDTH                ),
    .LENGTH                             (43                        ) 
) IQ_tdata_shiftreg (
    .CLK                                (Clk                       ),
    .D                                  (IQ_tdata_Reg              ),
    .Q                                  (IQ_tdata_Delay            ),
    .CE                                 ('b1                       ) 
);


localparam integer SHIFT = 32 - IQ_WIDTH - 1;  

reg                  [  63: 0]      Cartesian_Dat               ;

wire    signed       [IQ_WIDTH-1: 0]Data_I                      ;
wire    signed       [IQ_WIDTH-1: 0]Data_Q                      ;
wire    signed       [  31: 0]      I_cordic                    ;
wire    signed       [  31: 0]      Q_cordic                    ;

assign Data_I = IQ_tdata_Delay[IQ_WIDTH-1:0];
assign Data_Q = IQ_tdata_Delay[2*IQ_WIDTH-1:IQ_WIDTH];

assign I_cordic = $signed(Data_I) <<< SHIFT;
assign Q_cordic = $signed(Data_Q) <<< SHIFT;

always @(posedge Clk) begin
    Cartesian_Dat <= {Q_cordic, I_cordic};
end


wire                                    cordic_Result_Val           ;
wire                 [  47: 0]          cordic_Result               ;

// Latency = 23
Frequency_Shift_CORDIC u_Frequency_Shift_CORDIC (
    .aclk                               (Clk                       ),// input wire aclk
    .s_axis_phase_tvalid                (Rotate_Phase_Val          ),// input wire s_axis_phase_tvalid
    .s_axis_phase_tdata                 (Rotate_Phase              ),// input wire [31 : 0] s_axis_phase_tdata
    .s_axis_cartesian_tvalid            (Rotate_Phase_Val          ),// input wire s_axis_cartesian_tvalid
    .s_axis_cartesian_tdata             (Cartesian_Dat             ),// input wire [63 : 0] s_axis_cartesian_tdata
    .m_axis_dout_tvalid                 (cordic_Result_Val         ),// output wire m_axis_dout_tvalid
    .m_axis_dout_tdata                  (cordic_Result             ) // output wire [47 : 0] m_axis_dout_tdata
);

always @(posedge Clk) begin
    if (Rst) begin
        F_Shift_IQ_tvalid <= 'b0;
    end
    else begin
        F_Shift_IQ_tvalid <= cordic_Result_Val;
    end
end

always @(posedge Clk) begin
    if (cordic_Result_Val) begin
        F_Shift_IQ_tdata <= {cordic_Result[39:24], cordic_Result[15:0]};
    end
    else begin
        F_Shift_IQ_tdata <= 'd0;
    end
end

endmodule

`default_nettype wire