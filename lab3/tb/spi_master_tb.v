// =========================================================================
// Модуль  : spi_master_tb (тестбенч)
// Проєкт  : ЛР3 АПКС, варіант 12 (SPI, Verilog), Кравченко В. А., КІ-405
// Опис    : Функціональна верифікація SPI Master.
//           Тестбенч імітує зовнішнє середовище:
//             1. генерує тактовий сигнал CLK (100 МГц) і скидання RST;
//             2. подає тестові байти на вхід передавача (tx_data);
//             3. підключає модель Slave, яка приймає байт з MOSI і
//                відповідає своїм байтом на MISO (перевірка приймача);
//             4. проганяє 4 режими SPI (CPOL/CPHA = 00, 01, 10, 11);
//             5. автоматично порівнює відправлене й прийняте і друкує
//                підсумок TEST PASSED / TEST FAILED.
// Запуск у Vivado: Run Behavioral Simulation, потім Run All (F3).
// =========================================================================
`timescale 1ns / 1ps

module spi_master_tb;

    // ---- параметри тесту ----
    localparam DATA_WIDTH = 8;
    localparam CLK_DIV    = 4;      // SCK = 100 МГц / 8 = 12,5 МГц
    localparam CLK_PERIOD = 10;     // 10 нс -> CLK = 100 МГц
    localparam N_VECTORS  = 5;      // тестових пар байтів на кожен режим

    // ---- сигнали, що подаються на Master ----
    reg                   clk     = 1'b0;
    reg                   rst     = 1'b1;
    reg                   start   = 1'b0;
    reg                   cpol    = 1'b0;
    reg                   cpha    = 1'b0;
    reg  [DATA_WIDTH-1:0] tx_data = 0;

    // ---- виходи Master ----
    wire [DATA_WIDTH-1:0] rx_data;
    wire                  rx_valid, busy, done;
    wire                  sclk, mosi, miso, cs_n;

    // ---- сигнали моделі Slave ----
    reg  [DATA_WIDTH-1:0] slave_tx = 0;   // що відповідає Slave
    wire [DATA_WIDTH-1:0] slave_rx;       // що прийняв Slave
    wire [7:0]            slave_bits;     // скільки біт прийняв Slave

    // ---- тестові вектори: {байт Master, байт Slave} ----
    reg [DATA_WIDTH-1:0] vec_m [0:N_VECTORS-1];
    reg [DATA_WIDTH-1:0] vec_s [0:N_VECTORS-1];
    initial begin
        vec_m[0] = 8'hA5; vec_s[0] = 8'h3C;   // чергування біт
        vec_m[1] = 8'h12; vec_s[1] = 8'hC3;   // 0x12 = варіант 12
        vec_m[2] = 8'hFF; vec_s[2] = 8'h00;   // усі одиниці / нулі
        vec_m[3] = 8'h00; vec_s[3] = 8'hFF;
        vec_m[4] = 8'h81; vec_s[4] = 8'h7E;   // крайні біти MSB і LSB
    end

    // ---- пристрій, що перевіряється (DUT) ----
    spi_master #(
        .DATA_WIDTH (DATA_WIDTH),
        .CLK_DIV    (CLK_DIV)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .cpol     (cpol),
        .cpha     (cpha),
        .tx_data  (tx_data),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .busy     (busy),
        .done     (done),
        .sclk     (sclk),
        .mosi     (mosi),
        .miso     (miso),
        .cs_n     (cs_n)
    );

    // ---- модель зовнішнього Slave ----
    spi_slave_model #(
        .DATA_WIDTH (DATA_WIDTH)
    ) slave (
        .sclk      (sclk),
        .cs_n      (cs_n),
        .mosi      (mosi),
        .miso      (miso),
        .cpol      (cpol),
        .cpha      (cpha),
        .tx_byte   (slave_tx),
        .rx_byte   (slave_rx),
        .bit_count (slave_bits)
    );

    // ---- генерація тактового сигналу ----
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---- фіксуємо байт, який прийняв Master (за імпульсом rx_valid) ----
    reg [DATA_WIDTH-1:0] master_got = 0;
    reg                  got_valid  = 1'b0;
    always @(posedge clk)
        if (rx_valid) begin
            master_got <= rx_data;
            got_valid  <= 1'b1;
        end

    // ---- лічильники результатів ----
    integer tests       = 0;
    integer errors      = 0;
    integer edge_errors = 0;
    integer mode, i;

    // ---- монітор: Master фіксує MISO саме на фронті фіксації режиму ----
    // Режими 0 і 3 - фіксація на зростаючому фронті SCK (0 -> 1),
    // режими 1 і 2 - на спадаючому (1 -> 0). У такті строба sample_tick
    // SCK ще має старе значення - воно має дорівнювати CPOL xor CPHA.
    always @(posedge clk)
        if (dut.u_tx.sample_tick && (sclk !== (cpol ^ cpha))) begin
            $display("  ERROR at %0t: wrong MISO sample edge", $time);
            edge_errors = edge_errors + 1;
        end

    // ---------------------------------------------------------------------
    // Задача: один кадр SPI з перевіркою обох напрямків
    // ---------------------------------------------------------------------
    task spi_transfer(input [DATA_WIDTH-1:0] m_byte,
                      input [DATA_WIDTH-1:0] s_byte);
        reg ok;
        begin
            slave_tx  = s_byte;
            got_valid = 1'b0;

            @(posedge clk);
            if (sclk !== cpol) begin          // перевірка рівня спокою SCK
                $display("  ERROR: idle SCK=%b, CPOL=%b", sclk, cpol);
                errors = errors + 1;
            end
            tx_data <= m_byte;                // байт і імпульс start
            start   <= 1'b1;
            @(posedge clk);
            start   <= 1'b0;

            @(posedge done);                  // чекаємо кінця кадру
            repeat (2) @(posedge clk);

            tests = tests + 1;
            ok = got_valid && (master_got == s_byte) &&
                 (slave_rx == m_byte) && (slave_bits == DATA_WIDTH);
            if (!ok) errors = errors + 1;

            // рядок звіту: відправлено -> прийнято в обох напрямках
            $write("  M->S: 0x%h -> 0x%h", m_byte, slave_rx);
            $write(" | S->M: 0x%h -> 0x%h", s_byte, master_got);
            if (ok) $display(" | bits=%0d | OK", slave_bits);
            else    $display(" | bits=%0d | FAIL", slave_bits);
        end
    endtask

    // ---------------------------------------------------------------------
    // Основний сценарій тесту
    // ---------------------------------------------------------------------
    initial begin
        $dumpfile("spi_master_tb.vcd");       // файл осцилограм (VCD)
        $dumpvars(0, spi_master_tb);

        $display("=== SPI Master testbench, variant 12 ===");
        $display("DATA_WIDTH=%0d, CLK_DIV=%0d", DATA_WIDTH, CLK_DIV);

        // скидання протягом 5 тактів
        rst = 1'b1;
        repeat (5) @(posedge clk);
        rst <= 1'b0;
        repeat (3) @(posedge clk);

        // перебір усіх режимів SPI: mode = {CPOL, CPHA}
        for (mode = 0; mode < 4; mode = mode + 1) begin
            cpol <= mode[1];
            cpha <= mode[0];
            repeat (4) @(posedge clk);        // SCK встановлюється в CPOL
            $display("MODE %0d (CPOL=%0d, CPHA=%0d):",
                     mode, mode[1], mode[0]);
            for (i = 0; i < N_VECTORS; i = i + 1)
                spi_transfer(vec_m[i], vec_s[i]);
        end

        // підсумок
        $display("Sample-edge check: %0d errors", edge_errors);
        if (errors == 0 && edge_errors == 0)
            $display("=== TEST PASSED: %0d/%0d transfers OK ===",
                     tests, tests);
        else
            $display("=== TEST FAILED: %0d data, %0d edge errors ===",
                     errors, edge_errors);

        repeat (10) @(posedge clk);
        $finish;
    end

endmodule
