module lcd(
    output wire tx,
    input  wire clk,
    output reg [7:0] led,
    input  wire rx
);

// bo cong rst o port list, dung reset noi bo
reg       auto_rst = 1;
reg [3:0] rcnt     = 4'd15;     // giu reset 15 chu ky khi bat nguon

wire done = (step == 3'd2) && (state == stop) && tick && (s >= 15) && (bi == 3);

always @(posedge clk) begin
    if (done) begin
        rcnt     <= 4'd15;
        auto_rst <= 1;
    end
    else if (rcnt != 0) begin
        rcnt <= rcnt - 1;
        if (rcnt == 1) auto_rst <= 0;
    end
end

wire rst = auto_rst;            // cac cho dang dung rst giu nguyen
wire r;                          // [SUA] r do loader dieu khien, khong con la reg
wire w;                          // [THEM] khai bao w
wire[7:0] dt;
wire fifo_empty;
reg [8:0]  data;
wire[7:0]  datacontrol;
reg [3:0]  state = 4'd0;
reg [2:0]  step = 3'd0;
reg [4:0]  s = 0, n = 0, i = 0;
wire tick;
reg tx_ena = 0;
reg tx_out = 1'bz;
localparam [3:0]
    ide  = 4'd0,
    start= 4'd1,
    stop = 4'd2;

// ---------------- [THEM] loader + bo nho lenh + CPU ----------------
wire        we, run;
wire [7:0]  addr;
wire [31:0] instr_new;
wire [31:0] result;
wire        result_valid;
reg  [31:0] res;                 // ket qua dang gui
reg  [1:0]  bi = 0;              // byte thu may (0..3)z
wire [7:0]  cur = res[{bi, 3'b000} +: 8];

loader ld (.clk(clk), .rst(rst), .dt(dt), .fifo_empty(fifo_empty), .r(r),
           .we(we), .addr(addr), .instr(instr_new), .run(run));

// CPU: giu reset den khi run = 1; lenh duoc loader ghi thang vao ittm ben trong hehe
hehe u_cpu (.clock(clk), .rst(rst | !run),
            .imem_we(we), .imem_waddr(addr), .imem_wdata(instr_new),
            .result(result), .result_valid(result_valid));
// -------------------------------------------------------------------

control uut (.clk(clk), .rst(rst), .rx(rx), .w(w), .data(datacontrol), .tick(tick));
fifo dut (.clk(clk), .rst(rst), .data(datacontrol), .w(w), .dt(dt), .r(r), .fifo_empty(fifo_empty));
assign tx = (tx_ena == 1) ? tx_out : 1'bz;
always @(posedge clk or posedge rst) begin
        if (rst) begin
            s <= 0;
            n <= 0;
            state <= 4'd0;
            step <= 3'd0;
            tx_ena <= 0;
            tx_out <= 1'bz;
            bi <= 0;             // [THEM]
            res <= 0;            // [THEM]
            led <= 0;            // [THEM]
        end
        else  begin
            case(step)
                3'd0 : begin     // [SUA] cho CPU co dap an thay vi doc FIFO
                    if (result_valid) begin
                        res <= result;
                        led <= result[7:0];
                        bi <= 0;
                        step <= 3'd2;
                    end
                end
                3'd2 : begin     // [SUA] bo "led <= dt;"
                    case(state)
                            ide : begin
                                if (tick == 1) begin
                                    if (s <= 15) begin
                                        tx_ena <= 1;
                                        tx_out <= 0;
                                        s <= s + 1;
                                    end
                                    else begin
                                        tx_ena <= 0;
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
                                            tx_ena <= 1;
                                            tx_out <= cur[n[2:0]];   // [SUA] dt[n] -> cur[n]
                                        end
                                        else begin
                                            s <= 0;
                                            n <= n + 1;
                                            tx_ena <= 0;
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
                                        tx_ena <= 1;
                                        tx_out <= 1;
                                    end
                                    else begin
                                        tx_ena <= 0;
                                        state <= ide;
                                        s <= 0;
                                        if (bi == 3) step <= 3'd0;   // [SUA] het 4 byte moi ve cho
                                        else bi <= bi + 1;           // [THEM] gui byte ke tiep
                                    end
                                end
                            end
                    endcase
                end
                default : step <= 3'd0;
            endcase
        end
    end
endmodule
