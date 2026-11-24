`timescale 1ns/1ps

module tik_tb;
    reg  clk;
    reg  rst;
    wire tick;
    reg rx = 0;
    wire [7:0] data;
    wire w;
    reg [7:0] dt [0:9];
    integer count = 0;
    integer error = 0;

    initial begin
        dt[0] = 8'h54;
        dt[1] = 8'hCD;
    end
    control uut (.clk(clk), .rst(rst), .rx(rx), .w(w), .data(data));
    tik dut(.tick(tick), .clk(clk), .rst(rst));
    always #10 clk = ~clk;

    reg [4:0]  s = 0, n = 0, i = 0;
    reg [3:0]  state = 4'd0;
    localparam [3:0]
        ide  = 4'd0,
        start= 4'd1,
        stop = 4'd2;
    initial begin
        clk = 0;
        rst = 1;
        dt[0] = 8'b01010100;  
        dt[1] = 8'b11001101;
        $dumpfile("tik_tb.vcd");
        $dumpvars(0, tik_tb);
        #25;
        rst = 0;
    end
    always @(posedge clk ) begin
        if (rst) begin 
            s <= 0;
            n <= 0;
            state <= 4'd0;
        end
        else begin 
            case(state)
                    ide : begin 
                        if (tick == 1) begin
                            if (s <= 15) begin
                                rx <= 0; 
                                s <= s + 1;
                            end
                            else begin
                                state <= start;
                                s <= 0;                                                    
                            end                    
                        end
                    end
                    start : begin 
                        if (n < 8) begin
                            if (tick == 1) begin
                                if (s < 15) begin
                                    s <= s + 1;
                                    rx <= dt[count][n];     
                                end
                                else begin                 
                                    s <= 0;
                                    n <= n + 1;        
                                end
                            end
                        end
                        else begin 
                            state <= stop;
                            n <= 0;
                            s <= 0;
                        end
                    end
                    stop : begin
                        if (tick == 1) begin 
                            if (s < 15) begin
                                s <= s + 1;
                                rx <= 1;
                            end
                            else begin
                                state <= ide;
                                s <= 0;
                            end
                        end
                    end
            endcase        
        end
    end 
    always @(posedge clk) begin
        if(w) begin
            if(data == dt[count]) begin
                $display("PASS : Byte %0d = %02h",count,data);
            end
            else begin
                $display("FAIL : Byte %0d",count);
                $display("dt = %02h",dt[count]);
                $display("Receive  = %02h",data);
                error = error + 1;
            end
            if (count) begin 
                if(error==0)
                    $display("========== TEST PASS ==========");
                else
                    $display("========== TEST FAIL (%0d errors)",error);
                $stop;   
            end
            count = count + 1;

        end
    end
endmodule