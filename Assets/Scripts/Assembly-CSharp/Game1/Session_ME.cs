using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using UnityEngine;

namespace Game1
{
	public class Session_ME : ISession
	{
		public class Sender
		{
			public NRO.Networking.ConcurrentMessageQueue<Message> sendingMessage;

			public Sender()
			{
				sendingMessage = new NRO.Networking.ConcurrentMessageQueue<Message>();
			}

			public void AddMessage(Message message)
			{
				sendingMessage.Enqueue(message);
			}

			public void run()
			{
				while (connected)
				{
					try
					{
						if (getKeyComplete)
						{
							while (sendingMessage.TryDequeue(out Message message))
							{
								doSendMessage(message);
							}
						}
						try
						{
							Thread.Sleep(5);
						}
						catch (Exception ex)
						{
							Cout.LogError(ex.ToString());
						}
					}
					catch (Exception)
					{
						Res.outz("error send message! ");
					}
				}
			}
		}

		private class MessageCollector
		{
			public void run()
			{
				try
				{
					while (connected)
					{
						Message message = readMessage();
						if (message == null)
						{
							break;
						}
						try
						{
							if (message.command == -27)
							{
								getKey(message);
							}
							else
							{
								onRecieveMsg(message);
							}
						}
						catch (Exception)
						{
							Cout.println("LOI NHAN  MESS THU 1");
						}
						try
						{
							Thread.Sleep(5);
						}
						catch (Exception)
						{
							Cout.println("LOI NHAN  MESS THU 2");
						}
					}
				}
				catch (Exception ex3)
				{
					Debug.Log(ex3.Message.ToString());
				}
				if (!connected)
				{
					return;
				}
				if (messageHandler != null)
				{
					if (currentTimeMillis() - timeConnected > 500)
					{
						messageHandler.onDisconnected(isMainSession);
					}
					else
					{
						messageHandler.onConnectionFail(isMainSession);
					}
				}
				if (sc != null)
				{
					cleanNetwork();
				}
			}

		private void getKey(Message message)
			{
				try
				{
					sbyte b = message.reader().readSByte();
					key = new sbyte[b];
					for (int i = 0; i < b; i++)
					{
						key[i] = message.reader().readSByte();
					}
					for (int j = 0; j < key.Length - 1; j++)
					{
						key[j + 1] ^= key[j];
					}
					getKeyComplete = true;
					GameMidlet.IP2 = message.reader().readUTF();
					GameMidlet.PORT2 = message.reader().readInt();
					GameMidlet.isConnect2 = ((message.reader().readByte() != 0) ? true : false);
					if (isMainSession && GameMidlet.isConnect2)
					{
						GameCanvas.connect2();
					}
				}
				catch (Exception)
				{
				}
			}

			private int readLengthByte(bool extended)
			{
				sbyte value = dis.ReadSByte();
				if (getKeyComplete) value = readKey(value);
				return extended ? value + 128 : value & 255;
			}

			private Message readPayload(sbyte command, int length, int headerLength)
			{
				if (length < 0 || length > 0xFFFFFF) throw new InvalidDataException("Invalid message length");
				if (dis.BaseStream.CanSeek && length > dis.BaseStream.Length - dis.BaseStream.Position)
					throw new EndOfStreamException("Truncated message payload");
				byte[] bytes = dis.ReadBytes(length);
				if (bytes.Length != length) throw new EndOfStreamException("Truncated message payload");
				sbyte[] data = new sbyte[length];
				Buffer.BlockCopy(bytes, 0, data, 0, length);
				if (getKeyComplete)
				{
					for (int i = 0; i < data.Length; i++) data[i] = readKey(data[i]);
				}
				recvByteCount += headerLength + length;
				int total = recvByteCount + sendByteCount;
				strRecvByteCount = total / 1024 + "." + total % 1024 / 102 + "Kb";
				// Apply negotiation on this collector before it reads the next frame.
				// Inspect raw payload without advancing the main-thread message reader.
				if (command == -29 && data.Length >= 2 && data[0] == 100)
				{
					UseItemOptionsInt32 = data[1] != 0;
					UseInventory200 = data.Length >= 3 && data[2] != 0;
				}
				Message message = new Message(command, data);
				message.PacketItemOptionsInt32 = UseItemOptionsInt32;
				message.PacketInventory200 = UseInventory200;
				return message;
			}

