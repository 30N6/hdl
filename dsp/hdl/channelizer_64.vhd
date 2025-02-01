library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library common_lib;
  use common_lib.common_pkg.all;
  use common_lib.math_pkg.all;

library dsp_lib;
  use dsp_lib.dsp_pkg.all;

entity channelizer_64 is
generic (
  INPUT_DATA_WIDTH    : natural;
  OUTPUT_DATA_WIDTH   : natural;
  BASEBANDING_ENABLE  : boolean
);
port (
  Clk                   : in  std_logic;
  Rst                   : in  std_logic;

  Input_valid           : in  std_logic;
  Input_data            : in  signed_array_t(1 downto 0)(INPUT_DATA_WIDTH - 1 downto 0);

  Output_chan_ctrl      : out channelizer_control_t;
  Output_chan_data      : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);
  Output_chan_pwr       : out unsigned(CHAN_POWER_WIDTH - 1 downto 0);

  Output_fft_ctrl       : out channelizer_control_t;
  Output_fft_data       : out signed_array_t(1 downto 0)(OUTPUT_DATA_WIDTH - 1 downto 0);

  Warning_demux_gap     : out std_logic;
  Error_demux_overflow  : out std_logic;
  Error_filter_overflow : out std_logic;
  Error_mux_overflow    : out std_logic;
  Error_mux_underflow   : out std_logic;
  Error_mux_collision   : out std_logic
);
end entity channelizer_64;

