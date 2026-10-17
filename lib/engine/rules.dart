/// Every tunable number of the game in one place.
abstract final class Rules {
  // Economy
  static const int unitCost = 4;
  static const int unitsPerUpkeepGold = 4;
  static const int baseIncome = 4;

  /// A province raises at most this many units per turn, plus its income.
  static const int recruitBase = 2;

  // Combat
  static const double defenseBonus = 1.5;
  static const double capitalBonus = 0.5;

  /// Locals who fight beside the garrison of their own province. They cannot
  /// be moved and are back at full strength every turn: this base, plus the
  /// province's income times [militiaPerIncome].
  static const int militiaBase = 2;
  static const double militiaPerIncome = 0.5;

  /// The people of unclaimed land defend it this many times as hard as a
  /// militia would.
  static const double wildMilitia = 4;

  /// Each side's strength is scaled by a roll in [1 - spread, 1 + spread].
  static const double combatSpread = 0.15;

  // Landings
  /// Units that land from the sea fight at this share of their strength.
  static const double landingFactor = 0.75;

  // Building. One project per province per turn, finished at once.
  /// Each level of fortification adds this to a defender's cover.
  static const double fortBonus = 0.5;
  static const int maxFort = 2;

  /// Gold for a fort level: this times the level it reaches.
  static const int fortCost = 40;

  /// Gold a turn for every fort level standing.
  static const int fortUpkeep = 1;

  /// Development adds 1 income a level, up to [maxDevelop] levels. The first
  /// costs [developCost], each further one [developStep] more.
  static const int maxDevelop = 5;
  static const int developCost = 20;
  static const int developStep = 15;

  // Technology
  /// Gold for a level: the nation's income for this many turns, times the
  /// level it reaches. So the share of income put into research, not the
  /// size of the realm, sets the pace.
  static const int techCost = 2;
  static const int maxTech = 10;

  /// Each army level makes every unit fight this much harder, in attack and
  /// defence alike.
  static const double armyTechBonus = 0.05;

  /// Each industry level adds this share to the income.
  static const double industryTechBonus = 0.04;

  /// The shares of income, in percent, that can go into research.
  static const List<int> researchShares = [0, 10, 20, 30, 50];

  // Occupation
  /// A province taken from the nation that held it in the scenario yields
  /// this share of its income at first, and all of it after
  /// [integrationTurns]. Its first owner gets it back whole.
  static const double occupiedShare = 0.5;
  static const int integrationTurns = 24;

  // Unrest
  /// Each turn, an occupied province held by fewer units than its militia
  /// rises with this chance, scaled by how far short the garrison falls.
  static const double revoltChance = 0.015;

  /// Rebels who take the province: this many times its militia.
  static const double rebelsPerMilitia = 1.5;

  // Peace terms
  /// Reparations: the loser pays this share of its income to the winner for
  /// [reparationTurns] turns.
  static const double reparationShare = 0.25;
  static const int reparationTurns = 24;

  /// A vassal pays its overlord this share of its income every turn.
  static const double vassalTribute = 0.2;

  // Diplomacy
  static const int truceTurns = 8;

  /// A peace, alliance or pact offer stays on the table for this many
  /// end-of-turns.
  static const int peaceOfferTurns = 2;

  // Relations
  /// How two nations feel about each other, from -[maxRelation] to
  /// [maxRelation]; 0 is indifference.
  static const int maxRelation = 100;

  /// Relations at the start between allies, and between nations at war.
  /// Allies grow closer by themselves up to [alliedRelation], no further.
  static const int alliedRelation = 50;
  static const int warRelation = -60;

  /// A war, however it starts, leaves relations at this at best.
  static const int declaredRelation = -50;

  /// Peace on terms costs the loser this much with the winner, and leaving
  /// an alliance [brokenRelation] with the old ally.
  static const int termsRelation = -20;
  static const int brokenRelation = -25;

  /// Each turn allies grow a point closer (see [alliedRelation]) and
  /// enemies a point further apart; everyone else drifts a point towards
  /// indifference every [relationDriftTurns] turns.
  static const int relationDriftTurns = 1;

