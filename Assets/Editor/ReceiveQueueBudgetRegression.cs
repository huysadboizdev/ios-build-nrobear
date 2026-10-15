using System;

public static class ReceiveQueueBudgetRegression
{
    private const int QueuedMessages = 40;

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
        var oldHandler = Game1.Session_ME.messageHandler;
        var handler = new Handler1();
        try
        {
            Game1.Main.isIPhone = true;
            Game1.Controller.isStopReadMessage = false;
            Game1.Session_ME.recieveMsg.removeAllElements();
            Game1.Session_ME.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game1.Session_ME.recieveMsg.addElement(new Game1.Message(1));
            Game1.Session_ME.update();
            Assert(handler.Received == QueuedMessages, "Game1 main session did not drain the queued batch");
            Assert(Game1.Session_ME.recieveMsg.size() == 0, "Game1 main session left stale packets in the queue");
            Game1.Session_ME.update();
            Assert(handler.Received == QueuedMessages, "Game1 main session did not resume queued packets next frame");
        }
        finally
        {
            Game1.Session_ME.recieveMsg.removeAllElements();
            Game1.Session_ME.messageHandler = oldHandler;
            Game1.Main.isIPhone = oldMobile;
        }
    }

    private static void RunGame1SecondSession()
    {
        bool oldMobile = Game1.Main.isIPhone;
        var oldHandler = Game1.Session_ME2.messageHandler;
        var handler = new Handler1();
        try
        {
            Game1.Main.isIPhone = true;
            Game1.Controller.isStopReadMessage = false;
            Game1.Session_ME2.recieveMsg.removeAllElements();
            Game1.Session_ME2.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game1.Session_ME2.recieveMsg.addElement(new Game1.Message(1));
            Game1.Session_ME2.update();
            Assert(handler.Received == QueuedMessages, "Game1 second session did not drain the queued batch");
            Assert(Game1.Session_ME2.recieveMsg.size() == 0, "Game1 second session left stale packets in the queue");
            Game1.Session_ME2.update();
            Assert(handler.Received == QueuedMessages, "Game1 second session did not resume queued packets next frame");
        }
        finally
        {
            Game1.Session_ME2.recieveMsg.removeAllElements();
            Game1.Session_ME2.messageHandler = oldHandler;
            Game1.Main.isIPhone = oldMobile;
        }
    }

    private static void RunGame2MainSession()
    {
        bool oldMobile = Game2.Main.isIPhone;
        var oldHandler = Game2.Session_ME.messageHandler;
        var handler = new Handler2();
        try
        {
            Game2.Main.isIPhone = true;
            Game2.Controller.isStopReadMessage = false;
            Game2.Session_ME.recieveMsg.removeAllElements();
            Game2.Session_ME.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game2.Session_ME.recieveMsg.addElement(new Game2.Message(1));
            Game2.Session_ME.update();
            Assert(handler.Received == QueuedMessages, "Game2 main session did not drain the queued batch");
            Assert(Game2.Session_ME.recieveMsg.size() == 0, "Game2 main session left stale packets in the queue");
            Game2.Session_ME.update();
            Assert(handler.Received == QueuedMessages, "Game2 main session did not resume queued packets next frame");
        }
        finally
        {
            Game2.Session_ME.recieveMsg.removeAllElements();
            Game2.Session_ME.messageHandler = oldHandler;
            Game2.Main.isIPhone = oldMobile;
        }
    }

    private static void RunGame2SecondSession()
    {
        bool oldMobile = Game2.Main.isIPhone;
        var oldHandler = Game2.Session_ME2.messageHandler;
        var handler = new Handler2();
        try
        {
            Game2.Main.isIPhone = true;
            Game2.Controller.isStopReadMessage = false;
            Game2.Session_ME2.recieveMsg.removeAllElements();
            Game2.Session_ME2.gI().setHandler(handler);
            for (int i = 0; i < QueuedMessages; i++) Game2.Session_ME2.recieveMsg.addElement(new Game2.Message(1));
            Game2.Session_ME2.update();
            Assert(handler.Received == QueuedMessages, "Game2 second session did not drain the queued batch");
            Assert(Game2.Session_ME2.recieveMsg.size() == 0, "Game2 second session left stale packets in the queue");
            Game2.Session_ME2.update();
            Assert(handler.Received == QueuedMessages, "Game2 second session did not resume queued packets next frame");
        }
        finally
        {
            Game2.Session_ME2.recieveMsg.removeAllElements();
            Game2.Session_ME2.messageHandler = oldHandler;
            Game2.Main.isIPhone = oldMobile;
        }
    }
}
