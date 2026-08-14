//==============================================================
// parking_lot_controller
// Author: Farhan
//
// FSM-based parking lot controller with entry/exit barrier
// arbitration, occupancy tracking, and basic statistics.
//==============================================================

module parking_lot_controller #(
    parameter int NUM_SLOTS = 8
)(
    input  logic                            clk,
    input  logic                            rst,

    // Requests
    input  logic                            entry_request,
    input  logic                            exit_request,

    // Vehicle-present sensors at each barrier
    input  logic                            entry_sensor,
    input  logic                            exit_sensor,

    // Per-slot occupancy (1 = occupied)
    input  logic [NUM_SLOTS-1:0]            slot_occupied,

    // Barrier outputs
    output logic                            entry_barrier,
    output logic                            exit_barrier,

    // Status
    output logic [$clog2(NUM_SLOTS+1)-1:0]  occupied_count,
    output logic [$clog2(NUM_SLOTS+1)-1:0]  available_slots,
    output logic                            parking_full,
    output logic                            parking_empty,

    // Statistics
    output logic [15:0]                     entry_count,
    output logic [15:0]                     exit_count,

    // Error flag: exit requested while lot is empty
    output logic                            illegal_exit
);

    localparam int COUNT_W = $clog2(NUM_SLOTS + 1);

    typedef enum logic [2:0] {
        IDLE,
        CHECK_ENTRY,
        ENTRY_OPEN,
        ENTRY_WAIT,
        CHECK_EXIT,
        EXIT_OPEN,
        EXIT_WAIT
    } state_t;

    state_t state, next_state;

    logic [COUNT_W-1:0] slot_count;


    //----------------------------------------------------------
    // Occupancy popcount + derived status
    //----------------------------------------------------------

    always_comb begin

        slot_count = '0;

        for (int i = 0; i < NUM_SLOTS; i++) begin
            slot_count = slot_count + slot_occupied[i];
        end

    end


    assign occupied_count  = slot_count;

    assign available_slots = COUNT_W'(NUM_SLOTS) - slot_count;

    assign parking_full    = (slot_count == NUM_SLOTS);

    assign parking_empty   = (slot_count == 0);


    //----------------------------------------------------------
    // Next-state logic
    //
    // Arbitration:
    //   - Both requests + lot full  -> EXIT
    //   - Both requests + space     -> ENTRY
    //----------------------------------------------------------

    always_comb begin

        next_state = state;

        case (state)

            IDLE: begin

                if (entry_request && exit_request) begin

                    if (parking_full)
                        next_state = CHECK_EXIT;
                    else
                        next_state = CHECK_ENTRY;

                end

                else if (entry_request) begin
                    next_state = CHECK_ENTRY;
                end

                else if (exit_request) begin
                    next_state = CHECK_EXIT;
                end

            end


            CHECK_ENTRY: begin

                if (parking_full)
                    next_state = IDLE;
                else
                    next_state = ENTRY_OPEN;

            end


            ENTRY_OPEN: begin

                if (entry_sensor)
                    next_state = ENTRY_WAIT;

            end


            ENTRY_WAIT: begin

                if (!entry_sensor)
                    next_state = IDLE;

            end


            CHECK_EXIT: begin

                if (parking_empty)
                    next_state = IDLE;
                else
                    next_state = EXIT_OPEN;

            end


            EXIT_OPEN: begin

                if (exit_sensor)
                    next_state = EXIT_WAIT;

            end


            EXIT_WAIT: begin

                if (!exit_sensor)
                    next_state = IDLE;

            end


            default:
                next_state = IDLE;

        endcase

    end


    //----------------------------------------------------------
    // State register
    //----------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst)
            state <= IDLE;
        else
            state <= next_state;

    end


    //----------------------------------------------------------
    // Barrier outputs
    //----------------------------------------------------------

    always_comb begin

        entry_barrier = 1'b0;
        exit_barrier  = 1'b0;

        case (state)

            ENTRY_OPEN,
            ENTRY_WAIT:
                entry_barrier = 1'b1;

            EXIT_OPEN,
            EXIT_WAIT:
                exit_barrier = 1'b1;

            default: begin
                entry_barrier = 1'b0;
                exit_barrier  = 1'b0;
            end

        endcase

    end


    //----------------------------------------------------------
    // Statistics + illegal-exit flag
    //
    // Entry/exit is counted when the vehicle clears the
    // corresponding sensor.
    //----------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            entry_count  <= 16'd0;
            exit_count   <= 16'd0;
            illegal_exit <= 1'b0;

        end

        else begin

            // Default: illegal_exit is a one-cycle pulse
            illegal_exit <= 1'b0;


            // Successful entry

            if ((state == ENTRY_WAIT) && !entry_sensor)
                entry_count <= entry_count + 16'd1;


            // Successful exit

            if ((state == EXIT_WAIT) && !exit_sensor)
                exit_count <= exit_count + 16'd1;


            // Illegal exit attempt

            if ((state == CHECK_EXIT) && parking_empty)
                illegal_exit <= 1'b1;

        end

    end

endmodule