			private Message readMessage2(sbyte command)
			{
				int low = readLengthByte(true);
				int middle = readLengthByte(true);
				int high = readLengthByte(true);
				return readPayload(command, low | (middle << 8) | (high << 16), 4);
			}

			private Message readMessage()
			{
				try
				{
					sbyte command = dis.ReadSByte();
					if (getKeyComplete) command = readKey(command);
					if (command == -32 || command == -66 || command == 11 || command == -67 || command == -74 || command == -87 || command == 66 || command == 12  || (UseInventory200 && (command == -30 || command == -35 || command == -36 || command == -86 || command == -44)))
						return readMessage2(command);
					int high = readLengthByte(false);
					int low = readLengthByte(false);
					return readPayload(command, (high << 8) | low, 3);
				}
				catch (Exception)
				{
					return null;
				}
			}
		}

		protected static Session_ME instance = new Session_ME();

		private static NetworkStream dataStream;

		private static BinaryReader dis;

		private static BinaryWriter dos;

		public static IMessageHandler messageHandler;

		public static bool isMainSession = true;

		private static TcpClient sc;

		public static bool connected;

		public static bool connecting;

		private static Sender sender = new Sender();

		public static Thread initThread;

		public static Thread collectorThread;

		public static Thread sendThread;

		public static int sendByteCount;

		public static int recvByteCount;

		public static bool UseInventory200;

		public static bool UseItemOptionsInt32;

		private static bool getKeyComplete;

		public static sbyte[] key = null;

		private static sbyte curR;

		private static sbyte curW;

		private static int timeConnected;

		public static string strRecvByteCount = string.Empty;

		public static bool isCancel;

		private string host;

		private int port;

		private long timeWaitConnect;

		public static int count;

		public static MyVector recieveMsg = new MyVector();

		public void clearSendingMessage()
		{
			sender.sendingMessage.Clear();
		}

		public static Session_ME gI()
		{
			if (instance == null)
			{
				instance = new Session_ME();
			}
			return instance;
		}

		public bool isConnected()
		{
			if (connected && sc != null)
			{
				return dis != null;
			}
			return false;
		}

		public void setHandler(IMessageHandler msgHandler)
		{
			messageHandler = msgHandler;
		}

		public void connect(string host, int port)
		{
			if (!connected && !connecting && mSystem.currentTimeMillis() >= timeWaitConnect)
			{
				timeWaitConnect = mSystem.currentTimeMillis() + 50;
				if (isMainSession)
				{
					ServerListScreen.testConnect = -1;
				}
				this.host = host;
				this.port = port;
				getKeyComplete = false;
				close();
				Debug.Log("host: " + host + ":" + port);
				initThread = new Thread(NetworkInit);
				initThread.Start();
			}
		}

		private async void NetworkInit()
		{
			isCancel = false;
			connecting = true;
            System.Threading.Thread.CurrentThread.Priority = System.Threading.ThreadPriority.Highest;
			connected = true;
			try
			{
				doConnect(host, port);
				messageHandler.onConnectOK(isMainSession);
			}
			catch (Exception)
			{
				if (messageHandler != null)
				{
					close();
					messageHandler.onConnectionFail(isMainSession);
				}
			}
		}

		public void doConnect(string host, int port)
		{
			sc = new TcpClient();
			sc.Connect(host, port);
			dataStream = sc.GetStream();
			dis = new BinaryReader(dataStream, new UTF8Encoding());
			dos = new BinaryWriter(dataStream, new UTF8Encoding());
			sendThread = new Thread(sender.run);
			sendThread.Start();
			collectorThread = new Thread(new MessageCollector().run);
			collectorThread.Start();
			timeConnected = currentTimeMillis();
			connecting = false;
			doSendMessage(new Message(-27));
			key = null;
		}

		public void sendMessage(Message message)
		{
			count++;
			Res.outz("SEND MSG: " + message.command);
			sender.AddMessage(message);
		}

