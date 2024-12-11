// ESE 507 Stony Brook University
// Peter Milder
// You may not redistribute this code.
// Testbench for MMM module

// To use this testbench:

// Compile it and your accompanying design with:
//   vlog -64 +acc test_helper.c MMM.sv [add your other .sv files to simulate here]
//   vsim -64 -c MMM_tb -sv_seed random 
//      [options]:
//       - If you want to run in GUI mode, remove -c

// Note that this testbench relies on params.sv, which can be generated 
// using the ./genParams4 script. See instructions in the project description.


// Import the C function (in test_helper.c) that computes the output matrix given the input matrices.
import "DPI-C" function void calcOutput(input int matrixA[], input int matrixB[],input int M, input int N, input int K, output longint outmat[], input int OUTW);


// A class to hold one instance of test data and its expected output. When we call 
// .randomize() on an object of this class, it will randomly generate values for the 
// matrices, the value of K, and the value of new_A.
// This class also has two functions force_new_A() and allow_old_A().
// These functions will generate random input values. The difference between 
// these is that force_new_A() will always set new_A=1 while allow_old_A() will 
// randomly pick whether to use the old A matrix or create a new one.
class testdata #(parameter INW=8, parameter OUTW=32, parameter M=18, parameter N=15, parameter MAXK=18);
    
    // The value of K
    rand logic [$clog2(MAXK+1)-1:0] K;

    // This constraint means when we randomize an object of this class, it will
    // choose the value of K to be between 1 and MAXK, with
    // equal probability of each number
    constraint c {K dist {[2:MAXK] := 1};}

    // an M x MAXK matrix
    // we will only use K columns of this
    rand int matrixA[M*MAXK];   
    
    // a MAXK x N matrix
    // we will only use K rows of this
    rand int matrixB[MAXK*N];
    
    // These constraints will ensure that the matrix values follow K and that 
    // they fit within INW bits
    constraint m1 {
        if (INW < 32) {
            foreach(matrixA[i]) {
                if (i < M*K) {
                    matrixA[i] < (1<<(INW-1));
                    matrixA[i] >= -1*(1<<(INW-1));
                }
                else {
                    matrixA[i] == 0;
                }
            }
        }
    }

    constraint m2 {
        if (INW < 32) {
            foreach(matrixB[i]) {
                if (i < N*K) {
                    matrixB[i] < (1<<(INW-1));
                    matrixB[i] >= -1*(1<<(INW-1));
                }            
                else {
                    matrixB[i] == 0;
                } 
            }
        }
    }

    // new_A==0 means this test will use the previous A matrix; new_A==1 means this
    // test will load a new inputA matrix.
    rand logic new_A;    

    // The expected output vector of this MMM calculation
    longint output_matrix[M*N];

    // This will randomize K and the input matrices, forcing new_A to 1. It will 
    // then calculated the expected output.
    function void force_new_A();
        // randomize matrixA, matrixB, K, and new_A
        assert(this.randomize());   

        // force new_A to 1
        this.new_A = 1;       

        // calculate the expected result and store in this.output_matrix
        calcOutput(this.matrixA, this.matrixB, M, N, this.K, this.output_matrix, OUTW);

    endfunction


    // This will randomly choose new_A. If it is 1, it will generate a new
    // random A matrix. If it is 0, it will copy the old matrix from olddata.
    // Then it will generate a new matrixB and compute the expected output.
    function void allow_old_A(testdata #(INW, OUTW, M, N, MAXK) olddata);
        // randomize 
        assert(this.randomize());

        // if the random new_A is 0, then we will copy the previous matrixA
        // and K from old_data
        if (this.new_A == 0) begin
            this.matrixA = olddata.matrixA;
            this.K = olddata.K;
        end

        // calculate the expected result and store in this.output_matrix     
        calcOutput(this.matrixA, this.matrixB, M, N, this.K, this.output_matrix, OUTW);

    endfunction

endclass

`include "params.sv"

module MMM_tb();

    parameter TESTS = 10000;    // the number of MVMs to test
    parameter INW   = `INWVAL;  // INW is the size of each matrix entry
    parameter OUTW  = `OUTWVAL; // OUTW is the size of each output

    // We require 2 <= INW < 32 and 4 <= OUTW <= 64.
    // OUTW must also be large enough to prevent the accumulator from overflowing.
    // (If the accumulator overflows, the testbench will warn you when it computes
    // the expected result.)
    
    parameter M=`MVAL;        // M is the number of rows in the A matrix
    parameter N=`NVAL;        // N is the number of cols in the B matrix
    parameter MAXK=`MAXKVAL;  // MAXK is the maximum number of cols in A/rows in B
    

    // The probability that the testbench asserts INPUT_TVALID=1 and OUTPUT_TREADY
    // on any given cycle.
    // You can adjust these values to simulate different scenarios.
    // Valid values for these parameters are 0.001 to 1. 
    // If a value is set to 0, then it will be randomized when you start
    // your simulation.
    parameter real INPUT_TVALID_PROB = `TVPR;
    parameter real OUTPUT_TREADY_PROB = `TRPR;

    localparam K_BITS = $clog2(MAXK+1); // the number of bits needed for K

    //localparam LOGN      = $clog2(N);
    //localparam LOGMN     = $clog2(M*N);

    logic clk, reset;
    
    // Signals for the DUT's AXI-Stream input interface
    logic signed [INW-1:0] INPUT_TDATA;
    logic INPUT_TVALID;

    // AXIS_TUSER[K_BITS:1] is the value of K during the first matrix entry
    // AXIS_TUSER[0] is the new_A signal during the first matrix entry  
    logic [K_BITS:0] INPUT_TUSER; 
    logic INPUT_TREADY;   
    
    // Signals for the DUT's AXI-Stream output interface
    logic signed [OUTW-1:0] OUTPUT_TDATA;
    logic                   OUTPUT_TVALID;
    logic                   OUTPUT_TREADY;

    initial clk=0;
    always #5 clk = ~clk;

    // Instantiate the DUT
    MMM #(INW, OUTW, M, N, MAXK) dut(clk, reset, INPUT_TDATA, INPUT_TVALID, INPUT_TUSER, INPUT_TREADY, OUTPUT_TDATA, OUTPUT_TVALID, OUTPUT_TREADY);

    // This is an array of "testdata" objects. (See definition of the testdata class above.)
    // It will will hold all of our test data. Each "testdata" object holds data for one MMM operation test case.
    // It holds a set of inputs (matrixA, matrixB, K, new_A) and the corresponding expected output. 
    testdata #(INW, OUTW, M, N, MAXK) td[TESTS];

    // generate random bits to use when randomizing INPUT_TVALID and OUTPUT_TREADY
    logic rb0, rb1;
    logic [9:0] randomNum;
    logic [9:0] tvalid_prob, tready_prob;

    initial begin
        if (INPUT_TVALID_PROB >= 0.001)
            tvalid_prob = (1024*INPUT_TVALID_PROB-1);
        else
            tvalid_prob = ($urandom % 1024);

        if (OUTPUT_TREADY_PROB >= 0.001)
            tready_prob = (1024*OUTPUT_TREADY_PROB-1);
        else
            tready_prob = ($urandom % 1024);

        $display("--------------------------------------------------------");
        $display("Starting top-level simulation: %d tests", TESTS);
        $display("M x N: %d x %d", M, N);
        $display("MAXK:  %d", MAXK);
        $display("Input %d bits\nOutput: %d bits", INW, OUTW);

        $display("INPUT_TVALID_PROB = %1.3f", real'(tvalid_prob+1)/1024);
        $display("OUTPUT_TREADY_PROB = %1.3f", real'(tready_prob+1)/1024);            
        $display("--------------------------------------------------------");
    end

    // Every clock cycle, randomly generate rb0 and rb1 for the INPUT_TVALID and
    // OUTPUT_TREADY signals, respectively
    always begin
        @(posedge clk);
        #1;
        randomNum = $urandom;
        rb0 = (randomNum <= tvalid_prob);
        randomNum = $urandom;
        rb1 = (randomNum <= tready_prob);
    end

    // Logic to keep track of where we are in the test data.
    // which_test keeps track of which of the TESTS test cases we are operating on
    // which_element keeps track of which matrix value within this test case we
    // are sending.
    logic [31:0] which_test, which_element; 
    initial which_test=0; 
    initial which_element=0;
    always @(posedge clk) begin
        if (INPUT_TVALID && INPUT_TREADY) begin
            if (which_element == M*td[which_test].K + N*td[which_test].K-1) begin // if we just finished loading this test...
                which_test <= #1 which_test+1;   // increment to next test

                // if we are not at the last test input:
                if (which_test < TESTS-1) begin
                    // if the next test has a new_A, set the counter back to 0
                    if (td[which_test+1].new_A == 1) begin
                        which_element <= #1 0;
                    end
                    else begin // if doesn't have a new_A, set the counter to the vector location
                        which_element <= #1 M*td[which_test+1].K;
                    end
                end

            end
            else begin   // or if we are in the middle of a test, just increment
                which_element <= #1 which_element+1;
            end        
        end
    end

    // Logic to set INPUT_TVALID based on random value rb0.
    always @* begin
        // If we haven't finished all of our test inputs and the random bit rb0 is 1,
        if ((which_test < TESTS) && (rb0==1'b1))
            INPUT_TVALID=1;
        else
            INPUT_TVALID=0;
    end

    // Logic to set the value of INPUT_TDATA based on the random input value and the 
    // which_element and which_test variables
    always @(INPUT_TVALID or which_element or which_test) begin
        INPUT_TDATA = 'x;
         if (INPUT_TVALID == 1) begin
            if (which_element < M*td[which_test].K) begin  // we are loading the matrix
                INPUT_TDATA = td[which_test].matrixA[which_element];
            end
            else begin // we are loading matrixB
                INPUT_TDATA = td[which_test].matrixB[which_element-M*td[which_test].K];
            end            
        end
    end    

    // Logic to set the value of INPUT_TUSER based on the random input value and the 
    // which_element and which_test variables
    always @(INPUT_TVALID or which_element or which_test) begin
        INPUT_TUSER = 'x;
         if (INPUT_TVALID == 1) begin
            if ((td[which_test].new_A == 1) && (which_element == 0))
                INPUT_TUSER = {td[which_test].K, 1'b1};
            else if ((td[which_test].new_A == 0) && (which_element == M*td[which_test].K))
                INPUT_TUSER = {td[which_test].K, 1'b0};
        end
    end    

    // generate our test input data and expected output data
    initial begin        
        td[0]=new();
        td[0].force_new_A(); // the first test needs a new_A

        for (int i=1; i<TESTS; i++) begin
            td[i]=new();
            td[i].allow_old_A(td[i-1]);     
        end
    end

    // Logic to set OUTPUT_TREADY based on random value rb1
    logic [31:0] which_test_out, which_element_out; 
    always @* begin
        if ((which_test_out < TESTS) && (rb1==1'b1))
            OUTPUT_TREADY = 1;
        else
            OUTPUT_TREADY = 0;
    end

    
    integer errors = 0;
    initial which_test_out = 0;
    initial which_element_out = 0;

    integer cycle_count=0;

    // Logic to check the outputs and keep track of which output test you are checking
    always @(posedge clk) begin
        if (OUTPUT_TVALID && OUTPUT_TREADY) begin 
            if (OUTPUT_TDATA !== td[which_test_out].output_matrix[which_element_out]) begin
                $display($time,,"ERROR: Test %d, y[%d] = %d; expected value = %d", which_test_out, which_element_out, OUTPUT_TDATA, td[which_test_out].output_matrix[which_element_out]);        
                errors = errors+1;
            end
            if (which_element_out == N*M-1) begin
                which_element_out = 0;
                which_test_out = which_test_out+1;
            end 
            else begin
                which_element_out = which_element_out+1;
            end
        end
    end

    // Logic to count cycles, used in our throughput testing
    always @(posedge clk) begin

        // reset the cycle_counter on the first element of the first input
        if (INPUT_TVALID && INPUT_TREADY && (which_test==0) && (which_element==0))
            cycle_count <= 0;    
        else
            cycle_count <= cycle_count+1;

    end

    // Logic to assert reset at the beginning, then wait until all tests are done,
    // print the results, and then quit the simulation.
    initial begin
        reset = 1;        
        @(posedge clk); #1; reset = 0; 

        wait(which_test_out == TESTS);
        $display("Simulated %d tests, with a total of %d output values. Detected %d errors.", TESTS, TESTS*N*M, errors);
        $display("Your system computed %d MMMs in %d cycles --> %e MMMs per cycle", TESTS, cycle_count, real'(TESTS)/(real'(cycle_count)));
        #1;
        $finish;
    end
  

endmodule


