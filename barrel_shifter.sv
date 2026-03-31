
module barrelshifter #(parameter D_SIZE = 8) (
  input  logic [D_SIZE-1:0]         x_in, // num to shift
  input  logic [$clog2(D_SIZE)-1:0] s_in, // shift ammount
  input  logic [2:0]                op_in,
  output logic [D_SIZE-1:0]         y_out,  // result of shift/rotate operation
  output logic                      zf_out, // zero flag: 1 if y_out == 0
  output logic                      vf_out  // overflow flag: 1 if SLA shifts 
);

    localparam DEPTH = $clog2(D_SIZE);
    localparam MUX_CNT_LAYER = D_SIZE;

    logic [D_SIZE-1:0] wires [DEPTH:0];
    assign wires[0] = x_in;

    logic isars, fill;
    is_ars ars_check (.op_in(op_in), .isars(isars));

    // Decide fill bit->> 0 for logical shifts, sign bit for arithmetic shift
    mux1 decide_fill (1'b0, x_in[D_SIZE-1], fill, isars);
    logic sign_bit;
    assign sign_bit = x_in[D_SIZE -1];

    logic [D_SIZE-2:0] shift_xors; // save xors for shifted bits (to set vf)
    genvar i, j;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin: layer
            localparam SHIFT_AMT = D_SIZE / (2 ** (i + 1));
            //-------------------- set ovrflow flag stuff
                for (j = 0; j < SHIFT_AMT; j= j+ 1) begin: overflow_check
                    logic result;
                    xor(result, sign_bit,wires[i][D_SIZE -2 -j]); // loop through val in reverse and xor shifted values (potentially shifted values.)
                    // we start at 2^(d-(i-1)-1) -> 2^(d-i)
                    // saving xord values
                    and(shift_xors[j+ (D_SIZE - D_SIZE / (2**i))], result, s_in[DEPTH - 1 - i] );
                end

                // --------------------
            for (j = 0; j < MUX_CNT_LAYER; j = j + 1) begin: row
                //TODO: ask how structural ithas to e (like anywhere i have to do structural that im not? -> like for basic operations and stuff? )
            
                logic right_shift, right_rot, right_final, left_shift, left_rot, left_final;
                
                wire b_val;
                //TODO: ask if this is okay or if this is behavioral cause >= is hard and i think this is all compile time stuff anyway
                // Left: shift (fill 0) vs rotate
                localparam LEFT_SHIFT_SIGNAL = (j >= SHIFT_AMT) ? 1 : 0;
                localparam RIGHT_SHIFT_SIGNAL = (j + SHIFT_AMT < D_SIZE) ? 1 : 0;

                assign left_rot = wires[i][(j - SHIFT_AMT + D_SIZE) % D_SIZE];
                logic left_fill_val;
                assign left_fill_val = wires[i][(j - SHIFT_AMT + D_SIZE) % D_SIZE]; // wrap incase neg
                mux1 left_shift_mux (.a(1'b0), .b(left_fill_val), .y(left_shift), .s(LEFT_SHIFT_SIGNAL));

                // right
                logic right_fill_val;
                assign right_fill_val = wires[i][(j + SHIFT_AMT) % D_SIZE]; // wrap incase oob
                assign right_rot = wires[i][(j + SHIFT_AMT) % D_SIZE];
                mux1 right_shift_mux (.a(fill), .b(right_fill_val), .y(right_shift), .s(RIGHT_SHIFT_SIGNAL));


                // Decide rotate or shift lefte (op_in[1] = rotate)
                mux1 left_mux (.a(left_shift), .b(left_rot), .y(left_final), .s(op_in[1]));

                // same but for right 
                mux1 right_mux (.a(right_shift), .b(right_rot), .y(right_final), .s(op_in[1]) );

                // Decide direction
                mux1 dir_mux (.a(right_final), .b(left_final), .y(b_val), .s(op_in[2]));

                // do the actual shifting. 
                mux1 shift_mux (
                    .a(wires[i][j]),
                    .b(b_val),
                    .y(wires[i+1][j]),
                    .s(s_in[DEPTH - i - 1])
                );
            end
        end

    endgenerate

    // Check if operation is SLA (needed for sign bit preservation and overflow flag)
    logic als;
    is_als als_check (.op_in(op_in), .isals(als));

    // make sure that we save msb ofr the arith left shift 
    logic msb_sign;
    // if als then first bit should be sign bit - special calse for als
    mux1 msb_select (.a(wires[DEPTH][D_SIZE-1]), .b(sign_bit), .y(msb_sign), .s(als));
    logic [D_SIZE-1:0] final_res;
    assign final_res[D_SIZE-2:0] = wires[DEPTH][D_SIZE-2:0];
    assign final_res[D_SIZE-1] = msb_sign;

    assign y_out = final_res;

    // Instantiate zero flag detector (use final_result which has correct sign bit)
    zero_flag_setter #(.D_SIZE(D_SIZE)) zero (.val(final_res), .zero_flag(zf_out));
    // Overflow detection module
    overflow_detector #(.D_SIZE(D_SIZE)) ovf_detect (
        .shift_xors(shift_xors),
        .als(als),
        .vf_out(vf_out)
    );
endmodule

// helper modules
// overflow detector module
module overflow_detector #(parameter D_SIZE) (
    input logic [D_SIZE-2:0] shift_xors,
    input logic als,
    output logic vf_out
);
    logic vf_result;
    logic vf_result_inv;
    logic [D_SIZE-1:0] shift_xors_padded;

    assign shift_xors_padded = {1'b0, shift_xors};
    // need to bpad here becuase zeroflag uses clog2(D_SIZE)
    zero_flag_setter #(.D_SIZE(D_SIZE)) overflow_check (.val(shift_xors_padded), .zero_flag(vf_result));
    
    not (vf_result_inv, vf_result); //  is 1 if overflow
    and (vf_out, als, vf_result_inv); // for als special case
endmodule

// module for 2:1 multiplexer a when 0, b when 1
module mux1(input a, input b, output y, input s);
    wire s_inv, one, two;
    not (s_inv, s);
    and(one, a, s_inv);
    and (two, b, s);
    or (y, one, two);
endmodule


// check if op is ars (001)
module is_ars (input  logic [2:0] op_in, output logic isars );
    wire op2_inv, op1_inv, temp_and;
    not(op2_inv, op_in[2]);
    not(op1_inv, op_in[1]);
    and(temp_and, op2_inv, op1_inv);
    and(isars, temp_and, op_in[0]);
endmodule
// check if op is als
module is_als (input  logic [2:0] op_in, output logic isals );
    wire one, op1_inv;
    and(one, op_in[2], op_in[0]);
    not(op1_inv, op_in[1]);
    and(isals, one, op1_inv);
endmodule

module zero_flag_setter #(parameter D_SIZE)(input [D_SIZE-1:0] val, output logic zero_flag);
    // log reduction tree from below commented version but modified for one vector.
    logic [2*D_SIZE-2:0] zfr;
    assign zfr[D_SIZE-1:0] = val;
    localparam TIMES = D_SIZE -1;
    genvar i;
    generate
        for (i = 0; i <  TIMES; i = i + 1) begin: one
            // every layer indep so should happ in parallel for each layer
            or(zfr[D_SIZE + i], zfr[i*2], zfr[i*2 + 1]);
        end
    endgenerate

    not(zero_flag, zfr[2*D_SIZE-2]);
endmodule