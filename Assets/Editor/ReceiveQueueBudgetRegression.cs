using System;

public static class ReceiveQueueBudgetRegression
{
    private const int QueuedMessages = 1000;

    private sealed class Handler1 : Game1.IMessageHandler
    {
        public int Received;
        public void onMessage(Game1.Message message) { Received++; }
        public void onConnectionFail(bool isMain) { }
        public void onDisconnected(bool isMain) { }
        public void onConnectOK(bool isMain) { }
    }

    private sealed class Handler2 : Game2.IMessageHandler
    {
        public int Received;
        public void onMessage(Game2.Message message) { Received++; }
        public void onConnectionFail(bool isMain) { }
        public void onDisconnected(bool isMain) { }
        public void onConnectOK(bool isMain) { }
    }

    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new Exception(message);
    }

    public static void Run()
    {
        RunGame1MainSession();
        RunGame1SecondSession();
        RunGame2MainSession();
        RunGame2SecondSession();
        UnityEngine.Debug.Log("ReceiveQueueBudgetRegression passed");
    }

    private static void RunGame1MainSession()
    {
        bool oldMobile = Game1.Main.isIPhone;
        bool oldStop = Game1.Controller.isStopReadMessage;
        var oldHandler = Game1.Session_ME.messageHandler;
        var handler = new Handler1();
        try
        {
            Game1.Main.isIPhone = true;
            Game1.Controller.isStopReadMessage = false;
            Game1.Session_ME.recieveMsg.Clear();
            Game1.Session_ME.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game1.Session_ME.recieveMsg.Enqueue(new Game1.Message(1));
            Game1.Session_ME.update();
            int received = handler.Received;
            Assert(received > 0 && received <= 64, "Game1 main session exceeded its frame budget");
            Assert(Game1.Session_ME.recieveMsg.Count == QueuedMessages - received, "Game1 main session lost deferred packets");
            Game1.Session_ME.update();
            Assert(handler.Received == received, "Game1 main session spent a second budget in one frame");
        }
        finally
        {
            Game1.Session_ME.recieveMsg.Clear();
            Game1.Session_ME.messageHandler = oldHandler;
            Game1.Main.isIPhone = oldMobile;
            Game1.Controller.isStopReadMessage = oldStop;
        }
    }

    private static void RunGame1SecondSession()
    {
        bool oldMobile = Game1.Main.isIPhone;
        bool oldStop = Game1.Controller.isStopReadMessage;
        var oldHandler = Game1.Session_ME2.messageHandler;
        var handler = new Handler1();
        try
        {
            Game1.Main.isIPhone = true;
            Game1.Controller.isStopReadMessage = false;
            Game1.Session_ME2.recieveMsg.Clear();
            Game1.Session_ME2.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game1.Session_ME2.recieveMsg.Enqueue(new Game1.Message(1));
            Game1.Session_ME2.update();
            int received = handler.Received;
            Assert(received > 0 && received <= 64, "Game1 second session exceeded its frame budget");
            Assert(Game1.Session_ME2.recieveMsg.Count == QueuedMessages - received, "Game1 second session lost deferred packets");
            Game1.Session_ME2.update();
            Assert(handler.Received == received, "Game1 second session spent a second budget in one frame");
        }
        finally
        {
            Game1.Session_ME2.recieveMsg.Clear();
            Game1.Session_ME2.messageHandler = oldHandler;
            Game1.Main.isIPhone = oldMobile;
            Game1.Controller.isStopReadMessage = oldStop;
        }
    }

    private static void RunGame2MainSession()
    {
        bool oldMobile = Game2.Main.isIPhone;
        bool oldStop = Game2.Controller.isStopReadMessage;
        var oldHandler = Game2.Session_ME.messageHandler;
        var handler = new Handler2();
        try
        {
            Game2.Main.isIPhone = true;
            Game2.Controller.isStopReadMessage = false;
            Game2.Session_ME.recieveMsg.Clear();
            Game2.Session_ME.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game2.Session_ME.recieveMsg.Enqueue(new Game2.Message(1));
            Game2.Session_ME.update();
            int received = handler.Received;
            Assert(received > 0 && received <= 64, "Game2 main session exceeded its frame budget");
            Assert(Game2.Session_ME.recieveMsg.Count == QueuedMessages - received, "Game2 main session lost deferred packets");
            Game2.Session_ME.update();
            Assert(handler.Received == received, "Game2 main session spent a second budget in one frame");
        }
        finally
        {
            Game2.Session_ME.recieveMsg.Clear();
            Game2.Session_ME.messageHandler = oldHandler;
            Game2.Main.isIPhone = oldMobile;
            Game2.Controller.isStopReadMessage = oldStop;
        }
    }

    private static void RunGame2SecondSession()
    {
        bool oldMobile = Game2.Main.isIPhone;
        bool oldStop = Game2.Controller.isStopReadMessage;
        var oldHandler = Game2.Session_ME2.messageHandler;
        var handler = new Handler2();
        try
        {
            Game2.Main.isIPhone = true;
            Game2.Controller.isStopReadMessage = false;
            Game2.Session_ME2.recieveMsg.Clear();
            Game2.Session_ME2.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game2.Session_ME2.recieveMsg.Enqueue(new Game2.Message(1));
            Game2.Session_ME2.update();
            int received = handler.Received;
            Assert(received > 0 && received <= 64, "Game2 second session exceeded its frame budget");
            Assert(Game2.Session_ME2.recieveMsg.Count == QueuedMessages - received, "Game2 second session lost deferred packets");
            Game2.Session_ME2.update();
            Assert(handler.Received == received, "Game2 second session spent a second budget in one frame");
        }
        finally
        {
            Game2.Session_ME2.recieveMsg.Clear();
            Game2.Session_ME2.messageHandler = oldHandler;
            Game2.Main.isIPhone = oldMobile;
            Game2.Controller.isStopReadMessage = oldStop;
        }
    }
}
