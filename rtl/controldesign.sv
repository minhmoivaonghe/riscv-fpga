module tik (
    input  wire clk,
    input  wire rst,
    output reg tick
);
    reg [25:0] count = 0;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            tick  <= 0;
        end
        else if (count == 162) begin
            count <= 0;
            tick  <= 1;
        end
        else begin
            count <= count + 1;
            tick  <= 0;
        end
    end
endmodule
module control (
    input  wire clk,
    input  wire rst,
    input  wire rx,
    output reg [7:0] data,
    output wire tick,
    output reg w
);
    reg [4:0]  s = 0, n = 0;
    reg [3:0]  state = 4'd0;
    localparam [3:0]
        ide  = 4'd0,
        start= 4'd1,
        stop = 4'd2;
    tik dut(.tick(tick), .clk(clk), .rst(rst));
    always @(posedge clk or posedge rst) begin
        if (rst) begin 
            data <= 8'b0;
            w <= 0;
            s <= 0;
            n <= 0;
            state <= 4'd0;
        end
        else begin 
            case(state)
                ide : begin 
                    w <= 0;
                    if (rx == 0) begin 
                        if (tick == 1) begin
                            w <= 0;
                            if (s <= 7) begin 
                                s <= s + 1;
                            end
                            else begin
                                state <= start;
                                s <= 0;                                                    
                            end                    
                        end
                    end
                    else s <= 0;
                end
                start : begin 
                    if (n <= 7) begin
                        if (tick == 1) begin
                            if (s < 15) s <= s + 1;
                            else begin                 
                                data <= {rx , data[7:1]};
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
                        end
                        else begin
                            state <= ide;
                            w <= 1;
                            s <= 0;
                        end
                    end
                end
            endcase
        end
    end 
endmodule
