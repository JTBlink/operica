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
  lg: { wrapper: "p-2.5", icon: "size-5" },
};

export function OperciaIcon({
  className,
  animate = false,
  noSpin = false,
  bordered = false,
  size = "sm",
  ...props
}: OperciaIconProps) {
  const mark = (
    <svg
      viewBox="0 0 64 64"
      fill="none"
      aria-hidden="true"
      className="block size-full"
    >
      <path
        d="M14 25C16.7 14.4 26.3 7 38 7c13.8 0 25 11.2 25 25 0 10.4-6.4 19.4-15.5 23.1 5.2-5.1 7.5-11.5 6.1-18.2-2-9.6-10.5-16.7-20.4-16.7-7.7 0-14.7 4.2-18.3 10.6L14 25Z"
        fill="currentColor"
      />
      <path
        d="M50 39c-2.9 10.4-12.4 18-23.7 18C12.9 57 2 46.1 2 32.7c0-10 6.1-18.6 14.7-22.3-4.7 5-6.8 11.2-5.4 17.6 2 9.3 10.2 16.1 19.8 16.1 7.5 0 14.3-4.1 17.9-10.3L50 39Z"
        fill="currentColor"
      />
      <rect
        x="26"
        y="26"
        width="12"
        height="12"
        rx="3"
        fill="currentColor"
        transform="rotate(45 32 32)"
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
