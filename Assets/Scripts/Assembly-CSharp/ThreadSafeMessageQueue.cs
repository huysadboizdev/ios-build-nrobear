using System.Collections.Generic;

namespace NRO.Networking
{
	public sealed class ConcurrentMessageQueue<T>
	{
		private readonly object gate = new object();
		private readonly Queue<T> queue = new Queue<T>();

		public int Count
		{
			get
			{
				lock (gate)
				{
					return queue.Count;
				}
			}
		}

		public void Enqueue(T message)
		{
			lock (gate)
			{
				queue.Enqueue(message);
			}
		}

		public bool TryDequeue(out T message)
		{
			lock (gate)
			{
				if (queue.Count == 0)
				{
					message = default(T);
					return false;
				}
				message = queue.Dequeue();
				return true;
			}
		}

		public void Clear()
		{
			lock (gate)
			{
				queue.Clear();
			}
		}
	}
}
