public sealed class UpgradeBatchState
{
    private int maximumAttempts;
    private int attemptsSent;
    private bool active;
    private bool requestPending;
    private bool effectPending;

    public bool IsActive
    {
        get { return active; }
    }

    public int RemainingAttempts
    {
        get { return maximumAttempts - attemptsSent; }
    }

    public bool HasPendingRequest
    {
        get { return requestPending; }
    }

    public void Start(int maxAttempts)
    {
        Cancel();
        if (maxAttempts <= 0)
        {
            return;
        }

        maximumAttempts = maxAttempts;
        attemptsSent = 0;
        active = true;
    }

    public bool TryMarkRequestSent()
    {
        if (!active || requestPending || effectPending || attemptsSent >= maximumAttempts)
        {
            return false;
        }

        attemptsSent++;
        requestPending = true;
        return true;
    }

    public bool OnResponse(bool successful)
    {
        if (!active || !requestPending)
        {
            return false;
        }

        requestPending = false;
        if (successful || attemptsSent >= maximumAttempts)
        {
            active = false;
            effectPending = false;
            return true;
        }

        effectPending = true;
        return true;
    }

    public bool OnEffectFinished()
    {
        if (!active || !effectPending)
        {
            return false;
        }

        effectPending = false;
        return true;
    }

    public void Cancel()
    {
        active = false;
        requestPending = false;
        effectPending = false;
        attemptsSent = 0;
        maximumAttempts = 0;
    }
}
