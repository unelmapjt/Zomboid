local SpawnItems = {};

SpawnItems.SpecialKeyRingChance = 1

SpawnItems.ProfessionKeyRings = {
	[CharacterProfession.FKLR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.KLBR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.LSTR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.ADLR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.ATCR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.ATSR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.EULR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.ARAR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
	[CharacterProfession.MNHR] = { ItemKey.Container.KEY_RING_EAGLE_FLAG,  },
}

Events.OnNewGame.Add(SpawnItems.OnNewGame);
Events.OnGameStart.Add(SpawnItems.onNewGame);