`timescale 1ns/1ps

module shiftreg #(
    parameter                           WIDTH                       = 12                   ,
    parameter                           LENGTH                      = 46                   
) (
    input                               CLK                        ,
    input                [WIDTH-1: 0]   D                          ,
    output               [WIDTH-1: 0]   Q                          ,
    input                               CE                          
);


reg                [WIDTH-1: 0]        Data[0:LENGTH-1]            ;

wire               [WIDTH-1: 0]        DataIn                      ;


initial begin : INIT_DATA
    integer i;
    for (i = 0; i < LENGTH; i = i + 1) begin
        Data[i] = {WIDTH{1'b0}};
    end
end


assign                              DataIn                      = D                    ;
assign                              Q                           = Data[LENGTH-1]       ;

always @(posedge CLK) begin
    if (CE) begin
        Data[0] <= DataIn;
    end
end

genvar i;

generate
    for (i = 0; i < (LENGTH - 1); i = i + 1) begin
        always @(posedge CLK) begin
            if (CE) begin
                Data[i+1] <= Data[i];
            end
        end
    end
endgenerate


endmodule