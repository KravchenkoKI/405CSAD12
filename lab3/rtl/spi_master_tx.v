// =========================================================================
// Модуль  : spi_master_tx
// Проєкт  : ЛР3 АПКС, варіант 12 (SPI, Verilog), Кравченко В. А., КІ-405
// Опис    : Передавач (Tx) SPI Master. Містить:
//             - дільник тактової частоти, що формує SCK із системного CLK;
//             - скінченний автомат (FSM), який керує кадром передачі;
//             - зсувний регістр, що видає біти на лінію MOSI (старшим бітом
//               уперед, MSB first);
//             - формування сигналу вибору пристрою CS_N (активний 0).
//           Також видає строб sample_tick для приймача (spi_master_rx), щоб
//           приймач знав, у який момент фіксувати біт із лінії MISO.
//
// Режими SPI задаються входами cpol/cpha (CPHA фіксується на старті):
//   CPOL - рівень SCK у стані спокою (0 - низький, 1 - високий).
//   CPHA - фаза: 0 - біт фіксується на першому (передньому) фронті SCK,
//                    а змінюється на другому (задньому);
//                1 - біт змінюється на передньому фронті,
//                    а фіксується на задньому.
//
// Частота SCK: f_SCK = f_CLK / (2 * CLK_DIV).
//   Наприклад, CLK = 100 МГц, CLK_DIV = 4  ->  SCK = 12,5 МГц.
// =========================================================================
`timescale 1ns / 1ps

module spi_master_tx #(
    parameter DATA_WIDTH = 8,   // кількість біт у кадрі
    parameter CLK_DIV    = 4    // тактів CLK на половину періоду SCK (>= 1)
) (
    // ---- системні сигнали ----
    input  wire                  clk,          // системний тактовий сигнал
    input  wire                  rst,          // скидання, активний 1
    // ---- керування від користувача ----
    input  wire                  start,        // імпульс: почати кадр
    input  wire                  cpol,         // полярність SCK (режим SPI)
    input  wire                  cpha,         // фаза SCK (режим SPI)
    input  wire [DATA_WIDTH-1:0] tx_data,      // байт для передачі
    output reg                   busy,         // 1 - йде передача кадру
    output reg                   done,         // імпульс: кадр завершено
    // ---- зв'язок із приймачем ----
    output wire                  sample_tick,  // строб: фіксувати MISO
    output reg                   frame_start,  // імпульс: початок кадру
    // ---- лінії інтерфейсу SPI ----
    output reg                   sclk,         // тактовий сигнал SPI (SCK)
    output reg                   mosi,         // дані Master -> Slave
    output reg                   cs_n          // вибір Slave, активний 0
);

    // ---------------------------------------------------------------------
    // Кодування станів FSM
    // ---------------------------------------------------------------------
    localparam [1:0] S_IDLE     = 2'd0,  // очікування команди start
                     S_SETUP    = 2'd1,  // CS_N = 0, пауза до 1-го фронту
                     S_TRANSFER = 2'd2,  // 2*DATA_WIDTH фронтів SCK
                     S_HOLD     = 2'd3;  // витримка після останнього фронту

    // Розрядності лічильників (захист від нульової ширини при CLK_DIV = 1)
    localparam CNT_W  = (CLK_DIV > 1) ? $clog2(CLK_DIV) : 1;
    localparam EDGE_W = $clog2(2 * DATA_WIDTH);
    localparam [EDGE_W-1:0] LAST_EDGE = 2 * DATA_WIDTH - 1;
    localparam [CNT_W-1:0]  CNT_MAX   = CLK_DIV - 1;

    // ---------------------------------------------------------------------
    // Внутрішні регістри
    // ---------------------------------------------------------------------
    reg [1:0]            state;     // поточний стан FSM
    reg [CNT_W-1:0]      clk_cnt;   // дільник: такти в півперіоді SCK
    reg [EDGE_W-1:0]     edge_cnt;  // номер фронту SCK у кадрі (0..2*DW-1)
    reg [DATA_WIDTH-1:0] shreg;     // зсувний регістр даних передавача
    reg                  cpha_r;    // CPHA, зафіксований на початку кадру

    // half_tick = 1 у такті, коли закінчується половина періоду SCK
    wire half_tick = (clk_cnt == CNT_MAX);

    // Парні фронти (0, 2, 4...) - передні, непарні - задні
    wire leading_edge = ~edge_cnt[0];

    // Фронт "зміни" даних, на якому на MOSI виставляється наступний біт:
    //   CPHA = 0 -> задні фронти (крім останнього);
    //   CPHA = 1 -> передні фронти (крім першого: MSB уже на лінії).
    wire shift_edge = cpha_r ? ( leading_edge && edge_cnt != 0)
                             : (!leading_edge && edge_cnt != LAST_EDGE);

    // Строб для приймача: у такті, коли формується фронт фіксації даних.
    //   CPHA = 0 -> фіксуємо на передньому фронті;
    //   CPHA = 1 -> фіксуємо на задньому фронті.
    // Приймач читає MISO в цьому ж такті, тобто рівно в момент фронту SCK.
    assign sample_tick = (state == S_TRANSFER) && half_tick &&
                         (leading_edge ^ cpha_r);

    // ---------------------------------------------------------------------
    // Основний автомат передавача
    // ---------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state       <= S_IDLE;
            clk_cnt     <= 0;
            edge_cnt    <= 0;
            shreg       <= 0;
            cpha_r      <= 1'b0;
            sclk        <= 1'b0;
            mosi        <= 1'b0;
            cs_n        <= 1'b1;
            busy        <= 1'b0;
            done        <= 1'b0;
            frame_start <= 1'b0;
        end else begin
            // імпульсні сигнали за замовчуванням тримаються в 0
            done        <= 1'b0;
            frame_start <= 1'b0;

            case (state)
            // -------------------------------------------------------------
            // IDLE: лінії в стані спокою, чекаємо start
            // -------------------------------------------------------------
            S_IDLE: begin
                sclk     <= cpol;      // SCK у спокої = CPOL
                cs_n     <= 1'b1;
                mosi     <= 1'b0;
                busy     <= 1'b0;
                clk_cnt  <= 0;
                edge_cnt <= 0;
                if (start) begin
                    cpha_r      <= cpha;              // фіксуємо фазу
                    shreg       <= tx_data;           // завантажуємо байт
                    mosi        <= tx_data[DATA_WIDTH-1]; // MSB на лінію
                    cs_n        <= 1'b0;              // вибираємо Slave
                    busy        <= 1'b1;
                    frame_start <= 1'b1;              // сигнал приймачу
                    state       <= S_SETUP;
                end
            end

            // -------------------------------------------------------------
            // SETUP: CS_N уже 0, MSB на MOSI; чекаємо півперіоду SCK,
            // щоб Slave встиг підготуватися (час t_lead)
            // -------------------------------------------------------------
            S_SETUP: begin
                if (half_tick) begin
                    clk_cnt <= 0;
                    state   <= S_TRANSFER;
                end else begin
                    clk_cnt <= clk_cnt + 1'b1;
                end
            end

            // -------------------------------------------------------------
            // TRANSFER: кожні CLK_DIV тактів перемикаємо SCK.
            // За кадр - 2*DATA_WIDTH фронтів (по 2 на кожен біт).
            // -------------------------------------------------------------
            S_TRANSFER: begin
                if (half_tick) begin
                    clk_cnt  <= 0;
                    sclk     <= ~sclk;               // формуємо фронт SCK
                    edge_cnt <= edge_cnt + 1'b1;

                    // на фронті зміни - наступний біт на MOSI
                    if (shift_edge) begin
                        shreg <= {shreg[DATA_WIDTH-2:0], 1'b0};
                        mosi  <= shreg[DATA_WIDTH-2];
                    end

                    if (edge_cnt == LAST_EDGE)       // останній фронт кадру
                        state <= S_HOLD;
                end else begin
                    clk_cnt <= clk_cnt + 1'b1;
                end
            end

            // -------------------------------------------------------------
            // HOLD: SCK уже повернувся в стан спокою; чекаємо півперіоду
            // (час t_lag) і знімаємо CS_N, кадр завершено
            // -------------------------------------------------------------
            S_HOLD: begin
                if (half_tick) begin
                    clk_cnt <= 0;
                    cs_n    <= 1'b1;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    state   <= S_IDLE;
                end else begin
                    clk_cnt <= clk_cnt + 1'b1;
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule
