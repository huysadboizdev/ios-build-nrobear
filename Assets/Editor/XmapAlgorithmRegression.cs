using System;
using System.Collections.Generic;
using Game2.Mod.XMAP;
using Game1XmapAlgorithm = Game1.Mod.XMAP.XmapAlgorithm;
using UnityEngine;

public static class XmapAlgorithmRegression
{
	private static int checks;
	private static void Check(bool condition, string message)
	{
		checks++;
		if (!condition) throw new Exception(message);
	}
	private static List<int> Find(Dictionary<int, int[]> graph, int start, int end, Action<int> visit = null)
	{
		return XmapAlgorithm.FindWay(start, end, id =>
		{
			if (visit != null) visit(id);
			int[] next;
			return graph.TryGetValue(id, out next) ? (IEnumerable<int>)next : new int[0];
		});
	}
	private static List<int> FindGame1(Dictionary<int, int[]> graph, int start, int end, Action<int> visit = null)
	{
		Func<int, IEnumerable<int>> getNextMaps = id =>
		{
			if (visit != null) visit(id);
			int[] next;
			return graph.TryGetValue(id, out next) ? (IEnumerable<int>)next : new int[0];
		};
		return (List<int>)typeof(Game1XmapAlgorithm).GetMethod("FindWay", new[] { typeof(int), typeof(int), typeof(Func<int, IEnumerable<int>>) })
			.Invoke(null, new object[] { start, end, getNextMaps });
	}
	private static string Route(List<int> route) { return route == null ? "null" : String.Join(",", route); }

	public static void Run()
	{
		checks = 0;
		Check(typeof(Game1XmapAlgorithm).GetMethod("FindWay", new[] { typeof(int), typeof(int), typeof(Func<int, IEnumerable<int>>) }) != null,
			"Game1 must expose a graph seam for route regression coverage");
		Dictionary<int, int[]> game1Graph = new Dictionary<int, int[]>
		{
			{ 0, new[] { 1, 2 } }, { 1, new[] { 3 } }, { 2, new[] { 3 } }, { 3, new[] { 4 } }
		};
		Check(Route(FindGame1(game1Graph, 0, 4)) == "0,1,3,4", "Game1 BFS must preserve shortest route and edge order");
		Check(Route(FindGame1(game1Graph, 4, 0)) == "null", "Game1 unreachable destination must return null");
		Check(Route(FindGame1(game1Graph, 3, 3)) == "3", "Game1 same start and destination must return one map");
		Dictionary<int, int[]> game1FutureGraph = new Dictionary<int, int[]>
		{
			{ 27, new[] { 102, 30 } }, { 102, new[] { 24 } }, { 30, new[] { 31 } }, { 31, new[] { 24 } }
		};
		Check(Route(FindGame1(game1FutureGraph, 27, 24)) == "27,30,31,24", "Game1 must prefer a valid route over the future-and-back route");
		Dictionary<int, int[]> game1BadOnlyGraph = new Dictionary<int, int[]>
		{
			{ 28, new[] { 102 } }, { 102, new[] { 24 } }
		};
		Check(Route(FindGame1(game1BadOnlyGraph, 28, 24)) == "28,102,24", "Game1 must allow the undesirable route as a fallback");
		int game1Expansions = 0;
		Dictionary<int, int[]> game1CapsuleGraph = new Dictionary<int, int[]>
		{
			{ 0, new[] { 1, 2, 3, 4, 5, 6 } }, { 1, new[] { 7, 8 } }, { 2, new[] { 7, 8 } },
			{ 3, new[] { 7, 8 } }, { 4, new[] { 7, 8 } }, { 5, new[] { 7, 8 } },
			{ 6, new[] { 7, 8 } }, { 7, new[] { 9 } }, { 8, new[] { 9 } }
		};
		Check(Route(FindGame1(game1CapsuleGraph, 0, 9, id => game1Expansions++)) == "0,1,7,9", "Game1 capsule fan-out must return the first shortest route");
		Check(game1Expansions <= 12, "Game1 capsule route search must have bounded graph expansion");
		Dictionary<int, int[]> graph = new Dictionary<int, int[]>
		{
			{ 0, new[] { 1, 2 } }, { 1, new[] { 3 } }, { 2, new[] { 3 } }, { 3, new[] { 4 } }
		};
		Check(Route(Find(graph, 0, 4)) == "0,1,3,4", "BFS must return the first shortest route and preserve edge order");
		Check(Route(Find(graph, 4, 0)) == "null", "Unreachable destination must return null");
		Check(Route(Find(graph, 3, 3)) == "3", "Same start and destination must return the one-map route");

		Dictionary<int, int[]> futureGraph = new Dictionary<int, int[]>
		{
			{ 27, new[] { 102, 30 } }, { 102, new[] { 24 } }, { 30, new[] { 31 } }, { 31, new[] { 24 } }
		};
		Check(Route(Find(futureGraph, 27, 24)) == "27,30,31,24", "A valid route must beat the shorter future-and-back route");
		Dictionary<int, int[]> badOnlyGraph = new Dictionary<int, int[]>
		{
			{ 28, new[] { 102 } }, { 102, new[] { 24 } }
		};
		Check(Route(Find(badOnlyGraph, 28, 24)) == "28,102,24", "Bad route remains available as fallback when no valid route exists");

		int expansions = 0;
		Dictionary<int, int[]> capsuleGraph = new Dictionary<int, int[]>
		{
			{ 0, new[] { 1, 2, 3, 4, 5, 6 } }, { 1, new[] { 7, 8 } }, { 2, new[] { 7, 8 } },
			{ 3, new[] { 7, 8 } }, { 4, new[] { 7, 8 } }, { 5, new[] { 7, 8 } },
			{ 6, new[] { 7, 8 } }, { 7, new[] { 9 } }, { 8, new[] { 9 } }
		};
		Check(Route(Find(capsuleGraph, 0, 9, id => expansions++)) == "0,1,7,9", "Capsule fan-out must find shortest path");
		Check(expansions <= 12, "Search work must remain bounded by graph states");
		Debug.Log("XMAP_ALGORITHM_PASS checks=" + checks + " expansions=" + expansions);
	}
}
