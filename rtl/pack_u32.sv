module loader(
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  dt,           // tu fifo
    input  wire        fifo_empty,   // tu fifo
    output reg         r,            // den fifo
    output reg         we,           // 1 chu ky khi co 1 instruction moi
    output reg  [7:0]  addr,         // dia chi instruction
    output reg  [31:0] instr,        // instruction da ghep
    output reg         run           // 1 = cho CPU chay
);
    reg [2:0]  step;
    reg [1:0]  cnt;
    reg [23:0] tmp;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r     <= 0;
            we    <= 0;
            addr  <= 0;
            instr <= 0;
            run   <= 0;
            step  <= 3'd0;
            cnt   <= 2'd0;
            tmp   <= 0;
        end
        else begin
            we <= 0;
            if (we) addr <= addr + 1;
            case (step)
                3'd0 : begin
                    r <= 0;
                    if (!fifo_empty) begin
                        r <= 1;
                        step <= 3'd1;
                    end
                end
                3'd1 : begin
                    r <= 0;
                    step <= 3'd2;
                end
                3'd2 : begin
                    step <= 3'd0;
                    if (run == 0) begin
                        if (cnt == 0 && dt == 8'h47) begin   // 'G'
                            run <= 1;
                        end
                        else begin
                            case (cnt)
                                2'd0 : begin
                                    tmp[7:0] <= dt;
                                    cnt <= 2'd1;
                                end
                                2'd1 : begin
                                    tmp[15:8] <= dt;
                                    cnt <= 2'd2;
                                end
                                2'd2 : begin
                                    tmp[23:16] <= dt;
                                    cnt <= 2'd3;
                                end
                                2'd3 : begin
                                    instr <= {dt, tmp};
                                    we <= 1;
                                    cnt <= 2'd0;
                                end
                            endcase
                        end
                    end
                end
                default : step <= 3'd0;
            endcase
        end
    end
endmodule