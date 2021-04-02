unit Wasm.Limits;

interface

uses
  System.Classes, System.SysUtils;

const
  // The page size as defined by the WebAssembly 1.0 specification.
  PageSize: Cardinal = 65536;

  // The maximum memory page limit as defined by the specification.
  // It is only possible to address 4 GB (32-bit) of memory.
  MaxMemoryPagesLimit = 65536;

  // The limit of the size of the call stack, i.e. how many calls are allowed to be stacked up
  // in a single execution thread. Allowed values for call depth levels are [0, CallStackLimit-1].
  // The current value is the same as the default limit in WABT:
  CallStackLimit = 2048;

  DefaultMemoryPagesLimit = (256 * 1024 * 1024) div 65536;

implementation

end.

