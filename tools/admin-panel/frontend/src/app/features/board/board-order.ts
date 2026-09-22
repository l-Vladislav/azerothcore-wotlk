// Translate a visible insertion slot to the unfiltered column, excluding the dragged card.
export function boardDropPosition(
  fullIds: readonly number[],
  visibleIds: readonly number[],
  index: number,
): number {
  const next = visibleIds[index];
  if (next !== undefined) {
    const position = fullIds.indexOf(next);
    if (position < 0) throw new Error('Board changed during drag.');
    return position;
  }
  const previous = visibleIds.at(-1);
  if (previous === undefined) return fullIds.length;
  const position = fullIds.indexOf(previous);
  if (position < 0) throw new Error('Board changed during drag.');
  return position + 1;
}
