module MMM #(
    parameter INW = 12,
    parameter OUTW = 32,
    parameter M = 7,
    parameter N = 9,
    parameter MAXK = 8,
    localparam K_BITS = $clog2(MAXK+1)
)(
    input clk,
    input reset,
    input [INW-1:0] INPUT_TDATA,
    input INPUT_TVALID,
    input [K_BITS:0] INPUT_TUSER,
    output INPUT_TREADY,
    output [OUTW-1:0] OUTPUT_TDATA,
    output OUTPUT_TVALID,
    input OUTPUT_TREADY
);
    // logics for counting read address in control logic
    logic [$clog2(M+1)-1:0] m;
    logic [$clog2(N+1)-1:0] n;
    logic [K_BITS-1:0] k; // i am not sure check

    logic clear_m, clear_n, clear_k;
    logic increment_k, increment_m, increment_n;
    
    // logical connections between input_mems and mac_pipe
    logic signed [INW-1:0] A_data_from_input_mems;
    logic signed [INW-1:0] B_data_from_input_mems;
     
    // logical connections between mac_pipe and fifo_out
    logic signed [OUTW-1:0]  output_from_mac;

    // logical connections between input_mems and control logic
    logic [$clog2(M*MAXK)-1:0] A_read_addr;
    logic [$clog2(MAXK*N)-1:0] B_read_addr;
    logic matrices_loaded;
    logic [K_BITS-1:0] K;
    logic compute_finished;
    
    // logical connections between mac_pipe and control logic
    logic clear_acc;
    logic valid_input;

    // logical connections between fifo_out and control logic
    logic wr_en_fifo;
    logic [($clog2(N+1))-1:0] capacity;

    // initialising FSM
    enum logic [1:0] {mmm_start, read_from_input_memory, store_in_fifo} state, next_state;
  
    always_comb begin
        if(reset) begin
            next_state = mmm_start;
            clear_acc = 1;
            valid_input = 0;
            wr_en_fifo = 0;
            compute_finished = 1;

            // A_read_addr = 'bx;
            // B_read_addr = 'bx;

            increment_k = 0;
            increment_m = 0;
            increment_n = 0;
            
            clear_m = 1;
            clear_n = 1;
            clear_k = 1;
        end
        else begin
            if(state == mmm_start) begin
                if(matrices_loaded == 1) begin
                    next_state = read_from_input_memory;
                    clear_m = 1;
                    clear_n = 1;
                    clear_k = 0;

                    increment_k = 1;
                    increment_m = 0;
                    increment_n = 0;

                    valid_input = 1;
                    wr_en_fifo = 0;
                    compute_finished = 0;
                    
                    // A_read_addr = 0;
                    // B_read_addr = 0;
                end
                else begin
                    next_state = mmm_start;
                    clear_m = 1;
                    clear_n = 1;
                    clear_k = 1;

                    increment_k = 0;
                    increment_m = 0;
                    increment_n = 0;
                    
                    valid_input = 0;
                    wr_en_fifo = 0;
                    compute_finished = 1;

                    // A_read_addr = 'bx;
                    // B_read_addr = 'bx;
                end
            end
            else if (state == read_from_input_memory) begin
                clear_acc = 0;
                compute_finished = 0;
                if(k<K) begin
                    valid_input = 1;
                    wr_en_fifo = 0;

                    clear_m = 0;
                    clear_n = 0;
                    clear_k = 0;

                    // A_read_addr = m*K + k;
                    // B_read_addr = k*N + n;

                    increment_k = 1;
                    increment_m = 0;
                    increment_n = 0;

                    next_state = read_from_input_memory;
                end
                else if(k==K) begin
                    // A_read_addr = 'bx;
                    // B_read_addr = 'bx;

                    increment_k = 1;
                    increment_m = 0;
                    increment_n = 0;

                    valid_input = 0;
                    wr_en_fifo = 0;

                    clear_m = 0;
                    clear_n = 0;
                    clear_k = 0;

                    next_state = read_from_input_memory;
                end
                else begin
                    // A_read_addr = 'bx;
                    // B_read_addr = 'bx;
                    increment_k = 0;
                    increment_m = 0;
                    increment_n = 0;

                    valid_input = 0;
                    wr_en_fifo = 0;

                    clear_m = 0;
                    clear_n = 0;
                    if(capacity != 0) begin
                        clear_k = 1;
                        next_state = store_in_fifo;
                    end
                    else begin
                        clear_k = 0;
                        next_state = read_from_input_memory;
                    end
                end
            end
            else if (state == store_in_fifo) begin
                compute_finished = 0;
                valid_input = 0;
                wr_en_fifo = 1;
                // A_read_addr = 'bx;
                // B_read_addr = 'bx;
                if(n<N) begin
                    increment_k = 0;
                    increment_m = 0;
                    increment_n = 1;

                    clear_m = 0;
                    clear_n = 0;
                    clear_k = 0;

                    next_state = read_from_input_memory;
                end
                else if(m<M) begin
                    increment_k = 0;
                    increment_m = 1;
                    increment_n = 0;

                    clear_m = 0;
                    clear_n = 1;
                    clear_k = 0;

                    next_state = read_from_input_memory;
                end
                else begin
                    // A_read_addr = m*K + k;
                    // B_read_addr = k*N + n;

                    increment_k = 0;
                    increment_m = 0;
                    increment_n = 0;

                    clear_m = 0;
                    clear_n = 0;
                    clear_k = 0;
                    
                    compute_finished = 1;
                    next_state = mmm_start;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            state <= mmm_start;
        end
        else begin
            state <= next_state;
        end
    end

    always_ff @(posedge clk) begin
        if(state == mmm_start) begin
            A_read_addr <= 0;
            B_read_addr <= 0;
        end
        else if(state == read_from_input_memory) begin
            A_read_addr <= m*K + k;
            B_read_addr <= k*N + n;
        end
    end
    
    // Instantiating input memories unit
    input_mems #(.INW(INW), .M(M), .N(N), .MAXK(MAXK)) input_memories_inst(
        .clk(clk),
        .reset(reset),
        .AXIS_TDATA(INPUT_TDATA),
        .AXIS_TVALID(INPUT_TVALID),
        .AXIS_TUSER(INPUT_TUSER),
        .AXIS_TREADY(INPUT_TREADY),
        .matrices_loaded(matrices_loaded),
        .compute_finished(compute_finished),
        .K(K),
        .A_read_addr(A_read_addr),
        .A_data(A_data_from_input_mems),
        .B_read_addr(B_read_addr),
        .B_data(B_data_from_input_mems)

    );

    //instantiating piplined mac unit
    mac_pipe #(.INW(INW), .OUTW(OUTW)) pipelined_mac_inst(
        .in0(A_data_from_input_mems),
        .in1(B_data_from_input_mems),
        .valid_input(valid_input),
        .clear_acc(clear_acc),
        .reset(reset),
        .clk(clk),
        .out(output_from_mac)
    );

    //instantiating output fifo unit
    fifo_out #(.OUTW(OUTW), .DEPTH(N)) output_fifo_inst(
        .clk(clk),
        .reset(reset),
        .data_in(output_from_mac),
        .wr_en(wr_en_fifo),
        .capacity(capacity),
        .AXIS_TDATA(OUTPUT_TDATA),
        .AXIS_TVALID(OUTPUT_TVALID),
        .AXIS_TREADY(OUTPUT_TREADY)
    );

    // instantiating counter for k
    incrementk #(.MAXK(MAXK)) counter_k_inst(
        .clk(clk),
        .reset(reset),
        .increment_k(increment_k),
        .clear_k(clear_k),
        .k(k)
    );

    //instantiating counter for m
    incrementm #(.M(M)) m_counter_inst(
        .clk(clk),
        .reset(reset),
        .increment_m(increment_m),
        .clear_m(clear_m),
        .m(m)
    );

    //instantiating counter for n
    incrementn #(.N(N)) n_counter_inst(
        .clk(clk),
        .reset(reset),
        .increment_n(increment_n),
        .clear_n(clear_n),
        .n(n)
    );

