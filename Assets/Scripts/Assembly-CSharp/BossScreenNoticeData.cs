// Boss screen notification filter shared by Game1/Game2.
// Matches the server/Web command 115 v2 contract:
// schema, version, eventKey, semanticId, form, mapId, mapType, ticker, hiddenFromPanel.
// Command 93 stays ticker-only and its legacy overlay entry is visible.
// No Unity/drawing dependencies so client tests can compile this file in isolation.
using System;

namespace Game1
{
	public class BossScreenNoticeData
	{
		public const int ScreenCommand = 115;

		public const int ScreenSchema = 1;

		public const int ScreenVersion = 2;

		public string eventKey;

		public int semanticBossId;

		public int form;

		public int mapId;

		public int mapType;

		public string ticker;

		public bool hiddenFromPanel;

		public BossScreenNoticeData(string eventKey, int semanticBossId, int form, int mapId, int mapType, string ticker, bool hiddenFromPanel)
		{
			this.eventKey = eventKey;
			this.semanticBossId = semanticBossId;
			this.form = form;
			this.mapId = mapId;
			this.mapType = mapType;
			this.ticker = ticker;
			this.hiddenFromPanel = hiddenFromPanel;
		}

		public static bool TryRead(myReader reader, out BossScreenNoticeData data)
		{
			data = null;
			int schema = reader.readUnsignedByte();
			int version = reader.readUnsignedByte();
			string eventKey = reader.readUTF();
			int semanticBossId = reader.readInt();
			int form = reader.readInt();
			int mapId = reader.readInt();
			int mapType = reader.readInt();
			string ticker = reader.readUTF();
			bool hiddenFromPanel = reader.readBoolean();
			if (schema != ScreenSchema || version != ScreenVersion)
			{
				return false;
			}
			data = new BossScreenNoticeData(eventKey, semanticBossId, form, mapId, mapType, ticker, hiddenFromPanel);
			return true;
		}

		public static bool ShouldShow(BossScreenNoticeData data)
		{
			if (data == null)
			{
				return true;
			}
			return !data.hiddenFromPanel;
		}

		public static bool ShouldShowLegacyFallback(bool hiddenFromPanel, bool awaitingScreenMetadata, long now, long fallbackAt)
		{
			return !hiddenFromPanel && (!awaitingScreenMetadata || now >= fallbackAt);
		}
	}
}

namespace Game2
{
	public class BossScreenNoticeData
	{
		public const int ScreenCommand = 115;

		public const int ScreenSchema = 1;

		public const int ScreenVersion = 2;

		public string eventKey;

		public int semanticBossId;

		public int form;

		public int mapId;

		public int mapType;

		public string ticker;

		public bool hiddenFromPanel;

		public BossScreenNoticeData(string eventKey, int semanticBossId, int form, int mapId, int mapType, string ticker, bool hiddenFromPanel)
		{
			this.eventKey = eventKey;
			this.semanticBossId = semanticBossId;
			this.form = form;
			this.mapId = mapId;
			this.mapType = mapType;
			this.ticker = ticker;
			this.hiddenFromPanel = hiddenFromPanel;
		}

		public static bool TryRead(myReader reader, out BossScreenNoticeData data)
		{
			data = null;
			int schema = reader.readUnsignedByte();
			int version = reader.readUnsignedByte();
			string eventKey = reader.readUTF();
			int semanticBossId = reader.readInt();
			int form = reader.readInt();
			int mapId = reader.readInt();
			int mapType = reader.readInt();
			string ticker = reader.readUTF();
			bool hiddenFromPanel = reader.readBoolean();
			if (schema != ScreenSchema || version != ScreenVersion)
			{
				return false;
			}
			data = new BossScreenNoticeData(eventKey, semanticBossId, form, mapId, mapType, ticker, hiddenFromPanel);
			return true;
		}

		public static bool ShouldShow(BossScreenNoticeData data)
		{
			if (data == null)
			{
				return true;
			}
			return !data.hiddenFromPanel;
		}

		public static bool ShouldShowLegacyFallback(bool hiddenFromPanel, bool awaitingScreenMetadata, long now, long fallbackAt)
		{
			return !hiddenFromPanel && (!awaitingScreenMetadata || now >= fallbackAt);
		}
	}
}
