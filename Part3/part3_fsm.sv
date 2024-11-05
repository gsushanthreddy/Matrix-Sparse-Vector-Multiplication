module fsm(
    input clk, reset,
    input AXIS_TVALID,
    input compute_finished,
    input new_A,
    input matrix_A_loaded,
    input matrix_B_loaded,

    output logic clear_counter_A,
    output logic clear_counter_B,
    output logic increment_counter_A,
    output logic increment_counter_B,
    output logic matrices_loaded,
    output logic wr_en_a,
    output logic wr_en_b,
    output logic AXIS_TREADY
);
    enum {start, load_a, load_b, read} state, next_state;

    always_comb begin
        clear_counter_A = 1;
        clear_counter_B = 1;
        increment_counter_A = 0;
        increment_counter_B = 0;
        matrices_loaded = 0;
        wr_en_a = 0;
        wr_en_b = 0;
        AXIS_TREADY = 1;

        if (state==start) begin
            if (AXIS_TVALID && AXIS_TREADY) begin
                if (new_A) begin
                    clear_counter_A = 0;
                    wr_en_a = 1;
                    next_state = load_a;
                end
                else begin
                    clear_counter_B = 0;
                    wr_en_b = 1;
                    next_state = load_b;
                end
            end 
            else begin
                next_state = start;
            end
        end
        else if (state==load_a) begin
            if (AXIS_TVALID) begin
                if (matrix_A_loaded==0) begin
                    clear_counter_A = 0;
                    increment_counter_A = 1;
                    wr_en_a = 1;
                    next_state = load_a;
                end
                else begin
                    clear_counter_B = 0;
                    increment_counter_B = 1;
                    wr_en_b = 1;
                    next_state = load_b;
                end
            end
            else begin
                clear_counter_A = 0;
                next_state = load_a;
            end
        end
        else if (state==load_b) begin
            if (AXIS_TVALID) begin
                if (matrix_B_loaded==0) begin
                    clear_counter_B = 0;
                    increment_counter_B = 1;
                    wr_en_b = 1;
                    next_state = load_b;
                end
                else begin
                    clear_counter_A = 0;
                    clear_counter_B = 0;
                    matrices_loaded = 1;
                    AXIS_TREADY = 0;
                    next_state = read;
                end
            end
            else begin
                clear_counter_B = 0;
                next_state = load_b;
            end
        end
        else if (state==read) begin
            if (compute_finished) begin
                next_state = start;
            end
            else begin
                clear_counter_A = 0;
                clear_counter_B = 0;
                matrices_loaded = 1;
                next_state = read;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            state <= start;
        end
        else begin
            state <= next_state;
        end
    end
endmodule