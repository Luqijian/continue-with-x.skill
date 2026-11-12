// TODO: finish implementing cancel/flush semantics (in progress)
export interface DebouncedFn<F extends (...args: any[]) => any> {
  (...args: Parameters<F>): void;
  cancel(): void;
  flush(): void;
}

export function debounce<F extends (...args: any[]) => any>(
  fn: F,
  waitMs: number,
): DebouncedFn<F> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let lastArgs: Parameters<F> | undefined;

  const debounced = (...args: Parameters<F>) => {
    lastArgs = args;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = undefined;
      fn(...lastArgs!);
    }, waitMs);
  };

  // WIP: cancel() and flush() below are not implemented yet
  debounced.cancel = () => {
    // TODO: implement
  };
  debounced.flush = () => {
    // TODO: implement — should fire pending call immediately
  };

  return debounced;
}
// wip note