architecture rtl of channelizer_64 is

  constant NUM_CHANNELS : natural := 64;
  constant NUM_COEFS    : natural := 768;
  constant COEF_WIDTH   : natural := 18;
  constant COEF_DATA    : signed_array_t(NUM_COEFS - 1 downto 0)(COEF_WIDTH - 1 downto 0) := (
      0 => "111111111111111101",   1 => "111111111111111101",   2 => "111111111111111100",   3 => "111111111111111100",   4 => "111111111111111100",   5 => "111111111111111011",   6 => "111111111111111011",   7 => "111111111111111011",
      8 => "111111111111111010",   9 => "111111111111111010",  10 => "111111111111111010",  11 => "111111111111111010",  12 => "111111111111111001",  13 => "111111111111111001",  14 => "111111111111111001",  15 => "111111111111111001",
     16 => "111111111111111001",  17 => "111111111111111010",  18 => "111111111111111010",  19 => "111111111111111010",  20 => "111111111111111011",  21 => "111111111111111011",  22 => "111111111111111100",  23 => "111111111111111101",
     24 => "111111111111111110",  25 => "111111111111111111",  26 => "000000000000000001",  27 => "000000000000000010",  28 => "000000000000000100",  29 => "000000000000000101",  30 => "000000000000000111",  31 => "000000000000001010",
     32 => "000000000000001100",  33 => "000000000000001110",  34 => "000000000000010001",  35 => "000000000000010100",  36 => "000000000000010111",  37 => "000000000000011010",  38 => "000000000000011101",  39 => "000000000000100000",
     40 => "000000000000100100",  41 => "000000000000100111",  42 => "000000000000101011",  43 => "000000000000101110",  44 => "000000000000110010",  45 => "000000000000110110",  46 => "000000000000111001",  47 => "000000000000111101",
     48 => "000000000001000001",  49 => "000000000001000100",  50 => "000000000001000111",  51 => "000000000001001011",  52 => "000000000001001110",  53 => "000000000001010001",  54 => "000000000001010011",  55 => "000000000001010110",
     56 => "000000000001011000",  57 => "000000000001011001",  58 => "000000000001011011",  59 => "000000000001011011",  60 => "000000000001011100",  61 => "000000000001011100",  62 => "000000000001011011",  63 => "000000000001011010",
     64 => "000000000001011000",  65 => "000000000001010110",  66 => "000000000001010010",  67 => "000000000001001111",  68 => "000000000001001010",  69 => "000000000001000101",  70 => "000000000000111111",  71 => "000000000000111000",
     72 => "000000000000110000",  73 => "000000000000101000",  74 => "000000000000011110",  75 => "000000000000010100",  76 => "000000000000001001",  77 => "111111111111111110",  78 => "111111111111110001",  79 => "111111111111100100",
     80 => "111111111111010110",  81 => "111111111111000111",  82 => "111111111110110111",  83 => "111111111110100111",  84 => "111111111110010110",  85 => "111111111110000101",  86 => "111111111101110011",  87 => "111111111101100001",
     88 => "111111111101001110",  89 => "111111111100111011",  90 => "111111111100101000",  91 => "111111111100010101",  92 => "111111111100000001",  93 => "111111111011101110",  94 => "111111111011011011",  95 => "111111111011001000",
     96 => "111111111010110110",  97 => "111111111010100100",  98 => "111111111010010011",  99 => "111111111010000010", 100 => "111111111001110011", 101 => "111111111001100100", 102 => "111111111001010111", 103 => "111111111001001011",
    104 => "111111111001000000", 105 => "111111111000110111", 106 => "111111111000110000", 107 => "111111111000101010", 108 => "111111111000100110", 109 => "111111111000100101", 110 => "111111111000100110", 111 => "111111111000101001",
    112 => "111111111000101110", 113 => "111111111000110110", 114 => "111111111001000000", 115 => "111111111001001101", 116 => "111111111001011101", 117 => "111111111001110000", 118 => "111111111010000110", 119 => "111111111010011110",
    120 => "111111111010111010", 121 => "111111111011011001", 122 => "111111111011111010", 123 => "111111111100011111", 124 => "111111111101000110", 125 => "111111111101110000", 126 => "111111111110011101", 127 => "111111111111001101",
    128 => "000000000000000000", 129 => "000000000000110101", 130 => "000000000001101101", 131 => "000000000010100111", 132 => "000000000011100011", 133 => "000000000100100000", 134 => "000000000101100000", 135 => "000000000110100001",
    136 => "000000000111100100", 137 => "000000001000100111", 138 => "000000001001101011", 139 => "000000001010110000", 140 => "000000001011110101", 141 => "000000001100111010", 142 => "000000001101111110", 143 => "000000001111000001",
    144 => "000000010000000011", 145 => "000000010001000100", 146 => "000000010010000011", 147 => "000000010011000000", 148 => "000000010011111001", 149 => "000000010100110000", 150 => "000000010101100100", 151 => "000000010110010011",
    152 => "000000010110111111", 153 => "000000010111100110", 154 => "000000011000001000", 155 => "000000011000100100", 156 => "000000011000111011", 157 => "000000011001001100", 158 => "000000011001010110", 159 => "000000011001011010",
    160 => "000000011001010111", 161 => "000000011001001101", 162 => "000000011000111011", 163 => "000000011000100001", 164 => "000000010111111111", 165 => "000000010111010101", 166 => "000000010110100011", 167 => "000000010101101000",
    168 => "000000010100100101", 169 => "000000010011011001", 170 => "000000010010000101", 171 => "000000010000101000", 172 => "000000001111000011", 173 => "000000001101010101", 174 => "000000001011011111", 175 => "000000001001100010",
    176 => "000000000111011100", 177 => "000000000101001111", 178 => "000000000010111011", 179 => "000000000000100000", 180 => "111111111101111110", 181 => "111111111011010111", 182 => "111111111000101011", 183 => "111111110101111001",
    184 => "111111110011000100", 185 => "111111110000001010", 186 => "111111101101001110", 187 => "111111101010010000", 188 => "111111100111010000", 189 => "111111100100010000", 190 => "111111100001001111", 191 => "111111011110010000",
    192 => "111111011011010011", 193 => "111111011000011000", 194 => "111111010101100001", 195 => "111111010010101111", 196 => "111111010000000010", 197 => "111111001101011100", 198 => "111111001010111101", 199 => "111111001000100111",
    200 => "111111000110011010", 201 => "111111000100010111", 202 => "111111000010100000", 203 => "111111000000110101", 204 => "111110111111010111", 205 => "111110111110001000", 206 => "111110111101000111", 207 => "111110111100010101",
    208 => "111110111011110101", 209 => "111110111011100101", 210 => "111110111011100111", 211 => "111110111011111100", 212 => "111110111100100100", 213 => "111110111101011111", 214 => "111110111110101110", 215 => "111111000000010010",
    216 => "111111000010001010", 217 => "111111000100010111", 218 => "111111000110111001", 219 => "111111001001101111", 220 => "111111001100111011", 221 => "111111010000011100", 222 => "111111010100010001", 223 => "111111011000011010",
    224 => "111111011100110111", 225 => "111111100001101000", 226 => "111111100110101011", 227 => "111111101100000000", 228 => "111111110001100101", 229 => "111111110111011011", 230 => "111111111101100000", 231 => "000000000011110011",
    232 => "000000001010010011", 233 => "000000010000111110", 234 => "000000010111110011", 235 => "000000011110110001", 236 => "000000100101110101", 237 => "000000101100111111", 238 => "000000110100001100", 239 => "000000111011011011",
    240 => "000001000010101010", 241 => "000001001001110110", 242 => "000001010000111111", 243 => "000001011000000001", 244 => "000001011110111011", 245 => "000001100101101011", 246 => "000001101100001110", 247 => "000001110010100011",
    248 => "000001111000100110", 249 => "000001111110010111", 250 => "000010000011110011", 251 => "000010001000111000", 252 => "000010001101100011", 253 => "000010010001110011", 254 => "000010010101100101", 255 => "000010011000111000",
    256 => "000010011011101010", 257 => "000010011101111001", 258 => "000010011111100011", 259 => "000010100000100111", 260 => "000010100001000011", 261 => "000010100000110110", 262 => "000010011111111110", 263 => "000010011110011010",
    264 => "000010011100001010", 265 => "000010011001001100", 266 => "000010010101011111", 267 => "000010010001000100", 268 => "000010001011111010", 269 => "000010000110000000", 270 => "000001111111010111", 271 => "000001110111111111",
    272 => "000001101111111000", 273 => "000001100111000011", 274 => "000001011101100000", 275 => "000001010011010001", 276 => "000001001000010111", 277 => "000000111100110011", 278 => "000000110000100111", 279 => "000000100011110100",
    280 => "000000010110011110", 281 => "000000001000100101", 282 => "111111111010001100", 283 => "111111101011010111", 284 => "111111011100000111", 285 => "111111001100100000", 286 => "111110111100100110", 287 => "111110101100011010",
    288 => "111110011100000010", 289 => "111110001011100001", 290 => "111101111010111011", 291 => "111101101010010011", 292 => "111101011001101110", 293 => "111101001001010001", 294 => "111100111000111111", 295 => "111100101000111101",
    296 => "111100011001001111", 297 => "111100001001111011", 298 => "111011111011000110", 299 => "111011101100110010", 300 => "111011011111000111", 301 => "111011010010000111", 302 => "111011000101111001", 303 => "111010111010100001",
    304 => "111010110000000011", 305 => "111010100110100100", 306 => "111010011110001010", 307 => "111010010110110111", 308 => "111010010000110001", 309 => "111010001011111100", 310 => "111010001000011101", 311 => "111010000110010110",
    312 => "111010000101101100", 313 => "111010000110100010", 314 => "111010001000111100", 315 => "111010001100111110", 316 => "111010010010101001", 317 => "111010011010000001", 318 => "111010100011001000", 319 => "111010101110000000",
    320 => "111010111010101011", 321 => "111011001001001100", 322 => "111011011001100010", 323 => "111011101011101110", 324 => "111011111111110011", 325 => "111100010101101111", 326 => "111100101101100011", 327 => "111101000111001111",
    328 => "111101100010110001", 329 => "111110000000001000", 330 => "111110011111010100", 331 => "111111000000010010", 332 => "111111100011000000", 333 => "000000000111011011", 334 => "000000101101100001", 335 => "000001010101001110",
    336 => "000001111110100000", 337 => "000010101001010001", 338 => "000011010101011101", 339 => "000100000011000001", 340 => "000100110001110111", 341 => "000101100001111010", 342 => "000110010011000101", 343 => "000111000101010001",
    344 => "000111111000011001", 345 => "001000101100010110", 346 => "001001100001000011", 347 => "001010010110010111", 348 => "001011001100001101", 349 => "001100000010011101", 350 => "001100111001000000", 351 => "001101101111101110",
    352 => "001110100110100001", 353 => "001111011101001111", 354 => "010000010011110011", 355 => "010001001010000011", 356 => "010001111111111001", 357 => "010010110101001011", 358 => "010011101001110100", 359 => "010100011101101010",
    360 => "010101010000100110", 361 => "010110000010100001", 362 => "010110110011010010", 363 => "010111100010110011", 364 => "011000010000111101", 365 => "011000111101100111", 366 => "011001101000101101", 367 => "011010010010000101",
    368 => "011010111001101100", 369 => "011011011111011001", 370 => "011100000011000111", 371 => "011100100100110010", 372 => "011101000100010010", 373 => "011101100001100100", 374 => "011101111100100010", 375 => "011110010101001001",
    376 => "011110101011010101", 377 => "011110111111000001", 378 => "011111010000001011", 379 => "011111011110110001", 380 => "011111101010101111", 381 => "011111110100000100", 382 => "011111111010101110", 383 => "011111111110101101",
    384 => "011111111111111111", 385 => "011111111110100101", 386 => "011111111010011110", 387 => "011111110011101100", 388 => "011111101010001111", 389 => "011111011110001001", 390 => "011111001111011100", 391 => "011110111110001010",
    392 => "011110101010010111", 393 => "011110010100000100", 394 => "011101111011010111", 395 => "011101100000010010", 396 => "011101000010111010", 397 => "011100100011010011", 398 => "011100000001100100", 399 => "011011011101110000",
    400 => "011010110111111111", 401 => "011010010000010100", 402 => "011001100110111000", 403 => "011000111011101111", 404 => "011000001111000010", 405 => "010111100000110110", 406 => "010110110001010011", 407 => "010110000000100000",
    408 => "010101001110100101", 409 => "010100011011101000", 410 => "010011100111110010", 411 => "010010110011001011", 412 => "010001111101111001", 413 => "010001001000000101", 414 => "010000010001110111", 415 => "001111011011010110",
    416 => "001110100100101010", 417 => "001101101101111011", 418 => "001100110111010001", 419 => "001100000000110010", 420 => "001011001010100111", 421 => "001010010100110110", 422 => "001001011111100111", 423 => "001000101011000000",
    424 => "000111110111001001", 425 => "000111000100000111", 426 => "000110010010000010", 427 => "000101100000111110", 428 => "000100110001000010", 429 => "000100000010010011", 430 => "000011010100110110", 431 => "000010101000110001",
    432 => "000001111110000111", 433 => "000001010100111110", 434 => "000000101101011000", 435 => "000000000111011001", 436 => "111111100011000110", 437 => "111111000000011111", 438 => "111110011111101001", 439 => "111110000000100100",
    440 => "111101100011010100", 441 => "111101000111111001", 442 => "111100101110010100", 443 => "111100010110100110", 444 => "111100000000110000", 445 => "111011101100110010", 446 => "111011011010101010", 447 => "111011001010011010",
    448 => "111010111011111111", 449 => "111010101111011000", 450 => "111010100100100100", 451 => "111010011011100001", 452 => "111010010100001101", 453 => "111010001110100100", 454 => "111010001010100110", 455 => "111010001000001110",
    456 => "111010000111011001", 457 => "111010001000000100", 458 => "111010001010001100", 459 => "111010001101101100", 460 => "111010010010100001", 461 => "111010011000100111", 462 => "111010011111111001", 463 => "111010101000010010",
    464 => "111010110001101111", 465 => "111010111100001011", 466 => "111011000111100001", 467 => "111011010011101101", 468 => "111011100000101001", 469 => "111011101110010001", 470 => "111011111100100000", 471 => "111100001011010010",
    472 => "111100011010100010", 473 => "111100101010001010", 474 => "111100111010000111", 475 => "111101001010010100", 476 => "111101011010101100", 477 => "111101101011001011", 478 => "111101111011101110", 479 => "111110001100001110",
    480 => "111110011100101001", 481 => "111110101100111011", 482 => "111110111101000000", 483 => "111111001100110101", 484 => "111111011100010110", 485 => "111111101011011111", 486 => "111111111010001111", 487 => "000000001000100001",
    488 => "000000010110010100", 489 => "000000100011100101", 490 => "000000110000010010", 491 => "000000111100011001", 492 => "000001000111110111", 493 => "000001010010101100", 494 => "000001011100110110", 495 => "000001100110010100",
    496 => "000001101111000101", 497 => "000001110111000111", 498 => "000001111110011100", 499 => "000010000101000001", 500 => "000010001010110111", 501 => "000010001111111110", 502 => "000010010100010111", 503 => "000010011000000000",
    504 => "000010011010111100", 505 => "000010011101001011", 506 => "000010011110101101", 507 => "000010011111100100", 508 => "000010011111110000", 509 => "000010011111010100", 510 => "000010011110010000", 511 => "000010011100100110",
    512 => "000010011010010111", 513 => "000010010111100110", 514 => "000010010100010100", 515 => "000010010000100011", 516 => "000010001100010101", 517 => "000010000111101011", 518 => "000010000010101001", 519 => "000001111101010000",
    520 => "000001110111100010", 521 => "000001110001100001", 522 => "000001101011001111", 523 => "000001100100101111", 524 => "000001011110000011", 525 => "000001010111001101", 526 => "000001010000001110", 527 => "000001001001001010",
    528 => "000001000010000001", 529 => "000000111010110111", 530 => "000000110011101100", 531 => "000000101100100011", 532 => "000000100101011110", 533 => "000000011110011101", 534 => "000000010111100100", 535 => "000000010000110011",
    536 => "000000001010001100", 537 => "000000000011110001", 538 => "111111111101100010", 539 => "111111110111100001", 540 => "111111110001101111", 541 => "111111101100001101", 542 => "111111100110111100", 543 => "111111100001111101",
    544 => "111111011101010000", 545 => "111111011000110110", 546 => "111111010100110000", 547 => "111111010000111101", 548 => "111111001101011111", 549 => "111111001010010110", 550 => "111111000111100010", 551 => "111111000101000010",
    552 => "111111000010110111", 553 => "111111000001000000", 554 => "111110111111011110", 555 => "111110111110010000", 556 => "111110111101010110", 557 => "111110111100101111", 558 => "111110111100011011", 559 => "111110111100011001",
    560 => "111110111100101001", 561 => "111110111101001010", 562 => "111110111101111011", 563 => "111110111110111100", 564 => "111111000000001011", 565 => "111111000001101000", 566 => "111111000011010010", 567 => "111111000101001000",
    568 => "111111000111001001", 569 => "111111001001010100", 570 => "111111001011101001", 571 => "111111001110000110", 572 => "111111010000101010", 573 => "111111010011010101", 574 => "111111010110000101", 575 => "111111011000111010",
    576 => "111111011011110010", 577 => "111111011110101101", 578 => "111111100001101010", 579 => "111111100100101000", 580 => "111111100111100110", 581 => "111111101010100011", 582 => "111111101101011111", 583 => "111111110000011001",
    584 => "111111110011001111", 585 => "111111110110000010", 586 => "111111111000110001", 587 => "111111111011011100", 588 => "111111111110000000", 589 => "000000000000011111", 590 => "000000000010111000", 591 => "000000000101001010",
    592 => "000000000111010101", 593 => "000000001001011000", 594 => "000000001011010100", 595 => "000000001101001000", 596 => "000000001110110100", 597 => "000000010000011000", 598 => "000000010001110011", 599 => "000000010011000110",
    600 => "000000010100010000", 601 => "000000010101010010", 602 => "000000010110001100", 603 => "000000010110111101", 604 => "000000010111100110", 605 => "000000011000000111", 606 => "000000011000100000", 607 => "000000011000110010",
    608 => "000000011000111100", 609 => "000000011000111111", 610 => "000000011000111011", 611 => "000000011000110001", 612 => "000000011000100000", 613 => "000000011000001001", 614 => "000000010111101101", 615 => "000000010111001011",
    616 => "000000010110100101", 617 => "000000010101111010", 618 => "000000010101001011", 619 => "000000010100011001", 620 => "000000010011100011", 621 => "000000010010101010", 622 => "000000010001101110", 623 => "000000010000110000",
    624 => "000000001111110000", 625 => "000000001110101111", 626 => "000000001101101101", 627 => "000000001100101010", 628 => "000000001011100110", 629 => "000000001010100011", 630 => "000000001001011111", 631 => "000000001000011100",
    632 => "000000000111011010", 633 => "000000000110011001", 634 => "000000000101011001", 635 => "000000000100011011", 636 => "000000000011011110", 637 => "000000000010100011", 638 => "000000000001101011", 639 => "000000000000110100",
    640 => "000000000000000000", 641 => "111111111111001110", 642 => "111111111110100000", 643 => "111111111101110011", 644 => "111111111101001010", 645 => "111111111100100011", 646 => "111111111100000000", 647 => "111111111011011111",
    648 => "111111111011000001", 649 => "111111111010100110", 650 => "111111111010001110", 651 => "111111111001111001", 652 => "111111111001100111", 653 => "111111111001010111", 654 => "111111111001001010", 655 => "111111111001000000",
    656 => "111111111000111001", 657 => "111111111000110011", 658 => "111111111000110001", 659 => "111111111000110000", 660 => "111111111000110010", 661 => "111111111000110101", 662 => "111111111000111011", 663 => "111111111001000010",
    664 => "111111111001001011", 665 => "111111111001010101", 666 => "111111111001100001", 667 => "111111111001101110", 668 => "111111111001111101", 669 => "111111111010001100", 670 => "111111111010011100", 671 => "111111111010101101",
    672 => "111111111010111110", 673 => "111111111011010000", 674 => "111111111011100011", 675 => "111111111011110101", 676 => "111111111100001000", 677 => "111111111100011011", 678 => "111111111100101110", 679 => "111111111101000000",
    680 => "111111111101010011", 681 => "111111111101100101", 682 => "111111111101110111", 683 => "111111111110001000", 684 => "111111111110011001", 685 => "111111111110101010", 686 => "111111111110111001", 687 => "111111111111001000",
    688 => "111111111111010111", 689 => "111111111111100101", 690 => "111111111111110001", 691 => "111111111111111110", 692 => "000000000000001001", 693 => "000000000000010100", 694 => "000000000000011101", 695 => "000000000000100110",
    696 => "000000000000101111", 697 => "000000000000110110", 698 => "000000000000111101", 699 => "000000000001000011", 700 => "000000000001001000", 701 => "000000000001001100", 702 => "000000000001010000", 703 => "000000000001010011",
    704 => "000000000001010101", 705 => "000000000001010111", 706 => "000000000001011000", 707 => "000000000001011001", 708 => "000000000001011001", 709 => "000000000001011000", 710 => "000000000001010111", 711 => "000000000001010110",
    712 => "000000000001010101", 713 => "000000000001010011", 714 => "000000000001010000", 715 => "000000000001001110", 716 => "000000000001001011", 717 => "000000000001001000", 718 => "000000000001000101", 719 => "000000000001000001",
    720 => "000000000000111110", 721 => "000000000000111011", 722 => "000000000000110111", 723 => "000000000000110011", 724 => "000000000000110000", 725 => "000000000000101100", 726 => "000000000000101001", 727 => "000000000000100101",
    728 => "000000000000100010", 729 => "000000000000011111", 730 => "000000000000011100", 731 => "000000000000011000", 732 => "000000000000010110", 733 => "000000000000010011", 734 => "000000000000010000", 735 => "000000000000001110",
    736 => "000000000000001011", 737 => "000000000000001001", 738 => "000000000000000111", 739 => "000000000000000101", 740 => "000000000000000011", 741 => "000000000000000010", 742 => "000000000000000001", 743 => "111111111111111111",
    744 => "111111111111111110", 745 => "111111111111111101", 746 => "111111111111111100", 747 => "111111111111111100", 748 => "111111111111111011", 749 => "111111111111111011", 750 => "111111111111111010", 751 => "111111111111111010",
    752 => "111111111111111010", 753 => "111111111111111010", 754 => "111111111111111010", 755 => "111111111111111010", 756 => "111111111111111010", 757 => "111111111111111010", 758 => "111111111111111010", 759 => "111111111111111010",
    760 => "111111111111111011", 761 => "111111111111111011", 762 => "111111111111111011", 763 => "111111111111111100", 764 => "111111111111111100", 765 => "111111111111111100", 766 => "111111111111111101", 767 => "111111111111111101"
  );

