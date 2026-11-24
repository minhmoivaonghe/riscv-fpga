// Testbench: chạy core rồi in a0 (x10)
module tb;
    reg clock = 0, rst = 1;
    hehe dut (.clock(clock), .rst(rst));

    always #5 clock = ~clock;

    initial begin
        #20 rst = 0;
        #20000;                                   // đủ lâu cho vòng lặp 10 lần
        $display("a0 = %0d", dut.regs[10]);       // x10 = a0, đúng thì = 10
        $finish;
    end
endmodule
