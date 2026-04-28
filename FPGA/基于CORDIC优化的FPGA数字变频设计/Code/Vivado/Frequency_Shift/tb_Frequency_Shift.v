`timescale 1ns/1ps
`default_nettype none

module tb_Frequency_Shift;

parameter                           IQ_WIDTH                  = 'd16                 ;

reg                                     Clk                        ;
reg                                     Rst                        ;
reg                                     IQ_tvalid                  ;
reg                  [2*IQ_WIDTH-1: 0]  IQ_tdata                   ;
reg                  [  31: 0]          F_Shift                    ;
reg                  [  31: 0]          Sample_Rate                ;

wire                                    F_Shift_IQ_tvalid          ;
wire                 [2*IQ_WIDTH-1: 0]  F_Shift_IQ_tdata           ;

reg                  [  31: 0]          Cnt                        ;

reg                  [2*IQ_WIDTH-1: 0]  IQ_Data_Mem[0:109599]      ;

Frequency_Shift #(
    .IQ_WIDTH                           (IQ_WIDTH                  ) 
) u_Frequency_Shift (
    .Clk                                (Clk                       ),
    .Rst                                (Rst                       ),
    .IQ_tvalid                          (IQ_tvalid                 ),
    .IQ_tdata                           (IQ_tdata                  ),
    .F_Shift                            (F_Shift                   ),
    .Sample_Rate                        (Sample_Rate               ),

    .F_Shift_IQ_tvalid                  (F_Shift_IQ_tvalid         ),
    .F_Shift_IQ_tdata                   (F_Shift_IQ_tdata          ) 
);

localparam CLK_PERIOD = 10;
always #(CLK_PERIOD/2) Clk=~Clk;

initial begin
    $readmemh("IQ_Data.mem", IQ_Data_Mem);
end

integer fid_result;

initial begin
    fid_result = $fopen("IQ_Result.txt", "w");
    if (fid_result == 0) begin
        $display("ERROR: Cannot open IQ_Result.txt");
        $finish;
    end
end

initial begin
    #1 Rst<=1'bx;Clk<=1'bx;
    #(CLK_PERIOD*3) Rst<=0;
    #(CLK_PERIOD*3) Rst<=1;Clk<=0;
    repeat(5) @(posedge Clk);
    Rst<=0;
    IQ_tvalid = 'b0;
    F_Shift = 'd10000000;
    Sample_Rate = 'd122880000;
    @(posedge Clk);
    repeat(2) @(posedge Clk);
    #1;
    #(CLK_PERIOD*30);
    IQ_tvalid = 'b1;
    #(CLK_PERIOD*109600);
    IQ_tvalid = 'b0;
end

always @(posedge Clk) begin
    if (Rst) begin
        Cnt <= 'd0;
    end
    else if (IQ_tvalid) begin
        Cnt <= Cnt + 1;
    end
    else begin
        Cnt <= 'd0;
    end
end

always @(*) begin
    IQ_tdata = IQ_Data_Mem[Cnt];
end

always @(posedge Clk) begin
    if (F_Shift_IQ_tvalid) begin
        $fwrite(fid_result, "%h\n", F_Shift_IQ_tdata);
    end
end

endmodule
`default_nettype wire