begin

  i_channelizer : entity dsp_lib.channelizer_common
  generic map (
    INPUT_DATA_WIDTH    => INPUT_DATA_WIDTH,
    OUTPUT_DATA_WIDTH   => OUTPUT_DATA_WIDTH,
    NUM_CHANNELS        => NUM_CHANNELS,
    NUM_COEFS           => NUM_COEFS,
    COEF_WIDTH          => COEF_WIDTH,
    COEF_DATA           => COEF_DATA,
    FFT_PATH_ENABLE     => false,
    BASEBANDING_ENABLE  => BASEBANDING_ENABLE
  )
  port map (
    Clk                   => Clk,
    Rst                   => Rst,

    Input_valid           => Input_valid,
    Input_data            => Input_data,

    Output_chan_ctrl      => Output_chan_ctrl,
    Output_chan_data      => Output_chan_data,
    Output_chan_pwr       => Output_chan_pwr,

    Output_fft_ctrl       => Output_fft_ctrl,
    Output_fft_data       => Output_fft_data,

    Warning_demux_gap     => Warning_demux_gap,
    Error_demux_overflow  => Error_demux_overflow,
    Error_filter_overflow => Error_filter_overflow,
    Error_mux_overflow    => Error_mux_overflow,
    Error_mux_underflow   => Error_mux_underflow,
    Error_mux_collision   => Error_mux_collision
  );

end architecture rtl;
