import { cn } from "../../lib/utils";

interface OperciaIconProps extends React.ComponentProps<"span"> {
  /**
   * If true, play the one-time entrance animation.
   */
  animate?: boolean;
  /**
   * If true, suppress the optional animation.
   */
  noSpin?: boolean;
  /**
   * If true, show a border around the icon.
   */
  bordered?: boolean;
  /**
   * Size of the bordered icon: "sm" (default), "md", "lg"
   */
  size?: "sm" | "md" | "lg";
}

const borderedSizes = {
  sm: { wrapper: "p-1.5", icon: "size-3.5" },
  md: { wrapper: "p-2", icon: "size-4" },
  lg: { wrapper: "p-1.5", icon: "size-8" },
};

export function OperciaIcon({
  className,
  animate = false,
  noSpin = false,
  bordered = false,
  size = "sm",
  ...props
}: OperciaIconProps) {
  const viewBox = bordered && size === "lg" ? "40 40 176 176" : "0 0 256 256";
  const mark = (
    <svg
      viewBox={viewBox}
      fill="none"
      aria-hidden="true"
      className="block size-full"
    >
      <path
        fill="currentColor"
        d="M92 44h38c45.287 0 82 36.713 82 82v29c0 8.49-3.372 16.633-9.373 22.637L171 209v-79c0-23.196-18.804-42-42-42H62c-7.081 0-10.768-8.428-5.97-13.636l23.235-25.205C82.637 45.501 87.064 44 92 44Z"
      />
      <path
        fill="currentColor"
        d="M164 212h-38c-45.287 0-82-36.713-82-82v-29c0-8.49 3.372-16.633 9.373-22.637L85 47v79c0 23.196 18.804 42 42 42h67c7.081 0 10.768 8.428 5.97 13.636l-23.235 25.205C173.363 210.499 168.936 212 164 212Z"
      />
      <rect
        x="106"
        y="106"
        width="44"
        height="44"
        rx="12"
        fill="currentColor"
        transform="rotate(45 128 128)"
      />
    </svg>
  );

  if (bordered) {
    const sizeConfig = borderedSizes[size];
    return (
      <span
        className={cn(
          "inline-flex items-center justify-center border border-border rounded-md",
          sizeConfig.wrapper,
          className,
        )}
        aria-hidden="true"
        {...props}
      >
        <span
          className={cn(
            "block",
            sizeConfig.icon,
            animate && !noSpin && "animate-entrance-spin",
          )}
        >
          {mark}
        </span>
      </span>
    );
  }

  return (
    <span
      className={cn(
        "inline-block size-[1em]",
        animate && !noSpin && "animate-entrance-spin",
        className,
      )}
      aria-hidden="true"
      {...props}
    >
      {mark}
    </span>
  );
}
