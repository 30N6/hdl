library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_pipelined is
generic (
  NUM_POINTS        : natural;
  INDEX_WIDTH       : natural;
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  INPUT_PIPE_STAGES : natural
);
port (
  Clk             : in  std_logic;
  Rst             : in  std_logic;

  Input_control   : in  fft_control_t;
  Input_i         : in  signed(INPUT_DATA_WIDTH - 1 downto 0);
  Input_q         : in  signed(INPUT_DATA_WIDTH - 1 downto 0);

  Output_control  : out fft_control_t;
  Output_i        : out signed(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_q        : out signed(OUTPUT_DATA_WIDTH - 1 downto 0)
);
end entity fft_pipelined;

architecture rtl of fft_pipelined is

  constant NUM_PAGES                : natural := 2;
  constant PAGE_INDEX_WIDTH         : natural := clog2(NUM_PAGES);

  constant INPUT_BUFFER_ADDR_WIDTH  : natural := INDEX_WIDTH + PAGE_INDEX_WIDTH;
  constant INPUT_MEM_DATA_WIDTH     : natural := 2*INPUT_DATA_WIDTH;
  constant INPUT_MEM_INFO_WIDTH     : natural := FFT_TAG_WIDTH + 1;

  constant FFT4_OUTPUT_WIDTH        : natural := INPUT_DATA_WIDTH + 2;
  constant FFT8_OUTPUT_WIDTH        : natural := FFT4_OUTPUT_WIDTH + 1;
  constant FFT16_OUTPUT_WIDTH       : natural := FFT8_OUTPUT_WIDTH + 1;
  constant FFT32_OUTPUT_WIDTH       : natural := FFT16_OUTPUT_WIDTH + 1;
  constant FFT64_OUTPUT_WIDTH       : natural := FFT32_OUTPUT_WIDTH + 1;
  constant FFT128_OUTPUT_WIDTH      : natural := FFT64_OUTPUT_WIDTH + 1;
  constant FFT256_OUTPUT_WIDTH      : natural := FFT128_OUTPUT_WIDTH + 1;
  constant FFT512_OUTPUT_WIDTH      : natural := FFT256_OUTPUT_WIDTH + 1;
  constant FFT1024_OUTPUT_WIDTH     : natural := FFT512_OUTPUT_WIDTH + 1;

  constant INPUT_READ_INDEX_8       : natural_array_t(0 to 7)     := (0, 2, 4, 6, 1, 3, 5, 7);
  constant INPUT_READ_INDEX_16      : natural_array_t(0 to 15)    := (0, 4, 8, 12, 2, 6, 10, 14,   1, 5, 9, 13, 3, 7, 11, 15);
  constant INPUT_READ_INDEX_32      : natural_array_t(0 to 31)    := (0, 8, 16, 24,   4, 12, 20, 28,    2, 10, 18, 26,    6, 14, 22, 30,    1, 9, 17, 25,   5, 13, 21, 29,    3, 11, 19, 27,    7, 15, 23, 31);
  constant INPUT_READ_INDEX_64      : natural_array_t(0 to 63)    := (0, 16, 32, 48, 8, 24, 40, 56, 4, 20, 36, 52, 12, 28, 44, 60, 2, 18, 34, 50, 10, 26, 42, 58, 6, 22, 38, 54, 14, 30, 46, 62, 1, 17, 33, 49, 9, 25, 41, 57, 5, 21, 37, 53, 13, 29, 45, 61, 3, 19, 35, 51, 11, 27, 43, 59, 7, 23, 39, 55, 15, 31, 47, 63);
  constant INPUT_READ_INDEX_128     : natural_array_t(0 to 127)   := (0, 32, 64, 96, 16, 48, 80, 112, 8, 40, 72, 104, 24, 56, 88, 120, 4, 36, 68, 100, 20, 52, 84, 116, 12, 44, 76, 108, 28, 60, 92, 124, 2, 34, 66, 98, 18, 50, 82, 114, 10, 42, 74, 106, 26, 58, 90, 122, 6, 38, 70, 102, 22, 54, 86, 118, 14, 46, 78, 110, 30, 62, 94, 126, 1, 33, 65, 97, 17, 49, 81, 113, 9, 41, 73, 105, 25, 57, 89, 121, 5, 37, 69, 101, 21, 53, 85, 117, 13, 45, 77, 109, 29, 61, 93, 125, 3, 35, 67, 99, 19, 51, 83, 115, 11, 43, 75, 107, 27, 59, 91, 123, 7, 39, 71, 103, 23, 55, 87, 119, 15, 47, 79, 111, 31, 63, 95, 127);
  constant INPUT_READ_INDEX_256     : natural_array_t(0 to 255)   := (0, 64, 128, 192, 32, 96, 160, 224, 16, 80, 144, 208, 48, 112, 176, 240, 8, 72, 136, 200, 40, 104, 168, 232, 24, 88, 152, 216, 56, 120, 184, 248, 4, 68, 132, 196, 36, 100, 164, 228, 20, 84, 148, 212, 52, 116, 180, 244, 12, 76, 140, 204, 44, 108, 172, 236, 28, 92, 156, 220, 60, 124, 188, 252, 2, 66, 130, 194, 34, 98, 162, 226, 18, 82, 146, 210, 50, 114, 178, 242, 10, 74, 138, 202, 42, 106, 170, 234, 26, 90, 154, 218, 58, 122, 186, 250, 6, 70, 134, 198, 38, 102, 166, 230, 22, 86, 150, 214, 54, 118, 182, 246, 14, 78, 142, 206, 46, 110, 174, 238, 30, 94, 158, 222, 62, 126, 190, 254, 1, 65, 129, 193, 33, 97, 161, 225, 17, 81, 145, 209, 49, 113, 177, 241, 9, 73, 137, 201, 41, 105, 169, 233, 25, 89, 153, 217, 57, 121, 185, 249, 5, 69, 133, 197, 37, 101, 165, 229, 21, 85, 149, 213, 53, 117, 181, 245, 13, 77, 141, 205, 45, 109, 173, 237, 29, 93, 157, 221, 61, 125, 189, 253, 3, 67, 131, 195, 35, 99, 163, 227, 19, 83, 147, 211, 51, 115, 179, 243, 11, 75, 139, 203, 43, 107, 171, 235, 27, 91, 155, 219, 59, 123, 187, 251, 7, 71, 135, 199, 39, 103, 167, 231, 23, 87, 151, 215, 55, 119, 183, 247, 15, 79, 143, 207, 47, 111, 175, 239, 31, 95, 159, 223, 63, 127, 191, 255);
  constant INPUT_READ_INDEX_512     : natural_array_t(0 to 511)   := (0, 128, 256, 384, 64, 192, 320, 448, 32, 160, 288, 416, 96, 224, 352, 480, 16, 144, 272, 400, 80, 208, 336, 464, 48, 176, 304, 432, 112, 240, 368, 496, 8, 136, 264, 392, 72, 200, 328, 456, 40, 168, 296, 424, 104, 232, 360, 488, 24, 152, 280, 408, 88, 216, 344, 472, 56, 184, 312, 440, 120, 248, 376, 504, 4, 132, 260, 388, 68, 196, 324, 452, 36, 164, 292, 420, 100, 228, 356, 484, 20, 148, 276, 404, 84, 212, 340, 468, 52, 180, 308, 436, 116, 244, 372, 500, 12, 140, 268, 396, 76, 204, 332, 460, 44, 172, 300, 428, 108, 236, 364, 492, 28, 156, 284, 412, 92, 220, 348, 476, 60, 188, 316, 444, 124, 252, 380, 508, 2, 130, 258, 386, 66, 194, 322, 450, 34, 162, 290, 418, 98, 226, 354, 482, 18, 146, 274, 402, 82, 210, 338, 466, 50, 178, 306, 434, 114, 242, 370, 498, 10, 138, 266, 394, 74, 202, 330, 458, 42, 170, 298, 426, 106, 234, 362, 490, 26, 154, 282, 410, 90, 218, 346, 474, 58, 186, 314, 442, 122, 250, 378, 506, 6, 134, 262, 390, 70, 198, 326, 454, 38, 166, 294, 422, 102, 230, 358, 486, 22, 150, 278, 406, 86, 214, 342, 470, 54, 182, 310, 438, 118, 246, 374, 502, 14, 142, 270, 398, 78, 206, 334, 462, 46, 174, 302, 430, 110, 238, 366, 494, 30, 158, 286, 414, 94, 222, 350, 478, 62, 190, 318, 446, 126, 254, 382, 510, 1, 129, 257, 385, 65, 193, 321, 449, 33, 161, 289, 417, 97, 225, 353, 481, 17, 145, 273, 401, 81, 209, 337, 465, 49, 177, 305, 433, 113, 241, 369, 497, 9, 137, 265, 393, 73, 201, 329, 457, 41, 169, 297, 425, 105, 233, 361, 489, 25, 153, 281, 409, 89, 217, 345, 473, 57, 185, 313, 441, 121, 249, 377, 505, 5, 133, 261, 389, 69, 197, 325, 453, 37, 165, 293, 421, 101, 229, 357, 485, 21, 149, 277, 405, 85, 213, 341, 469, 53, 181, 309, 437, 117, 245, 373, 501, 13, 141, 269, 397, 77, 205, 333, 461, 45, 173, 301, 429, 109, 237, 365, 493, 29, 157, 285, 413, 93, 221, 349, 477, 61, 189, 317, 445, 125, 253, 381, 509, 3, 131, 259, 387, 67, 195, 323, 451, 35, 163, 291, 419, 99, 227, 355, 483, 19, 147, 275, 403, 83, 211, 339, 467, 51, 179, 307, 435, 115, 243, 371, 499, 11, 139, 267, 395, 75, 203, 331, 459, 43, 171, 299, 427, 107, 235, 363, 491, 27, 155, 283, 411, 91, 219, 347, 475, 59, 187, 315, 443, 123, 251, 379, 507, 7, 135, 263, 391, 71, 199, 327, 455, 39, 167, 295, 423, 103, 231, 359, 487, 23, 151, 279, 407, 87, 215, 343, 471, 55, 183, 311, 439, 119, 247, 375, 503, 15, 143, 271, 399, 79, 207, 335, 463, 47, 175, 303, 431, 111, 239, 367, 495, 31, 159, 287, 415, 95, 223, 351, 479, 63, 191, 319, 447, 127, 255, 383, 511);
  constant INPUT_READ_INDEX_1024    : natural_array_t(0 to 1023)  := (0, 256, 512, 768, 128, 384, 640, 896, 64, 320, 576, 832, 192, 448, 704, 960, 32, 288, 544, 800, 160, 416, 672, 928, 96, 352, 608, 864, 224, 480, 736, 992, 16, 272, 528, 784, 144, 400, 656, 912, 80, 336, 592, 848, 208, 464, 720, 976, 48, 304, 560, 816, 176, 432, 688, 944, 112, 368, 624, 880, 240, 496, 752, 1008, 8, 264, 520, 776, 136, 392, 648, 904, 72, 328, 584, 840, 200, 456, 712, 968, 40, 296, 552, 808, 168, 424, 680, 936, 104, 360, 616, 872, 232, 488, 744, 1000, 24, 280, 536, 792, 152, 408, 664, 920, 88, 344, 600, 856, 216, 472, 728, 984, 56, 312, 568, 824, 184, 440, 696, 952, 120, 376, 632, 888, 248, 504, 760, 1016, 4, 260, 516, 772, 132, 388, 644, 900, 68, 324, 580, 836, 196, 452, 708, 964, 36, 292, 548, 804, 164, 420, 676, 932, 100, 356, 612, 868, 228, 484, 740, 996, 20, 276, 532, 788, 148, 404, 660, 916, 84, 340, 596, 852, 212, 468, 724, 980, 52, 308, 564, 820, 180, 436, 692, 948, 116, 372, 628, 884, 244, 500, 756, 1012, 12, 268, 524, 780, 140, 396, 652, 908, 76, 332, 588, 844, 204, 460, 716, 972, 44, 300, 556, 812, 172, 428, 684, 940, 108, 364, 620, 876, 236, 492, 748, 1004, 28, 284, 540, 796, 156, 412, 668, 924, 92, 348, 604, 860, 220, 476, 732, 988, 60, 316, 572, 828, 188, 444, 700, 956, 124, 380, 636, 892, 252, 508, 764, 1020, 2, 258, 514, 770, 130, 386, 642, 898, 66, 322, 578, 834, 194, 450, 706, 962, 34, 290, 546, 802, 162, 418, 674, 930, 98, 354, 610, 866, 226, 482, 738, 994, 18, 274, 530, 786, 146, 402, 658, 914, 82, 338, 594, 850, 210, 466, 722, 978, 50, 306, 562, 818, 178, 434, 690, 946, 114, 370, 626, 882, 242, 498, 754, 1010, 10, 266, 522, 778, 138, 394, 650, 906, 74, 330, 586, 842, 202, 458, 714, 970, 42, 298, 554, 810, 170, 426, 682, 938, 106, 362, 618, 874, 234, 490, 746, 1002, 26, 282, 538, 794, 154, 410, 666, 922, 90, 346, 602, 858, 218, 474, 730, 986, 58, 314, 570, 826, 186, 442, 698, 954, 122, 378, 634, 890, 250, 506, 762, 1018, 6, 262, 518, 774, 134, 390, 646, 902, 70, 326, 582, 838, 198, 454, 710, 966, 38, 294, 550, 806, 166, 422, 678, 934, 102, 358, 614, 870, 230, 486, 742, 998, 22, 278, 534, 790, 150, 406, 662, 918, 86, 342, 598, 854, 214, 470, 726, 982, 54, 310, 566, 822, 182, 438, 694, 950, 118, 374, 630, 886, 246, 502, 758, 1014, 14, 270, 526, 782, 142, 398, 654, 910, 78, 334, 590, 846, 206, 462, 718, 974, 46, 302, 558, 814, 174, 430, 686, 942, 110, 366, 622, 878, 238, 494, 750, 1006, 30, 286, 542, 798, 158, 414, 670, 926, 94, 350, 606, 862, 222, 478, 734, 990, 62, 318, 574, 830, 190, 446, 702, 958, 126, 382, 638, 894, 254, 510, 766, 1022, 1, 257, 513, 769, 129, 385, 641, 897, 65, 321, 577, 833, 193, 449, 705, 961, 33, 289, 545, 801, 161, 417, 673, 929, 97, 353, 609, 865, 225, 481, 737, 993, 17, 273, 529, 785, 145, 401, 657, 913, 81, 337, 593, 849, 209, 465, 721, 977, 49, 305, 561, 817, 177, 433, 689, 945, 113, 369, 625, 881, 241, 497, 753, 1009, 9, 265, 521, 777, 137, 393, 649, 905, 73, 329, 585, 841, 201, 457, 713, 969, 41, 297, 553, 809, 169, 425, 681, 937, 105, 361, 617, 873, 233, 489, 745, 1001, 25, 281, 537, 793, 153, 409, 665, 921, 89, 345, 601, 857, 217, 473, 729, 985, 57, 313, 569, 825, 185, 441, 697, 953, 121, 377, 633, 889, 249, 505, 761, 1017, 5, 261, 517, 773, 133, 389, 645, 901, 69, 325, 581, 837, 197, 453, 709, 965, 37, 293, 549, 805, 165, 421, 677, 933, 101, 357, 613, 869, 229, 485, 741, 997, 21, 277, 533, 789, 149, 405, 661, 917, 85, 341, 597, 853, 213, 469, 725, 981, 53, 309, 565, 821, 181, 437, 693, 949, 117, 373, 629, 885, 245, 501, 757, 1013, 13, 269, 525, 781, 141, 397, 653, 909, 77, 333, 589, 845, 205, 461, 717, 973, 45, 301, 557, 813, 173, 429, 685, 941, 109, 365, 621, 877, 237, 493, 749, 1005, 29, 285, 541, 797, 157, 413, 669, 925, 93, 349, 605, 861, 221, 477, 733, 989, 61, 317, 573, 829, 189, 445, 701, 957, 125, 381, 637, 893, 253, 509, 765, 1021, 3, 259, 515, 771, 131, 387, 643, 899, 67, 323, 579, 835, 195, 451, 707, 963, 35, 291, 547, 803, 163, 419, 675, 931, 99, 355, 611, 867, 227, 483, 739, 995, 19, 275, 531, 787, 147, 403, 659, 915, 83, 339, 595, 851, 211, 467, 723, 979, 51, 307, 563, 819, 179, 435, 691, 947, 115, 371, 627, 883, 243, 499, 755, 1011, 11, 267, 523, 779, 139, 395, 651, 907, 75, 331, 587, 843, 203, 459, 715, 971, 43, 299, 555, 811, 171, 427, 683, 939, 107, 363, 619, 875, 235, 491, 747, 1003, 27, 283, 539, 795, 155, 411, 667, 923, 91, 347, 603, 859, 219, 475, 731, 987, 59, 315, 571, 827, 187, 443, 699, 955, 123, 379, 635, 891, 251, 507, 763, 1019, 7, 263, 519, 775, 135, 391, 647, 903, 71, 327, 583, 839, 199, 455, 711, 967, 39, 295, 551, 807, 167, 423, 679, 935, 103, 359, 615, 871, 231, 487, 743, 999, 23, 279, 535, 791, 151, 407, 663, 919, 87, 343, 599, 855, 215, 471, 727, 983, 55, 311, 567, 823, 183, 439, 695, 951, 119, 375, 631, 887, 247, 503, 759, 1015, 15, 271, 527, 783, 143, 399, 655, 911, 79, 335, 591, 847, 207, 463, 719, 975, 47, 303, 559, 815, 175, 431, 687, 943, 111, 367, 623, 879, 239, 495, 751, 1007, 31, 287, 543, 799, 159, 415, 671, 927, 95, 351, 607, 863, 223, 479, 735, 991, 63, 319, 575, 831, 191, 447, 703, 959, 127, 383, 639, 895, 255, 511, 767, 1023);

  signal r_rst                      : std_logic;

  signal r_input_wr_control         : fft_control_t;
  signal r_input_wr_data            : std_logic_vector(INPUT_MEM_DATA_WIDTH - 1 downto 0);
  signal w_input_wr_info            : std_logic_vector(INPUT_MEM_INFO_WIDTH - 1 downto 0);
  signal w_input_wr_addr            : unsigned(INPUT_BUFFER_ADDR_WIDTH - 1 downto 0);
  signal w_input_wr_valid_last      : std_logic;

  signal w_input_rd_addr            : unsigned(INPUT_BUFFER_ADDR_WIDTH - 1 downto 0);
  signal w_input_rd_data            : std_logic_vector(INPUT_MEM_DATA_WIDTH - 1 downto 0);
  signal w_input_rd_info            : std_logic_vector(INPUT_MEM_INFO_WIDTH - 1 downto 0);

  signal r_write_page_index         : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_read_page_index          : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_input_active             : std_logic;
  signal r_input_index              : unsigned(INDEX_WIDTH - 1 downto 0);

  signal r_input_index_pipe         : unsigned_array_t(INPUT_PIPE_STAGES - 1 downto 0)(INDEX_WIDTH - 1 downto 0);
  signal r_input_active_pipe        : std_logic_vector(INPUT_PIPE_STAGES - 1 downto 0);
  signal r_input_last_pipe          : std_logic_vector(INPUT_PIPE_STAGES - 1 downto 0);

  signal r_fft4_input_control       : fft_control_t;
  signal r_fft4_input_i             : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal r_fft4_input_q             : signed_array_t(3 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_fft4_output_control      : fft_control_t;
  signal w_fft4_output_i            : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_output_q            : signed_array_t(3 downto 0)(FFT4_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft4_serial_control      : fft_control_t;
  signal w_fft4_serial_i            : signed(FFT4_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft4_serial_q            : signed(FFT4_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft8_output_control      : fft_control_t;
  signal w_fft8_output_i            : signed(FFT8_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft8_output_q            : signed(FFT8_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft16_output_control     : fft_control_t;
  signal w_fft16_output_i           : signed(FFT16_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft16_output_q           : signed(FFT16_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft32_output_control     : fft_control_t;
  signal w_fft32_output_i           : signed(FFT32_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft32_output_q           : signed(FFT32_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft64_output_control     : fft_control_t;
  signal w_fft64_output_i           : signed(FFT64_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft64_output_q           : signed(FFT64_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft128_output_control    : fft_control_t;
  signal w_fft128_output_i          : signed(FFT128_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft128_output_q          : signed(FFT128_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft256_output_control    : fft_control_t;
  signal w_fft256_output_i          : signed(FFT256_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft256_output_q          : signed(FFT256_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft512_output_control    : fft_control_t;
  signal w_fft512_output_i          : signed(FFT512_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft512_output_q          : signed(FFT512_OUTPUT_WIDTH - 1 downto 0);

  signal w_fft1024_output_control   : fft_control_t;
  signal w_fft1024_output_i         : signed(FFT1024_OUTPUT_WIDTH - 1 downto 0);
  signal w_fft1024_output_q         : signed(FFT1024_OUTPUT_WIDTH - 1 downto 0);


begin

  assert ((NUM_POINTS = 8) or (NUM_POINTS = 16) or (NUM_POINTS = 32) or (NUM_POINTS = 64) or
          (NUM_POINTS = 128) or (NUM_POINTS = 256) or (NUM_POINTS = 512) or (NUM_POINTS = 1024))
    report "Invalid FFT length."
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_rst <= Rst;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_input_wr_control <= Input_control;
      r_input_wr_data    <= std_logic_vector(Input_i) & std_logic_vector(Input_q);
    end if;
  end process;

  w_input_wr_info       <= r_input_wr_control.reverse & r_input_wr_control.tag;
  w_input_wr_valid_last <= r_input_wr_control.valid and r_input_wr_control.last;
  w_input_wr_addr       <= r_write_page_index & r_input_wr_control.data_index(INDEX_WIDTH - 1 downto 0);

  process(all)
  begin
    if (NUM_POINTS = 8) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_8(to_integer(r_input_index)),  INDEX_WIDTH);
    elsif (NUM_POINTS = 16) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_16(to_integer(r_input_index)), INDEX_WIDTH);
    elsif (NUM_POINTS = 32) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_32(to_integer(r_input_index)), INDEX_WIDTH);
    elsif (NUM_POINTS = 64) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_64(to_integer(r_input_index)), INDEX_WIDTH);
    elsif (NUM_POINTS = 128) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_128(to_integer(r_input_index)), INDEX_WIDTH);
    elsif (NUM_POINTS = 256) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_256(to_integer(r_input_index)), INDEX_WIDTH);
    elsif (NUM_POINTS = 512) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_512(to_integer(r_input_index)), INDEX_WIDTH);
    elsif (NUM_POINTS = 1024) then
      w_input_rd_addr <= r_read_page_index  & to_unsigned(INPUT_READ_INDEX_1024(to_integer(r_input_index)), INDEX_WIDTH);
    end if;
  end process;

  i_data_buffer_s0 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => INPUT_BUFFER_ADDR_WIDTH,
    DATA_WIDTH  => INPUT_MEM_DATA_WIDTH,
    LATENCY     => INPUT_PIPE_STAGES
  )
  port map (
    Clk       => Clk,

    Wr_en     => r_input_wr_control.valid,
    Wr_addr   => w_input_wr_addr,
    Wr_data   => r_input_wr_data,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => w_input_rd_addr,
    Rd_data   => w_input_rd_data
  );

  i_info_buffer_s0 : entity mem_lib.ram_sdp
  generic map (
    ADDR_WIDTH  => PAGE_INDEX_WIDTH,
    DATA_WIDTH  => INPUT_MEM_INFO_WIDTH,
    LATENCY     => INPUT_PIPE_STAGES
  )
  port map (
    Clk       => Clk,

    Wr_en     => w_input_wr_valid_last,
    Wr_addr   => r_write_page_index,
    Wr_data   => w_input_wr_info,

    Rd_en     => '1',
    Rd_reg_ce => '1',
    Rd_addr   => r_read_page_index,
    Rd_data   => w_input_rd_info
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_rst = '1') then
        r_input_index       <= (others => '0');
        r_input_active      <= '0';
        r_write_page_index  <= (others => '0');
        r_read_page_index   <= (others => '0');
      else
        if (w_input_wr_valid_last = '1') then
          r_input_active      <= '1';
          r_input_index       <= (others => '0');
          r_write_page_index  <= r_write_page_index + 1;
          r_read_page_index   <= r_write_page_index;
        else
          if (r_input_index = (NUM_POINTS - 1)) then
            r_input_active <= '0';
          end if;
          r_input_index <= r_input_index + 1;
        end if;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (INPUT_PIPE_STAGES > 1) then
        r_input_index_pipe      <= r_input_index_pipe(INPUT_PIPE_STAGES - 2 downto 0)   & r_input_index;
        r_input_active_pipe     <= r_input_active_pipe(INPUT_PIPE_STAGES - 2 downto 0)  & r_input_active;
        r_input_last_pipe       <= r_input_last_pipe(INPUT_PIPE_STAGES - 2 downto 0)    & to_stdlogic(r_input_index = (NUM_POINTS-1));
      else
        r_input_index_pipe(0)   <=  r_input_index;
        r_input_active_pipe(0)  <=  r_input_active;
        r_input_last_pipe(0)    <=  to_stdlogic(r_input_index = (NUM_POINTS-1));
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (r_input_active_pipe(INPUT_PIPE_STAGES - 1) = '1') then
        for i in 0 to 3 loop
          if (r_input_index_pipe(INPUT_PIPE_STAGES - 1)(1 downto 0) = i) then

            r_fft4_input_i(i) <= signed(w_input_rd_data(INPUT_MEM_DATA_WIDTH - 1 downto (INPUT_MEM_DATA_WIDTH - INPUT_DATA_WIDTH)));
            r_fft4_input_q(i) <= signed(w_input_rd_data(INPUT_DATA_WIDTH - 1 downto 0));
          end if;
        end loop;
      end if;

      r_fft4_input_control.valid      <= r_input_active_pipe(INPUT_PIPE_STAGES - 1) and to_stdlogic(r_input_index_pipe(INPUT_PIPE_STAGES - 1)(1 downto 0) = 3);
      r_fft4_input_control.last       <= r_input_last_pipe(INPUT_PIPE_STAGES - 1);
      r_fft4_input_control.reverse    <= w_input_rd_info(FFT_TAG_WIDTH);
      r_fft4_input_control.data_index <= resize_up(r_input_index_pipe(INPUT_PIPE_STAGES - 1)(INDEX_WIDTH - 1 downto 2) & "00", r_fft4_input_control.data_index'length);
      r_fft4_input_control.tag        <= w_input_rd_info(FFT_TAG_WIDTH - 1 downto 0);
    end if;
  end process;

  i_fft_4_calc : entity dsp_lib.fft_4
  generic map (
    INPUT_DATA_WIDTH  => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH => FFT4_OUTPUT_WIDTH,
    LATENCY           => 2
  )
  port map (
    Clk             => Clk,

    Input_control   => r_fft4_input_control,
    Input_i         => r_fft4_input_i,
    Input_q         => r_fft4_input_q,

    Output_control  => w_fft4_output_control,
    Output_i        => w_fft4_output_i,
    Output_q        => w_fft4_output_q
  );

  i_ff4_serializer : entity dsp_lib.fft_4_serializer
  generic map (
    INPUT_DATA_WIDTH  => FFT4_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT4_OUTPUT_WIDTH
  )
  port map (
    Clk             => Clk,
    Rst             => r_rst,

    Input_control   => w_fft4_output_control,
    Input_i         => w_fft4_output_i,
    Input_q         => w_fft4_output_q,

    Output_control  => w_fft4_serial_control,
    Output_i        => w_fft4_serial_i,
    Output_q        => w_fft4_serial_q
  );

  i_fft_8 : entity dsp_lib.fft_radix2_stage
  generic map (
    NUM_POINTS        => NUM_POINTS,
    CYCLE_INDEX_WIDTH => INDEX_WIDTH,
    INPUT_DATA_WIDTH  => FFT4_OUTPUT_WIDTH,
    OUTPUT_DATA_WIDTH => FFT8_OUTPUT_WIDTH,
    STAGE_INDEX       => 8
  )
  port map (
    Clk             => Clk,
    Rst             => r_rst,

    Input_control   => w_fft4_serial_control,
    Input_i         => w_fft4_serial_i,
    Input_q         => w_fft4_serial_q,

    Output_control  => w_fft8_output_control,
    Output_i        => w_fft8_output_i,
    Output_q        => w_fft8_output_q
  );

  g_output_16 : if (NUM_POINTS > 8) generate
    i_fft_16 : entity dsp_lib.fft_radix2_stage
    generic map (
      NUM_POINTS        => NUM_POINTS,
      CYCLE_INDEX_WIDTH => INDEX_WIDTH,
      INPUT_DATA_WIDTH  => FFT8_OUTPUT_WIDTH,
      OUTPUT_DATA_WIDTH => FFT16_OUTPUT_WIDTH,
      STAGE_INDEX       => 16
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_control   => w_fft8_output_control,
      Input_i         => w_fft8_output_i,
      Input_q         => w_fft8_output_q,

      Output_control  => w_fft16_output_control,
      Output_i        => w_fft16_output_i,
      Output_q        => w_fft16_output_q
    );
  end generate g_output_16;

  g_output_32 : if (NUM_POINTS > 16) generate
    i_fft_32 : entity dsp_lib.fft_radix2_stage
    generic map (
      NUM_POINTS        => NUM_POINTS,
      CYCLE_INDEX_WIDTH => INDEX_WIDTH,
      INPUT_DATA_WIDTH  => FFT16_OUTPUT_WIDTH,
      OUTPUT_DATA_WIDTH => FFT32_OUTPUT_WIDTH,
      STAGE_INDEX       => 32
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_control   => w_fft16_output_control,
      Input_i         => w_fft16_output_i,
      Input_q         => w_fft16_output_q,

      Output_control  => w_fft32_output_control,
      Output_i        => w_fft32_output_i,
      Output_q        => w_fft32_output_q
    );
  end generate g_output_32;

  g_output_64 : if (NUM_POINTS > 32) generate
    i_fft_64 : entity dsp_lib.fft_radix2_stage
    generic map (
      NUM_POINTS        => NUM_POINTS,
      CYCLE_INDEX_WIDTH => INDEX_WIDTH,
      INPUT_DATA_WIDTH  => FFT32_OUTPUT_WIDTH,
      OUTPUT_DATA_WIDTH => FFT64_OUTPUT_WIDTH,
      STAGE_INDEX       => 64
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_control   => w_fft32_output_control,
      Input_i         => w_fft32_output_i,
      Input_q         => w_fft32_output_q,

      Output_control  => w_fft64_output_control,
      Output_i        => w_fft64_output_i,
      Output_q        => w_fft64_output_q
    );
  end generate g_output_64;

  g_output_128 : if (NUM_POINTS > 64) generate
    i_fft_128 : entity dsp_lib.fft_radix2_stage
    generic map (
      NUM_POINTS        => NUM_POINTS,
      CYCLE_INDEX_WIDTH => INDEX_WIDTH,
      INPUT_DATA_WIDTH  => FFT64_OUTPUT_WIDTH,
      OUTPUT_DATA_WIDTH => FFT128_OUTPUT_WIDTH,
      STAGE_INDEX       => 128
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_control   => w_fft64_output_control,
      Input_i         => w_fft64_output_i,
      Input_q         => w_fft64_output_q,

      Output_control  => w_fft128_output_control,
      Output_i        => w_fft128_output_i,
      Output_q        => w_fft128_output_q
    );
  end generate g_output_128;

  g_output_256 : if (NUM_POINTS > 128) generate
    i_fft_256 : entity dsp_lib.fft_radix2_stage
    generic map (
      NUM_POINTS        => NUM_POINTS,
      CYCLE_INDEX_WIDTH => INDEX_WIDTH,
      INPUT_DATA_WIDTH  => FFT128_OUTPUT_WIDTH,
      OUTPUT_DATA_WIDTH => FFT256_OUTPUT_WIDTH,
      STAGE_INDEX       => 256
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_control   => w_fft128_output_control,
      Input_i         => w_fft128_output_i,
      Input_q         => w_fft128_output_q,

      Output_control  => w_fft256_output_control,
      Output_i        => w_fft256_output_i,
      Output_q        => w_fft256_output_q
    );
  end generate g_output_256;

  g_output_512 : if (NUM_POINTS > 256) generate
    i_fft_512 : entity dsp_lib.fft_radix2_stage
    generic map (
      NUM_POINTS        => NUM_POINTS,
      CYCLE_INDEX_WIDTH => INDEX_WIDTH,
      INPUT_DATA_WIDTH  => FFT256_OUTPUT_WIDTH,
      OUTPUT_DATA_WIDTH => FFT512_OUTPUT_WIDTH,
      STAGE_INDEX       => 512
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_control   => w_fft256_output_control,
      Input_i         => w_fft256_output_i,
      Input_q         => w_fft256_output_q,

      Output_control  => w_fft512_output_control,
      Output_i        => w_fft512_output_i,
      Output_q        => w_fft512_output_q
    );
  end generate g_output_512;

  g_output_1024 : if (NUM_POINTS > 512) generate
    i_fft_1024 : entity dsp_lib.fft_radix2_stage
    generic map (
      NUM_POINTS        => NUM_POINTS,
      CYCLE_INDEX_WIDTH => INDEX_WIDTH,
      INPUT_DATA_WIDTH  => FFT512_OUTPUT_WIDTH,
      OUTPUT_DATA_WIDTH => FFT1024_OUTPUT_WIDTH,
      STAGE_INDEX       => 1024
    )
    port map (
      Clk             => Clk,
      Rst             => r_rst,

      Input_control   => w_fft512_output_control,
      Input_i         => w_fft512_output_i,
      Input_q         => w_fft512_output_q,

      Output_control  => w_fft1024_output_control,
      Output_i        => w_fft1024_output_i,
      Output_q        => w_fft1024_output_q
    );
  end generate g_output_1024;

  g_output : if (NUM_POINTS = 8) generate
    Output_control  <= w_fft8_output_control;
    Output_i        <= w_fft8_output_i(FFT8_OUTPUT_WIDTH - 1 downto (FFT8_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft8_output_q(FFT8_OUTPUT_WIDTH - 1 downto (FFT8_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  elsif (NUM_POINTS = 16) generate
    Output_control  <= w_fft16_output_control;
    Output_i        <= w_fft16_output_i(FFT16_OUTPUT_WIDTH - 1 downto (FFT16_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft16_output_q(FFT16_OUTPUT_WIDTH - 1 downto (FFT16_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  elsif (NUM_POINTS = 32) generate
    Output_control  <= w_fft32_output_control;
    Output_i        <= w_fft32_output_i(FFT32_OUTPUT_WIDTH - 1 downto (FFT32_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft32_output_q(FFT32_OUTPUT_WIDTH - 1 downto (FFT32_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  elsif (NUM_POINTS = 64) generate
    Output_control  <= w_fft64_output_control;
    Output_i        <= w_fft64_output_i(FFT64_OUTPUT_WIDTH - 1 downto (FFT64_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft64_output_q(FFT64_OUTPUT_WIDTH - 1 downto (FFT64_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  elsif (NUM_POINTS = 128) generate
    Output_control  <= w_fft128_output_control;
    Output_i        <= w_fft128_output_i(FFT128_OUTPUT_WIDTH - 1 downto (FFT128_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft128_output_q(FFT128_OUTPUT_WIDTH - 1 downto (FFT128_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  elsif (NUM_POINTS = 256) generate
    Output_control  <= w_fft256_output_control;
    Output_i        <= w_fft256_output_i(FFT256_OUTPUT_WIDTH - 1 downto (FFT256_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft256_output_q(FFT256_OUTPUT_WIDTH - 1 downto (FFT256_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  elsif (NUM_POINTS = 512) generate
    Output_control  <= w_fft512_output_control;
    Output_i        <= w_fft512_output_i(FFT512_OUTPUT_WIDTH - 1 downto (FFT512_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft512_output_q(FFT512_OUTPUT_WIDTH - 1 downto (FFT512_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  else generate
    Output_control  <= w_fft1024_output_control;
    Output_i        <= w_fft1024_output_i(FFT1024_OUTPUT_WIDTH - 1 downto (FFT1024_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
    Output_q        <= w_fft1024_output_q(FFT1024_OUTPUT_WIDTH - 1 downto (FFT1024_OUTPUT_WIDTH - OUTPUT_DATA_WIDTH));
  end generate g_output;

end architecture rtl;
