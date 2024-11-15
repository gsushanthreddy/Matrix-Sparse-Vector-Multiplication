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
    integer A_ADDR_BITS = $clog2(M*MAXK);
    integer B_ADDR_BITS = $clog2(MAXK*N);
    integer m,
    integer n;
    integer k;

    logic [A_ADDR_BITS-1:0] A_read_addr;
    logic [B_ADDR_BITS-1:0] B_read_addr;
    logic matrices_loaded;
    logic clear_acc;
    logic valid_input;
    logic wr_en_fifo;
    logic compute_finished;


    enum logic {mmm_start, read_from_input_memory, store_in_fifo} state, next_state;
  
    always_comb begin
        if(reset) begin
           next_state = mmm_start;
           clear_acc = 1;
           valid_input = 0;
           wr_en_fifo = 0;
           compute_finished = 1;
        end
        else begin
            if(state == mmm_start) begin
                clear_m = 1;
                clear_n = 1;
                clear_k = 1;
                if(matrices_loaded == 1) begin
                    next_state = read_from_input_memory;
                end
                else begin
                    next_state = mmm_start;
                end
            end
            else if (state == read_from_input_memory) begin
                if(k<K) begin
                    A_read_addr = m*K + k;
                    B_read_addr = k*N + n;
                    increment_k = 1;
                    increment_m = 0;
                    increment_n = 0;
                    next_state = read_from_input_memory;
                end
                else begin
                    clear_k = 1;
                    next_state = store_in_fifo;
                end
            end
            else if (state == store_in_fifo) begin
                wr_en_fifo = 1;
                if(n<N) begin
                    increment_n = 1;
                    next_state = read_from_input_memory;
                end
                else if(m<M) begin
                    clear_n = 1;
                    increment_m = 1;
                    next_state = read_from_input_memory;
                end
                else begin
                    A_read_addr = m*K + k;
                    B_read_addr = k*N + n;
                    next_state = mmm_start;
                end
            end
        end
    end

    always_ff begin
        if(reset) begin
            state <= mmm_start;
        end
        else begin
            state <= next_state;
        end
    end

endmodule

module incrementk(
    input clk, reset;
    input logic increment_k;
    input logic clear_k;
    output logic k;
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

module incrementm(
    input clk, reset;
    input logic increment_m;
    input logic clear_m;
    output logic m;
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

module incrementn(
    input clk, reset;
    input logic increment_n;
    input logic clear_n;
    output logic n;
);
    always_ff @(posedge clk) begin
        if(reset || clear_n) begin
            n <= 0;
        end
        else begin
            if(increment_k) begin
                n <= n + 1;
            end
        end
    end
endmodule