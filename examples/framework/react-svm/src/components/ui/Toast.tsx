import { useEffect } from "react";
import { messages } from "../../messages";

interface ErrorToastProps {
  message: string;
  onDismiss: () => void;
}

export function ErrorToast({ message, onDismiss }: ErrorToastProps) {
  useEffect(() => {
    const timer = setTimeout(onDismiss, 5000);
    return () => clearTimeout(timer);
  }, [message, onDismiss]);

  return (
    <div className="fixed bottom-4 right-4 z-50 max-w-sm w-full bg-red-50 border border-red-300 rounded-lg shadow-lg p-4 flex items-start gap-3">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-red-800">{messages.errors.toastTitle}</p>
        <p className="text-sm text-red-700 break-words mt-1">{message}</p>
      </div>
      <button
        onClick={onDismiss}
        className="flex-shrink-0 text-red-500 hover:text-red-700 text-xl leading-none ml-2"
        aria-label="Dismiss"
      >
        &times;
      </button>
    </div>
  );
}