  /// An envoy raises relations by [envoyGain]. It costs [envoyIncomeShare]
  /// of the receiver's income, and at least [envoyMinCost]: a great power
  /// takes more courting than a small one.
  static const int envoyGain = 8;
  static const int envoyMinCost = 5;
  static const double envoyIncomeShare = 0.5;

  /// A gift worth the receiver's income for a turn raises relations by
  /// [giftGain]; no single gift by more than [giftMaxGain].
  static const int giftGain = 10;
  static const int giftMaxGain = 30;

  /// A call to arms stands for this many end-of-turns.
  static const int armsCallTurns = 3;

  /// The AI answers an ally's call to arms when it likes the caller at
  /// least this much.
  static const int aiArmsCallRelation = 20;

  /// Guaranteeing a nation's independence warms its relations by this much.
  static const int guaranteeRelation = 10;

  /// A non-aggression pact binds both sides for this many turns, and can be
  /// renewed once fewer than [pactRenewTurns] are left.
  static const int pactTurns = 36;
  static const int pactRenewTurns = 6;

  // Chronicle
  /// The chronicle keeps at most this many samples; past it, every other
  /// one goes and samples are taken half as often.
  static const int chronicleSamples = 240;

  // Game setup
  static const double startArmyPerIncome = 1.6;
  static const int startArmyPerProvince = 1;
  static const int startGoldPerIncome = 2;
  static const double defaultWinFraction = 0.4;

  /// The shares of all provinces a game can be won with.
  static const List<double> winFractions = [0.3, 0.4, 0.6, 0.75, 1.0];

  /// What a turn can stand for on the calendar, in months.
  static const List<int> turnLengths = [1, 3, 12];

  // Difficulty
  /// What the AI nations earn, against a normal income, on each difficulty
  /// from easiest to hardest. The player always earns the normal income.
  static const List<double> aiIncome = [0.8, 1.0, 1.25];

  /// On each difficulty, how the AI weighs a war on the player against one
  /// on anyone else (below 1: it looks for other prey first), and the turns
  /// at the start in which it declares none on the player at all.
  static const List<double> aiPlayerTarget = [0.5, 0.75, 1.0];
  static const List<int> aiSparePlayerTurns = [36, 12, 0];
  static const int normalDifficulty = 1;

  // AI
  static const double aiAttackMargin = 1.2;
  static const double aiWarRatio = 1.8;
  static const int aiMinWarTurns = 6;
  static const int aiStalemateTurns = 10;

  /// Every turn at peace makes the AI accept worse odds for its next war by
  /// this share of [aiWarRatio], down to [aiRestlessMax] of it. Without this
  /// two evenly matched empires would face each other in peace forever.
  static const double aiRestlessPerTurn = 0.02;
  static const double aiRestlessMax = 0.6;

  /// At peace the AI keeps its army at this share of what income can pay
  /// for, and at [aiWarArmy] once it is at war or sits on a full treasury.
  static const double aiPeaceArmy = 0.7;
  static const double aiWarArmy = 0.95;
  static const int aiFullTreasuryTurns = 8;

  /// The AI keeps no more allies than this.
  static const int aiMaxAlliances = 3;

  /// After proposing an alliance, the AI waits this many turns before it
  /// asks the same nation again.
  static const int aiAllianceRetryTurns = 12;

  /// A nation whose temper ([Nation.aggression]) is below [aiContentTemper]
  /// keeps its alliances through a long peace; at [aiPeacefulTemper] or
  /// below it starts no war at all and stays neutral, allying only with a
  /// friend who asks.
  static const double aiContentTemper = 0.5;
  static const double aiPeacefulTemper = 0.05;

  /// After taking a province of unclaimed land, the AI waits this many turns
  /// before it goes after another.
  static const int aiSettleTurns = 24;

  /// An AI vassal throws off its overlord once it is this strong against it.
  static const double aiIndependence = 0.75;

  /// The AI allies only with nations it likes at least [aiAllyRelation], and
  /// with one it likes [aiFriendRelation] whether or not a threat binds them.
  /// It signs pacts with nations it likes at least [aiPactRelation].
  static const int aiAllyRelation = -20;
  static const int aiFriendRelation = 60;
  static const int aiPactRelation = -20;

  /// Share of income, in percent, the AI puts into research at peace and
  /// at war.
  static const int aiResearchPeace = 20;
  static const int aiResearchWar = 10;
}
