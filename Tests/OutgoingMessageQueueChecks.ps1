$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$queuePath = Join-Path $repo 'Assets/Scripts/Assembly-CSharp/ThreadSafeMessageQueue.cs'
if (-not (Test-Path -LiteralPath $queuePath)) {
    throw 'Missing thread-safe outgoing message queue implementation.'
}

$sessionPaths = @(
    'Assets/Scripts/Assembly-CSharp/Game1/Session_ME.cs',
    'Assets/Scripts/Assembly-CSharp/Game1/Session_ME2.cs',
    'Assets/Scripts/Assembly-CSharp/Game2/Session_ME.cs',
    'Assets/Scripts/Assembly-CSharp/Game2/Session_ME2.cs'
)
foreach ($relativePath in $sessionPaths) {
    $path = Join-Path $repo $relativePath
    $source = Get-Content -LiteralPath $path -Raw
    if ($source -notmatch 'ConcurrentMessageQueue<Message>') {
        throw "$relativePath does not use the synchronized queue."
    }
    if ($source -notmatch 'while\s*\(sendingMessage\.TryDequeue\(out Message message\)\)') {
        throw "$relativePath sender does not dequeue atomically."
    }
}

$queueSource = Get-Content -LiteralPath $queuePath -Raw
$harness = @'
public static class OutgoingMessageQueueStress
{
    public static string Run()
    {
        const int producerCount = 8;
        const int messagesPerProducer = 20000;
        const int expected = producerCount * messagesPerProducer;
        var queue = new NRO.Networking.ConcurrentMessageQueue<int>();
        var seen = new int[expected];
        int produced = 0;
        int consumed = 0;
        var consumer = Task.Run(() =>
        {
            while (Volatile.Read(ref produced) < expected || queue.Count > 0)
            {
                int value;
                if (!queue.TryDequeue(out value))
                {
                    Thread.Yield();
                    continue;
                }
                if (value < 0 || value >= expected || Interlocked.Increment(ref seen[value]) != 1)
                    throw new InvalidOperationException("Queue returned a missing, invalid, or duplicate message.");
                Interlocked.Increment(ref consumed);
            }
        });
        var producers = new Task[producerCount];
        for (int worker = 0; worker < producerCount; worker++)
        {
            int start = worker * messagesPerProducer;
            producers[worker] = Task.Run(() =>
            {
                for (int i = 0; i < messagesPerProducer; i++) queue.Enqueue(start + i);
                Interlocked.Add(ref produced, messagesPerProducer);
            });
        }
        Task.WaitAll(producers);
        consumer.Wait();
        if (consumed != expected) throw new InvalidOperationException("Queue lost outgoing messages.");
        for (int i = 0; i < seen.Length; i++)
            if (seen[i] != 1) throw new InvalidOperationException("Queue did not deliver every message exactly once.");
        queue.Enqueue(-1);
        queue.Clear();
        if (queue.Count != 0) throw new InvalidOperationException("Clear did not synchronize with queue operations.");
        return "PASS concurrent FIFO queue: " + consumed + " messages, exactly once";
    }
}
'@

$imports = "using System;`nusing System.Threading;`nusing System.Threading.Tasks;`n"
Add-Type -TypeDefinition ($imports + $queueSource + "`n" + $harness) -Language CSharp
[OutgoingMessageQueueStress]::Run()
