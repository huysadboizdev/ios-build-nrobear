using System;

class UpgradeBatchStateTests
{
    static void Check(bool value, string message)
    {
        if (!value) throw new Exception(message);
    }

    static void Main()
    {
        UpgradeBatchState state = new UpgradeBatchState();
        state.Start(100);
        Check(state.TryMarkRequestSent(), "first request must be accepted");
        Check(!state.TryMarkRequestSent(), "must reject a parallel request");
        Check(state.OnResponse(false), "failure response must be accepted");
        Check(!state.TryMarkRequestSent(), "must wait for failed-attempt effect");
        Check(state.OnEffectFinished(), "failed-attempt effect must release next send");
        Check(state.TryMarkRequestSent(), "next request must be accepted after effect");
        Check(state.OnResponse(true), "success response must be accepted");
        Check(!state.IsActive, "success must stop the batch immediately");
        Check(!state.TryMarkRequestSent(), "success must prevent another request");
        Check(!state.OnResponse(false), "duplicate response must be ignored");

        state.Start(100);
        for (int i = 0; i < 100; i++)
        {
            Check(state.TryMarkRequestSent(), "attempt " + (i + 1) + " must be accepted");
            Check(state.OnResponse(false), "failure response " + (i + 1) + " must be accepted");
            if (i < 99) Check(state.OnEffectFinished(), "effect " + (i + 1) + " must release next send");
        }
        Check(!state.IsActive, "100 failed attempts must stop the batch");
        Check(!state.OnResponse(false), "unsolicited response must be ignored");

        state.Start(100);
        Check(state.TryMarkRequestSent(), "request before cancel must be accepted");
        Check(state.HasPendingRequest, "in-flight request must be exposed for cancellation handling");
        state.Cancel();
        Check(!state.IsActive && !state.HasPendingRequest && !state.TryMarkRequestSent(), "cancel must stop future sends");
        Console.WriteLine("PASS upgrade batch state: sequential requests, first-success stop, 100-attempt limit, effect wait, cancellation, duplicate-response guard");
    }
}
