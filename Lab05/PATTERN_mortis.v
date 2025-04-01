`define CYCLE_TIME 20.0
`define PATTERN_LENGTH 2
`define SEED 25
`define DEBUG 1

//############################################################################
//   _,.---._       _,.---._      
// 	,-.' - ,  `.   ,-.' - ,  `.    
//  /==/ ,    -  \ /==/ ,    -  \   
// |==| - .=.  ,  |==| - .=.  ,  |  
// |==|  : ;=:  - |==|  : ;=:  - |  
// |==|,  '='  ,  |==|,  '='  ,  |  
//  \==\ _   -    ;\==\ _   -    ;  
// 	'.='.  ,  ; -\ '.='.  ,  ; -\  
// 		`--`--'' `--`  `--`--'' `--` 
//############################################################################

module PATTERN (
    clk,
    rst_n,
    in_valid,
    in_valid2,
    in_data,
    out_valid,
    out_sad
);
  output reg clk, rst_n, in_valid, in_valid2;
  output reg [11:0] in_data;
  input out_valid;
  input out_sad;

  //======================================
  //      PARAMETERS & VARIABLES
  //======================================
  reg [ 9*8:1] reset_color = "\033[1;0m";
  reg [10*8:1] txt_black_prefix = "\033[1;30m";
  reg [10*8:1] txt_red_prefix = "\033[1;31m";
  reg [10*8:1] txt_green_prefix = "\033[1;32m";
  reg [10*8:1] txt_yellow_prefix = "\033[1;33m";
  reg [10*8:1] txt_blue_prefix = "\033[1;34m";

  reg [10*8:1] bkg_black_prefix = "\033[40;1m";
  reg [10*8:1] bkg_red_prefix = "\033[41;1m";
  reg [10*8:1] bkg_green_prefix = "\033[42;1m";
  reg [10*8:1] bkg_yellow_prefix = "\033[43;1m";
  reg [10*8:1] bkg_blue_prefix = "\033[44;1m";
  reg [10*8:1] bkg_white_prefix = "\033[47;1m";

  reg [ 4*8:1] _line1 = "____";
  reg [ 4*8:1] _space1 = "    ";
  reg [ 9*8:1] _line2 = "_________";
  reg [ 9*8:1] _space2 = "         ";

  integer i_pat, i_set;
  real CYCLE = `CYCLE_TIME;
  real PATNUM = `PATTERN_LENGTH;
  integer SEED = `SEED;
  integer DEBUG = `DEBUG;
  integer total_latency, latency;

  integer file;


  reg [7:0] _L0[0:127][0:127], _L1[0:127][0:127];
  reg [11:0] _MV0_L0[0:1];  // point 1 x, y
  reg [11:0] _MV0_L1[0:1];  // point 1 x, y
  reg [11:0] _MV1_L0[0:1];  // point 2 x, y
  reg [11:0] _MV1_L1[0:1];  // point 2 x, y

  parameter MATRIX_SIZE = 10;
  reg [11:0] _A1_L0[0:1][0:MATRIX_SIZE][0:MATRIX_SIZE-1];  // L0
  reg [11:0] _A1_L1[0:1][0:MATRIX_SIZE][0:MATRIX_SIZE-1];  // L1
  reg [11:0] _A2_L0[0:1][0:MATRIX_SIZE][0:MATRIX_SIZE-1];
  reg [11:0] _A2_L1[0:1][0:MATRIX_SIZE][0:MATRIX_SIZE-1];

  reg [15:0] _BI_L0[0:1][0:9][0:9];
  reg [15:0] _BI_L1[0:1][0:9][0:9];

  reg [23:0] _sad0[0:8];
  reg [23:0] _sad1[0:8];

  reg [27:0] _sad0_golden;
  reg [27:0] _sad1_golden;

  parameter NUM_BI = 11;

  //======================================
  //              MAIN
  //======================================
  // Start Pattern
  initial begin
    total_latency = 0;
    rst_n = 1'b1;
    force clk = 0;
    reset_signal_task;
    total_latency = 0;
    #CYCLE;
    release clk;

    @(negedge clk);
    for (i_pat = 0; i_pat < PATNUM; i_pat = i_pat + 1) begin
      randomize_input_pat;
      input_task_pat;
      for (i_set = 0; i_set < 64; i_set = i_set + 1) begin
        randomize_input_set;
        if (DEBUG) begin
          dump_input;
        end
        cal_ans_task;
        if (DEBUG) begin
          dump_output;
        end
        input_task_set;
        wait_out_valid_task;
        check_ans;
        $display("%0sPASS PATTERN NO.%4d SET NO.%2d, %0sCycles: %3d%0s", txt_blue_prefix, i_pat,
                 i_set, txt_green_prefix, latency, reset_color);
      end
    end
    YOU_PASS_TASK;
  end

  //======================================
  //              Clock
  //======================================
  always #(CYCLE / 2.0) clk = ~clk;
  initial clk = 0;
  //======================================
  //              TASKS
  //======================================
  task cal_ans_task;
    integer i, j, k;
    reg [11:0] _A1;  // intermediate up
    reg [11:0] _A2;  // intermediate down
    reg [11:0] _p1_00, _p1_01, _p1_10, _p1_11;  // point 1 value
    reg [11:0] _p2_00, _p2_01, _p2_10, _p2_11;  // point 2 value
    begin
      for (i = 0; i < 11; i = i + 1) begin  // BI L0  Point1
        for (j = 0; j < 10; j = j + 1) begin
          _p1_00 = _L0[_MV0_L0[1][11:4]+i][_MV0_L0[0][11:4]+j];
          _p1_01 = _L0[_MV0_L0[1][11:4]+i][_MV0_L0[0][11:4]+j+1];
          _p1_10 = _L0[_MV0_L0[1][11:4]+i+1][_MV0_L0[0][11:4]+j];
          _p1_11 = _L0[_MV0_L0[1][11:4]+i+1][_MV0_L0[0][11:4]+j+1];

          _p2_00 = _L1[_MV0_L1[1][11:4]+i][_MV0_L1[0][11:4]+j];
          _p2_01 = _L1[_MV0_L1[1][11:4]+i][_MV0_L1[0][11:4]+j+1];
          _p2_10 = _L1[_MV0_L1[1][11:4]+i+1][_MV0_L1[0][11:4]+j];
          _p2_11 = _L1[_MV0_L1[1][11:4]+i+1][_MV0_L1[0][11:4]+j+1];

          _A1_L0[0][i][j] = _p1_00 * 16 + _MV0_L0[0][3:0] * (_p1_01 - _p1_00);
          _A2_L0[0][i][j] = _p1_10 * 16 + _MV0_L0[0][3:0] * (_p1_11 - _p1_10);
          _BI_L0[0][i][j] = _A1_L0[0][i][j] * 16 + _MV0_L0[1][3:0] * (_A2_L0[0][i][j] - _A1_L0[0][i][j]);  // BI L0  Point1


          _A1_L1[0][i][j] = _p2_00 * 16 + _MV0_L1[0][3:0] * (_p2_01 - _p2_00);
          _A2_L1[0][i][j] = _p2_10 * 16 + _MV0_L1[0][3:0] * (_p2_11 - _p2_10);
          _BI_L1[0][i][j] = _A1_L1[0][i][j] * 16 + _MV0_L1[1][3:0] * (_A2_L1[0][i][j] - _A1_L1[0][i][j]);  // BI L1  Point1
        end
      end
      for (i = 0; i < 11; i = i + 1) begin  // BI L1  Point1
        for (j = 0; j < 10; j = j + 1) begin
          _p1_00 = _L0[_MV1_L0[1][11:4]+i][_MV1_L0[0][11:4]+j];
          _p1_01 = _L0[_MV1_L0[1][11:4]+i][_MV1_L0[0][11:4]+j+1];
          _p1_10 = _L0[_MV1_L0[1][11:4]+i+1][_MV1_L0[0][11:4]+j];
          _p1_11 = _L0[_MV1_L0[1][11:4]+i+1][_MV1_L0[0][11:4]+j+1];

          _p2_00 = _L1[_MV1_L1[1][11:4]+i][_MV1_L1[0][11:4]+j];
          _p2_01 = _L1[_MV1_L1[1][11:4]+i][_MV1_L1[0][11:4]+j+1];
          _p2_10 = _L1[_MV1_L1[1][11:4]+i+1][_MV1_L1[0][11:4]+j];
          _p2_11 = _L1[_MV1_L1[1][11:4]+i+1][_MV1_L1[0][11:4]+j+1];

          _A1_L0[1][i][j] = _p1_00 * 16 + _MV1_L0[0][3:0] * (_p1_01 - _p1_00);
          _A2_L0[1][i][j] = _p1_10 * 16 + _MV1_L0[0][3:0] * (_p1_11 - _p1_10);
          _BI_L0[1][i][j] = _A1_L0[1][i][j] * 16 + _MV1_L0[1][3:0] * (_A2_L0[1][i][j] - _A1_L0[1][i][j]);  // BI L0  Point2

          _A1_L1[1][i][j] = _p2_00 * 16 + _MV1_L1[0][3:0] * (_p2_01 - _p2_00);
          _A2_L1[1][i][j] = _p2_10 * 16 + _MV1_L1[0][3:0] * (_p2_11 - _p2_10);
          _BI_L1[1][i][j] = _A1_L1[1][i][j] * 16 + _MV1_L1[1][3:0] * (_A2_L1[1][i][j] - _A1_L1[1][i][j]);  // BI L1  Point2
        end
      end

      for (i = 0; i < 9; i = i + 1) begin
        _sad0[i] = 0;
        _sad1[i] = 0;
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[0] = _sad0[0] + abs(_BI_L0[0][j][k], _BI_L1[0][j+2][k+2]);  // Point1
          _sad1[0] = _sad1[0] + abs(_BI_L0[1][j][k], _BI_L1[1][j+2][k+2]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[1] = _sad0[1] + abs(_BI_L0[0][j+1][k], _BI_L1[0][j+1][k+2]);  // Point1
          _sad1[1] = _sad1[1] + abs(_BI_L0[1][j+1][k], _BI_L1[1][j+1][k+2]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[2] = _sad0[2] + abs(_BI_L0[0][j+2][k], _BI_L1[0][j][k+2]);  // Point1
          _sad1[2] = _sad1[2] + abs(_BI_L0[1][j+2][k], _BI_L1[1][j][k+2]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[3] = _sad0[3] + abs(_BI_L0[0][j][k+1], _BI_L1[0][j+2][k+1]);  // Point1
          _sad1[3] = _sad1[3] + abs(_BI_L0[1][j][k+1], _BI_L1[1][j+2][k+1]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[4] = _sad0[4] + abs(_BI_L0[0][j+1][k+1], _BI_L1[0][j+1][k+1]);  // Point1
          _sad1[4] = _sad1[4] + abs(_BI_L0[1][j+1][k+1], _BI_L1[1][j+1][k+1]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[5] = _sad0[5] + abs(_BI_L0[0][j+2][k+1], _BI_L1[0][j][k+1]);  // Point1
          _sad1[5] = _sad1[5] + abs(_BI_L0[1][j+2][k+1], _BI_L1[1][j][k+1]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[6] = _sad0[6] + abs(_BI_L0[0][j][k+2], _BI_L1[0][j+2][k]);  // Point1
          _sad1[6] = _sad1[6] + abs(_BI_L0[1][j][k+2], _BI_L1[1][j+2][k]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[7] = _sad0[7] + abs(_BI_L0[0][j+1][k+2], _BI_L1[0][j+1][k]);  // Point1
          _sad1[7] = _sad1[7] + abs(_BI_L0[1][j+1][k+2], _BI_L1[1][j+1][k]);  // Point2
        end
      end

      for (j = 0; j < 8; j = j + 1) begin
        for (k = 0; k < 8; k = k + 1) begin
          _sad0[8] = _sad0[8] + abs(_BI_L0[0][j+2][k+2], _BI_L1[0][j][k]);  // Point1
          _sad1[8] = _sad1[8] + abs(_BI_L0[1][j+2][k+2], _BI_L1[1][j][k]);  // Point2
        end
      end

      _sad0_golden = {
        max_8_idx(
            _sad0[0], _sad0[1], _sad0[2], _sad0[3], _sad0[4], _sad0[5], _sad0[6], _sad0[7], _sad0[8]
        ),
        max_8(
            _sad0[0], _sad0[1], _sad0[2], _sad0[3], _sad0[4], _sad0[5], _sad0[6], _sad0[7], _sad0[8]
        )
      };
      _sad1_golden = {
        max_8_idx(
            _sad1[0], _sad1[1], _sad1[2], _sad1[3], _sad1[4], _sad1[5], _sad1[6], _sad1[7], _sad1[8]
        ),
        max_8(
            _sad1[0], _sad1[1], _sad1[2], _sad1[3], _sad1[4], _sad1[5], _sad1[6], _sad1[7], _sad1[8]
        )
      };
    end
  endtask

  function [15:0] abs;
    input [15:0] A, B;
    begin
      abs = (A > B) ? A - B : B - A;
    end
  endfunction

  function [23:0] max_8;
    input [23:0] a, b, c, d, e, f, g, h, i;
    reg [23:0] min;
    begin
      min = {24{1'b1}};
      if (a < min) min = a;
      if (b < min) min = b;
      if (c < min) min = c;
      if (d < min) min = d;
      if (e < min) min = e;
      if (f < min) min = f;
      if (g < min) min = g;
      if (h < min) min = h;
      if (i < min) min = i;
      max_8 = min;  // Return the maximum value
    end
  endfunction

  function [3:0] max_8_idx;
    input [23:0] a, b, c, d, e, f, g, h, i;
    reg [23:0] min;
    reg [ 3:0] idx;
    begin
      min = {24{1'b1}};
      if (a < min) begin
        min = a;
        idx = 0;
      end
      if (b < min) begin
        min = b;
        idx = 1;
      end
      if (c < min) begin
        min = c;
        idx = 2;
      end
      if (d < min) begin
        min = d;
        idx = 3;
      end
      if (e < min) begin
        min = e;
        idx = 4;
      end
      if (f < min) begin
        min = f;
        idx = 5;
      end
      if (g < min) begin
        min = g;
        idx = 6;
      end
      if (h < min) begin
        min = h;
        idx = 7;
      end
      if (i < min) begin
        min = i;
        idx = 8;
      end
      max_8_idx = idx;  // Return the maximum value
    end
  endfunction



  task input_task_set;
    begin
      in_valid2 = 0;
      // in_valid2 should come in 3~6 cycles after in_valid or out_valid falls
      repeat ({$random(SEED)} % 4 + 2) @(negedge clk);

      in_valid2 = 1;
      in_data   = _MV0_L0[0];  // point 1 x L0
      @(negedge clk);
      in_data = _MV0_L0[1];  // point 1 y L0
      @(negedge clk);
      in_data = _MV0_L1[0];  // point 1 x L1
      @(negedge clk);
      in_data = _MV0_L1[1];  // point 1 y L1
      @(negedge clk);


      in_data = _MV1_L0[0];  // point 2 x L0
      @(negedge clk);
      in_data = _MV1_L0[1];  // point 2 y L0
      @(negedge clk);
      in_data = _MV1_L1[0];  // point 2 x L1
      @(negedge clk);
      in_data = _MV1_L1[1];  // point 2 y L1
      @(negedge clk);

      in_valid2 = 0;
      in_data   = 12'bx;
    end
  endtask

  task input_task_pat;
    integer i;
    integer j;
    begin
      in_valid = 0;

      // in_valid should come in 3~6 cycles after in_valid or out_valid falls
      repeat ({$random(SEED)} % 4 + 2) @(negedge clk);
      for (i = 0; i < 128; i = i + 1) begin
        for (j = 0; j < 128; j = j + 1) begin
          in_data[11:4] = _L0[i][j];
          in_valid = 1;
          @(negedge clk);
        end
      end
      for (i = 0; i < 128; i = i + 1) begin
        for (j = 0; j < 128; j = j + 1) begin
          in_data[11:4] = _L1[i][j];
          in_valid = 1;
          @(negedge clk);
        end
      end
      in_valid = 0;
      in_data  = 12'bx;
    end
  endtask


  task randomize_input_pat;
    integer _row;
    integer _col;
    begin
      // L0 and L2
      for (_row = 0; _row < 128; _row = _row + 1) begin
        for (_col = 0; _col < 128; _col = _col + 1) begin
          _L0[_row][_col] = {$random(SEED)} % 128;
          _L1[_row][_col] = {$random(SEED)} % 128;
        end
      end
    end
  endtask

  task randomize_input_set;
    integer _row;
    integer _col;
    integer rand1;
    integer rand2;
    integer tmp1;
    integer tmp2;
    integer p1;
    integer p2;
    begin
      // L0 and L2
      for (_row = 0; _row < 2; _row = _row + 1) begin
        _MV0_L0[_row][11:4] = {$random(SEED)} % 118;  // point1 L0
        _MV0_L1[_row][11:4] = {$random(SEED)} % 118;  // point1 L1

        rand1 = {$random(SEED)} % 6;
        rand2 = {$random(SEED)} % 6;

        p1 = {$random(SEED)} % 2;
        p2 = {$random(SEED)} % 2;

        tmp1 = (p1) ? _MV0_L0[_row][11:4] + rand1 : _MV0_L0[_row][11:4] - rand1;
        tmp2 = (p2) ? _MV0_L1[_row][11:4] + rand2 : _MV0_L1[_row][11:4] - rand2;

        _MV1_L0[_row][11:4] = (tmp1 < 0) ? tmp1 + 10 : (tmp1 > 117) ? tmp1 - 10 : tmp1; // point2 L0
        _MV1_L1[_row][11:4] = (tmp2 < 0) ? tmp2 + 10 : (tmp2 > 117) ? tmp2 - 10 : tmp2; // point2 L1

        _MV0_L0[_row][3:0] = {$random(SEED)} % 16;
        _MV0_L1[_row][3:0] = {$random(SEED)} % 16;
        _MV1_L0[_row][3:0] = {$random(SEED)} % 16;
        _MV1_L1[_row][3:0] = {$random(SEED)} % 16;
      end
    end
  endtask

  task dump_input;
    integer _channel;
    integer col_idx;
    integer row_idx;
    begin
      file = $fopen("../00_TESTBED/input.txt", "w");
      $fwrite(file, "[PAT NO. %4d]\n", i_pat);
      $fwrite(file, "[SET NO. %4d]\n\n\n", i_set);

      // ======================================================================================
      $fwrite(file, "\n");
      $fwrite(file, "[========]\n");
      $fwrite(file, "[ Point1 ]\n");
      $fwrite(file, "[========]\n\n");


      $fwrite(file, "\n");
      $fwrite(file, "[========]\n");
      $fwrite(file, "[ L0, L1 ]\n");
      $fwrite(file, "[========]\n\n");

      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) $fwrite(file, "%3d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) $fwrite(file, "%0s", "____");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < NUM_BI; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) begin
          $fwrite(file, "%3d ", _L0[_MV0_L0[1][11:4]+row_idx][_MV0_L0[0][11:4]+col_idx]);
        end
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) begin
          $fwrite(file, "%3d ", _L1[_MV0_L1[1][11:4]+row_idx][_MV0_L1[0][11:4]+col_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      // reg [11:0] _MV0_L0[0:1];  // point 1 x, y
      // reg [11:0] _MV0_L1[0:1];  // point 1 x, y
      // reg [11:0] _MV1_L0[0:1];  // point 2 x, y
      // reg [11:0] _MV1_L1[0:1];  // point 2 x, y

      $fwrite(file, "\n");
      $fwrite(file, "[====================]\n");
      $fwrite(file, "[ MV L0 L1 of point 1]\n");
      $fwrite(file, "[====================]\n\n");

      $fwrite(file, "[%0d] ", row_idx);
      $fwrite(file, "%5s %5s", "y", "x");


      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < 2; col_idx = col_idx + 1) $fwrite(file, "%0s", "______");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      $fwrite(file, "%2d|", 0);
      $fwrite(file, "( %4h, %4h )", _MV0_L0[1], _MV0_L0[0]);
      $fwrite(file, "\n");
      $fwrite(file, "%2d|", 1);
      $fwrite(file, "( %4h, %4h )", _MV0_L1[1], _MV0_L1[0]);
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "%2d|", 0);
      $fwrite(file, "( %4d, %4d )", _MV0_L0[1][11:4], _MV0_L0[0][11:4]);
      $fwrite(file, "\n");
      $fwrite(file, "%2d|", 1);
      $fwrite(file, "( %4d, %4d )", _MV0_L1[1][11:4], _MV0_L1[0][11:4]);
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "\n");

      //=================================================================================================

      $fwrite(
          file,
          "===========================================================================================================================\n");
      $fwrite(file, "[========]\n");
      $fwrite(file, "[ Point2 ]\n");
      $fwrite(file, "[========]\n\n");

      $fwrite(file, "\n");
      $fwrite(file, "[========]\n");
      $fwrite(file, "[ L0, L1 ]\n");
      $fwrite(file, "[========]\n\n");

      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) $fwrite(file, "%3d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) $fwrite(file, "%0s", "____");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < NUM_BI; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) begin
          $fwrite(file, "%3d ", _L0[_MV1_L0[1][11:4]+row_idx][_MV1_L0[0][11:4]+col_idx]);
        end
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI; col_idx = col_idx + 1) begin
          $fwrite(file, "%3d ", _L1[_MV1_L1[1][11:4]+row_idx][_MV1_L1[0][11:4]+col_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "[====================]\n");
      $fwrite(file, "[ MV L0 L1 of point 2]\n");
      $fwrite(file, "[====================]\n\n");

      $fwrite(file, "[%0d] ", row_idx);
      $fwrite(file, "%5s %5s", "y", "x");


      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < 2; col_idx = col_idx + 1) $fwrite(file, "%0s", "______");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      $fwrite(file, "%2d|", 0);
      $fwrite(file, "( %4h, %4h )", _MV1_L0[1], _MV1_L0[0]);
      $fwrite(file, "\n");
      $fwrite(file, "%2d|", 1);
      $fwrite(file, "( %4h, %4h )", _MV1_L1[1], _MV1_L1[0]);
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "%2d|", 0);
      $fwrite(file, "( %4d, %4d )", _MV1_L0[1][11:4], _MV1_L0[0][11:4]);
      $fwrite(file, "\n");
      $fwrite(file, "%2d|", 1);
      $fwrite(file, "( %4d, %4d )", _MV1_L1[1][11:4], _MV1_L1[0][11:4]);
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "\n");
    end
  endtask

  task dump_output;
    integer _channel;
    integer col_idx;
    integer row_idx;
    begin
      file = $fopen("../00_TESTBED/output.txt", "w");
      $fwrite(file, "[PAT NO. %4d]\n", i_pat);
      $fwrite(file, "[SET NO. %4d]\n\n\n", i_set);

      // ======================================================================================
      // $fwrite(file, "\n");
      // $fwrite(file, "[========]\n");
      // $fwrite(file, "[ Point1 ]\n");
      // $fwrite(file, "[========]\n\n");

      $fwrite(file, "\n");
      $fwrite(file, "[=======]\n");
      $fwrite(file, "[ A1(2) P1]\n");
      $fwrite(file, "[=======]\n\n");

      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%4d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%0s", "_____");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < NUM_BI; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _A1_L0[0][row_idx][col_idx]);
        end
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _A1_L1[0][row_idx][col_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");


      $fwrite(file, "\n");
      $fwrite(file, "[=======]\n");
      $fwrite(file, "[ A1(2) P2]\n");
      $fwrite(file, "[=======]\n\n");

      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%4d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%0s", "_____");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < NUM_BI; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _A1_L0[1][row_idx][col_idx]);
        end
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _A1_L1[1][row_idx][col_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "[==============]\n");
      $fwrite(file, "[ BI_L0, BI_L1 P1]\n");
      $fwrite(file, "[==============]\n\n");

      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%4d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%0s", "_____");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < NUM_BI - 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _BI_L0[0][row_idx][col_idx]);
        end
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _BI_L1[0][row_idx][col_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "[==============]\n");
      $fwrite(file, "[ BI_L0, BI_L1 P2]\n");
      $fwrite(file, "[==============]\n\n");

      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%4d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 2; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1)
          $fwrite(file, "%0s", "_____");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < NUM_BI - 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _BI_L0[1][row_idx][col_idx]);
        end
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < NUM_BI - 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%4h ", _BI_L1[1][row_idx][col_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "[======]\n");
      $fwrite(file, "[ sad0 ]\n");
      $fwrite(file, "[======]\n\n");

      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%6d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%0s", "_______");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < 9; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%6h ", _sad0[row_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "[======]\n");
      $fwrite(file, "[ sad1 ]\n");
      $fwrite(file, "[======]\n\n");

      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%6d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%0s", "_______");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < 9; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%6h ", _sad1[row_idx]);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "[========]\n");
      $fwrite(file, "[ MAX  1 ]\n");
      $fwrite(file, "[========]\n\n");

      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%7d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%0s", "________");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%7h ", _sad0_golden);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");

      $fwrite(file, "\n");
      $fwrite(file, "[========]\n");
      $fwrite(file, "[ MAX  2 ]\n");
      $fwrite(file, "[========]\n\n");

      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "[%0d] ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%7d ", col_idx);
      end
      $fwrite(file, "%0s", _space1);
      $fwrite(file, "\n");
      // _________________
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%0s", "________");
      end

      $fwrite(file, "\n");
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < 1; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%7h ", _sad1_golden);
        end
        $fwrite(file, "%0s", _space1);
        $fwrite(file, "\n");
      end
      $fwrite(file, "\n");
      $fwrite(file, "\n");
    end

    //=================================================================================================

  endtask


  task reset_signal_task;
    begin
      #CYCLE;
      rst_n = 1'b1;
      #CYCLE;
      rst_n = 1'b0;

      // input
      in_valid = 1'b0;
      in_valid2 = 1'b0;
      in_data = 12'bx;
      #CYCLE;
      rst_n = 1'b1;

      // rest of signals
      if (out_valid !== 1'b0 || out_sad !== 1'b0) begin
        $display("\033[31m");
        $display("**************************************************");
        $display("                    SPEC-8 FAIL                   ");
        $display("  All output signals should be 0 at the beginning ");
        $display("**************************************************");
        $display("\033[0m");
        $finish;
      end
    end
  endtask

  task wait_out_valid_task;
    begin
      latency = 0;
      while (out_valid !== 1'b1) begin
        latency = latency + 1;
        if (latency == 1000) begin
          $display("\033[31m");
          $display("**************************************************");
          $display("                    SPEC-3 FAIL                   ");
          $display("  The execution latency is limited in 1000 cycles.");
          $display("**************************************************");
          $display("\033[0m");
          $finish;
        end
        @(negedge clk);
      end
      $display("\033[33mLatency: %0d\033[0m", latency);
      total_latency = total_latency + latency;
    end
  endtask

  task check_ans;
    integer i;
    integer cnt_out;
    begin
      cnt_out = 0;
      while (cnt_out < 56) begin
        if (out_valid === 1) begin
          if (cnt_out < 28) begin
            if (out_sad !== _sad0_golden[cnt_out]) begin
              $display("\033[31m");
              $display("***********************************************************************");
              $display("*  Error Code:                                                        *");
              $display("*  FAIL at output No.%0d. _sad0_golden: %0d, out_sad: %0d             *",
                       cnt_out, _sad0_golden[cnt_out], out_sad);
              $display("***********************************************************************");
              $display("\033[0m");
              $finish;
            end
          end else begin
            if (out_sad !== _sad1_golden[cnt_out-28]) begin
              $display("\033[31m");
              $display("***********************************************************************");
              $display("*  Error Code:                                                        *");
              $display("*  FAIL at output No.%0d. _sad1_golden: %0d, out_sad: %0d             *",
                       cnt_out, _sad1_golden[cnt_out-28], out_sad);
              $display("***********************************************************************");
              $display("\033[0m");
              $finish;
            end
          end
          cnt_out = cnt_out + 1;
        end else begin
          $display("\033[31m");
          $display("***********************************************************************");
          $display("*  Error Code:                                                        *");
          $display("*  The out_valid should be high for 56 cycles. (current less then 56) *");
          $display("***********************************************************************");
          $display("\033[0m");
          $finish;
        end
        @(negedge clk);
      end

      if (out_valid === 1) begin
        $display("\033[31m");
        $display("***********************************************************************");
        $display("*  Error Code:                                                        *");
        $display("*  The out_valid should be high for 56 cycles. (current more than 56) *");
        $display("***********************************************************************");
        $display("\033[0m");
        $finish;
      end

    end
  endtask
  //================================================================
  // global check
  //================================================================
  initial begin
    while (1) begin
      if ((out_valid === 0) && (out_sad !== 0)) begin
        $display("\033[31m");
        $display("***********************************************************************");
        $display("*  Error Code:                                                        *");
        $display("*       The out_sad should be low when out_valid is low.              *");
        $display("***********************************************************************");
        $display("\033[0m");
        $finish;
      end
      @(negedge clk);
    end
  end

  // Output signal out_valid
  initial begin
    while (1) begin
      if ((in_valid === 1) && (out_valid !== 0)) begin
        $display("\033[31m");
        $display("***********************************************************************");
        $display("*  Error Code:                                                        *");
        $display("*    The out_valid should be low when in_valid is high.               *");
        $display("***********************************************************************");
        $display("\033[0m");
        $finish;
      end
      if ((in_valid2 === 1) && (out_valid !== 0)) begin
        $display("\033[31m");
        $display("***********************************************************************");
        $display("*  Error Code:                                                        *");
        $display("*    The out_valid should be low when in_valid2 is high.               *");
        $display("***********************************************************************");
        $display("\033[0m");
        $finish;
      end
      @(negedge clk);
    end
  end

  // global check
  //================================================================

  // reg toggle;
  // initial begin
  //   toggle = 0;
  //   while (1) begin
  //     #1;  // 加入一個微小的延遲，確保時間能夠推進 (1ns 單位)
  //     if ($time % 1_000_000_000 == 0) begin  // 1秒 = 1_000_000_000 模擬單位
  //       toggle = ~toggle;  // 切換訊息顯示狀態	
  //       if (toggle) $display("Time: %0t ns - Text ON", $time);
  //       else $display("Time: %0t ns - Text OFF", $time);
  //     end
  //   end
  // end


  task YOU_PASS_TASK;
    begin
      $display(
          "                               `-:/+++++++/:-`                                        ");
      $display(
          "                          ./shmNdddmmNNNMMMMMNNhs/.                                   ");
      $display(
          "                       `:yNMMMMMdo------:/+ymMMMMMNds-                                ");
      $display(
          "                     +dNMMNysmMMMd/....-ymNMMMMNMMMMMd+                             ");
      $display(
          "                    .+NMMNy:-.-oNMMm..../MMMNho:-+dMMMMMm+`                           ");
      $display(
          "      ``            +-oso/:::::/+so:....-:+++//////hNNm++dd-                          ");
      $display(
          "      +/-  -`      -:.-//--.....-:+-.....-+/--....--/+-..:Nm:                         ");
      $display(
          "  :--./-:::/.      /-.+:..-:+oso+:-+....-+:/oso+:....-+:..yMN:                        ");
      $display(
          "  -/:-:-.+-/      `+--+.-smNMMMMMNh/....:ymNMMMMNy:...-+../MMm.                       ");
      $display(
          " ::/+-...--/   --:-...-dMMMh/.-yMMd-..-mMMy::oNMMm:...-..-mMMy.                     ");
      $display(
          " .-:+:.....---::-......+MMMM-  sMMN-..oMMN.  .mMMM+.......hd+:-::                   ");
      $display(
          "   /+/::/:..:/-........:mMMMmddmMMMs...+NMMmddNMMMm:......-+-....-/.                  ");
      $display(
          "   ```  /.::...........:odmNNNNmh/-..../ydmNNNmds:.......-.......-+                 ");
      $display(
          "         -:+..............--::::--........--:::--..................::                 ");
      $display(
          "          //.......................................................-:                 ");
      $display(
          "          `+...........................................--::::-....-/`                 ");
      $display(
          "           ::.....................................-//os+/+/+oo----.`                  ");
      $display(
          "            :/-.............................-::/\033[0;31;111mosyyyyyyyyyyyh\033[m-   ");
      $display(
          "             +s+:-...................--::/\033[0;31;111m+ssyyyyyyyyyyyyyyyyy\033[m+   ");
      $display(
          "            .\033[0;31;111myyyyso+:::----:/::://+osssyyyyyyyyyyyyyyyyyyyyyyyy\033[m-  ");
      $display(
          "             -/\033[0;31;111msyyyyyyysssssssyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m. ");
      $display(
          "               `-/\033[0;31;111mssyhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m`");
      $display(
          "                  `.\033[0;31;111mohyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyhyyyyyyyyyyss\033[m/");
      $display(
          "                   \033[0;31;111myyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyydyyyyysso/o\033[m. ");
      $display(
          "                   :\033[0;31;111mhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyhhhyy\033[m:-...+   ");
      $display(
          "                   \033[0;31;111msyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m+....o   ");
      $display(
          "                  `\033[0;31;111mhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m+:..//   ");
      $display(
          "                  :\033[0;31;111mhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m:+.-o`   ");
      $display(
          "                  -\033[0;31;111mhyyyyyyssoosyyyyyssoosyyyyyyssoo+oosy\033[m+--..o`   ");
      $display(
          "                  `s\033[0;33;219m/////:-.``.://::-.``.:/++/:-```````.\033[m+:--:+    ");
      $display(
          "                  ./\033[0;33;219m`````````````````````````````````````\033[ms.-.     ");
      $display(
          "                  /-\033[0;33;219m`````````````````. ``````````````````\033[mo        ");
      $display(
          "                  +\033[0;33;219m``````````````````. ``````````````````\033[m+`       ");
      $display(
          "                  +-\033[0;33;219m....-...---------: :::::::::::::/::::\033[m+`       ");
      $display(
          "                  `\033[0;33;219m.....+::::-:+`````   `   `/+..---o:```\033[m         ");
      $display(
          "                        :-..../`              o-....s``                              ");
      $display(
          "                        ./-.--o               :+:::/o                                ");
      $display(
          "                         /::--o               `o````o                                ");
      $display(
          "                        -//   +                +- `-s/                               ");
      $display(
          "                      -/-::::o:              :+////-+/:-                           ");
      $display(
          "                  `///:-:///:::+             `+////:////+s+                          ");
      $display(
          "*************************************************************************************");
      $display(
          "                        \033[0;38;5;219mCongratulations!\033[m                       ");
      $display(
          "                 \033[0;38;5;219mYou have passed all patterns!\033[m                 ");
      $display(
          "                 \033[0;38;5;219mTotal Cycles : %d\033[m                             ",
          total_latency);
      $display(
          "*************************************************************************************");
      $finish;
    end
  endtask



  task YOU_FAIL_TASK;
    begin
      $display("\033[31m");
      $display(
          "*************************************************************************************");
      $display(
          "*                                   FAILURE!                                        ");
      $display(
          "*                                   (;´༎ຶД༎ຶ`)                                         ");
      $display(
          "*                     Something went wrong with the test!                           ");
      $display(
          "*************************************************************************************");
      $display("\033[0m");
      $finish;
    end
  endtask
endmodule
