library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library mem_lib;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity fft_radix2_stage is
generic (
  NUM_POINTS        : natural;
  CYCLE_INDEX_WIDTH : natural;
  INPUT_DATA_WIDTH  : natural;
  OUTPUT_DATA_WIDTH : natural;
  STAGE_INDEX       : natural
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
end entity fft_radix2_stage;

architecture rtl of fft_radix2_stage is

  function get_read_index(is_a : boolean) return natural_array_t is
    variable r_a : natural_array_t(0 to NUM_POINTS - 1);
    variable r_b : natural_array_t(0 to NUM_POINTS - 1);
    variable phase : natural;
  begin
    for i in 0 to (NUM_POINTS - 1) loop
      phase := i mod STAGE_INDEX;
      if (phase < (STAGE_INDEX / 2)) then
        r_a(i) := i;
        r_b(i) := i + (STAGE_INDEX / 2);
      else
        r_a(i) := i - (STAGE_INDEX / 2);
        r_b(i) := i;
      end if;
    end loop;

    if (is_a) then
      return r_a;
    else
      return r_b;
    end if;
  end function;

  function get_ifft_index_map return natural_array_t is
    variable r : natural_array_t(0 to STAGE_INDEX - 1) := (others => 0);
  begin
    for i in 0 to (STAGE_INDEX - 1) loop
      if (i > 0) then
        r(i) := STAGE_INDEX - i;
      end if;
    end loop;
    return r;
  end function;

  constant BUFFER_DATA_WIDTH      : natural := 2*INPUT_DATA_WIDTH;
  constant TWIDDLE_DATA_WIDTH     : natural := 17;
  constant TWIDDLE_FRAC_WIDTH     : natural := 16;
  constant MEM_READ_LATENCY       : natural := 3; -- third stage to help timing into DSP block
  constant OUTPUT_STAGE_LATENCY   : natural := 8;
  constant OUTPUT_PIPE_DEPTH      : natural := MEM_READ_LATENCY + OUTPUT_STAGE_LATENCY;
  constant NUM_PAGES              : natural := 2;
  constant PAGE_INDEX_WIDTH       : natural := clog2(NUM_PAGES);
  constant MEM_ADDR_WIDTH         : natural := PAGE_INDEX_WIDTH + CYCLE_INDEX_WIDTH;

  constant READ_INDEX_A           : natural_array_t(0 to NUM_POINTS - 1) := get_read_index(true);
  constant READ_INDEX_B           : natural_array_t(0 to NUM_POINTS - 1) := get_read_index(false);

  --TODO: cleanup
  --constant READ_INDEX_A_S8        : natural_array_t(0 to MAX_CYCLES-1) := (0, 1, 2, 3,   0, 1, 2, 3,      8, 9, 10, 11,     8, 9, 10, 11,     16, 17, 18, 19,   16, 17, 18, 19,   24, 25, 26, 27,   24, 25, 26, 27,     32, 33, 34, 35,   32, 33, 34, 35,   40, 41, 42, 43,   40, 41, 42, 43,       48, 49, 50, 51,   48, 49, 50, 51,   56, 57, 58, 59,   56, 57, 58, 59);
  --constant READ_INDEX_B_S8        : natural_array_t(0 to MAX_CYCLES-1) := (4, 5, 6, 7,   4, 5, 6, 7,      12, 13, 14, 15,   12, 13, 14, 15,   20, 21, 22, 23,   20, 21, 22, 23,   28, 29, 30, 31,   28, 29, 30, 31,     36, 37, 38, 39,   36, 37, 38, 39,   44, 45, 46, 47,   44, 45, 46, 47,       52, 53, 54, 55,   52, 53, 54, 55,   60, 61, 62, 63,   60, 61, 62, 63);
  --constant READ_INDEX_A_S16       : natural_array_t(0 to MAX_CYCLES-1) := (0, 1, 2,  3,  4,  5,  6,  7,   0, 1, 2,  3,  4,  5,  6,  7,        16, 17, 18, 19, 20, 21, 22, 23,     16, 17, 18, 19, 20, 21, 22, 23,       32, 33, 34, 35, 36, 37, 38, 39,     32, 33, 34, 35, 36, 37, 38, 39,         48, 49, 50, 51, 52, 53, 54, 55,     48, 49, 50, 51, 52, 53, 54, 55);
  --constant READ_INDEX_B_S16       : natural_array_t(0 to MAX_CYCLES-1) := (8, 9, 10, 11, 12, 13, 14, 15,  8, 9, 10, 11, 12, 13, 14, 15,       24, 25, 26, 27, 28, 29, 30, 31,     24, 25, 26, 27, 28, 29, 30, 31,       40, 41, 42, 43, 44, 45, 46, 47,     40, 41, 42, 43, 44, 45, 46, 47,         56, 57, 58, 59, 60, 61, 62, 63,     56, 57, 58, 59, 60, 61, 62, 63);
  --constant READ_INDEX_A_S32       : natural_array_t(0 to MAX_CYCLES-1) := (0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15,    0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15,           32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,             32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47);
  --constant READ_INDEX_B_S32       : natural_array_t(0 to MAX_CYCLES-1) := (16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,           48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,             48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63);
  --constant READ_INDEX_A_S64       : natural_array_t(0 to MAX_CYCLES-1) := (0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,              0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31);
  --constant READ_INDEX_B_S64       : natural_array_t(0 to MAX_CYCLES-1) := (32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,              32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63);

  constant IFFT_INDEX_MAP         : natural_array_t(0 to STAGE_INDEX - 1) := get_ifft_index_map;
  --TODO: cleanup
  --constant IFFT_INDEX_MAP_8       : natural_array_t(0 to 7)     := (0, 7, 6, 5, 4, 3, 2, 1);
  --constant IFFT_INDEX_MAP_16      : natural_array_t(0 to 15)    := (0, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);
  --constant IFFT_INDEX_MAP_32      : natural_array_t(0 to 31)    := (0, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);
  --constant IFFT_INDEX_MAP_64      : natural_array_t(0 to 63)    := (0, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);
  --constant IFFT_INDEX_MAP_128     : natural_array_t(0 to 127)   := (0, 127, 126, 125, 124, 123, 122, 121, 120, 119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 109, 108, 107, 106, 105, 104, 103, 102, 101, 100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 89, 88, 87, 86, 85, 84, 83, 82, 81, 80, 79, 78, 77, 76, 75, 74, 73, 72, 71, 70, 69, 68, 67, 66, 65, 64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);
  --constant IFFT_INDEX_MAP_256     : natural_array_t(0 to 255)   := (0, 255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233, 232, 231, 230, 229, 228, 227, 226, 225, 224, 223, 222, 221, 220, 219, 218, 217, 216, 215, 214, 213, 212, 211, 210, 209, 208, 207, 206, 205, 204, 203, 202, 201, 200, 199, 198, 197, 196, 195, 194, 193, 192, 191, 190, 189, 188, 187, 186, 185, 184, 183, 182, 181, 180, 179, 178, 177, 176, 175, 174, 173, 172, 171, 170, 169, 168, 167, 166, 165, 164, 163, 162, 161, 160, 159, 158, 157, 156, 155, 154, 153, 152, 151, 150, 149, 148, 147, 146, 145, 144, 143, 142, 141, 140, 139, 138, 137, 136, 135, 134, 133, 132, 131, 130, 129, 128, 127, 126, 125, 124, 123, 122, 121, 120, 119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 109, 108, 107, 106, 105, 104, 103, 102, 101, 100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 89, 88, 87, 86, 85, 84, 83, 82, 81, 80, 79, 78, 77, 76, 75, 74, 73, 72, 71, 70, 69, 68, 67, 66, 65, 64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);
  --constant IFFT_INDEX_MAP_512     : natural_array_t(0 to 511)   := (0, 511, 510, 509, 508, 507, 506, 505, 504, 503, 502, 501, 500, 499, 498, 497, 496, 495, 494, 493, 492, 491, 490, 489, 488, 487, 486, 485, 484, 483, 482, 481, 480, 479, 478, 477, 476, 475, 474, 473, 472, 471, 470, 469, 468, 467, 466, 465, 464, 463, 462, 461, 460, 459, 458, 457, 456, 455, 454, 453, 452, 451, 450, 449, 448, 447, 446, 445, 444, 443, 442, 441, 440, 439, 438, 437, 436, 435, 434, 433, 432, 431, 430, 429, 428, 427, 426, 425, 424, 423, 422, 421, 420, 419, 418, 417, 416, 415, 414, 413, 412, 411, 410, 409, 408, 407, 406, 405, 404, 403, 402, 401, 400, 399, 398, 397, 396, 395, 394, 393, 392, 391, 390, 389, 388, 387, 386, 385, 384, 383, 382, 381, 380, 379, 378, 377, 376, 375, 374, 373, 372, 371, 370, 369, 368, 367, 366, 365, 364, 363, 362, 361, 360, 359, 358, 357, 356, 355, 354, 353, 352, 351, 350, 349, 348, 347, 346, 345, 344, 343, 342, 341, 340, 339, 338, 337, 336, 335, 334, 333, 332, 331, 330, 329, 328, 327, 326, 325, 324, 323, 322, 321, 320, 319, 318, 317, 316, 315, 314, 313, 312, 311, 310, 309, 308, 307, 306, 305, 304, 303, 302, 301, 300, 299, 298, 297, 296, 295, 294, 293, 292, 291, 290, 289, 288, 287, 286, 285, 284, 283, 282, 281, 280, 279, 278, 277, 276, 275, 274, 273, 272, 271, 270, 269, 268, 267, 266, 265, 264, 263, 262, 261, 260, 259, 258, 257, 256, 255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233, 232, 231, 230, 229, 228, 227, 226, 225, 224, 223, 222, 221, 220, 219, 218, 217, 216, 215, 214, 213, 212, 211, 210, 209, 208, 207, 206, 205, 204, 203, 202, 201, 200, 199, 198, 197, 196, 195, 194, 193, 192, 191, 190, 189, 188, 187, 186, 185, 184, 183, 182, 181, 180, 179, 178, 177, 176, 175, 174, 173, 172, 171, 170, 169, 168, 167, 166, 165, 164, 163, 162, 161, 160, 159, 158, 157, 156, 155, 154, 153, 152, 151, 150, 149, 148, 147, 146, 145, 144, 143, 142, 141, 140, 139, 138, 137, 136, 135, 134, 133, 132, 131, 130, 129, 128, 127, 126, 125, 124, 123, 122, 121, 120, 119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 109, 108, 107, 106, 105, 104, 103, 102, 101, 100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 89, 88, 87, 86, 85, 84, 83, 82, 81, 80, 79, 78, 77, 76, 75, 74, 73, 72, 71, 70, 69, 68, 67, 66, 65, 64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);
  --constant IFFT_INDEX_MAP_1024    : natural_array_t(0 to 1023)  := (0, 1023, 1022, 1021, 1020, 1019, 1018, 1017, 1016, 1015, 1014, 1013, 1012, 1011, 1010, 1009, 1008, 1007, 1006, 1005, 1004, 1003, 1002, 1001, 1000, 999, 998, 997, 996, 995, 994, 993, 992, 991, 990, 989, 988, 987, 986, 985, 984, 983, 982, 981, 980, 979, 978, 977, 976, 975, 974, 973, 972, 971, 970, 969, 968, 967, 966, 965, 964, 963, 962, 961, 960, 959, 958, 957, 956, 955, 954, 953, 952, 951, 950, 949, 948, 947, 946, 945, 944, 943, 942, 941, 940, 939, 938, 937, 936, 935, 934, 933, 932, 931, 930, 929, 928, 927, 926, 925, 924, 923, 922, 921, 920, 919, 918, 917, 916, 915, 914, 913, 912, 911, 910, 909, 908, 907, 906, 905, 904, 903, 902, 901, 900, 899, 898, 897, 896, 895, 894, 893, 892, 891, 890, 889, 888, 887, 886, 885, 884, 883, 882, 881, 880, 879, 878, 877, 876, 875, 874, 873, 872, 871, 870, 869, 868, 867, 866, 865, 864, 863, 862, 861, 860, 859, 858, 857, 856, 855, 854, 853, 852, 851, 850, 849, 848, 847, 846, 845, 844, 843, 842, 841, 840, 839, 838, 837, 836, 835, 834, 833, 832, 831, 830, 829, 828, 827, 826, 825, 824, 823, 822, 821, 820, 819, 818, 817, 816, 815, 814, 813, 812, 811, 810, 809, 808, 807, 806, 805, 804, 803, 802, 801, 800, 799, 798, 797, 796, 795, 794, 793, 792, 791, 790, 789, 788, 787, 786, 785, 784, 783, 782, 781, 780, 779, 778, 777, 776, 775, 774, 773, 772, 771, 770, 769, 768, 767, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 755, 754, 753, 752, 751, 750, 749, 748, 747, 746, 745, 744, 743, 742, 741, 740, 739, 738, 737, 736, 735, 734, 733, 732, 731, 730, 729, 728, 727, 726, 725, 724, 723, 722, 721, 720, 719, 718, 717, 716, 715, 714, 713, 712, 711, 710, 709, 708, 707, 706, 705, 704, 703, 702, 701, 700, 699, 698, 697, 696, 695, 694, 693, 692, 691, 690, 689, 688, 687, 686, 685, 684, 683, 682, 681, 680, 679, 678, 677, 676, 675, 674, 673, 672, 671, 670, 669, 668, 667, 666, 665, 664, 663, 662, 661, 660, 659, 658, 657, 656, 655, 654, 653, 652, 651, 650, 649, 648, 647, 646, 645, 644, 643, 642, 641, 640, 639, 638, 637, 636, 635, 634, 633, 632, 631, 630, 629, 628, 627, 626, 625, 624, 623, 622, 621, 620, 619, 618, 617, 616, 615, 614, 613, 612, 611, 610, 609, 608, 607, 606, 605, 604, 603, 602, 601, 600, 599, 598, 597, 596, 595, 594, 593, 592, 591, 590, 589, 588, 587, 586, 585, 584, 583, 582, 581, 580, 579, 578, 577, 576, 575, 574, 573, 572, 571, 570, 569, 568, 567, 566, 565, 564, 563, 562, 561, 560, 559, 558, 557, 556, 555, 554, 553, 552, 551, 550, 549, 548, 547, 546, 545, 544, 543, 542, 541, 540, 539, 538, 537, 536, 535, 534, 533, 532, 531, 530, 529, 528, 527, 526, 525, 524, 523, 522, 521, 520, 519, 518, 517, 516, 515, 514, 513, 512, 511, 510, 509, 508, 507, 506, 505, 504, 503, 502, 501, 500, 499, 498, 497, 496, 495, 494, 493, 492, 491, 490, 489, 488, 487, 486, 485, 484, 483, 482, 481, 480, 479, 478, 477, 476, 475, 474, 473, 472, 471, 470, 469, 468, 467, 466, 465, 464, 463, 462, 461, 460, 459, 458, 457, 456, 455, 454, 453, 452, 451, 450, 449, 448, 447, 446, 445, 444, 443, 442, 441, 440, 439, 438, 437, 436, 435, 434, 433, 432, 431, 430, 429, 428, 427, 426, 425, 424, 423, 422, 421, 420, 419, 418, 417, 416, 415, 414, 413, 412, 411, 410, 409, 408, 407, 406, 405, 404, 403, 402, 401, 400, 399, 398, 397, 396, 395, 394, 393, 392, 391, 390, 389, 388, 387, 386, 385, 384, 383, 382, 381, 380, 379, 378, 377, 376, 375, 374, 373, 372, 371, 370, 369, 368, 367, 366, 365, 364, 363, 362, 361, 360, 359, 358, 357, 356, 355, 354, 353, 352, 351, 350, 349, 348, 347, 346, 345, 344, 343, 342, 341, 340, 339, 338, 337, 336, 335, 334, 333, 332, 331, 330, 329, 328, 327, 326, 325, 324, 323, 322, 321, 320, 319, 318, 317, 316, 315, 314, 313, 312, 311, 310, 309, 308, 307, 306, 305, 304, 303, 302, 301, 300, 299, 298, 297, 296, 295, 294, 293, 292, 291, 290, 289, 288, 287, 286, 285, 284, 283, 282, 281, 280, 279, 278, 277, 276, 275, 274, 273, 272, 271, 270, 269, 268, 267, 266, 265, 264, 263, 262, 261, 260, 259, 258, 257, 256, 255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233, 232, 231, 230, 229, 228, 227, 226, 225, 224, 223, 222, 221, 220, 219, 218, 217, 216, 215, 214, 213, 212, 211, 210, 209, 208, 207, 206, 205, 204, 203, 202, 201, 200, 199, 198, 197, 196, 195, 194, 193, 192, 191, 190, 189, 188, 187, 186, 185, 184, 183, 182, 181, 180, 179, 178, 177, 176, 175, 174, 173, 172, 171, 170, 169, 168, 167, 166, 165, 164, 163, 162, 161, 160, 159, 158, 157, 156, 155, 154, 153, 152, 151, 150, 149, 148, 147, 146, 145, 144, 143, 142, 141, 140, 139, 138, 137, 136, 135, 134, 133, 132, 131, 130, 129, 128, 127, 126, 125, 124, 123, 122, 121, 120, 119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 109, 108, 107, 106, 105, 104, 103, 102, 101, 100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 89, 88, 87, 86, 85, 84, 83, 82, 81, 80, 79, 78, 77, 76, 75, 74, 73, 72, 71, 70, 69, 68, 67, 66, 65, 64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1);

  signal r_write_page_index       : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);
  signal r_read_page_index        : unsigned(PAGE_INDEX_WIDTH - 1 downto 0);

  signal w_buf_wr_addr            : unsigned(MEM_ADDR_WIDTH - 1 downto 0);
  signal w_buf_wr_data            : std_logic_vector(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_addr            : unsigned_array_t(1 downto 0)(MEM_ADDR_WIDTH - 1 downto 0);
  signal w_buf_rd_data            : std_logic_vector_array_t(1 downto 0)(BUFFER_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_i          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);
  signal w_buf_rd_data_q          : signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  signal w_twiddle_fac_c          : signed(TWIDDLE_DATA_WIDTH - 1 downto 0);
  signal w_twiddle_fac_c_plus_d   : signed(TWIDDLE_DATA_WIDTH downto 0);
  signal w_twiddle_fac_d_minus_c  : signed(TWIDDLE_DATA_WIDTH downto 0);

  signal r_input_control          : fft_control_t;
  signal r_calc_active            : std_logic;
  signal r_calc_index             : unsigned(CYCLE_INDEX_WIDTH - 1 downto 0);
  signal w_read_index             : unsigned(CYCLE_INDEX_WIDTH - 1 downto 0);

  signal r_calc_active_pipe       : std_logic_vector(OUTPUT_PIPE_DEPTH - 1 downto 0);
  signal r_calc_index_pipe        : unsigned_array_t(OUTPUT_PIPE_DEPTH - 1 downto 0)(CYCLE_INDEX_WIDTH - 1 downto 0);
  signal r_control_pipe           : fft_control_array_t(OUTPUT_PIPE_DEPTH - 1 downto 0);

begin

  assert ((STAGE_INDEX = 8) or (STAGE_INDEX = 16) or (STAGE_INDEX = 32) or (STAGE_INDEX = 64) or
          (STAGE_INDEX = 128) or (STAGE_INDEX = 256) or (STAGE_INDEX = 512) or (STAGE_INDEX = 1024))
    report "Invalid stage index"
    severity failure;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if ((Input_control.valid = '1') and (Input_control.last = '1')) then
        r_input_control <= Input_control;
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Rst = '1') then
        r_calc_active       <= '0';
        r_calc_index        <= (others => '-');
        r_write_page_index  <= (others => '0');
        r_read_page_index   <= (others => '0');
      else
        if ((Input_control.valid = '1') and (Input_control.last = '1')) then
          r_calc_active       <= '1';
          r_calc_index        <= (others => '0');
          r_write_page_index  <= r_write_page_index + 1;
          r_read_page_index   <= r_write_page_index;
        else
          if (r_calc_index = (2**CYCLE_INDEX_WIDTH - 1)) then
            r_calc_active <= '0';
          end if;
          r_calc_index <= r_calc_index + 1;
        end if;
      end if;
    end if;
  end process;

  w_buf_wr_addr <= r_write_page_index & Input_control.data_index(CYCLE_INDEX_WIDTH - 1 downto 0);
  w_buf_wr_data <= std_logic_vector(Input_i) & std_logic_vector(Input_q);

  process(all)
  begin
    if ((NUM_POINTS = STAGE_INDEX) and (r_input_control.reverse = '1')) then
      w_read_index <= to_unsigned(IFFT_INDEX_MAP(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);

      --TODO
      --if (STAGE_INDEX = 8) then
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_8(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --elsif (STAGE_INDEX = 16) then
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_16(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --elsif (STAGE_INDEX = 32) then
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_32(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --elsif (STAGE_INDEX = 64) then
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_64(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --elsif (STAGE_INDEX = 128) then
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_128(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --elsif (STAGE_INDEX = 256) then
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_256(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --elsif (STAGE_INDEX = 512) then
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_512(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --else
      --  w_read_index <= to_unsigned(IFFT_INDEX_MAP_1024(to_integer(r_calc_index)), CYCLE_INDEX_WIDTH);
      --end if;
    else
      w_read_index <= r_calc_index;
    end if;
  end process;

  w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);

  --TODO
  --process(all)
  --begin
  --  if (STAGE_INDEX = 8) then
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S8(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S8(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  elsif (STAGE_INDEX = 16) then
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S16(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S16(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  elsif (STAGE_INDEX = 32) then
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S32(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S32(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  elsif (STAGE_INDEX = 64) then
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S64(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S64(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  elsif (STAGE_INDEX = 128) then
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S128(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S128(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  elsif (STAGE_INDEX = 256) then
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S256(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S256(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  elsif (STAGE_INDEX = 512) then
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S512(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S512(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  else
  --    w_buf_rd_addr(0) <= r_read_page_index & to_unsigned(READ_INDEX_A_S1024(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --    w_buf_rd_addr(1) <= r_read_page_index & to_unsigned(READ_INDEX_B_S1024(to_integer(w_read_index)), CYCLE_INDEX_WIDTH);
  --  end if;
  --end process;

  g_buffer : for i in 0 to 1 generate
    i_buffer : entity mem_lib.ram_sdp
    generic map (
      ADDR_WIDTH  => MEM_ADDR_WIDTH,
      DATA_WIDTH  => BUFFER_DATA_WIDTH,
      LATENCY     => MEM_READ_LATENCY
    )
    port map (
      Clk       => Clk,

      Wr_en     => Input_control.valid,
      Wr_addr   => w_buf_wr_addr,
      Wr_data   => w_buf_wr_data,

      Rd_en     => '1',
      Rd_reg_ce => '1',
      Rd_addr   => w_buf_rd_addr(i),
      Rd_data   => w_buf_rd_data(i)
    );

    w_buf_rd_data_i(i) <= signed(w_buf_rd_data(i)(BUFFER_DATA_WIDTH - 1 downto (BUFFER_DATA_WIDTH - INPUT_DATA_WIDTH)));
    w_buf_rd_data_q(i) <= signed(w_buf_rd_data(i)(INPUT_DATA_WIDTH - 1 downto 0));
  end generate g_buffer;

  i_twiddle_mem : entity dsp_lib.fft_twiddle_mem
  generic map (
    NUM_POINTS        => NUM_POINTS,
    CYCLE_INDEX_WIDTH => CYCLE_INDEX_WIDTH,
    STAGE_INDEX       => STAGE_INDEX,
    DATA_WIDTH        => TWIDDLE_DATA_WIDTH,
    LATENCY           => MEM_READ_LATENCY
  )
  port map (
    Clk                 => Clk,

    Read_index          => w_read_index,
    Read_data_c         => w_twiddle_fac_c,
    Read_data_c_plus_d  => w_twiddle_fac_c_plus_d,
    Read_data_d_minus_c => w_twiddle_fac_d_minus_c
  );

  process(Clk)
  begin
    if rising_edge(Clk) then
      r_calc_active_pipe <= r_calc_active_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0) & r_calc_active;
      r_calc_index_pipe  <= r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0)  & r_calc_index;
      r_control_pipe     <= r_control_pipe(OUTPUT_PIPE_DEPTH - 2 downto 0)     & r_input_control;
    end if;
  end process;

  i_radix2_output : entity dsp_lib.fft_radix2_output
  generic map (
    INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
    TWIDDLE_DATA_WIDTH  => TWIDDLE_DATA_WIDTH,
    TWIDDLE_FRAC_WIDTH  => TWIDDLE_FRAC_WIDTH,
    LATENCY             => OUTPUT_STAGE_LATENCY
  )
  port map (
    Clk                     => Clk,

    Input_i                 => w_buf_rd_data_i,
    Input_q                 => w_buf_rd_data_q,
    Input_twiddle_c         => w_twiddle_fac_c,
    Input_twiddle_c_plus_d  => w_twiddle_fac_c_plus_d,
    Input_twiddle_d_minus_c => w_twiddle_fac_d_minus_c,

    Output_i                => Output_i,
    Output_q                => Output_q
  );

  process(all)
  begin
    Output_control            <= r_control_pipe(OUTPUT_PIPE_DEPTH - 1);
    Output_control.valid      <= r_calc_active_pipe(OUTPUT_PIPE_DEPTH - 1);
    Output_control.last       <= to_stdlogic(r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 1) = (NUM_POINTS - 1));
    Output_control.data_index <= resize_up(r_calc_index_pipe(OUTPUT_PIPE_DEPTH - 1), Output_control.data_index'length);
  end process;

end architecture rtl;
