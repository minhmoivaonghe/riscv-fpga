module fifo (
    input  wire clk,
    input  wire rst,
    input  wire [7:0] data,
    input  wire w,
    output reg [7:0] dt,
    input  wire r,
    output wire fifo_empty
);
    reg [7:0] datafifo [64];
    reg [6:0]  rd = 0, wr = 0;
    wire empty = (rd == wr);
    assign fifo_empty = empty;
    wire full  = (rd[5:0] == wr[5:0]) && (rd[6] != wr[6]);    
    always @(posedge clk or posedge rst) begin
        if (rst) begin 
            rd <= 0;
            wr <= 0;
            datafifo <= '{default: 8'd0};
        end
        else begin 
            if (w && !full) begin 
                datafifo[wr[5:0]] <= data ;
                wr <= wr + 1;
            end
            if (r && !empty) begin
                dt <= datafifo[rd[5:0]];
                rd <= rd + 1;             
            end
        end
    end 
endmodule
