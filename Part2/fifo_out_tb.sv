// ESE 507 Stony Brook University
// Peter Milder
// You may not redistribute this code.
// Testbench for fifo_out module


// To use this testbench:
// Compile it and your accompanying design with:
//  vlog -64 +acc fifo_out_tb.sv fifo_out.sv [and include any other design files]
//  vsim -64 -c fifo_out_tb -sv_seed random
// (add/adjust options as needed)
//       - If you want to run in GUI mode, remove -c

// Note that this testbench relies on params.sv, which can be generated 
// using the ./genParams2 script. See instructions in the project description.

// To compile:

`include "params.sv"

module fifo_out_tb();
    parameter OUTW=`OUTWVAL;    // the number of bits in each output 
    parameter DEPTH=`DEPTHVAL;  // the depth of the FIFO
    parameter TESTS=10000;      // the number of values to simulate 

    // The probability that the testbench attempts to write a value to the FIFO
    // and assert the output port's TREADY signal on any given cycle. 
    // You can adjust these values to simulate different scenarios.
    // Valid values for these parameters are 0.001 to 1. 
    // If a value is set to 0, then it will be randomized when you start
    // your simulation.
    parameter real WRITE_EN_PROB = `WRENPR;
    parameter real TREADY_PROB = `TRPR;
    
    logic clk, reset;

    initial clk=0;
    always #5 clk = ~clk;

    logic [OUTW-1:0] data_in, AXIS_TDATA;
    logic wr_en, AXIS_TVALID, AXIS_TREADY;
    logic [$clog2(DEPTH+1)-1:0] capacity;

    // Instance of the DUT we are simulating
    fifo_out #(OUTW, DEPTH) dut(clk, reset, data_in, wr_en, capacity, AXIS_TDATA, AXIS_TVALID, AXIS_TREADY);

    logic [9:0] write_prob, tready_prob;

    // If needed randomize the probability parameters
    initial begin
        if (WRITE_EN_PROB >= 0.001)
            write_prob = (1024*WRITE_EN_PROB-1);
        else
            write_prob = ($urandom % 1024);

        if (TREADY_PROB >= 0.001)
            tready_prob = (1024*TREADY_PROB-1);
        else
            tready_prob = ($urandom % 1024);

        $display("--------------------------------------------------------");
        $display("Starting simulation of output FIFO: %d tests", TESTS);
        $display("Number of bits: %d", OUTW);
        $display("FIFO Depth: %d", DEPTH);
        $display("WRITE_EN_PROB = %1.3f", real'(write_prob+1)/1024);
        $display("TREADY_PROB = %1.3f", real'(tready_prob+1)/1024);            
        $display("--------------------------------------------------------");
    end


    // randomize wr_en and AXIS_TREADY
    logic rb0, rb1;
    logic [9:0] randomNum;
    always begin
        @(posedge clk);
        #1;
        randomNum = $urandom;
        rb0 = (randomNum <= write_prob);
        randomNum = $urandom;
        rb1 = (randomNum <= tready_prob); 
    end

    // count the number of inputs loaded
    logic [31:0] in_count;
    initial in_count=0;
    always @(posedge clk) begin
        if (wr_en && (capacity!=0))
            in_count <= #1 in_count+1;
    end    

    // assign data_in and write based on random rb0
    always @* begin
        if ((in_count < TESTS) && (rb0 == 1) && ((capacity!=0))) begin
            wr_en = 1;
            data_in = in_count;
        end
        else begin
            wr_en = 0;
            data_in = 'bx;
        end
    end
        
    // assign the ready based on random rb1
    logic [OUTW-1:0] out_count;
    initial out_count=0;
    always @* begin
        if ((out_count >= 0) && (out_count < TESTS) && (rb1==1'b1))
            AXIS_TREADY = 1;
        else
            AXIS_TREADY = 0;
    end        

    integer errors=0;

    // count and check the number of outputs received
    always @(posedge clk) begin
        if (AXIS_TREADY && AXIS_TVALID) begin
                if (out_count[OUTW-1:0] === AXIS_TDATA)
                    $display($time,, "SUCCESS: out[%d] = %d", out_count, AXIS_TDATA);
                else begin
                    $display($time,, "ERROR:   out[%d] = %d; expected %d", out_count, AXIS_TDATA, out_count[OUTW-1:0]);
                    errors = errors+1;
                end
            out_count <= out_count+1;
        end
    end

    initial begin
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;

        wait(out_count==TESTS);
        #10;
        $display("Tested %d inputs. %d errors", TESTS, errors);
        $stop;
    end


endmodule
