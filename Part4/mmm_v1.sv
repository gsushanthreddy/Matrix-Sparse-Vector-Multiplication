module matrix_multiplication #(parameter M = 4, N = 4, K = 4) (
    input logic clk,
    input logic rst_n,
    input logic [31:0] A_mem [0:M*K-1],
    input logic [31:0] B_mem [0:K*N-1],
    output logic [31:0] fifo_data_out
);

    logic [31:0] accumulator_reg;
    integer m, n, k;
    logic [1:0] state;
    
    // FIFO signals
    logic fifo_wr_en;
    logic [31:0] fifo_data_in;
    logic fifo_full, fifo_empty;
    
    localparam IDLE = 2'b00, CALCULATE = 2'b01, STORE = 2'b10;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            m <= 0;
            n <= 0;
            k <= 0;
            accumulator_reg <= 0;
            fifo_wr_en <= 0;
        end else begin
            case (state)
                IDLE: begin
                    m <= 0;
                    n <= 0;
                    k <= 0;
                    accumulator_reg <= 0;
                    fifo_wr_en <= 0;
                    state <= CALCULATE;
                end
                
                CALCULATE: begin
                    if (k < K) begin
                        accumulator_reg <= accumulator_reg + (A_mem[m*K + k] * B_mem[k*N + n]);
                        k <= k + 1;
                    end else begin
                        fifo_data_in <= accumulator_reg;
                        state <= STORE;
                        k <= 0;
                    end
                end
                
                STORE: begin
                    if (!fifo_full) begin
                        fifo_wr_en <= 1;
                        fifo_data_in <= accumulator_reg;
                        fifo_wr_en <= 0;
                        accumulator_reg <= 0;
                        if (n < N-1) begin
                            n <= n + 1;
                        end else if (m < M-1) begin
                            n <= 0;
                            m <= m + 1;
                        end else begin
                            state <= IDLE; // Reset to IDLE or any other logic to handle completion
                        end
                    end
                end
            endcase
        end
    end

    fifo my_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(fifo_wr_en),
        .data_in(fifo_data_in),
        .data_out(fifo_data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

endmodule