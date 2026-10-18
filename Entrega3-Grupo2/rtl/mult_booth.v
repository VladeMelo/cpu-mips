`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// MULT - Multiplicador sinalizado de 32 bits (algoritmo de Booth, radix 2)
//
// Comunicacao com a UC:
//   MultStart (start) -> carrega os operandos e inicia o algoritmo
//   MultEnd   (done)  -> fica em 1 quando hi/lo contem o resultado final
//
// Algoritmo (uma iteracao por ciclo, 32 iteracoes):
//   {AC, Q, Q-1} = {0, B, 0},  M = A  (AC e M com 33 bits, estendidos com
//   sinal, para que AC - M nao estoure quando A = -2^31)
//   a cada ciclo: olha {Q[0], Q-1}
//      01 -> AC = AC + M
//      10 -> AC = AC - M
//      00/11 -> nada
//   em seguida desloca {AC, Q, Q-1} uma posicao para a direita (aritmetico)
//   apos 32 iteracoes: HI = AC, LO = Q
//
// Latencia: 1 ciclo de carga (estado S_MULT_START) + 32 ciclos de calculo.
// O reset limpa TODOS os registradores internos, inclusive os de resultado.
// -----------------------------------------------------------------------------
module mult_booth (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,     // MultStart
    input  wire [31:0] a,         // multiplicando (A)
    input  wire [31:0] b,         // multiplicador (B)
    output reg  [31:0] hi,        // 32 bits mais significativos
    output reg  [31:0] lo,        // 32 bits menos significativos
    output reg         done       // MultEnd
);

    reg [32:0] ac;
    reg [31:0] q;
    reg        q_1;
    reg [32:0] m;
    reg [5:0]  count;
    reg        busy;

    // soma/subtracao da iteracao atual
    reg [32:0] soma;
    always @(*) begin
        case ({q[0], q_1})
            2'b01:   soma = ac + m;
            2'b10:   soma = ac - m;
            default: soma = ac;
        endcase
    end

    // deslocamento aritmetico a direita de {soma, q, q_1}
    wire [32:0] ac_next = {soma[32], soma[32:1]};
    wire [31:0] q_next  = {soma[0], q[31:1]};
    wire        q1_next = q[0];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ac    <= 33'd0;
            q     <= 32'd0;
            q_1   <= 1'b0;
            m     <= 33'd0;
            count <= 6'd0;
            busy  <= 1'b0;
            hi    <= 32'd0;
            lo    <= 32'd0;
            done  <= 1'b0;
        end else if (start) begin
            ac    <= 33'd0;
            q     <= b;
            q_1   <= 1'b0;
            m     <= {a[31], a};
            count <= 6'd32;
            busy  <= 1'b1;
            done  <= 1'b0;
        end else if (busy) begin
            ac    <= ac_next;
            q     <= q_next;
            q_1   <= q1_next;
            count <= count - 6'd1;
            if (count == 6'd1) begin
                busy <= 1'b0;
                done <= 1'b1;
                hi   <= ac_next[31:0];
                lo   <= q_next;
            end
        end
    end

endmodule
