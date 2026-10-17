using System;
using System.Collections.Generic;

namespace Game1.Mod.XMAP
{
	public class XmapAlgorithm
	{
		public static List<int> FindWay(int idMapStart, int idMapEnd)
		{
			return FindWay(idMapStart, idMapEnd, GetNextMapIds);
		}

		// Keep route rules testable without depending on live map state.
		public static List<int> FindWay(int idMapStart, int idMapEnd, Func<int, IEnumerable<int>> getNextMaps)
		{
			List<int> way = FindShortestWay(idMapStart, idMapEnd, getNextMaps, true);
			return way ?? FindShortestWay(idMapStart, idMapEnd, getNextMaps, false);
		}

		private static IEnumerable<int> GetNextMapIds(int mapID)
		{
			if (XmapData.GI().CanGetMapNexts(mapID))
			{
				foreach (MapNext next in XmapData.GI().GetMapNexts(mapID))
				{
					yield return next.MapID;
				}
			}
		}

		private static List<int> FindShortestWay(int start, int end, Func<int, IEnumerable<int>> getNextMaps, bool avoidBadWay)
		{
			if (getNextMaps == null)
			{
				throw new ArgumentNullException("getNextMaps");
			}

			List<int> initial = new List<int> { start };
			if (start == end)
			{
				return initial;
			}

			Queue<List<int>> queue = new Queue<List<int>>();
			HashSet<long> visited = new HashSet<long>();
			queue.Enqueue(initial);
			visited.Add(StateKey(-1, start));
			while (queue.Count > 0)
			{
				List<int> way = queue.Dequeue();
				int current = way[way.Count - 1];
				IEnumerable<int> nextMaps = getNextMaps(current);
				if (nextMaps == null)
				{
					continue;
				}

				foreach (int next in nextMaps)
				{
					int previous = way.Count > 1 ? way[way.Count - 2] : -1;
					if (avoidBadWay && IsBadTransition(previous, current, next))
					{
						continue;
					}

					if (!visited.Add(StateKey(current, next)))
					{
						continue;
					}

					List<int> nextWay = new List<int>(way) { next };
					if (next == end)
					{
						return nextWay;
					}
					queue.Enqueue(nextWay);
				}
			}

			return null;
		}

		private static long StateKey(int previous, int current)
		{
			return ((long)(previous + 1) << 32) | (uint)current;
		}

		private static bool IsBadTransition(int previous, int current, int next)
		{
			return current == 102 && next == 24 && (previous == 27 || previous == 28 || previous == 29);
		}
	}
}
