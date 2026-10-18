`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// DIV - Divisor sinalizado de 32 bits (divisao por restauracao)
//
// Comunicacao com a UC:
//   DivStart (start) -> carrega os operandos e inicia o algoritmo
//   DivEnd   (done)  -> fica em 1 quando hi/lo contem o resultado final
//   DIV0     (div0)  -> fica em 1 quando o divisor e zero (excecao)
//
// Resultado (igual ao MIPS): LO = quociente, HI = resto.
//   O quociente e truncado em direcao a zero e o resto tem o sinal do
//   dividendo (ex.: -7 / 2 -> LO = -3, HI = -1).
//
// Algoritmo:
//   1. guarda o modulo de A (dividendo) e de B (divisor) e os sinais
//   2. 32 iteracoes do algoritmo de restauracao sem sinal:
//        R = (R << 1) | Q[31];  Q = Q << 1
//        se R >= M: R = R - M; Q[0] = 1
//   3. corrige os sinais: quociente negativo se sinais diferentes,
//      resto negativo se dividendo negativo
//
// Latencia: 1 ciclo de carga (S_DIV_START) + 32 iteracoes + 1 de correcao.
// O reset limpa TODOS os registradores internos, inclusive os de resultado.
// -----------------------------------------------------------------------------
module div_signed (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,     // DivStart
    input  wire [31:0] a,         // dividendo (A = rs)
    input  wire [31:0] b,         // divisor   (B = rt)
    output reg  [31:0] hi,        // resto
    output reg  [31:0] lo,        // quociente
    output reg         done,      // DivEnd
    output reg         div0       // divisao por zero
);

    reg [31:0] r;          // resto parcial
    reg [31:0] q;          // quociente parcial / dividendo deslocado
    reg [31:0] m;          // modulo do divisor
    reg        sinal_q;    // quociente negativo?
    reg        sinal_r;    // resto negativo?
    reg [5:0]  count;
    reg        busy;

    // iteracao combinacional
    wire [32:0] r_desl = {r, q[31]};               // (R << 1) | Q[31] com 33 bits
    wire [32:0] teste  = r_desl - {1'b0, m};
    wire        cabe   = ~teste[32];               // R >= M
    wire [31:0] r_next = cabe ? teste[31:0] : r_desl[31:0];
    wire [31:0] q_next = {q[30:0], cabe};

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r       <= 32'd0;
            q       <= 32'd0;
            m       <= 32'd0;
            sinal_q <= 1'b0;
            sinal_r <= 1'b0;
            count   <= 6'd0;
            busy    <= 1'b0;
            hi      <= 32'd0;
            lo      <= 32'd0;
            done    <= 1'b0;
            div0    <= 1'b0;
        end else if (start) begin
            done <= 1'b0;
            if (b == 32'd0) begin
                div0 <= 1'b1;
                busy <= 1'b0;
            end else begin
                div0    <= 1'b0;
                r       <= 32'd0;
                q       <= a[31] ? (~a + 32'd1) : a;
                m       <= b[31] ? (~b + 32'd1) : b;
                sinal_q <= a[31] ^ b[31];
                sinal_r <= a[31];
                count   <= 6'd32;
                busy    <= 1'b1;
            end
        end else if (busy) begin
            if (count != 6'd0) begin
                r     <= r_next;
                q     <= q_next;
                count <= count - 6'd1;
            end else begin
                // correcao de sinal e escrita do resultado
                lo   <= sinal_q ? (~q + 32'd1) : q;
                hi   <= sinal_r ? (~r + 32'd1) : r;
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end

endmodule