endmodule

// counter logic for K
module incrementk #(
    parameter MAXK = 8,
    localparam K_BITS = $clog2(MAXK+1)
)(
    input clk, reset,
    input logic increment_k,
    input logic clear_k,
    output logic [K_BITS-1:0] k // i am not sure check
);
    always_ff @(posedge clk) begin
        if(reset || clear_k) begin
            k <= 0;
        end
        else begin
            if(increment_k) begin
                k <= k + 1;
            end
        end
    end
endmodule

// counter logic for M
module incrementm #(
    parameter M = 7
)(
    input clk, reset,
    input logic increment_m,
    input logic clear_m,
    output logic [$clog2(M+1)-1:0] m
);
    always_ff @(posedge clk) begin
        if(reset || clear_m) begin
            m <= 0;
        end
        else begin
            if(increment_m) begin
                m <= m + 1;
            end
        end
    end
endmodule

// counter logic for N
module incrementn #(
    parameter N = 9
)(
    input clk, reset,
    input logic increment_n,
    input logic clear_n,
    output logic [$clog2(N+1)-1:0] n
);
    always_ff @(posedge clk) begin
        if(reset || clear_n) begin
            n <= 0;
        end
        else begin
            if(increment_n) begin
                n <= n + 1;
            end
        end
    end
endmodule

