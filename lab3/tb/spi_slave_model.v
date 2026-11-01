// =========================================================================
// Модуль  : spi_slave_model (лише для симуляції, не синтезується)
// Проєкт  : ЛР3 АПКС, варіант 12 (SPI, Verilog), Кравченко В. А., КІ-405
// Опис    : Поведінкова модель зовнішнього SPI Slave-пристрою.
//           Імітує "інший пристрій", щоб перевірити обидва напрямки:
//             - приймає байт, який Master видає на MOSI (rx_byte);
//             - одночасно відповідає своїм байтом tx_byte на лінії MISO.
//           Працює в тому самому режимі (CPOL/CPHA), що й Master.
//           Поки CS_N = 1, лінія MISO у високоімпедансному стані (Z).
// =========================================================================
`timescale 1ns / 1ps

module spi_slave_model #(
    parameter DATA_WIDTH = 8
) (
    input  wire                  sclk,
    input  wire                  cs_n,
    input  wire                  mosi,
    output reg                   miso,
    input  wire                  cpol,       // режим має збігатися з Master
    input  wire                  cpha,
    input  wire [DATA_WIDTH-1:0] tx_byte,    // відповідь Slave -> Master
    output reg  [DATA_WIDTH-1:0] rx_byte,    // байт, прийнятий від Master
    output reg  [7:0]            bit_count   // кількість біт у кадрі
);

    reg [DATA_WIDTH-1:0] tx_sh;   // зсувний регістр відповіді
    reg [DATA_WIDTH-1:0] rx_sh;   // зсувний регістр прийому
    reg                  leading; // 1 - передній фронт SCK

    initial begin
        miso      = 1'bz;
        rx_byte   = 0;
        bit_count = 0;
    end

    // Початок кадру: Master опустив CS_N
    always @(negedge cs_n) begin
        tx_sh     = tx_byte;
        rx_sh     = 0;
        bit_count = 0;
        // CPHA = 0: перший біт має бути на лінії ще до першого фронту SCK
        // CPHA = 1: перший біт виставляється на передньому фронті
        miso = cpha ? 1'b0 : tx_byte[DATA_WIDTH-1];
    end

    // Кінець кадру: Master підняв CS_N - запам'ятовуємо прийнятий байт
    always @(posedge cs_n) begin
        miso    = 1'bz;
        rx_byte = rx_sh;
    end

    // Обробка кожного фронту SCK під час кадру
    always @(sclk) begin
        if (!cs_n) begin
            leading = (sclk != cpol);           // відхід від рівня спокою
            if (leading ^ cpha) begin
                // фронт фіксації: читаємо біт з MOSI
                rx_sh     = {rx_sh[DATA_WIDTH-2:0], mosi};
                bit_count = bit_count + 1;
            end else if (cpha) begin
                // CPHA = 1, передній фронт: видаємо черговий біт
                miso  = tx_sh[DATA_WIDTH-1];
                tx_sh = tx_sh << 1;
            end else begin
                // CPHA = 0, задній фронт: переходимо до наступного біта
                tx_sh = tx_sh << 1;
                miso  = tx_sh[DATA_WIDTH-1];
            end
        end
    end

endmodule
