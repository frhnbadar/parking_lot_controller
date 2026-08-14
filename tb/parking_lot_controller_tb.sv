`timescale 1ns/1ps

//==============================================================
// Parking Lot Controller - SystemVerilog Testbench
// Author: Farhan
//
// Verification includes:
//   - Reset
//   - Occupancy calculation
//   - Entry transaction
//   - Exit transaction
//   - Full/empty behavior
//   - Illegal exit detection
//   - Simultaneous request arbitration
//   - Randomized occupancy testing
//   - SVA assertions
//   - Functional coverage
//==============================================================

module parking_lot_controller_tb;

    //==========================================================
    // Parameters
    //==========================================================

    localparam int NUM_SLOTS = 8;
    localparam int COUNT_W   = $clog2(NUM_SLOTS + 1);


    //==========================================================
    // DUT signals
    //==========================================================

    logic                     clk;
    logic                     rst;

    logic                     entry_request;
    logic                     exit_request;

    logic                     entry_sensor;
    logic                     exit_sensor;

    logic [NUM_SLOTS-1:0]     slot_occupied;

    logic                     entry_barrier;
    logic                     exit_barrier;

    logic [COUNT_W-1:0]       occupied_count;
    logic [COUNT_W-1:0]       available_slots;

    logic                     parking_full;
    logic                     parking_empty;

    logic [15:0]              entry_count;
    logic [15:0]              exit_count;

    logic                     illegal_exit;


    //==========================================================
    // DUT
    //==========================================================

    parking_lot_controller #(
        .NUM_SLOTS(NUM_SLOTS)
    ) dut (
        .clk             (clk),
        .rst             (rst),

        .entry_request   (entry_request),
        .exit_request    (exit_request),

        .entry_sensor    (entry_sensor),
        .exit_sensor     (exit_sensor),

        .slot_occupied   (slot_occupied),

        .entry_barrier   (entry_barrier),
        .exit_barrier    (exit_barrier),

        .occupied_count  (occupied_count),
        .available_slots (available_slots),

        .parking_full    (parking_full),
        .parking_empty   (parking_empty),

        .entry_count     (entry_count),
        .exit_count      (exit_count),

        .illegal_exit    (illegal_exit)
    );


    //==========================================================
    // CLOCK
    // 10 ns period
    //==========================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    //==========================================================
    // RESET TASK
    //==========================================================

    task automatic reset_dut;

        begin

            rst = 1'b1;

            entry_request = 1'b0;
            exit_request  = 1'b0;

            entry_sensor = 1'b0;
            exit_sensor  = 1'b0;

            slot_occupied = '0;

            repeat (2)
                @(posedge clk);

            rst = 1'b0;

            @(posedge clk);

        end

    endtask


    //==========================================================
    // STATUS CHECK TASK
    //
    // Independently calculates the expected occupancy.
    //==========================================================

    task automatic check_status(
        input logic [NUM_SLOTS-1:0] occupancy
    );

        int expected_count;

        begin

            slot_occupied = occupancy;

            expected_count = 0;

            for (int i = 0; i < NUM_SLOTS; i++) begin
                expected_count =
                    expected_count + occupancy[i];
            end

            #1;

            // Occupied count

            if (occupied_count !== expected_count) begin

                $error(
                    "OCCUPIED COUNT ERROR: occupancy=%b expected=%0d actual=%0d",
                    occupancy,
                    expected_count,
                    occupied_count
                );

            end
            else begin

                $display(
                    "[PASS] Occupied count = %0d",
                    occupied_count
                );

            end


            // Available slots

            if (available_slots !== (NUM_SLOTS - expected_count)) begin

                $error(
                    "AVAILABLE SLOT ERROR: expected=%0d actual=%0d",
                    NUM_SLOTS - expected_count,
                    available_slots
                );

            end


            // Full flag

            if (parking_full !== (expected_count == NUM_SLOTS)) begin

                $error(
                    "FULL FLAG ERROR: expected=%0b actual=%0b",
                    (expected_count == NUM_SLOTS),
                    parking_full
                );

            end


            // Empty flag

            if (parking_empty !== (expected_count == 0)) begin

                $error(
                    "EMPTY FLAG ERROR: expected=%0b actual=%0b",
                    (expected_count == 0),
                    parking_empty
                );

            end

        end

    endtask


    //==========================================================
    // TEST 1
    // RESET
    //==========================================================

    task automatic test_reset;

        begin

            $display("");
            $display("================================================");
            $display("TEST 1 : RESET");
            $display("================================================");

            reset_dut();

            #1;

            if (occupied_count !== 0)
                $error("Reset failed: occupied_count");

            if (available_slots !== NUM_SLOTS)
                $error("Reset failed: available_slots");

            if (parking_empty !== 1'b1)
                $error("Reset failed: parking_empty");

            if (parking_full !== 1'b0)
                $error("Reset failed: parking_full");

            if (entry_count !== 16'd0)
                $error("Reset failed: entry_count");

            if (exit_count !== 16'd0)
                $error("Reset failed: exit_count");

            if (illegal_exit !== 1'b0)
                $error("Reset failed: illegal_exit");

            if (entry_barrier !== 1'b0)
                $error("Reset failed: entry_barrier");

            if (exit_barrier !== 1'b0)
                $error("Reset failed: exit_barrier");

            $display("[PASS] Reset test");

        end

    endtask


    //==========================================================
    // TEST 2
    // OCCUPANCY COUNTING
    //==========================================================

    task automatic test_occupancy;

        begin

            $display("");
            $display("================================================");
            $display("TEST 2 : OCCUPANCY COUNTING");
            $display("================================================");

            check_status(8'b00000000);

            check_status(8'b00000001);

            check_status(8'b00000101);

            check_status(8'b10110100);

            check_status(8'b11110000);

            check_status(8'b11111111);

            $display("[PASS] Occupancy counting test");

        end

    endtask


    //==========================================================
    // TEST 3
    // NORMAL ENTRY
    //==========================================================

    task automatic test_entry;

        begin

            $display("");
            $display("================================================");
            $display("TEST 3 : NORMAL ENTRY");
            $display("================================================");

            // Three occupied slots

            slot_occupied = 8'b00000111;

            #1;

            // Request entry

            entry_request = 1'b1;

            @(posedge clk);

            entry_request = 1'b0;

            // State is now CHECK_ENTRY

            @(posedge clk);

            #1;

            // State should now be ENTRY_OPEN

            if (entry_barrier !== 1'b1) begin

                $error("Entry barrier did not open");

            end
            else begin

                $display("[PASS] Entry barrier opened");

            end


            // Vehicle reaches sensor

            entry_sensor = 1'b1;

            @(posedge clk);

            #1;

            if (entry_barrier !== 1'b1)
                $error("Entry barrier closed while vehicle detected");


            // Vehicle clears sensor

            entry_sensor = 1'b0;

            @(posedge clk);

            #1;

            if (entry_count !== 16'd1) begin

                $error(
                    "Entry count incorrect: expected=1 actual=%0d",
                    entry_count
                );

            end
            else begin

                $display("[PASS] Entry count incremented");

            end


            // Barrier should close

            @(posedge clk);

            #1;

            if (entry_barrier !== 1'b0)
                $error("Entry barrier did not close");

            $display("[PASS] Normal entry test");

        end

    endtask


    //==========================================================
    // TEST 4
    // NORMAL EXIT
    //==========================================================

    task automatic test_exit;

        begin

            $display("");
            $display("================================================");
            $display("TEST 4 : NORMAL EXIT");
            $display("================================================");

            // Four occupied slots

            slot_occupied = 8'b00001111;

            #1;

            // Request exit

            exit_request = 1'b1;

            @(posedge clk);

            exit_request = 1'b0;

            // State is now CHECK_EXIT

            @(posedge clk);

            #1;

            // State should now be EXIT_OPEN

            if (exit_barrier !== 1'b1) begin

                $error("Exit barrier did not open");

            end
            else begin

                $display("[PASS] Exit barrier opened");

            end


            // Vehicle reaches sensor

            exit_sensor = 1'b1;

            @(posedge clk);

            #1;

            if (exit_barrier !== 1'b1)
                $error("Exit barrier closed while vehicle detected");


            // Vehicle clears sensor

            exit_sensor = 1'b0;

            @(posedge clk);

            #1;

            if (exit_count !== 16'd1) begin

                $error(
                    "Exit count incorrect: expected=1 actual=%0d",
                    exit_count
                );

            end
            else begin

                $display("[PASS] Exit count incremented");

            end


            // Barrier should close

            @(posedge clk);

            #1;

            if (exit_barrier !== 1'b0)
                $error("Exit barrier did not close");

            $display("[PASS] Normal exit test");

        end

    endtask


    //==========================================================
    // TEST 5
    // FULL PARKING LOT
    //==========================================================

    task automatic test_full;

        begin

            $display("");
            $display("================================================");
            $display("TEST 5 : FULL PARKING LOT");
            $display("================================================");

            slot_occupied = 8'b11111111;

            #1;

            if (parking_full !== 1'b1)
                $error("Parking full flag is not asserted");

            if (available_slots !== 0)
                $error("Available slots should be zero");


            // Request entry while full

            entry_request = 1'b1;

            @(posedge clk);

            entry_request = 1'b0;

            // CHECK_ENTRY

            @(posedge clk);

            #1;

            if (entry_barrier !== 1'b0)
                $error("Entry barrier opened while lot was full");

            $display("[PASS] Full parking test");

        end

    endtask


    //==========================================================
    // TEST 6
    // EMPTY PARKING LOT
    //==========================================================

    task automatic test_empty;

        begin

            $display("");
            $display("================================================");
            $display("TEST 6 : EMPTY PARKING LOT");
            $display("================================================");

            slot_occupied = 8'b00000000;

            #1;

            if (parking_empty !== 1'b1)
                $error("Parking empty flag is not asserted");

            if (occupied_count !== 0)
                $error("Occupied count should be zero");

            if (available_slots !== NUM_SLOTS)
                $error("Available slots should equal NUM_SLOTS");

            $display("[PASS] Empty parking test");

        end

    endtask


    //==========================================================
    // TEST 7
    // ILLEGAL EXIT
    //==========================================================

    task automatic test_illegal_exit;

        begin

            $display("");
            $display("================================================");
            $display("TEST 7 : ILLEGAL EXIT");
            $display("================================================");

            slot_occupied = 8'b00000000;

            #1;

            exit_request = 1'b1;

            @(posedge clk);

            exit_request = 1'b0;

            // State is now CHECK_EXIT

            @(posedge clk);

            #1;

            // illegal_exit should have pulsed on this clock

            if (illegal_exit !== 1'b1) begin

                $error(
                    "Illegal exit was not detected"
                );

            end
            else begin

                $display("[PASS] Illegal exit detected");

            end


            if (exit_barrier !== 1'b0)
                $error("Exit barrier opened during illegal exit");

            $display("[PASS] Illegal exit test");

        end

    endtask


    //==========================================================
    // TEST 8
    // SIMULTANEOUS ENTRY + EXIT
    //
    // Policy:
    //
    //   Lot has space -> ENTRY wins
    //   Lot is full   -> EXIT wins
    //==========================================================

    task automatic test_simultaneous;

        begin

            $display("");
            $display("================================================");
            $display("TEST 8 : SIMULTANEOUS ENTRY + EXIT");
            $display("================================================");


            //==================================================
            // CASE A
            // Lot has space -> ENTRY wins
            //==================================================

            slot_occupied = 8'b00000111;

            #1;

            entry_request = 1'b1;
            exit_request  = 1'b1;

            @(posedge clk);

            entry_request = 1'b0;
            exit_request  = 1'b0;

            @(posedge clk);

            #1;

            if (entry_barrier !== 1'b1)
                $error("Entry should have priority when space exists");

            if (exit_barrier !== 1'b0)
                $error("Exit should not have priority when space exists");


            // Finish entry

            entry_sensor = 1'b1;

            @(posedge clk);

            entry_sensor = 1'b0;

            @(posedge clk);

            #1;


            //==================================================
            // CASE B
            // Lot full -> EXIT wins
            //==================================================

            slot_occupied = 8'b11111111;

            #1;

            entry_request = 1'b1;
            exit_request  = 1'b1;

            @(posedge clk);

            entry_request = 1'b0;
            exit_request  = 1'b0;

            @(posedge clk);

            #1;

            if (exit_barrier !== 1'b1)
                $error("Exit should have priority when lot is full");

            if (entry_barrier !== 1'b0)
                $error("Entry should not open when lot is full");


            // Finish exit

            exit_sensor = 1'b1;

            @(posedge clk);

            exit_sensor = 1'b0;

            @(posedge clk);

            #1;

            $display("[PASS] Simultaneous request test");

        end

    endtask


    //==========================================================
    // TEST 9
    // RANDOMIZED OCCUPANCY
    //==========================================================

    task automatic test_random_occupancy;

        logic [NUM_SLOTS-1:0] random_occupancy;

        int expected_count;

        begin

            $display("");
            $display("================================================");
            $display("TEST 9 : RANDOMIZED OCCUPANCY");
            $display("================================================");

            repeat (100) begin

                random_occupancy = $urandom;

                slot_occupied = random_occupancy;

                expected_count = 0;

                for (int i = 0; i < NUM_SLOTS; i++) begin

                    expected_count =
                        expected_count + random_occupancy[i];

                end

                #1;

                if (occupied_count !== expected_count) begin

                    $error(
                        "Random occupancy error: occupancy=%b expected=%0d actual=%0d",
                        random_occupancy,
                        expected_count,
                        occupied_count
                    );

                end


                if (available_slots !==
                    (NUM_SLOTS - expected_count)) begin

                    $error(
                        "Random available slot error: expected=%0d actual=%0d",
                        NUM_SLOTS - expected_count,
                        available_slots
                    );

                end


                if (parking_full !==
                    (expected_count == NUM_SLOTS)) begin

                    $error(
                        "Random full flag error: expected=%0b actual=%0b",
                        (expected_count == NUM_SLOTS),
                        parking_full
                    );

                end


                if (parking_empty !==
                    (expected_count == 0)) begin

                    $error(
                        "Random empty flag error: expected=%0b actual=%0b",
                        (expected_count == 0),
                        parking_empty
                    );

                end

            end

            $display("[PASS] 100 randomized occupancy tests");

        end

    endtask


    //==========================================================
    // SVA + FUNCTIONAL COVERAGE
    //
    // Enabled for simulators supporting SVA/covergroups.
    //
    // Compile with:
    //
    // +define+SIM_SUPPORTS_SVA
    //
    //==========================================================

`ifdef SIM_SUPPORTS_SVA


    //==========================================================
    // ASSERTION 1
    // FULL and EMPTY cannot both be true
    //==========================================================

    property p_full_empty_exclusive;

        @(posedge clk)
        !(parking_full && parking_empty);

    endproperty

    assert property (p_full_empty_exclusive)
        else $error(
            "ASSERTION FAILED: FULL and EMPTY both asserted"
        );


    //==========================================================
    // ASSERTION 2
    // FULL -> zero available slots
    //==========================================================

    property p_full_zero_available;

        @(posedge clk)
        parking_full |-> (available_slots == 0);

    endproperty

    assert property (p_full_zero_available)
        else $error(
            "ASSERTION FAILED: Full parking lot has available slots"
        );


    //==========================================================
    // ASSERTION 3
    // EMPTY -> zero occupied slots
    //==========================================================

    property p_empty_zero_occupied;

        @(posedge clk)
        parking_empty |-> (occupied_count == 0);

    endproperty

    assert property (p_empty_zero_occupied)
        else $error(
            "ASSERTION FAILED: Empty parking lot has occupied slots"
        );


    //==========================================================
    // ASSERTION 4
    // Both barriers must never be open simultaneously
    //==========================================================

    property p_barriers_exclusive;

        @(posedge clk)
        !(entry_barrier && exit_barrier);

    endproperty

    assert property (p_barriers_exclusive)
        else $error(
            "ASSERTION FAILED: Both barriers are open"
        );


    //==========================================================
    // ASSERTION 5
    // FULL -> entry barrier must remain closed
    //==========================================================

    property p_full_blocks_entry;

        @(posedge clk)
        parking_full |-> !entry_barrier;

    endproperty

    assert property (p_full_blocks_entry)
        else $error(
            "ASSERTION FAILED: Entry barrier opened while full"
        );


    //==========================================================
    // ASSERTION 6
    // EMPTY -> exit barrier must remain closed
    //==========================================================

    property p_empty_blocks_exit;

        @(posedge clk)
        parking_empty |-> !exit_barrier;

    endproperty

    assert property (p_empty_blocks_exit)
        else $error(
            "ASSERTION FAILED: Exit barrier opened while empty"
        );


    //==========================================================
    // FUNCTIONAL COVERAGE
    //==========================================================

    covergroup parking_coverage @(posedge clk);


        // Occupancy

        occupancy_cp : coverpoint occupied_count {

            bins occ_empty = {0};

            bins occ_low = {[1:2]};

            bins occ_mid = {[3:5]};

            bins occ_high = {[6:7]};

            bins occ_full = {NUM_SLOTS};

        }


        // Full status

        full_cp : coverpoint parking_full {

            bins lot_not_full = {0};

            bins lot_full = {1};

        }


        // Empty status

        empty_cp : coverpoint parking_empty {

            bins lot_not_empty = {0};

            bins lot_empty = {1};

        }


        // Entry barrier

        entry_barrier_cp : coverpoint entry_barrier {

            bins barrier_closed = {0};

            bins barrier_open = {1};

        }


        // Exit barrier

        exit_barrier_cp : coverpoint exit_barrier {

            bins barrier_closed = {0};

            bins barrier_open = {1};

        }


        // Entry request

        entry_request_cp : coverpoint entry_request {

            bins no_entry_request = {0};

            bins entry_requested = {1};

        }


        // Exit request

        exit_request_cp : coverpoint exit_request {

            bins no_exit_request = {0};

            bins exit_requested = {1};

        }


        // Entry sensor

        entry_sensor_cp : coverpoint entry_sensor {

            bins no_entry_vehicle = {0};

            bins entry_vehicle = {1};

        }


        // Exit sensor

        exit_sensor_cp : coverpoint exit_sensor {

            bins no_exit_vehicle = {0};

            bins exit_vehicle = {1};

        }


        // Entry/exit request combinations

        request_cross :
            cross entry_request_cp,
                  exit_request_cp;


        // Full/empty combinations

        status_cross :
            cross full_cp,
                  empty_cp;

    endgroup


    parking_coverage coverage = new();


`endif


    //==========================================================
    // TEST SEQUENCE
    //==========================================================

    initial begin

        $display("");
        $display("======================================================");
        $display("     PARKING LOT CONTROLLER VERIFICATION");
        $display("======================================================");


        // Initial values

        rst = 1'b0;

        entry_request = 1'b0;
        exit_request  = 1'b0;

        entry_sensor = 1'b0;
        exit_sensor  = 1'b0;

        slot_occupied = '0;


        // Run tests

        test_reset();

        test_occupancy();

        test_entry();

        test_exit();

        test_full();

        test_empty();

        test_illegal_exit();

        test_simultaneous();

        test_random_occupancy();


        // Allow final activity to settle

        #20;


        $display("");
        $display("======================================================");
        $display("          ALL TESTS COMPLETED");
        $display("======================================================");
        $display("");


        $finish;

    end


    //==========================================================
    // WAVEFORM DUMP
    //==========================================================

    initial begin

        $dumpfile("parking_lot_controller.vcd");

        $dumpvars(0, parking_lot_controller_tb);

    end


endmodule