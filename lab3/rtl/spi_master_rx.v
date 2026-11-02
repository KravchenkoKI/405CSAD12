// =========================================================================
// Модуль  : spi_master_rx
// Проєкт  : ЛР3 АПКС, варіант 12 (SPI, Verilog), Кравченко В. А., КІ-405
// Опис    : Приймач (Rx) SPI Master.
//           Фіксує біти з лінії MISO у моменти, які задає передавач
//           стробом sample_tick (фронт фіксації SCK), і збирає їх у
//           зсувному регістрі старшим бітом уперед. Після прийому
//           DATA_WIDTH біт видає байт на rx_data і імпульс rx_valid
//           тривалістю 1 такт.
//
// Логіка роботи:
//   1. frame_start (початок кадру) -> лічильник прийнятих біт = 0.
//   2. Кожен sample_tick -> зсув регістра вліво, у молодший біт
//      пишеться MISO, лічильник + 1.
//   3. Прийнято DATA_WIDTH біт -> rx_data = зібраний байт, rx_valid = 1.
// =========================================================================
`timescale 1ns / 1ps

module spi_master_rx #(
    parameter DATA_WIDTH = 8                 // кількість біт у кадрі
) (
    input  wire                  clk,         // системний тактовий сигнал
    input  wire                  rst,         // скидання, активний 1
    input  wire                  frame_start, // від Tx: почався новий кадр
    input  wire                  sample_tick, // від Tx: фіксувати MISO
    input  wire                  miso,        // лінія даних Slave -> Master
    output reg  [DATA_WIDTH-1:0] rx_data,     // прийнятий байт
    output reg                   rx_valid     // імпульс: байт готовий
);

    localparam BIT_W = $clog2(DATA_WIDTH + 1);

    reg [DATA_WIDTH-1:0] shreg;     // зсувний регістр приймача
    reg [BIT_W-1:0]      bit_cnt;   // кількість уже прийнятих біт

    // наступне значення регістра: зсув вліво + новий біт з MISO
    wire [DATA_WIDTH-1:0] shreg_next = {shreg[DATA_WIDTH-2:0], miso};

    always @(posedge clk) begin
        if (rst) begin
            shreg    <= 0;
            bit_cnt  <= 0;
            rx_data  <= 0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;                 // імпульс за замовчуванням 0

            if (frame_start) begin
                bit_cnt <= 0;                 // новий кадр - рахуємо з нуля
            end else if (sample_tick) begin
                shreg <= shreg_next;          // фіксуємо біт MISO
                if (bit_cnt == DATA_WIDTH - 1) begin
                    rx_data  <= shreg_next;   // останній біт - байт зібрано
                    rx_valid <= 1'b1;
                    bit_cnt  <= 0;
                end else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end
        end
    end

endmodule