		private static void doSendMessage(Message m)
		{
			sbyte[] data = m.getData();
			try
			{
				if (getKeyComplete)
				{
					sbyte value = writeKey(m.command);
					dos.Write(value);
				}
				else
				{
					dos.Write(m.command);
				}
				if (data != null)
				{
					int num = data.Length;
					if (getKeyComplete)
					{
						int num2 = writeKey((sbyte)(num >> 8));
						dos.Write((sbyte)num2);
						int num3 = writeKey((sbyte)(num & 0xFF));
						dos.Write((sbyte)num3);
					}
					else
					{
						dos.Write((ushort)num);
					}
					if (getKeyComplete)
					{
						for (int i = 0; i < data.Length; i++)
						{
							sbyte value2 = writeKey(data[i]);
							dos.Write(value2);
						}
					}
					sendByteCount += 5 + data.Length;
				}
				else
				{
					if (getKeyComplete)
					{
						int num4 = writeKey(0);
						dos.Write((sbyte)num4);
						int num5 = writeKey(0);
						dos.Write((sbyte)num5);
					}
					else
					{
						dos.Write((ushort)0);
					}
					sendByteCount += 5;
				}
				dos.Flush();
			}
			catch (Exception ex)
			{
				Debug.Log(ex.StackTrace);
				dos.Flush();
			}
		}

		public static sbyte readKey(sbyte b)
		{
			sbyte result = (sbyte)((key[curR++] & 0xFF) ^ (b & 0xFF));
			if (curR >= key.Length)
			{
				curR %= (sbyte)key.Length;
			}
			return result;
		}

		public static sbyte writeKey(sbyte b)
		{
			sbyte result = (sbyte)((key[curW++] & 0xFF) ^ (b & 0xFF));
			if (curW >= key.Length)
			{
				curW %= (sbyte)key.Length;
			}
			return result;
		}

		public static void onRecieveMsg(Message msg)
		{
			if (Thread.CurrentThread.Name == Main.mainThreadName)
			{
				messageHandler.onMessage(msg);
			}
			else
			{
				lock (recieveMsg)
				{
					recieveMsg.addElement(msg);
				}
			}
		}

		public static void update()
		{
			Message[] messages;
			lock (recieveMsg)
			{
				if (Controller.isStopReadMessage || recieveMsg.size() == 0)
				{
					return;
				}
				int count = recieveMsg.size();
				messages = new Message[count];
				for (int i = 0; i < count; i++)
				{
					messages[i] = (Message)recieveMsg.elementAt(i);
				}
				recieveMsg.removeAllElements();
			}
			for (int i = 0; i < messages.Length; i++)
			{
				if (messages[i] != null)
				{
					messageHandler.onMessage(messages[i]);
				}
			}
		}

		public void close()
		{
			cleanNetwork();
		}

		private static void cleanNetwork()
		{
			UseInventory200 = false;
			UseItemOptionsInt32 = false;
			ItemOptionWire.UseInt32 = false;
			key = null;
			curR = 0;
			curW = 0;
			try
			{
				connected = false;
				connecting = false;
				if (sc != null)
				{
					sc.Close();
					sc = null;
				}
				if (dataStream != null)
				{
					dataStream.Close();
					dataStream = null;
				}
				if (dos != null)
				{
					dos.Close();
					dos = null;
				}
				if (dis != null)
				{
					dis.Close();
					dis = null;
				}
				if (Thread.CurrentThread.Name == Main.mainThreadName)
				{
					if (sendThread != null)
					{
						sendThread.Abort();
					}
					sendThread = null;
					if (initThread != null)
					{
						initThread.Abort();
					}
					initThread = null;
					if (collectorThread != null)
					{
						collectorThread.Abort();
					}
					collectorThread = null;
				}
				else
				{
					sendThread = null;
					initThread = null;
					collectorThread = null;
				}
				if (isMainSession)
				{
					ServerListScreen.testConnect = 0;
				}
			}
			catch (Exception)
			{
			}
		}

		public static int currentTimeMillis()
		{
			return Environment.TickCount;
		}

		public bool isCompareIPConnect()
		{
			return true;
		}
	}
}
