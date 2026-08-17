export function appendMissingPaths(pathValue: string | undefined, fallbackPaths: string[]): string {
  const currentPaths = (pathValue ?? "").split(":").filter(Boolean);
  const missingFallbackPaths = fallbackPaths.filter(
    (path) => !currentPaths.includes(path),
  );
  return [...currentPaths, ...missingFallbackPaths].join(":");
}
