//==============================================================================
// RISC-V multi-cycle core (RV32I) 
// FSM: decode -> write | decode -> execute(chỉ load) -> write | decode -> smem(store) -> write
//==============================================================================


//------------------------------------------------------------------------------
// ittm: Instruction memory (RAM, loader ghi, đọc đồng bộ)
//------------------------------------------------------------------------------
module ittm (
    input  wire        clk,
    input  wire        we,            // [THEM] tu loader
    input  wire [7:0]  waddr,         // [THEM] chi so word tu loader
    input  wire [31:0] wdata,         // [THEM] lenh tu loader
    input  wire [31:0] address,       // dia chi byte (PC)
    output reg  [31:0] instruction    // [SUA] reg: doc dong bo, tre 1 chu ky
);
    reg [31:0] memory [0:255];        // 256 word = 1KB

    // [SUA] bo $readmemh: lenh do loader nap qua UART
    always @(posedge clk) begin
        if (we) memory[waddr] <= wdata;
        instruction <= memory[address[9:2]];
    end
endmodule


//------------------------------------------------------------------------------
// ram_mem: Data memory, hỗ trợ LB/LH/LW/LBU/LHU và SB/SH/SW
//------------------------------------------------------------------------------
module ram_mem (
    input  logic        clk,
    input  logic [31:0] addr,         // địa chỉ byte (từ ALU)
    input  logic [31:0] dataW,        // dữ liệu ghi (rs2)
    input  logic [2:0]  funct3,       // kích thước/kiểu truy cập
    input  logic        we,           // write enable (1 = store)
    output logic [31:0] dataR         // dữ liệu đọc (đã sign/zero extend)
);
    logic [31:0] mem [0:25];         // 256 word = 1KB


    wire [7:0]  idx   = addr[9:2];                          // chỉ số word
    wire [31:0] rdata = mem[idx];                           // word đọc ra
    wire [31:0] sh    = rdata >> {addr[1:0], 3'b000};       // dịch để đưa byte/half cần đọc về bit 0

    always @(posedge clk) begin
        //----------------------------------------------------------------------
        // STORE
        //----------------------------------------------------------------------
        if (we) begin
            case (funct3)
                // SB: ghi 1 byte vào đúng vị trí theo addr[1:0]
                3'b000:
                    case (addr[1:0])
                        2'b00:   mem[idx][7:0]   <= dataW[7:0];
                        2'b01:   mem[idx][15:8]  <= dataW[7:0];
                        2'b10:   mem[idx][23:16] <= dataW[7:0];
                        2'b11:   mem[idx][31:24] <= dataW[7:0];
                        default: mem[idx][7:0]   <= dataW[7:0];
                    endcase

                // SH: ghi 2 byte (half-word), addr[1:0] = 00 hoặc 10
                3'b001:
                    case (addr[1:0])
                        2'b00:   mem[idx][15:0]  <= dataW[15:0];
                        2'b10:   mem[idx][31:16] <= dataW[15:0];
                        default: mem[idx][15:0]  <= dataW[15:0];
                    endcase

                // SW: ghi cả word
                default: mem[idx] <= dataW;
            endcase
        end
        //----------------------------------------------------------------------
        // LOAD
        //----------------------------------------------------------------------
        else begin
            case (funct3)
                3'b000:  dataR <= {{24{sh[7]}},  sh[7:0]};     // LB  (sign-extend)
                3'b001:  dataR <= {{16{sh[15]}}, sh[15:0]};    // LH  (sign-extend)
                3'b010:  dataR <= rdata;                       // LW
                3'b100:  dataR <= {24'b0, sh[7:0]};            // LBU (zero-extend)
                3'b101:  dataR <= {16'b0, sh[15:0]};           // LHU (zero-extend)
                default: dataR <= rdata;
            endcase
        end

    end
endmodule


