package math;

  function automatic longint imax(longint a, longint b);
    return (a > b) ? a : b;
  endfunction

  function automatic longint imin(longint a, longint b);
    return (a > b) ? b : a;
  endfunction

  function automatic longint iabs(longint v);
    return (v < 0) ? -v : v;
  endfunction

endpackage
