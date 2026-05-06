interface NotEligibleMessageProps {
  sonarHomeURL: string;
}

export function NotEligibleMessage({ sonarHomeURL }: NotEligibleMessageProps) {
  return (
    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
      <p className="text-yellow-800 font-medium mb-2">Not Eligible</p>
      <p className="text-yellow-700 mb-4">
        Your entity is not currently eligible to participate in this sale. Please check your eligibility status or
        complete any required setup steps.
      </p>
      <div className="flex gap-4">
        <a
          href={sonarHomeURL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-block bg-yellow-600 hover:bg-yellow-700 text-white font-medium py-2 px-6 rounded-lg transition-colors"
        >
          Manage on Sonar
        </a>
      </div>
    </div>
  );
}
