`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// CPU multiciclo MIPS - Grupo 2 (Entrega 3)
//
// Datapath montado a partir do diagrama de blocos da Entrega 1
// (Entrega1-Grupo2-completo.drawio.xml) e controlado pela FSM da Entrega 2
// (FSM-Grupo2-linhas.drawio), implementada em unidade_controle.v.
//
// Componentes fornecidos (VHDL, usados sem modificacao):
//   Memoria, Registrador, Instr_Reg, Banco_reg, RegDesloc, Ula32
// Componentes do grupo (Verilog): unidade_controle, mult_booth, div_signed,
//   muxes, sign_extend_16_32, shift_left_2, jump_address, shift_left_16,
//   zero_extender, exception_address, load_size, store_size, alu_control
//
// Como no diagrama/FSM: A, B, ALUOut, MDR, HI e LO carregam todo ciclo
// (Load = 1); PC, IR, EPC e o banco de registradores tem enable.
// -----------------------------------------------------------------------------
module cpu (
    input wire clk,
    input wire reset
);

    // ------------------------------------------------------------- sinais de controle
    wire       PCWrite, PCWriteCond, MemRead, MemWrite, IRWrite;
    wire       ALUSrcA, RegWrite, SrcSP, EPCWrite, ByteWrite;
    wire       HISelect, LOSelect, MultStart, DivStart;
    wire [1:0] IorD, ALUSrcB, RegDst, ExcType;
    wire [2:0] PCSource, ALUOp, ShiftOp;
    wire [3:0] MemtoReg;
    wire [6:0] estado;

    // ------------------------------------------------------------- barramentos
    wire [31:0] pc_out, pc_in;
    wire        pc_enable;
    wire [31:0] mem_address, mem_data_in, mem_data_out;
    wire [31:0] mdr_out;
    wire [5:0]  ir31_26;
    wire [4:0]  ir25_21, ir20_16;
    wire [15:0] ir15_0;
    wire [4:0]  read_reg1, read_reg2, write_reg;
    wire [31:0] write_data, read_data1, read_data2;
    wire [31:0] a_out, b_out;
    wire [31:0] alu_a, alu_b, alu_result, aluout_out;
    wire [2:0]  alu_sel;
    wire        alu_overflow, alu_neg, alu_zero, alu_igual, alu_maior, alu_menor;
    wire [31:0] sign_ext, sign_ext_sl2, jump_addr, imm_sl16;
    wire [31:0] epc_out, exc_address, zero_ext;
    wire [31:0] shift_out;
    wire [31:0] load_size_out, store_size_out;
    wire [31:0] mult_hi, mult_lo, div_hi, div_lo;
    wire        mult_end, div_end, div0;
    wire [31:0] hi_in, lo_in, hi_out, lo_out;

    // campos da instrucao
    wire [4:0] ir15_11 = ir15_0[15:11];   // rd
    wire [4:0] ir10_6  = ir15_0[10:6];    // shamt
    wire [5:0] ir5_0   = ir15_0[5:0];     // funct

    // ------------------------------------------------------------- unidade de controle
    unidade_controle uc (
        .clk(clk), .reset(reset),
        .op(ir31_26), .funct(ir5_0),
        .overflow(alu_overflow),
        .mult_end(mult_end), .div_end(div_end), .div0(div0),
        .PCWrite(PCWrite), .PCWriteCond(PCWriteCond), .IorD(IorD),
        .MemRead(MemRead), .MemWrite(MemWrite), .MemtoReg(MemtoReg),
        .IRWrite(IRWrite), .PCSource(PCSource), .ALUOp(ALUOp),
        .ALUSrcB(ALUSrcB), .ALUSrcA(ALUSrcA), .RegWrite(RegWrite),
        .RegDst(RegDst), .ShiftOp(ShiftOp), .SrcSP(SrcSP),
        .EPCWrite(EPCWrite), .ExcType(ExcType), .ByteWrite(ByteWrite),
        .HISelect(HISelect), .LOSelect(LOSelect),
        .MultStart(MultStart), .DivStart(DivStart),
        .estado(estado)
    );

    // ------------------------------------------------------------- PC
    // portas AND/OR do diagrama: PCEnable = PCWrite OR (PCWriteCond AND Zero)
    assign pc_enable = PCWrite | (PCWriteCond & alu_zero);

    Registrador PC (
        .Clk(clk), .Reset(reset), .Load(pc_enable),
        .Entrada(pc_in), .Saida(pc_out)
    );

    // ------------------------------------------------------------- memoria
    exception_address exc_addr (
        .exc_type(ExcType), .address(exc_address)
    );

    mux_iord m_iord (
        .sel(IorD), .in0(pc_out), .in1(aluout_out), .in2(exc_address),
        .out(mem_address)
    );

    mux_bytewrite m_bytewrite (
        .sel(ByteWrite), .in0(b_out), .in1(store_size_out), .out(mem_data_in)
    );

    // Wr = 0 le, Wr = 1 escreve (MemRead nao tem porta na Memoria fornecida)
    Memoria MEM (
        .Address(mem_address), .Clock(clk), .Wr(MemWrite),
        .Datain(mem_data_in), .Dataout(mem_data_out)
    );

    // ------------------------------------------------------------- IR e MDR
    Instr_Reg IR (
        .Clk(clk), .Reset(reset), .Load_ir(IRWrite), .Entrada(mem_data_out),
        .Instr31_26(ir31_26), .Instr25_21(ir25_21),
        .Instr20_16(ir20_16), .Instr15_0(ir15_0)
    );

    Registrador MDR (
        .Clk(clk), .Reset(reset), .Load(1'b1),
        .Entrada(mem_data_out), .Saida(mdr_out)
    );

    // Load Size (lb) e Store Size (sb)
    load_size ls (
        .word_read(mdr_out), .which_byte(aluout_out[1:0]),
        .extended_byte(load_size_out)
    );

    store_size ss (
        .new_byte(b_out[7:0]), .current_word(mdr_out),
        .where_to_put(aluout_out[1:0]), .out(store_size_out)
    );

    // Zero extender: byte de 253/254/255 -> endereco da rotina de excecao
    zero_extender zext (
        .read_byte(mdr_out[7:0]), .address(zero_ext)
    );

    // ------------------------------------------------------------- banco de registradores
    mux_readreg1 m_rr1 (.sel(SrcSP), .in0(ir25_21), .out(read_reg1));
    mux_readreg2 m_rr2 (.sel(SrcSP), .in0(ir20_16), .in1(ir25_21), .out(read_reg2));

    mux_regdst m_regdst (
        .sel(RegDst), .in0(ir20_16), .in1(ir15_11), .out(write_reg)
    );

    shift_left_16 sl16 (.in(ir15_0), .out(imm_sl16));

    mux_memtoreg m_memtoreg (
        .sel(MemtoReg),
        .in0(aluout_out), .in1(mdr_out), .in2(hi_out), .in3(lo_out),
        .in4(shift_out), .in5(load_size_out), .in6(imm_sl16),
        .lt(alu_menor),
        .out(write_data)
    );

    Banco_reg banco (
        .Clk(clk), .Reset(reset), .RegWrite(RegWrite),
        .ReadReg1(read_reg1), .ReadReg2(read_reg2), .WriteReg(write_reg),
        .WriteData(write_data), .ReadData1(read_data1), .ReadData2(read_data2)
    );

    Registrador A (
        .Clk(clk), .Reset(reset), .Load(1'b1),
        .Entrada(read_data1), .Saida(a_out)
    );

    Registrador B (
        .Clk(clk), .Reset(reset), .Load(1'b1),
        .Entrada(read_data2), .Saida(b_out)
    );

    // ------------------------------------------------------------- ULA
    sign_extend_16_32 sext (.in(ir15_0), .out(sign_ext));
    shift_left_2      sl2  (.in(sign_ext), .out(sign_ext_sl2));

    mux_alusrca m_alusrca (.sel(ALUSrcA), .in0(pc_out), .in1(a_out), .out(alu_a));

    mux_alusrcb m_alusrcb (
        .sel(ALUSrcB), .in0(b_out), .in2(sign_ext), .in3(sign_ext_sl2),
        .out(alu_b)
    );

    alu_control alu_ctrl (.alu_op(ALUOp), .funct(ir5_0), .seletor(alu_sel));

    Ula32 ULA (
        .A(alu_a), .B(alu_b), .Seletor(alu_sel), .S(alu_result),
        .Overflow(alu_overflow), .Negativo(alu_neg), .z(alu_zero),
        .Igual(alu_igual), .Maior(alu_maior), .Menor(alu_menor)
    );

    Registrador ALUOut (
        .Clk(clk), .Reset(reset), .Load(1'b1),
        .Entrada(alu_result), .Saida(aluout_out)
    );

    // ------------------------------------------------------------- PCSource / EPC
    jump_address jaddr (
        .instr25_0({ir25_21, ir20_16, ir15_0}), .pc31_28(pc_out[31:28]),
        .out(jump_addr)
    );

    Registrador EPC (
        .Clk(clk), .Reset(reset), .Load(EPCWrite),
        .Entrada(pc_out), .Saida(epc_out)
    );

    mux_pcsource m_pcsource (
        .sel(PCSource),
        .in0(alu_result), .in1(aluout_out), .in2(jump_addr),
        .in3(epc_out), .in4(zero_ext),
        .out(pc_in)
    );

    // ------------------------------------------------------------- registrador de deslocamento
    RegDesloc ShiftReg (
        .Clk(clk), .Reset(reset), .Shift(ShiftOp), .N(ir10_6),
        .Entrada(b_out), .Saida(shift_out)
    );

    // ------------------------------------------------------------- MULT / DIV / HI / LO
    mult_booth MULT (
        .clk(clk), .reset(reset), .start(MultStart),
        .a(a_out), .b(b_out),
        .hi(mult_hi), .lo(mult_lo), .done(mult_end)
    );

    div_signed DIV (
        .clk(clk), .reset(reset), .start(DivStart),
        .a(a_out), .b(b_out),
        .hi(div_hi), .lo(div_lo), .done(div_end), .div0(div0)
    );

    mux_2x32 m_hi (.sel(HISelect), .in0(div_hi),  .in1(mult_hi), .out(hi_in));
    mux_2x32 m_lo (.sel(LOSelect), .in0(mult_lo), .in1(div_lo),  .out(lo_in));

    Registrador HI (
        .Clk(clk), .Reset(reset), .Load(1'b1), .Entrada(hi_in), .Saida(hi_out)
    );

    Registrador LO (
        .Clk(clk), .Reset(reset), .Load(1'b1), .Entrada(lo_in), .Saida(lo_out)
    );

endmodule