//------------------------------------------------------------------------------
// alu: Khối tính toán số học/logic/so sánh
//------------------------------------------------------------------------------
module alu (
    input  wire [31:0] A, B,
    input  wire [3:0]  op,            // mã phép toán (xem localparam ALU_* ở module hehe)
    output wire [31:0] result
);
    // tách wire riêng để tránh bị ép unsigned trong toán tử ?:
    wire signed [31:0] sra = $signed(A) >>> B[4:0];

    assign result =
        (op == 4'd0)  ? A + B                          :   // ADD
        (op == 4'd1)  ? A - B                          :   // SUB
        (op == 4'd2)  ? A & B                          :   // AND
        (op == 4'd3)  ? A | B                          :   // OR
        (op == 4'd4)  ? A ^ B                          :   // XOR
        (op == 4'd5)  ? {31'b0, $signed(A) < $signed(B)} : // SLT  (so sánh có dấu)
        (op == 4'd6)  ? {31'b0, A < B}                 :   // SLTU (so sánh không dấu)
        (op == 4'd7)  ? A << B[4:0]                    :   // SLL
        (op == 4'd8)  ? A >> B[4:0]                    :   // SRL  (dịch phải logic)
        (op == 4'd9)  ? sra                            :   // SRA  (dịch phải số học)
        (op == 4'd10) ? {31'b0, A == B}                :   // EQ   (dùng cho branch)
                        32'b0;
endmodule


//------------------------------------------------------------------------------
// decoder: Tách các trường của lệnh
//------------------------------------------------------------------------------
module decoder (
    input  wire [31:0] instruction,
    output wire [6:0]  funct7,
    output wire [2:0]  funct3,
    output wire [6:0]  opcode,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd
);
    assign funct7 = instruction[31:25];
    assign funct3 = instruction[14:12];
    assign rs2    = instruction[24:20];
    assign rs1    = instruction[19:15];
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
endmodule


//------------------------------------------------------------------------------
// immcheck: Sinh immediate theo từng loại lệnh + cờ useimm
//------------------------------------------------------------------------------
module immcheck (
    input  wire [31:0] instruction,
    output reg  [31:0] imm,
    output reg         useimm         // 1: ALU lấy imm thay cho rs2
);
    always @(*) begin
        imm    = 32'b0;
        useimm = 1'b0;

        case (instruction[6:0])
            // I-type: LOAD / OP-IMM / JALR
            7'b0000011, 7'b0010011, 7'b1100111: begin
                imm    = {{20{instruction[31]}}, instruction[31:20]};
                useimm = 1'b1;
            end

            // B-type: BRANCH (bit 0 luôn = 0)
            7'b1100011: begin
                imm = {{19{instruction[31]}}, instruction[31], instruction[7],
                       instruction[30:25], instruction[11:8], 1'b0};
            end

            // J-type: JAL (bit 0 luôn = 0)
            7'b1101111: begin
                imm = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                       instruction[20], instruction[30:21], 1'b0};
            end

            // S-type: STORE
            7'b0100011: begin
                imm    = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                useimm = 1'b1;
            end

            // U-type: LUI / AUIPC (imm[31:12] = instruction[31:12], 12 bit thấp = 0)
            7'b0110111, 7'b0010111: begin
                imm    = {instruction[31:12], 12'b0};
                useimm = 1'b1;
            end

            default: ;
        endcase
    end
endmodule


//------------------------------------------------------------------------------
// hehe: CPU top (multi-cycle)
//------------------------------------------------------------------------------
module hehe (
    input  wire        clock,
    input  wire        rst,
    input  wire        imem_we,          // [THEM] tu loader
    input  wire [7:0]  imem_waddr,       // [THEM]
    input  wire [31:0] imem_wdata,       // [THEM]
    output reg  [31:0] result,           // [THEM] dap an (x10) khi gap ebreak
    output reg         result_valid      // [THEM] xung 1 chu ky
);


    //--------------------------------------------------------------------------
    // Thanh ghi và tín hiệu nội bộ
    //--------------------------------------------------------------------------
    integer i;
    reg  [31:0] pc = 32'd0;                    // program counter
    reg  [31:0] A, B;                          // giá trị rs1, rs2 đã chốt ở bước decode
    reg  [3:0]  state = 4'd0;                  // trạng thái FSM
    reg  [31:0] regs [0:31];                   // register file x0..x31
    wire [3:0]  alu_op;                        // phép toán ALU (tổ hợp, tính từ lệnh hiện tại)

    // Tín hiệu của lệnh hiện tại
    wire [31:0] ir;                            // instruction register (đọc từ ROM theo PC)
    wire [31:0] imm;
    wire        useimm;
    wire [6:0]  funct7, opcode;
    wire [2:0]  funct3;
    wire [4:0]  rs1, rs2, rd;
    wire [31:0] alu_result;

    //--------------------------------------------------------------------------
    // Nhận diện loại lệnh theo opcode
    //--------------------------------------------------------------------------
    wire is_op     = (opcode == 7'b0110011);   // R-type
    wire is_opimm  = (opcode == 7'b0010011);   // I-type ALU
    wire is_load   = (opcode == 7'b0000011);   // LOAD
    wire is_branch = (opcode == 7'b1100011);   // BRANCH
    wire is_jal    = (opcode == 7'b1101111);   // JAL
    wire is_jalr   = (opcode == 7'b1100111);   // JALR
    wire is_rtype  = (opcode == 7'b0110011);   // R-type (trùng is_op)
    wire is_stype  = (opcode == 7'b0100011);   // STORE
    wire is_lui    = (opcode == 7'b0110111);   // LUI
    wire is_auipc  = (opcode == 7'b0010111);   // AUIPC    

    // Chọn toán hạng cho ALU
    wire [31:0] alu_b = useimm ? imm : B;      // imm hoặc rs2
    wire [31:0] alu_a = is_lui   ? 32'b0 :     // LUI:   0 + imm
                        is_auipc ? pc    :     // AUIPC: pc + imm
                                   A;          // còn lại: rs1
    logic [31:0] load_out;                     // dữ liệu đọc từ RAM

    logic        mem_we = 0;                   // write enable cho RAM (S-type)

    //--------------------------------------------------------------------------
    // Các khối con
    //--------------------------------------------------------------------------
    ittm u_mem (.clk(clock), .we(imem_we), .waddr(imem_waddr), .wdata(imem_wdata),
                .address(pc), .instruction(ir));

    decoder u_dec (
        .instruction(ir),
        .funct7(funct7), .funct3(funct3), .opcode(opcode),
        .rs1(rs1), .rs2(rs2), .rd(rd)
    );

    immcheck u_imm (.instruction(ir), .imm(imm), .useimm(useimm));

    alu u_alu (.A(alu_a), .B(alu_b), .op(alu_op), .result(alu_result));   // alu_a: 0 (LUI) / pc (AUIPC) / rs1

    ram_mem u_ram (
        .clk    (clock),
        .addr   (alu_result),                  // địa chỉ = rs1 + imm
        .dataW  (B),                           // dữ liệu store = rs2
        .funct3 (funct3),
        .we     (mem_we),
        .dataR  (load_out)
    );

    //--------------------------------------------------------------------------
    // Hằng số
    //--------------------------------------------------------------------------
    // Trạng thái FSM
    localparam [3:0]
        decode  = 4'd0,                        // đọc rs1, rs2
        execute = 4'd1,                        // chờ RAM đọc (chỉ cho LOAD)
        smem    = 4'd2,                        // bật ghi RAM (store)
        write   = 4'd3,                        // ghi regs, cập nhật PC
        fetch   = 4'd4,                        // [THEM] cho ittm doc lenh moi
        halt    = 4'd5;                        // [THEM] dung sau ebreak

    // Mã phép toán ALU
    localparam
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_AND  = 4'd2,
        ALU_OR   = 4'd3,
        ALU_XOR  = 4'd4,
        ALU_SLT  = 4'd5,
        ALU_SLTU = 4'd6,
        ALU_SLL  = 4'd7,
        ALU_SRL  = 4'd8,
        ALU_SRA  = 4'd9,
        ALU_EQ   = 4'd10;

    //--------------------------------------------------------------------------
    // Giải mã alu_op (tổ hợp)
    //--------------------------------------------------------------------------
    // BRANCH: funct3[2:1] = 00 -> EQ (BEQ/BNE), 10 -> SLT (BLT/BGE), 11 -> SLTU (BLTU/BGEU)
    wire [3:0] alu_op_branch = (funct3[2:1] == 2'b10) ? ALU_SLT  :
                               (funct3[2:1] == 2'b11) ? ALU_SLTU :
                                                        ALU_EQ;

    // R-type / I-type ALU
    wire [3:0] alu_op_arith  = (funct3 == 3'b000) ? ((is_rtype && funct7[5]) ? ALU_SUB : ALU_ADD) :
                               (funct3 == 3'b001) ? ALU_SLL :
                               (funct3 == 3'b010) ? ALU_SLT :
                               (funct3 == 3'b011) ? ALU_SLTU :
                               (funct3 == 3'b100) ? ALU_XOR :
                               (funct3 == 3'b101) ? (funct7[5] ? ALU_SRA : ALU_SRL) :
                               (funct3 == 3'b110) ? ALU_OR :
                                                    ALU_AND;

    // LOAD / STORE / JAL / JALR / LUI / AUIPC: ALU làm phép cộng
    assign alu_op = (is_load || is_jalr || is_jal || is_stype || is_lui || is_auipc) ? ALU_ADD :
                    (is_branch)                                                      ? alu_op_branch :
                                                                                       alu_op_arith;

    // Khởi tạo register file = 0
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
    end

    // Dữ liệu ghi ngược vào rd
    wire [31:0] wb_data = (is_jal || is_jalr) ? (pc + 4) :   // link address
                          (is_load)           ? load_out :   // dữ liệu từ RAM
                                                alu_result;  // kết quả ALU

    //--------------------------------------------------------------------------
    // FSM chính
    //--------------------------------------------------------------------------
    always @(posedge clock or posedge rst) begin
        if (rst) begin
            pc    <= 32'b0;
            state <= fetch;                  // [SUA] decode -> fetch
            result       <= 32'b0;           // [THEM]
            result_valid <= 1'b0;            // [THEM]
        end
        else begin
            result_valid <= 1'b0;            // [THEM] xung 1 chu ky
            case (state)

                //--------------------------------------------------------------
                // DECODE: chốt giá trị rs1, rs2
                //--------------------------------------------------------------
                decode: begin
                    A     <= regs[rs1];
                    B     <= regs[rs2];
                    // LOAD cần 1 chu kỳ chờ (RAM đọc đồng bộ), STORE đi qua smem, còn lại sang write
                    if (ir == 32'h00100073) begin            // [THEM] ebreak: chot dap an = x10
                        result       <= regs[10];
                        result_valid <= 1'b1;
                        state        <= halt;
                    end
                    else
                    state <= is_load  ? execute :
                             is_stype ? smem    : write;
                end

                //--------------------------------------------------------------
                // EXECUTE: chỉ dùng cho LOAD, chờ RAM chốt dataR
                //--------------------------------------------------------------
                execute: state <= write;

                //--------------------------------------------------------------
                // SMEM: bật write enable để ghi RAM
                //--------------------------------------------------------------
                smem: begin
                    mem_we <= 1;
                    state  <= write;
                end

                //--------------------------------------------------------------
                // WRITE: ghi register, cập nhật PC
                //--------------------------------------------------------------
                write: begin
                    mem_we <= 0;                              // tắt ghi RAM

                    // Ghi rd (bỏ qua x0 và lệnh branch)
                    if (rd != 5'd0 && !is_branch && !is_stype) begin
                        regs[rd] <= wb_data;
                    end

                    // Cập nhật PC
                    if (is_branch) begin
                        case (funct3)
                            // BNE, BGE, BGEU: nhảy khi kết quả so sánh = 0
                            3'b001, 3'b101, 3'b111: begin
                                if (!alu_result)
                                    pc <= pc + imm;
                                else
                                    pc <= pc + 4;
                            end

                            // BEQ, BLT, BLTU: nhảy khi kết quả so sánh = 1
                            default: begin
                                if (alu_result)
                                    pc <= pc + imm;
                                else
                                    pc <= pc + 4;
                            end
                        endcase
                    end
                    else if (is_jal)
                        pc <= pc + imm;                       // JAL:  pc + imm
                    else if (is_jalr)
                        pc <= {alu_result[31:1], 1'b0};       // JALR: (rs1 + imm) & ~1
                    else
                        pc <= pc + 4;                         // lệnh thường

                    state <= fetch;                           // [SUA] decode -> fetch
                end

                // [THEM] fetch: cho ittm (doc dong bo) co lenh moi
                fetch: state <= decode;

                // [THEM] halt: dung han sau ebreak (nhan rst de nap chuong trinh moi)
                halt:  state <= halt;

                default: state <= decode;
            endcase
        end
    end
endmodule