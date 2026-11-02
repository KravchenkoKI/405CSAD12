// =========================================================================
// Модуль  : spi_master (верхній рівень)
// Проєкт  : ЛР3 АПКС, варіант 12 (SPI, Verilog), Кравченко В. А., КІ-405
// Опис    : SPI Master, що об'єднує передавач spi_master_tx і приймач
//           spi_master_rx. Передача повнодуплексна: за один кадр Master
//           видає байт tx_data на MOSI і одночасно приймає байт з MISO.
//
// Як користуватися:
//   1. Виставити tx_data, cpol, cpha.
//   2. Подати start = 1 на один такт (коли busy = 0).
//   3. Дочекатися done = 1 (кадр завершено); прийнятий байт - на rx_data,
//      його готовність позначає імпульс rx_valid.
// =========================================================================
`timescale 1ns / 1ps

module spi_master #(
    parameter DATA_WIDTH = 8,   // кількість біт у кадрі
    parameter CLK_DIV    = 4    // f_SCK = f_CLK / (2 * CLK_DIV)
) (
    // ---- системні сигнали ----
    input  wire                  clk,
    input  wire                  rst,
    // ---- інтерфейс користувача ----
    input  wire                  start,
    input  wire                  cpol,
    input  wire                  cpha,
    input  wire [DATA_WIDTH-1:0] tx_data,
    output wire [DATA_WIDTH-1:0] rx_data,
    output wire                  rx_valid,
    output wire                  busy,
    output wire                  done,
    // ---- лінії SPI ----
    output wire                  sclk,
    output wire                  mosi,
    input  wire                  miso,
    output wire                  cs_n
);

    // внутрішні сигнали зв'язку Tx -> Rx
    wire sample_tick;
    wire frame_start;

    // ---- передавач: FSM, дільник частоти, SCK, MOSI, CS_N ----
    spi_master_tx #(
        .DATA_WIDTH (DATA_WIDTH),
        .CLK_DIV    (CLK_DIV)
    ) u_tx (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .cpol        (cpol),
        .cpha        (cpha),
        .tx_data     (tx_data),
        .busy        (busy),
        .done        (done),
        .sample_tick (sample_tick),
        .frame_start (frame_start),
        .sclk        (sclk),
        .mosi        (mosi),
        .cs_n        (cs_n)
    );

    // ---- приймач: фіксація MISO і збирання байта ----
    spi_master_rx #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_rx (
        .clk         (clk),
        .rst         (rst),
        .frame_start (frame_start),
        .sample_tick (sample_tick),
        .miso        (miso),
        .rx_data     (rx_data),
        .rx_valid    (rx_valid)
    );

endmodule
